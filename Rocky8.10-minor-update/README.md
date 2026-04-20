# Rocky8.10 Minor Update

Rocky Linux 8.x 시스템을 Rocky Linux 8.10 DVD ISO 기준으로 오프라인 minor update 하는 스크립트입니다.

## Purpose

인터넷 연결이 불가능한 환경에서 `/root/Rocky-8.10-x86_64-dvd1.iso` 파일을 local repository로 사용해 Rocky Linux 8.10 기준 `dnf distro-sync`를 수행합니다.

## Script

```text
Rocky8.10_minor_update.sh
```

## Version

```text
1.0.0
```

스크립트 내부의 `SCRIPT_VERSION` 값으로도 확인할 수 있습니다.

## Requirements

- Rocky Linux 8.x
- root 권한
- Rocky Linux 8.10 DVD ISO
- ISO 위치: `/root/Rocky-8.10-x86_64-dvd1.iso`
- `/mnt` 디렉터리 존재
- `dnf`, `rpm`, `mount`, `umount`, `mountpoint`, `df`, `awk` 명령 사용 가능

## Space Check

스크립트는 minor update 진행 전 아래 여유 공간을 확인합니다.

| Path | Minimum Free Space |
|---|---:|
| `/` | 3072 MB |
| `/var` | 5120 MB |
| `/boot` | 512 MB |

## Usage

```sh
sh /root/Rocky8.10_minor_update.sh
```

메뉴에서 필요한 작업을 선택합니다.

```text
1. minor update 환경 확인
2. minor update 진행
3. minor update 이전 설정 복원
4. 종료
```

## Menu

### 1. minor update 환경 확인

다음 항목을 확인합니다.

- root 권한 여부
- Rocky Linux 8.x 여부
- 현재 OS 버전
- 현재 `rocky-release` 패키지 버전
- ISO 파일 존재 여부
- `/`, `/var`, `/boot` 여유 공간
- ISO 마운트 위치 상태

### 2. minor update 진행

다음 순서로 작업합니다.

1. 환경 확인
2. 사용자 확인 입력
3. ISO read-only loop mount
4. ISO 내 `BaseOS`, `AppStream` 디렉터리 확인
5. 기존 repo 파일 백업
6. 기존 repo 파일 임시 비활성화
7. ISO 기반 local repo 생성
8. `dnf clean all`
9. local repo 확인
10. 업데이트 대상 확인
11. Rocky Linux 8.10 기준 `dnf distro-sync`
12. 최종 OS 버전 확인
13. 기존 repo 설정 복원
14. ISO 언마운트

### 3. minor update 이전 설정 복원

수동 복원 메뉴입니다.

다음 작업을 수행합니다.

- ISO local repo 파일 삭제
- 백업된 기존 repo 파일 복원
- ISO 언마운트

## Changed Paths

스크립트 실행 중 다음 경로를 사용합니다.

| Path | Purpose |
|---|---|
| `/root/Rocky-8.10-x86_64-dvd1.iso` | Rocky Linux 8.10 DVD ISO |
| `/mnt/rocky810_iso` | ISO mount point |
| `/etc/yum.repos.d/rocky-8.10-local.repo` | temporary local repo file |
| `/root/rocky810_minor_update_state/repo_backup` | original repo backup directory |

## Restore Behavior

`minor update 진행` 중 성공, 실패, 사용자 중단이 발생해도 스크립트는 종료 시 다음 복원을 시도합니다.

- `/etc/yum.repos.d/rocky-8.10-local.repo` 삭제
- `/root/rocky810_minor_update_state/repo_backup` 안의 기존 repo 파일 복원
- `/mnt/rocky810_iso` 언마운트

수동 복원이 필요한 경우 메뉴에서 `3. minor update 이전 설정 복원`을 실행합니다.

## Notes

- 온라인 repository는 사용하지 않습니다.
- ISO의 `BaseOS`와 `AppStream`만 사용합니다.
- EPEL, vendor repo, custom repo에 의존하는 패키지는 별도 검토가 필요합니다.
- `dnf autoremove`는 자동 실행하지 않습니다.
- 운영 서버 적용 전 테스트 서버에서 먼저 검증합니다.
- 작업 완료 후 재부팅을 권장합니다.

## Version History

| Version | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-04-20 | Initial release for Rocky Linux 8.10 offline minor update |
