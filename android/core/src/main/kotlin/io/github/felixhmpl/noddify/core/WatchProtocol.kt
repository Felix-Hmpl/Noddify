package io.github.felixhmpl.noddify.core

/**
 * The messages between the phone app and the watch besides the session itself
 * (see source/phone/PhoneProtocol.mc). Built as the HashMaps and Integers the Connect IQ
 * SDK serializes for the watch.
 */
object WatchProtocol {

    const val ACK = "ack"
    const val SYNC = "sync"
    const val SYNC_DONE = "syncDone"

    /** How many of the newest stored session ids a sync request lists; the watch keeps at most 10. */
    const val STORED_IDS = 20

    /** Tells the watch the phone stored the session, so it can drop it. */
    fun ack(sessionId: Long): HashMap<String, Any> = hashMapOf("type" to ACK, "id" to sessionId.toInt())

    /** Asks the watch for every pending session. [storedIds] are sessions the phone already has. */
    fun syncRequest(storedIds: List<Long>): HashMap<String, Any> =
        hashMapOf("type" to SYNC, "have" to ArrayList(storedIds.take(STORED_IDS).map { it.toInt() }))

    /** True for the watch's answer to a sync request, sent after the sessions. */
    fun isSyncDone(message: Any?): Boolean = (message as? Map<*, *>)?.get("type") == SYNC_DONE
}

enum class SyncState {
    /** No sync has run since the app started. */
    IDLE,
    SYNCING,
    SYNCED,
    FAILED,
}

/** Where the latest sync stands, and how many new sessions it brought. */
data class SyncStatus(val state: SyncState = SyncState.IDLE, val newSessions: Int = 0)

/**
 * Follows one sync at a time. A sync succeeds when the watch answers syncDone, or when it
 * times out after at least one session arrived; otherwise a timeout or a send error fails it.
 */
class SyncTracker {

    var status = SyncStatus()
        private set

    val isSyncing: Boolean get() = status.state == SyncState.SYNCING

    /** Returns false if a sync is already running. */
    fun start(): Boolean {
        if (isSyncing) return false
        status = SyncStatus(SyncState.SYNCING)
        return true
    }

    fun onSession(isNew: Boolean) {
        if (isSyncing && isNew) status = status.copy(newSessions = status.newSessions + 1)
    }

    fun onSyncDone() {
        if (isSyncing) status = status.copy(state = SyncState.SYNCED)
    }

    fun onTimeout() {
        if (isSyncing) status = status.copy(state = if (status.newSessions > 0) SyncState.SYNCED else SyncState.FAILED)
    }

    fun onFailed() {
        if (isSyncing) status = status.copy(state = SyncState.FAILED)
    }
}
