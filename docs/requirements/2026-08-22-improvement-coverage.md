# 2026-08-21 개선 명세 반영 현황

기준 코드: `origin/main@c6a2ac7`  
원문: `/Users/orbit/Downloads/아카이브/요괴뎐_개선안_2026-08-21`  
프로그램 설계: `docs/superpowers/specs/2026-08-22-first-five-minutes-onboarding-design.md`

## 상태 정의

- `완료`: 현재 main과 자동 테스트가 요구 행동을 직접 증명한다.
- `부분`: 기반 코드나 일부 표현만 있고 원문의 완료 조건을 충족하지 않는다.
- `미구현`: 요구 행동이 없거나 현재 코드가 반대 행동을 테스트로 고정한다.
- `보류`: 원문이 명시적으로 후순위로 둔 항목이다. 누락이 아니라 의식적인 대기 상태이며 실행 전 재승인이 필요하다.

## 요약

현재 main에서 확실히 완료된 축은 PC 입력 경로, 데스크톱 터치 UI 비노출, 기본 키 안내, 일부 카메라·햅틱·보상·보물방 기반이다. 첫 3~5분 품질을 결정하는 인트로 자동 진행, 지도 학습, 패링 피드백, 일반 히트스톱, 전투 반응음, 피격 비네트, 실제 웨이브, 포탈 재시도는 미구현 또는 부분 상태다.

## P — PC 대응

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| P1 온보딩 입력 소스 통합 | 완료 | `IngameControlOnboarding._runtime_input_state`, #497 | 성공 이벤트 방식으로 강화 |
| P2 터치 UI 데스크톱 자동 숨김 | 완료 | `touch_controls.gd`, platform feature tests, #497 | 회귀 유지 |
| P3 스포트라이트 좌표 대응 | 부분 | 터치 버튼과 정화 대상은 지원, 외부 minimap target은 미지원 | 첫 방 조작·지도 PR |
| P4 키 조작 안내 | 완료 | 좌클릭·SPACE·E 문구, #499/#501 | 공용 prompt policy로 일원화 |
| P5 마우스 조준 | 보류 | `aim_direction()`은 이동 방향 fallback | 웨이브·난이도 확정 뒤 재승인 |
| P6 미니맵 온보딩 | 미구현 | 온보딩 step에 map 없음, `_minimap_full` 신호 없음 | 첫 방 조작·지도 PR |

## B — 버그

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| B1 포탈 edge 소비 결함 | 미구현 | `check_transition_for_actor()`가 request 실패 전 `_was_actor_overlapping=true` 설정 | 포탈 안정성 PR |
| B2 포탈 레벨 트리거 전환 | 미구현 | point sampling과 entered callback 혼재 | B1 검증 후 필요성 재판정 |
| B3 온보딩 다시하기 원인 판정 | 부분 | 완료 결과 marker test는 있으나 사망/이탈 전체 경로 증거 없음 | 세션 종료 matrix PR |
| B4 marker 일원화 + `finish()` 방어 | 부분 | 완료 path는 marker 기록, 모든 종료 path의 `finish()` 방어 없음 | 포탈·온보딩 종료 안정성 PR |

## L — 레벨 디자인

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| L1 웨이브 스폰 살리기 | 미구현 | `_spawn_next_wave()`가 pending queue 전체를 while loop로 소진; 기존 test가 full spawn을 기대 | 웨이브 PR |
| L2 난이도 티어 3단 분리 | 미구현 | generator의 `>=0.7`과 `>=0.4` config 동일 | 웨이브 플레이 후 별도 PR |
| L3 엘리트 배치 켜기 | 미구현 | layout/generator의 `elite_*_count=0` | L2 뒤 별도 PR |
| L4 스폰 위치 지터 | 미구현 | 고정 factor 배열 기반 | L3 뒤 별도 PR |

## F — 게임필

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| F1 피격 카메라 셰이크 | 부분 | `combat_feedback` 카메라 경로는 있으나 플레이어 `take_damage`가 feedback을 emit하지 않음 | 피격 피드백 PR |
| F2 히트스톱 매니저 | 미구현 | `Engine.time_scale` manager 없음 | 패링 기반 PR |
| F3 일반 타격 히트스톱 | 미구현 | melee feedback은 camera뿐 | 일반 히트스톱 PR |
| F4 패링 성공 연출 | 미구현 | `parry_dash()` bool 반환을 player가 폐기, 햅틱 외 feedback 없음 | 패링 이벤트·피드백 PR |
| F5 넉백 트윈 | 미구현 | player가 적 위치를 즉시 대입 | 후순위 PR |
| F6 적 사망 셰이크·방 클리어 정적 | 미구현 | 공통 death event 없음 | D3 이후 |
| F7 피격 붉은 비네트 | 미구현 | vignette UI/contract 없음 | 피격 피드백 PR |
| F7b 저체력 상시 비네트 | 미구현 | low-health screen state 없음 | F7 뒤 |
| F7c 화면 효과 설정 토글 | 미구현 | settings key/UI 없음 | F7 뒤 |
| F8 효과 동시 조율 | 미구현 | hitstop/vignette/combat SFX 기반 자체가 없음 | 관련 축 merge 뒤 UAT |

## S — 사운드

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| S1 `awakened_bat_reveal.mp3` | 미구현 | registry 경로는 있으나 파일 없음 | 오디오 기반 PR |
| S2 미사용 SFX 3개 배선 | 완료 | 학교 전환·페이지·보상 SFX 호출과 unit tests 존재 | 회귀 유지 |
| S3 `play_sfx` 쿨다운 | 미구현 | 매 호출마다 새 AudioStreamPlayer 생성 | 전투음 선행 PR |
| S4 S급 전투음 | 부분 | 늑대·구미호·배트는 존재, 플레이어/적 피격·적 사망·악귀·맨손 누락 | 전투음 PR |
| S5 볼륨 테이블 | 부분 | override 구조는 있으나 table 비어 있음 | S4와 함께 조정 |
| S6 A급 8개 | 부분 | 일부 방/획득/전환음만 존재 | first-impression 뒤 |
| S7 패링 성공음 | 미구현 | parry SFX id/asset 없음 | 패링 피드백 PR |
| S8 B급 7개 | 미구현 | 요구 목록용 registry/asset 없음 | 후순위 |
| S9 웹 프리로드 | 보류 | 끊김 측정 증거 없음 | 최종 Web 성능 UAT 후 판단 |

## T — 플로팅 텍스트

| ID | 상태 | 현재 근거 | 다음 계약 |
|---|---|---|---|
| T1 floating text + pool | 미구현 | 관련 script/pool 없음 | 패링 피드백 기반 PR |
| T2 활성 20개 cap | 미구현 | T1 없음 | T1과 같은 PR |
| T3 적 데미지 숫자 | 미구현 | enemy damage text 없음 | 일반 전투 피드백 PR |
| T4 설정 토글 | 미구현 | Settings key/UI 없음 | T3과 같은 PR |
| T5 강공격 스타일 | 미구현 | power attack floating text 없음 | T3 뒤 |
| T6 `받아쳤다` | 미구현 | parry event/text 없음 | 패링 피드백 PR |
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
| M6a 악귀 90→140 | 미구현 | `chaser.gd move_speed=90` | 웨이브와 별도 밸런스 PR |
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
| PC `클릭하여 계속` | 미구현 | night intro와 dialogue가 `탭해서 계속` 고정 | 인트로·prompt policy PR |
| 인트로 무입력 자동 진행 | 미구현 | `_wait_for_advance()`가 timeout 없이 click만 대기 | 인트로 PR |
| 완전 검은 화면 장기 유지 방지 | 미구현 | black background와 첫 plate/subtitle fade 사이 공백 | 인트로 PR + 1920x900 UAT |
| 성공 기반 전체 온보딩 | 부분 | raw input 4단계, reward/purify hints는 분산 | 첫 방·여정 PR |
| 패링 안내와 성공 학습 | 미구현 | 안내·성공 signal 없음 | 패링 이벤트·피드백 PR |
| 요구사항 추적 | 이 문서로 시작 | 이전에는 mapping 없음 | 모든 하위 이슈/PR에 이 표 갱신 |

## 승인된 실행 큐

아래 순서는 `A 승인`으로 실행이 확정된 첫인상 프로그램이다. 각 행은 독립 이슈·worktree·PR로 끝낸다.

| 순서 | 포함 요구 | 완료 증거 |
|---|---|---|
| Q1 인트로·계속 문구 | 새 피드백: 자동 진행, 검은 공백, 클릭/탭 분기 | PC/mobile Web 무입력 timing UAT |
| Q2 첫 방·첫 런 여정 | P3, P6, 성공 기반 이동·공격·대시·강공격·지도·보상·정화·말 걸기 | 신호 기반 unit/integration + 전체 journey UAT |
| Q3 패링 학습·성공 피드백 | F2, F4, S7, T1, T2, T6 | 첫 늑대 실제 parry UAT와 복구 테스트 |
| Q4 안정성 | B1, B3, B4 | 포탈 pause-overlap 재시도와 종료 matrix |
| Q5 전투 흐름 | L1 | configured wave별 spawn 테스트와 Web play |
| Q6 적 압박 | M6a | 악귀 단독 변경 전후 encounter UAT |
| Q7 전투 반응 | S1, S3, S4, F7 | cooldown·asset·피격 시청각 테스트와 Web UAT |
| Q8 일반 타격 정보 | F3, T3, T4 | hitstop 복구·20 cap·설정 토글 테스트 |

## 장부 유지 규칙

1. 하위 이슈를 만들 때 해당 행의 `다음 계약`에 이슈 번호를 기록한다.
2. PR을 merge할 때 상태를 갱신하고 merge commit, 테스트, UAT 증거를 적는다.
3. `부분`을 `완료`로 바꿀 때는 사용자에게 보이는 동작과 자동 회귀 테스트가 모두 있어야 한다.
4. 보류 항목은 삭제하지 않는다. 재승인 또는 의존성 충족 근거를 기록한다.
5. 문서 원문의 사실과 사용자 후속 결정이 충돌하면 후속 결정을 우선하고 충돌을 행 근거에 남긴다.
