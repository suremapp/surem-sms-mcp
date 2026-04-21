# 슈어엠 SMS MCP

Claude에게 말만 하면, 슈어엠으로 문자메시지를 보내주는 MCP 서버입니다.

```
"발신번호 15884640으로 010-0000-0000에 '오늘 저녁 7시 약속 잊지 마세요' 문자 보내줘"
```

---

## 주요 기능

- **자연어 발송** — Claude에게 대화하듯 말하면 SMS/LMS를 자동으로 발송
- **자동 SMS/LMS 전환** — 메시지 길이(EUC-KR 기준 바이트)에 따라 자동 선택
  - 90바이트 이하 → **SMS**
  - 91 ~ 2,000바이트 → **LMS**
- **예약 발송** — 원하는 시각을 지정해 예약 발송 가능 (미지정 시 즉시 발송)
- **메시지 길이 검증** — 2,000바이트 초과 시 발송 전 경고
- **토큰 자동 갱신** — API 인증 토큰을 자동으로 캐싱/갱신 (50분 주기)

---

## 시작하기 (4단계)

### 1단계. 필수 프로그램 설치

| 프로그램 | 설명 |
|---|---|
| [Claude Desktop](https://claude.ai/download) | 이 MCP를 사용하는 클라이언트 |
| [Node.js](https://nodejs.org) | v16 이상 |

설치 후 터미널(PowerShell / Terminal)에서 아래 명령으로 확인:
```bash
node --version
```

---

### 2단계. 슈어엠 회원가입 및 SecretKey 발급

1. [슈어비즈(surebiz.co.kr)](https://surebiz.co.kr) 접속 후 회원가입
2. 로그인 후 **기본정보 → 내정보** 진입
3. 페이지 최하단 **REST API 인증키** 메뉴에서 `SecretKey` 발급
4. 발급된 **슈어엠 아이디(UserCode)** 와 **SecretKey** 를 메모해둡니다

> 이 두 값이 MCP 설치 시 환경변수로 필요합니다.

---

### 3단계. IP 등록 및 발신번호 등록

슈어엠 API는 **사전에 등록된 IP와 발신번호에서만 사용**할 수 있습니다. 반드시 아래 두 가지를 먼저 등록하세요.

#### 3-1. 내 PC의 IP 등록

1. [네이버](https://naver.com) 검색창에 **내 IP주소** 를 입력해 본인의 공인 IP 확인
2. 슈어비즈 → **기본정보 → 고객지원 → IP관리** 메뉴에서 해당 IP 등록

> IP를 등록하지 않으면 "HTTP 403 실패" 오류가 발생합니다.

#### 3-2. 발신번호 등록

문자 발송 시 사용할 **발신번호**는 슈어비즈에 사전 등록된 번호만 사용할 수 있습니다.

1. 슈어비즈 → **기본정보 → 발신번호** 메뉴에서 사용할 발신번호를 등록
2. 등록 심사가 완료된 번호만 MCP에서 사용 가능

> 미등록 번호로 발송 시도 시, 발신번호 미등록 에러로 전송되지 않습니다.

---

### 4단계. MCP 설치

OS에 맞는 방법을 선택하세요.

#### 🪟 Windows (자동 설치)

PowerShell을 열고 아래 명령을 실행하세요.

```powershell
iex ((irm https://raw.githubusercontent.com/suremapp/surem-sms-mcp/main/scripts/install-windows.ps1).TrimStart([char]0xFEFF))
```

스크립트가 실행되면 입력 안내 메시지와 함께 **UserCode**와 **SecretKey**를 순서대로 입력받습니다. (값을 미리 준비해두세요)

> `.TrimStart([char]0xFEFF)` 부분은 스크립트 파일의 UTF-8 BOM을 제거하기 위함입니다. BOM은 파일을 로컬 실행할 때 PowerShell 5.1의 한글 파싱 오류를 막아주지만, `irm | iex`에서는 명령 앞에 붙어 실행을 방해하므로 제거해야 합니다.

<details>
<summary>로컬에 저장소를 clone해 값과 함께 실행하는 경우</summary>

```powershell
.\scripts\install-windows.ps1 -UserCode "슈어엠_아이디" -SecretKey "API_키"
```
</details>

#### 🍎 Mac (자동 설치)

터미널에서 아래 명령을 실행하세요. 실행 후 **UserCode**와 **SecretKey**를 입력하라는 안내가 나타납니다.

```bash
curl -s https://raw.githubusercontent.com/suremapp/surem-sms-mcp/main/scripts/install-mac.sh | bash
```

<details>
<summary>값을 한 줄에 함께 전달해 실행하는 경우</summary>

```bash
curl -s https://raw.githubusercontent.com/suremapp/surem-sms-mcp/main/scripts/install-mac.sh | bash -s 슈어엠_아이디 API_키
```
</details>

#### ✏️ config 직접 설정

Claude Desktop의 `claude_desktop_config.json` 파일에 직접 추가합니다.

**파일 위치:**

| OS | 경로 |
|---|---|
| Windows (Microsoft Store) | `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json` |
| Windows (일반 설치) | `%APPDATA%\Claude\claude_desktop_config.json` |
| Mac | `~/Library/Application Support/Claude/claude_desktop_config.json` |

**설정 내용:**

```json
{
  "mcpServers": {
    "surem-sms-mcp": {
      "command": "npx",
      "args": ["-y", "surem-sms-mcp"],
      "env": {
        "SUREM_USER_CODE": "슈어엠_아이디",
        "SUREM_SECRET_KEY": "API_키"
      }
    }
  }
}
```

---

## 설치 확인

1. Claude Desktop을 **완전히 종료** 후 재시작 (시스템 트레이에서 실행 중이라면 트레이 아이콘 → 종료까지 확인)
2. 채팅창 왼쪽 아래 **+ 버튼 → 커넥터** 메뉴에서 `surem-sms-mcp`가 켜져 있는지 확인

<p align="center">
  <img src="https://raw.githubusercontent.com/suremapp/surem-sms-mcp/main/image/ex1.png" alt="Claude Desktop 커넥터 메뉴에서 surem-sms-mcp 확인" width="420">
</p>

---

## 사용 방법

Claude에게 자연어로 말하면 됩니다. **발신번호는 반드시 슈어비즈에 사전 등록된 번호**여야 합니다.

### 예시

```
"발신번호 15884640으로 010-0000-0000에 '내일 오전 10시 미팅입니다' 문자 보내줘"
```

```
"010-0000-0000에 배송 완료 안내 문자 보내줘. 발신번호는 15881234야."
```

```
"아래 내용으로 LMS 발송해줘.
 받는 사람: 010-0000-0000
 발신번호: 15884640
 제목: 주문 확인
 내용: 주문하신 상품이 오늘 출고됩니다. 감사합니다."
```

> 메시지 길이가 길면 자동으로 **LMS**로 전환됩니다. 별도 지시가 필요 없습니다.

### 예약 발송

시각을 지정해서 말하면 예약 발송됩니다.

```
"내일 오전 9시에 010-0000-0000로 '좋은 아침입니다' 문자 보내줘. 발신번호는 15884640."
```

```
"2026년 4월 25일 오후 2시 30분에 010-0000-0000에 세미나 안내 LMS 예약 발송해줘.
 발신번호: 15884640
 제목: 세미나 안내
 내용: 오늘 오후 3시 3층 대회의실에서 세미나가 진행됩니다."
```

> ⚠️ **예약 취소는 슈어비즈에서 수동으로 진행**해야 합니다.
> 슈어비즈 → **예약,결과 → 예약조회** 메뉴에서 예약된 건을 취소할 수 있습니다.

---

## 제공 도구 (Tools)

### `send_message`

수신번호, 내용, 발신번호를 받아 SMS 또는 LMS로 발송합니다. 메시지 길이에 따라 타입이 자동 선택됩니다.

| 파라미터 | 필수 | 설명 |
|---|:---:|---|
| `to` | ✅ | 수신자 전화번호 (예: `01012345678`) |
| `text` | ✅ | 발송할 메시지 내용 |
| `reqPhone` | ✅ | 발신번호 (슈어비즈에 사전 등록된 번호, 예: `15884640`) |
| `subject` | ⬜ | LMS 제목 — 메시지가 90바이트 초과로 LMS 전환될 때 사용 (기본값: `메시지`) |
| `reservedTime` | ⬜ | 예약 발송 시각 — `yyyyMMddhhmmss` 14자리 형식 (예: `20260420150000` = 2026-04-20 15:00:00). 미입력 시 즉시 발송 |

발송 결과는 슈어비즈 사이트의 **결과조회** 메뉴에서도 확인할 수 있습니다.
예약 발송 건의 취소는 슈어비즈 사이트의 **예약,결과 → 예약조회** 메뉴에서만 가능합니다.

---

## 자주 묻는 질문

<details>
<summary><strong>"인증 실패" 또는 "403" 오류가 발생해요</strong></summary>

- [ ] SecretKey를 올바르게 입력했는지 확인
- [ ] 현재 PC의 **공인 IP**가 슈어비즈에 등록되어 있는지 확인 (VPN/테더링/사무실 이전 시 IP 변경 가능)
- [ ] `SUREM_USER_CODE`가 **슈어엠 아이디**인지 확인
</details>

<details>
<summary><strong>"요청 성공인데 문자가 오지 않아요"</strong></summary>

발송 요청은 성공했지만 실제 수신이 되지 않는 경우, 아래 순서로 확인하세요.

1. 슈어비즈 **결과조회** 메뉴에서 실패 사유를 먼저 확인합니다.
2. 실패 사유는 아래와 같이 다양할 수 있습니다.
   - 발신번호 미등록 / 승인 대기
   - 수신자의 **080 수신거부** 등록
   - 이동통신사 스팸 필터링
   - 잘못된 수신번호 형식
</details>

<details>
<summary><strong>"메시지가 너무 깁니다" 오류가 발생해요</strong></summary>

메시지는 EUC-KR 기준 최대 **2,000바이트**까지 발송 가능합니다.
한글은 1글자 = 2바이트로 계산되므로 약 1,000자 정도가 한계입니다.
</details>

<details>
<summary><strong>Claude Desktop 커넥터 목록에 나타나지 않아요</strong></summary>

- [ ] Claude Desktop을 완전히 종료 후 재시작했는지 확인 (트레이 아이콘까지 종료)
- [ ] `claude_desktop_config.json` 파일의 JSON 문법이 올바른지 확인
- [ ] Node.js가 설치되어 있고 `node --version` 명령이 동작하는지 확인
</details>

<details>
<summary><strong>예약 발송을 취소하고 싶어요</strong></summary>

예약 발송의 **취소는 MCP에서 제공하지 않습니다.** 슈어비즈 사이트에서 직접 취소해야 합니다.

1. [슈어비즈(surebiz.co.kr)](https://surebiz.co.kr) 로그인
2. **예약,결과 → 예약조회** 메뉴 진입
3. 취소할 예약 건을 선택해 취소
</details>

<details>
<summary><strong>업데이트했는데 이전 버전처럼 동작해요</strong></summary>

Claude Desktop이 MCP 서버를 한 번 실행한 뒤에는 캐시된 버전을 계속 재사용합니다. 아래 순서대로 시도해보세요.

1. **(가장 간단)** 채팅창 **+ 버튼 → 커넥터** 에서 `surem-sms-mcp` 토글을 껐다가 다시 켜기
2. Claude Desktop을 완전 종료 후 재시작 (시스템 트레이 아이콘까지 확인)
3. npm 캐시 정리 후 재시작:
   ```powershell
   npm cache clean --force
   Remove-Item -Recurse -Force "$env:LOCALAPPDATA\npm-cache\_npx" -ErrorAction SilentlyContinue
   ```
</details>

---

## 라이센스

Copyright © 2026 SureM Co., Ltd. All Rights Reserved.

본 소프트웨어는 SureM Co., Ltd.의 독점 소유물입니다. 

---

## 문의

- **슈어엠 고객센터**: 1588-4640
- **이메일**: suremapp@surem.com
- **홈페이지**: [surebiz.co.kr](https://surebiz.co.kr)
