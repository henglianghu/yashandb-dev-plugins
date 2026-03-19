#!/bin/bash
# YashanDB Go 驱动测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/detect-platform.sh"

echo "========================================="
echo "YashanDB Go 驱动测试"
echo "========================================="
echo ""

# 测试 1: 检查 Go 安装
test_go_installed() {
    print_status "测试 1: 检查 Go 安装..."

    if command_exists go; then
        GO版本=$(go version)
        print_success "Go 已安装: $GO版本"
        return 0
    else
        print_error "Go 未安装"
        return 1
    fi
}

# 测试 2: 检查 Go 模块
test_go_module() {
    print_status "测试 2: 检查 yasdb-go 模块是否已安装..."

    if command_exists go; then
        if go list -m github.com/yashan-technologies/yashandb-go 2>/dev/null | grep -q "yashandb-go"; then
            print_success "yashandb-go 模块已安装"
            return 0
        else
            print_warning "yashandb-go 模块不在 Go 模块缓存中"
            return 1
        fi
    else
        print_warning "无法检查 - Go 未安装"
        return 1
    fi
}

# 测试 3: 检查 C 驱动依赖
test_c_driver() {
    print_status "测试 3: 检查 C 驱动依赖..."

    case "$(detect_os)" in
        linux|macos)
            if ldconfig -p 2>/dev/null | grep -q "libyascli"; then
                print_success "找到 C 驱动库"
                return 0
            else
                print_error "未找到 C 驱动库 - Go 驱动需要此依赖"
                return 1
            fi
            ;;
        windows)
            if where.exe yascli.dll 2>/dev/null | grep -q "yascli"; then
                print_success "找到 C 驱动库"
                return 0
            else
                print_error "未找到 C 驱动库 - Go 驱动需要此依赖"
                return 1
            fi
            ;;
    esac
}

# 运行所有测试
echo "正在运行测试..."
echo ""

通过=0
失败=0

if test_go_installed; then ((通过++)); else ((失败++)); fi
echo ""

if test_go_module; then ((通过++)); else ((失败++)); fi
echo ""

if test_c_driver; then ((通过++)); else ((失败++)); fi
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
    print_warning "部分测试失败"
    exit 1
fi