package io.github.felixhmpl.noddify.core

/**
 * Reads the session message the watch transmits (source/phone/SessionMessage.mc). The
 * Connect IQ SDK hands it over as maps, lists, strings and boxed numbers.
 */
object SessionMessageParser {

    const val TYPE = "session"

    /** The newest message version this app understands. */
    const val VERSION = 1

    /** The session in [message], or null if it isn't a session message this app can read. */
    fun parse(message: Any?): Session? {
        val map = message as? Map<*, *> ?: return null
        if (map["type"] != TYPE) return null
        val version = map.int("v") ?: return null
        if (version > VERSION) return null
        val id = map.long("id") ?: return null
        val params = map["params"] as? Map<*, *>
        return Session(
            id = id,
            formatVersion = version,
            start = map.long("start") ?: id,
            end = map.long("end") ?: id,
            seconds = map.int("seconds") ?: 0,
            calibratedAt = map.int("calibrated"),
            baselineHr = map.double("baselineHr"),
            baselineHrv = map.double("baselineHrv"),
            stillThreshold = params?.double("stillSeconds"),
            hrDropThreshold = params?.double("hrDrop"),
            pauses = (map["pauses"] as? List<*>).orEmpty().mapNotNull(::parsePause),
            events = (map["events"] as? List<*>).orEmpty().mapNotNull(::parseEvent),
        )
    }

    private fun parsePause(value: Any?): Pause? {
        val pair = value as? List<*> ?: return null
        val at = (pair.getOrNull(0) as? Number)?.toInt() ?: return null
        val seconds = (pair.getOrNull(1) as? Number)?.toInt() ?: return null
        return Pause(at, seconds)
    }

    private fun parseEvent(value: Any?): Event? {
        val map = value as? Map<*, *> ?: return null
        val type = map.int("c")?.let(EventType::ofCode) ?: return null
        return Event(
            second = map.int("s") ?: return null,
            type = type,
            stillSeconds = map.int("still"),
            hrDrop = map.double("drop"),
            napMinutes = map.int("min"),
        )
    }

    private fun Map<*, *>.int(key: String) = (this[key] as? Number)?.toInt()
    private fun Map<*, *>.long(key: String) = (this[key] as? Number)?.toLong()
    private fun Map<*, *>.double(key: String) = (this[key] as? Number)?.toDouble()
}
