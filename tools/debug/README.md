# Debug tools

Scripts for checking what Noddify records. They aren't part of the watch app.

Setup (once):

```
pip install -r tools/requirements.txt
```

## read_fit.py

Reads a Noddify activity (`.fit`) and prints the session summary, all events (alerts, answers,
naps) and the per-second values. Use `--csv` to export every record for analysis.

```
python tools/debug/read_fit.py                  # newest activity from the simulator
python tools/debug/read_fit.py path/to/file.fit
python tools/debug/read_fit.py --every 1        # print every second (default: every 10th)
python tools/debug/read_fit.py --csv out.csv    # also write all records to CSV
```

Where activities are saved:
- **Simulator:** `%TEMP%\com.garmin.connectiq\GARMIN\Activities\`
- **Watch:** `GARMIN\Activity\` on the watch over USB, or download the original file from the
  activity in Garmin Connect (⚙ → Export Original).

Things to know when reading simulator recordings:
- The native `heart_rate` is empty: in the simulator it only comes from the simulator's own
  sensor data, not from a debug scenario.
- Debug scenarios run at 5x speed, so `still_seconds` grows faster than the recorded time.
