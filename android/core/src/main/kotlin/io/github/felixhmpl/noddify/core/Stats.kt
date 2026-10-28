package io.github.felixhmpl.noddify.core

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** The time range the stats screen shows. ALL has no day limit. */
enum class StatsRange(val days: Int?) { WEEK(7), MONTH(30), ALL(null) }

data class DayValue(val date: LocalDate, val alertsPerHour: Double?)

data class BaselinePoint(val sessionStart: Long, val hr: Double)

/** A learned threshold at the first and the last session of the range. */
data class ThresholdChange(val first: Double, val last: Double)

data class Overview(
    val sessions: Int,
    val totalSeconds: Long,
    val alerts: Int,
    /** Alerts per monitored hour, or null without monitored time. */
    val alertsPerHour: Double?,
    /** Change of [alertsPerHour] against the same-length range before, when both exist. */
    val alertsPerHourChange: Double?,
    val confirmed: Int,
    val falseAlarms: Int,
    val unanswered: Int,
    val naps: Int,
    val napMinutes: Int,
    /** Alerts per hour for each day of the range, oldest first; null on days without a session. */
    val days: List<DayValue>,
    /** Baseline heart rate of each session in the range, oldest first. */
    val baselineHr: List<BaselinePoint>,
    val stillThreshold: ThresholdChange?,
    val hrDropThreshold: ThresholdChange?,
) {
    /** Share of answered-or-not alerts that the wearer confirmed, or null without any. */
    val confirmedShare: Double?
        get() = (confirmed + falseAlarms + unanswered).let { total -> if (total == 0) null else confirmed.toDouble() / total }
}

object Stats {

    /** At most this many days in the per-day chart; ALL shows the most recent ones. */
    const val MAX_CHART_DAYS = 60

    fun overview(sessions: List<Session>, range: StatsRange, today: LocalDate, zone: ZoneId): Overview {
        val firstDay = range.days?.let { today.minusDays(it - 1L) }
            ?: sessions.minOfOrNull { dateOf(it, zone) } ?: today
        val inRange = sessions.filter { dateOf(it, zone) in firstDay..today }.sortedBy { it.start }

        val previous = range.days?.let { days ->
            val previousFirst = firstDay.minusDays(days.toLong())
            sessions.filter { dateOf(it, zone) >= previousFirst && dateOf(it, zone) < firstDay }
        }
        val rate = alertsPerHour(inRange)
        val previousRate = previous?.let(::alertsPerHour)
        val alerts = inRange.flatMap { it.alerts() }

        val chartStart = maxOf(firstDay, today.minusDays(MAX_CHART_DAYS - 1L))
        val days = generateSequence(chartStart) { it.plusDays(1) }.takeWhile { it <= today }.map { day ->
            DayValue(day, alertsPerHour(inRange.filter { dateOf(it, zone) == day }))
        }.toList()

        return Overview(
            sessions = inRange.size,
            totalSeconds = inRange.sumOf { it.durationSeconds.toLong() },
            alerts = alerts.size,
            alertsPerHour = rate,
            alertsPerHourChange = if (rate != null && previousRate != null) rate - previousRate else null,
            confirmed = alerts.count { it.outcome == AlertOutcome.CONFIRMED },
            falseAlarms = alerts.count { it.outcome == AlertOutcome.FALSE_ALARM },
            unanswered = alerts.count { it.outcome == AlertOutcome.UNANSWERED },
            naps = inRange.sumOf { it.count(EventType.NAP) },
            napMinutes = inRange.sumOf { session -> session.events.sumOf { it.napMinutes ?: 0 } },
            days = days,
            baselineHr = inRange.mapNotNull { s -> s.baselineHr?.let { BaselinePoint(s.start, it) } },
            stillThreshold = change(inRange.mapNotNull { it.stillThreshold }),
            hrDropThreshold = change(inRange.mapNotNull { it.hrDropThreshold }),
        )
    }

    fun dateOf(session: Session, zone: ZoneId): LocalDate = Instant.ofEpochSecond(session.start).atZone(zone).toLocalDate()

    private fun alertsPerHour(sessions: List<Session>): Double? {
        val seconds = sessions.sumOf { it.seconds }
        if (sessions.isEmpty() || seconds == 0) return null
        return sessions.sumOf { it.count(EventType.ALERT) } * 3600.0 / seconds
    }

    private fun change(values: List<Double>): ThresholdChange? =
        if (values.isEmpty()) null else ThresholdChange(values.first(), values.last())
}
