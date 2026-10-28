package io.github.felixhmpl.noddify

import android.content.Context
import android.util.Log
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import io.github.felixhmpl.noddify.core.SessionMessageParser
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Receives sessions from the Noddify watch app through Garmin Connect Mobile (Connect IQ
 * Mobile SDK) and acknowledges each stored one, so the watch drops it from its outbox.
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

    fun start() {
        connectIQ.initialize(context, false, object : ConnectIQ.ConnectIQListener {
            override fun onSdkReady() = listenToWatches()

            override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                Log.w(TAG, "Connect IQ unavailable: $status")
                _state.value = State(Status.NO_GARMIN_CONNECT)
            }

            override fun onSdkShutDown() {
                _state.value = State(Status.STARTING)
            }
        })
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
        val session = SessionMessageParser.parse(message) ?: return
        scope.launch {
            sessions.add(listOf(session))
            acknowledge(device, session.id)
        }
    }

    private fun acknowledge(device: IQDevice, sessionId: Long) {
        val ack = hashMapOf<String, Any>("type" to "ack", "id" to sessionId.toInt())
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
    }
}
