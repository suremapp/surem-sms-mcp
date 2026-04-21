# 슈어엠 SMS MCP 서버 Windows 자동 설치 스크립트
param(
    [string]$UserCode,
    [string]$SecretKey
)

# ===== 1. 인사 =====
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  슈어엠 SMS MCP 서버 설치" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "이 스크립트는 Claude Desktop 설정 파일에" -ForegroundColor White
Write-Host "슈어엠 SMS MCP를 자동으로 추가합니다." -ForegroundColor White
Write-Host ""

# ===== 2. 자격증명 입력 안내 =====
if (-not $UserCode -or -not $SecretKey) {
    Write-Host "── 설치에 필요한 정보 ────────────────────" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1) 슈어엠 아이디 (UserCode)" -ForegroundColor White
    Write-Host "   슈어비즈(surebiz.co.kr) 로그인 시 사용하는 아이디" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "2) REST API SecretKey" -ForegroundColor White
    Write-Host "   발급: surebiz.co.kr 로그인" -ForegroundColor DarkGray
    Write-Host "     -> 기본정보 -> 내정보 -> 최하단 'REST API 인증키' 메뉴" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[ 사전 등록 필수 ]" -ForegroundColor Yellow
    Write-Host "  - IP 등록  : surebiz 기본정보 -> 고객지원 -> IP관리" -ForegroundColor DarkGray
    Write-Host "  - 발신번호 : surebiz 기본정보 -> 발신번호" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "──────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host ""
}

if (-not $UserCode) {
    $UserCode = Read-Host "[입력] 슈어엠 아이디(UserCode)"
}
if (-not $SecretKey) {
    $SecretKey = Read-Host "[입력] REST API SecretKey"
}

if (-not $UserCode -or -not $SecretKey) {
    Write-Host ""
    Write-Host "UserCode 또는 SecretKey가 비어 있어 설치를 중단합니다." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "입력 확인:" -ForegroundColor White
Write-Host "  UserCode  : $UserCode" -ForegroundColor Gray
$secretPreview = if ($SecretKey.Length -le 6) { "***" } else { $SecretKey.Substring(0, 4) + "***" + $SecretKey.Substring($SecretKey.Length - 2) }
Write-Host "  SecretKey : $secretPreview" -ForegroundColor Gray
Write-Host ""

# ===== 3. Node.js 설치 확인 =====
Write-Host "[1/4] Node.js 설치 확인 중..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version 2>&1
    Write-Host "      Node.js $nodeVersion 확인됨" -ForegroundColor Green
} catch {
    Write-Host "      Node.js가 설치되어 있지 않습니다." -ForegroundColor Red
    Write-Host "      https://nodejs.org 에서 설치 후 다시 실행해주세요." -ForegroundColor Red
    exit 1
}

# ===== 4. Claude Desktop 설정 파일 경로 탐색 =====
Write-Host "[2/4] Claude Desktop 설정 파일 경로 탐색 중..." -ForegroundColor Yellow

$configPaths = @(
    "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json",
    "$env:APPDATA\Claude\claude_desktop_config.json"
)

$configPath = $null
foreach ($path in $configPaths) {
    if (Test-Path (Split-Path $path)) {
        $configPath = $path
        break
    }
}

if (-not $configPath) {
    Write-Host "      Claude Desktop을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host "      https://claude.ai/download 에서 설치 후 다시 실행해주세요." -ForegroundColor Red
    exit 1
}

Write-Host "      경로 확인: $configPath" -ForegroundColor Green

# ===== 5. 기존 설정 파일 읽기 및 병합 =====
Write-Host "[3/4] 설정 파일 업데이트 중..." -ForegroundColor Yellow

$mcpEntry = @{
    command = "npx"
    args    = @("-y", "surem-sms-mcp")
    env     = @{
        SUREM_USER_CODE = $UserCode
        SUREM_SECRET_KEY = $SecretKey
    }
}

if (Test-Path $configPath) {
    # 기존 파일이 있으면 병합
    $existing = Get-Content $configPath -Raw | ConvertFrom-Json
    if (-not $existing.mcpServers) {
        $existing | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value @{}
    }
    $existing.mcpServers | Add-Member -MemberType NoteProperty -Name "surem-sms-mcp" -Value $mcpEntry -Force
    $existing | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding utf8
} else {
    # 새로 생성
    $newConfig = @{
        mcpServers = @{
            "surem-sms-mcp" = $mcpEntry
        }
    }
    $newConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding utf8
}

Write-Host "      설정 파일 업데이트 완료" -ForegroundColor Green

# ===== 6. 완료 =====
Write-Host "[4/4] 설치 완료!" -ForegroundColor Yellow
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  설치가 완료되었습니다!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor White
Write-Host "  1. Claude Desktop을 완전히 종료하세요" -ForegroundColor White
Write-Host "     (시스템 트레이에서 실행 중이라면 트레이 아이콘 -> 종료)" -ForegroundColor DarkGray
Write-Host "  2. Claude Desktop을 다시 실행하세요" -ForegroundColor White
Write-Host "  3. 채팅창 왼쪽 아래 + 버튼 -> 커넥터 메뉴에서" -ForegroundColor White
Write-Host "     'surem-sms-mcp'가 켜져 있는지 확인하세요" -ForegroundColor White
Write-Host ""
Write-Host "사용 예시:" -ForegroundColor White
Write-Host "  '발신번호 15884640으로 010-0000-0000에 안녕하세요 SMS 보내줘'" -ForegroundColor Gray
Write-Host "  ※ 발신번호는 슈어비즈에 사전 등록된 번호만 사용 가능합니다" -ForegroundColor DarkGray
Write-Host ""
Write-Host "설정 파일 위치:" -ForegroundColor White
Write-Host "  $configPath" -ForegroundColor Gray
Write-Host ""
