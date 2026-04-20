# Rocky8.10 Minor Update

Rocky Linux 8.x 시스템을 Rocky Linux 8.10 DVD ISO 기준으로 오프라인 minor update 하는 스크립트입니다.

## 목적

인터넷 연결이 불가능한 환경에서 `/root/Rocky-8.10-x86_64-dvd1.iso` 파일을 local repository로 사용하고, Rocky Linux 8.10의 BaseOS/AppStream repository 기준으로 `dnf distro-sync`를 수행합니다.

## 스크립트

```text
Rocky8.10_minor_update.sh
```

## 버전

```text
2.0.0
```

스크립트 내부의 `SCRIPT_VERSION` 값으로도 확인할 수 있습니다.

## 요구사항

- Rocky Linux 8.x
- root 권한
- Rocky Linux 8.10 DVD ISO
- ISO 위치: `/root/Rocky-8.10-x86_64-dvd1.iso`
- Rocky Linux GPG key: `/etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial`
- `/mnt` 디렉터리 존재
- 필요 명령어: `awk`, `basename`, `cat`, `cp`, `date`, `df`, `dirname`, `dnf`, `grep`, `id`, `ls`, `mkdir`, `mount`, `mountpoint`, `mv`, `rm`, `rpm`, `sed`, `sha256sum`, `sort`, `tail`, `umount`

## 용량 확인 기준

minor update 진행 전 아래 여유 공간을 확인합니다.

| 경로 | 최소 여유 공간 |
|---|---:|
| `/` | 3072 MB |
| `/var` | 5120 MB |
| `/boot` | 512 MB |

## 실행 방법

```sh
sh /root/Rocky8.10_minor_update.sh
```

운영체제 콘솔에서 한글이 깨질 수 있어 스크립트의 메뉴와 출력은 영어로 유지합니다. README는 한글로 관리합니다.

```text
1. Check minor update environment
2. ISO mount management
3. Run minor update
4. Show update status
5. Restore previous settings
6. Exit
```

## Hash 검증

외부 `.sha256` 파일은 사용하지 않습니다. 스크립트 내부의 `SCRIPT_SHA256` 값과 실행 중인 스크립트의 hash 값을 비교합니다.

순환 참조를 피하기 위해 hash 계산 시 `SCRIPT_SHA256=` 라인은 제외합니다.

```sh
sed '/^SCRIPT_SHA256=/d' /root/Rocky8.10_minor_update.sh | sha256sum
```

스크립트를 수정하면 위 명령으로 새 hash 값을 계산한 뒤, 스크립트 내부의 `SCRIPT_SHA256` 값을 함께 갱신해야 합니다.

이 방식은 파일 손상, 불완전한 복사, 의도하지 않은 수정 여부를 확인하는 데 유용합니다. 다만 `.sh` 파일을 수정할 수 있는 권한을 가진 사용자가 hash 값까지 다시 계산해 바꿀 수 있으므로, 강한 위변조 방지가 필요하면 GPG 서명처럼 스크립트와 분리된 신뢰 기준이 필요합니다.

## 메뉴 설명

### 1. Check minor update environment

다음 항목을 확인합니다.

- root 권한 여부
- 필수 명령어 존재 여부
- 스크립트 내부 hash 검증
- 스크립트 버전
- Rocky Linux 8.x 여부
- 현재 OS 버전
- 현재 `rocky-release` 패키지 버전
- ISO 파일 존재 여부
- Rocky Linux GPG key 존재 여부
- `/`, `/var`, `/boot` 여유 공간
- ISO 마운트 위치 상태

### 2. ISO mount management

ISO 마운트를 수동으로 확인하거나 제어하는 메뉴입니다.

```text
1. Show ISO mount status
2. Mount ISO
3. Unmount ISO
4. Back to main menu
```

`Mount ISO`는 `/root/Rocky-8.10-x86_64-dvd1.iso` 파일을 `/mnt/rocky810_iso`에 read-only loop mount하고, `BaseOS`와 `AppStream` 디렉터리가 존재하는지 확인합니다.

이미 `/mnt/rocky810_iso`가 마운트되어 있으면 해당 mount source가 `/root/Rocky-8.10-x86_64-dvd1.iso`인지 확인합니다. 다른 source가 마운트되어 있으면 작업을 중단합니다.

### 3. Run minor update

다음 순서로 작업합니다.

1. 환경 확인
2. 실행 중복 방지를 위한 lock 파일 확인
3. 사용자 진행 확인
4. lock 파일 생성
5. update status를 `RUNNING`으로 기록
6. ISO read-only loop mount
7. update status를 `ISO_MOUNTED`로 기록
8. 실행별 timestamp repo 백업 생성
9. 현재 백업 경로를 `current_backup` 파일에 기록
10. update status를 `REPO_BACKED_UP`으로 기록
11. 기존 repo 파일 임시 비활성화
12. update status를 `REPO_DISABLED`로 기록
13. ISO 기반 local repo 파일 생성
14. update status를 `LOCAL_REPO_CREATED`로 기록
15. `dnf clean all` 실행
16. local repo 확인
17. 업데이트 대상 확인
18. Rocky Linux 8.10 repo 기준 `dnf distro-sync` 실행
19. update status를 `SYNC_COMPLETED`로 기록
20. 최종 OS 버전 확인
21. 기존 repo 설정 복원
22. ISO 언마운트
23. lock 파일 제거
24. update status를 `COMPLETED`로 기록

성공, 실패, 사용자 중단, HUP/TERM/INT 신호가 발생해도 스크립트는 종료 전에 repo 복원과 ISO 언마운트를 시도합니다.

### 4. Show update status

현재 update 상태를 확인합니다.

상태 파일 위치:

```text
/root/rocky810_minor_update_state/update_status
```

lock 파일 위치:

```text
/root/rocky810_minor_update_state/update.lock
```

lock 파일에는 PID와 함께 OS boot id를 기록합니다. 재부팅 후 PID가 재사용되더라도 boot id가 다르면 이전 boot에서 남은 stale lock으로 판단해 제거합니다.

주요 상태 값은 다음과 같습니다.

| Status | 의미 |
|---|---|
| `RUNNING` | minor update 시작 |
| `ISO_MOUNTED` | ISO 마운트 완료 |
| `REPO_BACKED_UP` | 기존 repo 백업 완료 |
| `REPO_DISABLED` | 기존 repo 임시 비활성화 완료 |
| `LOCAL_REPO_CREATED` | ISO 기반 local repo 생성 완료 |
| `SYNC_COMPLETED` | `dnf distro-sync` 완료, cleanup 진행 예정 |
| `COMPLETED` | minor update와 cleanup 완료 |
| `FAILED_RESTORED` | 실패 또는 중단 후 설정 복원 완료 |
| `CLEANUP_FAILED` | cleanup 실패, 수동 확인 필요 |
| `MANUAL_RESTORE_COMPLETED` | 수동 복원 완료 |

실행 중인 lock PID가 있으면 status 메뉴에서 함께 표시됩니다. stale lock 파일은 다음 update 또는 restore 실행 시 제거합니다.

### 5. Restore previous settings

수동 복원 메뉴입니다.

다음 작업을 수행합니다.

- 실행 중인 update lock이 있으면 중단
- 임시 ISO local repo 파일 삭제
- `current_backup`에 기록된 repo 백업 디렉터리에서 기존 repo 파일 복원
- `current_backup`이 없으면 `repo_backups` 하위의 최신 timestamp 백업 디렉터리 사용
- 복원할 `.repo` 파일이 실제로 존재하는지 확인
- ISO 언마운트

마지막 상태가 `COMPLETED`이면 정상적으로 cleanup이 끝난 상태이므로 복원은 보통 필요하지 않습니다. 이 경우 스크립트가 재확인을 요구합니다.

마지막 상태가 `RUNNING`, `ISO_MOUNTED`, `REPO_BACKED_UP`, `REPO_DISABLED`, `LOCAL_REPO_CREATED`, `SYNC_COMPLETED` 중 하나이면 미완료 상태로 간주하고 재확인을 요구합니다. 실행 중 lock PID가 살아 있으면 restore는 진행하지 않습니다.

## 변경 또는 사용되는 경로

| 경로 | 용도 |
|---|---|
| `/root/Rocky8.10_minor_update.sh` | 실행 스크립트 |
| `/root/Rocky-8.10-x86_64-dvd1.iso` | Rocky Linux 8.10 DVD ISO |
| `/mnt/rocky810_iso` | ISO mount point |
| `/etc/yum.repos.d/rocky-8.10-local.repo` | 임시 local repo 파일 |
| `/root/rocky810_minor_update_state/repo_backups/repo_backup_YYYYMMDDHHMMSS` | 실행별 기존 repo 백업 디렉터리 |
| `/root/rocky810_minor_update_state/current_backup` | 현재 복원에 사용할 repo 백업 디렉터리 경로 |
| `/root/rocky810_minor_update_state/update_status` | update 진행 상태 파일 |
| `/root/rocky810_minor_update_state/update.lock` | 실행 중복 및 restore 충돌 방지 lock 파일 |

## 복원 동작

`Run minor update`가 성공, 실패, 사용자 중단으로 종료되더라도 스크립트는 다음 복원을 시도합니다.

- `/etc/yum.repos.d/rocky-8.10-local.repo` 삭제
- `current_backup`에 기록된 백업 디렉터리에서 기존 repo 파일 복원
- `current_backup`이 없으면 최신 timestamp 백업 디렉터리 사용
- 복원할 `.repo` 파일이 없으면 실패 처리
- `/mnt/rocky810_iso` 언마운트
- lock 파일 제거

정상 완료 후에는 `Restore previous settings`를 다시 실행할 필요가 없습니다. 수동 복원은 `CLEANUP_FAILED` 상태이거나, 상태 파일상 미완료인데 실제 update 프로세스가 더 이상 실행 중이 아닌 경우에만 사용합니다.

## 개선된 안전장치

- 외부 `.sha256` 파일 없이 스크립트 내부 hash를 검증합니다.
- 실행 중 lock 파일로 중복 update와 update 중 restore를 방지합니다.
- update 성공 직후 메뉴로 돌아가기 전에 repo 복원과 ISO unmount를 즉시 수행합니다.
- update 상태 파일로 완료, 실패, cleanup 실패, 수동 복원 여부를 확인할 수 있습니다.
- 실행마다 timestamp 기반 repo 백업 디렉터리를 새로 생성합니다.
- 같은 메뉴 세션에서 update를 여러 번 실행해도 매 실행마다 새 `RUN_ID`와 `BACKUP_DIR`를 생성합니다.
- 기존 repo 파일이 하나도 없던 환경은 `.no_repo_files` marker로 기록해 복원 단계에서 실패로 처리하지 않습니다.
- `current_backup` 파일로 현재 실행에서 복원할 백업 위치를 명확히 기록합니다.
- `current_backup`이 없으면 최신 timestamp 백업 디렉터리를 fallback으로 사용합니다.
- 복원 전 백업 디렉터리 안에 `.repo` 파일이 존재하는지 확인합니다.
- 필수 명령어 존재 여부를 사전에 확인합니다.
- Rocky Linux GPG key 존재 여부를 사전에 확인합니다.
- 이미 마운트된 ISO mount point의 source를 확인합니다.
- `dnf check-update`는 exit code `0`과 `100`만 정상으로 처리하고, 그 외 오류는 실패 처리합니다.
- `/var/cache/dnf` 직접 삭제는 제거하고 `dnf clean all`만 수행합니다.

## 주의사항

- 온라인 repository는 사용하지 않습니다.
- ISO의 `BaseOS`와 `AppStream`만 사용합니다.
- EPEL, vendor repository, custom repository에 의존하는 패키지는 별도 검토가 필요합니다.
- `dnf autoremove`는 자동 실행하지 않습니다.
- 운영 서버 적용 전 테스트 서버에서 먼저 검증해야 합니다.
- 작업 완료 후 재부팅을 권장합니다.
- 내부 hash 방식은 편의성과 파일 손상 감지 목적입니다. 강한 위변조 방지가 필요하면 별도 GPG 서명 검증 체계를 사용해야 합니다.
- minor update 후에는 커널, glibc, systemd, 보안 라이브러리 등 실행 중인 프로세스가 계속 이전 바이너리를 잡고 있을 수 있으므로 재부팅을 권장합니다.

## Version History

| Version | Date | Changes |
|---|---|---|
| 2.0.0 | 2026-04-20 | `RUN_ID`/`BACKUP_DIR`를 실행 시점마다 생성하도록 변경, 기존 repo 파일 0개 환경 복원 처리 개선, `REPO_DIR` 변수 추가 |
| 1.8.0 | 2026-04-20 | update lock에 boot id를 추가해 재부팅 후 PID 재사용으로 인한 오판 방지 |
| 1.7.0 | 2026-04-20 | update 성공 직후 cleanup 즉시 수행, update lock으로 중복 실행 및 실행 중 restore 방지 |
| 1.6.0 | 2026-04-20 | update lock/status 확인 보강, 미완료 상태에서 수동 restore 재확인 추가 |
| 1.5.0 | 2026-04-20 | 외부 `.sha256` 파일 제거, 스크립트 내부 checksum 검증 전환, update status 메뉴와 상태 파일 추가 |
| 1.4.0 | 2026-04-20 | 스크립트 checksum 검증 추가, 복원 시 최신 백업 fallback 및 repo 파일 존재 확인 추가 |
| 1.3.0 | 2026-04-20 | 실행별 repo 백업, 필수 명령/GPG key 확인, mount source 확인, dnf check-update 오류 처리, DNF cache 삭제 방식 개선 |
| 1.2.0 | 2026-04-20 | 스크립트 메뉴와 출력 메시지를 영어로 변경하고 ISO mount management를 2번 메뉴로 이동 |
| 1.1.0 | 2026-04-20 | ISO mount 상태 확인, mount, unmount 관리 메뉴 추가 |
| 1.0.0 | 2026-04-20 | Rocky Linux 8.10 오프라인 minor update 초기 버전 |
