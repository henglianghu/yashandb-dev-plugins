# YashanDB Python 驱动测试脚本 (Windows PowerShell)

$ErrorActionPreference = "Continue"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$SCRIPT_DIR\..\common\detect-platform.ps1"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "YashanDB Python 驱动测试" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 测试 1: 检查 Python 安装
function Test-PythonInstalled {
    Write-Status "测试 1: 检查 Python 安装..."

    if (Test-Command python) {
        $version = python --version
        Write-Success "Python 已安装: $version"
        return $true
    } elseif (Test-Command python3) {
        $version = python3 --version
        Write-Success "Python 已安装: $version"
        return $true
    } else {
        Write-ErrorMsg "Python 未安装"
        return $false
    }
}

# 测试 2: 检查 Python 驱动
function Test-PythonDriver {
    Write-Status "测试 2: 检查 Python 驱动..."

    try {
        $result = python -c "import yasdb" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "yasdb 模块已安装"
            return $true
        }
    } catch {}

    try {
        $result = python -c "import yaspy" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "yaspy 模块已安装"
            return $true
        }
    } catch {}

    Write-Warning "Python 驱动 (yasdb/yaspy) 未安装"
    return $false
}

# 测试 3: 检查 C 驱动
function Test-CDriver {
    Write-Status "测试 3: 检查 C 驱动依赖..."

    $yascliPath = Get-Command yascli.dll -ErrorAction SilentlyContinue
    if ($yascliPath) {
        Write-Success "找到 C 驱动库"
        return $true
    } else {
        Write-Warning "未找到 C 驱动库"
        return $false
    }
}

# 运行所有测试
Write-Host "正在运行测试..."
Write-Host ""

$passed = 0
$failed = 0

if (Test-PythonInstalled) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-PythonDriver) { $passed++ } else { $failed++ }
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