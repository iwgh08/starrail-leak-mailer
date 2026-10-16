# 붕괴: 스타레일 찌라시(유출) 자동 메일

매일 아침 아래 두 곳에서 새 유출 글을 모아 Gmail로 보냅니다.
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

## 실행

```
python hsr_news.py --dry-run   # 메일 없이 preview.pdf로 미리보기
python hsr_news.py             # 실제 발송
```

## 매일 자동 실행 (낮 12시, 오후 6시)

```
powershell -ExecutionPolicy Bypass -File register_task.ps1
powershell -ExecutionPolicy Bypass -File register_task.ps1 -Time "09:00,21:00"   # 시간 변경 (쉼표로 여러 개)
```

- PC가 꺼져 있었다면 다음에 켰을 때 실행됩니다. Windows에 로그인한 상태여야 실행됩니다.
- 자동 실행을 끄려면 `Unregister-ScheduledTask -TaskName "HSR News Digest"`를 실행합니다.
- 실행 기록은 `logs/` 폴더에 남습니다.
