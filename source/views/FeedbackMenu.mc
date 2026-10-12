import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// "Were you dozing off?" after the wearer dismissed an alert. Leaving with Back gives no answer,
// so an accidental button press never counts as a "No".
class FeedbackMenu {

    static function show() as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.DozingQuestion});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Yes, null, :yes, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.No, null, :no, {}));
        WatchUi.pushView(menu, new FeedbackMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

class FeedbackMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        (Application.getApp() as NoddifyApp).getMonitor().answerAlert(item.getId() == :yes);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
