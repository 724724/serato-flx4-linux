#!/bin/bash
# Apply FLX4 + Serato DJ Pro support to a Wine prefix.
# Registers the FLX4 USB device in the Wine registry and deploys the
# patched winealsa.so / winmm.dll from prebuilt/.
#
# NOTE: The libusb stub is built/deployed separately by patch.sh.
#       If your Wine version differs from prebuilt/WINE_VERSION.txt,
#       rebuild from wine-flx4.patch instead of using the prebuilt binaries.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "[1/3] Registering FLX4 USB device in the Wine registry..."
INST='HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_2B73&PID_0045\512&256&1&0'
wine reg add "$INST" /v DeviceDesc  /t REG_SZ    /d "Pioneer DDJ-FLX4" /f
wine reg add "$INST" /v HardwareId  /t REG_SZ    /d "USB\VID_2B73&PID_0045&REV_0100" /f
wine reg add "$INST" /v ClassGUID   /t REG_SZ    /d "{00000000-0000-0000-0000-000000000000}" /f
wine reg add "$INST" /v ConfigFlags /t REG_DWORD /d "0" /f

echo "[2/3] Setting Wine audio driver to ALSA (Serato needs WASAPI exclusive mode;"
echo "      winepulse rejects it, winealsa supports it via direct hw access)..."
wine reg add 'HKCU\Software\Wine\Drivers' /v Audio /t REG_SZ /d alsa /f

echo "[3/3] Deploying patched Wine DLLs (originals backed up as *.orig)..."
sudo cp -n /usr/lib/wine/x86_64-unix/winealsa.so     /usr/lib/wine/x86_64-unix/winealsa.so.orig     2>/dev/null || true
sudo cp -n /usr/lib/wine/x86_64-windows/winmm.dll    /usr/lib/wine/x86_64-windows/winmm.dll.orig    2>/dev/null || true
sudo cp -n /usr/lib/wine/x86_64-windows/mmdevapi.dll /usr/lib/wine/x86_64-windows/mmdevapi.dll.orig 2>/dev/null || true
sudo cp "$HERE/prebuilt/winealsa.so"  /usr/lib/wine/x86_64-unix/winealsa.so
sudo cp "$HERE/prebuilt/winmm.dll"    /usr/lib/wine/x86_64-windows/winmm.dll
sudo cp "$HERE/prebuilt/mmdevapi.dll" /usr/lib/wine/x86_64-windows/mmdevapi.dll

echo "Done. Run patch.sh separately to build/deploy the libusb stub into your Serato install."
