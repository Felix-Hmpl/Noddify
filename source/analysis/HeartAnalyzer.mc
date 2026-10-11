import Toybox.Lang;
import Toybox.Math;

// Smooths the heart rate and computes heart-rate variability (RMSSD) from beat-to-beat intervals.
class HeartAnalyzer {

    const AVERAGE_WINDOW_SECONDS = 30;
    const HRV_WINDOW_MS = 60000;
    // Intervals outside this range are sensor artifacts: 300 ms = 200 bpm, 2000 ms = 30 bpm.
    const MIN_INTERVAL_MS = 300;
    const MAX_INTERVAL_MS = 2000;
    // An interval differing from the previous one by more than this fraction is a missed or extra beat.
    const MAX_SUCCESSIVE_CHANGE = 0.2;
    // Fewer intervals than this give no meaningful RMSSD.
    const MIN_INTERVALS_FOR_HRV = 20;

    private var _currentHr as Number? = null;
    private var _hrWindow as Array<Number> = [];
    private var _intervals as Array<Number> = [];
    private var _intervalsTotalMs as Number = 0;
    private var _lastRawInterval as Number? = null;

    function initialize() {
    }

    // Records the heart rate for one second. Null or 0 (no reading) is ignored for the average.
    function addHeartRate(hr as Number?) as Void {
        _currentHr = hr;
        if (hr == null || hr <= 0) {
            return;
        }
        _hrWindow.add(hr);
        if (_hrWindow.size() > AVERAGE_WINDOW_SECONDS) {
            _hrWindow = _hrWindow.slice(1, null);
        }
    }

    function addBeatIntervals(intervals as Array<Number>) as Void {
        for (var i = 0; i < intervals.size(); i++) {
            addBeatInterval(intervals[i]);
        }
    }

    function addBeatInterval(interval as Number) as Void {
        if (interval < MIN_INTERVAL_MS || interval > MAX_INTERVAL_MS) {
            return;
        }
        // Compare against the previous raw interval, not the last accepted one, so a real
        // change in rhythm is accepted again after one rejected beat instead of stalling.
        var previous = _lastRawInterval;
        _lastRawInterval = interval;
        if (previous != null && (interval - previous).abs() > previous * MAX_SUCCESSIVE_CHANGE) {
            return;
        }
        _intervals.add(interval);
        _intervalsTotalMs += interval;
        while (_intervalsTotalMs > HRV_WINDOW_MS) {
            _intervalsTotalMs -= _intervals[0];
            _intervals = _intervals.slice(1, null);
        }
    }

    function getCurrentHr() as Number? {
        return _currentHr;
    }

    // Mean heart rate over the last 30 readings, or null before the first reading.
    function getAverageHr() as Float? {
        var n = _hrWindow.size();
        if (n == 0) {
            return null;
        }
        var sum = 0.0;
        for (var i = 0; i < n; i++) {
            sum += _hrWindow[i];
        }
        return sum / n;
    }

    // Root mean square of successive interval differences (ms) over the last minute.
    // Null until enough clean intervals are available.
    function getRmssd() as Float? {
        var n = _intervals.size();
        if (n < MIN_INTERVALS_FOR_HRV) {
            return null;
        }
        var sumSquares = 0.0;
        for (var i = 1; i < n; i++) {
            var diff = _intervals[i] - _intervals[i - 1];
            sumSquares += diff * diff;
        }
        return Math.sqrt(sumSquares / (n - 1)).toFloat();
    }

    function getIntervalCount() as Number {
        return _intervals.size();
    }
}
