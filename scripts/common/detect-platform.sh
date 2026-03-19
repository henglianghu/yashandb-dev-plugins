#!/bin/bash
# 跨平台测试脚本 - 平台检测工具

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*)    echo "windows";;
        MINGW*)     echo "windows";;
        MSYS*)      echo "windows";;
        *)          echo "unknown";;
    esac
}

# 检测架构
detect_arch() {
    case "$(uname -m)" in
        x86_64)     echo "x86_64";;
        aarch64)    echo "aarch64";;
        arm64)      echo "aarch64";;
        i386)       echo "x86";;
        i686)       echo "x86";;
        *)          echo "unknown";;
    esac
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 打印状态信息
print_status() {
    echo "[信息] $1"
}

# 打印错误信息
print_error() {
    echo "[错误] $1" >&2
}

# 打印成功信息
print_success() {
    echo "[成功] $1"
}

# 打印警告信息
print_warning() {
    echo "[警告] $1"
}

# 带错误退出
exit_with_error() {
    print_error "$1"
    exit 1
}