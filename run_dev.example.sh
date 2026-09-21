#!/usr/bin/env bash
# Dev launcher: auto-fills and auto-signs-in the app (debug only) so you never
# retype your credentials after a reinstall/reset on the simulator.
#
# Setup (once):
#   cp run_dev.example.sh run_dev.sh
#   # edit run_dev.sh, put your real email + password
#   chmod +x run_dev.sh
# Then just run:  ./run_dev.sh
#
# run_dev.sh is gitignored, so your password never gets committed (public repo).
set -e
flutter run \
  --dart-define=DEV_EMAIL=you@example.com \
  --dart-define=DEV_PASSWORD=your_password_here
