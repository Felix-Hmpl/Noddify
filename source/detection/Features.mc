import Toybox.Lang;

// Names of the features a detection rule can use. Strings rather than symbols, so snapshots
// can be saved to Application.Storage and the activity recording as they are.
module Feature {
    // Seconds since the last real movement.
    const STILL_SECONDS = "stillSeconds";
    // Session baseline heart rate minus the 30 s average (bpm). Positive = below baseline.
    const HR_DROP = "hrDrop";
    // RMSSD divided by the baseline RMSSD. Above 1 = more variability than at rest.
    const HRV_RATIO = "hrvRatio";
    // Movement bursts per minute over the last 5 minutes.
    const FIDGETS_PER_MINUTE = "fidgetsPerMinute";
    // 30 s average heart rate (bpm).
    const AVERAGE_HR = "averageHr";
}

// The feature values for one second, by name. A value is null while it isn't available,
// e.g. everything relative to the baseline during calibration, or HRV without beat intervals.
class FeatureSnapshot {

    private var _calibrated as Boolean;
    private var _values as Dictionary<String, Float?>;

    function initialize(calibrated as Boolean, values as Dictionary<String, Float?>) {
        _calibrated = calibrated;
        _values = values;
    }

    function isCalibrated() as Boolean {
        return _calibrated;
    }

    function get(name as String) as Float? {
        return _values[name] as Float?;
    }

    function toDictionary() as Dictionary<String, Float?> {
        return _values;
    }
}
