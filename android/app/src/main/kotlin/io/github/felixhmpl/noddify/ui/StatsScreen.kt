package io.github.felixhmpl.noddify.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.felixhmpl.noddify.WatchLink
import io.github.felixhmpl.noddify.core.Session
import io.github.felixhmpl.noddify.core.Stats
import io.github.felixhmpl.noddify.core.StatsRange
import io.github.felixhmpl.noddify.core.ThresholdChange
import java.time.LocalDate
import java.time.ZoneId

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(
    sessions: List<Session>,
    watch: WatchLink.State,
    contentPadding: PaddingValues,
    onLoadDemo: (() -> Unit)?,
) {
    var range by rememberSaveable { mutableStateOf(StatsRange.WEEK) }
    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val overview = remember(sessions, range, today) { Stats.overview(sessions, range, today, zone) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text("Noddify", fontSize = 26.sp, fontWeight = FontWeight.Bold)
            WatchStatusChip(watch)
        }
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            StatsRange.entries.forEachIndexed { i, option ->
                SegmentedButton(
                    selected = option == range,
                    onClick = { range = option },
                    shape = SegmentedButtonDefaults.itemShape(i, StatsRange.entries.size),
                    label = { Text(rangeLabel(option)) },
                )
            }
        }

        if (sessions.isEmpty()) {
            EmptyState(onLoadDemo)
            return@Column
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatTile("Sessions", "${overview.sessions}", Format.duration(overview.totalSeconds) + " total", Modifier.weight(1f))
            val change = overview.alertsPerHourChange
            StatTile(
                "Alerts per hour",
                overview.alertsPerHour?.let(Format::decimal) ?: "–",
                change?.let { Format.signedDecimal(it) + " vs before" },
                Modifier.weight(1f),
                noteColor = when {
                    change == null || change == 0.0 -> Color.Unspecified
                    change < 0 -> Color(0xFF15803D)
                    else -> NoddifyColors.Unanswered
                },
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatTile("Alerts you confirmed", overview.confirmedShare?.let(Format::percent) ?: "–", "answered “yes”", Modifier.weight(1f))
            StatTile("Naps logged", "${overview.naps}", "${overview.napMinutes} min in total", Modifier.weight(1f))
        }

        Panel {
            PanelTitle("Alerts per hour", "per day")
            AlertsPerDayChart(overview.days)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Caption(overview.days.firstOrNull()?.date?.let(Format::shortDay) ?: "")
                Caption("Gray: no session")
                Caption("Today")
            }
        }

        Panel {
            PanelTitle("How you answered alerts")
            AnswersBar(overview.confirmed, overview.falseAlarms, overview.unanswered)
            Row(Modifier.fillMaxWidth()) {
                AnswerCount("Yes, dozing", overview.confirmed, MaterialTheme.colorScheme.primary, Modifier.weight(1f))
                AnswerCount("No", overview.falseAlarms, NoddifyColors.FalseAlarm, Modifier.weight(1f))
                AnswerCount("Unanswered", overview.unanswered, NoddifyColors.Unanswered, Modifier.weight(1f))
            }
        }

        if (overview.baselineHr.isNotEmpty()) {
            Panel {
                PanelTitle("Resting heart rate baseline", "${overview.baselineHr.last().hr.toInt()} bpm")
                BaselineChart(overview.baselineHr)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Caption("${overview.baselineHr.first().hr.toInt()} bpm first")
                    Caption("${overview.baselineHr.last().hr.toInt()} bpm latest")
                }
            }
        }

        Panel {
            PanelTitle("What Noddify has learned")
            ThresholdRow("Stillness before alert", overview.stillThreshold) { "${it.toInt()} s" }
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            ThresholdRow("Heart rate drop", overview.hrDropThreshold) { "${Format.decimal(it)} bpm" }
        }
    }
}

private fun rangeLabel(range: StatsRange) = when (range) {
    StatsRange.WEEK -> "7 days"
    StatsRange.MONTH -> "30 days"
    StatsRange.ALL -> "All"
}

@Composable
private fun EmptyState(onLoadDemo: (() -> Unit)?) {
    Panel {
        PanelTitle("No sessions yet")
        Text(
            "Save a session in Noddify on your watch. It comes over through Garmin Connect, so keep the Garmin Connect app installed and the phone nearby.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (onLoadDemo != null) {
            TextButton(onClick = onLoadDemo) { Text("Load demo sessions") }
        }
    }
}

@Composable
private fun Caption(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun AnswerCount(label: String, count: Int, color: Color, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        LegendItem(color, label)
        Text("$count", fontSize = 18.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun ThresholdRow(label: String, change: ThresholdChange?, format: (Double) -> String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            if (change != null) Caption("started at ${format(change.first)}")
        }
        Text(change?.let { format(it.last) } ?: "–", fontSize = 18.sp, fontWeight = FontWeight.Bold)
    }
}
