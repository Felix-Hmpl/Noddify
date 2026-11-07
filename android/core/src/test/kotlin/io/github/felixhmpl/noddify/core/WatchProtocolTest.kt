package io.github.felixhmpl.noddify.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class WatchProtocolTest {

    @Test
    fun buildsMessagesForTheWatch() {
        assertEquals(hashMapOf<String, Any>("type" to "ack", "id" to 1_700_000_000), WatchProtocol.ack(1_700_000_000L))
        val request = WatchProtocol.syncRequest((1L..30L).toList())
        assertEquals("sync", request["type"])
        assertEquals((1..20).toList(), request["have"])
        assertTrue(WatchProtocol.isSyncDone(hashMapOf("type" to "syncDone")))
        assertFalse(WatchProtocol.isSyncDone(hashMapOf("type" to "session")))
        assertFalse(WatchProtocol.isSyncDone("syncDone"))
    }

    @Test
    fun syncSucceedsWhenTheWatchIsDone() {
        val tracker = SyncTracker()
        assertTrue(tracker.start())
        assertFalse(tracker.start())
        tracker.onSession(isNew = true)
        tracker.onSession(isNew = false)
        tracker.onSyncDone()
        assertEquals(SyncStatus(SyncState.SYNCED, newSessions = 1), tracker.status)
        // A late timeout doesn't change a finished sync.
        tracker.onTimeout()
        assertEquals(SyncState.SYNCED, tracker.status.state)
    }

    @Test
    fun timeoutFailsUnlessSessionsArrived() {
        val silent = SyncTracker().apply { start(); onTimeout() }
        assertEquals(SyncState.FAILED, silent.status.state)
        val partial = SyncTracker().apply { start(); onSession(isNew = true); onTimeout() }
        assertEquals(SyncState.SYNCED, partial.status.state)
        val unreachable = SyncTracker().apply { start(); onFailed() }
        assertEquals(SyncState.FAILED, unreachable.status.state)
        // A new sync can start after a failed one.
        assertTrue(unreachable.start())
    }
}
