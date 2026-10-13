"""Plot a Noddify activity (.fit) over time.

Shows heart rate, movement, stillness against its threshold, HRV against its baseline and the
detector state, with every event (alerts, answers, naps) marked as a vertical line.

Usage:
    python tools/debug/plot_fit.py                  # newest activity from the simulator
    python tools/debug/plot_fit.py path/to/file.fit
    python tools/debug/plot_fit.py --out plot.png   # save instead of opening a window

Requires: pip install -r tools/requirements.txt
"""

import argparse
from pathlib import Path

import matplotlib.pyplot as plt

from read_fit import STATE_NAMES, decode, developer_field_names, newest_simulator_activity, records_as_rows

EVENT_COLORS = {"alert": "red", "answer yes": "green", "answer no": "orange",
                "unanswered": "purple", "nap": "blue"}
STATE_COLORS = {"calibrating": "lightgray", "awake": "palegreen", "drowsy": "khaki",
                "cooldown": "lightblue", "alerting": "salmon"}


def column(rows, name):
    # 0 means "unavailable" in the recording, so leave those points out.
    return [row.get(name) or None for row in rows]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file", nargs="?", type=Path, help="FIT file (default: newest simulator activity)")
    parser.add_argument("--out", type=Path, help="save the plot to this image file")
    args = parser.parse_args()

    path = args.file or newest_simulator_activity()
    messages = decode(path)
    rows = records_as_rows(messages, developer_field_names(messages))
    if not rows:
        raise SystemExit(f"{path} has no records")
    t = [row["elapsed_s"] for row in rows]

    fig, axes = plt.subplots(5, 1, sharex=True, figsize=(11, 10),
                             gridspec_kw={"height_ratios": [2, 2, 2, 2, 0.6]})
    hr, move, still, hrv, state = axes
    fig.suptitle(path.name)

    hr.plot(t, column(rows, "heart_rate"), label="heart rate")
    hr.plot(t, column(rows, "baseline_hr"), "--", label="baseline")
    hr.set_ylabel("bpm")

    move.plot(t, [row.get("movement") for row in rows], label="movement")
    move.set_ylabel("mg")
    fidgets = move.twinx()
    fidgets.plot(t, [row.get("fidgets") for row in rows], color="gray", alpha=0.6, label="fidgets")
    fidgets.set_ylabel("fidgets/min")

    still.plot(t, [row.get("still_seconds") for row in rows], label="still")
    still.plot(t, column(rows, "still_threshold"), "--", label="threshold")
    still.set_ylabel("s")

    hrv.plot(t, column(rows, "rmssd"), label="RMSSD")
    hrv.plot(t, column(rows, "baseline_hrv"), "--", label="baseline")
    hrv.set_ylabel("ms")

    # Detector state as a colored band.
    for i, row in enumerate(rows):
        end = t[i + 1] if i + 1 < len(t) else t[i] + 1
        state.axvspan(t[i], end, color=STATE_COLORS.get(row["state"], "white"))
    state.set_yticks([])
    state.set_ylabel("state")
    state.legend(handles=[plt.Rectangle((0, 0), 1, 1, color=STATE_COLORS[name]) for name in STATE_NAMES.values()],
                 labels=list(STATE_NAMES.values()), loc="upper center", bbox_to_anchor=(0.5, -0.6), ncol=5)
    state.set_xlabel("elapsed (s)")

    # Events, counted once even when held over two records.
    for i, row in enumerate(rows):
        event = row.get("event")
        if event and (i == 0 or rows[i - 1].get("event") != event):
            label = f"nap {row['nap_minutes']} min" if event == "nap" else event
            for axis in axes:
                axis.axvline(row["elapsed_s"], color=EVENT_COLORS.get(event, "black"), linewidth=1)
            hr.annotate(label, (row["elapsed_s"], 1), xycoords=("data", "axes fraction"),
                        rotation=90, va="top", ha="right", fontsize=8, color=EVENT_COLORS.get(event, "black"))

    for axis in axes[:-1]:
        axis.legend(loc="upper left", fontsize=8)
        axis.grid(alpha=0.3)
    fig.tight_layout()

    if args.out:
        fig.savefig(args.out, dpi=110)
        print(f"Saved {args.out}")
    else:
        plt.show()


if __name__ == "__main__":
    main()
