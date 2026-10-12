import Toybox.Lang;
import Toybox.Test;

// Shared test helpers. Kept in classes, because the test runner would run (:test) functions as tests.

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

(:test)
class TestSupport {

    // A session monitor with default parameters, a recording vibrator and nothing saved.
    static function newMonitor(calibrationSeconds as Number) as SessionMonitor {
        return new SessionMonitor(calibrationSeconds, new RecordingVibrator(), new LearningModel(null), new EventLog(null));
    }

    // Calibrates a monitor at 74 bpm, then keeps it still at 60 bpm until the first alert fires.
    static function runUntilAlert(monitor as SessionMonitor) as Void {
        for (var i = 0; i < 1000 && monitor.getAlertCount() == 0; i++) {
            monitor.tick(i < 10 ? 74 : 60, 6.0, []);
        }
    }

    static function assertNear(actual as Numeric, expected as Numeric) as Void {
        Test.assertMessage((actual - expected).abs() < 0.001, "expected " + expected + ", got " + actual);
    }

    // A calibrated feature snapshot with the inputs of the stillness/heart-rate rule.
    static function features(stillSeconds as Numeric, hrDrop as Numeric, hrvRatio as Float?) as FeatureSnapshot {
        return new FeatureSnapshot(true, {
            Feature.STILL_SECONDS => stillSeconds.toFloat(),
            Feature.HR_DROP => hrDrop.toFloat(),
            Feature.HRV_RATIO => hrvRatio
        });
    }

    // Ticks the detector n times with the same features and returns how many alerts fired.
    static function tickDetector(detector as DrowsinessDetector, n as Number, features as FeatureSnapshot) as Number {
        var alerts = 0;
        for (var i = 0; i < n; i++) {
            if (detector.tick(features)) {
                alerts++;
            }
        }
        return alerts;
    }

    // Plays a whole scenario and returns the scenario second of each alert.
    static function alertTimesOf(scenarioIndex as Number) as Array<Number> {
        var monitor = newMonitor(Config.CALIBRATION_SECONDS);
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
