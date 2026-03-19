# YashanDB Docker 部署测试脚本 (Windows PowerShell)

$ErrorActionPreference = "Continue"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$SCRIPT_DIR\..\common\detect-platform.ps1"

$OS = Detect-OS
$ARCH = Detect-Arch

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "YashanDB Docker 部署测试" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "操作系统: $OS"
Write-Host "架构: $ARCH"
Write-Host ""

# 测试 1: 检查 Docker 安装
function Test-DockerInstalled {
    Write-Status "测试 1: 检查 Docker 安装..."

    if (Test-Command docker) {
        $version = docker --version
        Write-Success "Docker 已安装: $version"
        return $true
    } else {
        Write-ErrorMsg "Docker 未安装"
        return $false
    }
}

# 测试 2: 检查 Docker 守护进程
function Test-DockerDaemon {
    Write-Status "测试 2: 检查 Docker 守护进程..."

    $result = docker ps 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker 守护进程正在运行"
        return $true
    } else {
        Write-ErrorMsg "Docker 守护进程未运行或无法访问"
        return $false
    }
}

# 测试 3: 检查平台支持 (Windows 上的 Docker 需要 WSL2)
function Test-PlatformSupport {
    Write-Status "测试 3: 检查平台支持..."

    # Windows 上的 Docker 需要 WSL2
    if ($OS -eq "windows") {
        # 检查 WSL2 是否可用
        $wsl = wsl --list --verbose 2>$null
        if ($wsl) {
            Write-Success "WSL2 可用于 Docker"
            return $true
        } else {
            Write-Warning "Windows 上的 Docker 需要 WSL2"
            return $false
        }
    } elseif ($OS -eq "linux") {
        if ($ARCH -eq "x86_64" -or $ARCH -eq "aarch64") {
            Write-Success "平台支持: $OS-$ARCH"
            return $true
        } else {
            Write-ErrorMsg "不支持的平台: $OS-$ARCH"
            return $false
        }
    } else {
        Write-ErrorMsg "不支持 Docker 部署的平台"
        return $false
    }
}

# 测试 4: 检查磁盘空间
function Test-DiskSpace {
    Write-Status "测试 4: 检查可用磁盘空间..."

    $drive = Get-PSDrive C
    $availableGB = [math]::Round($drive.Free / 1GB, 0)

    if ($availableGB -ge 5) {
        Write-Success "磁盘空间充足: ${availableGB}GB"
        return $true
    } else {
        Write-Warning "磁盘空间不足: ${availableGB}GB (建议: 5GB+)"
        return $false
    }
}

# 测试 5: 检查 Docker Hub 连接（可选）
function Test-DockerHub {
    Write-Status "测试 5: 检查 Docker Hub 连接..."

    $result = docker pull hello-world 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker Hub 连接正常"
        # 清理测试镜像
        docker rmi hello-world >$null 2>&1
        return $true
    } else {
        Write-Warning "无法连接 Docker Hub，将使用离线导入方式"
        return $false
    }
}

# 运行所有测试
Write-Host "正在运行测试..."
Write-Host ""

$passed = 0
$failed = 0

if (Test-DockerInstalled) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-DockerDaemon) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-PlatformSupport) { $passed++ } else { $failed++ }
Write-Host ""

if (Test-DiskSpace) { $passed++ } else { $failed++ }
Write-Host ""

# Docker Hub 连接测试（可选，不计入失败）
Test-DockerHub
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "测试摘要" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "通过: $passed"
Write-Host "失败: $failed"
Write-Host ""

if ($failed -eq 0) {
    Write-Success "所有测试通过！"
    Write-Host ""
    Write-Host "下一步：执行部署脚本" -ForegroundColor Yellow
    Write-Host '  powershell -File scripts\yashandb-docker\deploy-yashandb.ps1' -ForegroundColor Gray
    exit 0
} else {
    Write-Warning "部分测试失败"
    exit 1
}