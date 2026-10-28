import Toybox.Lang;

// The message that sends a saved session to the Noddify phone app. The format is shared with
// android/core (SessionMessageParser): bump VERSION when a key changes meaning, add keys freely.
//
//   type        "session"
//   v           format version
//   id          the session's id, its start time (Unix seconds)
//   start, end  wall-clock start and end (Unix seconds)
//   seconds     monitored session seconds (pauses excluded)
//   calibrated  session second when calibration finished; missing if it never did
//   baselineHr, baselineHrv   the session baseline; missing if unavailable
//   params      learned parameters at the end: stillSeconds, hrDrop
//   pauses      [[session second, length in seconds], ...]
//   events      [{"s": session second, "c": RecordEvent code, ...}, ...] with, for alerts,
//               "still" (seconds) and "drop" (bpm below baseline) and, for naps, "min" (minutes)
module SessionMessage {

    const TYPE = "session";
    const VERSION = 1;

    function build(clock as SessionClock, now as Number, monitor as SessionMonitor) as Dictionary {
        var params = monitor.detector.params;
        var message = {
            "type" => TYPE,
            "v" => VERSION,
            "id" => clock.startTime,
            "start" => clock.startTime,
            "end" => clock.getEndTime(now),
            "seconds" => monitor.getSecond(),
            "params" => {
                Param.STILL_SECONDS => params.get(Param.STILL_SECONDS),
                Param.HR_DROP => params.get(Param.HR_DROP)
            },
            "pauses" => clock.getPauses(),
            "events" => monitor.getSessionEvents()
        } as Dictionary;
        if (monitor.calibrator.isCalibrated()) {
            message["calibrated"] = monitor.calibrator.getElapsed();
        }
        var baseline = monitor.calibrator.getBaseline();
        if (baseline != null) {
            message["baselineHr"] = baseline.hr;
            var hrv = baseline.hrv;
            if (hrv != null) {
                message["baselineHrv"] = hrv;
            }
        }
        return message;
    }
}
