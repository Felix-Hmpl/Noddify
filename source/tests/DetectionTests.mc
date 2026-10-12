import Toybox.Lang;
import Toybox.Test;

// Unit tests for parameters, features, the detection rule, the detector, the alert escalation
// and whole scenarios.

// --- Params ---

(:test)
function paramsStartAtDefaults(logger as Logger) as Boolean {
    var params = new Params();
    Test.assertEqual(params.get(Param.HR_DROP), 6.0);
    Test.assertEqual(params.get(Param.STILL_SECONDS), 120.0);
    Test.assertEqual(params.get(Param.CONFIRM_SECONDS), 20.0);
    Test.assertEqual(params.get(Param.COOLDOWN_SECONDS), 180.0);
    return true;
}

(:test)
function paramsAreClampedToLimits(logger as Logger) as Boolean {
    var params = new Params();
    params.set(Param.HR_DROP, 100.0);
    Test.assertEqual(params.get(Param.HR_DROP), 15.0);
    params.set(Param.HR_DROP, -3.0);
    Test.assertEqual(params.get(Param.HR_DROP), 2.0);
    params.set(Param.STILL_SECONDS, 300.0);
    Test.assertEqual(params.get(Param.STILL_SECONDS), 300.0);
    return true;
}

(:test)
function unknownParamIsIgnored(logger as Logger) as Boolean {
    var params = new Params();
    params.set("noSuchParam", 1.0);
    Test.assert(params.getSpec("noSuchParam") == null);
    return true;
}

// --- Features ---

(:test)
function monitorFeaturesAreNullBeforeCalibration(logger as Logger) as Boolean {
    var monitor = TestSupport.newMonitor(5);
    monitor.tick(74, 6.0, []);
    var features = monitor.getFeatures();
    Test.assert(!features.isCalibrated());
    Test.assertEqual(features.get(Feature.STILL_SECONDS), 1.0);
    Test.assert(features.get(Feature.HR_DROP) == null);
    Test.assert(features.get(Feature.HRV_RATIO) == null);
    return true;
}

(:test)
function monitorFeaturesAreRelativeToBaseline(logger as Logger) as Boolean {
    var monitor = TestSupport.newMonitor(5);
    for (var i = 0; i < 5; i++) {
        monitor.tick(74, 6.0, []);
    }
    monitor.tick(64, 6.0, []);
    var features = monitor.getFeatures();
    Test.assert(features.isCalibrated());
    // Average of five 74s and one 64.
    Test.assertEqual(features.get(Feature.AVERAGE_HR), 72.333336);
    Test.assertEqual(features.get(Feature.HR_DROP), 74.0 - 72.333336);
    return true;
}

(:test)
function fidgetsPerMinuteCountsMovementBursts(logger as Logger) as Boolean {
    var analyzer = new MovementAnalyzer();
    // Two seconds of movement every 20 seconds: 3 bursts per minute.
    for (var i = 0; i < 120; i++) {
        analyzer.addSecond(i % 20 < 2 ? 50.0 : 5.0);
        if (i == 30) {
            Test.assert(analyzer.getFidgetsPerMinute() == null);
        }
    }
    Test.assertEqual(analyzer.getFidgetsPerMinute(), 3.0);
    return true;
}

(:test)
function fidgetsOlderThanFiveMinutesAreForgotten(logger as Logger) as Boolean {
    var analyzer = new MovementAnalyzer();
    for (var i = 0; i < 60; i++) {
        analyzer.addSecond(i % 20 < 2 ? 50.0 : 5.0);
    }
    for (var i = 0; i < 300; i++) {
        analyzer.addSecond(5.0);
    }
    Test.assertEqual(analyzer.getFidgetsPerMinute(), 0.0);
    return true;
}

// --- StillnessHeartRateRule ---

(:test)
function ruleNeedsStillnessAndHeartRateDrop(logger as Logger) as Boolean {
    var rule = new StillnessHeartRateRule();
    var params = new Params();
    Test.assert(rule.isMet(TestSupport.features(120, 6.0, 1.0), params));
    Test.assert(!rule.isMet(TestSupport.features(119, 14.0, 1.0), params));
    Test.assert(!rule.isMet(TestSupport.features(300, 5.0, 1.0), params));
    Test.assert(!rule.isMet(new FeatureSnapshot(true, {}), params));
    return true;
}

(:test)
function hrvRiseLowersRequiredDrop(logger as Logger) as Boolean {
    var rule = new StillnessHeartRateRule();
    var params = new Params();
    Test.assertEqual(rule.requiredHrDrop(TestSupport.features(300, 0, 1.0), params), 6.0);
    Test.assertEqual(rule.requiredHrDrop(TestSupport.features(300, 0, 1.2), params), 4.5);
    Test.assertEqual(rule.requiredHrDrop(TestSupport.features(300, 0, null), params), 6.0);
    Test.assert(rule.isMet(TestSupport.features(300, 5.0, 1.3), params));
    return true;
}

(:test)
function ruleFollowsChangedParams(logger as Logger) as Boolean {
    var rule = new StillnessHeartRateRule();
    var params = new Params();
    params.set(Param.HR_DROP, 8.0);
    params.set(Param.STILL_SECONDS, 200.0);
    Test.assert(!rule.isMet(TestSupport.features(300, 7.0, 1.0), params));
    Test.assert(!rule.isMet(TestSupport.features(150, 9.0, 1.0), params));
    Test.assert(rule.isMet(TestSupport.features(200, 8.0, 1.0), params));
    return true;
}

// --- DrowsinessDetector ---

(:test)
function detectorWaitsForCalibration(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new StillnessHeartRateRule(), new Params());
    Test.assert(!detector.tick(new FeatureSnapshot(false, {Feature.STILL_SECONDS => 600.0})));
    Test.assertEqual(detector.getState(), STATE_CALIBRATING);
    return true;
}

(:test)
function detectorAlertsAfterConfirmSeconds(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new StillnessHeartRateRule(), new Params());
    var drowsy = TestSupport.features(130, 7.0, 1.0);
    Test.assertEqual(TestSupport.tickDetector(detector, 19, drowsy), 0);
    Test.assertEqual(detector.getState(), STATE_DROWSY);
    Test.assert(detector.tick(drowsy));
    Test.assertEqual(detector.getState(), STATE_COOLDOWN);
    return true;
}

(:test)
function detectorStaysAwakeWhileRuleNotMet(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new StillnessHeartRateRule(), new Params());
    Test.assertEqual(TestSupport.tickDetector(detector, 60, TestSupport.features(119, 14.0, 1.0)), 0);
    Test.assertEqual(detector.getState(), STATE_AWAKE);
    return true;
}

(:test)
function interruptedConditionsRestartConfirmation(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new StillnessHeartRateRule(), new Params());
    var drowsy = TestSupport.features(130, 7.0, 1.0);
    TestSupport.tickDetector(detector, 15, drowsy);
    TestSupport.tickDetector(detector, 1, TestSupport.features(0, 7.0, 1.0));
    Test.assertEqual(TestSupport.tickDetector(detector, 19, drowsy), 0);
    Test.assertEqual(TestSupport.tickDetector(detector, 1, drowsy), 1);
    return true;
}

(:test)
function cooldownBlocksNextAlert(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new StillnessHeartRateRule(), new Params());
    var drowsy = TestSupport.features(300, 14.0, 1.0);
    Test.assertEqual(TestSupport.tickDetector(detector, 20, drowsy), 1);
    // 180 s cooldown, then 20 s confirmation again.
    Test.assertEqual(TestSupport.tickDetector(detector, 199, drowsy), 0);
    Test.assertEqual(TestSupport.tickDetector(detector, 1, drowsy), 1);
    return true;
}

// A rule that is always met, to show any rule can be plugged into the detector.
(:test)
class AlwaysMetRule extends DetectionRule {
    function initialize() {
        DetectionRule.initialize();
    }

    function isMet(features as FeatureSnapshot, params as Params) as Boolean {
        return true;
    }
}

(:test)
function detectorAcceptsAnyRule(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new AlwaysMetRule(), new Params());
    Test.assertEqual(TestSupport.tickDetector(detector, 20, new FeatureSnapshot(true, {})), 1);
    return true;
}

// --- AlertEscalation ---

(:test)
function escalationRepeatsStrongThenGivesUp(logger as Logger) as Boolean {
    var escalation = new AlertEscalation();
    Test.assertEqual(escalation.start(), VIBE_GENTLE);
    var strong = 0;
    for (var i = 0; i < 100; i++) {
        var vibe = escalation.tick();
        if (vibe == VIBE_STRONG) {
            strong++;
        }
        // Strong vibrations come at 15, 30 and 45 s.
        Test.assertEqual(vibe == VIBE_STRONG, i + 1 == 15 || i + 1 == 30 || i + 1 == 45);
    }
    Test.assertEqual(strong, 3);
    Test.assert(!escalation.isActive());
    Test.assert(escalation.wasUnanswered());
    return true;
}

(:test)
function acknowledgeStopsEscalation(logger as Logger) as Boolean {
    var escalation = new AlertEscalation();
    Test.assert(!escalation.acknowledge());
    escalation.start();
    escalation.tick();
    Test.assert(escalation.acknowledge());
    Test.assert(!escalation.isActive());
    Test.assert(!escalation.wasUnanswered());
    for (var i = 0; i < 60; i++) {
        Test.assertEqual(escalation.tick(), VIBE_NONE);
    }
    return true;
}

// --- SessionMonitor ---

(:test)
function monitorVibratesOnAlert(logger as Logger) as Boolean {
    var vibrator = new RecordingVibrator();
    var monitor = new SessionMonitor(5, vibrator, new Params());
    for (var i = 0; i < 5; i++) {
        monitor.tick(74, 6.0, []);
    }
    // Still from the start, so the 120 s stillness is reached at second 120.
    for (var i = 0; i < 200 && monitor.getAlertCount() == 0; i++) {
        monitor.tick(60, 6.0, []);
    }
    Test.assertEqual(monitor.getAlertCount(), 1);
    Test.assert(monitor.isAlerting());
    Test.assertEqual(vibrator.played.size(), 1);
    Test.assertEqual(vibrator.played[0], VIBE_GENTLE);
    Test.assert(monitor.acknowledgeAlert());
    Test.assert(!monitor.isAlerting());
    return true;
}

// --- Scenarios ---
// The exact alert seconds guard against unintended changes in detection behavior.

(:test)
function scenarioDozingOffAlerts(logger as Logger) as Boolean {
    var times = TestSupport.alertTimesOf(0);
    logger.debug("Dozing off alerts at " + times);
    Test.assertEqual(times.toString(), "[225, 425]");
    return true;
}

(:test)
function scenarioStillAwakeDoesNotAlert(logger as Logger) as Boolean {
    var times = TestSupport.alertTimesOf(1);
    logger.debug("Still, awake alerts at " + times);
    Test.assertEqual(times.size(), 0);
    return true;
}

(:test)
function scenarioRestlessTiredDoesNotAlert(logger as Logger) as Boolean {
    var times = TestSupport.alertTimesOf(2);
    logger.debug("Restless, tired alerts at " + times);
    Test.assertEqual(times.size(), 0);
    return true;
}

(:test)
function scenarioNodAndWakeAlertsBeforeJolt(logger as Logger) as Boolean {
    var times = TestSupport.alertTimesOf(3);
    logger.debug("Nod and wake alerts at " + times);
    // The jolt awake happens at 270 s.
    Test.assertEqual(times.toString(), "[225]");
    return true;
}
