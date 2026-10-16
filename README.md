# 붕괴: 스타레일 찌라시(유출) 자동 알림

아래 두 곳에서 새 유출 글을 모아 한국어로 요약하고, 아이폰 웹앱과 알림으로 보내 줍니다.
- Reddit **r/HonkaiStarRail_leaks** (최근 48시간 안의 글)
- **아카라이브 붕괴 스타레일 채널**의 '찌라시'·'테섭' 게시판 (최근 48시간 안의 글)

## 무엇을 해 주나요

- **실시간 알림** (10분마다): 새 글이 올라오면 스크린샷·영상 장면을 읽고 한 줄 요약을 아이폰 알림으로 보냅니다.
  유출이 아닌 글(밈·잡담 등)은 빼고, 이미 알린 내용의 번역·재게시는 다시 알리지 않고 원래 글의 '다른 출처'로 합칩니다.
- **정리 리포트** (매일 낮 12시·오후 6시): 그사이 글을 모아 **배경 설명**과 **용어 풀이**(웹 검색으로 확인)를 붙인 리포트를 만들고,
  "📋 정리 리포트" 알림을 보냅니다. 메일(PDF)은 기본적으로 웹 업로드나 알림이 실패할 때만 보냅니다(`MAIL_MODE`).
- **아이폰 웹앱** (홈 화면에 추가해서 앱처럼 사용, 내 이메일 인증으로 잠김). 아래쪽 탭:
  - 📋 **리포트**: 날짜별 정리 리포트 목록 (안 읽은 회차에 NEW)
  - ⚡ **실시간**: 알림을 보낸 글 모음 (최근 7일)
  - 📖 **스토리**: 두 부분으로 나뉩니다.
    - 📚 지금까지의 스토리: 정식 출시된 메인 스토리를 무대별로 정리(기본 설정·줄거리·핵심 떡밥·세력과 개념·참고 자료).
      웹 검색으로 확인해 만들고, 14일마다 정리 리포트 뒤에 새 버전 내용을 더합니다(바로 하려면 `--update-lore`).
    - 🔮 유출 스토리: 스토리 유출을 버전별로 모아 Claude가 줄거리로 정리 (정리 리포트 때 갱신)
  - 🗂 **모아보기**: 버전별(예: 4.7)·캐릭터별·주제별 모아보기. 같은 캐릭터의 이전 유출 대비 바뀐 점(🔄)도 표시
  - 🔍 **검색**: 캐릭터 이름·버전·내용으로 찾기
  - 스크린샷은 누르면 크게 보이고, 앱을 다시 열면 새 내용으로 자동 새로고침됩니다.
- **방해 금지 시간** (`QUIET_HOURS`, 기본 01–08시): 그 시간의 알림은 모아 두었다가 끝난 뒤 "🌙 밤사이 유출"로 한 번에 보냅니다.
  **관심 캐릭터**(`FAVORITE_CHARACTERS`) 유출은 그 시간에도 바로 ⭐를 붙여 알립니다.
- **문제 알림**: 요약·업로드·메일이 실패하거나 두 출처 모두 접속이 안 되면 아이폰으로 알려 줍니다(같은 문제는 6시간에 한 번).

그 밖에
- 같은 유출이 두 곳에 모두 올라오면 한 항목으로 합치고, 출처는 둘 다 표시합니다.
- 요약은 이 PC에 설치된 Claude Code(`claude -p`, Sonnet 모델)로 합니다. API 키 없이 Claude 구독 사용량에서 조금씩 차감됩니다.
- Reddit 영상은 로그인 없이 v.redd.it에서 직접 받아 장면 4장을 뽑아 읽습니다.
- 캐릭터 이름은 HoYoLAB 위키의 한국 서버 표기를 따릅니다(`characters.json`에 7일간 저장).
- 이미 정리한 글은 `seen.json`, 이미 알린 글은 `alerted.json`에 기록합니다. 정리 리포트를 다시 만들려면 `--ignore-seen`을 씁니다.
- Reddit은 로그인 없이 1분에 1번만 요청할 수 있어서 기다렸다가 요청합니다. Reddit API 앱 정보를 넣으면 1분에 약 100번까지 늘어납니다(아래 4번).

## 처음 설정

1. 패키지를 설치합니다.
   ```
   pip install -r requirements.txt
   ```
2. Google 계정에서 2단계 인증을 켜고 [앱 비밀번호](https://myaccount.google.com/apppasswords)를 만듭니다.
3. `.env.example`을 복사해 이름을 `.env`로 바꾸고, `GMAIL_APP_PASSWORD`에 앱 비밀번호를 넣습니다.
4. (선택) Reddit 요청 제한을 늘리려면 Reddit에 로그인한 뒤 <https://www.reddit.com/prefs/apps>에서 **create another app…** 을 눌러 앱을 만듭니다.
   - 종류는 **script**, redirect uri는 `http://localhost:8080`으로 둡니다.
   - 앱 이름 아래의 14~22자 문자열을 `REDDIT_CLIENT_ID`, **secret** 값을 `REDDIT_CLIENT_SECRET`에 넣습니다.
   - Reddit이 API 이용 신청서(용도 설명)를 먼저 요구하면, 개인용 뉴스 요약에 읽기 전용으로 쓴다고 적어 신청합니다.
   - 로그인에 실패하면 로그에 경고를 남기고 로그인 없이 수집합니다.
5. 아이폰 웹앱. 리포트를 Cloudflare Pages에 올리고, Cloudflare Access로 내 이메일 인증을 거쳐야만 열리게 잠급니다(무료).
   1. Node.js를 설치한 뒤 `npm install -g wrangler`로 업로드 도구를 설치합니다.
   2. <https://dash.cloudflare.com>에 가입하고, 계정 홈의 **Account ID**를 `.env`의 `CLOUDFLARE_ACCOUNT_ID`에 넣습니다.
   3. **My Profile → API Tokens → Create Token → Custom token**에서 권한을 `Account · Cloudflare Pages · Edit`와
      `Account · Workers KV Storage · Edit`(6번 실시간 알림용)로 만들고, 토큰을 `CLOUDFLARE_API_TOKEN`에 넣습니다.
   4. 프로젝트를 만듭니다: `wrangler pages project create hsr-leaks --production-branch main --force`
      (이 PowerShell 창에서 `$env:CLOUDFLARE_API_TOKEN`·`$env:CLOUDFLARE_ACCOUNT_ID`를 먼저 설정합니다.
      `--force`는 새 wrangler가 프로젝트를 Workers 쪽으로 만들려는 것을 막고 기존 Pages로 만들 때 한 번만 씁니다)
   5. 대시보드 왼쪽의 **Zero Trust**를 열어 시작합니다(팀 이름이 자동으로 정해지고 Free 플랜이 됩니다).
   6. 잠금을 겁니다. **Workers & Pages → hsr-leaks → Settings → General → Preview access → Restrict previews**를 누른 뒤,
      **Manage**로 들어가 정책의 Include가 내 Gmail 주소뿐인지 확인하고, **Destinations**에서 Subdomain의 `*`를 지워
      기본 주소(`hsr-leaks.pages.dev`)를 잠그고 Session Duration을 1개월로 저장합니다.
      그다음 Preview access의 **Restrict previews**를 한 번 더 눌러 배포별 주소(`*.hsr-leaks.pages.dev`)도 잠급니다.
   7. `.env`의 `SITE_URL`에 `https://hsr-leaks.pages.dev`(프로젝트를 만들 때 나온 주소)를 넣고 `python hsr_news.py --publish-only`로 올려 봅니다.
   8. 아이폰 Safari에서 주소를 열고 이메일로 받은 코드로 로그인한 뒤, **공유 → 홈 화면에 추가**를 누르면 앱처럼 쓸 수 있습니다.
   - 웹 데이터는 `site/` 폴더에 쌓이고 최근 90일 치만 남깁니다(실시간 탭은 7일).
6. 아이폰 알림. 5번을 마친 뒤 진행합니다. iOS 16.4 이상이 필요합니다.
   1. `python hsr_news.py --setup-push`로 알림용 키(VAPID)를 만들어 `.env`에 넣습니다.
   2. 구독 정보를 저장할 KV를 만듭니다: `wrangler kv namespace create hsr-push`
      나온 id를 `wrangler.toml`의 `[[kv_namespaces]]`(binding = "PUSH")에 넣습니다.
   3. `python hsr_news.py --publish-only`로 다시 올립니다(`functions/api/subscribe.js`가 함께 올라갑니다).
   4. 아이폰의 **홈 화면 앱**(Safari가 아님)에서 **🔔 새 유출 알림 켜기**를 누르고 알림을 허용합니다.
   5. `python hsr_news.py --test-push`로 시험 알림이 오는지 확인합니다.

## `.env` 선택 항목

| 항목 | 설명 |
|---|---|
| `MAIL_MODE` | `fallback`(기본: 웹 업로드나 알림이 실패할 때만 PDF 메일) · `always`(늘 메일, 새 유출 없음 메일 포함) · `off` |
| `QUIET_HOURS` | 방해 금지 시간(한국 시간), 예: `01-08`, `23-07`. 비우면 사용 안 함 |
| `FAVORITE_CHARACTERS` | 관심 캐릭터(쉼표로 구분), 예: `반디,카프카`. 방해 금지 시간에도 바로 알리고 모아보기에서 앞에 보임 |
| `MAIL_TO` | 받는 메일 주소(비우면 `GMAIL_ADDRESS`) |

## 실행

```
python hsr_news.py --dry-run        # 보내지 않고 preview.pdf와 preview_site/(웹앱 미리보기)만 만듦
python hsr_news.py                  # 정리 리포트 실제 실행 (웹 업로드 → 알림 → 필요하면 메일)
python hsr_news.py --alert          # 새 글만 확인해 아이폰 알림 (예약 작업이 10분마다 실행)
python hsr_news.py --publish-only   # 수집 없이 웹앱 페이지만 다시 만들어 올림
python hsr_news.py --test-push      # 아이폰으로 시험 알림 보내기
python hsr_news.py --update-lore    # '지금까지의 스토리'를 지금 다시 정리해 올리기 (웹 검색, 몇 분)
```

`preview_site/`는 `python -m http.server --directory preview_site`로 띄워 PC 브라우저에서 볼 수 있습니다.
'지금까지의 스토리'는 이전 정리에 이어 쓰므로, 내용이 이상해서 처음부터 다시 쓰고 싶으면 `site/lore.json`을 지운 뒤 `--update-lore`를 실행합니다.

## 자동 실행 (정리 리포트 낮 12시·오후 6시, 실시간 알림 10분마다)

```
powershell -ExecutionPolicy Bypass -File register_task.ps1
powershell -ExecutionPolicy Bypass -File register_task.ps1 -Time "09:00,21:00"   # 정리 리포트 시간 변경 (쉼표로 여러 개)
powershell -ExecutionPolicy Bypass -File register_task.ps1 -AlertMinutes 0       # 실시간 알림 끄기
```

- PC가 꺼져 있었다면 다음에 켰을 때 실행됩니다. Windows에 로그인한 상태여야 실행되며, 노트북은 배터리 사용 중에도 실행됩니다.
- 정리 리포트 시각에는 절전 중인 PC를 깨워서 실행합니다. Windows **전원 옵션 → 고급 설정 → 절전 → 절전 해제 타이머 허용**이 켜져 있어야 합니다.
- 정리 리포트와 실시간 알림은 동시에 돌지 않습니다(`run.lock`). 정리 리포트가 도는 동안의 알림 확인은 건너뛰고 다음 확인 때 이어서 합니다.
- 자동 실행을 끄려면 `Unregister-ScheduledTask -TaskName "HSR News Digest"`(정리 리포트), `"HSR Leak Alerts"`(실시간 알림)를 실행합니다.
- 실행 기록은 `logs/` 폴더에 남습니다.
