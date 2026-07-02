#!/bin/bash
# Restore the original Wine DLLs backed up by apply.sh.
set -e
sudo cp /usr/lib/wine/x86_64-unix/winealsa.so.orig  /usr/lib/wine/x86_64-unix/winealsa.so
sudo cp /usr/lib/wine/x86_64-windows/winmm.dll.orig /usr/lib/wine/x86_64-windows/winmm.dll
echo "Restored original winealsa.so and winmm.dll."
