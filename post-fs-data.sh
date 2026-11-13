#!/system/bin/sh
# x625d-proaudio — bind-mount the shim HAL, audio policy and vendor
# permissions before audioserver / the audio HAL starts.
#
# Same pattern as fix-wifi-driver-x625d:
#   files/vendor/...  -> source to install
#   /vendor/...       -> target (never written, only bind-mounted)
#
# Permissions: /vendor is read-only, so new files cannot be created there.
# The fix: copy /vendor/etc/permissions to a temporary directory under
# /data/local/tmp (outside the module), add audio.pro.xml, then bind-mount
# the whole copy.

MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/x625d-proaudio

SRC=$MODDIR/files/vendor
LOG=$MODDIR/proaudio.log
MERGED=/data/local/tmp/proaudio_permissions

SHIM=$SRC/lib/hw/audio.primary.mt6765.so
ORIG=$SRC/lib/hw/audio.primary.mt6765.so.orig
POLICY=$SRC/etc/audio_policy_configuration.xml
PRO=$SRC/etc/permissions/android.hardware.audio.pro.xml

T_HAL=/vendor/lib/hw/audio.primary.mt6765.so
T_ORIG=/vendor/lib/hw/audio.primary.default.so
T_POLICY=/vendor/etc/audio_policy_configuration.xml
T_PERMS=/vendor/etc/permissions

SHIM_SHA=718b988b30b5ee8dcb29b38f06eb1cba6b976ef1981a4d0c5bc88b1cbf6d05ce
ORIG_SHA=85a0e5165cdb123b73e0656dafc9217351a752cf22323023af917296acf059f8
POLICY_SHA=23b1688aa54a95e1cf41c514d40867049a9b548122238f813c68aca8622cafdd
PRO_SHA=4925c81f33258e110aae5225a287394cf4c0fbfb16f3551aeb4ba98ed4d322f8

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [pfd] $*" >> "$LOG"; }

# cap the log size
if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null || echo 0)" -gt 262144 ]; then
    mv -f "$LOG" "$LOG.old"
fi

log "start uptime=$(cut -d. -f1 /proc/uptime 2>/dev/null)s"

sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

# --- guard: every source must exist and be intact --------------------------
for f in "$SHIM" "$ORIG" "$POLICY" "$PRO"; do
    if [ ! -f "$f" ]; then
        log "ABORT: missing source: $f"
        exit 1
    fi
done
if [ "$(sha_of "$SHIM")" != "$SHIM_SHA" ]; then
    log "ABORT: shim sha mismatch (got $(sha_of "$SHIM"))"
    exit 1
fi
if [ "$(sha_of "$ORIG")" != "$ORIG_SHA" ]; then
    log "ABORT: stock HAL sha mismatch (got $(sha_of "$ORIG"))"
    exit 1
fi
if [ "$(sha_of "$POLICY")" != "$POLICY_SHA" ]; then
    log "ABORT: policy sha mismatch (got $(sha_of "$POLICY"))"
    exit 1
fi
if [ "$(sha_of "$PRO")" != "$PRO_SHA" ]; then
    log "ABORT: permission sha mismatch (got $(sha_of "$PRO"))"
    exit 1
fi
log "source sha OK"

# --- SELinux labels --------------------------------------------------------
chcon u:object_r:vendor_file:s0 "$SHIM" "$ORIG" 2>/dev/null || log "WARN: chcon lib failed"
chcon u:object_r:vendor_configs_file:s0 "$POLICY" "$PRO" 2>/dev/null || log "WARN: chcon config failed"

# --- release old mounts (script re-run / module upgrade) -------------------
# An older module version may have left mounts on this directory or file.
for t in /vendor/etc/permissions \
         /vendor/etc/permissions/android.hardware.audio.low_latency.xml \
         "$T_HAL" "$T_ORIG" "$T_POLICY"; do
    if grep -q " $t " /proc/mounts 2>/dev/null; then
        if umount "$t" 2>/dev/null; then
            log "unmounted old: $t"
        elif umount -l "$t" 2>/dev/null; then
            # A running HAL can make a normal umount fail with EBUSY;
            # a lazy umount frees the mountpoint for the new mount.
            log "lazy unmounted: $t"
        else
            log "WARN: failed to unmount old: $t"
        fi
    fi
done

# --- prepare the merged permissions directory ------------------------------
# /vendor/etc/permissions must be stock at this point (old mounts released).
NSTOCK=$(ls "$T_PERMS" 2>/dev/null | wc -l)
if [ "$NSTOCK" -lt 10 ]; then
    log "ABORT: /vendor/etc/permissions looks wrong ($NSTOCK files)"
    exit 1
fi
# clean up old directories left inside the module by earlier layouts
rm -rf "$MODDIR/permissions"
rm -rf "$MERGED"
mkdir -p "$MERGED" || { log "ABORT: failed to create $MERGED"; exit 1; }
if ! cp -a "$T_PERMS/." "$MERGED"/ 2>>"$LOG"; then
    log "ABORT: failed to copy stock permissions"
    exit 1
fi
cp -f "$PRO" "$MERGED"/ || { log "ABORT: failed to add audio.pro.xml"; exit 1; }
chcon -R u:object_r:vendor_configs_file:s0 "$MERGED" 2>/dev/null || log "WARN: chcon merged failed"
log "merged permissions: $(ls "$MERGED" | wc -l) files (stock $NSTOCK + pro)"

# --- bind mounts -----------------------------------------------------------
mount --bind "$MERGED" "$T_PERMS" || { log "ABORT: permissions bind mount failed"; exit 1; }
mount --bind "$POLICY" "$T_POLICY" || { log "ABORT: policy bind mount failed"; exit 1; }
mount --bind "$ORIG" "$T_ORIG" || { log "ABORT: stock HAL bind mount failed"; exit 1; }
mount --bind "$SHIM" "$T_HAL" || { log "ABORT: shim bind mount failed"; exit 1; }

# --- verify targets --------------------------------------------------------
[ "$(sha_of "$T_HAL")" = "$SHIM_SHA" ] \
    && log "shim HAL active: $(sha_of "$T_HAL" | cut -c1-16)" \
    || log "WARN: target shim sha=$(sha_of "$T_HAL")"
[ "$(sha_of "$T_ORIG")" = "$ORIG_SHA" ] \
    && log "stock HAL active: $(sha_of "$T_ORIG" | cut -c1-16)" \
    || log "WARN: target stock HAL sha=$(sha_of "$T_ORIG")"
log "policy: mmap=$(grep -c mmap_no_irq_out "$T_POLICY")"
log "permissions: $(ls "$T_PERMS" | wc -l) files, pro=$(grep -l android.hardware.audio.pro "$T_PERMS"/*.xml 2>/dev/null | wc -l)"

# --- AAudio properties -----------------------------------------------------
# Without these audioserver does not register media.aaudio. They are not
# persist.* properties, so they must be set on every boot before audioserver.
setprop aaudio.mmap_policy 2
setprop aaudio.mmap_exclusive_policy 2
log "aaudio.mmap_policy=$(getprop aaudio.mmap_policy) exclusive=$(getprop aaudio.mmap_exclusive_policy)"
log "done"
exit 0
