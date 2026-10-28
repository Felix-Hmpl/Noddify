package io.github.felixhmpl.noddify

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.felixhmpl.noddify.core.DemoSessions
import io.github.felixhmpl.noddify.ui.NoddifyTheme
import io.github.felixhmpl.noddify.ui.SessionDetailScreen
import io.github.felixhmpl.noddify.ui.SessionsScreen
import io.github.felixhmpl.noddify.ui.StatsIcon
import io.github.felixhmpl.noddify.ui.StatsScreen
import java.time.LocalDate
import java.time.ZoneId

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as NoddifyApplication
        setContent {
            NoddifyTheme { NoddifyScreens(app) }
        }
    }
}

private enum class Tab { STATS, SESSIONS }

@Composable
private fun NoddifyScreens(app: NoddifyApplication) {
    val sessions by app.sessions.sessions.collectAsStateWithLifecycle()
    val watch by app.watch.state.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(Tab.STATS) }
    var openId by rememberSaveable { mutableStateOf<Long?>(null) }

    val open = sessions.firstOrNull { it.id == openId }
    if (open != null) {
        BackHandler { openId = null }
        SessionDetailScreen(open, onBack = { openId = null })
        return
    }

    // Debug builds can fill the app with made-up sessions, to try it without a watch.
    val loadDemo: (() -> Unit)? = if (BuildConfig.DEBUG) {
        { app.sessions.addInBackground(DemoSessions.create(LocalDate.now(), ZoneId.systemDefault())) }
    } else {
        null
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
                NavigationBarItem(
                    selected = tab == Tab.STATS,
                    onClick = { tab = Tab.STATS },
                    icon = { Icon(StatsIcon, contentDescription = null) },
                    label = { Text("Stats") },
                )
                NavigationBarItem(
                    selected = tab == Tab.SESSIONS,
                    onClick = { tab = Tab.SESSIONS },
                    icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null) },
                    label = { Text("Sessions") },
                )
            }
        },
    ) { padding ->
        when (tab) {
            Tab.STATS -> StatsScreen(sessions, watch, padding, loadDemo)
            Tab.SESSIONS -> SessionsScreen(sessions, padding) { openId = it.id }
        }
    }
}
