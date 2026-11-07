import Toybox.Lang;

// Messages between the watch and the phone app besides the session itself (SessionMessage).
// Shared with android/core (WatchProtocol).
//
//   phone -> watch  {"type": "ack", "id": <session id>}       the phone stored the session
//   phone -> watch  {"type": "sync", "have": [<session id>, ...]}
//                   send everything pending; "have" lists sessions the phone already stored
//   watch -> phone  {"type": "syncDone"}                       answers a sync, after the sessions
(:background)
module PhoneProtocol {

    const ACK = "ack";
    const SYNC = "sync";
    const SYNC_DONE = "syncDone";

    // Where the outbox is saved, shared by the app and the background sync service.
    const OUTBOX_KEY = "outbox";

    function typeOf(data as Object?) as String? {
        if (data instanceof Dictionary) {
            var type = data["type"];
            if (type instanceof String) {
                return type;
            }
        }
        return null;
    }

    // The session id of an ack, or null.
    function ackedId(data as Object?) as Number? {
        if (ACK.equals(typeOf(data))) {
            var id = (data as Dictionary)["id"];
            if (id instanceof Number) {
                return id;
            }
        }
        return null;
    }

    // The session ids a sync request says the phone already has; empty if it says none.
    function storedIds(data as Object?) as Array<Number> {
        var ids = [] as Array<Number>;
        if (SYNC.equals(typeOf(data))) {
            var have = (data as Dictionary)["have"];
            if (have instanceof Array) {
                for (var i = 0; i < have.size(); i++) {
                    if (have[i] instanceof Number) {
                        ids.add(have[i] as Number);
                    }
                }
            }
        }
        return ids;
    }

    function syncDone() as Dictionary {
        return {"type" => SYNC_DONE};
    }
}
