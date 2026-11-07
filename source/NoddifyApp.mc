import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// The application entry point. It is also loaded for the background sync service, so it keeps
// only what that needs; the app itself lives in Noddify, created when Noddify opens.
(:background)
class NoddifyApp extends Application.AppBase {

    private var _noddify as Noddify? = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var noddify = new Noddify();
        _noddify = noddify;
        noddify.start();
        return [new MainView(), new MainDelegate()];
    }

    function onStop(state as Dictionary?) as Void {
        var noddify = _noddify;
        if (noddify != null) {
            noddify.stop();
        }
    }

    function getServiceDelegate() {
        return [new SyncService()];
    }

    function getNoddify() as Noddify {
        return _noddify as Noddify;
    }
}
