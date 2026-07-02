# serato-flx4-linux

Makes the **Pioneer DDJ-FLX4** work in **hardware mode** with **Serato DJ Pro**
running under **Wine** on Linux.

No Windows. No dual-boot. No VM.

Forked from [anolis/serato-dj808-linux](https://github.com/anolis/serato-dj808-linux),
which targets the Roland DJ-808/505. This fork drops the Roland-specific pieces
(ASIO stubs, `.exe` binary patches) — the FLX4 doesn't need them — and adds the
`winealsa.so` / `winmm.dll` patches required to make Serato associate the FLX4's
MIDI port with its USB device.

> **Status:** MIDI + USB + HID hardware connection works — Serato reports
> `***CONNECTED*** Pioneer DDJ-FLX4`. Licensing (see below) is separate from
> hardware detection.

---

## Supported hardware

| Controller | VID | PID | Status |
|---|---|---|---|
| Pioneer DDJ-FLX4 | `0x2B73` | `0x0045` | Hardware connects |

> **Check your PID.** Run `lsusb | grep -i 2b73`. Some units report a different
> PID; if yours isn't `0045`, change it in `wine-flx4.patch` and `apply.sh`.

## Why the FLX4 is different from the Roland controllers

- **No ASIO stub needed.** The FLX4 is a USB audio/MIDI class-compliant device.
  Serato picks up its audio through the normal Windows Audio (WASAPI/waveOut)
  path Wine already provides, so there is no Roland-style kernel ASIO driver to
  fake. The `RDAS*.DLL` stubs from the original repo are removed.
- **No `.exe` binary patches needed.** The FLX4 aggregates without the vtable
  gate-check NOP patches the DJ-808 required.
- **The hard part is MIDI ↔ USB association**, which is fixed entirely at the
  Wine level (`winealsa.so` + `winmm.dll`), independent of the Serato version.

---

## Background — the four walls

Getting the FLX4 into Serato hardware mode means clearing four separate barriers:

1. **USB detection.** Serato uses `libusb` to read a controller's VID/PID. Under
   Wine the libusb→kernel path relies on `CM_Get_Parent`, which Wine stubs out,
   so the aggregation loop retries forever. The custom `libusb-1.0.dll` (from the
   original repo's `patch.sh`) reads VID/PID from the Wine registry and confirms
   presence via Linux sysfs instead.

2. **MIDI device interface (OUT).** Serato matches the MIDI port to the USB
   device by calling `DRV_QUERYDEVICEINTERFACE` on the MIDI output, expecting a
   USB interface path that contains the VID/PID. Stock `winealsa` doesn't
   implement this selector, so the path comes back empty and the MIDI port shows
   as `vid=0000&pid=0000`.

3. **MIDI device interface (IN).** Serato never sends
   `DRV_QUERYDEVICEINTERFACE` to the MIDI **input** — Wine's `winmm.dll`
   `midiInMessage` is missing the `MMDRV_PhysicalFeatures` fallback that
   `midiOutMessage` has, so the query never reaches the driver. Without this the
   IN side stays `vid=0000`, the IN/OUT connections get different
   `unique_group`s, and Serato never merges them into one duplex device.

4. **Duplex merge.** Once IN and OUT both report `vid=2b73&pid=0045` via the
   same interface path, Serato collapses them into a single
   `direction=duplex` connection and enters hardware mode.

---

## What this fork changes

### 1. Custom `libusb-1.0.dll` (unchanged, from `patch.sh`)
Reads VID/PID directly from Wine's device registry
(`SYSTEM\CurrentControlSet\Enum\USB`) and checks Linux sysfs to confirm the
device is physically present.

### 2. `winealsa.so` — MIDI VID/PID injection (`wine-flx4.patch`)
Two additions to `dlls/winealsa.drv/alsamidi.c`:

- **`DRV_QUERYDEVICEINTERFACE` / `...SIZE`** handling in both
  `alsa_midi_out_message` and `alsa_midi_in_message`. When the ALSA port name
  contains `FLX4`, returns the USB interface path:
```
  \\?\USB#VID_2B73&PID_0045#512&256&1&0#{A5DCBF10-6530-11D2-901F-00C04FB951ED}
```
- **`wMid` / `wPid` injection** in `midi_in_get_devcaps` /
  `midi_out_get_devcaps` (`0x2b73` / `0x0045`) as a belt-and-suspenders measure
  for the `MIDIINCAPS` / `MIDIOUTCAPS` path.

### 3. `winmm.dll` — `midiInMessage` fallback (`wine-flx4.patch`)
Adds the `MMDRV_PhysicalFeatures` fallback to `midiInMessage` in
`dlls/winmm/winmm.c`, mirroring the one already present in `midiOutMessage`.
This is what lets `DRV_QUERYDEVICEINTERFACE` reach the driver on the MIDI **input**
side, so IN and OUT end up with the same interface path and merge into one
duplex device.

> This is the piece the original repo's README described ("patched
> `winealsa.so`") but did not actually ship. It is implemented here.

---

## Requirements

| Package | Purpose |
|---|---|
| `wine` (WineHQ stable, 10.0 tested) | Runs Serato |
| `gcc` | Builds the libusb stub / LD_PRELOAD hook |
| `mingw-w64` | Cross-compiles the libusb stub (Windows DLL) |
| `python3`, `xdg-utils` | Used by `patch.sh` |
| Wine build deps + `alsa-lib` | Only if rebuilding `winealsa.so` / `winmm.dll` |

On Arch:
```bash
sudo pacman -S --needed wine mingw-w64-gcc python xdg-utils base-devel alsa-lib
```

---

## Usage

### 1. Install Serato DJ Pro into your Wine prefix as normal.

### 2. Build/deploy the libusb stub (from the original patcher)
```bash
chmod +x patch.sh
./patch.sh --wineprefix ~/.wine
```
`patch.sh` builds and deploys the `libusb-1.0.dll` stub. Its Roland ASIO / USB
registration and `.exe` binary-patch steps are harmless no-ops for the FLX4
(they either skip on an unknown Serato version or register unused devices).

### 3. Deploy the Wine DLL patches + register the FLX4 USB device
```bash
chmod +x apply.sh
./apply.sh
```
`apply.sh` copies the prebuilt `winealsa.so` / `winmm.dll` into your system Wine
(backing up the originals as `*.orig`) and adds the FLX4 USB entry to the Wine
registry.

> **Prebuilt binaries are Wine-version-specific.** They were built against the
> version in `prebuilt/WINE_VERSION.txt`. If your Wine differs, **rebuild** (see
> below) — a mismatched `winealsa.so` will fail to load with an ELF/ABI error.

### 4. Launch Serato and connect the FLX4.

To revert the Wine DLL changes:
```bash
./restore.sh
```

---

## Rebuilding the Wine patches (if your Wine version differs)

```bash
# Get the matching Wine source (match your installed version)
git clone --depth 1 -b wine-10.0 https://github.com/wine-mirror/wine.git ~/wine-build
cd ~/wine-build
git apply /path/to/serato-flx4-linux/wine-flx4.patch

./configure --enable-win64
make dlls/winealsa.drv/winealsa.so
make dlls/winmm/x86_64-windows/winmm.dll

# Deploy (adjust paths to your distro's Wine layout)
sudo cp dlls/winealsa.drv/winealsa.so          /usr/lib/wine/x86_64-unix/winealsa.so
sudo cp dlls/winmm/x86_64-windows/winmm.dll    /usr/lib/wine/x86_64-windows/winmm.dll
```

The full tree build (`make`) may fail on unrelated test binaries (e.g. dwrite
tests); building the two targets above directly avoids that.

---

## What gets changed

| File | Change |
|---|---|
| `<serato-dir>/libusb-1.0.dll` | Replaced with stub via `patch.sh` (original saved as `.orig`) |
| `/usr/lib/wine/x86_64-unix/winealsa.so` | Patched (original saved as `.orig` by `apply.sh`) |
| `/usr/lib/wine/x86_64-windows/winmm.dll` | Patched (original saved as `.orig` by `apply.sh`) |
| Wine registry `HKLM\SYSTEM\...\Enum\USB\VID_2B73&PID_0045` | FLX4 USB device entry |

---

## Verifying

Run Serato with MIDI tracing and watch for the FLX4 connecting:
```bash
WINEDEBUG=+midi wine "C:\Program Files\Serato\Serato DJ Pro\Serato DJ Pro.exe" 2>&1 | tee /tmp/serato.log
grep -E "vid=2b73|direction=duplex|CONNECTED" /tmp/serato.log
```
Success looks like:
```
New MIDI Connection: DDJ-FLX4 ... pid=0045 & vid=2b73 & direction=duplex
***CONNECTED*** Pioneer DDJ-FLX4 VID: 0x2b73 PID: 0x0045
```

---

## Aggregation flow (for contributors)

```
libusb USB scan (stub)
  → reads HKLM\SYSTEM\...\Enum\USB\VID_2B73&PID_0045\512&256&1&0
  → confirms presence via /sys/bus/usb/devices/
  → "New USB Connection: Vid=0x2b73&Pid=0x45"

MIDI association
  → OUT: winmm midiOutMessage → MMDRV_PhysicalFeatures
         → winealsa DRV_QUERYDEVICEINTERFACE returns path w/ VID_2B73&PID_0045
  → IN:  winmm midiInMessage → MMDRV_PhysicalFeatures  [added by this fork]
         → winealsa DRV_QUERYDEVICEINTERFACE returns same path
  → IN and OUT share unique_group → merged into one direction=duplex connection

Hardware mode
  → "***CONNECTED*** Pioneer DDJ-FLX4"
  → Minimum firmware version installed
```

Notes:
- The `winealsa` handler matches on the ALSA port name containing `FLX4`. To
  support another controller, change the match string, the VID/PID, and the
  interface path.
- No `.exe` binary patch is used; the FLX4 aggregates on the first attempts
  without the DJ-808 vtable-gate NOPs.

---

## Licensing note (Serato, not Wine)

Hardware detection is independent of your Serato license. The FLX4 is a Serato
DJ **Lite** hardware-unlock device; using it with Serato DJ **Pro** requires an
active Pro license/subscription. On Serato DJ Pro 4.0.x this is a subscription
even if a controller shipped with a perpetual unlock — with an expired/cancelled
subscription Serato will show the controller as connected but stay in trial/
unlicensed mode. This is a Serato account matter, not a Wine/patch issue.

---

## Credits & License

Forked from [anolis/serato-dj808-linux](https://github.com/anolis/serato-dj808-linux) (MIT).
The `winealsa.so` / `winmm.dll` changes are provided as a source patch
(`wine-flx4.patch`) against the Wine tree; Wine is LGPL. No Serato code is
included or redistributed — only VID/PID values and a MIDI interface path string.

MIT.
