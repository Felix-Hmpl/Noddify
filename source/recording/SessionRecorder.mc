import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Records the session as a Garmin activity (type "Other") with Noddify's data in custom fields.
// Heart rate is recorded by the watch itself; every other value is written once per second
// by update(). Unavailable values (e.g. the baseline during calibration) are written as 0.
//
// Field ids and meanings are part of the recorded data: never reuse or renumber an id,
// add new fields with new ids.
class SessionRecorder {

    // State codes in the "state" field: the DetectorState values, plus one for an active alert.
    const STATE_ALERTING = 4;

    private var _session as ActivityRecording.Session? = null;
    private var _eventQueue as RecordEventQueue = new RecordEventQueue();

    // Per-second fields.
    private var _movement as FitContributor.Field? = null;
    private var _stillSeconds as FitContributor.Field? = null;
    private var _fidgets as FitContributor.Field? = null;
    private var _rmssd as FitContributor.Field? = null;
    private var _baselineHr as FitContributor.Field? = null;
    private var _baselineHrv as FitContributor.Field? = null;
    private var _hrDropThreshold as FitContributor.Field? = null;
    private var _stillThreshold as FitContributor.Field? = null;
    private var _state as FitContributor.Field? = null;
    private var _event as FitContributor.Field? = null;
    private var _napMinutes as FitContributor.Field? = null;

    // Per-session fields.
    private var _alerts as FitContributor.Field? = null;
    private var _answersYes as FitContributor.Field? = null;
    private var _answersNo as FitContributor.Field? = null;
    private var _unanswered as FitContributor.Field? = null;
    private var _naps as FitContributor.Field? = null;
    private var _sessionBaselineHr as FitContributor.Field? = null;

    function initialize() {
    }

    function start() as Void {
        var session = ActivityRecording.createSession({
            :name => "Noddify",
            :sport => Activity.SPORT_GENERIC,
            :subSport => Activity.SUB_SPORT_GENERIC
        });
        var record = {:mesgType => FitContributor.MESG_TYPE_RECORD};
        _movement = session.createField("movement", 0, FitContributor.DATA_TYPE_UINT16, withUnits(record, "mg"));
        _stillSeconds = session.createField("still_seconds", 1, FitContributor.DATA_TYPE_UINT16, withUnits(record, "s"));
        _fidgets = session.createField("fidgets", 2, FitContributor.DATA_TYPE_FLOAT, withUnits(record, "/min"));
        _rmssd = session.createField("rmssd", 3, FitContributor.DATA_TYPE_UINT16, withUnits(record, "ms"));
        _baselineHr = session.createField("baseline_hr", 4, FitContributor.DATA_TYPE_UINT8, withUnits(record, "bpm"));
        _baselineHrv = session.createField("baseline_hrv", 5, FitContributor.DATA_TYPE_UINT16, withUnits(record, "ms"));
        _hrDropThreshold = session.createField("hr_drop_threshold", 6, FitContributor.DATA_TYPE_FLOAT, withUnits(record, "bpm"));
        _stillThreshold = session.createField("still_threshold", 7, FitContributor.DATA_TYPE_UINT16, withUnits(record, "s"));
        _state = session.createField("state", 8, FitContributor.DATA_TYPE_UINT8, record);
        _event = session.createField("event", 9, FitContributor.DATA_TYPE_UINT8, record);
        _napMinutes = session.createField("nap_minutes", 10, FitContributor.DATA_TYPE_UINT8, withUnits(record, "min"));

        var summary = {:mesgType => FitContributor.MESG_TYPE_SESSION};
        _alerts = session.createField("alerts", 20, FitContributor.DATA_TYPE_UINT16, summary);
        _answersYes = session.createField("answers_yes", 21, FitContributor.DATA_TYPE_UINT16, summary);
        _answersNo = session.createField("answers_no", 22, FitContributor.DATA_TYPE_UINT16, summary);
        _unanswered = session.createField("unanswered", 23, FitContributor.DATA_TYPE_UINT16, summary);
        _naps = session.createField("naps", 24, FitContributor.DATA_TYPE_UINT16, summary);
        _sessionBaselineHr = session.createField("baseline_hr", 25, FitContributor.DATA_TYPE_UINT8, withUnits(summary, "bpm"));

        session.start();
        _session = session;
    }

    // Writes the current second. The watch stores the field values with its next record.
    function update(monitor as SessionMonitor) as Void {
        if (!isRecording()) {
            return;
        }
        var features = monitor.getFeatures();
        var params = monitor.detector.params;
        var baseline = monitor.calibrator.getBaseline();

        setData(_movement, toUint16(monitor.movement.getLastMovement()));
        setData(_stillSeconds, toUint16(monitor.movement.getStillSeconds()));
        setData(_fidgets, orZero(features.get(Feature.FIDGETS_PER_MINUTE)));
        setData(_rmssd, toUint16(monitor.heart.getRmssd()));
        setData(_baselineHr, toUint8(baseline != null ? baseline.hr : null));
        setData(_baselineHrv, toUint16(baseline != null ? baseline.hrv : null));
        setData(_hrDropThreshold, params.get(Param.HR_DROP));
        setData(_stillThreshold, toUint16(params.get(Param.STILL_SECONDS)));
        setData(_state, monitor.isAlerting() ? STATE_ALERTING : monitor.detector.getState() as Number);
        _eventQueue.add(monitor.takeRecordEvents());
        var event = _eventQueue.current(System.getTimer());
        setData(_event, event[0]);
        setData(_napMinutes, event[1]);
    }

    function isRecording() as Boolean {
        var session = _session;
        return session != null && session.isRecording();
    }

    // True from start() until the session is saved or discarded.
    function isActive() as Boolean {
        return _session != null;
    }

    function stop() as Void {
        var session = _session;
        if (session != null && session.isRecording()) {
            session.stop();
        }
    }

    function resume() as Void {
        var session = _session;
        if (session != null && !session.isRecording()) {
            session.start();
        }
    }

    // Writes the session summary and saves the activity, so it syncs to Garmin Connect.
    function save(monitor as SessionMonitor) as Void {
        var session = _session;
        if (session == null) {
            return;
        }
        var baseline = monitor.calibrator.getBaseline();
        setData(_alerts, monitor.getEventCount(EventType.ALERT));
        setData(_answersYes, monitor.getEventCount(EventType.ANSWER_YES));
        setData(_answersNo, monitor.getEventCount(EventType.ANSWER_NO));
        setData(_unanswered, monitor.getEventCount(EventType.UNANSWERED));
        setData(_naps, monitor.getEventCount(EventType.NAP));
        setData(_sessionBaselineHr, toUint8(baseline != null ? baseline.hr : null));
        stop();
        session.save();
        _session = null;
    }

    function discard() as Void {
        var session = _session;
        if (session == null) {
            return;
        }
        stop();
        session.discard();
        _session = null;
    }

    private function withUnits(options as Dictionary, units as String) as Dictionary {
        return {:mesgType => options[:mesgType], :units => units};
    }

    private function setData(field as FitContributor.Field?, value as Numeric) as Void {
        if (field != null) {
            field.setData(value);
        }
    }

    private function orZero(value as Float?) as Float {
        return value != null ? value : 0.0;
    }

    // Rounds to an unsigned integer that fits the field; 0 when unavailable. The largest value
    // of each type is left free, since FIT uses it to mean "invalid".
    private function toUint16(value as Numeric?) as Number {
        return clampRounded(value, 65534);
    }

    private function toUint8(value as Numeric?) as Number {
        return clampRounded(value, 254);
    }

    private function clampRounded(value as Numeric?, max as Number) as Number {
        if (value == null) {
            return 0;
        }
        var rounded = Math.round(value.toFloat()).toNumber();
        if (rounded < 0) {
            return 0;
        }
        return rounded > max ? max : rounded;
    }
}
