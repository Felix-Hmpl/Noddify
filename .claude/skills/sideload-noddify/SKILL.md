---
name: sideload-noddify
description: Build Noddify for a Garmin watch and copy it onto the USB-connected watch's GARMIN\APPS folder. Use when the user asks to sideload, deploy, install, or update Noddify on the watch, or to build and copy it to the device.
---

# Sideload Noddify to the watch

The script `tools\sideload\sideload.ps1` builds `bin\Noddify.prg` with the developer key from `%USERPROFILE%\.garmin` and copies it to `GARMIN\APPS\` on the watch. Run it from the repo root. The device id comes from `manifest.xml` (`-Product` overrides it), so nothing here is tied to one watch model.

## Steps

1. **Check the watch.** Run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\sideload\sideload.ps1 -Check
   ```
   - If `manifest.xml` lists more than one product, the script exits with an error. Ask the user which device to build for, then pass `-Product <id>`.
   - Exit code 2 ("Watch not connected"): tell the user to connect the watch over USB and unlock it. Stop until they confirm.
   - Exit code 0: the output shows whether Noddify is already on the watch and when it was copied. Go on to step 2.

2. **If Noddify is already on the watch**, ask the user whether to replace it, unless the request already says so (e.g. "update the watch" or "replace it"). Don't replace without an answer.

3. **Build and copy.**
   - New install, or the user approved a replace: `powershell -ExecutionPolicy Bypass -File tools\sideload\sideload.ps1 -Replace`
   - Otherwise: the same command without `-Replace`. It stops with exit code 3 if Noddify is already there.

4. **Report the result.** Say where the file was copied, and tell the user to eject the watch from File Explorer before unplugging it. If the build fails, show the compiler's error output.

## Rules

- Don't commit anything. `bin\` is gitignored, and the script changes no tracked files.
- Don't copy to the watch until the user has answered the replace question when one is needed.
