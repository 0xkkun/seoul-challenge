# 온보딩 코치마크 시각 언어 재설계

## 상태

- 방향: 사용자 승인 A — 다이제틱 액션 코치마크
- 이슈: #513
- 기준 코드: `origin/main@76301ed`
- 범위: 시각 계층·문구·배치·모션·접근성
- 비범위: 성공 판정, 입력 매핑, 저장 flag, 난이도, 전투 수치

## 문제

현재 온보딩은 기능적으로는 성공 신호를 소비하지만, 화면에서는 큰 중앙 먹색 카드와 두꺼운 둥근 spotlight가 장면보다 먼저 보인다. 플레이어의 시선이 적·문·버튼보다 설명문으로 이동하고, 서로 다른 온보딩 표면이 각자 다른 카드 문법을 사용한다.

현재 960×540 패링 화면의 첫 시선 순서는 다음과 같다.

1. 화면 상단 중앙의 큰 검은 카드
2. 플레이어와 늑대를 함께 감싼 둥근 사각 테두리
3. 미니맵과 실제 전투 대상

의도한 순서는 `대상 → 입력 → 행동 결과`다. 이 순서를 되찾는 것이 이번 재설계의 핵심이다.

## 설계 원칙

1. **장면이 먼저 보인다.** 비모달 안내는 전체 viewport의 20%를 넘는 불투명 표면을 만들지 않는다.
2. **한 번에 한 행동만 말한다.** `키칩 + 행동어`를 기본 단위로 사용하고 설명은 한 줄을 넘지 않는다.
3. **안내는 대상에 붙는다.** world target, 실제 Control, 문, 미니맵 가까이에 배치한다.
4. **성공으로 사라진다.** 정상 경로는 실제 성공 signal이 완료를 결정하고, 시각 컴포넌트는 진행 상태를 소유하지 않는다.
5. **강한 모션은 짧게 한 번만 쓴다.** 반복 pulse 대신 등장·성공 순간에만 140–240ms 모션을 사용한다.
6. **PC와 터치는 같은 의미, 다른 glyph를 쓴다.** 사용할 수 없는 키를 다른 플랫폼에 노출하지 않는다.
7. **기존 게임의 재료를 쓴다.** NeoDunggeunmo 계열 pixel font, 먹색, 한지색, 금색, 청록, 주홍을 사용한다.

## 시각 토큰

### 색

| 역할 | 값 | 용도 |
|---|---:|---|
| `ink_surface` | `Color(0.025, 0.04, 0.055, 0.74)` | 키칩·행동 라벨 배경 |
| `ink_surface_strong` | `Color(0.025, 0.04, 0.055, 0.88)` | 정화처럼 잠시 입력을 설명하는 표면 |
| `paper_text` | `Color(0.96, 0.91, 0.80, 1.0)` | 기본 문구 |
| `gold_info` | `Color(0.93, 0.70, 0.25, 1.0)` | 이동·목표·탐색 |
| `cyan_timing` | `Color(0.38, 0.94, 0.89, 1.0)` | 패링·성공·타이밍 |
| `vermilion_danger` | `Color(0.91, 0.29, 0.23, 1.0)` | 위험·피격 전용 |
| `soft_shadow` | `Color(0.0, 0.0, 0.0, 0.54)` | 텍스트 outline과 얕은 분리 |

보라색 gradient, 흰색 대형 카드, 동일한 큰 radius의 반복은 사용하지 않는다.

### 형태

- 일반 coach label: 최대 `340×72px`, radius `4px`, border `1px`.
- key chip: 최소 높이 `34px`, 좌우 padding `10px`, radius `3px`.
- objective ribbon: 최대 `320×48px`, 화면 상단 safe area 안에 배치.
- target bracket: 대상 rect 네 모서리에 길이 `14px`, 두께 `3px`의 꺾쇠만 그린다.
- 비모달 안내는 전체 화면 dim을 사용하지 않는다.
- 정화의 첫 설명처럼 기존 흐름이 modal인 경우에만 `0.28` 이하 dim을 `450ms` 이내 사용한다.

### 타이포그래피

- 행동어: title role `22–24px`.
- key chip: pixel role `16px`, 영문 키는 대문자.
- 보조 문구: body role `14–15px`.
- 한 표면의 문구는 한국어 기준 22자를 목표로 하고 최대 34자를 넘지 않는다.
- 문장형 설명보다 명사·동사형 행동어를 우선한다.

### 모션

- 등장: `180ms`, opacity `0→1`, scale `0.94→1.0`, ease-out.
- target bracket reveal: `220ms`, 각 모서리가 바깥에서 `6px` 안으로 정렬.
- 성공: `200ms`, cyan flash 후 scale `1.0→0.88`, opacity `1→0`.
- 일반 dismiss: `140ms`, opacity만 감소.
- 자동 종료가 필요한 짧은 hint는 최대 `3.2s`.
- 무한 pulse와 layout 속성 animation은 금지한다.
- reduced motion에서는 모든 duration을 `0`으로 만들고 최종 상태를 즉시 적용한다.

## 공통 컴포넌트

### `OnboardingVisualTokens`

`scripts/ui/onboarding_visual_tokens.gd`는 색·spacing·duration·StyleBox 생성의 단일 진실 공급원이다. 진행 상태나 플랫폼 판정은 갖지 않는다.

### `OnboardingCoachMark`

`scripts/ui/onboarding_coach_mark.gd`는 시각만 담당하는 재사용 `CanvasLayer`다.

```gdscript
func configure(camera: Camera2D, reduced_motion: bool = false) -> void
func show_prompt(model: Dictionary) -> void
func complete() -> void
func dismiss(immediate: bool = false) -> void
func get_snapshot() -> Dictionary
```

`model` 계약:

```gdscript
{
    "id": &"parry",
    "tone": &"timing",             # info | timing | danger
    "action": "받아치기",
    "key_label": "LMB",           # touch는 빈 문자열 + target control
    "detail": "늑대가 달려들 때",
    "target_kind": &"world",       # world | control | none
    "target": wolf_or_control,
    "placement": &"auto",          # auto | top | bottom | ribbon
    "persistent": true,
}
```

컴포넌트는 target 위치, safe-area clamp, bracket, label, motion을 소유한다. 단계 전진, 완료 flag, room gate, tree pause는 소유하지 않는다. root와 모든 비대화형 자식의 `mouse_filter`는 `IGNORE`다.

## 표면별 적용

### 첫 조작 6단계

`IngameControlOnboarding`은 기존 성공 signal과 gate를 유지하고 렌더링만 `OnboardingCoachMark`에 위임한다.

| 단계 | PC | 터치 | 대상 |
|---|---|---|---|
| 이동 | `WASD  이동` | `스틱  이동` | actor / joystick |
| 기본공격 | `LMB  공격` | `공격 버튼  공격` | actor / attack button |
| 대시 | `SPACE  회피` | `대시 버튼  회피` | actor / skill button |
| 강공격 | `SPACE → LMB  강공격` | `대시 → 공격  강공격` | actor / 두 버튼 |
| 지도 | `미니맵 클릭  지도 펼치기` | `미니맵 탭  지도 펼치기` | minimap |
| 출구 | `열린 문  통과` | `열린 문  통과` | 현재 출구 또는 ribbon |

- 화면 중앙 전체 dim은 제거한다.
- touch target에는 bracket과 `12px` tether gap을 사용한다.
- PC target이 actor일 때 label은 actor 위쪽에 두되 체력 HUD·미니맵과 겹치면 아래로 전환한다.
- 완료 시 해당 단계가 cyan으로 짧게 수축한 뒤 다음 단계로 바뀐다.
- skip은 기존 `5.0s` 계약과 실제 버튼을 유지하되 compact text action으로 낮춘다.

### 전투·보상·친구 조우

- 첫 전투: 상단 objective ribbon `적 처치  길 열기`.
- 보상: 기존 reward card가 주 표면이므로 별도 검은 안내 카드를 만들지 않고 title 위에 `첫 강화 · 1장 선택` eyebrow만 둔다.
- 친구 조우: target bracket과 `기절 → 접근 → 정화` 3단 동사 chain.
- 기존 `phase`, `completed_phases`, `current_instruction` snapshot은 의미 계약으로 유지한다.

### 정화

- 기존 intro/groggy 단계와 dismiss 규칙은 유지한다.
- 4분할 대형 dim은 alpha `0.28` 이하, 첫 `450ms` 뒤 약화한다.
- target은 둥근 사각형 대신 금색 corner bracket으로 표시한다.
- intro: `공격  기절시키기` / 보조 `가까이 가면 정화 시작`.
- groggy: `곁을 지켜  정화` / 보조 `범위를 벗어나면 처음부터`.
- 계속 안내는 패널 내부 문장 대신 우하단 작은 `클릭 계속` 또는 `탭 계속` chip으로 분리한다.

### 첫 늑대 패링

- 상단 중앙 `패링` 카드 전체를 제거한다.
- 늑대에 cyan corner bracket을 붙이고 인접 label을 표시한다.
- PC: `LMB  받아치기`, 보조 `늑대가 달려들 때`.
- 터치: `공격 버튼  받아치기`, 보조 `늑대가 달려들 때`.
- Task 4의 reward gate, 첫 wolf prepare, miss/death retry, success flag, room-clear 비차단 계약은 그대로 유지한다.
- Task 5의 `받아쳤다`·hit stop·flash·shake·sound는 같은 cyan timing token을 소비한다.

### 인트로 계속 안내

- plate 중앙 문구와 분리해 우하단 safe area에 작은 chip으로 표시한다.
- PC `LMB  계속`, touch `탭  계속`.
- bounded 자동 진행과 autoplay 차단 복구는 유지한다.
- 음성·plate 전환보다 계속 chip이 먼저 시선을 끌지 않도록 기본 alpha `0.78`을 사용한다.

## Reduced Motion

- `Settings.KEY_REDUCED_MOTION := "reduced_motion"`을 추가하고 기본값은 `false`다.
- Settings UI에 `온보딩 모션 줄이기` toggle을 추가하고 기본값은 OFF다. ON일 때 coachmark와 spotlight의 등장·성공·dismiss tween을 즉시 완료한다.
- 카메라 shake·hit stop 같은 전투 효과 설정과는 별개다. 이 설정은 온보딩 안내 모션만 제어한다.
- PC와 mobile Web에서 설정 변경이 현재 열린 coachmark 다음 전환부터 반영돼야 한다.

## 레이어와 상호작용

```text
World / actor / enemy
  → target bracket + coach label (non-blocking)
  → session HUD / objective ribbon
  → blocking onboarding dim (purify only)
  → reward/dialogue/confirm/result modal
```

- non-blocking coachmark는 modal보다 아래에 둔다.
- reward, dialogue, confirm, result가 열리면 coachmark는 숨는다.
- modal이 닫힌 뒤 아직 유효한 단계만 다시 표시한다.
- 비모달 표면은 pointer와 keyboard event를 소비하지 않는다.

## Safe Area와 화면 점유

- 기준 viewport `960×540`.
- label과 ribbon은 left/right `60px`, top `24px`, bottom `34px` 안쪽.
- touch control comfort zone left/right `72px`, bottom `58px`를 침범하지 않는다.
- 모든 비모달 onboarding surface의 합집합은 viewport 면적의 `20%` 이하를 목표로 하고 `25%`를 hard cap으로 둔다.
- label이 target과 touch control을 동시에 피할 수 없으면 target 반대편과 ribbon 순서로 fallback한다.

## 자동 검증

### Unit

- token 값, radius, max size, motion duration.
- PC/touch copy matrix.
- world/control/none target 배치와 safe-area clamp.
- 모든 non-blocking child `mouse_filter=IGNORE`.
- reduced motion에서 tween 없이 최종 상태 적용.
- success motion은 한 번만 실행되고 stale tween이 다음 prompt를 닫지 않음.

### Integration

- 기존 6단계 성공 signal·gate·skip 계약 유지.
- reward/dialogue/purify/parry surface 상호 배타.
- Task 4 miss/death/next-wolf/success lifecycle 유지.
- intro bounded 자동 진행과 PC/mobile continue copy 유지.
- 960×540에서 joystick, attack, dash, minimap, health HUD와 overlap 없음.
- modal open/close 뒤 유효 단계만 복원.

### Release Web UAT

- PC 960×540: 이동→공격→대시→강공격→지도→출구 각 coachmark 전후.
- mobile Web 960×540: 실제 joystick/attack/dash/minimap target과 label 위치.
- 친구 intro/groggy, reward, school talk, PC/mobile parry.
- reduced motion ON/OFF 비교.
- 모든 경로 WebGL2=true, console/page/request error 0.
- 캡처는 before/after 동일 state 쌍으로 보관하고, PR raw URL 계약을 만족한다.

## 완료 조건

1. 중앙 대형 black onboarding card가 첫 조작·패링·contextual hint에서 사라진다.
2. 모든 안내가 공통 token과 coachmark 문법을 사용한다.
3. 플레이어가 읽어야 하는 문구가 `키/버튼 + 행동 + 선택적 한 줄 detail`로 제한된다.
4. 기존 성공 판정·gate·저장 flag·skip·retry 회귀가 모두 통과한다.
5. PC/mobile 960×540 release Web 캡처에서 장면과 대상이 첫 시선이 된다.
6. reduced motion이 실제 Settings toggle로 작동한다.
7. quick/full, 독립 Challenger, Codex review, 최신 CI가 모두 녹색이다.

## 실행 경계

이 재설계는 하나의 시각 계약이지만 변경 표면이 넓다. 구현 계획은 다음 순서를 지켜 각 단계가 독립적으로 검증 가능하게 한다.

1. token·coachmark·reduced-motion setting 기반.
2. 첫 조작 6단계와 contextual objective/reward.
3. 정화·패링·인트로 계속 안내.
4. 전체 PC/mobile release Web UAT와 visual regression.

Task 5 패링 성공 피드백은 이 계약이 병합된 뒤 재개한다.
