#!/bin/bash
# Build the x625d-proaudio module zip.
#   ./build.sh  ->  ../x625d-proaudio_v1.0.0.zip
set -euo pipefail
cd "$(dirname "$0")"

VER=$(sed -n 's/^version=//p' module.prop)
ZIP="../x625d-proaudio_v$VER.zip"

chmod 755 post-fs-data.sh service.sh action.sh uninstall.sh customize.sh
chmod 644 module.prop README.md
find files -type f -exec chmod 644 {} \;

# quick pre-zip guards
[ -f files/vendor/lib/hw/audio.primary.mt6765.so ] || { echo "shim missing"; exit 1; }
[ -f files/vendor/lib/hw/audio.primary.mt6765.so.orig ] || { echo "stock HAL missing"; exit 1; }
grep -q mmap_no_irq_out files/vendor/etc/audio_policy_configuration.xml || { echo "policy not patched"; exit 1; }
[ -f files/vendor/etc/permissions/android.hardware.audio.pro.xml ] || { echo "pro permission missing"; exit 1; }
grep -q android.hardware.audio.pro files/vendor/etc/permissions/android.hardware.audio.pro.xml || { echo "audio.pro feature missing"; exit 1; }

rm -f "$ZIP"
zip -X -D -r -q "$ZIP" \
    module.prop customize.sh post-fs-data.sh service.sh \
    action.sh uninstall.sh README.md files

echo "built $ZIP"
sha256sum "$ZIP"
unzip -l "$ZIP"
