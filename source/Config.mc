import Toybox.Lang;

// App-wide defaults. The learning model will take over the tunable ones in step 4.
module Config {

    // Debug builds (simulator, F5) calibrate quickly so testing doesn't take 5 minutes.
    (:debug) const CALIBRATION_SECONDS = 30;
    (:release) const CALIBRATION_SECONDS = 300;

    // Debug scenarios: scenario seconds per real second, and the menu id for the real sensors.
    (:debug) const SCENARIO_SPEED = 5;
    (:debug) const REAL_SENSORS_ID = -1;

    // Movement below baseline x this factor counts as still.
    const STILL_FACTOR = 1.5;
}
