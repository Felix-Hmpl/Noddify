import Toybox.Lang;

// Combines the analyzers, the detector and the alert for one session. Receives one tick per
// second from a DataSource. Has no sensor or UI code, so the unit tests drive it directly.
class SessionMonitor {

    var movement as MovementAnalyzer;
    var heart as HeartAnalyzer;
    var calibrator as Calibrator;
    var detector as DrowsinessDetector;
    var escalation as AlertEscalation;
    // Called after every tick, e.g. to write the second to the activity recording.
    var listener as Method? = null;

    private var _vibrator as Vibrator;
    private var _learning as LearningModel;
    private var _events as EventLog;
    private var _second as Number = 0;
    // Session seconds at which alerts fired, and the features of the latest one.
    private var _alertSeconds as Array<Number> = [];
    private var _lastAlertFeatures as FeatureSnapshot? = null;
    // Events of this session by type, for the summary.
    private var _eventCounts as Dictionary<String, Number> = {};
    // Events not yet handed to the recording, each [RecordEvent code, nap minutes].
    private var _recordEvents as Array<Array<Number>> = [];
    // Events of this session for the phone app, see SessionMessage.
    private var _sessionEvents as Array<Dictionary> = [];

    function initialize(calibrationSeconds as Number, vibrator as Vibrator, learning as LearningModel, events as EventLog) {
        movement = new MovementAnalyzer();
        heart = new HeartAnalyzer();
        calibrator = new Calibrator(calibrationSeconds);
        detector = new DrowsinessDetector(new StillnessHeartRateRule(), learning.params);
        escalation = new AlertEscalation();
        _vibrator = vibrator;
        _learning = learning;
        _events = events;
    }

    function tick(hr as Number?, movementValue as Float?, beatIntervals as Array<Number>) as Void {
        _second++;
        heart.addBeatIntervals(beatIntervals);
        heart.addHeartRate(hr);
        movement.addSecond(movementValue);

        if (!calibrator.isCalibrated()) {
            calibrator.addSecond(hr, movementValue, heart.getRmssd());
            var baseline = calibrator.getBaseline();
            var baselineMovement = baseline != null ? baseline.movement : null;
            if (baselineMovement != null) {
                movement.setBaseline(baselineMovement, Config.STILL_FACTOR);
            }
        }

        var wasAlerting = escalation.isActive();
        var vibe = escalation.tick();
        if (wasAlerting && !escalation.isActive() && escalation.wasUnanswered()) {
            logEvent(EventType.UNANSWERED, _lastAlertFeatures, null);
        }

        var features = getFeatures();
        if (detector.tick(features)) {
            _alertSeconds.add(_second);
            _lastAlertFeatures = features;
            logEvent(EventType.ALERT, features, null);
            vibe = escalation.start();
        }
        _vibrator.play(vibe);

        var callback = listener;
        if (callback != null) {
            callback.invoke();
        }
    }

    // The current values of all features. New features are added here and in the Feature module.
    function getFeatures() as FeatureSnapshot {
        var baseline = calibrator.getBaseline();
        var averageHr = heart.getAverageHr();
        var rmssd = heart.getRmssd();
        var hrDrop = null;
        var hrvRatio = null;
        if (baseline != null) {
            if (averageHr != null) {
                hrDrop = baseline.hr - averageHr;
            }
            var baselineHrv = baseline.hrv;
            if (rmssd != null && baselineHrv != null && baselineHrv > 0) {
                hrvRatio = rmssd / baselineHrv;
            }
        }
        return new FeatureSnapshot(baseline != null, {
            Feature.STILL_SECONDS => movement.getStillSeconds().toFloat(),
            Feature.HR_DROP => hrDrop,
            Feature.HRV_RATIO => hrvRatio,
            Feature.FIDGETS_PER_MINUTE => movement.getFidgetsPerMinute(),
            Feature.AVERAGE_HR => averageHr
        });
    }

    // Called when the wearer reacts to an alert. Returns false if no alert was active.
    function acknowledgeAlert() as Boolean {
        return escalation.acknowledge();
    }

    // The answer to "Were you dozing off?" for the latest alert.
    function answerAlert(wasDozing as Boolean) as Void {
        logEvent(wasDozing ? EventType.ANSWER_YES : EventType.ANSWER_NO, _lastAlertFeatures, null);
        _learning.apply(wasDozing ? FEEDBACK_CONFIRMED : FEEDBACK_FALSE_ALARM);
    }

    // A nap the wearer logged, ending now and lasting about the given minutes. If an alert fired
    // during it, the alert was late; otherwise the nap was missed.
    function logNap(minutes as Number) as Void {
        var napStart = _second - minutes * 60;
        var alerted = false;
        for (var i = 0; i < _alertSeconds.size(); i++) {
            if (_alertSeconds[i] >= napStart) {
                alerted = true;
            }
        }
        logEvent(EventType.NAP, getFeatures(), {"minutes" => minutes, "alerted" => alerted});
        _learning.apply(alerted ? FEEDBACK_LATE : FEEDBACK_MISSED);
    }

    function isAlerting() as Boolean {
        return escalation.isActive();
    }

    function getAlertCount() as Number {
        return _alertSeconds.size();
    }

    // How many events of the given type (see EventType) happened in this session.
    function getEventCount(type as String) as Number {
        var count = _eventCounts[type];
        return count != null ? count : 0;
    }

    function getSecond() as Number {
        return _second;
    }

    // The events since the last call, each [RecordEvent code, nap minutes], for the recording.
    function takeRecordEvents() as Array<Array<Number>> {
        var events = _recordEvents;
        _recordEvents = [];
        return events;
    }

    // The events of this session for the phone app, as described in SessionMessage.
    function getSessionEvents() as Array<Dictionary> {
        return _sessionEvents;
    }

    private function logEvent(type as String, features as FeatureSnapshot?, extra as Dictionary?) as Void {
        _events.add(type, _second, features, extra);
        _eventCounts[type] = getEventCount(type) + 1;
        var napMinutes = extra != null && extra["minutes"] != null ? extra["minutes"] as Number : 0;
        var code = RecordEvent.codeOf(type);
        _recordEvents.add([code, napMinutes]);

        var event = {"s" => _second, "c" => code} as Dictionary;
        if (code == RecordEvent.ALERT && features != null) {
            var still = features.get(Feature.STILL_SECONDS);
            var drop = features.get(Feature.HR_DROP);
            if (still != null) {
                event["still"] = still.toNumber();
            }
            if (drop != null) {
                event["drop"] = drop;
            }
        } else if (code == RecordEvent.NAP) {
            event["min"] = napMinutes;
        }
        _sessionEvents.add(event);
    }
}
