import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;

enum FeedbackKind {
    // "Were you dozing off?" → No.
    FEEDBACK_FALSE_ALARM,
    // "Were you dozing off?" → Yes.
    FEEDBACK_CONFIRMED,
    // A logged nap without any alert during it.
    FEEDBACK_MISSED,
    // A logged nap with an alert during it: the alert came, but too late.
    FEEDBACK_LATE
}

// Adjusts the detection parameters from feedback and saves them on the watch.
// Works only from the step sizes in the ParamTable, so it has no code for individual parameters.
// Each step is scaled by 1 / sqrt(1 + n) for the n-th feedback, but never below MIN_STEP_FACTOR,
// so the values settle over time yet can still follow real changes.
class LearningModel {

    const MIN_STEP_FACTOR = 0.25;
    const LATE_FACTOR = 0.5;
    const FORMAT_VERSION = 1;

    var params as Params;

    private var _storageKey as String?;
    private var _feedbackCount as Number = 0;

    // storageKey: where to save in Application.Storage, or null to keep everything in memory (tests).
    function initialize(storageKey as String?) {
        _storageKey = storageKey;
        params = new Params();
        load();
    }

    function apply(kind as FeedbackKind) as Void {
        var factor = getStepFactor();
        var specs = params.getSpecs();
        for (var i = 0; i < specs.size(); i++) {
            var step = stepFor(specs[i], kind);
            if (step != 0.0) {
                params.set(specs[i].name, params.get(specs[i].name) + step * factor);
            }
        }
        _feedbackCount++;
        save();
    }

    function getStepFactor() as Float {
        var factor = 1.0 / Math.sqrt(1 + _feedbackCount);
        return factor > MIN_STEP_FACTOR ? factor.toFloat() : MIN_STEP_FACTOR;
    }

    function getFeedbackCount() as Number {
        return _feedbackCount;
    }

    // Back to the defaults, as if no feedback had been given.
    function reset() as Void {
        params.resetToDefaults();
        _feedbackCount = 0;
        save();
    }

    private function stepFor(spec as ParamSpec, kind as FeedbackKind) as Float {
        switch (kind) {
            case FEEDBACK_FALSE_ALARM:
                return spec.stepFalseAlarm;
            case FEEDBACK_CONFIRMED:
                return spec.stepConfirmed;
            case FEEDBACK_MISSED:
                return spec.stepMissed;
            default:
                return spec.stepMissed * LATE_FACTOR;
        }
    }

    private function save() as Void {
        var key = _storageKey;
        if (key == null) {
            return;
        }
        Storage.setValue(key, {
            "version" => FORMAT_VERSION,
            "feedbackCount" => _feedbackCount,
            "params" => params.toDictionary()
        });
    }

    // Restores saved values. Parameters added to the table after saving keep their defaults.
    private function load() as Void {
        var key = _storageKey;
        if (key == null) {
            return;
        }
        var data = Storage.getValue(key) as Dictionary?;
        if (data == null) {
            return;
        }
        var count = data["feedbackCount"];
        if (count instanceof Number) {
            _feedbackCount = count;
        }
        var saved = data["params"];
        if (saved instanceof Dictionary) {
            var names = saved.keys();
            for (var i = 0; i < names.size(); i++) {
                var value = saved[names[i]];
                if (names[i] instanceof String && value instanceof Float) {
                    params.set(names[i] as String, value);
                }
            }
        }
    }
}
