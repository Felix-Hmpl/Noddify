package io.github.felixhmpl.noddify.core

import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import kotlin.random.Random

/** Made-up sessions for trying the app without a watch (debug builds only). */
object DemoSessions {

    fun create(today: LocalDate, zone: ZoneId, days: Int = 21): List<Session> {
        val random = Random(42)
        val sessions = mutableListOf<Session>()
        var still = 120.0
        var hrDrop = 6.0
        var baseline = 60.0
        for (dayIndex in days - 1 downTo 0) {
            if (random.nextInt(4) == 0) continue
            val date = today.minusDays(dayIndex.toLong())
            val startTime = LocalTime.of(9 + random.nextInt(10), random.nextInt(60))
            val start = date.atTime(startTime).atZone(zone).toEpochSecond()
            val seconds = 1800 + random.nextInt(4200)
            val calibrated = 300
            val events = mutableListOf<Event>()
            var second = calibrated + 300 + random.nextInt(600)
            while (second < seconds - 120) {
                val stillSeconds = still.toInt() + random.nextInt(60)
                events += Event(second, EventType.ALERT, stillSeconds = stillSeconds, hrDrop = hrDrop + random.nextDouble(3.0))
                when (random.nextInt(10)) {
                    in 0..5 -> {
                        events += Event(second + 20, EventType.ANSWER_YES)
                        still = (still - 4).coerceAtLeast(60.0)
                        hrDrop = (hrDrop - 0.25).coerceAtLeast(2.0)
                    }
                    in 6..8 -> {
                        events += Event(second + 15, EventType.ANSWER_NO)
                        still = (still + 15).coerceAtMost(600.0)
                        hrDrop = (hrDrop + 1).coerceAtMost(15.0)
                    }
                    else -> events += Event(second + 60, EventType.UNANSWERED)
                }
                if (random.nextInt(5) == 0) {
                    events += Event(second + 600, EventType.NAP, napMinutes = 5 + random.nextInt(15))
                    second += 600
                }
                second += 600 + random.nextInt(1500)
            }
            val pauses = if (random.nextInt(3) == 0) listOf(Pause(seconds / 2, 120 + random.nextInt(300))) else emptyList()
            baseline = (baseline + random.nextDouble(-1.5, 1.2)).coerceIn(50.0, 70.0)
            sessions += Session(
                id = start,
                formatVersion = SessionMessageParser.VERSION,
                start = start,
                end = start + seconds + pauses.sumOf { it.seconds },
                seconds = seconds,
                calibratedAt = calibrated,
                baselineHr = baseline,
                baselineHrv = 40.0 + random.nextInt(20),
                stillThreshold = still,
                hrDropThreshold = hrDrop,
                pauses = pauses,
                events = events.filter { it.second < seconds },
            )
        }
        return sessions
    }
}
