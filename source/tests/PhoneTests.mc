import Toybox.Lang;
import Toybox.Test;

// Unit tests for what is sent to the phone app. The transfer itself (Communications) only runs
// in the simulator and on the watch.

(:test)
function clockRecordsPausesOnSessionSeconds(logger as Logger) as Boolean {
    var clock = new SessionClock(1000);
    clock.pause(1100);
    // A second pause call while paused keeps the first time.
    clock.pause(1105);
    clock.resume(1160, 100);
    Test.assertEqual(clock.getPauses().toString(), "[[100, 60]]");
    Test.assertEqual(clock.getEndTime(1500), 1500);
    // Stopped for saving: the session ends when it was stopped.
    clock.pause(1500);
    Test.assertEqual(clock.getEndTime(1520), 1500);
    return true;
}

(:test)
function messageHoldsSessionAndEvents(logger as Logger) as Boolean {
    var monitor = TestSupport.newMonitor(5);
    TestSupport.runUntilAlert(monitor);
    var alertSecond = monitor.getSecond();
    monitor.acknowledgeAlert();
    monitor.answerAlert(true);
    monitor.logNap(15);

    var clock = new SessionClock(1700000000);
    var message = SessionMessage.build(clock, 1700000000 + alertSecond, monitor);
    Test.assertEqual(message["type"], "session");
    Test.assertEqual(message["v"], 1);
    Test.assertEqual(message["id"], 1700000000);
    Test.assertEqual(message["seconds"], alertSecond);
    Test.assertEqual(message["end"], 1700000000 + alertSecond);
    Test.assertEqual(message["calibrated"], 5);
    TestSupport.assertNear(message["baselineHr"] as Float, 74.0);
    Test.assertEqual((message["params"] as Dictionary).size(), 2);

    var events = message["events"] as Array<Dictionary>;
    Test.assertEqual(events.size(), 3);
    Test.assertEqual(events[0]["c"], RecordEvent.ALERT);
    Test.assertEqual(events[0]["s"], alertSecond);
    Test.assert((events[0]["still"] as Number) > 0);
    Test.assert((events[0]["drop"] as Float) > 0);
    Test.assertEqual(events[1]["c"], RecordEvent.ANSWER_YES);
    Test.assertEqual(events[2]["c"], RecordEvent.NAP);
    Test.assertEqual(events[2]["min"], 15);
    return true;
}

(:test)
function messageLeavesOutBaselineBeforeCalibration(logger as Logger) as Boolean {
    var monitor = TestSupport.newMonitor(60);
    monitor.tick(74, 6.0, []);
    var message = SessionMessage.build(new SessionClock(1000), 1001, monitor);
    Test.assert(!message.hasKey("calibrated"));
    Test.assert(!message.hasKey("baselineHr"));
    Test.assertEqual((message["events"] as Array).size(), 0);
    return true;
}

(:test)
function outboxRemovesAcknowledgedSessions(logger as Logger) as Boolean {
    var outbox = new PhoneOutbox(null);
    outbox.add({"id" => 1});
    outbox.add({"id" => 2});
    outbox.remove(1);
    Test.assertEqual(outbox.getMessages().size(), 1);
    Test.assertEqual(outbox.getMessages()[0]["id"], 2);
    // An unknown id changes nothing.
    outbox.remove(7);
    Test.assertEqual(outbox.getMessages().size(), 1);
    return true;
}

(:test)
function outboxDropsOldestBeyondLimit(logger as Logger) as Boolean {
    // PhoneOutbox.MAX_MESSAGES is 10.
    var outbox = new PhoneOutbox(null);
    for (var i = 0; i < 12; i++) {
        outbox.add({"id" => i});
    }
    Test.assertEqual(outbox.getMessages().size(), 10);
    Test.assertEqual(outbox.getMessages()[0]["id"], 2);
    return true;
}

(:test)
function syncWithEmptyOutboxReportsNothing(logger as Logger) as Boolean {
    var sync = new PhoneSync(new PhoneOutbox(null));
    sync.sendPending(null);
    Test.assertEqual(sync.getStatus(), SYNC_NONE);
    // An ack or a timeout without a running sync changes nothing.
    sync.acknowledge(1);
    sync.onAckTimeout();
    Test.assertEqual(sync.getStatus(), SYNC_NONE);
    return true;
}
