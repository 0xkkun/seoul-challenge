# 방과후 요괴뎐 — After School Yokai

> 서울 인디게임 챌린지 48시간 해커톤 출품작<br>
> Godot 4.6 기반 모바일 landscape 액션 로그라이크 MVP

[![Play on itch.io](https://img.shields.io/badge/Play-itch.io-fa5c5c?logo=itchdotio&logoColor=white)](https://ferv0r2.itch.io/afterschool)

<p align="center">
  <a href="https://ferv0r2.itch.io/afterschool">
    <img src="docs/assets/afterschool-itch-qr.svg" alt="방과후 요괴뎐 itch.io QR code" width="180" />
  </a>
</p>

<p align="center">
  <strong>플레이 링크:</strong> <a href="https://ferv0r2.itch.io/afterschool">https://ferv0r2.itch.io/afterschool</a>
</p>

## 소개

**방과후 요괴뎐**은 서울의 학교와 밤의 경복궁을 오가는 16비트 픽셀아트 액션 로그라이크입니다.
낮에는 학교 복도에서 친구와 대화하며 기억 무기를 준비하고, 밤에는 요괴가 들끓는 궁으로 들어가
친구를 정화하고 학생들을 구출합니다.

모바일 기기 배포를 목표로 만들었지만, 개발 중에는 Web 빌드와 GitHub Actions 프리뷰를 적극 활용해
UI/전투/루프 검증 속도를 높였습니다. 실제 모바일 검증은 터치, safe area, 성능, Android export처럼
모바일 특화 리스크를 확인하는 단계로 분리했습니다.

## 장르

- 탑다운 액션 로그라이크
- 트윈스틱 슈터 / 근접 배트 액션
- 낮/밤 구조의 학교 허브 + 궁 런
- 모바일 landscape 픽셀아트 게임

## 스토리라인

> 친구와 쌓은 기억을 들고, 밤의 궁에 갇힌 그 애를 구하러 간다.

무기는 판타지 퇴마구가 아니라 학교에서 쌓은 기억입니다. 비 오는 날 빌린 우산, 마지막 시즌의 배트,
이름이 지워진 학생증 같은 일상의 물건이 밤의 전투력이 됩니다. 낮에 쌓은 관계는 밤의 무기가 되고,
가장 가까웠던 친구는 요괴가 되어 플레이어 앞에 나타납니다.

## 코어 루프

```text
낮: 학교 허브
  └─ 복도 이동, 친구 대화, 기억/무기 해금

야간 준비: 사물함
  └─ 금 간 나무 배트 확인, 강화, 지도 선택

밤: 경복궁 런
  └─ 방 이동, 전투, 학생 구출, 친구 정화, 보스 처치

귀환
  └─ 성공/사망 후 학교로 돌아오고, 해금/성장은 유지
```

## MVP에 들어간 것

- 로비/타이틀/설정 화면
- 낮 학교 복도와 캐릭터 이동
- 친구 대화 UI와 해금 플로우
- 사물함 기반 무기/강화/지도 진입 화면
- 경복궁풍 밤 런과 방 전환
- 전투 HUD, 모바일 터치 조작, safe area 대응
- 야구방망이 근접 공격과 투사체/정화 액션
- 아귀, 구미호, 보스, 요괴화된 친구 등 적/보스 구성
- 학생 구출, 보상, 재화, 귀환/사망 루프
- BGM/SFX, 햅틱, Android/Web export preset
- 자동화 테스트와 GitHub Actions 검증

## 기술 스택

| 영역 | 사용 기술 |
|---|---|
| Engine | Godot `4.6.3.stable.official.7d41c59c4` |
| Language | GDScript |
| Target | Android debug APK, Web export |
| Viewport | `960x540` landscape |
| Rendering | Compatibility renderer, nearest texture filtering |
| UI | Godot Control UI, 모바일 safe-area helper, touch controls |
| CI | GitHub Actions `Verify`, `Web Preview` |
| Testing | Godot headless unit/integration/performance tests |
| Workflow | GitHub Issues/PR 기반 AI-agent 협업 개발 |

## 48시간 개발 기록

개발은 해커톤 시작 후 약 48시간 동안 초집중으로 진행했습니다. 최종 아카이빙 시점 기준 저장소 규모는 다음과 같습니다.

| 지표 | 값 |
|---|---:|
| Git tracked files | 695 |
| Text lines | 48,552 |
| Code lines estimate | 38,340 |
| Commits | 658 |
| Godot scenes | 44 |
| Runtime scripts | 79 |
| Test files | 72 |
| Test functions estimate | 617 |

> 초기 제출 직후 산출 기준으로도 약 489개 파일, 텍스트 31,984줄, 코드성 라인 24,761줄 규모였고,
> 이후 README 정리 시점까지 후속 정리와 품질 보강이 더해졌습니다.

## 실행

```sh
git clone https://github.com/0xkkun/seoul-challenge.git
cd seoul-challenge
godot --path .
```

`godot` 실행 파일이 `PATH`에 없다면 `GODOT_BIN=/path/to/godot` 형태로 검증 스크립트에 넘길 수 있습니다.

## 검증

```sh
bash scripts/verify_quick.sh
bash scripts/verify_full.sh
```

주요 검증 축:

- Godot headless unit/integration tests
- Room/session/play loop contracts
- 모바일 터치/safe-area UI contracts
- Web Preview export contract
- Android export preset sanity checks

## 빌드

### Web

```sh
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```

### Android debug APK

```sh
mkdir -p build/android
godot --headless --path . --export-debug "Android" build/android/afterschool.debug.apk
```

Android 빌드는 로컬 Godot export template, JDK 17, Android SDK, debug keystore 설정이 필요합니다.
자세한 내용은 [`docs/android-build.md`](docs/android-build.md)를 참고하세요.

## 우리가 가져갈 자산

- **모바일 게임도 초반 검증은 Web 빌드가 빠르다.** 실기기는 터치, 성능, safe area, export/SDK 검증에 집중한다.
- **작은 PR과 자동화 테스트가 해커톤 속도에도 맞다.** 기능 단위가 작을수록 AI-agent 병렬 작업과 리뷰가 쉬웠다.
- **장르/스토리/코어 루프를 먼저 고정해야 한다.** 낮 학교 허브와 밤 경복궁 런 구조가 이후 UI/전투/에셋 결정을 빠르게 만들었다.
- **모바일 safe-area는 초반부터 규칙화해야 한다.** 960x540 landscape 기준을 문서/테스트에 넣어 UI 흔들림을 줄였다.

## License / Credits

해커톤 프로토타입 아카이브용 저장소입니다. 외부 공개/재사용 전에는 에셋별 라이선스와 출처를 별도로 확인해야 합니다.
