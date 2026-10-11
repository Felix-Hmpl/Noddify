import Toybox.Lang;

enum DetectorState {
    STATE_CALIBRATING,
    // Calibrated, conditions for drowsiness not met.
    STATE_AWAKE,
    // Conditions met, waiting for them to hold long enough.
    STATE_DROWSY,
    // An alert fired recently; no new alert until the cooldown is over.
    STATE_COOLDOWN
}

// The tunable thresholds. The learning model will adjust them from feedback in step 4.
class DetectorParams {
    // Stillness needed before an alert (T_still).
    var stillSeconds as Number = 120;
    // Required drop of the 30 s average heart rate below baseline (ΔHR).
    var hrDrop as Float = 6.0;
    // When RMSSD is at least this many times its baseline, the required drop shrinks by hrvBoostBpm.
    var hrvBoostRatio as Float = 1.2;
    var hrvBoostBpm as Float = 1.5;
    // The conditions must hold this long before the alert fires.
    var confirmSeconds as Number = 20;
    // No new alert for this long after one fired.
    var cooldownSeconds as Number = 180;

    function initialize() {
    }
}

// Decides once per second whether the wearer is nodding off: still for long enough and
// heart rate clearly below the session baseline, sustained for confirmSeconds.
class DrowsinessDetector {

    var params as DetectorParams;

    private var _state as DetectorState = STATE_CALIBRATING;
    private var _confirmedSeconds as Number = 0;
    private var _cooldownRemaining as Number = 0;

    function initialize(params as DetectorParams) {
        self.params = params;
    }

    // Returns true on the second an alert should fire.
    function tick(baseline as Baseline?, stillSeconds as Number, averageHr as Float?, rmssd as Float?) as Boolean {
        if (baseline == null) {
            _state = STATE_CALIBRATING;
            return false;
        }
        if (_cooldownRemaining > 0) {
            _cooldownRemaining--;
            _confirmedSeconds = 0;
            _state = STATE_COOLDOWN;
            return false;
        }
        if (!conditionsMet(baseline, stillSeconds, averageHr, rmssd)) {
            _confirmedSeconds = 0;
            _state = STATE_AWAKE;
            return false;
        }
        _confirmedSeconds++;
        if (_confirmedSeconds < params.confirmSeconds) {
            _state = STATE_DROWSY;
            return false;
        }
        _confirmedSeconds = 0;
        _cooldownRemaining = params.cooldownSeconds;
        _state = STATE_COOLDOWN;
        return true;
    }

    function conditionsMet(baseline as Baseline, stillSeconds as Number, averageHr as Float?, rmssd as Float?) as Boolean {
        if (stillSeconds < params.stillSeconds || averageHr == null) {
            return false;
        }
        return baseline.hr - averageHr >= requiredHrDrop(baseline, rmssd);
    }

    // A rise in HRV is an early sign of sleepiness, so it lowers the heart-rate drop needed.
    function requiredHrDrop(baseline as Baseline, rmssd as Float?) as Float {
        var baselineHrv = baseline.hrv;
        if (rmssd != null && baselineHrv != null && baselineHrv > 0 && rmssd >= baselineHrv * params.hrvBoostRatio) {
            return params.hrDrop - params.hrvBoostBpm;
        }
        return params.hrDrop;
    }

    function getState() as DetectorState {
        return _state;
    }
}
