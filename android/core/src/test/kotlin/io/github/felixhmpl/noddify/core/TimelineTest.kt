package io.github.felixhmpl.noddify.core

import kotlin.test.Test
import kotlin.test.assertEquals

class TimelineTest {

    private fun session(events: List<Event>, pauses: List<Pause> = emptyList(), calibratedAt: Int? = 100) = Session(
        id = 0,
        formatVersion = 1,
        start = 0,
        end = 1_000L + pauses.sumOf { it.seconds },
        seconds = 1_000,
        calibratedAt = calibratedAt,
        pauses = pauses,
        events = events,
    )

    @Test
    fun calibrationIsInactiveThenAwake() {
        val timeline = TimelineBuilder.build(session(emptyList()))
        assertEquals(listOf(Segment(0, 100, Band.INACTIVE), Segment(100, 1_000, Band.AWAKE)), timeline.segments)
        assertEquals(emptyList(), timeline.markers)
    }

    @Test
    fun withoutCalibrationEverythingIsInactive() {
        val timeline = TimelineBuilder.build(session(emptyList(), calibratedAt = null))
        assertEquals(listOf(Segment(0, 1_000, Band.INACTIVE)), timeline.segments)
    }

    @Test
    fun confirmedAlertIsDrowsyFromStillnessUntilTheAnswer() {
        val timeline = TimelineBuilder.build(
            session(listOf(Event(400, EventType.ALERT, stillSeconds = 150), Event(420, EventType.ANSWER_YES))),
        )
        assertEquals(
            listOf(Segment(0, 100, Band.INACTIVE), Segment(100, 250, Band.AWAKE), Segment(250, 420, Band.DROWSY), Segment(420, 1_000, Band.AWAKE)),
            timeline.segments,
        )
        assertEquals(listOf(Marker(400, MarkerKind.CONFIRMED_ALERT)), timeline.markers)
    }

    @Test
    fun falseAlarmStaysAwakeWithADottedMarker() {
        val timeline = TimelineBuilder.build(
            session(listOf(Event(400, EventType.ALERT, stillSeconds = 150), Event(410, EventType.ANSWER_NO))),
        )
        assertEquals(listOf(Segment(0, 100, Band.INACTIVE), Segment(100, 1_000, Band.AWAKE)), timeline.segments)
        assertEquals(listOf(Marker(400, MarkerKind.FALSE_ALARM)), timeline.markers)
    }

    @Test
    fun napEndsWhenLoggedAndDrowsyWinsOverlaps() {
        val timeline = TimelineBuilder.build(
            session(
                listOf(
                    Event(700, EventType.ALERT, stillSeconds = 100),
                    Event(720, EventType.ANSWER_YES),
                    Event(800, EventType.NAP, napMinutes = 5),
                ),
            ),
        )
        // The nap covers 500-800, the drowsy stretch 600-720 on top of it.
        assertEquals(
            listOf(
                Segment(0, 100, Band.INACTIVE),
                Segment(100, 500, Band.AWAKE),
                Segment(500, 600, Band.NAP),
                Segment(600, 720, Band.DROWSY),
                Segment(720, 800, Band.NAP),
                Segment(800, 1_000, Band.AWAKE),
            ),
            timeline.segments,
        )
    }

    @Test
    fun pausesAreInactiveAndShiftLaterEvents() {
        val timeline = TimelineBuilder.build(
            session(listOf(Event(600, EventType.ALERT, stillSeconds = 50), Event(610, EventType.ANSWER_NO)), pauses = listOf(Pause(300, 200))),
        )
        assertEquals(1_200, timeline.durationSeconds)
        assertEquals(
            listOf(Segment(0, 100, Band.INACTIVE), Segment(100, 300, Band.AWAKE), Segment(300, 500, Band.INACTIVE), Segment(500, 1_200, Band.AWAKE)),
            timeline.segments,
        )
        assertEquals(listOf(Marker(800, MarkerKind.FALSE_ALARM)), timeline.markers)
    }
}
