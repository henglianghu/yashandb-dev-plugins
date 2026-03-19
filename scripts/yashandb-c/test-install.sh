#!/bin/bash
# YashanDB C 驱动安装测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/detect-platform.sh"

操作系统=$(detect_os)
架构=$(detect_arch)

echo "========================================="
echo "YashanDB C 驱动安装测试"
echo "========================================="
echo "操作系统: $操作系统"
echo "架构: $架构"
echo ""

# 测试 1: 检查 C 驱动库是否存在
test_library_exists() {
    print_status "测试 1: 检查 C 驱动库..."

    case "$操作系统" in
        linux|macos)
            if ldconfig -p 2>/dev/null | grep -q "libyascli"; then
                print_success "找到 C 驱动库"
                ldconfig -p | grep libyascli
                return 0
            else
                print_warning "未在 ldconfig 中找到 C 驱动库"
                return 1
            fi
            ;;
        windows)
            if where.exe yascli.dll 2>/dev/null | grep -q "yascli"; then
                print_success "找到 C 驱动库"
                where.exe yascli.dll
                return 0
            else
                print_warning "未找到 C 驱动库"
                return 1
            fi
            ;;
    esac
}

# 测试 2: 检查环境变量
test_env_vars() {
    print_status "测试 2: 检查环境变量..."

    case "$操作系统" in
        linux|macos)
            if [ -n "$LD_LIBRARY_PATH" ]; then
                print_success "LD_LIBRARY_PATH 已设置: $LD_LIBRARY_PATH"
                return 0
            else
                print_warning "LD_LIBRARY_PATH 未设置"
                return 1
            fi
            ;;
        windows)
            if [ -n "$PATH" ]; then
                print_success "PATH 已设置"
                return 0
            else
                print_warning "PATH 未设置"
                return 1
            fi
            ;;
    esac
}

# 测试 3: 检查安装目录
test_install_dir() {
    print_status "测试 3: 检查安装目录..."

    case "$操作系统" in
        linux|macos)
            YASDB_CLIENT="${YASDB_CLIENT:-$HOME/yasdb_client}"
            ;;
        windows)
            YASDB_CLIENT="${YASDB_CLIENT:-$env:USERPROFILE\yasdb_client}"
            ;;
    esac

    if [ -d "$YASDB_CLIENT" ]; then
        print_success "安装目录存在: $YASDB_CLIENT"
        return 0
    else
        print_warning "安装目录不存在: $YASDB_CLIENT"
        return 1
    fi
}

# 运行所有测试
echo "正在运行测试..."
echo ""

通过=0
失败=0

if test_library_exists; then ((通过++)); else ((失败++)); fi
echo ""

if test_env_vars; then ((通过++)); else ((失败++)); fi
echo ""

if test_install_dir; then ((通过++)); else ((失败++)); fi
echo ""

echo "========================================="
echo "测试摘要"
echo "========================================="
echo "通过: $通过"
echo "失败: $失败"
echo ""

if [ $失败 -eq 0 ]; then
    print_success "所有测试通过！"
    exit 0
else
    print_warning "部分测试失败，请检查 C 驱动安装"
    exit 1
fi