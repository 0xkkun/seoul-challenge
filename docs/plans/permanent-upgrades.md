# 영구 재화 메타 업그레이드 — 설계 (확정)

대상: Godot 로그라이크 seoul-challenge. SoT = origin/main.
목적: 4곳에서 벌리지만 **소비처가 0인 영구 재화**(`permanent`)에 의미를 부여 — 락커에서 영구 강화를 사고, 그 강화가 실제 런에 반영(메타 프로그레션).

> 상태: 설계 락 완료. 이슈 분할은 아직 하지 않음(사용자 지시). 구현 착수 전 단계.

## 1. 범위

**포함** — 영구 재화로 사는 영구 스탯 강화 4종(아래 카탈로그), 락커 UI 구매, 런 시작 시 자동 적용, 영속화.

**제외** — 시작 무기 언락(스토리/내러티브로 별도 처리), 환불/리스펙, 디스크 영속화 개선(현재 in-memory 프로필과 동일 수준 유지), 런 내 재화 상점 확장(별도 건).

## 2. 확정 결정 (락)

### 카탈로그 — 기존 모디파이어 키에 매핑(적용 코드 최소화), 각 3레벨, 비용 4/7/10
| id | 표시 | 모디파이어 키 | 레벨당 | 최대 | 비용(레벨1/2/3) | 효과(base→max) |
|---|---|---|---|---|---|---|
| `max_health` | 최대 체력 | `max_health_add` | +1 | 3 | 4 / 7 / 10 | 5 → 8 |
| `melee_damage` | 근접 피해 | `melee_damage_add` | +1 | 3 | 4 / 7 / 10 | 1 → 4 |
| `bat_damage` | 배트 피해 | `bat_damage_add` | +1 | 3 | 4 / 7 / 10 | 2 → 5 |
| `dodge_charges` | 회피 횟수 | `special_skill_uses_add` | +1 | 3 | 4 / 7 / 10 | 3 → 6 |

- 비용 커브: 에스컬레이팅(다음 레벨로 가는 비용 = `[4,7,10][현재레벨]`). 한 업그레이드 풀강 = 21. 영구 재화 런당 +8~15이라 초반 ~2개/런, 후반 선택 압박.
- 4종 모두 풀강 총비용 = 84.

### 영속화
`SaveManager` 프로필(`_profile` dict, `permanent_currency`와 동일 자리)에 `meta_upgrades: {id: level}` 추가. 기본값/`reset_profile`에 빈 dict 또는 0 레벨.

### 소비 API
`CurrencySystem.spend_permanent(amount: int, reason: String) -> bool` 신설 — `_permanent >= amount`면 `_change_permanent(-amount, reason)` 후 `true`, 아니면 `false`(차감 없음).

## 3. 아키텍처 — 기존 런 모디파이어 파이프라인 재사용

플레이어는 이미 모디파이어를 합성·적용한다:
- `player.gd`: `_run_modifier_ids` → `_apply_run_modifier_stats()` → `MapItemCatalog.compose_modifiers()` + `apply_modifiers_to_stats(_base_run_stats, mods)` → `_apply_stats()`.
- `apply_modifiers_to_stats`가 다루는 키: `move_speed_mult`, `attack_cooldown_mult`, `fire_cooldown_mult`, `melee_damage_add`, `bat_damage_add`, `max_health_add`.

**메타 업그레이드 = 영구 모디파이어 베이스라인**을 이 파이프라인에 합류:
1. 플레이어 스폰/리셋 시 `SaveManager`의 `meta_upgrades` 레벨 → 모디파이어 dict로 변환(`MetaUpgradeCatalog.compose_modifiers(levels)`).
2. `_apply_run_modifier_stats()`에서 런 아이템 모디파이어 합성 결과에 **메타 모디파이어를 머지**(`_add`는 합, `_mult`는 곱) 후 `apply_modifiers_to_stats`.
3. 기존 키(체력/근접/배트)는 적용 코드 0줄. **회피 횟수만 신규 키 배선**:
   - `apply_modifiers_to_stats`에 `special_skill_uses` = base + `special_skill_uses_add` 추가
   - `_capture_base_run_stats`에 `special_skill_max_uses` 캡처 추가, `_apply_stats`에서 `special_skill_max_uses` 반영 + `special_skill_uses_remaining` 재설정

## 4. 컴포넌트 (추가/변경)

| 파일 | 종류 | 내용 |
|---|---|---|
| `scripts/items/meta_upgrade_catalog.gd` | 신규(정적, 순수) | 4종 정의 + `upgrade_ids()`·`get_def(id)`·`max_level(id)`·`cost_to_next(id, level)`·`compose_modifiers(levels)→Dictionary`·`can_purchase(id, level, balance)` |
| `scripts/autoload/currency_system.gd` | 변경 | `spend_permanent(amount, reason) -> bool` 공개 API |
| `scripts/autoload/save_manager.gd` | 변경 | 기본 프로필/`reset_profile`에 `meta_upgrades` + 헬퍼 `get_meta_upgrade_level(id)`·`set_meta_upgrade_level(id, level)` |
| `scripts/items/map_item_catalog.gd` | 변경 | `apply_modifiers_to_stats`에 `special_skill_uses` 처리 + `_BASE_MODIFIERS`에 `special_skill_uses_add: 0` |
| `scripts/player/player.gd` | 변경 | 스폰 시 메타 모디파이어 시드 + `_apply_run_modifier_stats` 머지 + `special_skill` 캡처/적용 |
| `scripts/ui/locker_maintenance.gd` (+ .tscn) | 변경 | 업그레이드 행(이름/레벨·max/비용/BUY) + 영구 재화 잔액 표시 + 구매 wiring |
| `tests/unit/test_meta_upgrade_catalog.gd` | 신규 | 카탈로그 순수 로직(비용/compose/can_purchase) |
| `tests/unit/test_currency_spend.gd` | 신규 | `spend_permanent` 잔액/차감/실패 |
| `tests/unit/test_meta_upgrade_apply.gd` | 신규 | 레벨→플레이어 스탯 반영(체력/근접/배트/회피) |
| `scripts/verify_project_contract.py` | 변경(필요시) | autoload 추가 없음 → 변경 없을 가능성. 신규 .gd.uid 추적 |

> 신규 autoload는 만들지 않는다(상태는 SaveManager에, 로직은 정적 카탈로그/서비스). 구매 오케스트레이션(레벨 읽기→비용 확인→`spend_permanent`→레벨++ 저장)은 정적 헬퍼로 두고 락커 UI가 호출.

## 5. 구매 플로우
1. 락커 UI가 `MetaUpgradeCatalog.cost_to_next(id, level)` + `CurrencySystem.get_permanent()`로 구매 가능 판단(잔액·max레벨).
2. BUY → `CurrencySystem.spend_permanent(cost, "meta_upgrade:%s" % id)` 성공 시 `SaveManager.set_meta_upgrade_level(id, level+1)`.
3. UI 갱신(잔액·레벨·비용·버튼 활성). 다음 런 스폰부터 효과 반영.

## 6. 엣지/계약
- 최대 레벨 도달 → BUY 비활성("MAX").
- 잔액 부족 → BUY 비활성.
- 적용 타이밍: 진행 중 런에는 소급 안 함(스폰 시 시드). 락커는 런 사이 화면이라 자연스러움.
- UI 자동화 계약: 버튼에 `test_id`/`action` 부여(기존 락커 규약 준수) — 예 `settings.../locker.upgrade.<id>`.

## 7. 밸런스 점검
- 최대 체력 5→8(+60%), 근접 1→4(×4 — 강하지만 근접 위주 빌드 보상), 배트 2→5, 회피 3→6. 4종 풀강 84재화 ≈ 6~10런. 잼 분량에 적절.

## 8. 구현 순서(이슈 미분할 — 단일 설계)
토대(spend API + 저장 스키마) → 효과(카탈로그 + 플레이어 적용 + special_skill 키) → UI(락커) 순. 검증은 각 단계 단위테스트 + quick gate. 분할이 필요해지면 이 순서를 PR 경계로 쪼갠다.

## 9. 미해결/후속
- 비용·효과 수치 실기기/플레이 밸런스 튜닝(상수 격리).
- 시작 무기 언락(스토리 트랙에서 별도).
- 런 내 재화 상점 확장(별도 건).
