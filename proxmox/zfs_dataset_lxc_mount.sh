#!/bin/bash
# Create ZFS Dataset, find and create mount point with given LXC CTID and 
# CTID, Dataset-Prefix (Dataset Name = Dataset-Prefix + CTID) mount path and size can be passed as arguments


# ===== INPUT ARGUMENTS =====
CTID="$1"
DATASET_PREFIX="$2"
MOUNTPOINT="$3"
UserID=$4
GroupID=$5
CACHE_SIZE="${6:-50G}"


ZFS_POOL="rpool/data"
ZFS_DATASET="${ZFS_POOL}/${DATASET_PREFIX}-${CTID}"
LXC_CONF="/etc/pve/lxc/${CTID}.conf"

# ===== CHECKS =====
if [ -z "$CTID" ] || [ -z "$DATASET_PREFIX" ] || [ -z "$MOUNTPOINT" ]; then
  echo "Usage: $0 <CTID> <DatasetPrefix> <MountPath> [CacheSize]"
  echo "Example: $0 101 tdarr-cache /cache 50G"
  exit 1
fi

if ! pct status "$CTID" &>/dev/null; then
  echo "❌ Container ID $CTID does not exist."
  exit 1
fi

if zfs list "$ZFS_DATASET" &>/dev/null; then
  echo "⚠️ Dataset $ZFS_DATASET already exists."
else
  echo "✅ Creating ZFS dataset $ZFS_DATASET with quota $CACHE_SIZE..."
  if zfs create -o quota="$CACHE_SIZE" -o mountpoint=none "$ZFS_DATASET"; then
    echo "✅ Dataset $ZFS_DATASET created successfully."
  else
    echo "❌ Failed to create ZFS dataset $ZFS_DATASET."
    exit 1
  fi
fi

# ===== FIND AVAILABLE mpX SLOT =====
for i in {0..9}; do
  if ! grep -q "^mp$i:" "$LXC_CONF"; then
    if [ -z "$UserID" ] && [ -z "$GroupID" ]; then
      MP_ENTRY="mp$i: /${ZFS_DATASET},mp=${MOUNTPOINT}"
    else
      MP_ENTRY="mp$i: /${ZFS_DATASET},mp=${MOUNTPOINT},UserID=${UserID},GroupID=${GroupID}"
    fi
    echo "✅ Adding mount to container config: $MP_ENTRY"
    echo "$MP_ENTRY" >> "$LXC_CONF"
    echo "✅ Done! Restart container $CTID to apply changes."
    exit 0
  fi
done

echo "❌ No free mpX slot found in $LXC_CONF"
exit 1
