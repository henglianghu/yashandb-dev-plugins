# YashanDB C 驱动安装测试脚本 (Windows PowerShell)

$ErrorActionPreference = "Continue"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$SCRIPT_DIR\..\common\detect-platform.ps1"

$OS = Detect-OS
$ARCH = Detect-Arch

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "YashanDB C 驱动安装测试" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "操作系统: $OS"
Write-Host "架构: $ARCH"
Write-Host ""

# 测试 1: 检查 C 驱动库是否存在
function Test-LibraryExists {
    Write-Status "测试 1: 检查 C 驱动库..."

    $yascliPath = Get-Command yascli.dll -ErrorAction SilentlyContinue
    if ($yascliPath) {
        Write-Success "找到 C 驱动库"
        Write-Host $yascliPath.Source
        return $true
    } else {
        Write-Warning "未找到 C 驱动库"
        return $false
    }
}

# 测试 2: 检查环境变量
function Test-EnvVars {
    Write-Status "测试 2: 检查环境变量..."

    $path = $env:PATH
    if ($path -match "yasdb") {
        Write-Success "PATH 包含 yasdb 引用"
        return $true
    } else {
        Write-Warning "PATH 可能不包含 yasdb 引用"
        return $false
    }
}

# 测试 3: 检查安装目录
function Test-InstallDir {
    Write-Status "测试 3: 检查安装目录..."

    $yasdbClient = if ($env:YASDB_CLIENT) { $env:YASDB_CLIENT } else { "$env:USERPROFILE\yasdb_client" }

    if (Test-Path $yasdbClient) {
        Write-Success "安装目录存在: $yasdbClient"
        return $true
    } else {
        Write-Warning "安装目录不存在: $yasdbClient"
        return $false
    }
}

# 运行所有测试
Write-Host "正在运行测试..."
Write-Host ""

$passed = 0
$failed = 0

if (Test-LibraryExists) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-EnvVars) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-InstallDir) { $passed++ } else { $failed++ }
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "测试摘要" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "通过: $passed"
Write-Host "失败: $failed"
Write-Host ""

if ($failed -eq 0) {
    Write-Success "所有测试通过！"
    exit 0
} else {
    Write-Warning "部分测试失败，请检查 C 驱动安装"
    exit 1
}