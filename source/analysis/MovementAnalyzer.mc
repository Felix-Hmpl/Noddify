import Toybox.Lang;

// Turns accelerometer samples into one movement value per second and tracks
// how long the wearer has been still.
class MovementAnalyzer {

    // Movement (milli-g) below which a second counts as still, until calibration sets a personal threshold.
    const DEFAULT_THRESHOLD = 40.0;
    // The personal threshold never drops below this, so sensor noise can't make stillness unreachable.
    const MIN_THRESHOLD = 15.0;
    // Movement shorter than this many seconds (a twitch, a nod) doesn't reset the stillness timer.
    const RESET_AFTER_MOVING_SECONDS = 3;
    // Movement this many times above the threshold resets the timer immediately.
    const BIG_MOVE_FACTOR = 4.0;

    private var _threshold as Float = DEFAULT_THRESHOLD;
    private var _stillSeconds as Number = 0;
    private var _movingStreak as Number = 0;
    private var _lastMovement as Float? = null;

    function initialize() {
    }

    // Movement in one batch of samples (milli-g): the sum over the axes of each axis's mean absolute
    // deviation. Taking the deviation per axis removes gravity but still catches slow wrist rotation.
    // Returns null when there are no samples.
    static function movementOf(x as Array<Number>, y as Array<Number>, z as Array<Number>) as Float? {
        if (x.size() == 0 || y.size() == 0 || z.size() == 0) {
            return null;
        }
        return meanAbsDeviation(x) + meanAbsDeviation(y) + meanAbsDeviation(z);
    }

    static function meanAbsDeviation(values as Array<Number>) as Float {
        var n = values.size();
        var sum = 0.0;
        for (var i = 0; i < n; i++) {
            sum += values[i];
        }
        var mean = sum / n;
        var deviation = 0.0;
        for (var i = 0; i < n; i++) {
            deviation += (values[i] - mean).abs();
        }
        return deviation / n;
    }

    // Records one second. Missing data (null, e.g. in the simulator) counts as still; the
    // heart-rate condition still has to hold before anything alerts.
    function addSecond(movement as Float?) as Void {
        _lastMovement = movement;
        if (movement == null || movement < _threshold) {
            _stillSeconds++;
            _movingStreak = 0;
            return;
        }
        _movingStreak++;
        if (_movingStreak >= RESET_AFTER_MOVING_SECONDS || movement >= _threshold * BIG_MOVE_FACTOR) {
            _stillSeconds = 0;
        }
    }

    // Sets the personal still threshold from the calibrated baseline movement.
    function setBaseline(baselineMovement as Float, stillFactor as Float) as Void {
        var threshold = baselineMovement * stillFactor;
        _threshold = threshold > MIN_THRESHOLD ? threshold : MIN_THRESHOLD;
    }

    function getStillSeconds() as Number {
        return _stillSeconds;
    }

    function getThreshold() as Float {
        return _threshold;
    }

    function getLastMovement() as Float? {
        return _lastMovement;
    }
}
