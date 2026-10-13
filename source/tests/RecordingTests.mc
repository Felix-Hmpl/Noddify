import Toybox.Lang;
import Toybox.Test;

// Unit tests for what goes into the activity recording. The recording itself (ActivityRecording,
// FitContributor) only runs in the simulator and on the watch.

(:test)
function recordEventCodesAreStable(logger as Logger) as Boolean {
    // These codes are stored in recorded activities and must never change.
    Test.assertEqual(RecordEvent.codeOf(EventType.ALERT), 1);
    Test.assertEqual(RecordEvent.codeOf(EventType.ANSWER_YES), 2);
    Test.assertEqual(RecordEvent.codeOf(EventType.ANSWER_NO), 3);
    Test.assertEqual(RecordEvent.codeOf(EventType.UNANSWERED), 4);
    Test.assertEqual(RecordEvent.codeOf(EventType.NAP), 5);
    Test.assertEqual(RecordEvent.codeOf("unknown"), 0);
    return true;
}

(:test)
function eventsAreHandedToRecordingOnce(logger as Logger) as Boolean {
    var monitor = TestSupport.newMonitor(5);
    TestSupport.runUntilAlert(monitor);
    var events = monitor.takeRecordEvents();
    Test.assertEqual(events.size(), 1);
    Test.assertEqual(events[0][0], RecordEvent.ALERT);
    Test.assertEqual(monitor.takeRecordEvents().size(), 0);
    return true;
}

(:test)
function answerAndNapAreHandedToRecording(logger as Logger) as Boolean {
    var monitor = TestSupport.newMonitor(5);
    TestSupport.runUntilAlert(monitor);
    monitor.takeRecordEvents();
    monitor.acknowledgeAlert();
    monitor.answerAlert(false);
    monitor.logNap(15);
    var events = monitor.takeRecordEvents();
    Test.assertEqual(events.size(), 2);
    Test.assertEqual(events[0][0], RecordEvent.ANSWER_NO);
    Test.assertEqual(events[0][1], 0);
    Test.assertEqual(events[1][0], RecordEvent.NAP);
    Test.assertEqual(events[1][1], 15);
    return true;
}

// --- RecordEventQueue ---

(:test)
function queueShowsEachEventForHoldTime(logger as Logger) as Boolean {
    var queue = new RecordEventQueue();
    Test.assertEqual(queue.current(0)[0], RecordEvent.NONE);
    queue.add([[RecordEvent.ALERT, 0], [RecordEvent.NAP, 5]]);
    Test.assertEqual(queue.current(1000)[0], RecordEvent.ALERT);
    Test.assertEqual(queue.current(2499)[0], RecordEvent.ALERT);
    // After 1.5 s the next event takes over, then nothing.
    var nap = queue.current(2500);
    Test.assertEqual(nap[0], RecordEvent.NAP);
    Test.assertEqual(nap[1], 5);
    Test.assertEqual(queue.current(3999)[0], RecordEvent.NAP);
    Test.assertEqual(queue.current(4000)[0], RecordEvent.NONE);
    return true;
}

(:test)
function queueKeepsEventsArrivingWithinOneSecond(logger as Logger) as Boolean {
    // Five ticks within one real second (scenario speed), each with an event.
    var queue = new RecordEventQueue();
    var seen = [] as Array<Number>;
    for (var ms = 0; ms < 10000; ms += 200) {
        if (ms < 1000) {
            queue.add([[RecordEvent.ALERT + ms / 200 % 5, 0]]);
        }
        var code = queue.current(ms)[0];
        if (code != RecordEvent.NONE && (seen.size() == 0 || seen[seen.size() - 1] != code)) {
            seen.add(code);
        }
    }
    Test.assertEqual(seen.toString(), "[1, 2, 3, 4, 5]");
    return true;
}

(:test)
function eventCountsArePerSession(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    var events = new EventLog(null);
    var first = new SessionMonitor(5, new RecordingVibrator(), learning, events);
    first.tick(74, 6.0, []);
    first.logNap(5);
    first.logNap(10);
    Test.assertEqual(first.getEventCount(EventType.NAP), 2);
    Test.assertEqual(first.getEventCount(EventType.ALERT), 0);

    // A new session shares the saved history, but counts its own events.
    var second = new SessionMonitor(5, new RecordingVibrator(), learning, events);
    Test.assertEqual(second.getEventCount(EventType.NAP), 0);
    Test.assertEqual(events.count(EventType.NAP), 2);
    return true;
}

(:test)
function listenerRunsAfterEveryTick(logger as Logger) as Boolean {
    var monitor = TestSupport.newMonitor(5);
    var counter = new TickCounter();
    monitor.listener = counter.method(:onTick);
    for (var i = 0; i < 3; i++) {
        monitor.tick(74, 6.0, []);
    }
    Test.assertEqual(counter.ticks, 3);
    return true;
}

(:test)
class TickCounter {
    var ticks as Number = 0;

    function initialize() {
    }

    function onTick() as Void {
        ticks++;
    }
}

(:test)
function durationFormat(logger as Logger) as Boolean {
    Test.assertEqual(Format.duration(0), "0:00");
    Test.assertEqual(Format.duration(65), "1:05");
    Test.assertEqual(Format.duration(3599), "59:59");
    Test.assertEqual(Format.duration(3600 + 2 * 60 + 3), "1:02:03");
    return true;
}
