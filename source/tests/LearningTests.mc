import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for the learning model, the event log and feedback through the session monitor.

// --- LearningModel ---

(:test)
function falseAlarmMakesLessSensitive(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    learning.apply(FEEDBACK_FALSE_ALARM);
    Test.assertEqual(learning.params.get(Param.HR_DROP), 7.0);
    Test.assertEqual(learning.params.get(Param.STILL_SECONDS), 135.0);
    Test.assertEqual(learning.getFeedbackCount(), 1);
    return true;
}

(:test)
function confirmedAlertNudgesMoreSensitive(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    learning.apply(FEEDBACK_CONFIRMED);
    Test.assertEqual(learning.params.get(Param.HR_DROP), 5.75);
    Test.assertEqual(learning.params.get(Param.STILL_SECONDS), 116.0);
    return true;
}

(:test)
function missedNapMakesMoreSensitive(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    learning.apply(FEEDBACK_MISSED);
    Test.assertEqual(learning.params.get(Param.HR_DROP), 5.0);
    Test.assertEqual(learning.params.get(Param.STILL_SECONDS), 105.0);
    return true;
}

(:test)
function lateAlertCountsHalfAsMissed(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    learning.apply(FEEDBACK_LATE);
    Test.assertEqual(learning.params.get(Param.HR_DROP), 5.5);
    Test.assertEqual(learning.params.get(Param.STILL_SECONDS), 112.5);
    return true;
}

(:test)
function stepsShrinkWithExperience(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    learning.apply(FEEDBACK_FALSE_ALARM);
    // The second step is scaled by 1 / sqrt(2).
    learning.apply(FEEDBACK_FALSE_ALARM);
    TestSupport.assertNear(learning.params.get(Param.HR_DROP), 7.0 + 0.70711);
    TestSupport.assertNear(learning.params.get(Param.STILL_SECONDS), 135.0 + 10.6066);
    return true;
}

(:test)
function stepsNeverShrinkBelowMinimum(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    for (var i = 0; i < 30; i++) {
        learning.apply(i % 2 == 0 ? FEEDBACK_FALSE_ALARM : FEEDBACK_MISSED);
    }
    // 1 / sqrt(31) would be 0.18.
    Test.assertEqual(learning.getStepFactor(), 0.25);
    return true;
}

(:test)
function learnedValuesStayWithinLimits(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    // Enough feedback to push both values past their limits, even with the shrinking steps.
    for (var i = 0; i < 200; i++) {
        learning.apply(FEEDBACK_FALSE_ALARM);
    }
    Test.assertEqual(learning.params.get(Param.HR_DROP), 15.0);
    Test.assertEqual(learning.params.get(Param.STILL_SECONDS), 600.0);
    for (var i = 0; i < 1000; i++) {
        learning.apply(FEEDBACK_MISSED);
    }
    Test.assertEqual(learning.params.get(Param.HR_DROP), 2.0);
    Test.assertEqual(learning.params.get(Param.STILL_SECONDS), 60.0);
    return true;
}

(:test)
function feedbackLeavesUnlearnedParamsAlone(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    learning.apply(FEEDBACK_FALSE_ALARM);
    learning.apply(FEEDBACK_MISSED);
    Test.assertEqual(learning.params.get(Param.CONFIRM_SECONDS), 20.0);
    Test.assertEqual(learning.params.get(Param.COOLDOWN_SECONDS), 180.0);
    Test.assertEqual(learning.params.get(Param.HRV_BOOST_BPM), 1.5);
    return true;
}

(:test)
function resetRestoresDefaults(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    var params = learning.params;
    learning.apply(FEEDBACK_FALSE_ALARM);
    learning.reset();
    Test.assertEqual(params.get(Param.HR_DROP), 6.0);
    Test.assertEqual(learning.getFeedbackCount(), 0);
    // Resetting keeps the same Params object, which running detectors hold on to.
    Test.assert(learning.params == params);
    return true;
}

(:test)
function learnedValuesSurviveRestart(logger as Logger) as Boolean {
    var key = "test_learning";
    Storage.deleteValue(key);
    var learning = new LearningModel(key);
    learning.apply(FEEDBACK_FALSE_ALARM);
    learning.apply(FEEDBACK_FALSE_ALARM);

    var restored = new LearningModel(key);
    Storage.deleteValue(key);
    Test.assertEqual(restored.getFeedbackCount(), 2);
    Test.assertEqual(restored.params.get(Param.HR_DROP), learning.params.get(Param.HR_DROP));
    Test.assertEqual(restored.params.get(Param.STILL_SECONDS), learning.params.get(Param.STILL_SECONDS));
    return true;
}

(:test)
function savedValuesOutsideNewLimitsAreClamped(logger as Logger) as Boolean {
    var key = "test_learning";
    Storage.setValue(key, {"version" => 1, "feedbackCount" => 3, "params" => {Param.HR_DROP => 99.0, "removedParam" => 1.0}});
    var learning = new LearningModel(key);
    Storage.deleteValue(key);
    Test.assertEqual(learning.params.get(Param.HR_DROP), 15.0);
    Test.assertEqual(learning.params.get(Param.STILL_SECONDS), 120.0);
    Test.assertEqual(learning.getFeedbackCount(), 3);
    return true;
}

// --- EventLog ---

(:test)
function eventLogKeepsFeaturesWithoutNulls(logger as Logger) as Boolean {
    var log = new EventLog(null);
    log.add(EventType.ALERT, 42, TestSupport.features(130, 7.0, null), {"extra" => 1});
    var event = log.getEvents()[0];
    Test.assertEqual(event["type"], EventType.ALERT);
    Test.assertEqual(event["second"], 42);
    Test.assertEqual(event["extra"], 1);
    var features = event["features"] as Dictionary;
    Test.assertEqual(features[Feature.HR_DROP], 7.0);
    Test.assert(!features.hasKey(Feature.HRV_RATIO));
    return true;
}

(:test)
function eventLogDropsOldestBeyondLimit(logger as Logger) as Boolean {
    var log = new EventLog(null);
    for (var i = 0; i < 60; i++) {
        log.add(EventType.NAP, i, null, null);
    }
    Test.assertEqual(log.getEvents().size(), 50);
    Test.assertEqual(log.getEvents()[0]["second"], 10);
    return true;
}

(:test)
function eventLogSurvivesRestart(logger as Logger) as Boolean {
    var key = "test_events";
    Storage.deleteValue(key);
    new EventLog(key).add(EventType.NAP, 7, null, {"minutes" => 5});
    var restored = new EventLog(key);
    Storage.deleteValue(key);
    Test.assertEqual(restored.count(EventType.NAP), 1);
    Test.assertEqual(restored.getEvents()[0]["minutes"], 5);
    return true;
}

// --- Feedback through the SessionMonitor ---

(:test)
function answeringNoMakesDetectorLessSensitive(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    var events = new EventLog(null);
    var monitor = new SessionMonitor(5, new RecordingVibrator(), learning, events);
    TestSupport.runUntilAlert(monitor);
    Test.assertEqual(events.count(EventType.ALERT), 1);
    monitor.acknowledgeAlert();
    monitor.answerAlert(false);
    Test.assertEqual(events.count(EventType.ANSWER_NO), 1);
    // The running detector uses the learned value right away.
    Test.assertEqual(monitor.detector.params.get(Param.HR_DROP), 7.0);
    return true;
}

(:test)
function answeringYesIsLogged(logger as Logger) as Boolean {
    var events = new EventLog(null);
    var monitor = new SessionMonitor(5, new RecordingVibrator(), new LearningModel(null), events);
    TestSupport.runUntilAlert(monitor);
    monitor.acknowledgeAlert();
    monitor.answerAlert(true);
    var answer = events.getEvents()[1];
    Test.assertEqual(answer["type"], EventType.ANSWER_YES);
    // The answer carries the features of the alert it refers to.
    Test.assert((answer["features"] as Dictionary).hasKey(Feature.HR_DROP));
    return true;
}

(:test)
function ignoredAlertIsLoggedAsUnanswered(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    var events = new EventLog(null);
    var monitor = new SessionMonitor(5, new RecordingVibrator(), learning, events);
    TestSupport.runUntilAlert(monitor);
    for (var i = 0; i < 60; i++) {
        monitor.tick(60, 6.0, []);
    }
    Test.assert(!monitor.isAlerting());
    Test.assertEqual(events.count(EventType.UNANSWERED), 1);
    // No answer: nothing learned.
    Test.assertEqual(learning.getFeedbackCount(), 0);
    return true;
}

(:test)
function napWithoutAlertCountsAsMissed(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    var events = new EventLog(null);
    var monitor = new SessionMonitor(5, new RecordingVibrator(), learning, events);
    for (var i = 0; i < 30; i++) {
        monitor.tick(74, 6.0, []);
    }
    monitor.logNap(10);
    Test.assertEqual(learning.params.get(Param.HR_DROP), 5.0);
    var nap = events.getEvents()[0];
    Test.assertEqual(nap["minutes"], 10);
    Test.assertEqual(nap["alerted"], false);
    return true;
}

(:test)
function napWithAlertCountsAsLate(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    var monitor = new SessionMonitor(5, new RecordingVibrator(), learning, new EventLog(null));
    TestSupport.runUntilAlert(monitor);
    monitor.acknowledgeAlert();
    monitor.logNap(5);
    Test.assertEqual(learning.params.get(Param.HR_DROP), 5.5);
    return true;
}

(:test)
function napBeforeAnOldAlertCountsAsMissed(logger as Logger) as Boolean {
    var learning = new LearningModel(null);
    var monitor = new SessionMonitor(5, new RecordingVibrator(), learning, new EventLog(null));
    TestSupport.runUntilAlert(monitor);
    monitor.acknowledgeAlert();
    // 10 minutes later, log a 2 minute nap: the alert lies before it.
    for (var i = 0; i < 600; i++) {
        monitor.tick(74, 50.0, []);
    }
    monitor.logNap(2);
    Test.assertEqual(learning.params.get(Param.HR_DROP), 5.0);
    return true;
}
