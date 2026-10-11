import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Live screen: detector state or calibration progress, current heart rate, average and baseline,
// stillness bar and HRV, plus the scenario name when a debug scenario replaces the sensors.
// Turns red while an alert is active.
class MainView extends WatchUi.View {

    const BAR_HEIGHT = 8;
    const BAR_LABEL_GAP = 4;

    private var _monitor as SessionMonitor;

    function initialize() {
        View.initialize();
        _monitor = getApp().getMonitor();
    }

    function onUpdate(dc as Dc) as Void {
        // The app replaces the monitor when a debug scenario is selected.
        var app = getApp();
        _monitor = app.getMonitor();
        var sourceLabel = app.getSourceLabel();

        var alerting = _monitor.isAlerting();
        var background = alerting ? Graphics.COLOR_DK_RED : Graphics.COLOR_BLACK;
        dc.setColor(background, background);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var heart = _monitor.heart;
        var baseline = _monitor.calibrator.getBaseline();

        // Rows are stacked by their font heights and the whole block is centered, so rows
        // can't overlap regardless of the device's font sizes.
        var headerHeight = dc.getFontHeight(Graphics.FONT_TINY);
        var hrHeight = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        var smallHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        var gap = h * 3 / 100;
        var total = headerHeight + hrHeight + smallHeight + gap + smallHeight + BAR_LABEL_GAP + BAR_HEIGHT + gap + smallHeight;
        if (sourceLabel != null) {
            total += smallHeight;
        }
        var y = (h - total) / 2;

        drawHeader(dc, cx, y);
        y += headerHeight;

        var hr = heart.getCurrentHr();
        if (hr == null || hr <= 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + hrHeight / 2, Graphics.FONT_SMALL, str(Rez.Strings.WaitingForHr), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(alerting ? Graphics.COLOR_WHITE : Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_NUMBER_HOT, hr.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        }
        y += hrHeight;

        var averageText = str(Rez.Strings.Average) + " " + formatOptional(heart.getAverageHr());
        if (baseline != null) {
            averageText += " / " + str(Rez.Strings.Baseline) + " " + baseline.hr.format("%d");
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, averageText + " bpm", Graphics.TEXT_JUSTIFY_CENTER);
        y += smallHeight + gap;

        drawStillness(dc, cx, y, w * 55 / 100);
        y += smallHeight + BAR_LABEL_GAP + BAR_HEIGHT + gap;

        if (alerting) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, str(Rez.Strings.TapToDismiss), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, str(Rez.Strings.Hrv) + " " + formatOptional(heart.getRmssd()) + " ms", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (sourceLabel != null) {
            y += smallHeight;
            dc.setColor(Graphics.COLOR_PURPLE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, sourceLabel, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function getApp() as NoddifyApp {
        return Application.getApp() as NoddifyApp;
    }

    // The detector state, or calibration progress while calibrating.
    private function drawHeader(dc as Dc, cx as Number, y as Number) as Void {
        var calibrator = _monitor.calibrator;
        var state = _monitor.detector.getState();
        var color;
        var text;
        if (_monitor.isAlerting()) {
            color = Graphics.COLOR_WHITE;
            text = str(Rez.Strings.WakeUp);
        } else if (state == STATE_CALIBRATING) {
            color = Graphics.COLOR_YELLOW;
            text = str(Rez.Strings.Calibrating) + " " + formatDuration(calibrator.getElapsed()) + "/" + formatDuration(calibrator.getDuration());
        } else if (state == STATE_DROWSY) {
            color = Graphics.COLOR_ORANGE;
            text = str(Rez.Strings.Drowsy);
        } else if (state == STATE_COOLDOWN) {
            color = Graphics.COLOR_BLUE;
            text = str(Rez.Strings.Cooldown);
        } else {
            color = Graphics.COLOR_GREEN;
            text = str(Rez.Strings.Awake);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Still-time label with a bar below it filling up towards the stillness target. y is the label's top.
    private function drawStillness(dc as Dc, cx as Number, y as Number, width as Number) as Void {
        var still = _monitor.movement.getStillSeconds();
        var target = _monitor.detector.params.stillSeconds;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, str(Rez.Strings.Still) + " " + formatDuration(still), Graphics.TEXT_JUSTIFY_CENTER);

        var barY = y + dc.getFontHeight(Graphics.FONT_XTINY) + BAR_LABEL_GAP;
        var left = cx - width / 2;
        var fill = still >= target ? width : width * still / target;

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, barY, width, BAR_HEIGHT, BAR_HEIGHT / 2);
        if (fill > 0) {
            dc.setColor(still >= target ? Graphics.COLOR_ORANGE : Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(left, barY, fill, BAR_HEIGHT, BAR_HEIGHT / 2);
        }
    }

    private function str(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

    private function formatDuration(seconds as Number) as String {
        return (seconds / 60).toString() + ":" + (seconds % 60).format("%02d");
    }

    private function formatOptional(value as Float?) as String {
        return value == null ? "--" : value.format("%d");
    }
}
