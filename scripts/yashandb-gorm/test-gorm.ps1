# YashanDB GORM 测试脚本 (Windows PowerShell)

$ErrorActionPreference = "Continue"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$SCRIPT_DIR\..\common\detect-platform.ps1"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "YashanDB GORM 测试" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 测试 1: 检查 Go 安装
function Test-GoInstalled {
    Write-Status "测试 1: 检查 Go 安装..."

    if (Test-Command go) {
        $version = go version
        Write-Success "Go 已安装: $version"
        return $true
    } else {
        Write-ErrorMsg "Go 未安装"
        return $false
    }
}

# 测试 2: 检查 Go 驱动
function Test-GoDriver {
    Write-Status "测试 2: 检查 Go 驱动..."

    if (Test-Command go) {
        $module = go list -m github.com/yashan-technologies/yashandb-go 2>$null
        if ($module -match "yashandb-go") {
            Write-Success "yashandb-go 模块已安装"
            return $true
        } else {
            Write-ErrorMsg "yashandb-go 模块未安装"
            return $false
        }
    } else {
        Write-Warning "无法检查 - Go 未安装"
        return $false
    }
}

# 测试 3: 检查 GORM 适配器
function Test-GormAdapter {
    Write-Status "测试 3: 检查 GORM 适配器..."

    if (Test-Command go) {
        $module = go list -m github.com/yashan-technologies/yashandb-gorm 2>$null
        if ($module -match "yashandb-gorm") {
            Write-Success "yashandb-gorm 模块已安装"
            return $true
        } else {
            Write-ErrorMsg "yashandb-gorm 模块未安装"
            return $false
        }
    } else {
        Write-Warning "无法检查 - Go 未安装"
        return $false
    }
}

# 测试 4: 检查 C 驱动
function Test-CDriver {
    Write-Status "测试 4: 检查 C 驱动依赖..."

    $yascliPath = Get-Command yascli.dll -ErrorAction SilentlyContinue
    if ($yascliPath) {
        Write-Success "找到 C 驱动库"
        return $true
    } else {
        Write-ErrorMsg "未找到 C 驱动库"
        return $false
    }
}

# 运行所有测试
Write-Host "正在运行测试..."
Write-Host ""

$passed = 0
$failed = 0

if (Test-GoInstalled) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-GoDriver) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-GormAdapter) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-CDriver) { $passed++ } else { $failed++ }
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
    Write-Warning "部分测试失败"
    exit 1
}