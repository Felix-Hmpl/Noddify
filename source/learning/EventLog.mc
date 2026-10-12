import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Types of logged events.
module EventType {
    const ALERT = "alert";
    const ANSWER_YES = "answerYes";
    const ANSWER_NO = "answerNo";
    // All vibrations of an alert ran out without a reaction.
    const UNANSWERED = "unanswered";
    const NAP = "nap";
}

// History of alerts, answers and logged naps, each with the feature values at that moment.
// Kept for analysis and for data-driven learning later; the activity recording gets the same events.
// Saved on the watch, oldest events dropped beyond MAX_EVENTS to stay within the storage limits.
class EventLog {

    const MAX_EVENTS = 50;

    private var _storageKey as String?;
    private var _events as Array<Dictionary> = [];

    // storageKey: where to save in Application.Storage, or null to keep everything in memory (tests).
    function initialize(storageKey as String?) {
        _storageKey = storageKey;
        if (storageKey != null) {
            var saved = Storage.getValue(storageKey);
            if (saved instanceof Array) {
                _events = saved as Array<Dictionary>;
            }
        }
    }

    // Adds an event. sessionSecond is the second of the session it happened in;
    // extra holds event-specific values like a nap's duration.
    function add(type as String, sessionSecond as Number, features as FeatureSnapshot?, extra as Dictionary?) as Void {
        var event = {
            "type" => type,
            "time" => Time.now().value(),
            "second" => sessionSecond
        } as Dictionary;
        if (features != null) {
            event["features"] = withoutNulls(features.toDictionary());
        }
        if (extra != null) {
            var keys = extra.keys();
            for (var i = 0; i < keys.size(); i++) {
                event[keys[i]] = extra[keys[i]];
            }
        }
        _events.add(event);
        if (_events.size() > MAX_EVENTS) {
            _events = _events.slice(_events.size() - MAX_EVENTS, null);
        }
        var key = _storageKey;
        if (key != null) {
            Storage.setValue(key, _events);
        }
    }

    function getEvents() as Array<Dictionary> {
        return _events;
    }

    // Number of events of the given type.
    function count(type as String) as Number {
        var n = 0;
        for (var i = 0; i < _events.size(); i++) {
            if (type.equals(_events[i]["type"])) {
                n++;
            }
        }
        return n;
    }

    private function withoutNulls(values as Dictionary) as Dictionary {
        var result = {};
        var keys = values.keys();
        for (var i = 0; i < keys.size(); i++) {
            if (values[keys[i]] != null) {
                result[keys[i]] = values[keys[i]];
            }
        }
        return result;
    }
}
