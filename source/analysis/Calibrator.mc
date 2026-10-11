import Toybox.Lang;

// The wearer's resting values for this session, measured at the start of class.
class Baseline {
    var hr as Float;
    var movement as Float?;
    var hrv as Float?;

    function initialize(hr as Float, movement as Float?, hrv as Float?) {
        self.hr = hr;
        self.movement = movement;
        self.hrv = hrv;
    }
}

// Collects per-second readings during the first minutes of a session and produces the Baseline
// from their medians. Medians ignore a short burst like walking in late or sitting down.
class Calibrator {

    private var _duration as Number;
    private var _elapsed as Number = 0;
    private var _hr as Array<Number> = [];
    private var _movement as Array<Float> = [];
    private var _hrv as Array<Float> = [];
    private var _baseline as Baseline? = null;

    function initialize(durationSeconds as Number) {
        _duration = durationSeconds;
    }

    function addSecond(hr as Number?, movement as Float?, hrv as Float?) as Void {
        if (_baseline != null) {
            return;
        }
        _elapsed++;
        if (hr != null && hr > 0) {
            _hr.add(hr);
        }
        if (movement != null) {
            _movement.add(movement);
        }
        if (hrv != null) {
            _hrv.add(hrv);
        }
        // Keep calibrating past the planned duration until at least half of it had a heart rate.
        if (_elapsed >= _duration && _hr.size() > 0 && _hr.size() >= _duration / 2) {
            _baseline = new Baseline(Stats.median(_hr) as Float, Stats.median(_movement), Stats.median(_hrv));
            _hr = [];
            _movement = [];
            _hrv = [];
        }
    }

    function isCalibrated() as Boolean {
        return _baseline != null;
    }

    function getBaseline() as Baseline? {
        return _baseline;
    }

    function getElapsed() as Number {
        return _elapsed;
    }

    function getDuration() as Number {
        return _duration;
    }
}
