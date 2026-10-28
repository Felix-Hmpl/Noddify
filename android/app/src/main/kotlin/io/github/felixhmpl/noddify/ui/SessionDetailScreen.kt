package io.github.felixhmpl.noddify.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.felixhmpl.noddify.core.Alert
import io.github.felixhmpl.noddify.core.AlertOutcome
import io.github.felixhmpl.noddify.core.EventType
import io.github.felixhmpl.noddify.core.Session
import io.github.felixhmpl.noddify.core.Stats
import io.github.felixhmpl.noddify.core.TimelineBuilder
import java.time.LocalDate
import java.time.ZoneId

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionDetailScreen(session: Session, onBack: () -> Unit) {
    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val alerts = remember(session) { session.alerts() }
    val timeline = remember(session) { TimelineBuilder.build(session) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(Format.day(Stats.dateOf(session, zone), today), fontWeight = FontWeight.Bold)
                        Text(
                            "${Format.time(session.start, zone)} – ${Format.time(session.end, zone)} · ${Format.duration(session.durationSeconds.toLong())}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back to sessions") }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(padding).padding(horizontal = 16.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val napMinutes = session.events.filter { it.type == EventType.NAP }.sumOf { it.napMinutes ?: 0 }
                SummaryTile("${alerts.size}", "alerts", Modifier.weight(1f))
                SummaryTile("${alerts.count { it.outcome == AlertOutcome.CONFIRMED }}", "yes", Modifier.weight(1f))
                SummaryTile("${alerts.count { it.outcome == AlertOutcome.FALSE_ALARM }}", "no", Modifier.weight(1f))
                SummaryTile("$napMinutes′", "nap", Modifier.weight(1f))
            }

            Panel {
                Row(Modifier.fillMaxWidth()) {
                    Figure("Baseline HR", session.baselineHr?.let { "${it.toInt()} bpm" }, Modifier.weight(1f))
                    Figure("Baseline HRV", session.baselineHrv?.let { "${it.toInt()} ms" }, Modifier.weight(1f))
                    Figure(
                        "Thresholds",
                        listOfNotNull(session.stillThreshold?.let { "${it.toInt()} s" }, session.hrDropThreshold?.let(Format::decimal))
                            .joinToString(" · ").ifEmpty { null },
                        Modifier.weight(1f),
                    )
                }
            }

            Panel {
                PanelTitle("Session timeline")
                TimelineBar(timeline)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Caption(Format.time(session.start, zone))
                    Caption(Format.time(session.start + timeline.durationSeconds / 2, zone))
                    Caption(Format.time(session.start + timeline.durationSeconds, zone))
                }
                TimelineLegend()
            }

            Panel {
                PanelTitle("What happened")
                Column { happenings(session, alerts).forEach { EventRow(it, session.start, zone) } }
            }

            DetailsPlaceholder()
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TimelineLegend() {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        LegendItem(NoddifyColors.Awake, "Awake")
        LegendItem(NoddifyColors.Drowsy, "Drowsy or asleep")
        LegendItem(NoddifyColors.Nap, "Logged nap")
        LegendItem(NoddifyColors.Inactive, "Calibration or pause")
        LineLegend(dotted = false, "Confirmed alert")
        LineLegend(dotted = true, "False alarm (answered no)")
    }
}

@Composable
private fun LineLegend(dotted: Boolean, label: String) {
    val color = MaterialTheme.colorScheme.onSurface
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Column(Modifier.width(2.dp), verticalArrangement = Arrangement.spacedBy(if (dotted) 2.dp else 0.dp)) {
            repeat(if (dotted) 4 else 1) {
                Box(Modifier.width(2.dp).height(if (dotted) 2.dp else 14.dp).background(color))
            }
        }
        Text(label, style = MaterialTheme.typography.bodySmall)
    }
}

/** One line of "What happened". */
private data class Happening(val offset: Int, val kind: Kind, val title: String, val detail: String?) {
    enum class Kind { PLAIN, ALERT, NAP }
}

private fun happenings(session: Session, alerts: List<Alert>): List<Happening> {
    val list = mutableListOf(Happening(0, Happening.Kind.PLAIN, "Session started", null))
    session.calibratedAt?.let { list += Happening(session.wallOffset(it), Happening.Kind.PLAIN, "Calibrated", null) }
    alerts.forEach { alert ->
        val answer = when (alert.outcome) {
            AlertOutcome.CONFIRMED -> "you answered yes"
            AlertOutcome.FALSE_ALARM -> "you answered no"
            AlertOutcome.UNANSWERED -> "no reaction"
            AlertOutcome.OPEN -> "not answered"
        }
        val detail = listOfNotNull(
            alert.stillSeconds?.let { "Still for ${Format.duration(it.toLong())}" },
            alert.hrDrop?.let { "HR ${Format.decimal(it)} bpm below baseline" },
        ).joinToString(" · ").ifEmpty { null }
        list += Happening(session.wallOffset(alert.second), Happening.Kind.ALERT, "Alert · $answer", detail)
    }
    session.events.filter { it.type == EventType.NAP }.forEach { nap ->
        list += Happening(session.wallOffset(nap.second), Happening.Kind.NAP, "Nap logged · ${nap.napMinutes ?: 0} min", null)
    }
    session.pauses.fold(0) { before, pause ->
        list += Happening(pause.atSecond + before, Happening.Kind.PLAIN, "Paused for ${Format.duration(pause.seconds.toLong())}", null)
        before + pause.seconds
    }
    list += Happening(session.durationSeconds, Happening.Kind.PLAIN, "Session saved", null)
    return list.sortedBy { it.offset }
}

@Composable
private fun EventRow(happening: Happening, sessionStart: Long, zone: ZoneId) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            Format.time(sessionStart + happening.offset, zone),
            Modifier.width(48.dp).padding(top = 2.dp),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Column(Modifier.width(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            val dot = when (happening.kind) {
                Happening.Kind.ALERT -> MaterialTheme.colorScheme.primary
                Happening.Kind.NAP -> NoddifyColors.Nap
                Happening.Kind.PLAIN -> NoddifyColors.Inactive
            }
            Box(Modifier.padding(top = 3.dp).size(12.dp).clip(CircleShape).background(dot))
        }
        Column(Modifier.padding(bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(happening.title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
            happening.detail?.let { Caption(it) }
        }
    }
}

@Composable
private fun SummaryTile(value: String, label: String, modifier: Modifier) {
    Panel(modifier) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Caption(label)
        }
    }
}

@Composable
private fun Figure(label: String, value: String?, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Caption(label)
        Text(value ?: "–", style = MaterialTheme.typography.titleMedium)
    }
}

/** Where the per-second heart rate and movement chart goes once the watch can send it. */
@Composable
private fun DetailsPlaceholder() {
    Panel(Modifier) {
        PanelTitle("Heart rate and movement")
        Caption("The second-by-second timeline isn't sent yet. A later version can fetch it from the watch and draw it here, with the events marked.")
        OutlinedButton(onClick = {}, enabled = false, border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)) {
            Text("Get details · coming later")
        }
    }
}

@Composable
private fun Caption(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}
