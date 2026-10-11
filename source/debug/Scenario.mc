import Toybox.Lang;

// One phase of a scenario. Heart rate and HRV move linearly from their start to their end value
// over the phase; fidgets are short bursts of movement that reset the stillness timer.
(:debug)
class ScenarioPhase {
    var seconds as Number;
    var hrFrom as Float;
    var hrTo as Float;
    var hrvFrom as Float;
    var hrvTo as Float;
    var fidgetsPerMinute as Float;

    function initialize(seconds as Number, hrFrom as Numeric, hrTo as Numeric, hrvFrom as Numeric, hrvTo as Numeric, fidgetsPerMinute as Numeric) {
        self.seconds = seconds;
        self.hrFrom = hrFrom.toFloat();
        self.hrTo = hrTo.toFloat();
        self.hrvFrom = hrvFrom.toFloat();
        self.hrvTo = hrvTo.toFloat();
        self.fidgetsPerMinute = fidgetsPerMinute.toFloat();
    }
}

// The scripted values at one second of a scenario, before noise is added.
(:debug)
class ScenarioSample {
    var hr as Float;
    var hrv as Float;
    var fidgetsPerMinute as Float;

    function initialize(hr as Float, hrv as Float, fidgetsPerMinute as Float) {
        self.hr = hr;
        self.hrv = hrv;
        self.fidgetsPerMinute = fidgetsPerMinute;
    }
}

// A scripted session for testing in the simulator. Debug builds only.
(:debug)
class Scenario {
    var name as String;
    var phases as Array<ScenarioPhase>;

    function initialize(name as String, phases as Array<ScenarioPhase>) {
        self.name = name;
        self.phases = phases;
    }

    function getTotalSeconds() as Number {
        var total = 0;
        for (var i = 0; i < phases.size(); i++) {
            total += phases[i].seconds;
        }
        return total;
    }

    // Scripted values at second t. Past the end, the last phase's end values hold.
    function sample(t as Number) as ScenarioSample {
        var start = 0;
        for (var i = 0; i < phases.size(); i++) {
            var phase = phases[i];
            if (t < start + phase.seconds) {
                var f = (t - start).toFloat() / phase.seconds;
                return new ScenarioSample(
                    phase.hrFrom + (phase.hrTo - phase.hrFrom) * f,
                    phase.hrvFrom + (phase.hrvTo - phase.hrvFrom) * f,
                    phase.fidgetsPerMinute);
            }
            start += phase.seconds;
        }
        var last = phases[phases.size() - 1];
        return new ScenarioSample(last.hrTo, last.hrvTo, last.fidgetsPerMinute);
    }
}

// The built-in scenarios. Timings assume the 30 s calibration of debug builds.
(:debug)
class Scenarios {

    static function all() as Array<Scenario> {
        return [
            // Expected: alert once still for 2 min and HR has fallen clearly below baseline.
            new Scenario("Dozing off", [
                new ScenarioPhase(90, 74, 74, 35, 35, 4),
                new ScenarioPhase(180, 74, 63, 35, 55, 0),
                new ScenarioPhase(180, 63, 62, 55, 55, 0)
            ]),
            // Expected: no alert. Completely still, but HR stays at baseline.
            new Scenario("Still, awake", [
                new ScenarioPhase(90, 74, 74, 35, 35, 4),
                new ScenarioPhase(360, 74, 73, 35, 36, 0)
            ]),
            // Expected: no alert. HR drops, but regular fidgeting keeps resetting stillness.
            new Scenario("Restless, tired", [
                new ScenarioPhase(90, 74, 74, 35, 35, 4),
                new ScenarioPhase(360, 74, 62, 35, 55, 3)
            ]),
            // Expected: alert while dozing, then HR recovers after a jolt awake.
            new Scenario("Nod and wake", [
                new ScenarioPhase(90, 74, 74, 35, 35, 4),
                new ScenarioPhase(180, 74, 64, 35, 50, 0),
                new ScenarioPhase(5, 64, 70, 50, 40, 60),
                new ScenarioPhase(180, 70, 75, 40, 35, 4)
            ])
        ];
    }
}
