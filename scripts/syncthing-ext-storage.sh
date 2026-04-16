#!/bin/sh
# Move the syncthing.koplugin database off /mnt/us (VFAT) to /var/local (ext3).
#
# Why: Syncthing 2.x stores its state in SQLite with WAL journaling. VFAT's
# fsync semantics are unreliable, and under burst write load the SQLite WAL
# corrupts with errors like
#   "update (insert file): disk I/O error: no such file or directory"
# which puts Syncthing into a connect/crash loop against every peer.
# Moving the DB to an ext filesystem fixes this permanently.
#
# What this does:
#   1. Creates /var/local/syncthing (ext3, writable, persists across reboots)
#   2. Copies identity files (config.xml + cert.pem + key.pem + https-cert.pem
#      + https-key.pem) from the old VFAT home. The cert pair defines the
#      device ID — MUST be preserved so peers don't need re-introduction.
#   3. Patches syncthing.koplugin/main.lua's Syncthing:homePath() to return
#      /var/local/syncthing instead of DataStorage:getSettingsDir()/syncthing.
#   4. Leaves a .orig backup of main.lua alongside the patched version.
#
# Idempotent: safe to re-run.
#
# Run on-device (SSH into the Kindle):
#   /bin/sh syncthing-ext-storage.sh
#
# After running, restart KOReader (or reboot) so the koplugin re-launches
# Syncthing with the patched home path.
#
# Tested on: Kindle Paperwhite 5 (PW5). Other Kindles with /var/local on
# ext[234] should also work — the script checks for a writable /var/local.

set -e

PLUGIN=/mnt/us/koreader/plugins/syncthing.koplugin/main.lua
OLD_HOME=/mnt/us/koreader/settings/syncthing
NEW_HOME=/var/local/syncthing

if [ ! -f "$PLUGIN" ]; then
    echo "ERROR: $PLUGIN not found. Is syncthing.koplugin installed?" >&2
    exit 1
fi

if ! touch /var/local/.ext-probe 2>/dev/null; then
    echo "ERROR: /var/local is not writable. This script assumes an ext filesystem there." >&2
    exit 1
fi
rm -f /var/local/.ext-probe

# Step 1: create the new home
mkdir -p "$NEW_HOME"
chmod 755 "$NEW_HOME"

# Step 2: seed identity files (only if source exists and destination is absent
# — don't overwrite an already-migrated DB's config)
for f in config.xml config.xml.v51 cert.pem key.pem https-cert.pem https-key.pem device-id; do
    if [ -f "$OLD_HOME/$f" ] && [ ! -f "$NEW_HOME/$f" ]; then
        cp -p "$OLD_HOME/$f" "$NEW_HOME/$f"
        echo "  seeded $f"
    fi
done

# Step 3: patch the koplugin (idempotent)
if grep -q "/var/local/syncthing" "$PLUGIN"; then
    echo "  koplugin already patched"
else
    # Backup once
    if [ ! -f "${PLUGIN}.orig" ]; then
        cp "$PLUGIN" "${PLUGIN}.orig"
    fi
    # Replace the return line. This matches the upstream form exactly; if
    # upstream ever renames homePath() or changes the expression, the
    # script should be updated accordingly.
    sed -i 's|return DataStorage:getSettingsDir() \.\. "/syncthing"|-- Patched: DB on ext to avoid SQLite-on-VFAT corruption. See koreader-tweaks.\n    return "/var/local/syncthing"|' "$PLUGIN"
    if ! grep -q "/var/local/syncthing" "$PLUGIN"; then
        echo "ERROR: patch did not apply. Inspect $PLUGIN manually." >&2
        exit 1
    fi
    echo "  koplugin patched (backup at ${PLUGIN}.orig)"
fi

cat <<MSG

Migration complete. Next steps:

  1. Restart KOReader (or reboot). The syncthing.koplugin will relaunch
     Syncthing with --home=/var/local/syncthing.

  2. Verify the device ID is unchanged:
     curl -s -H "X-API-Key: \$TOKEN" http://localhost:8384/rest/system/status \\
       | grep myID

     It should still match the value in $OLD_HOME/device-id.

  3. Once you're satisfied the new location works, you can delete the old
     Syncthing home to reclaim VFAT space (the database files can be large):
       rm -rf $OLD_HOME/index-v2 $OLD_HOME/index-v0.14.0.db
     Keep $OLD_HOME/config.xml, cert.pem, key.pem for now as a recovery
     option; remove them when you're confident.

MSG
