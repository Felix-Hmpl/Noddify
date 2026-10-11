import Toybox.Lang;

// Combines the analyzers, the detector and the alert for one session. Receives one tick per
// second from a DataSource. Has no sensor or UI code, so the unit tests drive it directly.
class SessionMonitor {

    var movement as MovementAnalyzer;
    var heart as HeartAnalyzer;
    var calibrator as Calibrator;
    var detector as DrowsinessDetector;
    var escalation as AlertEscalation;

    private var _vibrator as Vibrator;
    private var _alertCount as Number = 0;

    function initialize(calibrationSeconds as Number, vibrator as Vibrator) {
        movement = new MovementAnalyzer();
        heart = new HeartAnalyzer();
        calibrator = new Calibrator(calibrationSeconds);
        detector = new DrowsinessDetector(new DetectorParams());
        escalation = new AlertEscalation();
        _vibrator = vibrator;
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

        var vibe = escalation.tick();
        if (detector.tick(calibrator.getBaseline(), movement.getStillSeconds(), heart.getAverageHr(), heart.getRmssd())) {
            _alertCount++;
            vibe = escalation.start();
        }
        _vibrator.play(vibe);
    }

    // Called when the wearer reacts to an alert. Returns false if no alert was active.
    function acknowledgeAlert() as Boolean {
        return escalation.acknowledge();
    }

    function isAlerting() as Boolean {
        return escalation.isActive();
    }

    function getAlertCount() as Number {
        return _alertCount;
    }
}
