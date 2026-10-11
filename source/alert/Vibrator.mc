import Toybox.Attention;
import Toybox.Lang;

// Plays the alert vibrations. Tests replace it with a recording subclass.
class Vibrator {

    function initialize() {
    }

    function play(level as VibeLevel) as Void {
        if (level == VIBE_NONE || !(Attention has :vibrate)) {
            return;
        }
        var pattern;
        if (level == VIBE_STRONG) {
            pattern = [
                new Attention.VibeProfile(100, 800),
                new Attention.VibeProfile(0, 300),
                new Attention.VibeProfile(100, 800),
                new Attention.VibeProfile(0, 300),
                new Attention.VibeProfile(100, 800)
            ];
        } else {
            pattern = [
                new Attention.VibeProfile(50, 300),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(50, 300)
            ];
        }
        Attention.vibrate(pattern);
    }
}
