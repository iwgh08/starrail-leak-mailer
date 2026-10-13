---
name: ship
description: 변경 사항에 문제가 없는지 점검한 뒤 git add → commit → push 한다. 사용자가 /ship 을 입력했을 때만 실행.
disable-model-invocation: true
argument-hint: "[dry-run] [커밋 메시지에 넣을 설명]"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git remote:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git ls-files:*), Bash(python -m py_compile:*), Read, Grep, Glob
---

# /ship — 점검 후 커밋·푸시

인자: `$ARGUMENTS`

아래 순서대로 진행한다. **점검에서 문제가 하나라도 나오면 커밋하지 말고 멈춘 뒤**, 무엇이 문제인지와 어떻게 고치면 되는지 한국어로 알려 준다. 사용자가 고치라고 하면 고친 뒤 처음부터 다시 점검한다.

## 1. 현황 파악

- `git status --short`, `git branch --show-current`, `git remote -v`, `git diff`, `git diff --cached`를 확인한다.
- 바뀐 것이 없으면 "커밋할 변경 없음"이라고 알리고 끝낸다.

## 2. 점검

1. **비밀 정보와 실행 결과물이 올라가지 않는지**
   - `.env`, `seen.json`, `characters.json`, `preview.pdf`, `logs/`, `_images/`, `__pycache__/`가 untracked나 staged 목록에 있으면 안 된다. `git ls-files`로 이미 추적 중인지도 본다. 있으면 `.gitignore`를 확인한다.
   - diff 안에 실제 비밀번호나 키가 없는지 본다. 예: `GMAIL_APP_PASSWORD=`, `REDDIT_CLIENT_SECRET=`, `REDDIT_CLIENT_ID=` 뒤의 실제 값, 16자리 앱 비밀번호, `bearer` 토큰. `.env.example`의 `xxxx` 같은 자리표시자는 괜찮다.
2. **문법 오류**
   - `python -m py_compile hsr_news.py`가 통과해야 한다.
   - `register_task.ps1`이 바뀌었으면 PowerShell 파서로 문법을 확인한다: `[System.Management.Automation.Language.Parser]::ParseFile(...)`. 오류가 0개여야 한다.
3. **변경 내용 검토**
   - diff를 읽고 명백한 버그가 있는지 본다. 예: 정의되지 않은 이름, 잘못된 들여쓰기, 지워진 함수를 아직 부르는 곳, 디버그용 `print`나 임시 코드.
   - 동작이 바뀌었는데 `CLAUDE.md`나 `README.md`가 그대로면 문서가 낡았다고 알린다. 이것은 경고만 하고 커밋을 막지는 않는다.
4. **실행 확인 (선택)**
   - 인자에 `dry-run`이 있을 때만 `python hsr_news.py --dry-run`을 실행하고 로그에 ERROR가 없는지 본다.
   - 이 실행은 몇 분 걸리고 Claude 사용량이 든다. 인자가 없으면 실행하지 않고, 요약할 때 "dry-run은 생략함"이라고 밝힌다.

## 3. 커밋

- `git add -A`로 올린 뒤, `git status --short`로 올라간 파일이 예상한 것뿐인지 다시 확인한다.
- 커밋 메시지는 이 저장소의 기존 메시지처럼 한국어로 쓴다. 첫 줄은 무엇을 바꿨는지 짧게 요약하고, 필요하면 빈 줄 뒤에 항목별로 덧붙인다. 인자에 설명이 있으면 그 내용을 반영한다.
- 메시지 끝에는 현재 시스템 안내에 있는 Co-Authored-By 줄을 붙인다.

## 4. 푸시

- `git push`로 현재 브랜치를 origin에 올린다. 업스트림이 없으면 `git push -u origin <브랜치>`를 쓴다.
- 원격에 새 커밋이 있어 거절되면, 강제 푸시(`--force`)는 하지 말고 상황을 알린 뒤 사용자에게 어떻게 할지 묻는다.

## 5. 결과 보고

짧게 알린다:
- 점검 결과 (통과 항목, 경고)
- 커밋 해시와 메시지 첫 줄, 포함된 파일
- 푸시 결과
