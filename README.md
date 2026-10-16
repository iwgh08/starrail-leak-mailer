# 붕괴: 스타레일 찌라시(유출) 자동 메일

매일 낮 12시와 오후 6시에 아래 두 곳에서 새 유출 글을 모아 Gmail로 보냅니다.
- Reddit **r/HonkaiStarRail_leaks**
- **아카라이브 붕괴 스타레일 채널**의 '찌라시'·'테섭' 게시판 (최근 48시간 안의 글)

같은 유출이 두 곳에 모두 올라오면 한 항목으로 합치고, 출처는 둘 다 표시합니다.

- 스크린샷, 갤러리 첫 장, 영상 프레임, 댓글까지 읽고 한국어로 요약합니다.
- 항목마다 **배경 설명**을 붙이고, 끝에 **용어 풀이**를 넣은 **PDF**를 만듭니다. 배경 설명과 용어 풀이에는 웹 검색으로 확인한 내용이 들어갑니다.

- 요약은 이 PC에 설치된 Claude Code(`claude -p`, Sonnet 모델 + 웹 검색)로 합니다. API 키 없이 Claude 구독 사용량에서 조금씩 차감됩니다.
- PDF에는 항목마다 출처가 표시됩니다.
  - 유출 출처: 원 게시물 제목의 "via ○○"(Reddit) 또는 "○○)"(아카라이브)
  - 최초 출처: 스크린샷에 보이는 텔레그램·X 채널
  - 게시판, 게시자, 게시 시각(한국 시간), 원문 링크, 스크린샷
- PDF는 Microsoft Edge로 만듭니다.
- 캐릭터 이름은 HoYoLAB 위키의 한국 서버 표기를 따릅니다. 운명의 길·속성·소속 정보도 함께 가져오며, `characters.json`에 7일간 저장합니다.
- 이미 보낸 글은 `seen.json`에 기록해서 다시 보내지 않습니다. 다시 보내려면 `--ignore-seen` 옵션을 씁니다.
- Reddit은 로그인 없이 접속하면 1분에 1번만 요청할 수 있어서, 제한이 풀릴 때까지 기다렸다가 다음 요청을 보냅니다. Reddit API 앱 정보를 `.env`에 넣으면 이 제한이 1분에 약 100번으로 늘어납니다(아래 4번).
- (선택) 같은 리포트를 **아이폰 Safari에서 날짜별로 볼 수 있는 웹앱**으로도 올립니다(아래 5번). 메일에 "📱 웹에서 보기" 링크가 붙습니다.
- (선택) 10분마다 새 글을 확인해 한 줄 요약을 **아이폰 알림**으로 바로 보냅니다(아래 6번). 알림을 누르면 웹앱의 ⚡실시간 페이지가 열립니다.

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
5. (선택) 아이폰 웹앱. 리포트를 Cloudflare Pages에 올리고, Cloudflare Access로 내 이메일 인증을 거쳐야만 열리게 잠급니다(무료).
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
   - 리포트는 `site/` 폴더에 쌓이고 최근 90일 치만 남깁니다. 토큰이 없거나 배포에 실패해도 메일은 그대로 보냅니다.
6. (선택) 실시간 아이폰 알림. 5번을 마친 뒤 진행합니다. iOS 16.4 이상이 필요합니다.
   1. `python hsr_news.py --setup-push`로 알림용 키(VAPID)를 만들어 `.env`에 넣습니다.
   2. 구독 정보를 저장할 KV를 만듭니다: `wrangler kv namespace create hsr-push`
      나온 id를 `wrangler.toml`의 `[[kv_namespaces]]`(binding = "PUSH")에 넣습니다.
   3. `python hsr_news.py --publish-only`로 다시 올립니다(`functions/api/subscribe.js`가 함께 올라갑니다).
   4. 아이폰의 **홈 화면 앱**(Safari가 아님)에서 **🔔 새 유출 알림 켜기**를 누르고 알림을 허용합니다.
   5. `python hsr_news.py --test-push`로 시험 알림이 오는지 확인합니다.
   - 예약 작업 "HSR Leak Alerts"가 10분마다 `--alert`로 실행됩니다. 처음 실행 때는 지금 있는 글을 기록만 하고, 그 뒤 새 글부터 알립니다.
   - 새 글이 있을 때만 Claude로 짧게 요약하므로(웹 검색 없음) 알림 한 번에 Claude 사용량이 조금 듭니다. 유출이 아닌 글은 알리지 않습니다.
   - 3건 이하면 글마다, 더 많으면 한 번에 묶어서 알립니다. PC가 꺼져 있거나 절전 중이면 켜진 뒤 밀린 글을 알립니다.

## 실행

```
python hsr_news.py --dry-run        # 메일 없이 preview.pdf로 미리보기 (웹에는 올리지 않음)
python hsr_news.py                  # 실제 발송 (웹 설정이 있으면 웹에도 올림)
python hsr_news.py --publish-only   # 수집 없이 site/ 목록만 다시 만들어 웹에 올림
python hsr_news.py --alert          # 새 글만 확인해 아이폰 알림 (예약 작업이 10분마다 실행)
python hsr_news.py --test-push      # 아이폰으로 시험 알림 보내기
```

## 자동 실행 (정리 리포트 낮 12시·오후 6시, 실시간 알림 10분마다)

```
powershell -ExecutionPolicy Bypass -File register_task.ps1
powershell -ExecutionPolicy Bypass -File register_task.ps1 -Time "09:00,21:00"   # 정리 리포트 시간 변경 (쉼표로 여러 개)
powershell -ExecutionPolicy Bypass -File register_task.ps1 -AlertMinutes 0       # 실시간 알림 끄기
```

- PC가 꺼져 있었다면 다음에 켰을 때 실행됩니다. Windows에 로그인한 상태여야 실행되며, 노트북은 배터리 사용 중에도 실행됩니다.
- 정리 리포트와 실시간 알림은 동시에 돌지 않습니다(`run.lock`). 정리 리포트가 도는 동안의 알림 확인은 건너뛰고 다음 확인 때 이어서 합니다.
- 자동 실행을 끄려면 `Unregister-ScheduledTask -TaskName "HSR News Digest"`(정리 리포트), `"HSR Leak Alerts"`(실시간 알림)를 실행합니다.
- 실행 기록은 `logs/` 폴더에 남습니다.
