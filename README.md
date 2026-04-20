# Script

운영 자동화와 점검용 스크립트를 목적별 폴더로 관리하는 저장소입니다.

## Directory Index

| Path | Description |
|---|---|
| `Rocky8.10-minor-update/` | Rocky Linux 8.x 시스템을 Rocky Linux 8.10 기준으로 오프라인 minor update 하는 스크립트 |

## Management Policy

- 스크립트는 목적별 폴더 단위로 관리합니다.
- 각 폴더에는 실행 스크립트와 전용 `README.md`를 함께 둡니다.
- 스크립트 내부에는 `SCRIPT_VERSION`을 명시합니다.
- 변경 이력은 Git commit과 각 폴더의 Version History에 남깁니다.
- 운영 서버 적용 전에는 반드시 테스트 서버에서 먼저 검증합니다.

## Current Scripts

### Rocky8.10-minor-update

Rocky Linux 8.x 시스템에서 인터넷 연결 없이 Rocky Linux 8.10 DVD ISO를 사용해 minor update를 수행합니다.

- Script: `Rocky8.10-minor-update/Rocky8.10_minor_update.sh`
- Guide: `Rocky8.10-minor-update/README.md`
