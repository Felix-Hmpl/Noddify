import Toybox.Lang;

// Numeric codes for events in the activity recording's "event" field. The values are part of
// the recorded data, so existing codes must never change; add new ones at the end.
module RecordEvent {
    const NONE = 0;
    const ALERT = 1;
    const ANSWER_YES = 2;
    const ANSWER_NO = 3;
    const UNANSWERED = 4;
    const NAP = 5;

    function codeOf(type as String) as Number {
        if (type.equals(EventType.ALERT)) {
            return ALERT;
        } else if (type.equals(EventType.ANSWER_YES)) {
            return ANSWER_YES;
        } else if (type.equals(EventType.ANSWER_NO)) {
            return ANSWER_NO;
        } else if (type.equals(EventType.UNANSWERED)) {
            return UNANSWERED;
        } else if (type.equals(EventType.NAP)) {
            return NAP;
        }
        return NONE;
    }
}

// Decides which event the recording's event field shows. The watch writes the field values
// once per second on its own clock, so a value that is only set for one tick can be missed.
// Each event is therefore shown for at least HOLD_MS of real time, one after the other.
// An event can show up in two consecutive records; readers count consecutive repeats once.
class RecordEventQueue {

    const HOLD_MS = 1500;

    // Waiting events, each [code, nap minutes].
    private var _waiting as Array<Array<Number>> = [];
    private var _shown as Array<Number>? = null;
    private var _shownSince as Number = 0;

    function initialize() {
    }

    function add(events as Array<Array<Number>>) as Void {
        _waiting.addAll(events);
    }

    // The event to write at the given time (milliseconds, e.g. System.getTimer()),
    // as [code, nap minutes]; [NONE, 0] when there is none.
    function current(nowMs as Number) as Array<Number> {
        var shown = _shown;
        if (shown != null && nowMs - _shownSince >= HOLD_MS) {
            shown = null;
        }
        if (shown == null && _waiting.size() > 0) {
            shown = _waiting[0];
            _waiting = _waiting.slice(1, null);
            _shownSince = nowMs;
        }
        _shown = shown;
        return shown != null ? shown : [RecordEvent.NONE, 0];
    }
}
