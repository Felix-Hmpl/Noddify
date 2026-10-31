package io.github.felixhmpl.noddify.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import io.github.felixhmpl.noddify.core.BaselinePoint
import io.github.felixhmpl.noddify.core.DayValue
import io.github.felixhmpl.noddify.core.MarkerKind
import io.github.felixhmpl.noddify.core.Timeline

/** Alerts per hour for each day; days without a session get a thin gray stub. */
@Composable
fun AlertsPerDayChart(days: List<DayValue>, modifier: Modifier = Modifier) {
    val bar = MaterialTheme.colorScheme.primary
    val baseline = MaterialTheme.colorScheme.outlineVariant
    val max = days.mapNotNull { it.alertsPerHour }.maxOrNull()?.takeIf { it > 0 } ?: 1.0
    Canvas(modifier.fillMaxWidth().height(110.dp).semantics { contentDescription = "Alerts per hour for each day" }) {
        if (days.isEmpty()) return@Canvas
        val gap = if (days.size > 31) 1.dp.toPx() else 4.dp.toPx()
        val width = (size.width - gap * (days.size - 1)) / days.size
        days.forEachIndexed { i, day ->
            val x = i * (width + gap)
            val value = day.alertsPerHour
            if (value == null) {
                drawRect(baseline, Offset(x, size.height - 3.dp.toPx()), Size(width, 3.dp.toPx()))
            } else {
                val height = ((value / max) * (size.height - 4.dp.toPx())).toFloat().coerceAtLeast(2.dp.toPx())
                drawRoundRect(bar, Offset(x, size.height - height), Size(width, height), CornerRadius(3.dp.toPx()))
            }
        }
        drawLine(baseline, Offset(0f, size.height), Offset(size.width, size.height), 1.dp.toPx())
    }
}

/** The session baselines as a line, scaled to their own range. */
@Composable
fun BaselineChart(points: List<BaselinePoint>, modifier: Modifier = Modifier) {
    val line = MaterialTheme.colorScheme.primary
    val axis = MaterialTheme.colorScheme.outlineVariant
    Canvas(modifier.fillMaxWidth().height(90.dp).semantics { contentDescription = "Baseline heart rate per session" }) {
        val pad = 6.dp.toPx()
        drawLine(axis, Offset(0f, size.height - 1), Offset(size.width, size.height - 1), 1.dp.toPx())
        if (points.isEmpty()) return@Canvas
        val low = points.minOf { it.hr } - 1
        val high = points.maxOf { it.hr } + 1
        fun at(i: Int): Offset {
            val x = if (points.size == 1) size.width / 2 else i * (size.width - 2 * pad) / (points.size - 1) + pad
            val y = (pad + (high - points[i].hr) / (high - low) * (size.height - 2 * pad)).toFloat()
            return Offset(x, y)
        }
        val path = Path().apply {
            moveTo(at(0).x, at(0).y)
            for (i in 1 until points.size) lineTo(at(i).x, at(i).y)
        }
        drawPath(path, line, style = Stroke(2.5.dp.toPx(), join = StrokeJoin.Round))
        drawCircle(line, 4.dp.toPx(), at(points.size - 1))
    }
}

/** One bar split by how the alerts were answered. */
@Composable
fun AnswersBar(confirmed: Int, falseAlarms: Int, unanswered: Int, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().height(20.dp).clip(RoundedCornerShape(50)).semantics {
            contentDescription = "Answers: $confirmed yes, $falseAlarms no, $unanswered unanswered"
        },
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        if (confirmed + falseAlarms + unanswered == 0) {
            Box(Modifier.fillMaxWidth().fillMaxHeight().background(NoddifyColors.Inactive))
        }
        listOf(
            confirmed to MaterialTheme.colorScheme.primary,
            falseAlarms to NoddifyColors.FalseAlarm,
            unanswered to NoddifyColors.Unanswered,
        ).filter { it.first > 0 }.forEach { (count, color) ->
            Box(Modifier.weight(count.toFloat()).fillMaxHeight().background(color))
        }
    }
}

/**
 * The session from start to end: colored stretches (see NoddifyColors), a solid line for each
 * confirmed alert and a dotted line for each false alarm.
 */
@Composable
fun TimelineBar(timeline: Timeline, modifier: Modifier = Modifier) {
    val markerColor = MaterialTheme.colorScheme.onSurface
    Canvas(modifier.fillMaxWidth().height(40.dp).semantics { contentDescription = "Session timeline" }) {
        if (timeline.durationSeconds == 0) return@Canvas
        val top = 6.dp.toPx()
        val barHeight = size.height - 2 * top
        val perSecond = size.width / timeline.durationSeconds
        val outline = Path().apply {
            addRoundRect(RoundRect(0f, top, size.width, top + barHeight, CornerRadius(6.dp.toPx())))
        }
        clipPath(outline) {
            timeline.segments.forEach { segment ->
                drawRect(
                    NoddifyColors.of(segment.band),
                    Offset(segment.start * perSecond, top),
                    Size((segment.end - segment.start) * perSecond, barHeight),
                )
            }
        }
        timeline.markers.forEach { marker ->
            val x = (marker.offset * perSecond).coerceIn(1f, size.width - 1f)
            val dotted = marker.kind == MarkerKind.FALSE_ALARM
            drawLine(
                markerColor,
                Offset(x, 0f),
                Offset(x, size.height),
                strokeWidth = 2.dp.toPx(),
                pathEffect = if (dotted) PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 2.dp.toPx())) else null,
            )
        }
    }
}
