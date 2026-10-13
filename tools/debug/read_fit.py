"""Read a Noddify activity (.fit) and show its recorded data.

Prints the session summary, every event (alerts, answers, naps) and the per-second values,
and can export all records to CSV for analysis.

Usage:
    python tools/debug/read_fit.py                  # newest activity from the simulator
    python tools/debug/read_fit.py path/to/file.fit
    python tools/debug/read_fit.py --every 1        # print every second instead of every 10th
    python tools/debug/read_fit.py --csv out.csv    # also write all records to a CSV file

Requires: pip install -r tools/requirements.txt
"""

import argparse
import csv
import math
import os
import sys
from pathlib import Path

from garmin_fit_sdk import Decoder, Stream

# Where the Connect IQ simulator saves activities.
SIMULATOR_ACTIVITIES = Path(os.environ.get("TEMP", "")) / "com.garmin.connectiq" / "GARMIN" / "Activities"

# FIT message numbers of the messages Noddify adds fields to.
MESG_RECORD = 20
MESG_SESSION = 18

# Must match RecordEvent in source/recording/RecordEvent.mc.
EVENT_NAMES = {0: "", 1: "alert", 2: "answer yes", 3: "answer no", 4: "unanswered", 5: "nap"}

# Must match DetectorState in source/detection/DrowsinessDetector.mc, plus STATE_ALERTING
# in source/recording/SessionRecorder.mc.
STATE_NAMES = {0: "calibrating", 1: "awake", 2: "drowsy", 3: "cooldown", 4: "alerting"}


def newest_simulator_activity():
    files = sorted(SIMULATOR_ACTIVITIES.glob("*.fit"), key=lambda f: f.stat().st_mtime)
    if not files:
        sys.exit(f"No activities found in {SIMULATOR_ACTIVITIES}")
    return files[-1]


def decode(path):
    decoder = Decoder(Stream.from_file(str(path)))
    if not decoder.is_fit():
        sys.exit(f"{path} is not a FIT file")
    messages, errors = decoder.read()
    for error in errors:
        print(f"Warning while decoding: {error}", file=sys.stderr)
    return messages


def developer_field_names(messages):
    """Maps (message number, developer field key) to (name, units)."""
    names = {}
    for description in messages.get("field_description_mesgs", []):
        names[(description["native_mesg_num"], description["key"])] = (
            description["field_name"], description.get("units") or "")
    return names


def named_developer_fields(message, mesg_num, names):
    fields = {}
    for key, value in message.get("developer_fields", {}).items():
        name, _ = names.get((mesg_num, key), (f"field_{key}", ""))
        fields[name] = value
    return fields


def format_value(value):
    if isinstance(value, float):
        return "" if math.isnan(value) else f"{value:.2f}"
    return "" if value is None else str(value)


def print_table(rows, columns):
    widths = [max(len(column), *(len(format_value(row.get(column))) for row in rows)) for column in columns]
    print("  ".join(column.rjust(width) for column, width in zip(columns, widths)))
    for row in rows:
        print("  ".join(format_value(row.get(column)).rjust(width) for column, width in zip(columns, widths)))


def records_as_rows(messages, names):
    records = messages.get("record_mesgs", [])
    if not records:
        return []
    start = records[0]["timestamp"]
    rows = []
    for record in records:
        row = {
            "time": record["timestamp"].astimezone().strftime("%H:%M:%S"),
            "elapsed_s": int((record["timestamp"] - start).total_seconds()),
            "heart_rate": record.get("heart_rate"),
        }
        row.update(named_developer_fields(record, MESG_RECORD, names))
        row["state"] = STATE_NAMES.get(row.get("state"), row.get("state"))
        row["event"] = EVENT_NAMES.get(row.get("event"), row.get("event"))
        rows.append(row)
    return rows


def print_session(messages, names):
    session = messages["session_mesgs"][0]
    print(f"Name:      {session.get('sport_profile_name', '')} ({session.get('sport')}/{session.get('sub_sport')})")
    print(f"Start:     {session['start_time'].astimezone():%Y-%m-%d %H:%M:%S}")
    print(f"Duration:  {session.get('total_timer_time', 0) / 60:.1f} min recorded, "
          f"{session.get('total_elapsed_time', 0) / 60:.1f} min elapsed")
    print(f"Avg HR:    {session.get('avg_heart_rate')} bpm (native; missing in the simulator)")
    for name, value in named_developer_fields(session, MESG_SESSION, names).items():
        print(f"{name + ':':<11}{format_value(value)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file", nargs="?", type=Path, help="FIT file (default: newest simulator activity)")
    parser.add_argument("--every", type=int, default=10, help="print every Nth second (default 10)")
    parser.add_argument("--csv", type=Path, help="write all records to this CSV file")
    args = parser.parse_args()

    path = args.file or newest_simulator_activity()
    messages = decode(path)
    names = developer_field_names(messages)
    rows = records_as_rows(messages, names)
    columns = list(rows[0].keys()) if rows else []

    print(f"File:      {path}\n")
    if messages.get("session_mesgs"):
        print("== Session ==")
        print_session(messages, names)

    # The app keeps each event in the field for 1.5 s so no record write misses it, so the same
    # event can appear in two consecutive records. Count it once.
    events = [row for i, row in enumerate(rows)
              if row.get("event") and (i == 0 or rows[i - 1].get("event") != row["event"])]
    print(f"\n== Events ({len(events)}) ==")
    if events:
        print_table(events, ["time", "elapsed_s", "event", "nap_minutes", "state", "still_seconds",
                             "baseline_hr", "hr_drop_threshold", "still_threshold"])

    print(f"\n== Records ({len(rows)}, every {args.every}. shown) ==")
    if rows:
        print_table(rows[::max(args.every, 1)], columns)

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as file:
            writer = csv.DictWriter(file, fieldnames=columns)
            writer.writeheader()
            writer.writerows(rows)
        print(f"\nWrote {len(rows)} records to {args.csv}")


if __name__ == "__main__":
    main()
