package io.github.felixhmpl.noddify.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.felixhmpl.noddify.core.AlertOutcome
import io.github.felixhmpl.noddify.core.EventType
import io.github.felixhmpl.noddify.core.Session
import io.github.felixhmpl.noddify.core.Stats
import java.time.LocalDate
import java.time.ZoneId

@Composable
fun SessionsScreen(sessions: List<Session>, contentPadding: PaddingValues, onOpen: (Session) -> Unit) {
    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val byDay = remember(sessions) { sessions.groupBy { Stats.dateOf(it, zone) } }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = 16.dp,
            end = 16.dp,
            top = contentPadding.calculateTopPadding() + 12.dp,
            bottom = contentPadding.calculateBottomPadding() + 16.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Sessions", fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Text(Format.plural(sessions.size, "session"), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (sessions.isEmpty()) {
            item {
                Text(
                    "Sessions you save on the watch show up here.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        byDay.forEach { (day, daySessions) ->
            item(key = day.toString()) {
                Text(
                    Format.day(day, today),
                    Modifier.padding(start = 4.dp, top = 8.dp),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            items(daySessions, key = { it.id }) { session -> SessionCard(session, zone) { onOpen(session) } }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SessionCard(session: Session, zone: ZoneId, onClick: () -> Unit) {
    val alerts = session.alerts()
    val yes = alerts.count { it.outcome == AlertOutcome.CONFIRMED }
    val no = alerts.count { it.outcome == AlertOutcome.FALSE_ALARM }
    val unanswered = alerts.count { it.outcome == AlertOutcome.UNANSWERED }
    val napMinutes = session.events.filter { it.type == EventType.NAP }.sumOf { it.napMinutes ?: 0 }

    Card(
        Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLowest),
    ) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("${Format.time(session.start, zone)} – ${Format.time(session.end, zone)}", style = MaterialTheme.typography.titleMedium)
                Text(Format.duration(session.durationSeconds.toLong()), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Tag(
                    if (alerts.isEmpty()) "No alerts" else Format.plural(alerts.size, "alert"),
                    MaterialTheme.colorScheme.primaryContainer,
                    MaterialTheme.colorScheme.onPrimaryContainer,
                )
                val answers = listOfNotNull(
                    if (yes > 0) "$yes yes" else null,
                    if (no > 0) "$no no" else null,
                    if (unanswered > 0) "$unanswered unanswered" else null,
                )
                if (answers.isNotEmpty()) {
                    Tag(answers.joinToString(" · "), MaterialTheme.colorScheme.surfaceVariant, MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (napMinutes > 0) Tag("Nap $napMinutes min", Color(0xFFFFEDD5), Color(0xFF9A3412))
            }
        }
    }
}
