import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// The menu behind the Back button. During a session: log a nap and end the session. Always:
// see the learned thresholds and reset them. Before a session: exit.
class MainMenu {

    // Nap length choices in minutes.
    static const NAP_MINUTES = [1, 2, 3, 5, 10, 15, 20, 30];

    static function show() as Void {
        var app = getApp();
        var state = app.getState();
        var learning = app.getLearning();
        var params = learning.params;
        var thresholds = params.get(Param.HR_DROP).format("%.1f") + " bpm, "
            + params.get(Param.STILL_SECONDS).format("%d") + " s, "
            + learning.getFeedbackCount() + " answers";

        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        if (state != SESSION_IDLE) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.LogNap, null, :logNap, {}));
        }
        if (state == SESSION_RUNNING) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.EndSession, null, :endSession, {}));
        }
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Thresholds, thresholds, :thresholds, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.ResetLearning, null, :resetLearning, {}));
        // With a session in progress, leaving goes through Save or Discard.
        if (state == SESSION_IDLE) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.Exit, null, :exit, {}));
        }
        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
    }

    static function showNapLengths() as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.NapLength});
        for (var i = 0; i < NAP_MINUTES.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(NAP_MINUTES[i] + " min", null, NAP_MINUTES[i], {}));
        }
        WatchUi.pushView(menu, new NapLengthDelegate(), WatchUi.SLIDE_LEFT);
    }

    static function getApp() as NoddifyApp {
        return Application.getApp() as NoddifyApp;
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :logNap) {
            MainMenu.showNapLengths();
        } else if (id == :endSession) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            MainMenu.getApp().stopSession();
            SessionMenu.show();
        } else if (id == :resetLearning) {
            WatchUi.pushView(new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.ResetQuestion) as String),
                new ResetLearningDelegate(), WatchUi.SLIDE_UP);
        } else if (id == :exit) {
            System.exit();
        }
    }
}

class NapLengthDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        MainMenu.getApp().getMonitor().logNap(item.getId() as Number);
        // Back to the live screen: close the nap lengths and the main menu.
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (WatchUi has :showToast) {
            WatchUi.showToast(Rez.Strings.NapLogged, null);
        }
    }
}

class ResetLearningDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            MainMenu.getApp().getLearning().reset();
            // Close the main menu too, so its thresholds line isn't stale.
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
        return true;
    }
}
