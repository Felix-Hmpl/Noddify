import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class NoddifyApp extends Application.AppBase {

    private var _monitor as SessionMonitor;
    private var _source as DataSource;
    // Name of the scenario being played in place of the sensors, or null for the real sensors.
    private var _sourceLabel as String? = null;

    function initialize() {
        AppBase.initialize();
        _monitor = new SessionMonitor(Config.CALIBRATION_SECONDS);
        _source = new SensorManager(_monitor);
    }

    // Monitoring runs from app start to app exit. Explicit start/stop of the activity comes in step 5.
    function onStart(state as Dictionary?) as Void {
        _source.start();
    }

    function onStop(state as Dictionary?) as Void {
        _source.stop();
    }

    function getInitialView() {
        return [new MainView(), new MainDelegate()];
    }

    function getMonitor() as SessionMonitor {
        return _monitor;
    }

    function getSourceLabel() as String? {
        return _sourceLabel;
    }

    // Restarts the session with the real sensors (index < 0) or the scenario at index.
    (:debug)
    function selectSource(index as Number) as Void {
        _source.stop();
        _monitor = new SessionMonitor(Config.CALIBRATION_SECONDS);
        if (index < 0) {
            _source = new SensorManager(_monitor);
            _sourceLabel = null;
        } else {
            var scenario = Scenarios.all()[index];
            _source = new ScenarioSource(_monitor, scenario);
            _sourceLabel = scenario.name;
        }
        _source.start();
        WatchUi.requestUpdate();
    }
}
