import Toybox.Lang;
import Toybox.Test;

// Unit tests for the analysis classes. Run with "Monkey C: Run Tests" in VS Code.
// (:test) code is left out of normal builds.

// --- Stats ---

(:test)
function medianOfOddCountIsMiddleValue(logger as Logger) as Boolean {
    Test.assertEqual(Stats.median([5, 1, 9, 3, 7]), 5.0);
    return true;
}

(:test)
function medianOfEvenCountIsMeanOfMiddleValues(logger as Logger) as Boolean {
    Test.assertEqual(Stats.median([4, 1, 3, 2]), 2.5);
    return true;
}

(:test)
function medianHandlesDuplicatesAndFloats(logger as Logger) as Boolean {
    Test.assertEqual(Stats.median([2.5, 2.5, 1.0, 2.5, 9.0]), 2.5);
    return true;
}

(:test)
function medianOfEmptyArrayIsNull(logger as Logger) as Boolean {
    Test.assert(Stats.median([]) == null);
    return true;
}

(:test)
function medianDoesNotModifyInput(logger as Logger) as Boolean {
    var values = [3, 1, 2];
    Stats.median(values);
    Test.assertEqual(values[0], 3);
    Test.assertEqual(values[1], 1);
    Test.assertEqual(values[2], 2);
    return true;
}

// --- MovementAnalyzer ---

(:test)
function movementOfConstantSamplesIsZero(logger as Logger) as Boolean {
    Test.assertEqual(MovementAnalyzer.movementOf([0, 0, 0], [0, 0, 0], [1000, 1000, 1000]), 0.0);
    return true;
}

(:test)
function movementSumsMeanAbsoluteDeviationOfAxes(logger as Logger) as Boolean {
    // x deviates 5 mg on average, y 2 mg, z not at all.
    Test.assertEqual(MovementAnalyzer.movementOf([0, 10, 0, 10], [-2, 2, -2, 2], [1000, 1000, 1000, 1000]), 7.0);
    return true;
}

(:test)
function movementOfNoSamplesIsNull(logger as Logger) as Boolean {
    Test.assert(MovementAnalyzer.movementOf([], [], []) == null);
    return true;
}

(:test)
function stillSecondsCountWhileBelowThreshold(logger as Logger) as Boolean {
    var analyzer = new MovementAnalyzer();
    for (var i = 0; i < 5; i++) {
        analyzer.addSecond(10.0);
    }
    Test.assertEqual(analyzer.getStillSeconds(), 5);
    return true;
}

(:test)
function missingMovementCountsAsStill(logger as Logger) as Boolean {
    var analyzer = new MovementAnalyzer();
    analyzer.addSecond(null);
    analyzer.addSecond(null);
    Test.assertEqual(analyzer.getStillSeconds(), 2);
    return true;
}

(:test)
function shortTwitchDoesNotResetStillness(logger as Logger) as Boolean {
    var analyzer = new MovementAnalyzer();
    for (var i = 0; i < 5; i++) {
        analyzer.addSecond(10.0);
    }
    analyzer.addSecond(50.0);
    analyzer.addSecond(50.0);
    Test.assertEqual(analyzer.getStillSeconds(), 5);
    analyzer.addSecond(10.0);
    Test.assertEqual(analyzer.getStillSeconds(), 6);
    return true;
}

(:test)
function sustainedMovementResetsStillness(logger as Logger) as Boolean {
    var analyzer = new MovementAnalyzer();
    for (var i = 0; i < 5; i++) {
        analyzer.addSecond(10.0);
    }
    for (var i = 0; i < 3; i++) {
        analyzer.addSecond(50.0);
    }
    Test.assertEqual(analyzer.getStillSeconds(), 0);
    return true;
}

(:test)
function bigMovementResetsStillnessImmediately(logger as Logger) as Boolean {
    var analyzer = new MovementAnalyzer();
    for (var i = 0; i < 5; i++) {
        analyzer.addSecond(10.0);
    }
    analyzer.addSecond(200.0);
    Test.assertEqual(analyzer.getStillSeconds(), 0);
    return true;
}

(:test)
function baselineSetsThresholdWithFloor(logger as Logger) as Boolean {
    var analyzer = new MovementAnalyzer();
    analyzer.setBaseline(20.0, 1.5);
    Test.assertEqual(analyzer.getThreshold(), 30.0);
    analyzer.setBaseline(2.0, 1.5);
    Test.assertEqual(analyzer.getThreshold(), 15.0);
    return true;
}

// --- HeartAnalyzer ---

(:test)
function averageUsesLastThirtyReadings(logger as Logger) as Boolean {
    var analyzer = new HeartAnalyzer();
    Test.assert(analyzer.getAverageHr() == null);
    for (var hr = 1; hr <= 40; hr++) {
        analyzer.addHeartRate(hr);
    }
    // Readings 11..40 remain.
    Test.assertEqual(analyzer.getAverageHr(), 25.5);
    return true;
}

(:test)
function missingHeartRateIsIgnoredForAverage(logger as Logger) as Boolean {
    var analyzer = new HeartAnalyzer();
    analyzer.addHeartRate(60);
    analyzer.addHeartRate(null);
    analyzer.addHeartRate(0);
    analyzer.addHeartRate(70);
    Test.assertEqual(analyzer.getAverageHr(), 65.0);
    Test.assertEqual(analyzer.getCurrentHr(), 70);
    return true;
}

(:test)
function rmssdOfAlternatingIntervals(logger as Logger) as Boolean {
    var analyzer = new HeartAnalyzer();
    for (var i = 0; i < 30; i++) {
        analyzer.addBeatInterval(i % 2 == 0 ? 800 : 850);
    }
    Test.assertEqual(analyzer.getRmssd(), 50.0);
    return true;
}

(:test)
function rmssdNeedsEnoughIntervals(logger as Logger) as Boolean {
    var analyzer = new HeartAnalyzer();
    for (var i = 0; i < 19; i++) {
        analyzer.addBeatInterval(800);
    }
    Test.assert(analyzer.getRmssd() == null);
    analyzer.addBeatInterval(800);
    Test.assertEqual(analyzer.getRmssd(), 0.0);
    return true;
}

(:test)
function artifactIntervalsAreIgnored(logger as Logger) as Boolean {
    var analyzer = new HeartAnalyzer();
    analyzer.addBeatIntervals([800, 100, 2500, 800]);
    Test.assertEqual(analyzer.getIntervalCount(), 2);
    // A sudden jump of more than 20% is a missed beat; the beat after it is accepted again.
    analyzer.addBeatIntervals([1600, 800]);
    Test.assertEqual(analyzer.getIntervalCount(), 2);
    analyzer.addBeatIntervals([1600, 1600]);
    Test.assertEqual(analyzer.getIntervalCount(), 3);
    return true;
}

(:test)
function intervalsAreLimitedToOneMinute(logger as Logger) as Boolean {
    var analyzer = new HeartAnalyzer();
    for (var i = 0; i < 100; i++) {
        analyzer.addBeatInterval(1000);
    }
    Test.assertEqual(analyzer.getIntervalCount(), 60);
    return true;
}

// --- Calibrator ---

(:test)
function calibrationProducesMedians(logger as Logger) as Boolean {
    var calibrator = new Calibrator(10);
    for (var i = 0; i < 10; i++) {
        Test.assert(!calibrator.isCalibrated());
        calibrator.addSecond(70 + i % 5, 5.0, i < 5 ? null : 40.0);
    }
    var baseline = calibrator.getBaseline() as Baseline;
    Test.assert(baseline != null);
    Test.assertEqual(baseline.hr, 72.0);
    Test.assertEqual(baseline.movement, 5.0);
    Test.assertEqual(baseline.hrv, 40.0);
    return true;
}

(:test)
function calibrationWithoutHrvLeavesItNull(logger as Logger) as Boolean {
    var calibrator = new Calibrator(4);
    for (var i = 0; i < 4; i++) {
        calibrator.addSecond(65, null, null);
    }
    var baseline = calibrator.getBaseline() as Baseline;
    Test.assert(baseline != null);
    Test.assert(baseline.movement == null);
    Test.assert(baseline.hrv == null);
    return true;
}

(:test)
function calibrationWaitsForEnoughHeartRate(logger as Logger) as Boolean {
    var calibrator = new Calibrator(10);
    for (var i = 0; i < 10; i++) {
        calibrator.addSecond(null, 5.0, null);
    }
    for (var i = 0; i < 4; i++) {
        calibrator.addSecond(70, 5.0, null);
    }
    Test.assert(!calibrator.isCalibrated());
    calibrator.addSecond(70, 5.0, null);
    Test.assert(calibrator.isCalibrated());
    Test.assertEqual(calibrator.getElapsed(), 15);
    return true;
}

// --- SessionMonitor ---

(:test)
function monitorSetsMovementThresholdAfterCalibration(logger as Logger) as Boolean {
    var monitor = new SessionMonitor(5);
    for (var i = 0; i < 5; i++) {
        monitor.tick(70, 20.0, []);
    }
    Test.assert(monitor.calibrator.isCalibrated());
    Test.assertEqual(monitor.movement.getThreshold(), 30.0);
    return true;
}
