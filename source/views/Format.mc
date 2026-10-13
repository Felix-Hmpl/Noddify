import Toybox.Lang;

module Format {

    // "m:ss" below an hour, "h:mm:ss" from an hour on.
    function duration(seconds as Number) as String {
        var minutes = (seconds / 60) % 60;
        var rest = (seconds % 60).format("%02d");
        if (seconds >= 3600) {
            return (seconds / 3600) + ":" + minutes.format("%02d") + ":" + rest;
        }
        return minutes + ":" + rest;
    }
}
