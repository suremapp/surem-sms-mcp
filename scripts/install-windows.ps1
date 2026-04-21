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

$storePath     = "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json"
$installerPath = "$env:APPDATA\Claude\claude_desktop_config.json"

$storeDirExists     = Test-Path "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc"
$installerDirExists = Test-Path "$env:APPDATA\Claude"

$configPath = $null
$detectedBy = ""

# 방법 1: 실행 중인 Claude 프로세스의 실제 경로로 판별 (가장 신뢰도 높음)
$claudeProc = Get-Process -Name "Claude" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($claudeProc -and $claudeProc.Path) {
    if ($claudeProc.Path -like "*WindowsApps*" -or $claudeProc.Path -like "*Packages*") {
        $configPath = $storePath
        $detectedBy = "실행 중 Claude (Store 버전)"
    } else {
        $configPath = $installerPath
        $detectedBy = "실행 중 Claude (installer 버전)"
    }
}

# 방법 2: AppxPackage로 Store 버전 설치 여부 감지
if (-not $configPath) {
    $storeClaude = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue
    if ($storeClaude) {
        $configPath = $storePath
        $detectedBy = "AppxPackage (Store 버전 감지)"
    }
}

# 방법 3: Store 패키지 디렉터리 존재 여부 (Store 버전이 한 번이라도 실행된 적 있으면 존재)
if (-not $configPath -and $storeDirExists) {
    $configPath = $storePath
    $detectedBy = "Store 패키지 디렉터리 존재"
}

# 방법 4: installer 디렉터리 존재
if (-not $configPath -and $installerDirExists) {
    $configPath = $installerPath
    $detectedBy = "installer 디렉터리 존재"
}

if (-not $configPath) {
    Write-Host "      Claude Desktop을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host "      https://claude.ai/download 에서 설치 후 다시 실행해주세요." -ForegroundColor Red
    exit 1
}

Write-Host "      경로 확인: $configPath" -ForegroundColor Green
Write-Host "      (감지 방식: $detectedBy)" -ForegroundColor DarkGray

# 양쪽 경로가 모두 존재하면 stale 경로 경고
if ($storeDirExists -and $installerDirExists) {
    $stalePath = if ($configPath -eq $storePath) { $installerPath } else { $storePath }
    if (Test-Path $stalePath) {
        Write-Host ""
        Write-Host "[!] 사용되지 않는 다른 config 경로가 존재합니다:" -ForegroundColor Yellow
        Write-Host "    $stalePath" -ForegroundColor DarkGray
        Write-Host "    Claude Desktop 버전이 변경된 흔적으로 보입니다. 이 파일은 무시됩니다." -ForegroundColor DarkGray
    }
}

# Claude Desktop 실행 중이면 경고 (config 덮어쓰기 리스크)
if ($claudeProc) {
    Write-Host ""
    Write-Host "[!] Claude Desktop이 현재 실행 중입니다." -ForegroundColor Yellow
    Write-Host "    설치 완료 후 반드시 완전히 종료(트레이 아이콘까지) 후 재시작하세요." -ForegroundColor Yellow
    Write-Host ""
}

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

# 기존 config 읽기 (PSCustomObject로 통일)
if (Test-Path $configPath) {
    try {
        $content = Get-Content $configPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) {
            $existing = [PSCustomObject]@{}
        } else {
            $existing = $content | ConvertFrom-Json -ErrorAction Stop
        }
    } catch {
        Write-Host "      기존 config 파일 파싱 실패, 새로 생성합니다: $_" -ForegroundColor Yellow
        $existing = [PSCustomObject]@{}
    }
} else {
    $existing = [PSCustomObject]@{}
}

# mcpServers 프로퍼티가 없으면 PSCustomObject로 추가
# (hashtable @{} 로 추가하면 Add-Member의 Note Property가 저장되지 않는 PS 5.1 버그 있음)
$hasMcpServers = $existing.PSObject.Properties.Name -contains 'mcpServers'
if (-not $hasMcpServers) {
    $existing | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value ([PSCustomObject]@{})
}

# surem-sms-mcp 엔트리 추가/업데이트 (다른 MCP 설정은 그대로 유지)
$existing.mcpServers | Add-Member -MemberType NoteProperty -Name "surem-sms-mcp" -Value $mcpEntry -Force

$json = $existing | ConvertTo-Json -Depth 10

# Claude Desktop의 JSON 파서는 BOM을 거부하므로 BOM 없는 UTF-8로 저장
# Out-File -Encoding utf8 은 PS 5.1에서 BOM을 추가하므로 사용하지 않음
[System.IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))

# 저장 검증: 다시 읽어서 surem-sms-mcp 엔트리가 있는지 확인
try {
    $verify = Get-Content $configPath -Raw | ConvertFrom-Json -ErrorAction Stop
    if (-not $verify.mcpServers.'surem-sms-mcp') {
        Write-Host "      저장 검증 실패: surem-sms-mcp 엔트리가 저장되지 않았습니다." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "      저장 검증 실패: 파일을 다시 읽을 수 없습니다. $_" -ForegroundColor Red
    exit 1
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
