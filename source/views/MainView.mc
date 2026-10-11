import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Live screen: calibration progress or baseline, current heart rate, stillness bar and HRV,
// plus the scenario name when a debug scenario replaces the sensors.
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

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var heart = _monitor.heart;

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
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_NUMBER_HOT, hr.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        }
        y += hrHeight;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, str(Rez.Strings.Average) + " " + formatOptional(heart.getAverageHr()) + " bpm", Graphics.TEXT_JUSTIFY_CENTER);
        y += smallHeight + gap;

        drawStillness(dc, cx, y, w * 55 / 100);
        y += smallHeight + BAR_LABEL_GAP + BAR_HEIGHT + gap;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, str(Rez.Strings.Hrv) + " " + formatOptional(heart.getRmssd()) + " ms", Graphics.TEXT_JUSTIFY_CENTER);

        if (sourceLabel != null) {
            y += smallHeight;
            dc.setColor(Graphics.COLOR_PURPLE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, sourceLabel, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function getApp() as NoddifyApp {
        return Application.getApp() as NoddifyApp;
    }

    private function drawHeader(dc as Dc, cx as Number, y as Number) as Void {
        var calibrator = _monitor.calibrator;
        var baseline = calibrator.getBaseline();
        var text;
        if (baseline == null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            text = str(Rez.Strings.Calibrating) + " " + formatDuration(calibrator.getElapsed()) + "/" + formatDuration(calibrator.getDuration());
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            text = str(Rez.Strings.Baseline) + " " + baseline.hr.format("%d") + " bpm";
        }
        dc.drawText(cx, y, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Still-time label with a bar below it filling up towards the stillness target. y is the label's top.
    private function drawStillness(dc as Dc, cx as Number, y as Number, width as Number) as Void {
        var still = _monitor.movement.getStillSeconds();
        var target = Config.STILL_TARGET_SECONDS;

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
