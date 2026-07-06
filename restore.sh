#!/bin/bash
# Restore the original Wine DLLs backed up by apply.sh.
set -e
sudo cp /usr/lib/wine/x86_64-unix/winealsa.so.orig     /usr/lib/wine/x86_64-unix/winealsa.so
sudo cp /usr/lib/wine/x86_64-windows/winmm.dll.orig    /usr/lib/wine/x86_64-windows/winmm.dll
sudo cp /usr/lib/wine/x86_64-windows/mmdevapi.dll.orig /usr/lib/wine/x86_64-windows/mmdevapi.dll
wine reg delete 'HKCU\Software\Wine\Drivers' /v Audio /f 2>/dev/null || true
echo "Restored original winealsa.so, winmm.dll and mmdevapi.dll; Wine audio driver reset."
