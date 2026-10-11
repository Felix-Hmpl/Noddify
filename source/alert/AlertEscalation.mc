import Toybox.Lang;

enum VibeLevel {
    VIBE_NONE,
    VIBE_GENTLE,
    VIBE_STRONG
}

// Escalates an alert until the wearer reacts: a gentle vibration first, then a strong one
// every REPEAT_SECONDS, up to MAX_STRONG times. After that the alert counts as unanswered.
class AlertEscalation {

    const REPEAT_SECONDS = 15;
    const MAX_STRONG = 3;

    private var _active as Boolean = false;
    private var _elapsed as Number = 0;
    private var _unanswered as Boolean = false;

    function initialize() {
    }

    // Starts a new alert and returns the vibration to play now.
    function start() as VibeLevel {
        _active = true;
        _elapsed = 0;
        _unanswered = false;
        return VIBE_GENTLE;
    }

    // Advances one second and returns the vibration to play, if any.
    function tick() as VibeLevel {
        if (!_active) {
            return VIBE_NONE;
        }
        _elapsed++;
        if (_elapsed % REPEAT_SECONDS != 0) {
            return VIBE_NONE;
        }
        if (_elapsed / REPEAT_SECONDS <= MAX_STRONG) {
            return VIBE_STRONG;
        }
        _active = false;
        _unanswered = true;
        return VIBE_NONE;
    }

    // Stops the alert. Returns false if no alert was active.
    function acknowledge() as Boolean {
        if (!_active) {
            return false;
        }
        _active = false;
        return true;
    }

    function isActive() as Boolean {
        return _active;
    }

    // True when the last alert ran through all repeats without a reaction.
    function wasUnanswered() as Boolean {
        return _unanswered;
    }
}
