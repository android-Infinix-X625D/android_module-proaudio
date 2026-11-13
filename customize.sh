#!/system/bin/sh
# x625d-proaudio — installer hook (KernelSU / Magisk).
MODPATH="${MODPATH:-$PWD}"

ui_print() { echo "$1"; }

# Module id changed in the past: proaudio_x625d -> x625d-proaudio. Remove the
# old module so two post-fs-data scripts cannot fight over the same mounts.
LEGACY=/data/adb/modules/proaudio_x625d
if [ -d "$LEGACY" ] && [ "$LEGACY" != "$MODPATH" ]; then
    rm -rf "$LEGACY" && ui_print "- removed old module proaudio_x625d"
fi

# Drop leftovers from older layouts (vendor/ + permissions/ in the module root).
rm -rf "$MODPATH/vendor" "$MODPATH/permissions" "$MODPATH/permissions_merged"
# Only android.hardware.audio.pro.xml belongs in the permissions folder.
find "$MODPATH/files/vendor/etc/permissions" -type f \
    ! -name android.hardware.audio.pro.xml -delete 2>/dev/null

if type set_perm_recursive >/dev/null 2>&1; then
    set_perm_recursive "$MODPATH" 0 0 0755 0644
    set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
    set_perm "$MODPATH/service.sh" 0 0 0755
    set_perm "$MODPATH/action.sh" 0 0 0755
    set_perm "$MODPATH/uninstall.sh" 0 0 0755
    set_perm "$MODPATH/customize.sh" 0 0 0755
else
    chmod 755 "$MODPATH" "$MODPATH"/*.sh
    chmod 644 "$MODPATH/module.prop" "$MODPATH/README.md" 2>/dev/null
    find "$MODPATH/files" -type f -exec chmod 644 {} \; 2>/dev/null
fi

if [ ! -f "$MODPATH/files/vendor/lib/hw/audio.primary.mt6765.so" ] || \
   [ ! -f "$MODPATH/files/vendor/lib/hw/audio.primary.mt6765.so.orig" ]; then
    ui_print "! incomplete HAL files"
    exit 1
fi
if ! grep -q mmap_no_irq_out "$MODPATH/files/vendor/etc/audio_policy_configuration.xml" 2>/dev/null; then
    ui_print "! policy is missing mmap_no_irq_out"
    exit 1
fi
PERM="$MODPATH/files/vendor/etc/permissions/android.hardware.audio.pro.xml"
if [ ! -f "$PERM" ] || ! grep -q android.hardware.audio.pro "$PERM"; then
    ui_print "! android.hardware.audio.pro.xml is incomplete"
    exit 1
fi

ui_print "- x625d-proaudio: HAL shim + MMAP/NOIRQ"
ui_print "- reboot to activate"
exit 0
