#!/bin/bash
# 슈어엠 SMS MCP 서버 Mac 자동 설치 스크립트

USER_CODE=$1
SECRET_KEY=$2

# ===== 1. 인사 =====
echo ""
echo "=========================================="
echo "  슈어엠 SMS MCP 서버 설치"
echo "=========================================="
echo ""
echo "이 스크립트는 Claude Desktop 설정 파일에"
echo "슈어엠 SMS MCP를 자동으로 추가합니다."
echo ""

# ===== 2. 자격증명 입력 안내 =====
if [ -z "$USER_CODE" ] || [ -z "$SECRET_KEY" ]; then
    echo "── 설치에 필요한 정보 ────────────────────"
    echo ""
    echo "1) 슈어엠 아이디 (UserCode)"
    echo "   슈어비즈(surebiz.co.kr) 로그인 시 사용하는 아이디"
    echo ""
    echo "2) REST API SecretKey"
    echo "   발급: surebiz.co.kr 로그인"
    echo "     → 기본정보 → 내정보 → 최하단 'REST API 인증키' 메뉴"
    echo ""
    echo "[ 사전 등록 필수 ]"
    echo "  - IP 등록  : surebiz 기본정보 → 고객지원 → IP관리"
    echo "  - 발신번호 : surebiz 기본정보 → 발신번호"
    echo ""
    echo "──────────────────────────────────────────"
    echo ""
fi

# curl | bash -s 로 실행 시 stdin이 막혀있으므로 /dev/tty 에서 읽기
if [ -z "$USER_CODE" ]; then
    read -r -p "[입력] 슈어엠 아이디(UserCode): " USER_CODE </dev/tty
fi
if [ -z "$SECRET_KEY" ]; then
    read -r -p "[입력] REST API SecretKey: " SECRET_KEY </dev/tty
fi

if [ -z "$USER_CODE" ] || [ -z "$SECRET_KEY" ]; then
    echo ""
    echo "UserCode 또는 SecretKey가 비어 있어 설치를 중단합니다."
    exit 1
fi

# SecretKey 미리보기 (앞 4자리 + *** + 뒤 2자리)
if [ ${#SECRET_KEY} -le 6 ]; then
    SECRET_PREVIEW="***"
else
    SECRET_PREVIEW="${SECRET_KEY:0:4}***${SECRET_KEY: -2}"
fi

echo ""
echo "입력 확인:"
echo "  UserCode  : $USER_CODE"
echo "  SecretKey : $SECRET_PREVIEW"
echo ""

# ===== 3. Node.js 확인 =====
echo "[1/4] Node.js 설치 확인 중..."
if ! command -v node &> /dev/null; then
    echo "      Node.js가 설치되어 있지 않습니다."
    echo "      https://nodejs.org 에서 설치 후 다시 실행해주세요."
    exit 1
fi
echo "      Node.js $(node --version) 확인됨"

# ===== 4. Claude Desktop 경로 확인 =====
echo "[2/4] Claude Desktop 설정 파일 경로 탐색 중..."
CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_PATH="$CONFIG_DIR/claude_desktop_config.json"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "      Claude Desktop을 찾을 수 없습니다."
    echo "      https://claude.ai/download 에서 설치 후 다시 실행해주세요."
    exit 1
fi
echo "      경로 확인: $CONFIG_PATH"

# ===== 5. 설정 파일 업데이트 =====
echo "[3/4] 설정 파일 업데이트 중..."

MCP_CONFIG=$(cat <<EOF
{
  "mcpServers": {
    "surem-sms-mcp": {
      "command": "npx",
      "args": ["-y", "surem-sms-mcp"],
      "env": {
        "SUREM_USER_CODE": "$USER_CODE",
        "SUREM_SECRET_KEY": "$SECRET_KEY"
      }
    }
  }
}
EOF
)

if [ -f "$CONFIG_PATH" ]; then
    # 기존 파일에 병합 (python3 사용)
    python3 - <<PYEOF
import json

with open('$CONFIG_PATH', 'r') as f:
    config = json.load(f)

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['surem-sms-mcp'] = {
    'command': 'npx',
    'args': ['-y', 'surem-sms-mcp'],
    'env': {
        'SUREM_USER_CODE': '$USER_CODE',
        'SUREM_SECRET_KEY': '$SECRET_KEY'
    }
}

with open('$CONFIG_PATH', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
PYEOF
else
    echo "$MCP_CONFIG" > "$CONFIG_PATH"
fi

echo "      설정 파일 업데이트 완료"

# ===== 6. 완료 =====
echo "[4/4] 설치 완료!"
echo ""
echo "=========================================="
echo "  설치가 완료되었습니다!"
echo "=========================================="
echo ""
echo "다음 단계:"
echo "  1. Claude Desktop을 완전히 종료하세요 (Cmd+Q)"
echo "  2. Claude Desktop을 다시 실행하세요"
echo "  3. 채팅창 왼쪽 아래 + 버튼 → 커넥터 메뉴에서"
echo "     'surem-sms-mcp'가 켜져 있는지 확인하세요"
echo ""
echo "사용 예시:"
echo "  '발신번호 15884640으로 010-0000-0000에 안녕하세요 SMS 보내줘'"
echo "  ※ 발신번호는 슈어비즈에 사전 등록된 번호만 사용 가능합니다"
echo ""
echo "설정 파일 위치:"
echo "  $CONFIG_PATH"
echo ""
