package io.github.felixhmpl.noddify.core

/** What a stretch of the session timeline shows. */
enum class Band {
    /** Calibrating, or paused. */
    INACTIVE,
    AWAKE,
    /** Drowsy or asleep: the stillness before an alert the wearer confirmed or didn't answer. */
    DROWSY,
    /** A nap the wearer logged. */
    NAP,
}

enum class MarkerKind {
    /** An alert the wearer confirmed with "yes". */
    CONFIRMED_ALERT,
    /** An alert the wearer answered "no". */
    FALSE_ALARM,
}

/** Offsets are seconds since the session's start. */
data class Segment(val start: Int, val end: Int, val band: Band)

data class Marker(val offset: Int, val kind: MarkerKind)

data class Timeline(val durationSeconds: Int, val segments: List<Segment>, val markers: List<Marker>)

/**
 * The session from start to end as colored stretches plus alert markers. Where stretches
 * overlap, inactive wins over drowsy, drowsy over nap and nap over awake.
 */
object TimelineBuilder {

    fun build(session: Session): Timeline {
        val duration = maxOf(session.durationSeconds, session.wallOffset(session.seconds))
        if (duration == 0) return Timeline(0, emptyList(), emptyList())
        val bands = Array(duration) { Band.AWAKE }
        fun paint(from: Int, to: Int, band: Band) {
            for (i in from.coerceAtLeast(0) until to.coerceAtMost(duration)) bands[i] = band
        }

        session.events.filter { it.type == EventType.NAP }.forEach { nap ->
            val end = session.wallOffset(nap.second)
            paint(end - (nap.napMinutes ?: 0) * 60, end, Band.NAP)
        }

        val alerts = session.alerts()
        alerts.filter { it.outcome == AlertOutcome.CONFIRMED || it.outcome == AlertOutcome.UNANSWERED }.forEach { alert ->
            val at = session.wallOffset(alert.second)
            val end = session.wallOffset(alert.outcomeSecond ?: alert.second)
            paint(at - (alert.stillSeconds ?: 0), maxOf(end, at + 1), Band.DROWSY)
        }

        val calibratedAt = session.calibratedAt
        paint(0, if (calibratedAt != null) session.wallOffset(calibratedAt) else duration, Band.INACTIVE)
        var pausedBefore = 0
        session.pauses.forEach { pause ->
            val start = pause.atSecond + pausedBefore
            paint(start, start + pause.seconds, Band.INACTIVE)
            pausedBefore += pause.seconds
        }

        val markers = alerts.mapNotNull { alert ->
            val kind = when (alert.outcome) {
                AlertOutcome.CONFIRMED -> MarkerKind.CONFIRMED_ALERT
                AlertOutcome.FALSE_ALARM -> MarkerKind.FALSE_ALARM
                else -> null
            }
            kind?.let { Marker(session.wallOffset(alert.second), it) }
        }
        return Timeline(duration, runs(bands), markers)
    }

    private fun runs(bands: Array<Band>): List<Segment> {
        val segments = mutableListOf<Segment>()
        var start = 0
        for (i in 1..bands.size) {
            if (i == bands.size || bands[i] != bands[start]) {
                segments += Segment(start, i, bands[start])
                start = i
            }
        }
        return segments
    }
}
