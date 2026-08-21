# 첫 5분 완성 프로그램 설계

상태: 사용자 승인됨 (`A 승인`, 2026-08-22)  
추적 이슈: #502  
기준 코드: `origin/main@c6a2ac7`  
요구사항 장부: `docs/requirements/2026-08-22-improvement-coverage.md`

## 목표

새 PC 사용자가 게임 시작 후 첫 3~5분 동안 입력을 추측하거나 검은 화면을 멈춘 화면으로 오해하지 않고, 다음 행동을 실제 플레이로 익히게 한다. 학습 범위는 이동, 공격, 대시, 강공격, 지도, 보상, 정화, 말 걸기이며, 배트를 얻은 뒤 첫 늑대전에서 패링을 실제로 성공하는 후속 학습까지 이어진다.

이 프로그램은 제공된 개선 명세를 문서에만 남기지 않는다. 각 요구사항을 현재 구현과 대조하고, 실행할 계약을 별도 GitHub 이슈와 PR로 연결한다.

## 승인된 결정

- PC 입력의 기준은 `좌클릭=공격`, `SPACE=대시`, `E=말 걸기`다.
- `SHIFT`는 기존 사용자를 위한 보조 대시로 유지하되 온보딩의 기본 키로 홍보하지 않는다.
- 별도 튜토리얼 아레나는 만들지 않는다. 이야기 속 실제 첫 런과 첫 정규 런에서 학습한다.
- 툴팁을 읽은 것만으로 완료하지 않는다. 가능한 단계는 실제 성공 이벤트로 완료한다.
- 패링 실패는 방 진행을 막지 않는다. 성공하지 못하면 다음 늑대에서 다시 안내한다.
- 제품 변경은 한 이슈·한 검증 계약·한 worktree·한 PR 원칙으로 분할한다.
- 마우스 조준과 키 리바인딩 UI는 이 프로그램의 입력 계약에 포함하지 않는다.

## 확인된 문제와 원인

### 인트로가 멈춘 검은 화면처럼 보인다

headed Chromium의 새 Web 세션에서 게임 시작 후 추가 입력 없이 8.5초를 관찰했지만 첫 장면에 그대로 머물렀다. `NightIntroCutscene._wait_for_advance()`는 timeout 없이 `_advance_requested`만 기다린다. 따라서 클릭하지 않으면 진행되지 않는 것은 브라우저 렌더링 실패가 아니라 현재 코드의 무기한 수동 진행 계약이다.

인트로 배경은 완전한 검정에서 시작해 어두운 플레이트로 페이드된다. 첫 자막과 진행 힌트가 나타나기 전의 공백까지 겹쳐 사용자는 정지 화면으로 인식할 수 있다.

### 플랫폼별 계속 안내가 없다

`NightIntroCutscene`과 `HubDialogueUi`는 `탭해서 계속`을 고정 문자열로 사용한다. PC Web에서도 터치 표현이 보인다. `DisplayServer.is_touchscreen_available()`는 마우스→터치 에뮬레이션이 켜진 데스크톱에서도 참일 수 있으므로, 문구 분기는 `mobile`, `web_android`, `web_ios` feature tag를 기준으로 해야 한다.

### 현재 온보딩은 실제 숙련을 증명하지 않는다

`IngameControlOnboarding`은 이동 벡터, 공격 입력, 대시 입력을 프레임마다 읽고 네 단계를 넘긴다. 실제 이동 거리, 공격 실행, 대시 시작, 지도 확대 같은 도메인 성공 신호가 없다. 강공격만 `power_attack_executed` 신호를 사용한다.

### 패링은 존재하지만 학습과 보상이 없다

배트 스윙은 늑대의 `parry_dash()`를 호출하지만 반환값을 버린다. 성공 여부가 플레이어, 세션, UI로 전달되지 않는다. 현재 성공 피드백은 늑대 회복 상태와 햅틱뿐이며, Web 사용자가 인지할 텍스트·히트스톱·플래시·전용음이 없다.

## 경험 설계

### 1. 밤 인트로

각 문장은 다음 조건 중 먼저 충족되는 경로로 진행한다.

1. 음성이 정상 재생되면 음성 종료 후 `0.35초`가 지나 자동 진행한다.
2. Web autoplay 제한 등으로 음성이 시작되지 않으면 자막 노출 후 `2.2초`가 지나 자동 진행한다.
3. 음성이 비정상적으로 끝나지 않아도 자막 노출 후 `4.0초`가 지나면 강제 진행한다.
4. 사용자의 클릭/탭은 음성을 끊지 않고, 음성 종료 후의 대기만 즉시 끝내는 가속 입력이다.

시각 계약은 다음과 같다.

- 게임 시작 후 `1.0초` 안에 배경 플레이트 또는 첫 자막 중 하나가 읽을 수 있는 알파로 나타난다.
- 현재 음성 8개의 합계 `14.88초`를 기준으로, 정상 재생과 autoplay 차단 경로는 아무 입력 없이 `30초` 안에 세션으로 넘어간다. 모든 음성이 고착되는 비정상 경로도 `45초` 안에 끝난다.
- PC는 `클릭하여 계속`, 모바일 Web/native mobile은 `탭하여 계속`을 표시한다.
- `건너뛰기` 버튼은 전체 인트로 동안 사용할 수 있고 한 번만 종료 신호를 보낸다.
- 비트 사이에 완전한 검은 화면만 `1.5초` 넘게 유지하지 않는다.

### 2. 첫 런의 기본 조작

첫 방은 다음 여섯 역량을 순서대로 안내한다.

| 순서 | 역량 | PC 안내 | 터치 안내 | 완료 증거 |
|---|---|---|---|---|
| 1 | 이동 | `WASD로 96px 이동` | `왼쪽 스틱으로 이동` | 시작 위치 대비 누적 실제 이동 거리 `>=96px` |
| 2 | 기본공격 | `좌클릭으로 공격` | `공격 버튼으로 공격` | 플레이어의 `attack_executed` 성공 신호 |
| 3 | 대시 | `SPACE로 대시` | `대시 버튼으로 회피` | 플레이어의 `dash_started` 성공 신호 |
| 4 | 강공격 | `SPACE 직후 좌클릭` | `대시 직후 공격 버튼` | 기존 `power_attack_executed` 신호 |
| 5 | 지도 | `오른쪽 위 지도를 클릭` | `오른쪽 위 지도를 탭` | `_minimap_full == true` 전환 이벤트 |
| 6 | 출구 | `열린 문으로 이동` | 동일 | `room_entered`가 첫 전투방을 가리킴 |

첫 방의 출구는 1~5번이 끝나기 전에는 잠긴 이유를 화면에 설명한다. 진행 불가 상태를 만들지 않도록 `안내 건너뛰기`를 5초 뒤에 노출하며, 누르면 해당 세션의 출구 잠금과 단계 UI를 즉시 해제한다. 건너뛴 역량은 성공으로 기록하지 않으며, 그 세션 동안 화면 좌측에 compact 조작표를 유지한다.

### 3. 첫 런의 실제 여정

기본 조작 카드가 끝난 뒤에는 화면 중앙 툴팁을 계속 띄우지 않는다. 실제 사건이 발생할 때 짧은 목표 카드와 대상 스포트라이트를 사용한다.

| 맥락 | 안내 | 완료 증거 |
|---|---|---|
| 첫 전투 승리 | `적을 쓰러뜨리면 방이 열린다` | 첫 `room_cleared` |
| 첫 보상 | `카드 하나를 골라 이번 탐험을 강화` | 기존 `reward_choice_selected` |
| 친구 조우 | `공격해 기절시킨 뒤 가까이 다가가 정화` | 기존 groggy 상태와 `friend_purified` |
| 학교 귀환 | PC `[E] 말 걸기`, 모바일 대화 버튼 | `dialogue_requested` 또는 동일 의미의 UAT action |
| 배트 획득 | `배트는 늑대 돌진과 적탄을 받아친다` | 배트 해금 팝업 닫힘 |

보상·정화·대화는 이미 존재하는 신호를 재사용한다. 새 범용 이벤트를 만들기 전에 기존 신호가 의미를 충분히 표현하는지 우선한다.

### 4. 첫 패링 학습

패링 학습은 배트를 받기 전에는 나오지 않는다. `baseball_captain_reward_claimed=true`이고 `parry_tutorial_complete=false`인 첫 정규 런에서 활성화한다. 현재 경복궁 첫 전투방에는 늑대 한 마리가 보장되어 있으므로 별도 튜토리얼 씬이나 적 복제는 필요 없다.

늑대가 처음 `prepare` 상태에 들어가면 짧은 비모달 카드로 다음을 안내한다.

- PC: `늑대가 돌진할 때 좌클릭으로 배트를 휘둘러 받아치기`
- 터치: `늑대가 돌진할 때 공격 버튼으로 배트를 휘둘러 받아치기`

늑대가 일반 공격으로 먼저 죽거나 플레이어가 타이밍을 놓쳐도 방 진행은 계속된다. 완료 플래그는 실제 `parry_dash()`가 `true`를 반환할 때만 기록한다. 성공하지 못하면 다음 늑대의 첫 `prepare`에서 다시 안내한다.

### 5. 패링 성공 피드백

성공 순간의 순서는 고정한다.

1. 적과 플레이어 중간에 `받아쳤다` 텍스트를 생성한다.
2. `HitStopManager.request(0.10, 0.05)`를 호출한다.
3. `combat_feedback(kind=parry, intensity=9.0)`으로 카메라 셰이크와 백색 플래시를 발생시킨다.
4. `parry_success` 전용 SFX와 강한 햅틱을 재생한다.
5. `parry_succeeded` 이벤트와 온보딩 완료 플래그를 기록한다.

플로팅 텍스트는 동시 활성 `20개`를 상한으로 한다. 패링 텍스트는 `32pt`, 청록 또는 백색 발광, 상승 `20px`, 지속 `1.0초`, punch scale을 사용한다. 히트스톱보다 먼저 생성해 정지 화면에서 읽히게 한다.

`HitStopManager`는 `PROCESS_MODE_ALWAYS`로 실행하고, 세션 종료·재시작·씬 전환에서 `Engine.time_scale=1.0`을 강제로 복구한다.

## 코드 구조

### 플랫폼 문구 정책

`scripts/ui/input_prompt_policy.gd`를 플랫폼 문구의 단일 진실 공급원으로 둔다.

```gdscript
static func input_mode_from_features(features: Dictionary) -> StringName
static func continue_hint(input_mode: StringName) -> String
static func action_hint(action: StringName, input_mode: StringName) -> String
```

`input_mode_from_features`는 `mobile`, `web_android`, `web_ios`만 터치 기본 모드로 판단한다. 터치스크린 가용성만으로 PC를 모바일로 분류하지 않는다.

### 인트로 진행 정책

`NightIntroCutscene`은 시간 계산을 순수 함수로 분리한다.

```gdscript
static func should_advance_line(
    narration_started: bool,
    narration_playing: bool,
    elapsed: float,
    user_requested: bool
) -> bool
```

런타임 코루틴은 이 함수의 결과만 소비한다. 단위 테스트는 음성 정상, autoplay 차단, 고착 음성, 조기 클릭을 각각 검증한다.

### 온보딩 성공 이벤트

플레이어에 다음 신호를 추가한다.

```gdscript
signal attack_executed(payload: Dictionary)
signal dash_started(payload: Dictionary)
signal parry_succeeded(payload: Dictionary)
```

`attack_executed`는 실제 공격 루틴이 시작된 뒤 한 번, `dash_started`는 charge 소비와 대시 상태 진입이 성공한 뒤 한 번 발생한다. `parry_succeeded`는 늑대의 반환값이 `true`일 때만 발생한다.

`SessionUIRoot` 또는 minimap controller는 확대 상태 변경 신호를 노출한다.

```gdscript
signal minimap_expanded_changed(expanded: bool)
```

### 화면별 책임

- `NightIntroCutscene`: 자동 진행, 플랫폼별 계속 문구, 스킵.
- `IngameControlOnboarding`: 첫 방의 이동·공격·대시·강공격·지도·출구 단계.
- `SessionRoot`: 보상·정화·패링 학습의 맥락 연결과 세션 정리.
- `DayCorridor`: 말 걸기와 배트 획득 안내.
- `ParryFeedbackController`: 텍스트·히트스톱·플래시·SFX·햅틱의 표현 순서.
- `SaveManager`: `parry_tutorial_complete` 한 번성 플래그. 첫 방 조작 상태는 해당 세션 안에서만 유지한다.

별도 전역 `OnboardingManager`는 만들지 않는다. 현재 여정은 씬별 도메인 신호로 충분하며 새 autoload는 수명 주기와 저장 복잡도를 불필요하게 늘린다.

## 첫인상 요구사항 프로그램

온보딩과 패링만 끝내고 전체 명세를 다시 방치하지 않는다. 다음 순서로 독립 계약을 실행한다.

1. 인트로 자동 진행·플랫폼 문구.
2. 첫 방 성공 기반 조작·지도.
3. 보상·정화·말 걸기 여정 통합.
4. 패링 성공 이벤트와 피드백.
5. 포탈 전환 재시도와 온보딩 종료 정리.
6. 실제 웨이브 분할과 악귀 속도 조정.
7. SFX 쿨다운, 누락 전투음, 피격 비네트.
8. 일반 타격 히트스톱과 데미지 숫자.

각 항목은 앞선 계약이 merge된 `origin/main`에서 새 worktree를 만든다. 난이도를 바꾸는 6번은 웨이브와 속도를 별도 이슈로 나누고 각각 Web 플레이를 수행한다.

## 오류와 중단 처리

- 인트로 음성이 시작되지 않아도 fallback timer로 진행한다.
- 온보딩 UI가 제거되거나 씬이 전환되면 모든 신호 연결과 카메라 zoom을 복구한다.
- 일시정지·보상 모달 동안 입력 성공을 기록하지 않는다.
- 지도/HUD 클릭은 공격으로 처리하지 않는다.
- 패링 학습 UI가 사라져도 전투 AI와 방 완료는 정상 작동한다.
- 패링 피드백 중 씬이 끝나면 time scale, 카메라 offset, 화면 flash를 기본값으로 되돌린다.
- 모바일 일반 화면 터치는 공격·대시·대화를 암묵적으로 실행하지 않는다. 지정된 버튼만 성공 이벤트를 만든다.

## 검증 계약

### 자동 테스트

- 인트로 진행 truth table: 음성 정상, autoplay 차단, 음성 고착, 클릭 가속, 스킵 멱등성.
- PC/모바일 continue copy와 모든 action copy.
- 각 온보딩 단계가 잘못된 이벤트로는 진행되지 않고 정확한 성공 이벤트로만 진행됨.
- HUD 클릭 공격 누수와 모바일 mouse emulation guard 유지.
- 패링 실패는 완료 이벤트를 내지 않고, 성공은 정확히 한 번 낸다.
- 패링 피드백 호출 순서와 `Engine.time_scale` 복구.
- 플로팅 텍스트 활성 20개 상한.
- 포탈 실패 후 overlap 상태에서 재시도.
- 웨이브가 configured count만큼 분할되어 마지막 적 처치 후 다음 wave를 생성.

### Web UAT

- 960x540 PC 새 프로필: 정상 음성과 autoplay 차단 양쪽에서 게임 시작 후 입력 없이 인트로가 30초 안에 끝남. 모든 음성 고착 fixture도 45초 안에 끝남.
- 1920x900 PC: 완전 검은 화면만 1.5초 넘게 유지되지 않고 `클릭하여 계속`이 보임.
- 960x540 mobile Web: `탭하여 계속`과 touch controls가 보이고 일반 tap guard 유지.
- 첫 방: 이동→좌클릭→SPACE→SPACE+좌클릭→지도 확대→출구 순서로 실제 상태 전이.
- 학교: PC E와 모바일 대화 버튼으로 대화 시작.
- 배트 획득 후 첫 정규 전투: 늑대 패링 성공 전후 캡처, `받아쳤다`·플래시·회복 상태 확인.
- 모든 경로에서 WebGL2=true, console/page/request error 0.

### 프로젝트 게이트

- `bash scripts/verify_quick.sh`
- 넓은 전투/세션 변경에서는 `bash scripts/verify_full.sh`
- UI 변경 PR은 `ui-previews/pr-<PR>/...` raw 이미지 계약 통과
- ready PR, assignee, milestone, P0/P1, `area:*` labels, Korean title/body/commit
- Codex 1회 이상, 모든 thread 답변·해결, 최신 CI green 후 즉시 merge

## PR 분할

| 순서 | 계약 | 권장 area |
|---|---|---|
| 1 | 인트로 자동 진행과 계속 문구 | `area:ui` |
| 2 | 첫 방 성공 기반 조작과 지도 | `area:ui`, `area:player` |
| 3 | 보상·정화·말 걸기 여정 | `area:ui`, `area:session` |
| 4 | 패링 성공 이벤트 | `area:player`, `area:enemy` |
| 5 | 패링 시청각 피드백 | `area:combat`, `area:audio`, `area:ui` |
| 6 | 포탈·온보딩 종료 안정성 | `area:session` |
| 7 | 웨이브와 적 속도 | 각각 별도 `area:room`/`area:enemy` |
| 8 | 전투 SFX·비네트·일반 히트스톱·데미지 숫자 | 기능별 별도 PR |

## 완료 정의

- 위 Web UAT에서 신규 사용자가 별도 설명 없이 첫 런과 학교 대화를 끝낸다.
- 배트 획득 후 실제 패링 성공을 인지하고 동일 행동을 재현할 수 있다.
- 첫 3~5분에 노출되는 안내 문구가 플랫폼 입력과 일치한다.
- 인트로, 온보딩, 패링 어느 것도 클릭 누락·음성 autoplay·실패 행동으로 soft-lock되지 않는다.
- coverage 장부의 `실행 대상` 항목이 모두 merge evidence를 갖는다.
- 남은 전체 명세는 상태·근거·후속 이슈가 없어지는 항목 없이 추적된다.
