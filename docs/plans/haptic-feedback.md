# 햅틱 피드백(진동) 도입 플랜

대상: Godot 모바일 게임 seoul-challenge. SoT = origin/main.
작성/리뷰: plan-design-review (인터랙션·필 차원 집중. 비주얼 화면이 없어 목업 루프는 비적용).

## 1. 목표 / 비목표

**목표** — 전투·진행의 임팩트 순간에 손맛(햅틱)을 더해 모바일 체감을 끌어올린다. MVP 최소가 아니라 *꽤 풍부하게*, 단 과진동 없이.

**비목표** — 데스크톱/웹 진동(no-op), 사운드 시스템 개편, 새 설정 화면 UI 프레임워크.

## 2. 아키텍처

신규 autoload **`HapticManager`** (project.godot 맨 뒤 등록 — EventBus/Settings/PlatformManager 이후 로드).

- **Tier 1 (EventBus 구독)**: 임팩트 순간 대부분이 이미 시그널로 emit됨 → 호출부 수정 0. `HapticManager._ready()`에서 구독.
- **Tier 2/3 (직접 호출)**: 시그널이 없는 전투 손맛·UI 확정은 해당 라인에서 `HapticManager.play_*()` 직접 호출(오디오 패턴과 동일).

진입점 1개로 통일:
```gdscript
func _try(category: StringName, level: int) -> void:
    if not _enabled or not _mobile: return
    var now := Time.get_ticks_msec()
    if now - _last_any_ms < MIN_GAP_MS: return          # 전역 바닥(과진동 융합 방지)
    if now - _last_cat_ms.get(category, -9999) < _cooldown.get(category, 0): return
    _last_any_ms = now
    _last_cat_ms[category] = now
    _emit(level)
```

## 3. 세기 모델 (iOS 제약 반영)

| 레벨 | duration_ms | amplitude | 용도 |
|---|---|---|---|
| LIGHT | 12 | 0.35 | 발사/일반 타격/UI 확정 |
| MEDIUM | 30 | 0.65 | 피격/보스타격/방클리어/구출·정화 |
| STRONG | 70 | 1.0 | 배트 디플렉트(시그니처) |
| DOUBLE | STRONG ×2 (70ms 간격) | 1.0 | 보스 처치(최고조) |
| LONG | 180 | 1.0 | 플레이어 사망 |

> ⚠️ **iOS 제약**: `Input.vibrate_handheld(duration, amplitude)`의 길이·세기는 **Android만 반영**. iOS는 무시하고 고정 임팩트 1발 → 레벨이 균일하게 느껴짐. DOUBLE/LONG은 호출 자체가 2발/1발이라 iOS에서도 구분됨. 이 한계는 의도적으로 수용(iOS 기본 햅틱이 무난).

## 4. 과진동 방지 (이 기능의 #1 리스크 — 핵심 설계 결정)

- **전역 바닥 `MIN_GAP_MS = 30`**: 어떤 두 진동도 30ms 내 연속 불가. 난사·군집 타격이 상시 버즈로 융합되는 것 방지.
- **카테고리 쿨다운**: `enemy_hit=60ms`, `fire=50ms`, `currency=120ms`. 잡몹 떼 타격/연사/동전 다발 수집을 coalesce.
- **델타 게이트**: `player_health_changed`는 *감소(피격)* 시에만, `currency_changed`는 *증가* 시에만 발동. 회복·소비엔 무진동.
- **타임소스**: `Time.get_ticks_msec()`.

## 5. 이벤트 → 세기 매핑 (확정)

### Tier 1 — EventBus 구독 (호출부 수정 0)
| 순간 | 시그널 | 레벨 | 게이트 |
|---|---|---|---|
| 플레이어 피격 | `player_health_changed` | MEDIUM | current < 직전값일 때만 |
| 플레이어 사망 | `player_died` | LONG | — |
| 방 클리어(전투 승리) | `room_cleared` | MEDIUM | — |
| 보스 처치 | `boss_defeated` | DOUBLE | — |
| 친구 정화 | `friend_purified` | MEDIUM | — |
| 학생 구출 | `student_rescued` | MEDIUM | — |

> **`currency_changed` 진동은 컷(디자인 리뷰 결정)** — CurrencySystem이 room_cleared/rescue/purify와 같은 프레임에 보상 currency를 동기 emit하고, 그 핸들러가 HapticManager보다 먼저 등록돼 약한 currency LIGHT가 전역 바닥으로 정작 중요한 MEDIUM을 삼키는 역전이 발생(단위테스트가 검출). 게다가 currency는 최고빈도·저신호 이벤트라 버즈 위험이 큼. 보상 순간은 진행 이벤트의 MEDIUM/DOUBLE가 이미 커버하므로 currency 전용 진동은 제거한다. (후속: 디바운스된 "보상 차임"으로 재도입 여지)

### Tier 2 — 직접 호출 (전투 손맛)
| 순간 | 위치 | 레벨 | 비고 |
|---|---|---|---|
| 발사(런치) | `player.gd:_attack_ranged` | LIGHT | cd50 — 연사 버즈 방지 |
| 배트 디플렉트 성공 | `player.gd:_deflect_bullets_in_arc` | STRONG | 시그니처 |
| 적 피격 | `chaser/ranged_shooter/yokai_friend.take_damage` | LIGHT | cd60 — 근접·투사체 타격 공통 hit-confirm |
| 보스 피격 | `boss.gd:take_damage` | MEDIUM | — |

> **근접 타격은 별도 햅틱 없음** — `_attack_melee`가 부르는 `enemy.take_damage`의 hit-confirm(LIGHT)이 곧 근접 손맛. 별도 추가 시 전역 바닥과 충돌해 우선순위가 뒤집히므로 hit-confirm 하나로 통일.

### Tier 3 — UI 확정 (이산·저빈도만)
| 순간 | 위치 | 레벨 |
|---|---|---|
| 확인 모달 예/아니오 | `confirm_modal.gd` | LIGHT |
| 대화 선택지 확정 | `hub_dialogue_ui.gd:_on_choice_pressed` | LIGHT |

> **공격/스킬 버튼 탭·조이스틱은 의도적 제외** — 공격 입력은 이미 게임플레이 햅틱(발사/타격)을 유발해 중복·버즈가 됨. "풍부함"은 버즈가 아니라 *위계 있는 다양성*으로 달성.

## 6. 설정 토글

`settings.gd`의 `DEFAULT`/`reset_defaults`에 `"haptic_enabled": true` 추가(기존 `touch_controls` 패턴 동일). `set_value`가 이미 `settings_changed`를 emit하므로 HapticManager가 구독해 즉시 반영. 영속화는 다른 키와 동일 경로.

## 7. 플랫폼 게이팅

`_mobile = PlatformManager.has_touch_input() and OS.has_feature("mobile")`. 데스크톱/웹은 전부 no-op(테스트·개발 중 무진동).

## 8. 테스트 가능성

`Input.vibrate_handheld`는 헤드리스에서 부작용 없음. HapticManager에 `_test_log: Array` + `var test_mode` 두어 `_emit` 대신 로그 적재(오디오 매니저의 `_played_sfx` 패턴 차용) → 단위테스트로 (a) 게이트/쿨다운/델타 로직, (b) 이벤트→레벨 매핑 검증.

---

## 7차원 디자인 리뷰 (0-10)

| 차원 | 점수 | 근거 / 10점 조건 |
|---|---|---|
| 1. 인터랙션 상태 커버리지 | 9 | 전투·진행·UI 전 구간 커버. 회복/소비 무진동 구분까지. (10: 저체력 경고 햅틱 등 추가 여지) |
| 2. 피드백 위계 | 10 | LIGHT→MEDIUM→STRONG→DOUBLE/LONG이 이벤트 중요도와 단조 매핑 |
| 3. 과자극/노이즈 제어 | 9 | 전역 바닥+카테고리 쿨다운+델타 게이트+버튼/조이스틱 제외. (10: 실기기 튜닝 후 확정) |
| 4. 컨트롤/설정 | 9 | 기본 ON, 즉시 토글, 기존 키 패턴 일치. (10: 설정 화면 UI 노출까지) |
| 5. 플랫폼 정합성 | 9 | 모바일 게이팅 + iOS 균일 한계 명시 |
| 6. 접근성 | 8 | 햅틱 자체가 보조 피드백. on/off 제공. (10: 시스템 reduce-motion 연동) |
| 7. 일관성 | 10 | 동일 이벤트=동일 레벨. 단일 진입점으로 강제 |

**미해결(실기기 후속)**: 세기 수치(12/30/70/180ms)와 쿨다운(30/50/60/120)은 실기기 체감 튜닝 필요 — 코드 상수 1곳에 모아 조정 쉽게.

---

## GSTACK REVIEW REPORT

| Runs | Status | Findings |
|---|---|---|
| plan-design-review (haptic feel + settings UX, 7 passes) | issues_found→resolved | 과진동 리스크(버튼 탭 중복·군집 버즈)를 전역 바닥+카테고리 쿨다운+버튼 제외로 해소. 회복/소비 무진동 델타 게이트 추가. iOS 균일 한계 명시. |

VERDICT: 설계 승인. 비주얼 목업/아웃사이드보이스는 비적용(비주얼 화면 없음). 세기·쿨다운 상수는 실기기 튜닝 대상으로 단일 상수 블록에 격리.

**UNRESOLVED DECISIONS:**
- 세기/쿨다운 수치 실기기 튜닝 (구현엔 영향 없음 — 상수만 조정)
