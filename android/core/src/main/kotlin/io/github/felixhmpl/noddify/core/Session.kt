package io.github.felixhmpl.noddify.core

import kotlinx.serialization.Serializable

/**
 * One Noddify session as the watch sent it (see source/phone/SessionMessage.mc).
 *
 * Times are Unix seconds. Session seconds count only while the session ran, so they skip
 * the [pauses]; [wallOffset] turns one into seconds since [start].
 */
@Serializable
data class Session(
    /** The session's id: its start time on the watch. */
    val id: Long,
    /** Version of the watch message the session came from. */
    val formatVersion: Int,
    val start: Long,
    val end: Long,
    /** Monitored session seconds, pauses excluded. */
    val seconds: Int,
    /** Session second when calibration finished, or null if it never did. */
    val calibratedAt: Int? = null,
    val baselineHr: Double? = null,
    val baselineHrv: Double? = null,
    /** Learned stillness threshold at the end of the session, in seconds. */
    val stillThreshold: Double? = null,
    /** Learned heart rate drop threshold at the end of the session, in bpm. */
    val hrDropThreshold: Double? = null,
    val pauses: List<Pause> = emptyList(),
    val events: List<Event> = emptyList(),
) {
    /** Wall-clock length from start to end, pauses included. */
    val durationSeconds: Int get() = (end - start).toInt().coerceAtLeast(0)

    fun count(type: EventType): Int = events.count { it.type == type }

    /** Seconds since [start] at the given session second. */
    fun wallOffset(sessionSecond: Int): Int =
        sessionSecond + pauses.filter { it.atSecond < sessionSecond }.sumOf { it.seconds }

    /** Every alert with the answer it got. */
    fun alerts(): List<Alert> {
        val alerts = mutableListOf<Alert>()
        for (event in events) {
            when (event.type) {
                EventType.ALERT -> alerts += Alert(event.second, event.stillSeconds, event.hrDrop)
                EventType.ANSWER_YES, EventType.ANSWER_NO, EventType.UNANSWERED -> {
                    val index = alerts.indexOfLast { it.outcome == AlertOutcome.OPEN }
                    if (index >= 0) {
                        alerts[index] = alerts[index].copy(outcome = outcomeOf(event.type), outcomeSecond = event.second)
                    }
                }
                EventType.NAP -> {}
            }
        }
        return alerts
    }

    private fun outcomeOf(type: EventType) = when (type) {
        EventType.ANSWER_YES -> AlertOutcome.CONFIRMED
        EventType.ANSWER_NO -> AlertOutcome.FALSE_ALARM
        else -> AlertOutcome.UNANSWERED
    }
}

/** The session was paused after [atSecond] for [seconds] of wall-clock time. */
@Serializable
data class Pause(val atSecond: Int, val seconds: Int)

@Serializable
data class Event(
    /** Session second the event happened in. */
    val second: Int,
    val type: EventType,
    /** Alerts: how long the wearer had been still. */
    val stillSeconds: Int? = null,
    /** Alerts: heart rate below baseline, in bpm. */
    val hrDrop: Double? = null,
    /** Naps: the length the wearer entered, in minutes. The nap ended when it was logged. */
    val napMinutes: Int? = null,
)

/** Event types with the codes the watch uses (source/recording/RecordEvent.mc). */
enum class EventType(val code: Int) {
    ALERT(1),
    ANSWER_YES(2),
    ANSWER_NO(3),
    UNANSWERED(4),
    NAP(5);

    companion object {
        fun ofCode(code: Int): EventType? = entries.firstOrNull { it.code == code }
    }
}

enum class AlertOutcome { OPEN, CONFIRMED, FALSE_ALARM, UNANSWERED }

data class Alert(
    val second: Int,
    val stillSeconds: Int?,
    val hrDrop: Double?,
    val outcome: AlertOutcome = AlertOutcome.OPEN,
    /** Session second of the answer, or of giving up when unanswered. */
    val outcomeSecond: Int? = null,
)
