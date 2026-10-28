import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

enum SessionState {
    // App open, session not started yet.
    SESSION_IDLE,
    SESSION_RUNNING,
    // Stopped with the START/STOP button; can be resumed, saved or discarded.
    SESSION_STOPPED
}

class NoddifyApp extends Application.AppBase {

    // How long saving waits for the phone transfer before the app closes anyway.
    const SEND_TIMEOUT_MS = 8000;

    // Learned detection parameters and the event history, saved on the watch and shared by
    // every session the app runs.
    private var _learning as LearningModel = new LearningModel("learning");
    private var _events as EventLog = new EventLog("events");
    private var _recorder as SessionRecorder = new SessionRecorder();
    // Saved sessions waiting for the phone app, and the link that sends them.
    private var _outbox as PhoneOutbox = new PhoneOutbox("outbox");
    private var _phone as PhoneSync;
    private var _clock as SessionClock? = null;
    private var _exitTimer as Timer.Timer? = null;
    private var _state as SessionState = SESSION_IDLE;
    private var _monitor as SessionMonitor;
    private var _source as DataSource? = null;
    // Name of the scenario being played in place of the sensors, or null for the real sensors.
    private var _sourceLabel as String? = null;
    // Debug builds: the scenario to play instead of the sensors, or REAL_SENSORS_ID.
    (:debug) private var _scenarioIndex as Number = Config.REAL_SENSORS_ID;

    function initialize() {
        AppBase.initialize();
        _monitor = newMonitor();
        _phone = new PhoneSync(_outbox);
    }

    // Sends sessions the phone app hasn't confirmed yet, e.g. when the phone was out of reach.
    function onStart(state as Dictionary?) as Void {
        _phone.listen();
        _phone.sendPending(null);
    }

    // Closing the app with a session in progress (e.g. from the system) saves it rather than
    // losing the data.
    function onStop(state as Dictionary?) as Void {
        stopSource();
        if (_recorder.isActive()) {
            queueForPhone();
            _recorder.save(_monitor);
        }
    }

    function getInitialView() {
        return [new MainView(), new MainDelegate()];
    }

    // Starts monitoring and recording with a fresh calibration.
    function startSession() as Void {
        _monitor = newMonitor();
        var source = createSource(_monitor);
        source.start();
        _source = source;
        _recorder.start();
        _clock = new SessionClock(Time.now().value());
        _state = SESSION_RUNNING;
        WatchUi.requestUpdate();
    }

    function stopSession() as Void {
        stopSource();
        _recorder.stop();
        var clock = _clock;
        if (clock != null) {
            clock.pause(Time.now().value());
        }
        _state = SESSION_STOPPED;
        WatchUi.requestUpdate();
    }

    function resumeSession() as Void {
        var source = _source;
        if (source != null) {
            source.start();
        }
        _recorder.resume();
        var clock = _clock;
        if (clock != null) {
            clock.resume(Time.now().value(), _monitor.getSecond());
        }
        _state = SESSION_RUNNING;
        WatchUi.requestUpdate();
    }

    // Saves the activity, sends it to the phone app and leaves the app, like Garmin's own
    // activities. Leaves after the transfer or SEND_TIMEOUT_MS, whichever comes first; a session
    // that didn't make it is sent again on the next start.
    function saveSession() as Void {
        queueForPhone();
        _recorder.save(_monitor);
        WatchUi.pushView(new WatchUi.ProgressBar(WatchUi.loadResource(Rez.Strings.SendingToPhone) as String, null), null, WatchUi.SLIDE_IMMEDIATE);
        var timer = new Timer.Timer();
        timer.start(method(:exitApp), SEND_TIMEOUT_MS, false);
        _exitTimer = timer;
        _phone.sendPending(method(:exitApp));
    }

    function exitApp() as Void {
        System.exit();
    }

    function discardSession() as Void {
        _recorder.discard();
        System.exit();
    }

    function getState() as SessionState {
        return _state;
    }

    function getMonitor() as SessionMonitor {
        return _monitor;
    }

    function getLearning() as LearningModel {
        return _learning;
    }

    function getSourceLabel() as String? {
        return _sourceLabel;
    }

    // Writes each monitored second to the recording.
    function onMonitorTick() as Void {
        _recorder.update(_monitor);
    }

    private function queueForPhone() as Void {
        var clock = _clock;
        if (clock != null) {
            _outbox.add(SessionMessage.build(clock, Time.now().value(), _monitor));
            _clock = null;
        }
    }

    private function newMonitor() as SessionMonitor {
        var monitor = new SessionMonitor(Config.CALIBRATION_SECONDS, new Vibrator(), _learning, _events);
        monitor.listener = method(:onMonitorTick);
        return monitor;
    }

    private function stopSource() as Void {
        var source = _source;
        if (source != null) {
            source.stop();
        }
    }

    (:release)
    private function createSource(monitor as SessionMonitor) as DataSource {
        return new SensorManager(monitor);
    }

    (:debug)
    private function createSource(monitor as SessionMonitor) as DataSource {
        if (_scenarioIndex == Config.REAL_SENSORS_ID) {
            return new SensorManager(monitor);
        }
        return new ScenarioSource(monitor, Scenarios.all()[_scenarioIndex]);
    }

    // Debug builds: plays the real sensors (index < 0) or the scenario at index. Before the
    // session it starts the session; while running it restarts monitoring with the new source.
    (:debug)
    function selectSource(index as Number) as Void {
        _scenarioIndex = index < 0 ? Config.REAL_SENSORS_ID : index;
        _sourceLabel = index < 0 ? null : Scenarios.all()[index].name;
        if (_state == SESSION_IDLE) {
            startSession();
        } else if (_state == SESSION_RUNNING) {
            stopSource();
            _monitor = newMonitor();
            var source = createSource(_monitor);
            source.start();
            _source = source;
        }
        WatchUi.requestUpdate();
    }
}
