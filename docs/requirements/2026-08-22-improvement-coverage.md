# 2026-08-21 개선 명세 반영 현황

기준 코드: `origin/main@1743c36` + #524 검증 대상
사용자 제공 자료: `요괴뎐_개선안_2026-08-21`
프로그램 설계: `docs/superpowers/specs/2026-08-22-first-five-minutes-onboarding-design.md`
시각 재설계: `docs/superpowers/specs/2026-08-22-onboarding-coachmark-redesign.md`

## 상태 정의

- `완료`: 현재 main과 자동 테스트가 요구 행동을 직접 증명한다.
- `부분`: 기반 코드나 일부 표현만 있고 원문의 완료 조건을 충족하지 않는다.
- `미구현`: 요구 행동이 없거나 현재 코드가 반대 행동을 테스트로 고정한다.
- `보류`: 원문이 명시적으로 후순위로 둔 항목이다. 누락이 아니라 의식적인 대기 상태이며 실행 전 재승인이 필요하다.

## 요약

현재 검증 대상에서 확실히 완료된 축은 PC 입력 경로, 데스크톱 터치 UI 비노출, bounded 인트로, 성공 기반 첫 방 6단계, 보상→정화→학교 대화 contextual 여정, 반복 가능한 패링 학습, 기본 키 안내, 공통 coachmark·objective ribbon·reward eyebrow, 패링 성공 연출, 포탈 실패 재시도와 세션 종료 cleanup, 실제 순차 웨이브, 악귀 추적 압박, 쿨다운 기반 일반 전투 반응음, 피격·저체력 비네트, 일부 카메라·햅틱·보상·보물방 기반이다. 일반 타격 히트스톱은 아직 미구현 상태다.

## P — PC 대응

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| P1 온보딩 입력 소스 통합 | 완료 | `IngameControlOnboarding._runtime_input_state`, #497 | 성공 이벤트 방식으로 강화 |
| P2 터치 UI 데스크톱 자동 숨김 | 완료 | `touch_controls.gd`, platform feature tests, #497 | 회귀 유지 |
| P3 스포트라이트 좌표 대응 | 완료 | 터치 버튼·정화 대상·외부 minimap target #507; corner bracket·safe clamp #513 | 대상 없는 exit와 modal 복원 회귀 유지 |
| P4 키 조작 안내 | 완료 | 좌클릭·SPACE·E 문구와 `InputPromptPolicy`, #499/#501/#505 | 후속 copy 회귀 유지 |
| P5 마우스 조준 | 보류 | `aim_direction()`은 이동 방향 fallback | 웨이브·난이도 확정 뒤 재승인 |
| P6 미니맵 온보딩 | 완료 | `minimap_expanded_changed`, map→exit gate, desktop/mobile Web, #507 | emulated touch+mouse pair 회귀 유지 |

## B — 버그

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| B1 포탈 edge 소비 결함 | 완료 | #516에서 request 성공 후에만 latch 소비; pause-overlap 실패→actor 이동 없는 재시도→성공 1회 unit·release Web test | 회귀 유지 |
| B2 포탈 레벨 트리거 전환 | 미구현 | point sampling과 entered callback 혼재 | B1 검증 후 필요성 재판정 |
| B3 온보딩 다시하기 원인 판정 | 완료 | #516 completion·death가 latch 기반 `onboarding_kind`를 보존하고 retry UI 판정에 사용 | 결과 copy 회귀 유지 |
| B4 marker 일원화 + `finish()` 방어 | 완료 | #516 `_finish_all_onboarding_ui()`가 완료·사망·포기·retry·return·scene exit를 멱등 정리 | 새 종료 경로 추가 시 matrix 확장 |

## L — 레벨 디자인

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| L1 웨이브 스폰 살리기 | 완료 | #518 ceiling partition 6/2→3+3·5/2→3+2, final wave 전 clear 금지, 모든 `enemy_spawned` 1회 | authored combat_2 Web 회귀 유지 |
| L2 난이도 티어 3단 분리 | 미구현 | generator의 `>=0.7`과 `>=0.4` config 동일 | 웨이브 플레이 후 별도 PR |
| L3 엘리트 배치 켜기 | 미구현 | layout/generator의 `elite_*_count=0` | L2 뒤 별도 PR |
| L4 스폰 위치 지터 | 미구현 | 고정 factor 배열 기반 | L3 뒤 별도 PR |

## F — 게임필

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| F1 피격 카메라 셰이크 | 부분 | `combat_feedback` 카메라 경로는 있으나 플레이어 `take_damage`가 feedback을 emit하지 않음 | 피격 피드백 PR |
| F2 히트스톱 매니저 | 완료 | `HitStopManager` longer-wins·실시간 복구·종료 복구, #512 unit/session teardown tests | 일반 타격 연결 시 회귀 유지 |
| F3 일반 타격 히트스톱 | 미구현 | melee feedback은 camera뿐 | 일반 히트스톱 PR |
| F4 패링 성공 연출 | 완료 | #510의 실제 `parry_succeeded`에 #512가 `텍스트→히트스톱→플래시→셰이크→SFX→햅틱` 고정 순서 연결 | 실전 encounter 회귀 유지 |
| F5 넉백 트윈 | 미구현 | player가 적 위치를 즉시 대입 | 후순위 PR |
| F6 적 사망 셰이크·방 클리어 정적 | 미구현 | 공통 death event 없음 | D3 이후 |
| F7 피격 붉은 비네트 | 완료 | #524 실제 Player damage 감소에서 edge pulse, heal/setting/pause/exit lifecycle 회귀 | 일반 hitstop과 동시 조율 유지 |
| F7b 저체력 상시 비네트 | 완료 | #524 `current/max <= 0.25` persistent edge, heal 해제·setting 재계산 | max-health modifier 회귀 유지 |
| F7c 화면 효과 설정 토글 | 완료 | #524 full settings snapshot·즉시 tween cancel·5행 mobile-safe SettingsUI | 새 screen effect가 같은 key를 준수 |
| F8 효과 동시 조율 | 미구현 | hitstop/vignette/combat SFX 기반 자체가 없음 | 관련 축 merge 뒤 UAT |

## S — 사운드

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| S1 각성 배트 공개음 | 완료 | #522 `awakened_bat_reveal.wav` 실파일·registry·팝업→보상 순서 회귀 | 리소스 누락 fallback 유지 |
| S2 미사용 SFX 3개 배선 | 완료 | 학교 전환·페이지·보상 SFX 호출과 unit tests 존재 | 회귀 유지 |
| S3 `play_sfx` 쿨다운 | 완료 | #522 ID별 cooldown·boundary·reset·0 override; accepted play만 기록/player 생성 | 새 반응 ID는 table entry 필수 |
| S4 S급 전투음 | 완료 | #522 player/enemy hit·enemy death·악귀 attack·맨손 swing 실파일과 accepted/rejected event wiring | D3 공통 death event 전까지 enemy-local 1회 유지 |
| S5 볼륨 테이블 | 완료 | 모든 registered SFX가 명시적 유한 `[-24,6]dB` entry; deterministic multi mix -5.9dBFS, reaction mix -2.4dBFS | 신규 ID 누락 금지 |
| S6 A급 8개 | 부분 | 일부 방/획득/전환음만 존재 | first-impression 뒤 |
| S7 패링 성공음 | 완료 | `parry_success.wav`·`AudioManager.PARRY_SUCCESS`, 스윙→패링→타격 순서 test, #512 | 볼륨 table 통합 시 회귀 유지 |
| S8 B급 7개 | 미구현 | 요구 목록용 registry/asset 없음 | 후순위 |
| S9 웹 프리로드 | 보류 | 끊김 측정 증거 없음 | 최종 Web 성능 UAT 후 판단 |

## T — 플로팅 텍스트

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| T1 floating text + pool | 완료 | `FloatingCombatText`와 `PoolManager` warm/release/reset/generation guard, #512 | 일반 데미지 숫자 재사용 |
| T2 활성 20개 cap | 완료 | 사전 준비 20개·21번째 거절·반복 Web UAT `text_count=20`, #512 | 다종 텍스트 합산 cap 설계 |
| T3 적 데미지 숫자 | 미구현 | enemy damage text 없음 | 일반 전투 피드백 PR |
| T4 설정 토글 | 미구현 | Settings key/UI 없음 | T3과 같은 PR |
| T5 강공격 스타일 | 미구현 | power attack floating text 없음 | T3 뒤 |
| T6 `받아쳤다` | 완료 | 패링 접점 중점에 32pt cyan/white glow·1.0초·20px rise, #512 | 실전 가독성 회귀 유지 |
| T7 플레이어 피격 숫자 | 미구현 | player damage text 없음 | 피격 피드백 PR |

## D — 사망 연출

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| D3 공통 `enemy_died` event | 미구현 | 네 enemy script가 death fade를 직접 생성 | 사망 시스템 선행 PR |
| D1 death fade 풀링 | 미구현 | 매 사망마다 `EnemyDeathFade.new()` | D3 뒤 |
| D2 모션 3종 | 미구현 | 단일 fade motion | D1 뒤 |
| D4 보스 전용 사망 연출 | 부분 | boss도 generic death fade 사용 | D3 뒤 |

## R — 보상 다양성

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| R1 seeded·보유 제외 선택 | 부분 | room id hash로 시작 위치는 결정하지만 run seed·보유 제외는 없음 | 보상 알고리즘 PR |
| R2a `fire_cooldown_mult` 복구 | 미구현 | catalog base/effect order에 축 없음 | 보상 축 PR |
| R2b 아이템 12개 | 미구현 | room reward item 7개 | R2a 뒤 |
| R3 희귀도·진행도 가중 | 미구현 | item rarity 모델 없음 | 아이템 확장 뒤 |
| R4 tradeoff 최소 1개 | 미구현 | choice composition guard 없음 | R3와 함께 |
| R6 배지·대가 적색·획득 text | 미구현 | reward card style에 rarity/tradeoff 표시 없음 | T1 뒤 |
| R5 방 타입별 차등 | 보류 | 범위 큼 | 이벤트/상점 계약 승인 후 |

## M — 맵·탐험

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| M6a 악귀 90→140 | 완료 | #520에서 기본·AkGwi scene 140, 첫 야구부장 전투만 명시적 92; regular/teaching 실스폰·접촉 시간 회귀 | 일반 방 override 누락과 온보딩 92 예외 회귀 유지 |
| M1a treasure index 복구 | 완료 | authored layout에 `treasure_1` 존재 | 회귀 유지 |
| M1b 보물방 scene 배선 | 완료 | `treasure_room.tscn` 사용 | 회귀 유지 |
| M3a 클리어 시간 측정 | 미구현 | run duration 계측 없음 | 맵 밸런스 PR |
| M3b 방 수 14~18 변동 | 미구현 | session constant room count | M3a 뒤 |
| M3c 전투 9·특수 3 재배분 | 미구현 | generator 배치 계약 없음 | M3a 뒤 |
| M6b 늑대 108→125 | 미구현 | `wolf.gd move_speed=108` | 패링 UAT 뒤 재판정 |
| M5a 이벤트방 선택지 | 미구현 | 생성 layout에서 event/shop disabled | 후순위 승인 필요 |
| M5b 보물방 복수 배치 | 미구현 | authored 1개, generated path 제한 | M3 뒤 |
| M5c 상점 | 보류 | generated session에서 제거됨 | 통화 loop 승인 후 |

## 새 사용자 피드백

| 항목 | 상태 | 현재 근거 | 실행 계약 |
|---|---|---|---|
| PC 계속 안내 | 완료 | #505의 클릭/탭 분기 뒤 #513 승인으로 `LMB  계속` / `탭  계속` key chip 적용 | bounded intro와 PC/mobile Web 캡처 |
| 인트로 무입력 자동 진행 | 완료 | 정상·autoplay 차단·음성 고착에 bounded line scheduling 적용, #505 | blocked 24,753ms·stuck 39,121ms Web UAT |
| 완전 검은 화면 장기 유지 방지 | 완료 | plate 초기 alpha와 transition 단축, #505 | 960x540·1920x900 release Web UAT |
| 성공 기반 전체 온보딩 | 완료 | 첫 방 6단계·실제 action/minimap/room transition은 #507, reward/purify/talk·PC E/mobile prompt는 #509 | Task 2·3 release Web UAT와 자동 회귀 유지 |
| 패링 안내와 성공 학습 | 완료 | #510의 `enemy_spawned`·`dash_state_changed`·`parry_succeeded`, miss/death/next-wolf/success lifecycle tests | Task 5가 성공 시청각 피드백을 추가 |
| 온보딩 시각 품질 | 완료 | #513/#514의 공통 token/coachmark, corner bracket, objective ribbon, reward eyebrow, reduced-motion toggle | merge `e424012`; release Web 12 mode, Design C→A, AI slop C→A |
| 요구사항 추적 | 이 문서로 시작 | 이전에는 mapping 없음 | 모든 하위 이슈/PR에 이 표 갱신 |

## 승인된 실행 큐

아래 순서는 `A 승인`으로 실행이 확정된 첫인상 프로그램이다. 각 행은 독립 이슈·worktree·PR로 끝낸다.

| 순서 | 포함 요구 | 완료 증거 |
|---|---|---|
| Q1 인트로·계속 문구 (완료) | 새 피드백: 자동 진행, 검은 공백, 클릭/탭 분기 | #504/#505, merge `0e87117`; blocked 24,753ms·stuck 39,121ms, UI 캡처 3개, CI·Codex 통과 |
| Q2 첫 방·첫 런 여정 (완료) | P3, P6, 이동·공격·대시·강공격·지도·출구 #507; 보상·정화·말 걸기 #509 | Task 2 merge `5a4f667`; Task 3 merge `31f8ba1`; PC/mobile journey UAT |
| Q2b 온보딩 시각 재설계 (완료) | #513에서 첫 조작·objective·reward·정화·패링·인트로를 diegetic coachmark로 통일 | #513/#514 merge `e424012`; unit 544/544, integration 116/116, release Web 12 mode, Design C→A |
| Q3 패링 학습·성공 피드백 (완료) | #510에서 반복 가능한 첫 늑대 학습 완료; #512에서 F2, F4, S7, T1, T2, T6 완성 | #510/#511 merge `76301ed`; #512/#515 merge `ab2ec465`; coverage 100%, release Web 5상태 UAT |
| Q4 안정성 (완료) | #516에서 B1, B3, B4 구현 | #516/#517 merge `839281ec`; unit 560/560, integration 125/125, coverage 100%, release Web 5상태 |
| Q5 전투 흐름 (완료) | #518에서 L1 구현 | #518/#519 merge `040276e`; 6/2·5/2 partition, failed-batch recovery, authored combat_2 release Web UAT |
| Q6 적 압박 (완료) | #520에서 M6a 구현 | #520/#521 merge `5d8bb48`; 일반 140·온보딩 92, 첫 접촉 1.717s/2.617s, keyboard 99.4px·touch 96.6px 무피격 회피 |
| Q7 전투 반응 (진행 중) | #522에서 S1, S3, S4, S5, #524에서 F7/F7b/F7c 구현 | cooldown·volume·damage/critical/settings tests와 release Web mix·vignette UAT |
| Q8 일반 타격 정보 | F3, T3, T4 | hitstop 복구·20 cap·설정 토글 테스트 |

## 병합 근거

| 작업 | 이슈 / PR | merge | 자동 검증 | UAT |
|---|---|---|---|---|
| Task 1 인트로 자동 진행·플랫폼 안내 | #504 / #505 | `0e87117` | unit 526/526, integration 107/107, quick/full, 최신 CI green, Codex 👍 | release WebGL2 PC 960x540·1920x900/mobile 960x540; blocked 24,753ms, stuck 39,121ms; console error 0 |
| Task 2 성공 기반 첫 방 조작·지도 | #506 / #507 | `5a4f667` | unit 531/531, integration 109/109, quick/full, PR UI capture·Quick·Rooms·Web Preview green, Codex P1 해결 + 👍 | release WebGL2 PC/mobile 6단계→첫 전투방, PC/mobile skip→compact legend; console/page/request error 0 |
| Task 3 첫 런 보상·정화·대화 안내 | #508 / #509 | `31f8ba1` | unit 532/532, integration 111/111, quick/full, PR UI capture·Quick·Rooms·Web Preview green, Codex major issue 0 + 👍 | 실제 PC combat→reward→friend→purify intro, deterministic PC/mobile groggy·talk·bat popup; WebGL2=true, error 0 |
| Task 4 첫 늑대 패링 학습 | #510 / #511 | `76301ed` | unit 535/535, integration 115/115, quick/full, PR UI capture·Quick·Rooms·Web Preview green, Challenger/Codex issue 0 | release WebGL2 PC/touch prepare, miss, next-wolf retry, success; console/network error 0 |
| Task 4b 온보딩 코치마크 시각 재설계 | #513 / #514 | `e424012` | unit 544/544, integration 116/116, quick/full, PR UI capture·Quick·Rooms·Web Preview green, Challenger/Codex issue 0 + 👍 | release WebGL2 12 mode, Design C→A, AI slop C→A, console error 0 |
| Task 5 패링 성공 피드백 | #512 / #515 | `ab2ec465` | unit 559/559, integration 120/120, functional 1/1, coverage 100%, PR UI capture·Quick·Rooms·Web Preview green, Codex P2 RED→GREEN + latest-head major issue 0 | release WebGL2 before/impact/recovery/repeated/teardown; impact camera `(-7, 0)`, console/network error 0 |
| Task 6 포탈 재시도·온보딩 종료 정리 | #516 / #517 | `839281ec` | unit 560/560, integration 125/125, functional 1/1, coverage 100%, PR UI capture·Quick·Rooms·Web Preview green, Challenger 0, Codex latest-head major issue 0 | release WebGL2 portal blocked/retry·death before/after·next session; console/network error 0 |
| Task 7 실제 순차 전투 웨이브 | #518 / #519 | `040276e` | unit 565/565, integration 125/125, performance 5/5, quick/full, latest-head CI·Codex green | release WebGL2 wave one/two/cleared; 3+3 spawn event 보존, console/network error 0 |
| Task 8 악귀 추적 압박 | #520 / #521 | `5d8bb48` | unit 568/568, integration 126/126, performance 5/5, functional 1/1, quick/full, latest-head CI·Codex green | release WebGL2 PC 1280x720/mobile 960x540; 일반 1.717s·온보딩 2.617s 첫 접촉 health 4; physical keyboard 99.4px·touch drag 96.6px full-health 회피; console/network error 0 |
| Task 9 전투 반응음·쿨다운 | #522 / #523 | `1743c36` | unit 577/577, integration 126/126, functional 1/1, quick/full, Codex P2 gesture gate 해결·latest-head CI green | release WebGL2 gesture 전 WAITING/READY 없음→gesture 후 multi-hit 3체/accepted 3/player 3, reaction mix player 3; deterministic -5.9/-2.4dBFS, console/network error 0 |
| Task 10 플레이어 피격 비네트 | #524 / #525 | 검증 대상 | unit 582/582, integration 127/127; damage/heal/critical/off-on/pause/exit·max-health reset·실시간 fade·full payload·signal lifecycle 회귀 | release WebGL2 11 mode valid; fade midpoint alpha 0.258·pause 후 alpha 0·max reset pulse false; layer5/mouse-ignore, settings actual rect safe, console/network error 0 |

## 장부 유지 규칙

1. 하위 이슈를 만들 때 해당 행의 `다음 계약`에 이슈 번호를 기록한다.
2. PR을 merge할 때 상태를 갱신하고 merge commit, 테스트, UAT 증거를 적는다.
3. `부분`을 `완료`로 바꿀 때는 사용자에게 보이는 동작과 자동 회귀 테스트가 모두 있어야 한다.
4. 보류 항목은 삭제하지 않는다. 재승인 또는 의존성 충족 근거를 기록한다.
5. 문서 원문의 사실과 사용자 후속 결정이 충돌하면 후속 결정을 우선하고 충돌을 행 근거에 남긴다.
