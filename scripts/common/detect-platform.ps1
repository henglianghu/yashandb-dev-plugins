# 平台检测工具 - Windows PowerShell 版本

# 检测操作系统
function Detect-OS {
    if ($IsWindows) {
        return "windows"
    } elseif ($IsMacOS) {
        return "macos"
    } elseif ($IsLinux) {
        return "linux"
    }
    return "unknown"
}

# 检测架构
function Detect-Arch {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "x86_64" }
        "ARM64" { return "aarch64" }
        "x86"   { return "x86" }
        default { return "unknown" }
    }
}

# 检查命令是否存在
function Test-Command {
    param(
        [string]$Command
    )
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# 打印状态信息
function Write-Status {
    param([string]$Message)
    Write-Host "[信息] $Message" -ForegroundColor Cyan
}

# 打印错误信息
function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[错误] $Message" -ForegroundColor Red
}

# 打印成功信息
function Write-Success {
    param([string]$Message)
    Write-Host "[成功] $Message" -ForegroundColor Green
}

# 打印警告信息
function Write-WarningMsg {
    param([string]$Message)
    Write-Host "[警告] $Message" -ForegroundColor Yellow
}

# 带错误退出
function Exit-WithError {
    param([string]$Message)
    Write-ErrorMsg $Message
    exit 1
}