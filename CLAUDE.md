# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 개요

붕괴: 스타레일 유출(찌라시) 글을 모아 Claude로 한국어 요약을 만들고, 아이폰 웹앱(Cloudflare Pages + Access)과 웹 푸시 알림으로 전하는 Windows용 단일 스크립트(`hsr_news.py`)입니다. 10분마다 새 글만 짧게 알리는 실시간 알림(`--alert`)과, 매일 12시·18시에 배경 설명·용어 풀이까지 붙이는 정리 리포트(기본 실행)가 있습니다. 메일(PDF)은 기본적으로 예비용입니다(`MAIL_MODE`). 수집처는 Reddit r/HonkaiStarRail_leaks(RSS 100개)와 아카라이브 붕괴 스타레일 채널의 '찌라시'·'테섭' 게시판(HTML 파싱)이며 둘 다 최근 48시간 글만 봅니다. 사용자에게 보이는 글, 코드 주석, 로그 메시지, README는 모두 한국어이므로 계속 한국어로 씁니다.

## 명령어

```
pip install -r requirements.txt
python hsr_news.py --dry-run                 # 보내지 않고 preview.pdf와 preview_site/(site/ 복사본에 웹앱 생성) 만들기, seen.json 갱신 안 함
python hsr_news.py --dry-run --ignore-seen   # 이미 정리한 글도 다시 처리 (테스트용)
python hsr_news.py                           # 정리 리포트 실제 실행: 웹 배포 → 📋 알림 → (필요하면) 메일 → seen.json 갱신
python hsr_news.py --alert                   # 실시간 알림 1회 (새 글만 짧게 요약 → site/live/ → 웹 푸시)
python hsr_news.py --publish-only            # 수집 없이 site/의 웹앱 페이지만 다시 만들어 Cloudflare Pages에 배포
python hsr_news.py --test-push               # 구독한 기기에 시험 알림
python hsr_news.py --setup-push              # VAPID 키를 만들어 .env에 추가 (처음 한 번)
python hsr_news.py --update-lore             # '지금까지의 스토리'(정식 출시 스토리 정리, site/lore.json)를 지금 다시 만들어 배포
powershell -ExecutionPolicy Bypass -File register_task.ps1 [-Time "12:00,18:00"] [-AlertMinutes 10]   # 예약 작업 "HSR News Digest"(12시·18시, 절전 해제)와 "HSR Leak Alerts"(10분마다) 등록
```

테스트는 없고, `python -m pyflakes hsr_news.py`로 정의되지 않은 이름 등을 확인할 수 있습니다. 변경 후에는 `--dry-run`으로 실행해 `preview.pdf`와 `preview_site/`(`python -m http.server --directory preview_site`)를 확인합니다. dry-run도 Reddit·아카라이브에 실제로 접속하고 `claude -p`를 호출하므로(스토리 정리 포함) 몇 분 걸리고 구독 사용량이 차감됩니다. Claude 없이 분기만 확인하려면 모듈을 불러 `SITE_DIR`·`ALERT_FILE` 등을 임시 폴더로 바꾸고 `summarize`·`send_push`·`publish_site`를 가짜로 바꿔 `run_alerts()`·`publish_report()`를 부르면 됩니다. 실행 기록은 `logs/YYYY-MM.log`에 남습니다.

`.env`에는 `GMAIL_ADDRESS`, `GMAIL_APP_PASSWORD`(Gmail 앱 비밀번호)가 필요하고, 선택 항목으로 `MAIL_TO`, `MAIL_MODE`(fallback/always/off), `QUIET_HOURS`(예 01-08), `FAVORITE_CHARACTERS`(쉼표 구분), `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`, 웹앱용 `CLOUDFLARE_API_TOKEN`(권한: Cloudflare Pages Edit, Workers KV Storage Edit), `CLOUDFLARE_ACCOUNT_ID`, `SITE_URL`, 웹 푸시용 `VAPID_PRIVATE_KEY`·`VAPID_PUBLIC_KEY`를 넣을 수 있습니다.

## 실행 구조

`main()`은 옵션에 따라 `run_digest()`(기본) 또는 `run_alerts()`(`--alert`)를 부릅니다. 둘은 `run.lock`으로 동시에 돌지 않습니다(정리 리포트는 최대 15분 기다리고, 알림은 잠겨 있으면 그 회차를 건너뜀). `site/`를 다시 만드는 `--publish-only`·`--update-lore`도 같은 잠금을 기다립니다. 최상위 예외는 `notify_problem("crash", …)`로 아이폰에 알립니다(`notify_problem()`은 같은 key를 `problem_push.json` 기준 6시간에 한 번만 보냄).

### 공통 단계
1. **수집** — `fetch_all()`이 `fetch_leaks()`(Reddit RSS, OAuth가 있으면 API)와 `fetch_arca()`를 부르고 (글 목록, 실패한 출처)를 돌려줍니다. 두 수집 함수는 같은 형태의 항목 dict(`id`, `source`, `board`, `title`, `leaker`, `poster`, 한국 시간 `posted`, `url`, `text`, `media`, `images`, `comments`, `source_links`, Reddit은 `video_url`·`video_id`)를 만들므로 필드를 추가할 때는 양쪽에 모두 넣습니다. ID는 `leaks:` / `arca:` 접두어가 붙습니다.
2. **미디어** — `collect_media()`가 `WORK_DIR`(정리 리포트 `_images/`, 알림 `_alert/`)를 기준으로 스크린샷(`NN_k.확장자`), 갤러리 첫 장, 영상 프레임 4장을 받습니다. 영상은 `reddit_video_url()`이 `v.redd.it/<id>/DASHPlaylist.mpd`에서 480p 이하 CMAF 파일을 골라 `download_video_direct()`로 받습니다(로그인·Reddit 요청 제한과 무관). 아카라이브 글은 `fetch_arca_post()` 한 번의 요청으로 본문·이미지·댓글을 받고, Reddit의 이미지 외 글은 상위 댓글과 게시자가 단 원 출처 링크를 받습니다(알림은 `max_comments=3`).
3. **요약** — `summarize()`가 `run_claude_json()`(이 PC의 `claude -p --model sonnet`, `cwd=WORK_DIR`라 `.env`에는 접근 불가)을 부릅니다. 입력은 프롬프트 + `glossary_text()` + 항목 JSON + `recent_context()`가 만든 "최근에 이미 다룬 유출" R번호 목록입니다. 항목 필드는 `include`, `same_as`, `topic`, `headline`, `origin`, `summary`, `version`, `characters`, `repeat_of`(R번호 → 글 ID로 바꿔 둠), 정리 리포트만 `context`·`changes`이고, 최상위에 `overview`·`glossary`가 있습니다. 공통 규칙은 `NAMING_RULES`·`TAG_RULES`를 두 프롬프트(`PROMPT`, `ALERT_PROMPT`)가 같이 씁니다. 요약이 실패하면 원제목으로 진행합니다.
4. **중복 합치기** — `merge_duplicates()`는 `same_as`가 가리키는 글의 `also`로 합칩니다(같은 회차 안). 회차를 넘는 중복은 `repeat_of`로 처리합니다.

### 정리 리포트 (`run_digest()`)
- 최근 14일의 리포트 항목을 `recent_context({"report"}, …)`로 넘기고, `repeat_of`가 있는 글(이전 리포트와 같은 내용)은 빼고, 알림만 갔던 글은 그대로 넣습니다.
- `publish_report()` = `archive_report()`(site/r/<YYYY-MM-DD_HHMM>/에 `build_report(web=True)` 페이지와 `shrink_image()`로 줄인 이미지, `reports.json`, `items.json` 갱신) → `update_story()`(스토리 글이 있는 버전마다 `STORY_PROMPT`로 `story.json` 다시 씀, 최대 3개) → `write_site_shell()` → `publish_site()`(`wrangler pages deploy site`).
- 이어 "📋 HH시 정리 리포트" 웹 푸시를 보내고, `MAIL_MODE=fallback`이면 웹 배포나 푸시가 실패했을 때만 `make_pdf()`(Edge 헤드리스) + `send_mail()`(Gmail SMTP)을 씁니다. 새 유출이 없으면 아무것도 보내지 않습니다(always일 때만 "새 유출 없음" 메일). `seen.json`은 웹·알림·메일 중 하나라도 된 뒤 저장합니다.
- dry-run은 `build_preview()`가 `SITE_DIR`를 `preview_site/`(site/ 복사본)로 바꿔 같은 과정을 밟고, 배포·알림·메일은 하지 않습니다.
- 리포트가 끝난 뒤(dry-run 제외) `main()`이 `refresh_lore()`를 부릅니다: `lore.json`의 `updated`가 `LORE_REFRESH_DAYS`(14일)를 넘었으면 `update_lore()`가 `LORE_PROMPT`(웹 검색, 이전 정리를 넘겨 새 버전만 더함)로 정식 출시 스토리 정리를 다시 쓰고 배포합니다. 실패해도 리포트와 무관하며 다음 리포트 때 다시 시도합니다. `--update-lore`도 이전 정리를 이어 쓰므로 처음부터 다시 쓰려면 `site/lore.json`을 지우고 실행합니다. `LORE_PROMPT`는 `NAMING_RULES`(미출시 이름은 음역) 대신 자체 이름 규칙을 씁니다: 출시된 인물·장소는 한국어 자료로 공식 이름을 확인하고, 못 하면 음역하지 않고 영문 그대로 둡니다.

### 실시간 알림 (`run_alerts()`)
- `alerted.json`(최대 2000개)과 `seen.json`에 없는 글만 대상으로 합니다. `alerted.json`이 없는 첫 실행은 지금 있는 글을 기록만 합니다. 두 출처 모두 수집에 실패하면 `notify_problem("fetch")`.
- `summarize(prompt=ALERT_PROMPT, tools="Read", recent=recent_context({"live", "report"}, 48))`로 웹 검색 없이 요약합니다.
- `repeat_of`가 있는 글은 알리지 않고 `add_live()`가 원래 live 항목의 `also`에 붙입니다. 새 글은 `site/live/feed.json`·`live/img/`에 쌓고(최근 `LIVE_KEEP_DAYS`=7일) `items.json`에 kind=live로 넣은 뒤 배포합니다.
- `deliver_alerts()`: `QUIET_HOURS` 안이면 관심 캐릭터(`is_favorite()`) 글만 바로(⭐) 보내고 나머지 제목은 `pending_push.json`에 모읍니다. 시간이 끝난 뒤 첫 실행(새 글이 없어도 부름)에서 "🌙 밤사이 유출 N건"으로 보냅니다. 3건 이하면 글마다, 더 많으면 묶어서 보냅니다(`alert_messages()`).
- `send_push()`는 `wrangler.toml`의 KV(binding `PUSH`) id로 Cloudflare API에서 `sub:*` 구독을 읽어 pywebpush로 보내고, 404/410이 오면 그 구독을 지웁니다. 구독은 목록 페이지의 '새 유출 알림 켜기'(`PUSH_HTML`) → `functions/api/subscribe.js`(Pages Function) → KV로 저장됩니다.

### 웹앱 (`site/`)
- `items.json`이 색인입니다: 글 ID별 {kind(report/live), url(카드 앵커), added, date, topic, version, characters, headline, summary, changes, leaker, source}, 90일. `update_index()`에서 리포트 항목은 같은 글의 live 항목을 덮어쓰지만 반대는 아닙니다. 모아보기·검색·스토리 탭과 `recent_context()`가 모두 여기서 읽습니다.
- 📖 스토리 탭(`write_story_page()`)은 `#lore`(📚 지금까지의 스토리, `lore_html()`이 `lore.json`을 무대별 `<details>`로)와 `#leaks`(🔮 유출 스토리, `story.json` + 근거 유출) 두 부분이고, `STORY_JS`가 주소의 `#leaks`·`#v-<버전>`을 보고 전환합니다.
- `write_site_shell()`이 매번 전체를 다시 만듭니다: `index.html`(📋 리포트 목록, `data-run`), `live/`, `story/`, `browse/`, `v/<version_slug>/`, `c/<char_slug(해시)>/`(둘 다 지우고 다시 만듦), `search/`(`SEARCH_JS`가 items.json을 받아 거름), `404.html`, `sw.js`(`SW_JS`), manifest, 아이콘, `badges.json`(NEW 표시용 회차·live ID).
- 모든 웹 페이지는 `web_page()`로 감싸 `WEB_HEAD` + 하단 탭 바(`TABS`, `nav_html()`) + `APP_JS`(3분 넘게 숨겨졌다 돌아오면 새로고침, 스크린샷 라이트박스, localStorage로 NEW·실시간 배지)를 붙입니다. 리포트·실시간처럼 카드가 있는 페이지는 `report_css=True`(`CSS` + `WEB_CSS`), 목록형은 `INDEX_CSS`.
- 사이트 안의 링크·스크립트·API 경로는 모두 `/`로 시작하는 절대 경로로 씁니다. `site/404.html`도 꼭 있어야 합니다. 404.html이 없으면 Pages가 없는 주소에도 목록 페이지를 200으로 보여 주는데(SPA 방식), 그 상태에서 상대 경로 링크를 누르면 주소가 계속 덧붙어 페이지가 열리지 않습니다.
- `wrangler pages deploy`는 저장소 루트에서 실행되므로 `functions/`와 `wrangler.toml`(KV 바인딩)이 함께 올라갑니다. iOS는 홈 화면에 추가한 앱에서만 웹 푸시를 쓸 수 있습니다(16.4 이상).

## 유의할 점

- **한국어 표기**: `characters.json`은 HoYoLAB 위키에서 받은 캐릭터 이름(영문 → 한국어 + 운명의 길·속성·등급·세력), `names.json`은 같은 위키의 적·NPC 이름(영문 → 한국어)을 7일간 저장하는 캐시이며 `fetch_character_names()`·`fetch_other_names()`가 `cached_wiki()`로 만듭니다. `FIXED_TERMS`에는 운명의 길·속성, 게임 용어, 전투 용어(필살기·강인성 등), 세계관 용어(에이언즈·절멸 대군 등)가 들어 있습니다. `glossary_text()`가 셋을 묶어 모든 요약·스토리 프롬프트에 넣고, `NAMING_RULES`는 사전에 없는 이름만 음역하게 합니다(Claude가 기억으로 짐작한 한국어 이름은 커뮤니티 말이나 영문 음역이 섞여 자주 틀림). 결과물에서 틀린 표기가 보이면 위키 한국어판 스킬 설명 등으로 공식 표기를 확인해 `FIXED_TERMS`에 넣습니다. 사전을 강제로 새로 받으려면 `characters.json`·`names.json`을 지웁니다.
- **요청 제한**: Reddit 요청은 모두 `reddit_get()` / `reddit_wait()`를 거쳐야 합니다(로그인 없는 요청은 1분 창마다 1번만 허용되므로 응답 헤더 `x-ratelimit-remaining`/`reset`을 보고 창이 풀릴 때까지 대기). v.redd.it·i.redd.it 같은 CDN 주소는 이 제한과 무관합니다. `.env`에 `REDDIT_CLIENT_ID`/`REDDIT_CLIENT_SECRET`이 있으면 `reddit_login()`이 앱 전용 OAuth 토큰을 받고 `fetch_leaks_api()`·`fetch_comments()`가 `oauth.reddit.com`의 JSON API를 씁니다. 토큰이 없거나 API 수집이 실패하면 RSS로 돌아갑니다. 로그인 없는 `www.reddit.com/*.json`과 yt-dlp는 막혀 있습니다. 아카라이브 요청은 `arca_get()`을 거칩니다(3초 대기, 브라우저 UA).
- **정규식 기반 파싱**: 아카라이브 파싱은 특정 class 이름(`vrow column`, `article-content`, `message`)에 의존합니다. 아카라이브 수집 결과가 0건이 되면 먼저 이 부분을 확인합니다.
- **예약 실행 제약**: `pythonw.exe`로 실행되고 실행 시간 제한은 정리 리포트 45분·알림 20분입니다. 하위 프로세스는 `CREATE_NO_WINDOW`로 띄우고, `claude` 호출 제한 시간은 정리 1500초·알림과 스토리 600초입니다. 예약 작업을 실행하는 사용자의 PATH에서 `claude`와 `wrangler`(npm 전역 설치)를 찾을 수 있어야 합니다.
- `_images/`, `_alert/`, `preview.pdf`, `preview_site/`, `logs/`, `site/`, `characters.json`, `names.json`, `alerted.json`, `pending_push.json`, `problem_push.json`, `run.lock`은 실행 결과물입니다. `site/`는 지우지 않고 쌓아 가는 웹 보관소이므로(리포트·items.json·story.json·feed.json) 지우면 웹의 지난 내용도 사라집니다.
