import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

// Plays a Scenario into the SessionMonitor instead of the real sensors, faster than real time.
// Produces heart rate, movement and beat intervals, so the whole pipeline can be tested in the
// simulator. Debug builds only.
(:debug)
class ScenarioSource extends DataSource {

    // Movement (milli-g) of an arm resting on a desk, and of a fidget.
    const REST_MOVEMENT = 6.0;
    const FIDGET_MOVEMENT = 80.0;
    const FIDGET_SECONDS = 3;
    // Fixed seed so a scenario plays the same way every time.
    const SEED = 42;

    private var _monitor as SessionMonitor;
    private var _scenario as Scenario;
    private var _timer as Timer.Timer? = null;
    private var _second as Number = 0;
    private var _fidgetRemaining as Number = 0;
    private var _beatsDue as Float = 0.0;
    private var _longBeat as Boolean = false;

    function initialize(monitor as SessionMonitor, scenario as Scenario) {
        DataSource.initialize();
        _monitor = monitor;
        _scenario = scenario;
    }

    function start() as Void {
        seedRandom();
        var timer = new Timer.Timer();
        timer.start(method(:onTick), 1000 / Config.SCENARIO_SPEED, true);
        _timer = timer;
    }

    function stop() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    function seedRandom() as Void {
        Math.srand(SEED);
    }

    function onTick() as Void {
        step();
        WatchUi.requestUpdate();
    }

    // Plays one scenario second into the monitor. The tests call this directly.
    function step() as Void {
        var sample = _scenario.sample(_second);
        var hr = Math.round(sample.hr + random(-1.0, 1.0)).toNumber();
        _monitor.tick(hr, nextMovement(sample.fidgetsPerMinute), nextBeatIntervals(sample.hr, sample.hrv));
        _second++;
    }

    // Resting noise, with fidget bursts started at random at the scripted rate.
    private function nextMovement(fidgetsPerMinute as Float) as Float {
        if (_fidgetRemaining == 0 && random(0.0, 60.0) < fidgetsPerMinute) {
            _fidgetRemaining = FIDGET_SECONDS;
        }
        if (_fidgetRemaining > 0) {
            _fidgetRemaining--;
            return FIDGET_MOVEMENT * random(0.8, 1.2);
        }
        return REST_MOVEMENT * random(0.7, 1.3);
    }

    // The beats falling into this second. Intervals alternate long and short around the mean
    // interval by hrv / 2, so successive differences equal hrv and the RMSSD comes out as hrv.
    function nextBeatIntervals(hr as Float, hrv as Float) as Array<Number> {
        var intervals = [] as Array<Number>;
        _beatsDue += hr / 60.0;
        while (_beatsDue >= 1.0) {
            _beatsDue -= 1.0;
            _longBeat = !_longBeat;
            var mean = 60000.0 / hr;
            intervals.add((_longBeat ? mean + hrv / 2 : mean - hrv / 2).toNumber());
        }
        return intervals;
    }

    private function random(min as Float, max as Float) as Float {
        return min + (max - min) * (Math.rand() % 10000) / 10000.0;
    }
}
