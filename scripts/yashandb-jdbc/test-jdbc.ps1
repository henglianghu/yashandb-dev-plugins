# YashanDB JDBC 驱动测试脚本 (Windows PowerShell)

$ErrorActionPreference = "Continue"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$SCRIPT_DIR\..\common\detect-platform.ps1"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "YashanDB JDBC 驱动测试" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 测试 1: 检查 Java 安装
function Test-JavaInstalled {
    Write-Status "测试 1: 检查 Java 安装..."

    if (Test-Command java) {
        $version = java -version 2>&1 | Select-Object -First 1
        Write-Success "Java 已安装: $version"
        return $true
    } else {
        Write-ErrorMsg "Java 未安装"
        return $false
    }
}

# 测试 2: 检查 Java 编译器
function Test-JavacInstalled {
    Write-Status "测试 2: 检查 Java 编译器..."

    if (Test-Command javac) {
        $version = javac -version 2>&1
        Write-Success "Java 编译器已安装: $version"
        return $true
    } else {
        Write-Warning "Java 编译器 (javac) 未安装"
        return $false
    }
}

# 测试 3: 检查 Maven 或 Gradle
function Test-BuildTool {
    Write-Status "测试 3: 检查构建工具..."

    if (Test-Command mvn) {
        $version = mvn --version 2>&1 | Select-Object -First 1
        Write-Success "Maven 已安装: $version"
        return $true
    } elseif (Test-Command gradle) {
        $version = gradle --version 2>&1 | Select-Object -First 1
        Write-Success "Gradle 已安装: $version"
        return $true
    } else {
        Write-Warning "Maven 和 Gradle 都未安装"
        return $false
    }
}

# 运行所有测试
Write-Host "正在运行测试..."
Write-Host ""

$passed = 0
$failed = 0

if (Test-JavaInstalled) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-JavacInstalled) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-BuildTool) { $passed++ } else { $failed++ }
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