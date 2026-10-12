import Toybox.Lang;

// Decides from one second's features whether the wearer looks drowsy right now. To try another
// detection method, subclass this and pass it to the DrowsinessDetector; confirmation and
// cooldown stay the same for every rule.
class DetectionRule {

    function initialize() {
    }

    function isMet(features as FeatureSnapshot, params as Params) as Boolean {
        return false;
    }
}

// Still for long enough and the heart rate clearly below baseline. A rise in HRV is an early
// sign of sleepiness, so it lowers the heart-rate drop needed.
class StillnessHeartRateRule extends DetectionRule {

    function initialize() {
        DetectionRule.initialize();
    }

    function isMet(features as FeatureSnapshot, params as Params) as Boolean {
        var still = features.get(Feature.STILL_SECONDS);
        var drop = features.get(Feature.HR_DROP);
        if (still == null || drop == null || still < params.get(Param.STILL_SECONDS)) {
            return false;
        }
        return drop >= requiredHrDrop(features, params);
    }

    function requiredHrDrop(features as FeatureSnapshot, params as Params) as Float {
        var hrvRatio = features.get(Feature.HRV_RATIO);
        if (hrvRatio != null && hrvRatio >= params.get(Param.HRV_BOOST_RATIO)) {
            return params.get(Param.HR_DROP) - params.get(Param.HRV_BOOST_BPM);
        }
        return params.get(Param.HR_DROP);
    }
}
