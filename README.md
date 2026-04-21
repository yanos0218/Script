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

## Version Policy

스크립트 버전은 `MAJOR.MINOR.PATCH` 형식으로 관리합니다.

| 자리 | 증가 기준 |
|---|---|
| `MAJOR` | 기존 사용 절차, 상태 파일 의미, 복원 방식, 입력/출력 계약, 호환성에 큰 영향을 주는 변경 |
| `MINOR` | 새 메뉴, 새 작업 모드, 새 검증 항목, 새 안전장치처럼 기존 사용 방식을 유지하면서 기능이 늘어나는 변경 |
| `PATCH` | 메시지 개선, README 보강, 오타 수정, 진단 출력 개선, 작은 버그 수정처럼 동작 목적이나 절차를 바꾸지 않는 변경 |

버전 증가 판단은 사용자에게 미치는 영향 기준으로 결정합니다.

- 출력 문구, 색상, 메뉴 표시 형식, README만 바뀌면 보통 `PATCH`를 올립니다.
- 실패 원인 안내처럼 진단 품질을 높이지만 진행 조건이 그대로이면 보통 `PATCH`를 올립니다.
- 기존에는 검사하지 않던 위험 조건을 새로 차단하거나, 새 검증 항목을 추가하면 보통 `MINOR`를 올립니다.
- 메뉴 번호, 상태값, lock/restore 방식, 실행 위치 정책처럼 운영 절차나 자동화 호환성에 영향을 주면 `MAJOR`를 검토합니다.
- 여러 변경이 함께 들어가면 가장 큰 영향도를 기준으로 한 번만 올립니다.

스크립트 버전을 올릴 때는 다음 항목을 함께 갱신합니다.

- 스크립트 내부 `SCRIPT_VERSION`
- 스크립트 내부 checksum 값이 있는 경우 해당 checksum
- 해당 폴더 `README.md`의 현재 버전
- 해당 폴더 `README.md`의 `Version History`

이미 기록된 Version History 항목은 해당 버전의 당시 변경 범위를 유지합니다. 이후 추가 수정은 기존 항목에 덧붙이지 않고 새 버전 항목으로 남깁니다.

## Current Scripts

### Rocky8.10-minor-update

Rocky Linux 8.x 시스템에서 인터넷 연결 없이 Rocky Linux 8.10 DVD ISO를 사용해 minor update를 수행합니다.

- Script: `Rocky8.10-minor-update/Rocky8.10_minor_update.sh`
- Guide: `Rocky8.10-minor-update/README.md`
