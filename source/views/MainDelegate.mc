import Toybox.Lang;
import Toybox.WatchUi;

// Input handling for the live screen. Start/stop and the menu come in later steps.
class MainDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Debug builds: tapping the screen, pressing the top button or the menu action
    // opens the data source menu.
    (:debug)
    function onSelect() as Boolean {
        DataSourceMenu.show();
        return true;
    }

    (:debug)
    function onMenu() as Boolean {
        DataSourceMenu.show();
        return true;
    }
}
