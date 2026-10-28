import Toybox.Communications;
import Toybox.Lang;

// Sends the outbox to the phone app and removes each session the phone acknowledges.
// The phone answers {"type": "ack", "id": <session id>} for every session it has stored.
// Messages only go out while Noddify runs, so pending ones are retried on every app start.
class PhoneSync {

    private var _outbox as PhoneOutbox;
    private var _queue as Array<Dictionary> = [];
    private var _sending as Boolean = false;
    private var _onDone as Method? = null;

    function initialize(outbox as PhoneOutbox) {
        _outbox = outbox;
    }

    function listen() as Void {
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    // Transmits every pending message, one after the other, then calls onDone (if given).
    // Failed transmissions stay in the outbox for the next try.
    function sendPending(onDone as Method?) as Void {
        _onDone = onDone;
        if (_sending) {
            return;
        }
        _queue = _outbox.getMessages().slice(0, null);
        _sending = true;
        sendNext();
    }

    function onTransmitDone() as Void {
        sendNext();
    }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        if (data instanceof Dictionary && "ack".equals(data["type"])) {
            var id = data["id"];
            if (id instanceof Number) {
                _outbox.remove(id);
            }
        }
    }

    private function sendNext() as Void {
        if (_queue.size() == 0) {
            _sending = false;
            var onDone = _onDone;
            _onDone = null;
            if (onDone != null) {
                onDone.invoke();
            }
            return;
        }
        var message = _queue[0];
        _queue = _queue.slice(1, null);
        Communications.transmit(message, null, new PhoneSyncListener(self));
    }
}

class PhoneSyncListener extends Communications.ConnectionListener {

    private var _sync as PhoneSync;

    function initialize(sync as PhoneSync) {
        ConnectionListener.initialize();
        _sync = sync;
    }

    function onComplete() as Void {
        _sync.onTransmitDone();
    }

    function onError() as Void {
        _sync.onTransmitDone();
    }
}
