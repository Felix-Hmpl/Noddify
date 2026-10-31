package io.github.felixhmpl.noddify

import io.github.felixhmpl.noddify.core.Session
import io.github.felixhmpl.noddify.core.SessionStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** The stored sessions as a flow for the screens, newest first. */
class SessionRepository(private val store: SessionStore) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val lock = Mutex()
    private val _sessions = MutableStateFlow<List<Session>>(emptyList())
    val sessions: StateFlow<List<Session>> = _sessions

    init {
        scope.launch { lock.withLock { _sessions.value = store.loadAll() } }
    }

    /** Stores the sessions; ones already stored are left as they are. */
    suspend fun add(sessions: List<Session>) = withContext(Dispatchers.IO) {
        lock.withLock {
            sessions.forEach { store.save(it) }
            _sessions.value = store.loadAll()
        }
    }

    fun addInBackground(sessions: List<Session>) {
        scope.launch { add(sessions) }
    }

    fun deleteAllInBackground() {
        scope.launch {
            lock.withLock {
                store.deleteAll()
                _sessions.value = emptyList()
            }
        }
    }
}
