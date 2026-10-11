import Toybox.Lang;
import Toybox.Test;

// Unit tests for the debug scenario playback.

(:test)
function scenarioInterpolatesWithinPhase(logger as Logger) as Boolean {
    var scenario = new Scenario("Test", [
        new ScenarioPhase(10, 70, 70, 30, 30, 0),
        new ScenarioPhase(10, 70, 60, 30, 50, 2)
    ]);
    Test.assertEqual(scenario.getTotalSeconds(), 20);
    var sample = scenario.sample(15);
    Test.assertEqual(sample.hr, 65.0);
    Test.assertEqual(sample.hrv, 40.0);
    Test.assertEqual(sample.fidgetsPerMinute, 2.0);
    return true;
}

(:test)
function scenarioHoldsEndValuesAfterLastPhase(logger as Logger) as Boolean {
    var scenario = new Scenario("Test", [new ScenarioPhase(10, 70, 60, 30, 50, 0)]);
    var sample = scenario.sample(100);
    Test.assertEqual(sample.hr, 60.0);
    Test.assertEqual(sample.hrv, 50.0);
    return true;
}

(:test)
function scenarioBeatsMatchHeartRateAndHrv(logger as Logger) as Boolean {
    var monitor = new SessionMonitor(5);
    var source = new ScenarioSource(monitor, Scenarios.all()[0]);
    var heart = new HeartAnalyzer();
    var beats = 0;
    for (var i = 0; i < 60; i++) {
        var intervals = source.nextBeatIntervals(60.0, 40.0);
        beats += intervals.size();
        heart.addBeatIntervals(intervals);
    }
    Test.assertEqual(beats, 60);
    Test.assertEqual(heart.getRmssd(), 40.0);
    return true;
}

(:test)
function allScenariosHavePhases(logger as Logger) as Boolean {
    var scenarios = Scenarios.all();
    Test.assert(scenarios.size() > 0);
    for (var i = 0; i < scenarios.size(); i++) {
        Test.assert(scenarios[i].getTotalSeconds() > Config.CALIBRATION_SECONDS);
    }
    return true;
}
