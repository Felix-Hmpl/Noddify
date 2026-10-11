import Toybox.Lang;

// Combines the analyzers for one session. Receives one tick per second from the SensorManager.
// Has no sensor or UI code, so the unit tests drive it directly.
class SessionMonitor {

    var movement as MovementAnalyzer;
    var heart as HeartAnalyzer;
    var calibrator as Calibrator;

    function initialize(calibrationSeconds as Number) {
        movement = new MovementAnalyzer();
        heart = new HeartAnalyzer();
        calibrator = new Calibrator(calibrationSeconds);
    }

    function tick(hr as Number?, movementValue as Float?, beatIntervals as Array<Number>) as Void {
        heart.addBeatIntervals(beatIntervals);
        heart.addHeartRate(hr);
        movement.addSecond(movementValue);

        if (!calibrator.isCalibrated()) {
            calibrator.addSecond(hr, movementValue, heart.getRmssd());
            var baseline = calibrator.getBaseline();
            var baselineMovement = baseline != null ? baseline.movement : null;
            if (baselineMovement != null) {
                movement.setBaseline(baselineMovement, Config.STILL_FACTOR);
            }
        }
    }
}
