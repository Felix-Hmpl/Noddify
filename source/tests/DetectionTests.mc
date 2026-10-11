import Toybox.Lang;
import Toybox.Test;

// Unit tests for the drowsiness detector, the alert escalation and whole scenarios.

// Records vibrations instead of playing them.
(:test)
class RecordingVibrator extends Vibrator {
    var played as Array<VibeLevel> = [];

    function initialize() {
        Vibrator.initialize();
    }

    function play(level as VibeLevel) as Void {
        if (level != VIBE_NONE) {
            played.add(level);
        }
    }
}

// Shared helpers. A class, because the test runner would run (:test) functions as tests.
(:test)
class DetectionTestHelpers {

    static function baseline() as Baseline {
        return new Baseline(74.0, 6.0, 35.0);
    }

    // Ticks the detector n times with the same inputs and returns how many alerts fired.
    static function tickDetector(detector as DrowsinessDetector, n as Number, stillSeconds as Number, averageHr as Float, rmssd as Float?) as Number {
        var alerts = 0;
        for (var i = 0; i < n; i++) {
            if (detector.tick(baseline(), stillSeconds, averageHr, rmssd)) {
                alerts++;
            }
        }
        return alerts;
    }

    // Plays a whole scenario and returns the scenario second of each alert.
    static function alertTimesOf(scenarioIndex as Number) as Array<Number> {
        var monitor = new SessionMonitor(Config.CALIBRATION_SECONDS, new RecordingVibrator());
        var scenario = Scenarios.all()[scenarioIndex];
        var source = new ScenarioSource(monitor, scenario);
        source.seedRandom();
        var times = [] as Array<Number>;
        for (var second = 0; second < scenario.getTotalSeconds(); second++) {
            var before = monitor.getAlertCount();
            source.step();
            if (monitor.getAlertCount() > before) {
                times.add(second);
            }
        }
        return times;
    }
}

// --- DrowsinessDetector ---

(:test)
function detectorWaitsForCalibration(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new DetectorParams());
    Test.assert(!detector.tick(null, 600, 50.0, 35.0));
    Test.assertEqual(detector.getState(), STATE_CALIBRATING);
    return true;
}

(:test)
function detectorAlertsAfterConfirmSeconds(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new DetectorParams());
    // Still long enough, 7 bpm below baseline.
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 19, 130, 67.0, 35.0), 0);
    Test.assertEqual(detector.getState(), STATE_DROWSY);
    Test.assert(detector.tick(DetectionTestHelpers.baseline(), 130, 67.0, 35.0));
    Test.assertEqual(detector.getState(), STATE_COOLDOWN);
    return true;
}

(:test)
function detectorNeedsStillness(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new DetectorParams());
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 60, 119, 60.0, 35.0), 0);
    Test.assertEqual(detector.getState(), STATE_AWAKE);
    return true;
}

(:test)
function detectorNeedsHeartRateDrop(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new DetectorParams());
    // Only 5 bpm below baseline and no HRV rise.
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 60, 300, 69.0, 35.0), 0);
    return true;
}

(:test)
function hrvRiseLowersRequiredDrop(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new DetectorParams());
    Test.assertEqual(detector.requiredHrDrop(DetectionTestHelpers.baseline(), 35.0), 6.0);
    Test.assertEqual(detector.requiredHrDrop(DetectionTestHelpers.baseline(), 42.0), 4.5);
    Test.assertEqual(detector.requiredHrDrop(DetectionTestHelpers.baseline(), null), 6.0);
    // 5 bpm below baseline is enough once HRV is 20% up.
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 20, 300, 69.0, 45.0), 1);
    return true;
}

(:test)
function interruptedConditionsRestartConfirmation(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new DetectorParams());
    DetectionTestHelpers.tickDetector(detector, 15, 130, 67.0, 35.0);
    DetectionTestHelpers.tickDetector(detector, 1, 0, 67.0, 35.0);
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 19, 130, 67.0, 35.0), 0);
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 1, 130, 67.0, 35.0), 1);
    return true;
}

(:test)
function cooldownBlocksNextAlert(logger as Logger) as Boolean {
    var detector = new DrowsinessDetector(new DetectorParams());
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 20, 300, 60.0, 35.0), 1);
    // 180 s cooldown, then 20 s confirmation again.
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 199, 300, 60.0, 35.0), 0);
    Test.assertEqual(DetectionTestHelpers.tickDetector(detector, 1, 300, 60.0, 35.0), 1);
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
    var monitor = new SessionMonitor(5, vibrator);
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

(:test)
function scenarioDozingOffAlerts(logger as Logger) as Boolean {
    var times = DetectionTestHelpers.alertTimesOf(0);
    logger.debug("Dozing off alerts at " + times);
    Test.assert(times.size() > 0);
    // Stillness starts at 90 s and HR has dropped enough by about 180 s.
    Test.assert(times[0] >= 200 && times[0] <= 300);
    return true;
}

(:test)
function scenarioStillAwakeDoesNotAlert(logger as Logger) as Boolean {
    var times = DetectionTestHelpers.alertTimesOf(1);
    logger.debug("Still, awake alerts at " + times);
    Test.assertEqual(times.size(), 0);
    return true;
}

(:test)
function scenarioRestlessTiredDoesNotAlert(logger as Logger) as Boolean {
    var times = DetectionTestHelpers.alertTimesOf(2);
    logger.debug("Restless, tired alerts at " + times);
    Test.assertEqual(times.size(), 0);
    return true;
}

(:test)
function scenarioNodAndWakeAlertsBeforeJolt(logger as Logger) as Boolean {
    var times = DetectionTestHelpers.alertTimesOf(3);
    logger.debug("Nod and wake alerts at " + times);
    Test.assert(times.size() > 0);
    // The jolt awake happens at 270 s.
    Test.assert(times[0] < 270);
    return true;
}
