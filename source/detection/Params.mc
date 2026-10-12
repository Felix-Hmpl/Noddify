import Toybox.Lang;

// Names of the detection parameters.
module Param {
    // Stillness needed before an alert (T_still).
    const STILL_SECONDS = "stillSeconds";
    // Required drop of the 30 s average heart rate below baseline (ΔHR).
    const HR_DROP = "hrDrop";
    // When HRV is at least this many times its baseline, the required drop shrinks by HRV_BOOST_BPM.
    const HRV_BOOST_RATIO = "hrvBoostRatio";
    const HRV_BOOST_BPM = "hrvBoostBpm";
    // The rule must hold this long before the alert fires.
    const CONFIRM_SECONDS = "confirmSeconds";
    // No new alert for this long after one fired.
    const COOLDOWN_SECONDS = "cooldownSeconds";
}

// One adjustable parameter: its default, its limits and how each kind of feedback moves it.
// A step of 0 means feedback doesn't change the parameter.
class ParamSpec {
    var name as String;
    var defaultValue as Float;
    var min as Float;
    var max as Float;
    var stepFalseAlarm as Float;
    var stepConfirmed as Float;
    var stepMissed as Float;

    function initialize(name as String, defaultValue as Numeric, min as Numeric, max as Numeric,
            stepFalseAlarm as Numeric, stepConfirmed as Numeric, stepMissed as Numeric) {
        self.name = name;
        self.defaultValue = defaultValue.toFloat();
        self.min = min.toFloat();
        self.max = max.toFloat();
        self.stepFalseAlarm = stepFalseAlarm.toFloat();
        self.stepConfirmed = stepConfirmed.toFloat();
        self.stepMissed = stepMissed.toFloat();
    }
}

// All detection parameters. To add one, add a line here and read it in a DetectionRule.
// To make one learnable, give it non-zero steps.
class ParamTable {

    static function all() as Array<ParamSpec> {
        return [
            //            name                    default  min    max    false alarm  confirmed  missed
            new ParamSpec(Param.HR_DROP,          6.0,     2.0,   15.0,  1.0,         -0.25,     -1.0),
            new ParamSpec(Param.STILL_SECONDS,    120.0,   60.0,  600.0, 15.0,        -4.0,      -15.0),
            new ParamSpec(Param.HRV_BOOST_RATIO,  1.2,     1.0,   2.0,   0.0,         0.0,       0.0),
            new ParamSpec(Param.HRV_BOOST_BPM,    1.5,     0.0,   4.0,   0.0,         0.0,       0.0),
            new ParamSpec(Param.CONFIRM_SECONDS,  20.0,    5.0,   60.0,  0.0,         0.0,       0.0),
            new ParamSpec(Param.COOLDOWN_SECONDS, 180.0,   60.0,  600.0, 0.0,         0.0,       0.0)
        ];
    }
}

// Current parameter values. Starts at the defaults; set() keeps each value within its limits.
class Params {

    private var _specs as Array<ParamSpec>;
    private var _values as Dictionary<String, Float> = {};

    function initialize() {
        _specs = ParamTable.all();
        resetToDefaults();
    }

    function resetToDefaults() as Void {
        for (var i = 0; i < _specs.size(); i++) {
            _values[_specs[i].name] = _specs[i].defaultValue;
        }
    }

    // A copy of all values by name, e.g. for saving.
    function toDictionary() as Dictionary<String, Float> {
        var copy = {} as Dictionary<String, Float>;
        var names = _values.keys();
        for (var i = 0; i < names.size(); i++) {
            copy[names[i]] = _values[names[i]] as Float;
        }
        return copy;
    }

    function get(name as String) as Float {
        return _values[name] as Float;
    }

    // Sets a value, clamped to the parameter's limits. Unknown names are ignored.
    function set(name as String, value as Float) as Void {
        var spec = getSpec(name);
        if (spec == null) {
            return;
        }
        if (value < spec.min) {
            value = spec.min;
        } else if (value > spec.max) {
            value = spec.max;
        }
        _values[name] = value;
    }

    function getSpec(name as String) as ParamSpec? {
        for (var i = 0; i < _specs.size(); i++) {
            if (_specs[i].name.equals(name)) {
                return _specs[i];
            }
        }
        return null;
    }

    function getSpecs() as Array<ParamSpec> {
        return _specs;
    }
}
