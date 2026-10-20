#!/bin/sh
# Pull the latest version, build it, and install it to /Applications.
set -e
cd "$(dirname "$0")"
# git pull --ff-only
./build.sh
pkill -x NotifyMe || true
rm -rf /Applications/NotifyMe.app
ditto NotifyMe.app /Applications/NotifyMe.app
open /Applications/NotifyMe.app
echo "Notify Me installed to /Applications."
