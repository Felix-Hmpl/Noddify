import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Input handling for the live screen. During an alert, tapping or pressing either button dismisses
// it and asks for feedback. Otherwise Back opens the main menu instead of leaving the app.
class MainDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        if (dismissAlert()) {
            return true;
        }
        return onSelectWithoutAlert();
    }

    function onBack() as Boolean {
        if (!dismissAlert()) {
            MainMenu.show();
        }
        return true;
    }

    // Ends an active alert and asks whether it was right. Returns false if no alert was active.
    private function dismissAlert() as Boolean {
        if (!(Application.getApp() as NoddifyApp).getMonitor().acknowledgeAlert()) {
            return false;
        }
        WatchUi.requestUpdate();
        FeedbackMenu.show();
        return true;
    }

    // Debug builds: without an alert, tapping opens the data source menu.
    (:debug)
    private function onSelectWithoutAlert() as Boolean {
        DataSourceMenu.show();
        return true;
    }

    (:release)
    private function onSelectWithoutAlert() as Boolean {
        return false;
    }

    (:debug)
    function onMenu() as Boolean {
        DataSourceMenu.show();
        return true;
    }
}
