# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 개요

붕괴: 스타레일 유출(찌라시) 글을 매일 낮 12시·오후 6시에 모아 Claude로 한국어 요약을 만들고, PDF 리포트로 Gmail에 보내는 Windows용 단일 스크립트(`hsr_news.py`)입니다. 같은 리포트를 아이폰 웹앱(Cloudflare Pages + Access)에도 올리고, 10분마다 새 글을 확인해 웹 푸시 알림도 보냅니다(`--alert`). 수집처는 Reddit r/HonkaiStarRail_leaks(RSS)와 아카라이브 붕괴 스타레일 채널의 '찌라시'·'테섭' 게시판(HTML 파싱, 최근 48시간 글만)입니다. 사용자에게 보이는 글, 코드 주석, 로그 메시지, README는 모두 한국어이므로 계속 한국어로 씁니다.

## 명령어

```
pip install -r requirements.txt
python hsr_news.py --dry-run                 # 메일 없이 preview.pdf와 _images/report.html 생성, seen.json은 갱신 안 함
python hsr_news.py --dry-run --ignore-seen   # 이미 보낸 글도 다시 처리 (테스트용)
python hsr_news.py                           # 실제 실행: 웹 배포·메일 발송 후 seen.json 갱신
python hsr_news.py --publish-only            # 수집 없이 site/ 목록·manifest만 다시 만들어 Cloudflare Pages에 배포
python hsr_news.py --alert                   # 실시간 알림 1회 (새 글만 짧게 요약 → site/live/ → 웹 푸시)
python hsr_news.py --test-push               # 구독한 기기에 시험 알림
python hsr_news.py --setup-push              # VAPID 키를 만들어 .env에 추가 (처음 한 번)
powershell -ExecutionPolicy Bypass -File register_task.ps1 [-Time "12:00,18:00"] [-AlertMinutes 10]   # 예약 작업 "HSR News Digest"(12시·18시)와 "HSR Leak Alerts"(10분마다) 등록
```

테스트나 린터는 없습니다. 변경 후에는 `--dry-run`으로 실행해 `preview.pdf`와 `_images/report.html`을 확인합니다. dry-run도 Reddit·아카라이브에 실제로 접속하고 `claude -p`를 호출하므로 몇 분 걸리고 구독 사용량이 차감됩니다. 실행 기록은 `logs/YYYY-MM.log`에 남습니다.

`.env`에는 `GMAIL_ADDRESS`, `GMAIL_APP_PASSWORD`(Gmail 앱 비밀번호)가 필요하고, 선택 항목으로 `MAIL_TO`, `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`, 웹앱용 `CLOUDFLARE_API_TOKEN`(권한: Cloudflare Pages Edit, Workers KV Storage Edit), `CLOUDFLARE_ACCOUNT_ID`, `SITE_URL`, 웹 푸시용 `VAPID_PRIVATE_KEY`·`VAPID_PUBLIC_KEY`를 넣을 수 있습니다.

## 처리 흐름 (`run_digest()` — 정리 리포트)

`main()`은 옵션에 따라 `run_digest()`(기본) 또는 `run_alerts()`(`--alert`)를 부릅니다. 둘은 `run.lock`으로 동시에 돌지 않습니다(정리 리포트는 최대 15분 기다리고, 알림은 잠겨 있으면 그 회차를 건너뜀).


1. **수집** — `fetch_leaks()`(Reddit RSS)와 `fetch_arca()`(게시판 목록 페이지). 한쪽이 실패해도 다른 쪽은 계속 진행합니다. 두 함수는 같은 형태의 항목 dict(`id`, `source`, `board`, `title`, `leaker`, `poster`, 한국 시간 `posted`, `url`, `text`, `media`, `images`, `comments`, `source_links`)를 만들므로 필드를 추가할 때는 양쪽에 모두 넣습니다. ID는 `leaks:` / `arca:` 접두어가 붙고 `seen.json`(최대 1000개)과 대조해 걸러냅니다.
2. **미디어** — `collect_media()`는 매 실행마다 `_images/`를 지우고 새로 만든 뒤 스크린샷(`NN_k.확장자`), 갤러리 첫 장(preview.redd.it 썸네일 → i.redd.it 원본 주소로 바꿈), 영상 프레임(yt-dlp + imageio-ffmpeg)을 받습니다. 아카라이브 글은 `fetch_arca_post()` 한 번의 요청으로 본문·이미지·댓글을 받고, Reddit의 이미지 외 글은 글 RSS에서 상위 댓글과 게시자가 단 원 출처 링크를 받습니다.
3. **요약** — `summarize()`가 이 PC의 Claude Code CLI(`claude -p --model sonnet --tools Read,WebSearch,WebFetch`)를 `cwd=_images/`로 실행합니다. 받은 이미지는 읽을 수 있지만 `.env`에는 접근할 수 없게 하기 위함입니다. 입력은 `PROMPT` + `glossary_text()` + 항목 JSON이고, 출력은 stdout의 첫 `{`부터 마지막 `}`까지를 JSON으로 파싱합니다. 항목별 필드는 `include`, `same_as`, `topic`, `headline`, `origin`, `summary`, `context`이고, 최상위에 `overview`, `glossary`가 있습니다. 요약이 실패하면 원제목으로 대체해 리포트를 만듭니다.
4. **중복 합치기** — `merge_duplicates()`는 `same_as`가 번호가 더 작은 포함 항목을 가리키는 글을 그 항목의 `also` 목록으로 합칩니다(카드 하나에 출처 표가 여러 개 표시됨).
5. **리포트** — `build_report()`가 HTML을 만들고(인라인 `CSS`, `_images/` 기준 상대 경로 `<img src>`), `make_pdf()`가 Microsoft Edge 헤드리스 모드로 PDF로 인쇄합니다.
6. **웹 보관·배포** (실제 실행만) — `publish_report()`가 `archive_report()`로 `site/r/<YYYY-MM-DD_HHMM>/`에 웹용 리포트(`build_report(web=True)`: 아이폰용 메타·`WEB_CSS`·목록 링크)와 `shrink_image()`로 가로 1080px JPEG로 줄인 이미지를 저장하고, `site/reports.json`을 갱신해 `SITE_KEEP_DAYS`(90일)보다 오래된 회차를 지운 뒤 `write_site_shell()`로 날짜별 목록 `index.html`·manifest·아이콘을 다시 만듭니다. 이어 `publish_site()`가 `wrangler pages deploy site --project-name hsr-leaks`로 Cloudflare Pages에 올립니다. 사이트는 Cloudflare Access(이메일 인증)로 잠겨 있습니다. 토큰이 없거나 배포가 실패하면 경고만 남기고 메일은 보냅니다.
7. **발송** — `send_mail()`이 Gmail SMTP SSL로 보냅니다. 배포에 성공하고 `SITE_URL`이 있으면 본문에 회차 웹페이지 링크가 붙습니다. `seen.json`은 실제 발송이 성공한 뒤에만 갱신됩니다. 새 글이 없어도 "새 유출 없음" 메일을 보냅니다.

## 실시간 알림 (`run_alerts()`)

- `alerted.json`(최대 2000개)과 `seen.json`에 없는 글만 대상으로 합니다. `alerted.json`이 없는 첫 실행은 지금 있는 글을 기록만 하고 알리지 않습니다.
- 이미지는 `_alert/`에 받습니다(`WORK_DIR`를 바꿔 씀, 정리 리포트의 `_images/`와 분리). 빨리 끝나도록 영상은 받지 않고(`collect_media(videos=False)`), 댓글은 3개 글까지만 받습니다.
- 요약은 `summarize(prompt=ALERT_PROMPT, tools="Read")`로 웹 검색 없이 합니다. 이름 표기 규칙은 `NAMING_RULES`를 정리 리포트와 같이 씁니다.
- `add_live()`가 알린 글을 `site/live/feed.json`·`live/img/`에 쌓고(최근 `LIVE_KEEP_DAYS`=7일) `live/index.html`(⚡실시간 페이지, 카드에 글 ID 앵커)을 만든 뒤 배포합니다. 카드 HTML은 정리 리포트와 같은 `render_card()`를 씁니다.
- `send_push()`는 `wrangler.toml`의 KV(binding `PUSH`) id로 Cloudflare API에서 `sub:*` 구독을 읽어 pywebpush로 보내고, 404/410이 오면 그 구독을 지웁니다. 3건 이하면 글마다, 더 많으면 묶어서 한 번 보냅니다(`alert_messages()`).
- 구독은 목록 페이지의 '새 유출 알림 켜기'(`PUSH_HTML`) → `functions/api/subscribe.js`(Pages Function) → KV로 저장됩니다. 서비스 워커는 `SW_JS`(`site/sw.js`)이며 알림을 누르면 해당 글 앵커로 엽니다. iOS는 홈 화면에 추가한 앱에서만 웹 푸시를 쓸 수 있습니다(16.4 이상).
- `wrangler pages deploy`는 저장소 루트에서 실행되므로 `functions/`와 `wrangler.toml`(KV 바인딩)이 함께 올라갑니다.

## 유의할 점

- **한국어 표기**: `characters.json`은 HoYoLAB 위키에서 받은 캐릭터 이름(영문 → 한국어 + 운명의 길·속성·등급·세력)을 7일간 저장하는 캐시이며 `fetch_character_names()`가 만듭니다. `FIXED_TERMS`에는 운명의 길·속성·자주 쓰는 게임 용어가 들어 있습니다. 둘 다 프롬프트에 넣어 Claude가 한국 서버 공식 표기를 쓰게 합니다. 사전을 강제로 새로 받으려면 `characters.json`을 지웁니다.
- **요청 제한**: Reddit 요청(yt-dlp 다운로드 포함)은 모두 `reddit_get()` / `reddit_wait()`를 거쳐야 합니다(로그인 없는 요청은 1분 창마다 1번만 허용되므로 응답 헤더 `x-ratelimit-remaining`/`reset`을 보고 창이 풀릴 때까지 대기. yt-dlp 호출 뒤에는 61초 대기). `.env`에 `REDDIT_CLIENT_ID`/`REDDIT_CLIENT_SECRET`이 있으면 `reddit_login()`이 앱 전용 OAuth 토큰을 받고, `fetch_leaks_api()`·`fetch_comments()`가 `oauth.reddit.com`의 JSON API를 씁니다. 이때 영상은 API가 준 `video_url`(v.redd.it 직접 주소)로 받아 yt-dlp를 거치지 않습니다. 토큰이 없거나 API 수집이 실패하면 RSS(`fetch_leaks_rss()`)로 돌아갑니다. 로그인 없는 `www.reddit.com/*.json`은 403으로 막혀 있습니다.. 아카라이브 요청은 `arca_get()`을 거칩니다(3초 대기, 브라우저 UA).
- **정규식 기반 파싱**: 아카라이브 파싱은 특정 class 이름(`vrow column`, `article-content`, `message`)에 의존합니다. 아카라이브 수집 결과가 0건이 되면 먼저 이 부분을 확인합니다.
- **예약 실행 제약**: `pythonw.exe`로 실행되고 실행 시간 제한은 45분입니다. 하위 프로세스는 `CREATE_NO_WINDOW`로 띄우고, `claude` 호출 제한 시간은 1500초입니다. 예약 작업을 실행하는 사용자의 PATH에서 `claude`를 찾을 수 있어야 합니다.
- `_images/`, `_alert/`, `preview.pdf`, `logs/`, `site/`, `alerted.json`, `run.lock`은 실행 결과물입니다. `site/`는 매 실행마다 지우지 않고 쌓아 가는 웹 리포트 보관소이므로 지우면 웹의 지난 회차도 사라집니다. 예약 작업 사용자의 PATH에서 `wrangler`(npm 전역 설치)도 찾을 수 있어야 합니다.
