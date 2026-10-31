package io.github.felixhmpl.noddify.ui

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/** Text formats shared by the screens. */
object Format {

    private val time = DateTimeFormatter.ofPattern("HH:mm")
    private val day = DateTimeFormatter.ofPattern("EEE d MMM", Locale.ENGLISH)
    private val shortDay = DateTimeFormatter.ofPattern("d MMM", Locale.ENGLISH)

    /** "1 h 07 min", "47 min" or "40 s". */
    fun duration(seconds: Long): String {
        val minutes = seconds / 60
        return when {
            minutes >= 60 -> "${minutes / 60} h %02d min".format(minutes % 60)
            minutes > 0 -> "$minutes min"
            else -> "$seconds s"
        }
    }

    fun time(epochSeconds: Long, zone: ZoneId): String = time.format(Instant.ofEpochSecond(epochSeconds).atZone(zone))

    /** "Today, Tue 28 Oct" for today, else "Mon 27 Oct". */
    fun day(date: LocalDate, today: LocalDate): String =
        if (date == today) "Today, ${day.format(date)}" else day.format(date)

    fun shortDay(date: LocalDate): String = shortDay.format(date)

    fun decimal(value: Double): String = String.format(Locale.ENGLISH, "%.1f", value)

    /** "+0.3" or "−0.4". */
    fun signedDecimal(value: Double): String = (if (value < 0) "−" else "+") + decimal(abs(value))

    fun percent(share: Double): String = "${(share * 100).roundToInt()}%"

    fun plural(count: Int, one: String, many: String = one + "s") = "$count ${if (count == 1) one else many}"
}
