import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Debug-only menu to switch between the real sensors and the scripted scenarios.
(:debug)
class DataSourceMenu {

    static function show() as Void {
        var menu = new WatchUi.Menu2({:title => "Data source"});
        menu.addItem(new WatchUi.MenuItem("Real sensors", null, Config.REAL_SENSORS_ID, {}));
        var scenarios = Scenarios.all();
        for (var i = 0; i < scenarios.size(); i++) {
            var scenario = scenarios[i];
            var minutes = (scenario.getTotalSeconds() + 59) / 60;
            menu.addItem(new WatchUi.MenuItem(scenario.name, minutes + " min, " + Config.SCENARIO_SPEED + "x speed", i, {}));
        }
        WatchUi.pushView(menu, new DataSourceMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

(:debug)
class DataSourceMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        (Application.getApp() as NoddifyApp).selectSource(item.getId() as Number);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
