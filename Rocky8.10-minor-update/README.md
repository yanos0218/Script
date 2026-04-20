# Rocky8.10 Minor Update

Rocky Linux 8.x 시스템을 Rocky Linux 8.10 DVD ISO 기준으로 오프라인 minor update 하는 스크립트입니다.

## 목적

인터넷 연결이 불가능한 환경에서 `/root/Rocky-8.10-x86_64-dvd1.iso` 파일을 local repository로 사용하고, Rocky Linux 8.10의 BaseOS/AppStream repository 기준으로 `dnf distro-sync`를 수행합니다.

## 스크립트

```text
Rocky8.10_minor_update.sh
Rocky8.10_minor_update.sh.sha256
```

## 버전

```text
1.4.0
```

스크립트 내부의 `SCRIPT_VERSION` 값으로도 확인할 수 있습니다.

## 요구사항

- Rocky Linux 8.x
- root 권한
- Rocky Linux 8.10 DVD ISO
- ISO 위치: `/root/Rocky-8.10-x86_64-dvd1.iso`
- 스크립트 checksum 파일 위치: `/root/Rocky8.10_minor_update.sh.sha256`
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

운영체제 콘솔에서 한글이 깨질 수 있어 스크립트의 메뉴와 출력은 영어로 유지합니다.

```text
1. Check minor update environment
2. ISO mount management
3. Run minor update
4. Restore previous settings
5. Exit
```

## Hash 검증

스크립트 실행 시 `/root/Rocky8.10_minor_update.sh.sha256` 파일의 hash 값과 실제 `/root/Rocky8.10_minor_update.sh`의 hash 값을 비교합니다.

검증 실패 시 스크립트는 실행을 중단합니다.

```sh
sha256sum /root/Rocky8.10_minor_update.sh
```

스크립트를 수정하거나 GitHub에서 새 버전을 배포한 경우 `.sha256` 파일도 함께 갱신해야 합니다.

주의할 점은 hash 검증이 실수로 인한 파일 손상이나 배포 누락을 잡는 데 유용하지만, 공격자가 `.sh`와 `.sha256` 파일을 모두 바꿀 수 있는 권한을 가진 경우에는 완전한 위변조 방지가 아닙니다. 더 강한 보장이 필요하면 GPG 서명 검증 방식이 필요합니다.

## 메뉴 설명

### 1. Check minor update environment

다음 항목을 확인합니다.

- root 권한 여부
- 필수 명령어 존재 여부
- 스크립트 checksum 검증
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

이미 `/mnt/rocky810_iso`가 마운트되어 있으면, 해당 마운트 source가 `/root/Rocky-8.10-x86_64-dvd1.iso`인지 확인합니다. 다른 source가 마운트되어 있으면 작업을 중단합니다.

### 3. Run minor update

다음 순서로 작업합니다.

1. 환경 확인
2. 사용자 진행 확인
3. ISO read-only loop mount
4. ISO 내 `BaseOS`, `AppStream` 디렉터리 확인
5. 실행별 timestamp repo 백업 생성
6. 현재 백업 경로를 `current_backup` 파일에 기록
7. 기존 repo 파일 임시 비활성화
8. ISO 기반 local repo 파일 생성
9. `dnf clean all` 실행
10. local repo 확인
11. 업데이트 대상 확인
12. Rocky Linux 8.10 repo 기준 `dnf distro-sync` 실행
13. 최종 OS 버전 확인
14. 기존 repo 설정 복원
15. ISO 언마운트

### 4. Restore previous settings

수동 복원 메뉴입니다.

다음 작업을 수행합니다.

- 임시 ISO local repo 파일 삭제
- `current_backup`에 기록된 repo 백업 디렉터리에서 기존 repo 파일 복원
- `current_backup`이 없으면 `repo_backups` 하위의 최신 timestamp 백업 디렉터리를 사용
- 복원할 `.repo` 파일이 실제로 존재하는지 확인
- ISO 언마운트

## 변경 또는 사용되는 경로

스크립트는 다음 경로를 사용합니다.

| 경로 | 용도 |
|---|---|
| `/root/Rocky8.10_minor_update.sh` | 실행 스크립트 |
| `/root/Rocky8.10_minor_update.sh.sha256` | 스크립트 checksum 파일 |
| `/root/Rocky-8.10-x86_64-dvd1.iso` | Rocky Linux 8.10 DVD ISO |
| `/mnt/rocky810_iso` | ISO mount point |
| `/etc/yum.repos.d/rocky-8.10-local.repo` | 임시 local repo 파일 |
| `/root/rocky810_minor_update_state/repo_backups/repo_backup_YYYYMMDDHHMMSS` | 실행별 기존 repo 백업 디렉터리 |
| `/root/rocky810_minor_update_state/current_backup` | 현재 복원에 사용할 repo 백업 디렉터리 경로 |

## 복원 동작

`Run minor update`가 성공, 실패, 사용자 중단으로 종료되더라도 스크립트는 종료 전 다음 복원을 시도합니다.

- `/etc/yum.repos.d/rocky-8.10-local.repo` 삭제
- `current_backup`에 기록된 백업 디렉터리에서 기존 repo 파일 복원
- `current_backup`이 없으면 최신 timestamp 백업 디렉터리 사용
- 복원할 `.repo` 파일이 없으면 실패 처리
- `/mnt/rocky810_iso` 언마운트

수동 복원이 필요한 경우 메인 메뉴에서 `4. Restore previous settings`를 실행합니다.

## 개선된 안전장치

- 실행 시 스크립트 checksum을 검증합니다.
- 실행마다 timestamp 기반 repo 백업 디렉터리를 새로 생성합니다.
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
- `.sh` 파일을 수정하면 `.sha256` 파일도 반드시 갱신해야 합니다.

## Version History

| Version | Date | Changes |
|---|---|---|
| 1.4.0 | 2026-04-20 | 스크립트 checksum 검증 추가, 복원 시 최신 백업 fallback 및 repo 파일 존재 확인 추가 |
| 1.3.0 | 2026-04-20 | 실행별 repo 백업, 필수 명령/GPG key 확인, mount source 확인, dnf check-update 오류 처리, DNF cache 삭제 방식 개선 |
| 1.2.0 | 2026-04-20 | 스크립트 메뉴와 출력 메시지를 영어로 변경하고 ISO mount management를 2번 메뉴로 이동 |
| 1.1.0 | 2026-04-20 | ISO mount 상태 확인, mount, unmount 관리 메뉴 추가 |
| 1.0.0 | 2026-04-20 | Rocky Linux 8.10 오프라인 minor update 초기 버전 |
