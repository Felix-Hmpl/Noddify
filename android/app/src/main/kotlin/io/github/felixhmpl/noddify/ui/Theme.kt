package io.github.felixhmpl.noddify.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import io.github.felixhmpl.noddify.core.Band

/** Colors of the session timeline and charts, the same in light and dark mode. */
object NoddifyColors {
    val Awake = Color(0xFF16A34A)
    val Drowsy = Color(0xFFDC2626)
    val Nap = Color(0xFFF59E0B)
    val Inactive = Color(0xFFC9C8D3)
    val FalseAlarm = Color(0xFFA5A4BC)
    val Unanswered = Color(0xFFC2410C)

    fun of(band: Band) = when (band) {
        Band.AWAKE -> Awake
        Band.DROWSY -> Drowsy
        Band.NAP -> Nap
        Band.INACTIVE -> Inactive
    }
}

private val Light = lightColorScheme(
    primary = Color(0xFF4F46E5),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFE7E6FB),
    onPrimaryContainer = Color(0xFF312E81),
    secondaryContainer = Color(0xFFE7E6FB),
    onSecondaryContainer = Color(0xFF312E81),
    background = Color(0xFFF6F6F9),
    surface = Color(0xFFF6F6F9),
    surfaceContainerLowest = Color.White,
    surfaceContainer = Color.White,
    onSurfaceVariant = Color(0xFF5B5B68),
    outlineVariant = Color(0xFFDCDBE4),
)

private val Dark = darkColorScheme(
    primary = Color(0xFFA5B4FC),
    onPrimary = Color(0xFF1E1B4B),
    primaryContainer = Color(0xFF312E81),
    onPrimaryContainer = Color(0xFFE7E6FB),
    secondaryContainer = Color(0xFF312E81),
    onSecondaryContainer = Color(0xFFE7E6FB),
)

@Composable
fun NoddifyTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Dark else Light, content = content)
}
