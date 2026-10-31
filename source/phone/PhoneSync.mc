import Toybox.Communications;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

enum SyncStatus {
    // Nothing was sent in this run, so there is nothing to report.
    SYNC_NONE,
    SYNC_SYNCING,
    SYNC_SUCCESS,
    SYNC_FAILED
}

// Sends the outbox to the phone app and removes each session the phone acknowledges.
// The phone answers {"type": "ack", "id": <session id>} for every session it has stored.
// Messages only go out while Noddify runs, so pending ones are retried on every app start.
//
// The status is SYNCING from the first transmission until the phone has acknowledged every
// session (SUCCESS) or ACK_TIMEOUT_MS passed after the last transmission without that (FAILED).
class PhoneSync {

    // How long to wait for the acks once everything has been transmitted.
    const ACK_TIMEOUT_MS = 5000;

    private var _status as SyncStatus = SYNC_NONE;
    private var _ackTimer as Timer.Timer? = null;
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

    function getStatus() as SyncStatus {
        return _status;
    }

    // Transmits every pending message, one after the other, then calls onDone (if given) once
    // the phone acknowledged them or the wait for that ran out. Unconfirmed messages stay in the
    // outbox for the next try.
    function sendPending(onDone as Method?) as Void {
        _onDone = onDone;
        if (_sending) {
            return;
        }
        if (_outbox.getMessages().size() == 0) {
            finish(SYNC_NONE);
            return;
        }
        _queue = _outbox.getMessages().slice(0, null);
        _sending = true;
        setStatus(SYNC_SYNCING);
        sendNext();
    }

    // The phone has stored the session: the watch can forget it.
    function acknowledge(id as Number) as Void {
        _outbox.remove(id);
        if (_status == SYNC_SYNCING && _outbox.getMessages().size() == 0) {
            finish(SYNC_SUCCESS);
        }
    }

    function onAckTimeout() as Void {
        if (_status == SYNC_SYNCING) {
            finish(SYNC_FAILED);
        }
    }

    function onTransmitDone() as Void {
        sendNext();
    }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        if (data instanceof Dictionary && "ack".equals(data["type"])) {
            var id = data["id"];
            if (id instanceof Number) {
                acknowledge(id);
            }
        }
    }

    private function sendNext() as Void {
        if (_queue.size() == 0) {
            _sending = false;
            // Everything is out; now the acks decide.
            if (_status == SYNC_SYNCING) {
                var timer = new Timer.Timer();
                timer.start(method(:onAckTimeout), ACK_TIMEOUT_MS, false);
                _ackTimer = timer;
            }
            return;
        }
        var message = _queue[0];
        _queue = _queue.slice(1, null);
        Communications.transmit(message, null, new PhoneSyncListener(self));
    }

    private function finish(status as SyncStatus) as Void {
        var timer = _ackTimer;
        if (timer != null) {
            timer.stop();
            _ackTimer = null;
        }
        setStatus(status);
        var onDone = _onDone;
        _onDone = null;
        if (onDone != null) {
            onDone.invoke();
        }
    }

    private function setStatus(status as SyncStatus) as Void {
        _status = status;
        WatchUi.requestUpdate();
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
