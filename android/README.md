# Noddify for Android

A companion app that receives the sessions saved by the Noddify watch app and shows stats:
alerts per hour, how alerts were answered, naps, the baseline heart rate and what the
detection has learned, plus a timeline for each session.

## How sessions get here

When a session is saved, the watch sends a short summary (times, pauses, baseline, learned
thresholds and events; see `source/phone/SessionMessage.mc`) through Garmin Connect Mobile.
The app stores it and answers with an ack, so the watch drops it from its outbox. Sessions the
phone didn't confirm are sent again the next time Noddify starts on the watch.

You need:
- Garmin Connect Mobile installed, with the watch paired.
- This app running (in the foreground or background) when the watch sends.

The per-second heart rate and movement data isn't sent yet. Each session is stored as
`<id>.json`, so a detailed timeline can be added next to it later.

## Project layout

- `core/`: the message format, storage, timeline and stats in plain Kotlin, with unit tests.
- `app/`: the Android app (Jetpack Compose and the Connect IQ Mobile SDK).

## Building

Open this folder in Android Studio, or run:

```
./gradlew :core:test :app:assembleDebug
```

Debug builds have a "Load demo sessions" button on the empty stats screen, so you can try
the app without a watch. CI builds the debug APK for every change under `android/`; download
it from the workflow run's artifacts.

The Connect IQ Mobile SDK is Garmin's and comes from Maven Central under Garmin's own SDK
license.
