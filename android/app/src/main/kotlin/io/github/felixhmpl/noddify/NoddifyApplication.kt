package io.github.felixhmpl.noddify

import android.app.Application
import io.github.felixhmpl.noddify.core.SessionStore
import java.io.File

/** Owns the session storage and the watch link for as long as the app process lives. */
class NoddifyApplication : Application() {

    lateinit var sessions: SessionRepository
        private set
    lateinit var watch: WatchLink
        private set

    override fun onCreate() {
        super.onCreate()
        sessions = SessionRepository(SessionStore(File(filesDir, "sessions")))
        watch = WatchLink(this, sessions)
        watch.start()
    }
}
