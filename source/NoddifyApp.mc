import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class NoddifyApp extends Application.AppBase {

    private var _monitor as SessionMonitor;
    private var _sensors as SensorManager;

    function initialize() {
        AppBase.initialize();
        _monitor = new SessionMonitor(Config.CALIBRATION_SECONDS);
        _sensors = new SensorManager(_monitor);
    }

    // Monitoring runs from app start to app exit. Explicit start/stop of the activity comes in step 5.
    function onStart(state as Dictionary?) as Void {
        _sensors.start();
    }

    function onStop(state as Dictionary?) as Void {
        _sensors.stop();
    }

    function getInitialView() {
        return [new MainView(_monitor), new MainDelegate()];
    }
}
