# Pull Request Hygiene

Use this checklist before opening a PR and again before marking it ready.

## Language (언어)

PR 제목·본문과 커밋 메시지는 **한글로 작성**한다.

- `[Area]` 태그, 코드 식별자, 파일 경로, 명령어, 라벨 이름은 영문 그대로 둔다.
- 그 외 요약·설명·체크리스트 텍스트는 한글로 쓴다.
- 영문으로만 작성된 PR/커밋은 리뷰 전에 한글로 고친다.

## Title

Format:

```text
[Area] 한글 요약
```

Use one primary area prefix:

- `[UI]` for visible scene, layout, control, or interaction changes
- `[Docs]` for README, guide, or contributor documentation changes
- `[Harness]` for verification scripts, test runners, or agent workflow changes
- `[CI]` for GitHub Actions and required status checks
- `[Scene]` for scene tree or scene transition structure
- `[Autoload]` for boot services and global runtime contracts
- `[Interaction]` for interaction dispatch and pooled object behavior
- `[Assets]` for committed source assets and import metadata
- `[Config]` for project settings, export presets, or example config

When a PR crosses multiple areas, choose the prefix for the user-visible or highest
risk part of the diff. Let labels carry the secondary areas.

Examples:

```text
[Docs] 첫 시간 작업 흐름 명확화
[UI] 세션 요약 컨트롤 추가
[Harness] 임포트 메타데이터 가드 추가
[CI] main에 quick verification 필수화
```

## Metadata

Set these before asking for review:

- Assignee: the person or agent responsible for landing the PR
- Milestone: the current delivery slice
- Priority label: `p0`, `p1`, or `p2`
- Area label: at least one `area:*` label
- Optional labels: `agent-ready` or standard GitHub labels

## Body

The PR body should include (한글로):

- linked issue with `Closes #N` when the PR fully resolves it
- 변경 범위 요약
- 검증 명령과 결과
- `[UI]` PR이거나 화면/레이아웃/컨트롤이 보이는 방식으로 바뀌는 PR이면
  `## UI 캡처` 섹션과 캡처 URL
- 알려진 한계 또는 후속 이슈

Also confirm:

- no private project references from the upstream template are copied
- no generated caches, local config, or credentials are tracked
- README, `docs/customizing.md`, `docs/pr-hygiene.md`, and `AGENTS.md` still agree
  with the commands and workflow in the repo

## UI Capture Flow

Visible UI changes must include reviewable screenshots in the PR body. Do not
require an AOS device for every UI PR: use the fastest faithful capture path
available for the changed screen, and reserve AOS 실기기 확인 for device-specific
touch, safe-area, orientation, export, or platform rendering risks.

For UI PRs:

1. Capture the changed screen after local verification. Prefer a deterministic
   scene state and the project landscape viewport (`960x540`) when possible.
2. Store capture files outside the feature branch. Use the orphan branch
   `ui-previews`, under `pr-<PR number>/`.
3. Push the capture commit to `origin/ui-previews`.
4. Add a `## UI 캡처` section to the PR body with the raw image URLs.

Use stable file names so updates replace the same preview path:

```text
pr-177/session-map-tab-960x540.png
pr-177/session-map-tab-paused-960x540.png
```

Raw URL format:

```text
https://raw.githubusercontent.com/0xkkun/seoul-challenge/ui-previews/pr-<PR>/<file>.png
```

Example PR body section:

```markdown
## UI 캡처
- 인게임 맵 탭: https://raw.githubusercontent.com/0xkkun/seoul-challenge/ui-previews/pr-177/session-map-tab-960x540.png
```

Keep screenshots out of the PR branch. If a UI change cannot be captured in the
current environment, say why in `## UI 캡처` and list the closest verification
that was performed.

## Codex Review Signal

After requesting a Codex review, a `👍` reaction from Codex
(`chatgpt-codex-connector[bot]`) on the PR body means there are no requested
changes. If CI is green and there are no outstanding review comments, merge
immediately with `gh pr merge <n> --merge --delete-branch` instead of waiting
for a formal review object.

## Commit Messages (커밋 메시지)

- 제목·본문은 **한글로 작성**한다. 제목은 PR과 같은 `[Area]` 태그로 시작한다.
  - 예: `[Scene] 방 베이스 계약 추가`
- 제목은 명령형 한 줄(약 50자 이내), 본문은 "무엇을·왜"를 한글로 설명한다.
- `[Area]` 태그·코드 식별자·파일 경로·명령어는 영문 그대로 둔다.
- 하나의 커밋은 하나의 논리적 변경만 담는다(혼합 커밋 금지).
