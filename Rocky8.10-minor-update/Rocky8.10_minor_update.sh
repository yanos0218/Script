#!/bin/sh
set -eu

ISO_PATH="/root/Rocky-8.10-x86_64-dvd1.iso"
MNT_DIR="/mnt/rocky810_iso"
REPO_FILE="/etc/yum.repos.d/rocky-8.10-local.repo"
STATE_DIR="/root/rocky810_minor_update_state"
BACKUP_DIR="$STATE_DIR/repo_backup"
SCRIPT_VERSION="1.1.0"

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
  info "실행: $*"
  "$@"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fail "root 권한으로 실행해야 합니다."
  fi
}

require_rocky8() {
  if [ ! -f /etc/rocky-release ]; then
    fail "Rocky Linux 시스템이 아닙니다."
  fi

  if ! grep -qE '^Rocky Linux release 8\.' /etc/rocky-release; then
    fail "현재 시스템이 Rocky Linux 8.x가 아닙니다."
  fi

  info "현재 OS: $(cat /etc/rocky-release)"
  info "현재 rocky-release 패키지: $(rpm -q rocky-release || true)"
}

require_iso() {
  if [ ! -f "$ISO_PATH" ]; then
    fail "ISO 파일이 없습니다: $ISO_PATH"
  fi

  ok "ISO 파일 확인: $ISO_PATH"
}

free_mb() {
  df -Pm "$1" | awk 'NR==2 {print $4}'
}

check_mount_path() {
  parent_dir=$(dirname "$MNT_DIR")

  if [ ! -d "$parent_dir" ]; then
    fail "마운트 상위 디렉터리가 없습니다: $parent_dir"
  fi

  if mountpoint -q "$MNT_DIR"; then
    warn "이미 마운트되어 있습니다: $MNT_DIR"
  else
    ok "ISO 마운트 가능 위치 확인: $MNT_DIR"
  fi
}

show_mount_status() {
  if mountpoint -q "$MNT_DIR"; then
    ok "ISO 마운트 상태: mounted"
    info "마운트 위치: $MNT_DIR"
    mount | grep " on $MNT_DIR " || true
  else
    info "ISO 마운트 상태: not mounted"
    info "마운트 위치: $MNT_DIR"
  fi
}

check_space_one() {
  path="$1"
  min_mb="$2"
  label="$3"

  if [ ! -e "$path" ]; then
    warn "$label 경로가 없어 용량 확인을 건너뜁니다: $path"
    return 0
  fi

  available_mb=$(free_mb "$path")
  if [ "$available_mb" -lt "$min_mb" ]; then
    fail "$label 여유 공간 부족: ${available_mb}MB 사용 가능, 최소 ${min_mb}MB 필요"
  fi

  ok "$label 여유 공간 확인: ${available_mb}MB 사용 가능"
}

check_space() {
  check_space_one "/" "$MIN_ROOT_MB" "/"
  check_space_one "/var" "$MIN_VAR_MB" "/var"
  check_space_one "/boot" "$MIN_BOOT_MB" "/boot"
}

check_environment() {
  require_root
  info "스크립트 버전: $SCRIPT_VERSION"
  require_rocky8
  require_iso
  check_space
  check_mount_path
  ok "minor update 환경 확인 완료"
}

mount_iso() {
  mkdir -p "$MNT_DIR"

  if mountpoint -q "$MNT_DIR"; then
    info "기존 ISO 마운트 사용: $MNT_DIR"
  else
    run_cmd mount -o loop,ro "$ISO_PATH" "$MNT_DIR"
  fi

  if [ ! -d "$MNT_DIR/BaseOS" ]; then
    fail "BaseOS 디렉터리가 없습니다. Rocky 8.10 DVD ISO인지 확인하세요."
  fi

  if [ ! -d "$MNT_DIR/AppStream" ]; then
    fail "AppStream 디렉터리가 없습니다. Rocky 8.10 DVD ISO인지 확인하세요."
  fi

  ok "ISO 마운트 및 DVD repo 구조 확인 완료"
}

unmount_iso() {
  if mountpoint -q "$MNT_DIR"; then
    run_cmd umount "$MNT_DIR"
    ok "ISO 언마운트 완료: $MNT_DIR"
  else
    info "언마운트 대상이 없습니다: $MNT_DIR"
  fi
}

backup_repos() {
  repo_file_name=$(basename "$REPO_FILE")

  mkdir -p "$STATE_DIR"

  if [ -d "$BACKUP_DIR" ]; then
    warn "기존 repo 백업이 이미 있습니다: $BACKUP_DIR"
    warn "기존 백업을 유지하고 현재 설정 백업은 건너뜁니다."
    return 0
  fi

  mkdir -p "$BACKUP_DIR"
  info "기존 repo 백업: $BACKUP_DIR"

  repo_count=0
  for repo_file in /etc/yum.repos.d/*.repo; do
    [ -e "$repo_file" ] || continue
    [ "$(basename "$repo_file")" = "$repo_file_name" ] && continue
    run_cmd cp -a "$repo_file" "$BACKUP_DIR"/
    repo_count=$((repo_count + 1))
  done

  if [ "$repo_count" -eq 0 ]; then
    warn "백업할 repo 파일이 없습니다."
    return 0
  fi

  ok "기존 repo 백업 완료"
}

disable_existing_repos() {
  repo_file_name=$(basename "$REPO_FILE")

  info "기존 repo 비활성화"

  repo_count=0
  for repo_file in /etc/yum.repos.d/*.repo; do
    [ -e "$repo_file" ] || continue
    [ "$(basename "$repo_file")" = "$repo_file_name" ] && continue
    run_cmd mv "$repo_file" "$BACKUP_DIR"/
    repo_count=$((repo_count + 1))
  done

  if [ "$repo_count" -eq 0 ]; then
    warn "비활성화할 repo 파일이 없습니다."
    return 0
  fi

  ok "기존 repo 비활성화 완료"
}

create_local_repo() {
  info "Rocky 8.10 ISO local repo 생성: $REPO_FILE"

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

  ok "local repo 생성 완료"
}

restore_repos() {
  repo_file_name=$(basename "$REPO_FILE")

  info "minor update 이전 repo 설정 복원 시작"

  if [ -f "$REPO_FILE" ]; then
    run_cmd rm -f "$REPO_FILE"
  fi

  if [ ! -d "$BACKUP_DIR" ]; then
    warn "repo 백업 디렉터리가 없습니다: $BACKUP_DIR"
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
    warn "복원할 repo 백업 파일이 없습니다."
    return 0
  fi

  ok "repo 설정 복원 완료"
}

cleanup_after_update() {
  exit_code=$?

  trap - 0 INT TERM HUP

  if [ "$WORK_STARTED" -eq 1 ]; then
    if [ "$exit_code" -ne 0 ]; then
      warn "작업이 실패 또는 취소되었습니다. 설정 복원을 수행합니다."
    fi

    if [ "$RESTORE_ON_EXIT" -eq 1 ]; then
      restore_repos || warn "repo 설정 복원 중 오류가 발생했습니다. 수동 확인 필요: /etc/yum.repos.d"
    fi

    unmount_iso || warn "ISO 언마운트 중 오류가 발생했습니다. 수동 확인 필요: $MNT_DIR"
  fi

  exit "$exit_code"
}

signal_exit() {
  warn "작업 중단 신호를 받았습니다."
  exit 130
}

run_minor_update() {
  check_environment

  echo
  warn "이 작업은 ISO 기반으로 Rocky Linux 8.10 패키지 동기화를 수행합니다."
  warn "작업 중 기존 repo 설정은 임시로 비활성화되며, 완료/실패/취소 시 복원됩니다."
  printf "minor update를 진행하시겠습니까? [yes/NO]: "
  read answer
  if [ "$answer" != "yes" ]; then
    fail "사용자 취소"
  fi

  WORK_STARTED=1
  RESTORE_ON_EXIT=1
  trap cleanup_after_update 0
  trap signal_exit INT TERM HUP

  mount_iso
  backup_repos
  disable_existing_repos
  create_local_repo

  info "DNF 캐시 정리"
  run_cmd dnf clean all
  run_cmd rm -rf /var/cache/dnf

  info "local repo 확인"
  run_cmd dnf --disablerepo='*' --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" repolist

  info "업데이트 대상 확인"
  dnf --disablerepo='*' --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" check-update || true

  info "Rocky 8.10 기준 distro-sync 수행"
  run_cmd dnf -y --disablerepo='*' \
    --enablerepo="$BASEOS_REPO_ID","$APPSTREAM_REPO_ID" \
    distro-sync

  ok "패키지 동기화 완료"

  info "최종 버전 확인"
  run_cmd cat /etc/rocky-release
  run_cmd rpm -q rocky-release

  ok "minor update 완료. 재부팅을 권장합니다."
}

restore_previous_settings() {
  require_root
  restore_repos
  unmount_iso
  ok "minor update 이전 설정 복원 작업 완료"
}

manage_iso_mount() {
  require_root

  while true; do
    echo
    echo "ISO Mount Management"
    echo "1. ISO 마운트 상태 확인"
    echo "2. ISO 마운트"
    echo "3. ISO 언마운트"
    echo "4. 이전 메뉴"
    echo
    printf "선택 [1-4]: "
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
        warn "잘못된 선택입니다."
        ;;
    esac
  done
}

show_menu() {
  while true; do
    echo
    echo "Rocky Linux 8.10 Minor Update Menu v$SCRIPT_VERSION"
    echo "1. minor update 환경 확인"
    echo "2. minor update 진행"
    echo "3. ISO 마운트 관리"
    echo "4. minor update 이전 설정 복원"
    echo "5. 종료"
    echo
    printf "선택 [1-5]: "
    read choice

    case "$choice" in
      1)
        check_environment
        ;;
      2)
        run_minor_update
        ;;
      3)
        manage_iso_mount
        ;;
      4)
        restore_previous_settings
        ;;
      5)
        exit 0
        ;;
      *)
        warn "잘못된 선택입니다."
        ;;
    esac
  done
}

show_menu
