#!/bin/bash
# Compiles Noddify with its (:test) code and runs the unit tests in a headless simulator.
# Runs inside the connectiq-tester image, which has the SDK, device files and simulator:
#   docker run --rm -v "$PWD":/app -w /app --entrypoint bash ghcr.io/matco/connectiq-tester:v2.8.0 tools/test/run_tests.sh
# Same as the image's own script, but with the compiler's default type checking instead of strict.

DEVICE_ID=${1:-venu3s}

# A throwaway signing key, since the build only needs some key.
openssl genrsa -out /tmp/key.pem 4096 2>/dev/null
openssl pkcs8 -topk8 -inform PEM -outform DER -in /tmp/key.pem -out /tmp/key.der -nocrypt

echo "Compiling for $DEVICE_ID..."
rm -f bin/test.prg
monkeyc -f monkey.jungle -d "$DEVICE_ID" -o bin/test.prg -y /tmp/key.der -t
[[ -f bin/test.prg ]] || { echo "Compilation failed"; exit 1; }

echo "Starting simulator..."
export DISPLAY=:1
Xvfb "$DISPLAY" -screen 0 1280x1024x24 &
simulator > /dev/null 2>&1 &
trap 'kill $(jobs -p) 2>/dev/null' EXIT
sleep 5

echo "Running tests..."
# monkeydo exits with 1 even when all tests pass, so the result is read from its output.
monkeydo bin/test.prg "$DEVICE_ID" -t | tee /tmp/result.txt
[[ $(tail -1 /tmp/result.txt) == PASSED* ]]
