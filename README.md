# Infinix X625D - Pro Audio (MMAP/NOIRQ)

Root module (KernelSU/Magisk) for the Infinix Hot 7 Pro **X625D** (MT6765, Android 9) that enables **Pro Audio** and AAudio **MMAP / MMAP_NOIRQ EXCLUSIVE** playback.


## Result

- `android.hardware.audio.pro` is declared
- `media.aaudio` (`IAAudioService`) is running
- AAudio: `sharing=0` (EXCLUSIVE), `perf=12` (LOW_LATENCY), burst 256 / capacity 2048
- `AudioMmapOut_*` type 5 (MMAP), PCM7 RUNNING, 440 Hz tone audible


## Why a shim HAL

The stock MTK HAL can already play audio, but 4 MMAP pointers in its 32-bit `audio_stream_out` are `NULL`, so `createMmapBuffer()` always fails.

A small 32-bit shim `audio.primary.mt6765.so` `dlopen()`s the stock HAL, copies the struct and fills in:

| offset | field |
|---|---|
| `0x64` | `start` |
| `0x68` | `stop` |
| `0x6C` | `create_mmap_buffer` |
| `0x70` | `get_mmap_position` |

Only streams with `AUDIO_OUTPUT_FLAG_MMAP_NOIRQ` (`0x4001`) use the new pointers; normal streams go straight to the stock HAL. A copy thread reads the ring buffer and calls the stock `out_write()` with realtime pacing.


## What the patch changes

- **Shim HAL** — mounted over `/vendor/lib/hw/audio.primary.mt6765.so`; the stock HAL is mounted over `audio.primary.default.so`.
- **Audio policy** — one extra mixPort plus its `sources` entries:

  ```xml
  <mixPort name="mmap_no_irq_out" role="source"
           flags="AUDIO_OUTPUT_FLAG_DIRECT|AUDIO_OUTPUT_FLAG_MMAP_NOIRQ">
  ```

- **Permissions** — new files cannot be created in `/vendor`, so `post-fs-data` copies `/vendor/etc/permissions` to `/data/local/tmp/proaudio_permissions`, adds `android.hardware.audio.pro.xml`, and bind-mounts the directory back (23 files).
- **Properties** — `aaudio.mmap_policy=2` and `aaudio.mmap_exclusive_policy=2` are set every boot (not `persist.*`).

Stock hashes: HAL `85a0e516…`, policy `720c734a…`. The module guards its own sources by sha256 and skips the mounts if anything changed.


## How it works at boot

`/vendor` is never written. `post-fs-data.sh` bind-mounts the prepared files before audioserver starts, then `service.sh` verifies mounts, hashes, properties, the `media.aaudio` service and the `audio.pro` feature.

The bind mounts are manual because the KernelSU build on this device does not magic-mount module files into `/vendor`. Removing the module unmounts everything; a reboot restores stock.


## Verification

Log: `/data/adb/modules/x625d-proaudio/proaudio.log`

```
[pfd] source sha OK
[pfd] shim HAL active: 718b988b30b5ee8d
[pfd] stock HAL active: 85a0e5165cdb123b
[pfd] policy: mmap=13
[pfd] permissions: 23 files, pro=1
[pfd] aaudio.mmap_policy=2 exclusive=2
[svc] media.aaudio: registered
[svc] feature audio.pro: present
```

Next boot, the Action button in KernelSU shows mount, sha, policy, permissions and AAudio status.


## Notes

- Sound is routed through the stock HAL, so effects, volume and routing behave exactly as stock.
- MMAP EXCLUSIVE only applies to apps that request it (`AAudioStreamBuilder_setSharingMode(EXCLUSIVE)`); other apps keep using normal AudioTrack.
- Reverse engineered from the stock `audio.primary.mt6765.so`; the stock file itself is shipped unchanged as `audio.primary.mt6765.so.orig`.


## Credits

Built with **OpenCode** — the AI coding agent used for the reverse engineering, shim HAL, on-device testing, and module packaging.
