#!/system/bin/sh
# x625d-proaudio — status output for the Action button in KernelSU/Magisk.
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/x625d-proaudio

LOG=$MODDIR/proaudio.log
T_HAL=/vendor/lib/hw/audio.primary.mt6765.so
T_ORIG=/vendor/lib/hw/audio.primary.default.so
T_POLICY=/vendor/etc/audio_policy_configuration.xml
T_PERMS=/vendor/etc/permissions

SHIM_SHA=718b988b30b5ee8dcb29b38f06eb1cba6b976ef1981a4d0c5bc88b1cbf6d05ce
ORIG_SHA=85a0e5165cdb123b73e0656dafc9217351a752cf22323023af917296acf059f8

sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

echo "== x625d-proaudio =="

if grep -q " $T_HAL " /proc/mounts 2>/dev/null; then
    echo "HAL shim    : ACTIVE"
else
    echo "HAL shim    : not mounted"
fi
[ "$(sha_of "$T_HAL")" = "$SHIM_SHA" ] && echo "shim sha    : OK" || echo "shim sha    : $(sha_of "$T_HAL")"

[ "$(sha_of "$T_ORIG")" = "$ORIG_SHA" ] && echo "stock HAL   : OK" || echo "stock HAL   : $(sha_of "$T_ORIG")"

if grep -q " $T_POLICY " /proc/mounts 2>/dev/null; then
    echo "policy      : ACTIVE (mmap=$(grep -c mmap_no_irq_out "$T_POLICY"))"
else
    echo "policy      : not mounted"
fi

if grep -q " $T_PERMS " /proc/mounts 2>/dev/null; then
    echo "permissions : ACTIVE ($(ls "$T_PERMS" | wc -l) files + audio.pro)"
else
    echo "permissions : not mounted"
fi

echo "prop mmap   : $(getprop aaudio.mmap_policy) / exclusive $(getprop aaudio.mmap_exclusive_policy)"
service list 2>/dev/null | grep -q 'media.aaudio' && echo "media.aaudio: registered" || echo "media.aaudio: NOT registered"
pm list features 2>/dev/null | grep -q 'android.hardware.audio.pro' && echo "audio.pro   : present" || echo "audio.pro   : NOT present"

echo
echo "== last log =="
tail -6 "$LOG" 2>/dev/null

echo
echo "Audible test: /data/local/tmp/aaudio_mmap_test 1"
echo "Check MMAP  : dumpsys media.audio_flinger | grep AudioMmap"
