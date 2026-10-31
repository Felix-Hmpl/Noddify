package io.github.felixhmpl.noddify.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.felixhmpl.noddify.WatchLink

/** A white card with the screens' standard padding. */
@Composable
fun Panel(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLowest),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
    }
}

@Composable
fun PanelTitle(text: String, trailing: String? = null) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Bottom) {
        Text(text, style = MaterialTheme.typography.titleMedium)
        if (trailing != null) Text(trailing, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun StatTile(label: String, value: String, note: String?, modifier: Modifier = Modifier, noteColor: Color = Color.Unspecified) {
    Panel(modifier) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            if (note != null) {
                Text(
                    note,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (noteColor == Color.Unspecified) MaterialTheme.colorScheme.onSurfaceVariant else noteColor,
                )
            }
        }
    }
}

@Composable
fun Tag(text: String, container: Color, content: Color) {
    Surface(shape = RoundedCornerShape(50), color = container, contentColor = content) {
        Text(text, Modifier.padding(horizontal = 10.dp, vertical = 4.dp), style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
fun LegendItem(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.size(12.dp).clip(RoundedCornerShape(2.dp)).background(color))
        Text(label, style = MaterialTheme.typography.bodySmall)
    }
}

/** "Venu 3S connected" and the like, at the top of the stats screen. */
@Composable
fun WatchStatusChip(state: WatchLink.State) {
    val (dot, text) = when (state.status) {
        WatchLink.Status.CONNECTED -> NoddifyColors.Awake to "${state.watchName ?: "Watch"} connected"
        WatchLink.Status.NOT_CONNECTED -> NoddifyColors.Inactive to "${state.watchName ?: "Watch"} not connected"
        WatchLink.Status.NO_WATCH -> NoddifyColors.Inactive to "No watch paired"
        WatchLink.Status.NO_GARMIN_CONNECT -> NoddifyColors.Unanswered to "Garmin Connect needed"
        WatchLink.Status.STARTING -> NoddifyColors.Inactive to "Looking for the watch"
    }
    Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.primaryContainer, contentColor = MaterialTheme.colorScheme.onPrimaryContainer) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.size(8.dp).clip(CircleShape).background(dot))
            Text(text, style = MaterialTheme.typography.labelMedium)
        }
    }
}

/** Bar chart icon for the Stats tab. */
val StatsIcon: ImageVector = ImageVector.Builder("Stats", 24.dp, 24.dp, 24f, 24f).apply {
    path(fill = SolidColor(Color.Black)) {
        moveTo(4f, 11f); horizontalLineTo(7f); verticalLineTo(20f); horizontalLineTo(4f); close()
        moveTo(10.5f, 4f); horizontalLineTo(13.5f); verticalLineTo(20f); horizontalLineTo(10.5f); close()
        moveTo(17f, 13f); horizontalLineTo(20f); verticalLineTo(20f); horizontalLineTo(17f); close()
    }
}.build()
