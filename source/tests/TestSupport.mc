import Toybox.Lang;

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

    // A session monitor with default parameters and a recording vibrator.
    static function newMonitor(calibrationSeconds as Number) as SessionMonitor {
        return new SessionMonitor(calibrationSeconds, new RecordingVibrator(), new Params());
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
