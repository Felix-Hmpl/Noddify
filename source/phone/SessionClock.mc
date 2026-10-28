import Toybox.Lang;

// Wall-clock times of a session: when it started and when it was paused. The monitor counts
// session seconds only while running, so the phone needs the pauses to place each second in time.
// Times are Unix seconds (Time.now().value()), passed in so the tests can choose them.
class SessionClock {

    var startTime as Number;

    // Each pause as [session second it started at, length in seconds].
    private var _pauses as Array<Array<Number>> = [];
    private var _pausedAt as Number? = null;

    function initialize(now as Number) {
        startTime = now;
    }

    function pause(now as Number) as Void {
        if (_pausedAt == null) {
            _pausedAt = now;
        }
    }

    function resume(now as Number, sessionSecond as Number) as Void {
        var pausedAt = _pausedAt;
        if (pausedAt != null) {
            _pauses.add([sessionSecond, now - pausedAt]);
            _pausedAt = null;
        }
    }

    function getPauses() as Array<Array<Number>> {
        return _pauses;
    }

    // When the session ended: the moment it was stopped, or now if it is still running.
    // The time spent in the menu between stopping and saving doesn't count.
    function getEndTime(now as Number) as Number {
        var pausedAt = _pausedAt;
        return pausedAt != null ? pausedAt : now;
    }
}
