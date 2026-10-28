import Toybox.Application;
import Toybox.Lang;

// Session messages waiting for the phone app to confirm them. A message stays until the phone
// answers with an ack for its id, so it is sent again on every app start until then; the phone
// ignores sessions it already has. Saved on the watch, oldest dropped beyond MAX_MESSAGES.
class PhoneOutbox {

    const MAX_MESSAGES = 10;

    private var _storageKey as String?;
    private var _messages as Array<Dictionary> = [];

    // storageKey: where to save in Application.Storage, or null to keep everything in memory (tests).
    function initialize(storageKey as String?) {
        _storageKey = storageKey;
        if (storageKey != null) {
            var saved = Storage.getValue(storageKey);
            if (saved instanceof Array) {
                _messages = saved as Array<Dictionary>;
            }
        }
    }

    function add(message as Dictionary) as Void {
        _messages.add(message);
        if (_messages.size() > MAX_MESSAGES) {
            _messages = _messages.slice(_messages.size() - MAX_MESSAGES, null);
        }
        save();
    }

    // Drops the message with the given id, once the phone confirmed it.
    function remove(id as Number) as Void {
        var kept = [] as Array<Dictionary>;
        for (var i = 0; i < _messages.size(); i++) {
            if (_messages[i]["id"] != id) {
                kept.add(_messages[i]);
            }
        }
        if (kept.size() != _messages.size()) {
            _messages = kept;
            save();
        }
    }

    function getMessages() as Array<Dictionary> {
        return _messages;
    }

    private function save() as Void {
        var key = _storageKey;
        if (key != null) {
            Storage.setValue(key, _messages);
        }
    }
}
