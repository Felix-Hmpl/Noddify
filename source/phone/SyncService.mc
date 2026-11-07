import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Answers the phone app while Noddify is closed on the watch. The watch starts this background
// service for each message from the phone (Background.registerForPhoneAppMessageEvent):
// an ack drops that session from the outbox, a sync request sends every pending session and
// then syncDone. The system stops a background service after 30 seconds, so a transfer that
// doesn't finish in time is simply tried again on the next request.
(:background)
class SyncService extends System.ServiceDelegate {

    private var _queue as Array<Dictionary> = [];

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        var outbox = new PhoneOutbox(PhoneProtocol.OUTBOX_KEY);
        var acked = PhoneProtocol.ackedId(data);
        if (acked != null) {
            outbox.remove(acked);
            Background.exit(null);
        } else if (PhoneProtocol.SYNC.equals(PhoneProtocol.typeOf(data))) {
            outbox.removeAll(PhoneProtocol.storedIds(data));
            _queue = outbox.getMessages().slice(0, null);
            _queue.add(PhoneProtocol.syncDone());
            sendNext();
        } else {
            Background.exit(null);
        }
    }

    function onTransmitDone() as Void {
        sendNext();
    }

    private function sendNext() as Void {
        if (_queue.size() == 0) {
            Background.exit(null);
            return;
        }
        var message = _queue[0];
        _queue = _queue.slice(1, null);
        Communications.transmit(message, null, new SyncServiceListener(self));
    }
}

(:background)
class SyncServiceListener extends Communications.ConnectionListener {

    private var _service as SyncService;

    function initialize(service as SyncService) {
        ConnectionListener.initialize();
        _service = service;
    }

    function onComplete() as Void {
        _service.onTransmitDone();
    }

    function onError() as Void {
        _service.onTransmitDone();
    }
}
