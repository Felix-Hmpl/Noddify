import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Input handling for the live screen. Start/stop and the menu come in later steps.
class MainDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Tapping the screen or pressing the top button dismisses an active alert.
    function onSelect() as Boolean {
        if ((Application.getApp() as NoddifyApp).getMonitor().acknowledgeAlert()) {
            WatchUi.requestUpdate();
            return true;
        }
        return onSelectWithoutAlert();
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
