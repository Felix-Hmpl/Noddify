package io.github.felixhmpl.noddify.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SessionMessageParserTest {

    // Shaped like the Connect IQ SDK delivers the watch's message: maps, lists and boxed numbers.
    private val message = hashMapOf<Any, Any>(
        "type" to "session",
        "v" to 1,
        "id" to 1_700_000_000,
        "start" to 1_700_000_000,
        "end" to 1_700_004_000,
        "seconds" to 3_600,
        "calibrated" to 300,
        "baselineHr" to 61.5f,
        "params" to hashMapOf("stillSeconds" to 150.0f, "hrDrop" to 5.25f),
        "pauses" to arrayListOf(arrayListOf(1_000, 400)),
        "events" to arrayListOf(
            hashMapOf("s" to 900, "c" to 1, "still" to 170, "drop" to 6.5f),
            hashMapOf("s" to 920, "c" to 2),
            hashMapOf("s" to 1_500, "c" to 5, "min" to 12),
            hashMapOf("s" to 1_600, "c" to 99),
        ),
    )

    @Test
    fun readsTheWatchMessage() {
        val session = SessionMessageParser.parse(message)!!
        assertEquals(1_700_000_000L, session.id)
        assertEquals(4_000, session.durationSeconds)
        assertEquals(3_600, session.seconds)
        assertEquals(300, session.calibratedAt)
        assertEquals(61.5, session.baselineHr)
        assertNull(session.baselineHrv)
        assertEquals(150.0, session.stillThreshold)
        assertEquals(5.25, session.hrDropThreshold)
        assertEquals(listOf(Pause(1_000, 400)), session.pauses)
        // The unknown event code is skipped.
        assertEquals(
            listOf(
                Event(900, EventType.ALERT, stillSeconds = 170, hrDrop = 6.5),
                Event(920, EventType.ANSWER_YES),
                Event(1_500, EventType.NAP, napMinutes = 12),
            ),
            session.events,
        )
    }

    @Test
    fun rejectsOtherMessagesAndNewerVersions() {
        assertNull(SessionMessageParser.parse("hello"))
        assertNull(SessionMessageParser.parse(hashMapOf("type" to "ack", "id" to 1)))
        assertNull(SessionMessageParser.parse(HashMap(message).apply { put("v", 2) }))
        assertNull(SessionMessageParser.parse(HashMap(message).apply { remove("id") }))
    }

    @Test
    fun pairsAlertsWithTheirAnswers() {
        val session = SessionMessageParser.parse(message)!!.copy(
            events = listOf(
                Event(100, EventType.ALERT),
                Event(110, EventType.ANSWER_NO),
                Event(500, EventType.ALERT),
                Event(560, EventType.UNANSWERED),
                Event(900, EventType.ALERT),
            ),
        )
        assertEquals(
            listOf(AlertOutcome.FALSE_ALARM, AlertOutcome.UNANSWERED, AlertOutcome.OPEN),
            session.alerts().map { it.outcome },
        )
        assertEquals(560, session.alerts()[1].outcomeSecond)
    }

    @Test
    fun wallOffsetSkipsPauses() {
        val session = SessionMessageParser.parse(message)!!
        assertEquals(900, session.wallOffset(900))
        // The pause after second 1000 lasted 400 s.
        assertEquals(1_000, session.wallOffset(1_000))
        assertEquals(1_401, session.wallOffset(1_001))
    }
}
