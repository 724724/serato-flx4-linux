# Serato DJ Pro + DDJ-FLX4 on Wine

This project enables Pioneer/AlphaTheta DDJ-FLX4 hardware mode in Serato DJ Pro running through Wine on Linux, with clean MASTER and CUE output.

## Current status

- DDJ-FLX4 USB/MIDI detection and Serato hardware mode work
- FLX4 MASTER 1/2 and headphone CUE 3/4 play cleanly
- Fixes the severe distortion caused by Wine advertising PCM data as IEEE float
- Mirrors FLX4 MASTER 1/2 to the laptop speakers
- Maps a writable music directory to Wine `M:` to prevent `This drive is read only`
- Does not bypass Serato licensing

The laptop-speaker mirror requests approximately 100 ms of ALSA latency. Use the FLX4 outputs and headphone jack for live monitoring and CUE.

## Tested environment

| Component | Version/value |
|---|---|
| Distribution | Arch Linux based |
| Wine | `wine-stable 10.0-2` / Wine `10.0` |
| Serato DJ Pro | `4.0.7.240` |
| Controller | DDJ-FLX4 |
| USB ID | `2b73:0045` |
| Architecture | `x86_64` |
| Wine prefix | `~/.wine` |
| Wine DLL path | `/usr/lib/wine/x86_64-{unix,windows}` |

The binaries under `prebuilt/` are built for Wine 10.0. If your Wine version or distribution DLL layout differs, do not install them directly. Follow [Rebuilding from Wine source](#rebuilding-from-wine-source) instead. `apply.sh` replaces system-wide Wine files, so its binaries affect every prefix using that Wine installation.

## Repository layout

| File | Purpose |
|---|---|
| `wine-flx4.patch` | Core Wine MMDevice, ALSA audio/MIDI, and WinMM patch |
| `laptop-mirror.patch` | Mirrors FLX4 MASTER 1/2 to ALSA `default` |
| `prebuilt/winealsa.so` | Patched ALSA driver for Wine 10.0 |
| `prebuilt/mmdevapi.dll` | Patched MMDevice DLL for Wine 10.0 |
| `prebuilt/winmm.dll` | Patched WinMM DLL for Wine 10.0 |
| `patch.sh` | Installs the Serato libusb stub, launcher, OAuth handler, and `M:` music drive |
| `apply.sh` | Registers the FLX4, selects Wine ALSA, and installs the prebuilt binaries |
| `restore.sh` | Restores the system Wine files backed up by `apply.sh` |
| `config/51-ddj-flx4.conf` | Prevents PipeWire/WirePlumber from claiming the FLX4 |

## Installation

### 1. Install and activate Serato

Install Serato DJ Pro in the default Wine prefix, then finish login and license activation before applying the patches.

```bash
export WINEPREFIX="$HOME/.wine"
wine /path/to/Serato-DJ-Pro.exe
```

The resulting installation must exist at:

```text
~/.wine/drive_c/Program Files/Serato/Serato DJ Pro/Serato DJ Pro.exe
```

Close Serato and stop the prefix before continuing.

```bash
WINEPREFIX="$HOME/.wine" wineserver -k
```

### 2. Install dependencies

Arch Linux:

```bash
yay -S wine-stable 
```

```bash
sudo pacman -S --needed mingw-w64-gcc gcc python xdg-utils alsa-lib base-devel
```

If your repositories do not provide `wine-stable`, substitute the package that provides your Wine 10.0 installation.

### 3. Clone the repository

```bash
git clone https://github.com/724724/serato-flx4-linux.git
cd serato-flx4-linux
chmod +x patch.sh apply.sh restore.sh
```

### 4. Verify the FLX4

Connect the FLX4 and verify its USB ID.

```bash
lsusb -d 2b73:0045
cat /proc/asound/cards
```

This patch targets `VID=2B73`, `PID=0045`, and the ALSA card name `DDJ-FLX4`.

### 5. Release the FLX4 from PipeWire

With Serato closed, install the WirePlumber rule.

```bash
install -Dm644 config/51-ddj-flx4.conf \
  "$HOME/.config/wireplumber/wireplumber.conf.d/51-ddj-flx4.conf"
systemctl --user restart wireplumber
```

Disconnect and reconnect the FLX4. Its audio card should no longer appear in `wpctl status`, but it should remain visible under `/proc/asound/cards`.

```bash
wpctl status
cat /proc/asound/cards
```

This rule only releases the FLX4 from PipeWire. Wine's `winealsa` driver opens the raw FLX4 ALSA device directly. The built-in speakers and normal desktop audio continue to use PipeWire.

### 6. Patch the Serato files and launch environment

Create the music directory if necessary, then run `patch.sh`.

```bash
mkdir -p "$HOME/Music"
./patch.sh --wineprefix "$HOME/.wine" --music-dir "$HOME/Music"
```

The script performs the following operations:

- Replaces Serato's `libusb-1.0.dll` with the USB discovery stub and saves the original as `.orig`
- Maps Wine `M:` to `--music-dir` and sets Windows `My Music` to `M:\`
- Installs the OAuth URI handler and desktop entry
- Creates the `~/.local/bin/serato-dj-pro` launch wrapper
- Adds `WINE_FLX4_LAPTOP_MIRROR=1` to the launch wrapper
- On Serato 4.0.7, applies the inherited USB aggregation EXE patch and creates a `.bak_dj808_4_0_7` backup

This repository does not contain the Roland ASIO stub sources, so `patch.sh` automatically skips those inherited steps. The FLX4 audio fix is implemented in Wine, not in the Serato executable.

If Wine `M:` already points somewhere else, the script stops instead of overwriting it. Inspect the existing mapping, then clean it up manually or use another prefix.

### 7. Install the Wine patches

First confirm that the installed Wine version is exactly 10.0 and that its DLLs are under `/usr/lib/wine`.

```bash
wine --version
test -f /usr/lib/wine/x86_64-unix/winealsa.so
test -f /usr/lib/wine/x86_64-windows/mmdevapi.dll
test -f /usr/lib/wine/x86_64-windows/winmm.dll
```

If all conditions match, apply the prebuilt binaries.

```bash
WINEPREFIX="$HOME/.wine" ./apply.sh
```

`apply.sh` performs the following operations:

- Registers `HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_2B73&PID_0045`
- Sets `Audio=alsa` under `HKCU\Software\Wine\Drivers`
- Backs up the system `winealsa.so`, `mmdevapi.dll`, and `winmm.dll` as `*.orig` on the first run
- Installs the patched binaries from `prebuilt/`

### 8. Launch and configure Serato

Connect the FLX4 and launch Serato through the generated wrapper.

```bash
WINEPREFIX="$HOME/.wine" wineserver -k
"$HOME/.local/bin/serato-dj-pro"
```

Serato configuration:

- Keep Serato's built-in **Use Laptop Speakers** option disabled.
- Use the FLX4 outputs for MASTER and its headphone jack for CUE.
- The launch wrapper separately mirrors FLX4 MASTER 1/2 to the laptop speakers.

Serato's built-in **Use Laptop Speakers** path produces already-corrupted secondary PCM under Wine. Enabling it mixes the distorted path back into the output.

## Importing music and fixing `This drive is read only`

Wine maps `Z:` to the Linux root directory `/`. When Serato imports a file through `Z:`, it attempts to create `Z:\_Serato_`, which resolves to `/_Serato_` on Linux. A normal user cannot write there, so Serato reports `This drive is read only`.

Use either of these methods:

1. Store tracks under the `~/Music` directory supplied through `--music-dir`, then import them from **Files → M:** in Serato.
2. Drag files into Serato only from locations under `~/Music`.

Verify the mapping:

```bash
readlink -f "$HOME/.wine/dosdevices/m:"
WINEPREFIX="$HOME/.wine" winepath -w "$HOME/Music"
```

The expected results are `/home/<user>/Music` and `M:\`. To use another disk as the library root, provide that path when first running the patcher.

```bash
./patch.sh --wineprefix "$HOME/.wine" --music-dir "/mnt/music"
```

## Patch details

### USB and MIDI association

- The libusb stub reads VID/PID values from Wine's USB registry and confirms physical presence through Linux sysfs.
- `winealsa` handles `DRV_QUERYDEVICEINTERFACE` and `DRV_QUERYDEVICEINTERFACESIZE` for FLX4 MIDI IN and OUT.
- MIDI IN and OUT expose `wMid=0x2b73` and `wPid=0x0045`.
- `winmm.dll` adds the missing `MMDRV_PhysicalFeatures` fallback to `midiInMessage`.
- MIDI IN and OUT return the same USB interface path, allowing Serato to merge them into one duplex device.

### FLX4 audio distortion fix

Serato opens the FLX4 as a 48 kHz, four-channel WASAPI exclusive/event-driven device. The original Wine path has several problems:

1. `winepulse` rejects exclusive mode. The prefix is forced to the `alsa` driver so Wine can use raw ALSA.
2. Wine MMDevice rejects `EXCLUSIVE + EVENTCALLBACK`. The patch emulates it with timer-driven operation using a 256-frame period and eight periods, for a total 2048-frame buffer.
3. The unconstrained channel count reported by `plughw` causes Wine to reduce the FLX4 to stereo. The patch queries the raw `hw:` device and exposes all four channels.
4. Serato writes signed 32-bit PCM, but Wine advertises the FLX4 render endpoint as IEEE float. Interpreting the PCM bit patterns as floats saturates the USB output and directly causes the severe distortion. The patch advertises the four-channel FLX4 render endpoint as 32-bit `KSDATAFORMAT_SUBTYPE_PCM`.
5. Wine session volume is not reapplied to exclusive streams, preventing gain changes from producing zipper noise.
6. The ALSA pump thread requests best-effort `SCHED_FIFO` priority 10 for additional scheduling and underrun headroom.

The verified FLX4 output path is a 48 kHz, four-channel signed 32-bit application stream with a 256-frame ALSA period and a 2048-frame buffer. ALSA converts it to the USB device's S24_3LE format.

### Laptop-speaker mirror

`laptop-mirror.patch` copies MASTER channels 1/2 from the clean four-channel FLX4 S32 stream and writes them to a 48 kHz stereo S32 stream on ALSA `default`.

- Environment variable: `WINE_FLX4_LAPTOP_MIRROR=1`
- Source requirement: 48 kHz, four-channel, S32 render stream
- Source channels: FLX4 MASTER 1/2
- Destination: ALSA `default`
- Requested latency: 100,000 µs
- Uses non-blocking writes and ALSA recovery

FLX4 CUE channels 3/4 are not included in the mirror.

## Verification

Registry:

```bash
WINEPREFIX="$HOME/.wine" wine reg query 'HKCU\Software\Wine\Drivers' /v Audio
WINEPREFIX="$HOME/.wine" wine reg query \
  'HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_2B73&PID_0045\512&256&1&0'
```

Files and launch wrapper:

```bash
test -x "$HOME/.local/bin/serato-dj-pro"
grep WINE_FLX4_LAPTOP_MIRROR "$HOME/.local/bin/serato-dj-pro"
sha256sum prebuilt/winealsa.so /usr/lib/wine/x86_64-unix/winealsa.so
sha256sum prebuilt/mmdevapi.dll /usr/lib/wine/x86_64-windows/mmdevapi.dll
sha256sum prebuilt/winmm.dll /usr/lib/wine/x86_64-windows/winmm.dll
```

Each prebuilt binary must have the same hash as its installed counterpart.

## Rebuilding from Wine source

Use the same Wine source version as your installed Wine. Apply the two patches in the exact order shown below.

```bash
REPO="$PWD"
git clone --depth 1 --branch wine-10.0 \
  https://github.com/wine-mirror/wine.git "$HOME/wine-build"
cd "$HOME/wine-build"
git apply "$REPO/wine-flx4.patch"
git apply "$REPO/laptop-mirror.patch"
./configure --enable-win64
make -j"$(nproc)" \
  dlls/winealsa.drv/winealsa.so \
  dlls/mmdevapi/x86_64-windows/mmdevapi.dll \
  dlls/winmm/x86_64-windows/winmm.dll
```

Verify the patch state:

```bash
git diff --check
git apply --reverse --check "$REPO/laptop-mirror.patch"
```

Copy the newly built binaries into `prebuilt/`, then run `apply.sh`.

```bash
cp dlls/winealsa.drv/winealsa.so "$REPO/prebuilt/winealsa.so"
cp dlls/mmdevapi/x86_64-windows/mmdevapi.dll "$REPO/prebuilt/mmdevapi.dll"
cp dlls/winmm/x86_64-windows/winmm.dll "$REPO/prebuilt/winmm.dll"
printf '%s\n' "$(wine --version)" > "$REPO/prebuilt/WINE_VERSION.txt"
cd "$REPO"
WINEPREFIX="$HOME/.wine" ./apply.sh
```

A full Wine-tree `make` may fail on unrelated test binaries. This deployment only requires the three targets above to build successfully.

## Restoring the original files

Close Serato and stop Wine before restoring the system files backed up by `apply.sh`.

```bash
WINEPREFIX="$HOME/.wine" wineserver -k
WINEPREFIX="$HOME/.wine" ./restore.sh
```

To remove the WirePlumber rule as well, run the following commands and reconnect the FLX4.

```bash
rm "$HOME/.config/wireplumber/wireplumber.conf.d/51-ddj-flx4.conf"
systemctl --user restart wireplumber
```

`restore.sh` does not automatically restore the `M:` mapping, launch wrapper, libusb stub, or Serato EXE modified by `patch.sh`. Inspect these paths if you need to restore them manually:

```text
~/.wine/drive_c/Program Files/Serato/Serato DJ Pro/libusb-1.0.dll.orig
~/.wine/drive_c/Program Files/Serato/Serato DJ Pro/Serato DJ Pro.exe.bak_dj808_4_0_7
~/.wine/dosdevices/m:
~/.local/bin/serato-dj-pro
```

## Troubleshooting

### The FLX4 does not connect

- Verify the USB ID with `lsusb -d 2b73:0045`.
- Check for FLX4 MIDI ports with `aconnect -l` or `aplaymidi -l`.
- Confirm that `patch.sh` and `apply.sh` used the same `WINEPREFIX`.
- Launch Serato through `~/.local/bin/serato-dj-pro`, not by running its EXE directly.

### FLX4 MASTER or CUE is distorted

- Fully stop Serato and Wine, then restart them.
- Confirm that `wpctl status` does not list the FLX4 audio card.
- Verify the `Audio=alsa` registry value and installed `winealsa.so` hash.
- Confirm that the Wine version matches `prebuilt/WINE_VERSION.txt`.
- Changing only the Serato buffer size cannot fix the PCM/float format mismatch.

### FLX4 CUE is clean, but the laptop speakers are distorted

- Disable Serato's built-in **Use Laptop Speakers** option.
- Confirm that the wrapper exports `WINE_FLX4_LAPTOP_MIRROR=1`.
- Use `aplay -L` to verify that ALSA `default` routes to the built-in speakers.

### Dragging music produces a read-only error

- Use `M:` instead of a `Z:` path.
- Move the files under the directory supplied through `--music-dir`.
- Verify the `~/.wine/dosdevices/m:` symlink and `winepath -w` result.

## Licensing

You must provide a valid Serato DJ Pro license and account login. This repository does not bypass licensing or distribute Serato code.

Based on [anolis/serato-dj808-linux](https://github.com/anolis/serato-dj808-linux).

Repository code is MIT licensed. Patches against Wine source remain subject to Wine's LGPL terms.
