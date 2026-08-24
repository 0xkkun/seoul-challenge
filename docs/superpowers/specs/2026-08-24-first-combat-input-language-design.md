# 첫 전투 입력 언어 재설계

상태: 사용자 승인됨 (`추천안 진행`, 2026-08-24)
추적 이슈: #544
기준 코드: `origin/main@2298b52`
후속 검증: #543

## 배경

#543 실플레이에서 첫 전투의 PC 입력 언어가 실제 행동과 어긋나는 문제가 확인됐다.

1. 온보딩 중 사망하면 재학습이 필요한데 결과 화면은 학교 복귀만 남긴다.
2. 코치마크가 `LMB`, `SPACE` 같은 개발자 약어를 텍스트로 노출해 입력을 한눈에 읽기 어렵다.
3. 대시는 Space와 Shift를 모두 받으면서 안내와 실제 기준 키가 흔들린다.
4. 늑대 돌진 패링은 안내가 있지만 원거리 투사체 반사는 별도 학습·성공 문맥이 없다.
5. PC 근접 공격은 이동 방향만 바라보므로 투사체를 정밀하게 되받아칠 조준 수단이 없다.

현재 코드는 문제의 기반 기능을 상당 부분 이미 가진다.

- 결과 UI에는 `retry_requested`와 세션 config 보존 재시작 경로가 있다.
- `Player`는 Shift와 Space를 같은 대시 입력으로 처리한다.
- `EnemyBullet.deflect()`와 배트 부채꼴 투사체 반사가 존재한다.
- `Player.parry_succeeded`, `ParryOnboarding`, `ParryFeedbackController`가 늑대 패링에 연결돼 있다.
- 터치 입력에는 이미 공격 버튼 드래그 조준이 있고, PC만 별도 마우스 조준이 없다.

따라서 새 튜토리얼 씬이나 새 전투 시스템을 만들지 않는다. 기존 세션·플레이어·코치마크 경계를 일반화하고, 사용자에게 보이는 PC 입력 표현을 하나로 통일한다.

## 목표

- 온보딩 실패가 학습 흐름을 끊지 않고 같은 온보딩 재도전으로 이어진다.
- PC 사용자가 키 이름을 읽지 않아도 그림으로 이동·조준·공격·대시를 이해한다.
- PC 대시의 유일한 키보드 기준을 Shift로 만든다.
- 우클릭 홀드 중 이동하면서 커서 방향으로 근접 공격을 조준할 수 있다.
- 조준점은 커서를 따라가되 실제 타격 범위를 거짓으로 늘리지 않는다.
- 첫 원거리 투사체 패링을 실제 반사 성공까지 반복 학습한다.
- 늑대 패링과 투사체 패링이 같은 성공 피드백을 공유하면서도 완료 상태는 독립적으로 추적된다.
- 기존 모바일 터치·게임패드·일반 런 결과 흐름은 유지한다.

## 비목표

- 키 리바인딩 UI나 전체 InputMap 전환
- 우클릭 해제 시 자동 공격
- 조준 중 이동 감속·정지 또는 슬로모션
- 배트 사거리·부채꼴·피해량 재조정
- 일반 런 사망에서 학교 복귀 선택 제거
- 원거리 적·투사체 AI 재설계
- 모바일 조준 UX 변경

## 채택한 접근

### A. 증상별 문자열·조건만 직접 수정

가장 빠르지만 코치마크, compact legend, 패링 카드가 다시 서로 다른 입력 표기를 만들 가능성이 높다. 마우스 조준과 투사체 패링도 별도 성공 이벤트 없이 임시 조건에 묶이게 된다.

### B. 공통 입력 글리프 + 얇은 마우스 조준 계층 + 종류가 있는 패링 이벤트

채택안이다. 시각 표현은 `InputPromptStrip`, 조준 시각은 `MeleeAimIndicator`, 성공 의미는 종류가 포함된 `Player.parry_succeeded` payload에 모은다. 기존 전투 수학과 세션 흐름은 유지하면서 다섯 문제를 독립 PR로 검증할 수 있다.

### C. 전체 입력 액션·리바인딩·타깃 시스템 도입

장기적으로는 유연하지만 현재 요구보다 크다. 모든 입력을 InputMap과 타깃 선택 상태 머신으로 옮기면 모바일·게임패드 회귀 범위가 불필요하게 커진다.

## 경험 설계

### 1. 온보딩 사망

온보딩 세션에서 체력이 0이 되면 기존 사망 결과 화면을 사용하되 행동은 하나만 남긴다.

- 제목: `쓰러짐`
- 설명: `다시 일어나 첫 탐험을 이어가자.`
- 주 행동: `다시 도전`
- 학교 복귀 버튼: 숨김
- 재도전: 기존 active config를 복제하고 `source=session_result_retry`로 같은 온보딩을 시작

이 규칙은 `onboarding_kind != ""`인 사망 결과에만 적용한다. 온보딩 성공 결과는 지금처럼 학교 복귀만 노출하고, 일반 런 사망은 기존 선택지를 유지한다.

재시작 요청이 실패하면 학교로 보내지 않는다. 결과 화면을 유지하고 `다시 시작하지 못했습니다. 다시 시도해 주세요.` 상태를 보여 재시도할 수 있게 한다.

### 2. PC 입력 글리프

PC 안내는 영문 약어 대신 Kenney `Input Prompts Pixel 1-Bit` CC0 PNG를 사용한다.

- 원본: [Kenney Input Prompts Pixel 1-Bit](https://kenney.nl/assets/input-prompts-pixel-1-bit)
- 라이선스: CC0 원문을 에셋 폴더에 함께 커밋
- 렌더링: 16×16 원본을 정수 배율로 확대하고 nearest 필터 유지
- 기본 색: 상아색
- 활성·강조 색: 기존 코치마크 금색
- 배경: 기존 먹색 coach style

지원 글리프는 다음으로 제한한다.

| 의미 | 시각 |
|---|---|
| 이동 | W/A/S/D 키캡 묶음 |
| 조준 유지 | 오른쪽 버튼이 강조된 마우스 |
| 타격 | 왼쪽 버튼이 강조된 마우스 |
| 대시 | `SHIFT`가 적힌 키캡 |
| 순서 | 금색 화살표 |

`LMB`, `RMB`, `SPACE` 문자열은 플레이어 노출 문구와 snapshot에서 허용하지 않는다. `SHIFT`는 실제 키캡 표기이므로 유지한다. 한국어 행동어 `이동`, `조준`, `타격`, `회피`, `받아치기`는 아이콘의 의미를 보조한다.

모바일은 기존 터치 버튼·조이스틱 대상을 그대로 사용하고 PC 글리프를 렌더링하지 않는다.

### 3. Shift 전용 대시

PC 키보드 대시는 Shift만 받는다.

- 유지: 터치 skill 버튼, 게임패드 왼쪽 트리거
- 제거: Space 키 대시
- 유지: Shift 직후 좌클릭 강공격
- 코치마크: Shift 키캡 → 대시
- compact legend: Shift 키캡 + `회피`

Space는 이 변경 뒤 어떤 전투 행동도 시작하지 않는다. 입력 안내와 실제 판정이 같은 테스트에서 검증돼야 한다.

### 4. 우클릭 홀드 조준

PC에서 우클릭을 누르고 있는 동안 마우스 조준 상태가 활성화된다.

- WASD 이동은 계속된다.
- 캐릭터 조준 방향과 다음 공격 방향은 플레이어 위치에서 커서로 향한다.
- 좌클릭을 누르면 현재 조준 방향으로 기존 근접 공격을 실행한다.
- 좌클릭 단독 공격은 기존처럼 이동·마지막 바라보기 방향으로 실행한다.
- 우클릭을 놓으면 조준 표시를 숨기고 기존 이동 기반 방향으로 복귀한다.
- 우클릭 해제 자체는 공격을 발생시키지 않는다.

조준점은 커서를 따라가지만 표시되는 실제 타격점은 다음 공격의 유효 사거리로 제한한다.

```text
direction = normalize(cursor_world - player_world)
reach = current_melee_reach()
target = player_world + direction * min(distance_to_cursor, reach)
```

커서가 플레이어 위치와 거의 같으면 마지막 유효 facing을 사용한다. 대시 강공격 창이 활성화돼 다음 타격 사거리가 늘어나는 경우 indicator도 같은 `current_melee_reach()` 값을 사용해 실제 판정과 일치한다.

시각은 `MeleeAimIndicator`가 담당한다.

- 얇은 상아색 방향선
- 사거리 끝 또는 커서까지의 금색 타격 기준점 링
- 실제 `range`와 `arc`를 거짓 없이 보여 주는 낮은 알파의 부채꼴
- 충돌·입력 캡처 없음
- pause, modal, 사망 결과, 세션 종료, scene exit에서 즉시 숨김
- 조준 중 UI 버튼 위에 포인터가 있으면 활성화하지 않음

### 5. 원거리 투사체 패링 학습

원거리 패링은 실제로 투사체를 반사할 수 있는 각성 배트 상태에서만 학습한다. 단순 제거만 가능한 각성 전 배트에는 성공 안내를 띄우지 않는다.

첫 eligible 원거리 적이 투사체를 생성하면 비모달 coachmark를 투사체 또는 투사체 진행 경로 가까이에 표시한다.

- PC: 우클릭 조준 아이콘 → 좌클릭 타격 아이콘, `날아오는 공격을 되받아쳐`
- 터치: 기존 공격 버튼 대상, `날아오는 공격을 되받아쳐`
- dim 없음, pause 없음, gameplay pointer 통과
- 방 클리어 차단 없음

투사체가 빗나가거나 사라지면 안내를 닫고 다음 eligible 투사체에서 다시 띄운다. 실제 반사 성공 전까지 세션과 이후 런에서 반복한다.

성공 시 다음을 한 번 수행한다.

- 공통 `parry_succeeded` 이벤트에 `kind=enemy_projectile` 기록
- 기존 `ParryFeedbackController`의 텍스트·히트스톱·플래시·셰이크·사운드·햅틱 재사용
- `ranged_parry_tutorial_complete=true` 저장
- 원거리 패링 coachmark 즉시 종료

늑대 돌진 성공은 `kind=wolf_dash`, 기존 `parry_tutorial_complete` 플래그를 사용한다. 두 플래그는 합치지 않는다. 한 종류 성공이 다른 종류의 안내를 건너뛰게 만들면 안 된다.

## 컴포넌트와 인터페이스

### `InputPromptStrip`

위치: `scripts/ui/input_prompt_strip.gd`

역할은 선언적 action 목록을 실제 TextureRect·키캡·화살표로 렌더링하는 것이다.

```gdscript
func configure(actions: Array[StringName], input_mode: StringName) -> void
func get_snapshot() -> Dictionary
```

지원 action은 `move`, `aim_hold`, `attack`, `dash` 네 개다. 알 수 없는 action은 빈 텍스트로 대체하지 않고 숨기며 debug build에서 오류를 기록한다. `OnboardingCoachMark`는 optional `input_actions` 모델이 있으면 기존 `key_label` 대신 strip을 배치한다. 기존 text-only 호출자는 계속 동작한다.

### `MeleeAimIndicator`

위치: `scripts/ui/melee_aim_indicator.gd`

```gdscript
func show_aim(origin: Vector2, target: Vector2, reach: float, arc: float) -> void
func hide_aim() -> void
func get_snapshot() -> Dictionary
```

Indicator는 입력을 읽거나 공격을 결정하지 않는다. `Player`가 계산한 origin·target·reach·arc만 그린다. 링만으로 점 타격처럼 오해하지 않도록 실제 근접 판정의 부채꼴도 함께 표시한다. 이 경계로 조준 수학은 순수 함수 테스트가 가능하고 시각 노드는 전투 판정을 바꾸지 않는다.

### `Player` 조준·패링 계약

추가 순수 함수:

```gdscript
static func clamped_aim_target(origin: Vector2, cursor: Vector2, reach: float, fallback: Vector2) -> Vector2
```

추가 상태 조회:

```gdscript
func is_mouse_aiming() -> bool
func get_mouse_aim_snapshot() -> Dictionary
func current_melee_reach() -> float
```

기존 signal은 payload 의미를 확장한다.

```gdscript
signal parry_succeeded(payload: Dictionary)

# wolf
{kind=&"wolf_dash", direction, player_position, enemy_position}

# projectile
{kind=&"enemy_projectile", direction, player_position, projectile_position, count}
```

투사체 반사 함수는 성공 개수와 대표 위치를 반환한다. 실제 `EnemyBullet.deflect()` 호출이 수락된 뒤에만 `enemy_projectile` 성공을 방출한다.

`EnemyBullet.deflect()`는 중복 반사와 성공 반사를 구분할 수 있게 반환 계약을 명시한다.

```gdscript
func deflect(new_direction: Vector2) -> bool
```

처음 반사해 진행 방향·collision mask를 적 대상으로 바꾸면 `true`, 이미 반사됐거나 유효하지 않으면 `false`다. `deflect()`가 없는 fallback 투사체를 제거하는 동작은 원거리 패링 성공으로 세지 않는다.

### `RangedShooter` 투사체 생성 계약

기존 `fired(origin, direction)`은 유지한다. 실제 bullet을 tree에 추가하고 launch한 뒤 다음 signal을 추가한다.

```gdscript
signal projectile_spawned(projectile: Node2D)
```

`SessionRoot`는 `CombatRoom.enemy_spawned`로 들어온 각 ranged enemy의 `projectile_spawned`를 연결한다. 방 진입 시 한 번만 tree를 스캔하는 방식은 후속 wave를 놓치므로 사용하지 않는다.

### 패링 학습 coordinator

`SessionRoot`가 다음을 조정한다.

- wolf `dash_state_changed` → `ParryOnboarding.show_for_wolf()`
- ranged `projectile_spawned` → 일반화된 `ParryOnboarding.show_for_target(..., kind=&"enemy_projectile")`
- player `parry_succeeded.kind` → 해당 완료 플래그 저장 + 공통 피드백

`show_for_wolf()` 공개 계약은 기존 테스트와 호출자를 위해 유지하고 내부에서 일반 API를 호출한다.

## 상태 전이

### 온보딩 사망

```text
onboarding active
  → health 0
  → death summary(paused)
  → return hidden + retry primary
  → retry requested
  → old onboarding cleanup
  → same config replacement session
```

### PC 조준

```text
idle/facing
  → RMB pressed outside UI
  → aiming(move allowed, indicator visible)
  → LMB pressed
  → attack in clamped aim direction
  → RMB released / modal / death / exit
  → indicator hidden + movement facing
```

### 원거리 패링 학습

```text
eligible=false ───────────────────────────────┐
eligible=true + projectile_spawned            │
  → prompt active                             │
  → projectile gone without deflect           │
  → prompt hidden, wait next projectile ──────┤
  → actual deflect                            │
  → common parry feedback                     │
  → ranged_parry_tutorial_complete=true       │
  → future projectiles no prompt ─────────────┘
```

## 정리와 오류 경계

- 사망 retry 실패는 학교 복귀로 대체하지 않고 같은 화면에서 재시도 가능하게 한다.
- 조준 방향이 0이거나 non-finite이면 마지막 유효 facing을 사용한다.
- melee reach가 0 이하이거나 non-finite이면 indicator를 숨기고 공격 판정을 늘리지 않는다.
- UI hover, pause, modal, settings, summary가 열리면 RMB 상태를 소비하지 않고 indicator를 숨긴다.
- projectile이 prompt 표시 중 삭제되면 weak reference를 확인하고 즉시 dismiss한다.
- room change, death, retry, finish, scene exit에서 ranged enemy·projectile·player signal을 모두 해제한다.
- 중복 projectile signal이나 한 swing의 다중 탄환 반사는 성공 피드백과 완료 저장을 한 번만 만든다.
- 모바일 feature에서는 mouse aim을 만들지 않고 기존 touch aim이 우선한다.

## 구현 슬라이스

각 슬라이스는 별도 GitHub 이슈, origin/main 기반 worktree, ready PR, Korean commit/title/body, current-head Codex 및 green CI를 가진다.

1. **온보딩 사망 재도전**
   - death summary action 우선순위와 실패 처리
   - 일반 사망·온보딩 성공 무회귀
2. **공통 입력 글리프 에셋·렌더러**
   - Kenney 1-bit PNG, CC0, `InputPromptStrip`
   - text-only fallback과 mobile target 보존
3. **Shift 전용 대시와 첫 조작 안내 정렬**
   - Space 제거, Shift 판정·글리프·compact legend
   - 강공격 성공 순서 유지
4. **우클릭 홀드 근접 조준**
   - 순수 clamp 수학, Player 상태, `MeleeAimIndicator`
   - 이동·UI hover·pause·cleanup 계약
5. **원거리 투사체 패링 학습**
   - projectile spawn signal, 종류가 있는 parry payload
   - 독립 완료 플래그, 반복·성공·정리
6. **#543 통합 QA**
   - 최신 main full gate, release Web PC/mobile, Android visual launch
   - 다섯 사용자 지적의 사용자 관점 재검증

## 테스트 설계

### 단위 테스트

- 온보딩 death: return hidden, retry visible/primary, 설명에 학교 복귀 없음
- 일반 death: 기존 return/retry 선택 유지
- 온보딩 success: retry 숨김, 학교 복귀 유지
- `resolve_special_input`: Shift/touch/trigger만 true, Space 단독 false
- PC prompt snapshot: `LMB`, `RMB`, `SPACE` 없음, action별 texture path 존재
- 글리프 texture filtering: nearest, 정수 배율, CC0 파일 존재
- `clamped_aim_target`: inside range, outside clamp, zero vector fallback, non-finite 방어
- RMB hold/release와 UI hover가 aim 상태·indicator를 정확히 전환
- LMB 단독은 facing, RMB+LMB는 cursor direction 사용
- `EnemyBullet.deflect()` 실제 수락 수만 projectile parry payload에 포함
- 다중 탄환 한 swing은 완료 저장·피드백 한 번
- wolf/projectile kind가 서로 다른 플래그를 갱신

### 통합 테스트

- 온보딩 사망 → retry → 같은 onboarding kind 새 세션, 학교 callback 0
- Shift 대시 → 좌클릭 강공격 성공, Space 입력은 단계·대시를 시작하지 않음
- RMB 조준 중 WASD 이동 거리 증가 + 타격 방향은 커서 방향
- cursor가 사거리 밖이어도 indicator와 실제 hit arc가 같은 reach 사용
- 첫 ranged projectile prompt → miss → 다음 projectile 반복 → 실제 deflect 성공 → 이후 숨김
- room clear는 prompt 미완료 상태에서도 가능
- death/retry/scene exit가 aim·prompt·parry feedback을 모두 정리
- 기존 touch aim, touch dash, wolf parry lifecycle 통과

### Release Web UAT

headed Chromium WebGL2, 960×540에서 다음을 실제 production scene 또는 test-only fixture로 검증한다.

1. 온보딩 사망 화면에 `다시 도전`만 노출되고 같은 온보딩을 시작한다.
2. PC 첫 조작 카드와 compact legend가 1-bit 아이콘을 표시하고 약어를 노출하지 않는다.
3. Space는 무반응, Shift는 대시, Shift 직후 좌클릭은 강공격이다.
4. 우클릭 홀드 중 이동이 계속되고 타격점이 cursor를 따라가며 reach에서 clamp된다.
5. 첫 원거리 탄 안내가 보이고 miss 후 반복되며 실제 반사 성공에서 종료된다.
6. console/page/request error 0, time scale·camera·indicator·prompt leak 0.

Android는 PC 전용 입력을 좌표 탭으로 흉내 내지 않는다. debug APK 설치·landscape/safe-area 시각 확인과 기존 touch 자동 계약 회귀만 수행한다.

## 완료 기준

- 다섯 사용자 지적이 각각 독립 이슈·PR·merge SHA·테스트·UAT 증거를 가진다.
- 첫 PC 조작 화면 어디에도 `LMB`, `RMB`, `SPACE`가 노출되지 않는다.
- 온보딩 사망에서 학교 복귀 행동이 보이지 않는다.
- Space 단독은 대시를 시작하지 않고 Shift는 시작한다.
- RMB+LMB 조준 타격이 이동 중 동작하며 사거리를 늘리지 않는다.
- 원거리 패링 안내는 실제 반사 성공만 완료로 인정한다.
- 모바일 터치와 기존 늑대 패링 테스트가 모두 green이다.
- #543 최종 QA에서 P0/P1/P2 회귀가 없고 PR이 merge된다.
