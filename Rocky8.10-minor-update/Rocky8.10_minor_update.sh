#!/bin/sh
set -eu

ISO_PATH="/root/Rocky-8.10-x86_64-dvd1.iso"
MNT_DIR="/mnt/rocky810_iso"
REPO_FILE="/etc/yum.repos.d/rocky-8.10-local.repo"
STATE_DIR="/root/rocky810_minor_update_state"
BACKUP_DIR="$STATE_DIR/repo_backup"
SCRIPT_VERSION="1.2.0"

BASEOS_REPO_ID="rocky-8.10-baseos"
APPSTREAM_REPO_ID="rocky-8.10-appstream"

MIN_ROOT_MB=3072
MIN_VAR_MB=5120
MIN_BOOT_MB=512

WORK_STARTED=0
RESTORE_ON_EXIT=0

fail() {
  echo "[FAIL] $1"
  exit 1
}

info() {
  echo "[INFO] $1"
}

ok() {
  echo "[ OK ] $1"
}

warn() {
  echo "[WARN] $1"
}

run_cmd() {
  info "Run: $*"
  "$@"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fail "This script must be run as root."
  fi
}

require_rocky8() {
  if [ ! -f /etc/rocky-release ]; then
    fail "This system is not Rocky Linux."
  fi

  if ! grep -qE '^Rocky Linux release 8\.' /etc/rocky-release; then
    fail "This system is not Rocky Linux 8.x."
  fi

  info "Current OS: $(cat /etc/rocky-release)"
  info "Current rocky-release package: $(rpm -q rocky-release || true)"
}

require_iso() {
  if [ ! -f "$ISO_PATH" ]; then
    fail "ISO file not found: $ISO_PATH"
  fi

  ok "ISO file found: $ISO_PATH"
}

free_mb() {
  df -Pm "$1" | awk 'NR==2 {print $4}'
}

check_mount_path() {
  parent_dir=$(dirname "$MNT_DIR")

  if [ ! -d "$parent_dir" ]; then
    fail "Mount parent directory does not exist: $parent_dir"
  fi

  if mountpoint -q "$MNT_DIR"; then
    warn "Mount point is already mounted: $MNT_DIR"
  else
    ok "ISO mount point is available: $MNT_DIR"
  fi
}

show_mount_status() {
  if mountpoint -q "$MNT_DIR"; then
    ok "ISO mount status: mounted"
    info "Mount point: $MNT_DIR"
    mount | grep " on $MNT_DIR " || true
  else
    info "ISO mount status: not mounted"
    info "Mount point: $MNT_DIR"
  fi
}

check_space_one() {
  path="$1"
  min_mb="$2"
  label="$3"

  if [ ! -e "$path" ]; then
    warn "$label path does not exist. Skipping space check: $path"
    return 0
  fi

  available_mb=$(free_mb "$path")
  if [ "$available_mb" -lt "$min_mb" ]; then
    fail "$label has insufficient free space: ${available_mb}MB available, ${min_mb}MB required"
  fi

  ok "$label free space check passed: ${available_mb}MB available"
}

check_space() {
  check_space_one "/" "$MIN_ROOT_MB" "/"
  check_space_one "/var" "$MIN_VAR_MB" "/var"
  check_space_one "/boot" "$MIN_BOOT_MB" "/boot"
}

check_environment() {
  require_root
  info "Script version: $SCRIPT_VERSION"
  require_rocky8
  require_iso
  check_space
  check_mount_path
  ok "Minor update environment check completed"
}

mount_iso() {
  mkdir -p "$MNT_DIR"

  if mountpoint -q "$MNT_DIR"; then
    info "Using existing ISO mount: $MNT_DIR"
  else
    run_cmd mount -o loop,ro "$ISO_PATH" "$MNT_DIR"
  fi

  if [ ! -d "$MNT_DIR/BaseOS" ]; then
    fail "BaseOS directory not found. Check that this is a Rocky Linux 8.10 DVD ISO."
  fi

  if [ ! -d "$MNT_DIR/AppStream" ]; then
    fail "AppStream directory not found. Check that this is a Rocky Linux 8.10 DVD ISO."
  fi

  ok "ISO mount and DVD repository structure check completed"
}

unmount_iso() {
  if mountpoint -q "$MNT_DIR"; then
    run_cmd umount "$MNT_DIR"
    ok "ISO unmounted: $MNT_DIR"
  else
    info "No mounted ISO found at: $MNT_DIR"
  fi
}

backup_repos() {
  repo_file_name=$(basename "$REPO_FILE")

  mkdir -p "$STATE_DIR"

  if [ -d "$BACKUP_DIR" ]; then
    warn "Repository backup already exists: $BACKUP_DIR"
    warn "Keeping the existing backup and skipping a new backup."
    return 0
  fi

  mkdir -p "$BACKUP_DIR"
  info "Backing up current repository files to: $BACKUP_DIR"

  repo_count=0
  for repo_file in /etc/yum.repos.d/*.repo; do
    [ -e "$repo_file" ] || continue
    [ "$(basename "$repo_file")" = "$repo_file_name" ] && continue
    run_cmd cp -a "$repo_file" "$BACKUP_DIR"/
    repo_count=$((repo_count + 1))
  done

  if [ "$repo_count" -eq 0 ]; then
    warn "No repository files found to back up."
    return 0
  fi

  ok "Repository backup completed"
}

disable_existing_repos() {
  repo_file_name=$(basename "$REPO_FILE")

  info "Disabling existing repository files"

  repo_count=0
  for repo_file in /etc/yum.repos.d/*.repo; do
    [ -e "$repo_file" ] || continue
    [ "$(basename "$repo_file")" = "$repo_file_name" ] && continue
    run_cmd mv "$repo_file" "$BACKUP_DIR"/
    repo_count=$((repo_count + 1))
  done

  if [ "$repo_count" -eq 0 ]; then
    warn "No repository files found to disable."
    return 0
  fi

  ok "Existing repository files disabled"
}

create_local_repo() {
  info "Creating Rocky Linux 8.10 ISO local repository file: $REPO_FILE"

  cat > "$REPO_FILE" <<EOF
[$BASEOS_REPO_ID]
name=Rocky Linux 8.10 - BaseOS - Local ISO
baseurl=file://$MNT_DIR/BaseOS/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial

[$APPSTREAM_REPO_ID]
name=Rocky Linux 8.10 - AppStream - Local ISO
baseurl=file://$MNT_DIR/AppStream/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
EOF

  ok "Local repository file created"
}

restore_repos() {
  repo_file_name=$(basename "$REPO_FILE")

  info "Restoring repository settings"

  if [ -f "$REPO_FILE" ]; then
    run_cmd rm -f "$REPO_FILE"
  fi

  if [ ! -d "$BACKUP_DIR" ]; then
    warn "Repository backup directory not found: $BACKUP_DIR"
    return 0
  fi

  restore_count=0
  for backup_file in "$BACKUP_DIR"/*.repo; do
    [ -e "$backup_file" ] || continue
    [ "$(basename "$backup_file")" = "$repo_file_name" ] && continue
    run_cmd cp -a "$backup_file" /etc/yum.repos.d/
    restore_count=$((restore_count + 1))
  done

  if [ "$restore_count" -eq 0 ]; then
    warn "No repository backup files found to restore."
    return 0
  fi

  ok "Repository settings restored"
}

cleanup_after_update() {
  exit_code=$?

  trap - 0 INT TERM HUP

  if [ "$WORK_STARTED" -eq 1 ]; then
    if [ "$exit_code" -ne 0 ]; then
      warn "The task failed or was cancelled. Restoring settings."
    fi

    if [ "$RESTORE_ON_EXIT" -eq 1 ]; then
      restore_repos || warn "Repository restore failed. Manual check required: /etc/yum.repos.d"
    fi

    unmount_iso || warn "ISO unmount failed. Manual check required: $MNT_DIR"
  fi

  exit "$exit_code"
}

signal_exit() {
  warn "Interrupt signal received."
  exit 130
}

run_minor_update() {
  check_environment

  echo
  warn "This task will run Rocky Linux 8.10 package synchronization using the ISO only."
  warn "Existing repository settings are temporarily disabled and restored on completion, failure, or cancellation."
  printf "Proceed with minor update? [yes/NO]: "
  read answer
  if [ "$answer" != "yes" ]; then
    fail "Cancelled by user"
  fi

  WORK_STARTED=1
  RESTORE_ON_EXIT=1
  trap cleanup_after_update 0
  trap signal_exit INT TERM HUP

  mount_iso
  backup_repos
  disable_existing_repos
  create_local_repo

  info "Cleaning DNF cache"
  run_cmd dnf clean all
  run_cmd rm -rf /var/cache/dnf

  info "Checking local repositories"
  run_cmd dnf --disablerepo='*' --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" repolist

  info "Checking available updates"
  dnf --disablerepo='*' --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" check-update || true

  info "Running distro-sync to Rocky Linux 8.10"
  run_cmd dnf -y --disablerepo='*' \
    --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" \
    distro-sync

  ok "Package synchronization completed"

  info "Checking final OS version"
  run_cmd cat /etc/rocky-release
  run_cmd rpm -q rocky-release

  ok "Minor update completed. Reboot is recommended."
}

restore_previous_settings() {
  require_root
  restore_repos
  unmount_iso
  ok "Previous settings restore completed"
}

manage_iso_mount() {
  require_root

  while true; do
    echo
    echo "ISO Mount Management"
    echo "1. Show ISO mount status"
    echo "2. Mount ISO"
    echo "3. Unmount ISO"
    echo "4. Back to main menu"
    echo
    printf "Select [1-4]: "
    read mount_choice

    case "$mount_choice" in
      1)
        show_mount_status
        ;;
      2)
        require_iso
        mount_iso
        ;;
      3)
        unmount_iso
        ;;
      4)
        return 0
        ;;
      *)
        warn "Invalid selection."
        ;;
    esac
  done
}

show_menu() {
  while true; do
    echo
    echo "Rocky Linux 8.10 Minor Update Menu v$SCRIPT_VERSION"
    echo "1. Check minor update environment"
    echo "2. ISO mount management"
    echo "3. Run minor update"
    echo "4. Restore previous settings"
    echo "5. Exit"
    echo
    printf "Select [1-5]: "
    read choice

    case "$choice" in
      1)
        check_environment
        ;;
      2)
        manage_iso_mount
        ;;
      3)
        run_minor_update
        ;;
      4)
        restore_previous_settings
        ;;
      5)
        exit 0
        ;;
      *)
        warn "Invalid selection."
        ;;
    esac
  done
}

show_menu
