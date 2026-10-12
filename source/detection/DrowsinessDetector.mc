import Toybox.Lang;

enum DetectorState {
    STATE_CALIBRATING,
    // Calibrated, the rule isn't met.
    STATE_AWAKE,
    // The rule is met, waiting for it to hold long enough.
    STATE_DROWSY,
    // An alert fired recently; no new alert until the cooldown is over.
    STATE_COOLDOWN
}

// Decides once per second whether to alert. The DetectionRule says whether the wearer looks
// drowsy; the detector requires that to hold for CONFIRM_SECONDS and then waits out a cooldown.
class DrowsinessDetector {

    var params as Params;
    var rule as DetectionRule;

    private var _state as DetectorState = STATE_CALIBRATING;
    private var _confirmedSeconds as Number = 0;
    private var _cooldownRemaining as Number = 0;

    function initialize(rule as DetectionRule, params as Params) {
        self.rule = rule;
        self.params = params;
    }

    // Returns true on the second an alert should fire.
    function tick(features as FeatureSnapshot) as Boolean {
        if (!features.isCalibrated()) {
            _state = STATE_CALIBRATING;
            return false;
        }
        if (_cooldownRemaining > 0) {
            _cooldownRemaining--;
            _confirmedSeconds = 0;
            _state = STATE_COOLDOWN;
            return false;
        }
        if (!rule.isMet(features, params)) {
            _confirmedSeconds = 0;
            _state = STATE_AWAKE;
            return false;
        }
        _confirmedSeconds++;
        if (_confirmedSeconds < params.get(Param.CONFIRM_SECONDS)) {
            _state = STATE_DROWSY;
            return false;
        }
        _confirmedSeconds = 0;
        _cooldownRemaining = params.get(Param.COOLDOWN_SECONDS).toNumber();
        _state = STATE_COOLDOWN;
        return true;
    }

    function getState() as DetectorState {
        return _state;
    }
}
