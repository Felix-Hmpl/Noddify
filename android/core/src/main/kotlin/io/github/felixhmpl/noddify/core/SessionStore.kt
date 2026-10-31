package io.github.felixhmpl.noddify.core

import kotlinx.serialization.json.Json
import java.io.File

/**
 * Keeps each session as `<id>.json` in [directory]. A detailed timeline fetched later can sit
 * beside it under the same id without changing the summary file.
 */
class SessionStore(private val directory: File) {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }

    /** Saves the session. Returns false if a session with its id was already stored. */
    fun save(session: Session): Boolean {
        directory.mkdirs()
        val file = fileOf(session.id)
        if (file.exists()) return false
        val temp = File(directory, "${session.id}.json.tmp")
        temp.writeText(json.encodeToString(Session.serializer(), session))
        return temp.renameTo(file)
    }

    /** All stored sessions, newest first. Files that can't be read are skipped. */
    fun loadAll(): List<Session> =
        directory.listFiles { file -> file.name.endsWith(".json") }
            .orEmpty()
            .mapNotNull { file -> runCatching { json.decodeFromString(Session.serializer(), file.readText()) }.getOrNull() }
            .sortedByDescending { it.start }

    fun deleteAll() {
        directory.listFiles { file -> file.name.endsWith(".json") }.orEmpty().forEach { it.delete() }
    }

    private fun fileOf(id: Long) = File(directory, "$id.json")
}
