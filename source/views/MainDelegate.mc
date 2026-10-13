import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Input handling for the live screen.
// - START/STOP button: starts the session, or stops it and opens Resume / Save / Discard.
// - During an alert, any button or a tap dismisses it and asks for feedback instead.
// - Back opens the main menu instead of leaving the app.
// Taps and the START/STOP button are handled separately, so touching the screen can never
// start or end a session.
class MainDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() != WatchUi.KEY_ENTER) {
            return false;
        }
        if (dismissAlert()) {
            return true;
        }
        var app = getApp();
        var state = app.getState();
        if (state == SESSION_IDLE) {
            app.startSession();
        } else {
            if (state == SESSION_RUNNING) {
                app.stopSession();
            }
            SessionMenu.show();
        }
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (dismissAlert()) {
            return true;
        }
        return onTapWithoutAlert();
    }

    function onBack() as Boolean {
        if (!dismissAlert()) {
            MainMenu.show();
        }
        return true;
    }

    // Ends an active alert and asks whether it was right. Returns false if no alert was active.
    private function dismissAlert() as Boolean {
        if (!getApp().getMonitor().acknowledgeAlert()) {
            return false;
        }
        WatchUi.requestUpdate();
        FeedbackMenu.show();
        return true;
    }

    private function getApp() as NoddifyApp {
        return Application.getApp() as NoddifyApp;
    }

    // Debug builds: without an alert, tapping opens the data source menu.
    (:debug)
    private function onTapWithoutAlert() as Boolean {
        DataSourceMenu.show();
        return true;
    }

    (:release)
    private function onTapWithoutAlert() as Boolean {
        return false;
    }

    (:debug)
    function onMenu() as Boolean {
        DataSourceMenu.show();
        return true;
    }
}
