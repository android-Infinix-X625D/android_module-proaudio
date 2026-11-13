#!/system/bin/sh
# x625d-proaudio — post-boot verification (does not change anything).
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/x625d-proaudio

LOG=$MODDIR/proaudio.log
T_HAL=/vendor/lib/hw/audio.primary.mt6765.so
T_ORIG=/vendor/lib/hw/audio.primary.default.so
T_POLICY=/vendor/etc/audio_policy_configuration.xml
T_PERMS=/vendor/etc/permissions

SHIM_SHA=718b988b30b5ee8dcb29b38f06eb1cba6b976ef1981a4d0c5bc88b1cbf6d05ce
ORIG_SHA=85a0e5165cdb123b73e0656dafc9217351a752cf22323023af917296acf059f8

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [svc] $*" >> "$LOG"; }
sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

log "service start uptime=$(cut -d. -f1 /proc/uptime 2>/dev/null)s"

# wait for boot to finish (max 90 s)
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 90 ]; do
    sleep 1
    i=$((i+1))
done

# mounts + sha
if grep -q " $T_HAL " /proc/mounts 2>/dev/null; then
    log "HAL mount: present"
else
    log "WARN: HAL mount missing"
fi
[ "$(sha_of "$T_HAL")" = "$SHIM_SHA" ] \
    && log "target shim HAL: OK" \
    || log "WARN: target shim HAL=$(sha_of "$T_HAL")"

[ "$(sha_of "$T_ORIG")" = "$ORIG_SHA" ] \
    && log "target stock HAL: OK" \
    || log "WARN: target stock HAL=$(sha_of "$T_ORIG")"

if grep -q " $T_POLICY " /proc/mounts 2>/dev/null; then
    log "policy mount: present (mmap=$(grep -c mmap_no_irq_out "$T_POLICY"))"
else
    log "WARN: policy mount missing"
fi

if grep -q " $T_PERMS " /proc/mounts 2>/dev/null; then
    log "permissions mount: present ($(ls "$T_PERMS" | wc -l) files, pro=$(ls "$T_PERMS"/android.hardware.audio.pro.xml 2>/dev/null | wc -l))"
else
    log "WARN: permissions mount missing"
fi

# AAudio properties + service
log "props: mmap=$(getprop aaudio.mmap_policy) exclusive=$(getprop aaudio.mmap_exclusive_policy)"
if service list 2>/dev/null | grep -q 'media.aaudio'; then
    log "media.aaudio: registered"
else
    log "WARN: media.aaudio not registered"
fi

if pm list features 2>/dev/null | grep -q 'android.hardware.audio.pro'; then
    log "feature audio.pro: present"
else
    log "WARN: feature audio.pro missing"
fi

# summarize the last probe if the test binary is present
if [ -x /data/local/tmp/aaudio_mmap_test ]; then
    log "probe available: /data/local/tmp/aaudio_mmap_test 1"
fi

log "service done"
exit 0
