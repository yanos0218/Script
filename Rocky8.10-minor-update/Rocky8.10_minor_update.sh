#!/bin/sh
set -eu

ISO_PATH="/root/Rocky-8.10-x86_64-dvd1.iso"
SCRIPT_PATH="$0"
MNT_DIR="/mnt/rocky810_iso"
REPO_FILE="/etc/yum.repos.d/rocky-8.10-local.repo"
REPO_DIR="/etc/yum.repos.d"
STATE_DIR="/root/rocky810_minor_update_state"
BACKUP_BASE_DIR="$STATE_DIR/repo_backups"
RUN_ID=""
BACKUP_DIR=""
CURRENT_BACKUP_FILE="$STATE_DIR/current_backup"
UPDATE_STATUS_FILE="$STATE_DIR/update_status"
LOCK_FILE="$STATE_DIR/update.lock"
GPG_KEY="/etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial"
SCRIPT_SHA256="e1c2abd02bb92b43f0065621ac621e9b4a47e640e8a40b8001caf863149d26e3"
SCRIPT_VERSION="2.0.0"

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

set_run_context() {
  RUN_ID=$(date +%Y%m%d%H%M%S)
  BACKUP_DIR="$BACKUP_BASE_DIR/repo_backup_$RUN_ID"
}

require_commands() {
  missing_commands=""

  for command_name in awk basename cat cp date df dirname dnf grep id ls mkdir mount mountpoint mv rm rpm sed sha256sum sort tail umount; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      missing_commands="$missing_commands $command_name"
    fi
  done

  if [ -n "$missing_commands" ]; then
    fail "Required command(s) not found:$missing_commands"
  fi

  ok "Required command check passed"
}

verify_script_hash() {
  if [ -z "$SCRIPT_SHA256" ] || [ "$SCRIPT_SHA256" = "TO_BE_FILLED" ]; then
    fail "Embedded script checksum is not set."
  fi

  actual_hash=$(sed '/^SCRIPT_SHA256=/d' "$SCRIPT_PATH" | sha256sum | awk '{print $1}')
  if [ "$actual_hash" != "$SCRIPT_SHA256" ]; then
    fail "Script checksum mismatch. Expected $SCRIPT_SHA256 but got $actual_hash"
  fi

  ok "Script checksum verification passed"
}

write_update_status() {
  status="$1"
  detail="${2:-}"

  mkdir -p "$STATE_DIR"
  {
    echo "STATUS=$status"
    echo "UPDATED_AT=$(date +%Y%m%d%H%M%S)"
    echo "RUN_ID=${RUN_ID:-none}"
    echo "BACKUP_DIR=${BACKUP_DIR:-none}"
    echo "DETAIL=$detail"
  } > "$UPDATE_STATUS_FILE"
}

read_update_status() {
  if [ -f "$UPDATE_STATUS_FILE" ]; then
    sed -n 's/^STATUS=//p' "$UPDATE_STATUS_FILE" | tail -n 1
  fi
}

is_pid_running() {
  pid="$1"

  case "$pid" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac

  kill -0 "$pid" >/dev/null 2>&1
}

get_boot_id() {
  if [ -f /proc/sys/kernel/random/boot_id ]; then
    cat /proc/sys/kernel/random/boot_id
  else
    echo "unknown"
  fi
}

read_lock_value() {
  key="$1"

  if [ -f "$LOCK_FILE" ]; then
    sed -n "s/^$key=//p" "$LOCK_FILE" | tail -n 1
  fi
}

read_lock_pid() {
  lock_pid=$(read_lock_value "PID" || true)

  if [ -n "$lock_pid" ]; then
    echo "$lock_pid"
  elif [ -f "$LOCK_FILE" ]; then
    sed -n '1p' "$LOCK_FILE"
  fi
}

read_lock_boot_id() {
  read_lock_value "BOOT_ID" || true
}

check_update_lock() {
  lock_pid=$(read_lock_pid || true)
  lock_boot_id=$(read_lock_boot_id || true)
  current_boot_id=$(get_boot_id)

  if [ -n "$lock_boot_id" ] && [ "$lock_boot_id" != "$current_boot_id" ]; then
    warn "Stale update lock file from previous boot found. Removing: $LOCK_FILE"
    rm -f "$LOCK_FILE"
    return 0
  fi

  if is_pid_running "$lock_pid"; then
    fail "Another update task appears to be running. Lock file: $LOCK_FILE PID: $lock_pid"
  fi

  if [ -f "$LOCK_FILE" ]; then
    warn "Stale update lock file found. Removing: $LOCK_FILE"
    rm -f "$LOCK_FILE"
  fi
}

create_update_lock() {
  mkdir -p "$STATE_DIR"
  check_update_lock
  {
    echo "PID=$$"
    echo "BOOT_ID=$(get_boot_id)"
    echo "STARTED_AT=$(date +%Y%m%d%H%M%S)"
  } > "$LOCK_FILE"
}

remove_update_lock() {
  lock_pid=$(read_lock_pid || true)

  if [ "$lock_pid" = "$$" ]; then
    rm -f "$LOCK_FILE"
  fi
}

show_update_status() {
  if [ ! -f "$UPDATE_STATUS_FILE" ]; then
    info "Update status: no status file found"
    info "Status file: $UPDATE_STATUS_FILE"
  else
    info "Update status file: $UPDATE_STATUS_FILE"
    cat "$UPDATE_STATUS_FILE"
  fi

  lock_pid=$(read_lock_pid || true)
  lock_boot_id=$(read_lock_boot_id || true)
  current_boot_id=$(get_boot_id)
  if [ "$lock_boot_id" = "$current_boot_id" ] && is_pid_running "$lock_pid"; then
    info "Active update lock: $LOCK_FILE PID: $lock_pid"
  elif [ -f "$LOCK_FILE" ]; then
    warn "Stale update lock file exists: $LOCK_FILE"
  fi
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

require_gpg_key() {
  if [ ! -f "$GPG_KEY" ]; then
    fail "Rocky Linux GPG key not found: $GPG_KEY"
  fi

  ok "Rocky Linux GPG key found: $GPG_KEY"
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

get_mount_source() {
  mount | awk -v target="$MNT_DIR" '$3 == target {print $1; exit}'
}

check_iso_mount_source() {
  mounted_source=$(get_mount_source)

  if [ -n "$mounted_source" ] && [ "$mounted_source" != "$ISO_PATH" ]; then
    fail "Mount point is already used by another source: $mounted_source"
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
  require_commands
  verify_script_hash
  info "Script version: $SCRIPT_VERSION"
  require_rocky8
  require_iso
  require_gpg_key
  check_space
  check_mount_path
  ok "Minor update environment check completed"
}

mount_iso() {
  mkdir -p "$MNT_DIR"

  if mountpoint -q "$MNT_DIR"; then
    check_iso_mount_source
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

  mkdir -p "$STATE_DIR" "$BACKUP_BASE_DIR"
  mkdir -p "$BACKUP_DIR"
  info "Backing up current repository files to: $BACKUP_DIR"

  repo_count=0
  for repo_file in "$REPO_DIR"/*.repo; do
    [ -e "$repo_file" ] || continue
    [ "$(basename "$repo_file")" = "$repo_file_name" ] && continue
    run_cmd cp -a "$repo_file" "$BACKUP_DIR"/
    repo_count=$((repo_count + 1))
  done

  if [ "$repo_count" -eq 0 ]; then
    warn "No repository files found to back up."
    : > "$BACKUP_DIR/.no_repo_files"
    echo "$BACKUP_DIR" > "$CURRENT_BACKUP_FILE"
    return 0
  fi

  echo "$BACKUP_DIR" > "$CURRENT_BACKUP_FILE"
  ok "Repository backup completed"
}

disable_existing_repos() {
  repo_file_name=$(basename "$REPO_FILE")

  info "Disabling existing repository files"

  repo_count=0
  for repo_file in "$REPO_DIR"/*.repo; do
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
gpgkey=file://$GPG_KEY

[$APPSTREAM_REPO_ID]
name=Rocky Linux 8.10 - AppStream - Local ISO
baseurl=file://$MNT_DIR/AppStream/
enabled=1
gpgcheck=1
gpgkey=file://$GPG_KEY
EOF

  ok "Local repository file created"
}

restore_repos() {
  repo_file_name=$(basename "$REPO_FILE")

  info "Restoring repository settings"

  if [ -f "$REPO_FILE" ]; then
    run_cmd rm -f "$REPO_FILE"
  fi

  restore_backup_dir=""
  if [ -f "$CURRENT_BACKUP_FILE" ]; then
    restore_backup_dir=$(cat "$CURRENT_BACKUP_FILE")
  fi

  if [ -z "$restore_backup_dir" ] && [ -d "$BACKUP_BASE_DIR" ]; then
    restore_backup_dir=$(ls -1d "$BACKUP_BASE_DIR"/repo_backup_* 2>/dev/null | sort | tail -n 1 || true)
  fi

  if [ -z "$restore_backup_dir" ] && [ -d "$STATE_DIR/repo_backup" ]; then
    restore_backup_dir="$STATE_DIR/repo_backup"
  fi

  if [ -z "$restore_backup_dir" ]; then
    warn "Current repository backup pointer not found: $CURRENT_BACKUP_FILE"
    return 0
  fi

  if [ ! -d "$restore_backup_dir" ]; then
    warn "Repository backup directory not found: $restore_backup_dir"
    return 0
  fi

  if [ -f "$restore_backup_dir/.no_repo_files" ]; then
    warn "Backup marker says no repository files existed before update."
    return 0
  fi

  backup_file_count=0
  for backup_file in "$restore_backup_dir"/*.repo; do
    [ -e "$backup_file" ] || continue
    [ "$(basename "$backup_file")" = "$repo_file_name" ] && continue
    backup_file_count=$((backup_file_count + 1))
  done

  if [ "$backup_file_count" -eq 0 ]; then
    fail "No repository backup files found in: $restore_backup_dir"
  fi

  restore_count=0
  for backup_file in "$restore_backup_dir"/*.repo; do
    [ -e "$backup_file" ] || continue
    [ "$(basename "$backup_file")" = "$repo_file_name" ] && continue
    run_cmd cp -a "$backup_file" "$REPO_DIR"/
    restore_count=$((restore_count + 1))
  done

  ok "Repository settings restored"
}

cleanup_update_work() {
  exit_code="$1"
  cleanup_failed=0

  if [ "$WORK_STARTED" -eq 1 ]; then
    if [ "$exit_code" -ne 0 ]; then
      warn "The task failed or was cancelled. Restoring settings."
    fi

    if [ "$RESTORE_ON_EXIT" -eq 1 ]; then
      if ! restore_repos; then
        cleanup_failed=1
        warn "Repository restore failed. Manual check required: /etc/yum.repos.d"
      fi
    fi

    if ! unmount_iso; then
      cleanup_failed=1
      warn "ISO unmount failed. Manual check required: $MNT_DIR"
    fi

    if [ "$cleanup_failed" -ne 0 ]; then
      write_update_status "CLEANUP_FAILED" "Manual restore check is required"
    elif [ "$exit_code" -eq 0 ]; then
      write_update_status "COMPLETED" "Minor update completed and temporary settings were restored"
    else
      write_update_status "FAILED_RESTORED" "Minor update failed or was cancelled; temporary settings were restored"
    fi

    remove_update_lock
    WORK_STARTED=0
    RESTORE_ON_EXIT=0
  fi

  if [ "$cleanup_failed" -ne 0 ]; then
    return 1
  fi

  return 0
}

cleanup_after_update() {
  exit_code=$?

  trap - 0 INT TERM HUP

  if ! cleanup_update_work "$exit_code"; then
    exit_code=1
  fi

  exit "$exit_code"
}

signal_exit() {
  warn "Interrupt signal received."
  exit 130
}

run_minor_update() {
  check_environment
  check_update_lock

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
  set_run_context
  create_update_lock
  write_update_status "RUNNING" "Minor update started"
  trap cleanup_after_update 0
  trap signal_exit INT TERM HUP

  mount_iso
  write_update_status "ISO_MOUNTED" "ISO mounted or existing ISO mount reused"
  backup_repos
  write_update_status "REPO_BACKED_UP" "Repository files backed up"
  disable_existing_repos
  write_update_status "REPO_DISABLED" "Existing repository files disabled"
  create_local_repo
  write_update_status "LOCAL_REPO_CREATED" "Temporary ISO local repository created"

  info "Cleaning DNF cache"
  run_cmd dnf clean all

  info "Checking local repositories"
  run_cmd dnf --disablerepo='*' --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" repolist

  info "Checking available updates"
  set +e
  dnf --disablerepo='*' --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" check-update
  check_update_rc=$?
  set -e
  if [ "$check_update_rc" -ne 0 ] && [ "$check_update_rc" -ne 100 ]; then
    fail "dnf check-update failed with exit code: $check_update_rc"
  fi

  info "Running distro-sync to Rocky Linux 8.10"
  run_cmd dnf -y --disablerepo='*' \
    --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" \
    distro-sync

  ok "Package synchronization completed"
  write_update_status "SYNC_COMPLETED" "Package synchronization completed; cleanup pending"

  info "Checking final OS version"
  run_cmd cat /etc/rocky-release
  run_cmd rpm -q rocky-release

  ok "Minor update completed. Reboot is recommended."

  trap - 0 INT TERM HUP
  if ! cleanup_update_work 0; then
    fail "Post-update cleanup failed. Manual check required."
  fi

  ok "Post-update cleanup completed"
}

restore_previous_settings() {
  require_root
  require_commands
  verify_script_hash
  check_update_lock

  current_status=$(read_update_status || true)
  if [ "$current_status" = "COMPLETED" ]; then
    warn "Last update status is COMPLETED. Restore is usually not required."
    printf "Proceed with restore anyway? [yes/NO]: "
    read restore_answer
    if [ "$restore_answer" != "yes" ]; then
      fail "Cancelled by user"
    fi
  fi

  case "$current_status" in
    RUNNING|ISO_MOUNTED|REPO_BACKED_UP|REPO_DISABLED|LOCAL_REPO_CREATED|SYNC_COMPLETED)
      warn "Last update status is incomplete: $current_status"
      warn "Use restore only after confirming no update process is running."
      printf "Proceed with restore? [yes/NO]: "
      read incomplete_restore_answer
      if [ "$incomplete_restore_answer" != "yes" ]; then
        fail "Cancelled by user"
      fi
      ;;
  esac

  set_run_context
  restore_repos
  unmount_iso
  write_update_status "MANUAL_RESTORE_COMPLETED" "Manual restore completed"
  ok "Previous settings restore completed"
}

manage_iso_mount() {
  require_root
  require_commands
  verify_script_hash

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
    echo "4. Show update status"
    echo "5. Restore previous settings"
    echo "6. Exit"
    echo
    printf "Select [1-6]: "
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
        show_update_status
        ;;
      5)
        restore_previous_settings
        ;;
      6)
        exit 0
        ;;
      *)
        warn "Invalid selection."
        ;;
    esac
  done
}

require_root
require_commands
verify_script_hash
show_menu
