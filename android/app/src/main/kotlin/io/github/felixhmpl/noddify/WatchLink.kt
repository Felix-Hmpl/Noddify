package io.github.felixhmpl.noddify

import android.content.Context
import android.util.Log
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import io.github.felixhmpl.noddify.core.SessionMessageParser
import io.github.felixhmpl.noddify.core.SyncStatus
import io.github.felixhmpl.noddify.core.SyncTracker
import io.github.felixhmpl.noddify.core.WatchProtocol
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Receives sessions from the Noddify watch app through Garmin Connect Mobile (Connect IQ
 * Mobile SDK) and acknowledges each stored one, so the watch drops it from its outbox.
 *
 * [requestSync] asks the watch for its pending sessions. The watch answers even while Noddify
 * is closed on it, from its background sync service.
 */
class WatchLink(private val context: Context, private val sessions: SessionRepository) {

    enum class Status {
        STARTING,
        /** Garmin Connect Mobile is missing or too old. */
        NO_GARMIN_CONNECT,
        /** No watch is paired in Garmin Connect Mobile. */
        NO_WATCH,
        NOT_CONNECTED,
        CONNECTED,
    }

    data class State(val status: Status, val watchName: String? = null)

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val connectIQ = ConnectIQ.getInstance(context, ConnectIQ.IQConnectType.WIRELESS)
    private val watchApp = IQApp(BuildConfig.WATCH_APP_ID)
    private val _state = MutableStateFlow(State(Status.STARTING))
    val state: StateFlow<State> = _state

    private val tracker = SyncTracker()
    private val _sync = MutableStateFlow(SyncStatus())
    val sync: StateFlow<SyncStatus> = _sync
    private var sdkReady = false
    private var syncTimeout: Job? = null

    fun start() {
        connectIQ.initialize(context, false, object : ConnectIQ.ConnectIQListener {
            override fun onSdkReady() {
                sdkReady = true
                listenToWatches()
                if (tracker.isSyncing) sendSyncRequest()
            }

            override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                Log.w(TAG, "Connect IQ unavailable: $status")
                _state.value = State(Status.NO_GARMIN_CONNECT)
                updateSync { onFailed() }
            }

            override fun onSdkShutDown() {
                sdkReady = false
                _state.value = State(Status.STARTING)
            }
        })
    }

    /**
     * Asks the connected watch for every session it hasn't handed over yet. Does nothing while a
     * sync runs; waits for the SDK if it isn't ready yet.
     */
    fun requestSync() {
        if (!tracker.start()) return
        _sync.value = tracker.status
        syncTimeout?.cancel()
        syncTimeout = scope.launch {
            delay(SYNC_TIMEOUT_MS)
            updateSync { onTimeout() }
        }
        if (sdkReady) sendSyncRequest()
    }

    private fun sendSyncRequest() {
        val watches = try {
            connectIQ.connectedDevices.orEmpty()
        } catch (e: Exception) {
            Log.w(TAG, "Can't list connected watches", e)
            emptyList()
        }
        if (watches.isEmpty()) {
            updateSync { onFailed() }
            return
        }
        val request = WatchProtocol.syncRequest(sessions.sessions.value.map { it.id })
        watches.forEach { watch ->
            try {
                connectIQ.sendMessage(watch, watchApp, request) { _, _, status ->
                    if (status != ConnectIQ.IQMessageStatus.SUCCESS) {
                        Log.w(TAG, "Sync request to ${watch.friendlyName} failed: $status")
                        if (watches.size == 1) scope.launch { updateSync { onFailed() } }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Can't ask ${watch.friendlyName} to sync", e)
                if (watches.size == 1) updateSync { onFailed() }
            }
        }
    }

    private fun updateSync(change: SyncTracker.() -> Unit) {
        tracker.change()
        _sync.value = tracker.status
        if (!tracker.isSyncing) syncTimeout?.cancel()
    }

    private fun listenToWatches() {
        val devices = try {
            connectIQ.knownDevices.orEmpty()
        } catch (e: Exception) {
            Log.w(TAG, "Can't list watches", e)
            emptyList()
        }
        if (devices.isEmpty()) {
            _state.value = State(Status.NO_WATCH)
            return
        }
        devices.forEach { device ->
            try {
                connectIQ.registerForDeviceEvents(device) { watch, status -> onStatus(watch, status) }
                connectIQ.registerForAppEvents(device, watchApp) { watch, _, messages, status ->
                    if (status == ConnectIQ.IQMessageStatus.SUCCESS) {
                        messages.forEach { onMessage(watch, it) }
                    }
                }
                onStatus(device, connectIQ.getDeviceStatus(device))
            } catch (e: Exception) {
                Log.w(TAG, "Can't listen to ${device.friendlyName}", e)
            }
        }
    }

    private fun onStatus(device: IQDevice, status: IQDevice.IQDeviceStatus?) {
        if (status == IQDevice.IQDeviceStatus.CONNECTED) {
            _state.value = State(Status.CONNECTED, device.friendlyName)
        } else if (_state.value.watchName == null || _state.value.watchName == device.friendlyName) {
            _state.value = State(Status.NOT_CONNECTED, device.friendlyName)
        }
    }

    private fun onMessage(device: IQDevice, message: Any?) {
        if (WatchProtocol.isSyncDone(message)) {
            scope.launch { updateSync { onSyncDone() } }
            return
        }
        val session = SessionMessageParser.parse(message) ?: return
        scope.launch {
            val added = sessions.add(listOf(session))
            updateSync { onSession(isNew = added > 0) }
            acknowledge(device, session.id)
        }
    }

    private fun acknowledge(device: IQDevice, sessionId: Long) {
        val ack = WatchProtocol.ack(sessionId)
        try {
            connectIQ.sendMessage(device, watchApp, ack) { _, _, status ->
                if (status != ConnectIQ.IQMessageStatus.SUCCESS) Log.w(TAG, "Ack for $sessionId failed: $status")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Can't acknowledge $sessionId", e)
        }
    }

    private companion object {
        const val TAG = "WatchLink"

        /** How long a sync waits for the watch's syncDone. */
        const val SYNC_TIMEOUT_MS = 40_000L
    }
}
