import Toybox.Lang;
import Toybox.Sensor;
import Toybox.Timer;
import Toybox.WatchUi;

// Reads the watch sensors and ticks the SessionMonitor once per second with the heart rate,
// the movement since the last tick and the new beat intervals.
class SensorManager extends DataSource {

    const ACCEL_SAMPLE_RATE = 25;

    private var _monitor as SessionMonitor;
    private var _timer as Timer.Timer? = null;
    private var _pendingMovement as Float? = null;
    private var _pendingIntervals as Array<Number> = [];

    function initialize(monitor as SessionMonitor) {
        DataSource.initialize();
        _monitor = monitor;
    }

    function start() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.registerSensorDataListener(method(:onSensorData), {
            :period => 1,
            :accelerometer => {:enabled => true, :sampleRate => ACCEL_SAMPLE_RATE},
            :heartBeatIntervals => {:enabled => true}
        });
        // A separate timer drives the tick, so the session keeps running even if the
        // simulator never delivers accelerometer batches.
        var timer = new Timer.Timer();
        timer.start(method(:onTick), 1000, true);
        _timer = timer;
    }

    function stop() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
        Sensor.unregisterSensorDataListener();
        Sensor.setEnabledSensors([]);
    }

    function onSensorData(data as Sensor.SensorData) as Void {
        var accel = data.accelerometerData;
        if (accel != null) {
            var movement = MovementAnalyzer.movementOf(accel.x, accel.y, accel.z);
            // The timer and the 1 s batches aren't aligned; if two batches land in one tick, keep the larger.
            var pending = _pendingMovement;
            if (movement != null && (pending == null || movement > pending)) {
                _pendingMovement = movement;
            }
        }
        var heartData = data.heartRateData;
        if (heartData != null) {
            _pendingIntervals.addAll(heartData.heartBeatIntervals);
        }
    }

    function onTick() as Void {
        _monitor.tick(Sensor.getInfo().heartRate, _pendingMovement, _pendingIntervals);
        _pendingMovement = null;
        _pendingIntervals = [];
        WatchUi.requestUpdate();
    }
}
