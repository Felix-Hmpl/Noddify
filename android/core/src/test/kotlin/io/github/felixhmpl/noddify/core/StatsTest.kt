package io.github.felixhmpl.noddify.core

import java.nio.file.Files
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class StatsTest {

    private val zone = ZoneOffset.UTC
    private val today = LocalDate.of(2026, 10, 28)

    private fun sessionOn(date: LocalDate, hour: Int = 10, seconds: Int = 3_600, events: List<Event> = emptyList(), still: Double? = null, hr: Double? = null): Session {
        val start = date.atTime(hour, 0).toEpochSecond(zone)
        return Session(id = start, formatVersion = 1, start = start, end = start + seconds, seconds = seconds, events = events, stillThreshold = still, baselineHr = hr)
    }

    private val twoAlerts = listOf(
        Event(1_000, EventType.ALERT), Event(1_020, EventType.ANSWER_YES),
        Event(2_000, EventType.ALERT), Event(2_010, EventType.ANSWER_NO),
        Event(2_500, EventType.NAP, napMinutes = 10),
    )

    @Test
    fun weekCountsOnlyItsSessions() {
        val sessions = listOf(
            sessionOn(today, events = twoAlerts, still = 150.0, hr = 55.0),
            sessionOn(today.minusDays(6), events = twoAlerts.take(2), still = 180.0, hr = 58.0),
            sessionOn(today.minusDays(7), events = twoAlerts),
        )
        val overview = Stats.overview(sessions, StatsRange.WEEK, today, zone)
        assertEquals(2, overview.sessions)
        assertEquals(7_200, overview.totalSeconds)
        assertEquals(3, overview.alerts)
        assertEquals(1.5, overview.alertsPerHour)
        // The week before had one session with 2 alerts in an hour.
        assertEquals(-0.5, overview.alertsPerHourChange)
        assertEquals(2, overview.confirmed)
        assertEquals(1, overview.falseAlarms)
        assertEquals(2.0 / 3, overview.confirmedShare)
        assertEquals(1, overview.naps)
        assertEquals(10, overview.napMinutes)
        assertEquals(ThresholdChange(180.0, 150.0), overview.stillThreshold)
        assertEquals(listOf(58.0, 55.0), overview.baselineHr.map { it.hr })
        assertEquals(7, overview.days.size)
        assertEquals(1.0, overview.days.first().alertsPerHour)
        assertNull(overview.days[1].alertsPerHour)
        assertEquals(2.0, overview.days.last().alertsPerHour)
    }

    @Test
    fun allStartsAtTheFirstSessionWithoutAChange() {
        val sessions = listOf(sessionOn(today.minusDays(3)), sessionOn(today))
        val overview = Stats.overview(sessions, StatsRange.ALL, today, zone)
        assertEquals(4, overview.days.size)
        assertNull(overview.alertsPerHourChange)
        assertNull(overview.confirmedShare)
    }

    @Test
    fun emptyHistoryHasNoRates() {
        val overview = Stats.overview(emptyList(), StatsRange.MONTH, today, zone)
        assertEquals(0, overview.sessions)
        assertNull(overview.alertsPerHour)
        assertEquals(30, overview.days.size)
    }

    @Test
    fun storeKeepsEachSessionOnce() {
        val directory = Files.createTempDirectory("sessions").toFile()
        val store = SessionStore(directory)
        val first = sessionOn(today.minusDays(1), events = twoAlerts)
        assertTrue(store.save(first))
        assertFalse(store.save(first))
        store.save(sessionOn(today))
        assertEquals(listOf(today, today.minusDays(1)), store.loadAll().map { Stats.dateOf(it, zone) })
        assertEquals(first, store.loadAll().last())
        directory.deleteRecursively()
    }

    @Test
    fun demoSessionsProduceStats() {
        val sessions = DemoSessions.create(today, zone)
        assertTrue(sessions.isNotEmpty())
        val overview = Stats.overview(sessions, StatsRange.ALL, today, zone)
        assertTrue(overview.alerts > 0)
        sessions.forEach { TimelineBuilder.build(it) }
    }
}
