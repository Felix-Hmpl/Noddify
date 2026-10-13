import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Shown after stopping a session with the START/STOP button: Resume, Save or Discard, with the
// session's duration and events. Back closes it and leaves the session stopped.
class SessionMenu {

    static function show() as Void {
        var monitor = getApp().getMonitor();
        var summary = monitor.getAlertCount() + " alerts, "
            + monitor.getEventCount(EventType.ANSWER_YES) + " yes, "
            + monitor.getEventCount(EventType.ANSWER_NO) + " no, "
            + monitor.getEventCount(EventType.NAP) + " naps";

        var menu = new WatchUi.Menu2({:title => Format.duration(monitor.getSecond())});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Resume, null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Save, summary, :save, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Discard, null, :discard, {}));
        WatchUi.pushView(menu, new SessionMenuDelegate(), WatchUi.SLIDE_UP);
    }

    static function getApp() as NoddifyApp {
        return Application.getApp() as NoddifyApp;
    }
}

class SessionMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resume) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            SessionMenu.getApp().resumeSession();
        } else if (id == :save) {
            SessionMenu.getApp().saveSession();
        } else if (id == :discard) {
            WatchUi.pushView(new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.DiscardQuestion) as String),
                new DiscardDelegate(), WatchUi.SLIDE_UP);
        }
    }
}

class DiscardDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            SessionMenu.getApp().discardSession();
        }
        return true;
    }
}
