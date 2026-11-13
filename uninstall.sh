#!/system/bin/sh
# x625d-proaudio — release bind mounts; /vendor is never written.
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/x625d-proaudio

LOG=$MODDIR/proaudio.log
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [uninst] $*" >> "$LOG"; }

for t in /vendor/lib/hw/audio.primary.mt6765.so \
         /vendor/lib/hw/audio.primary.default.so \
         /vendor/etc/audio_policy_configuration.xml \
         /vendor/etc/permissions; do
    if grep -q " $t " /proc/mounts 2>/dev/null; then
        umount "$t" 2>/dev/null && log "unmounted: $t" || log "WARN: failed to unmount $t"
    fi
done

log "uninstalled; reboot recommended"
exit 0
