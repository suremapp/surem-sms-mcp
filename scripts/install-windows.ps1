# 슈어엠 MCP 서버 Windows 자동 설치 스크립트
param(
    [Parameter(Mandatory=$true)]
    [string]$UserCode,

    [Parameter(Mandatory=$true)]
    [string]$SecretKey
)

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  슈어엠 MCP 서버 설치를 시작합니다" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 1. Node.js 설치 확인
Write-Host "[1/4] Node.js 설치 확인 중..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version 2>&1
    Write-Host "      Node.js $nodeVersion 확인됨" -ForegroundColor Green
} catch {
    Write-Host "      Node.js가 설치되어 있지 않습니다." -ForegroundColor Red
    Write-Host "      https://nodejs.org 에서 설치 후 다시 실행해주세요." -ForegroundColor Red
    exit 1
}

# 2. Claude Desktop 설정 파일 경로 탐색
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

# 3. 기존 설정 파일 읽기 및 병합
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

# 4. 완료
Write-Host "[4/4] 설치 완료!" -ForegroundColor Yellow
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  설치가 완료되었습니다!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor White
Write-Host "  1. Claude Desktop을 완전히 종료하세요" -ForegroundColor White
Write-Host "  2. Claude Desktop을 다시 실행하세요" -ForegroundColor White
Write-Host "  3. 채팅창에서 Connector 메뉴에 'surem-sms-mcp'가 보이면 성공!" -ForegroundColor White
Write-Host ""
Write-Host "사용 예시:" -ForegroundColor White
Write-Host "  '010-0000-0000로 안녕하세요 SMS 보내줘'" -ForegroundColor Gray
Write-Host ""
