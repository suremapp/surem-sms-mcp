#!/bin/bash
# 슈어엠 MCP 서버 Mac 자동 설치 스크립트

USER_CODE=$1
SECRET_KEY=$2

if [ -z "$USER_CODE" ] || [ -z "$SECRET_KEY" ]; then
    echo "사용법: ./install-mac.sh [슈어엠_아이디] [API_키]"
    exit 1
fi

echo ""
echo "====================================="
echo "  슈어엠 MCP 서버 설치를 시작합니다"
echo "====================================="
echo ""

# 1. Node.js 확인
echo "[1/4] Node.js 설치 확인 중..."
if ! command -v node &> /dev/null; then
    echo "      Node.js가 설치되어 있지 않습니다."
    echo "      https://nodejs.org 에서 설치 후 다시 실행해주세요."
    exit 1
fi
echo "      Node.js $(node --version) 확인됨"

# 2. Claude Desktop 경로 확인
echo "[2/4] Claude Desktop 설정 파일 경로 탐색 중..."
CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_PATH="$CONFIG_DIR/claude_desktop_config.json"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "      Claude Desktop을 찾을 수 없습니다."
    echo "      https://claude.ai/download 에서 설치 후 다시 실행해주세요."
    exit 1
fi
echo "      경로 확인: $CONFIG_PATH"

# 3. 설정 파일 업데이트
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

# 4. 완료
echo "[4/4] 설치 완료!"
echo ""
echo "====================================="
echo "  설치가 완료되었습니다!"
echo "====================================="
echo ""
echo "다음 단계:"
echo "  1. Claude Desktop을 완전히 종료하세요 (Cmd+Q)"
echo "  2. Claude Desktop을 다시 실행하세요"
echo "  3. 채팅창에서 Connector 메뉴에 'surem-sms-mcp'가 보이면 성공!"
echo ""
echo "사용 예시:"
echo "  '010-0000-0000로 안녕하세요 SMS 보내줘'"
echo ""
