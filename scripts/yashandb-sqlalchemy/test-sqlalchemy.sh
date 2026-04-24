#!/bin/bash
# YashanDB SQLAlchemy 测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/detect-platform.sh"

echo "========================================="
echo "YashanDB SQLAlchemy 测试"
echo "========================================="
echo ""

# 测试 1: 检查 Python 安装
test_python_installed() {
    print_status "测试 1: 检查 Python 安装..."

    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version)
        print_success "Python 已安装: $PYTHON_VERSION"
        return 0
    elif command_exists python; then
        PYTHON_VERSION=$(python --version)
        print_success "Python 已安装: $PYTHON_VERSION"
        return 0
    else
        print_error "Python 未安装"
        return 1
    fi
}

# 测试 2: 检查 SQLAlchemy 安装
test_sqlalchemy_installed() {
    print_status "测试 2: 检查 SQLAlchemy 安装..."

    PYTHON_CMD="python3"
    if ! command_exists python3; then
        PYTHON_CMD="python"
    fi

    # 检查 SQLAlchemy 1.4.x
    SQLALCHEMY_VERSION=$($PYTHON_CMD -c "import sqlalchemy; print(sqlalchemy.__version__)" 2>/dev/null)

    if [ -n "$SQLALCHEMY_VERSION" ]; then
        # 检查版本是否为 1.4.x
        if [[ "$SQLALCHEMY_VERSION" == 1.4* ]]; then
            print_success "SQLAlchemy 已安装: $SQLALCHEMY_VERSION"
            return 0
        else
            print_warning "SQLAlchemy 版本: $SQLALCHEMY_VERSION (需要 1.4.x)"
            return 1
        fi
    else
        print_error "SQLAlchemy 未安装"
        return 1
    fi
}

# 测试 3: 检查 yaspy 驱动
test_yaspy_driver() {
    print_status "测试 3: 检查 yaspy 驱动..."

    PYTHON_CMD="python3"
    if ! command_exists python3; then
        PYTHON_CMD="python"
    fi

    if $PYTHON_CMD -c "import yaspy" 2>/dev/null; then
        print_success "yaspy 模块已安装"
        return 0
    else
        print_error "yaspy 模块未安装"
        return 1
    fi
}

# 测试 4: 检查 yashandb-sqlalchemy 方言
test_yashandb_sqlalchemy() {
    print_status "测试 4: 检查 yashandb-sqlalchemy 方言..."

    PYTHON_CMD="python3"
    if ! command_exists python3; then
        PYTHON_CMD="python"
    fi

    if $PYTHON_CMD -c "import yashandb_sqlalchemy" 2>/dev/null; then
        print_success "yashandb-sqlalchemy 模块已安装"
        return 0
    else
        print_error "yashandb-sqlalchemy 模块未安装"
        return 1
    fi
}

# 测试 5: 检查 C 驱动依赖
test_c_driver() {
    print_status "测试 5: 检查 C 驱动依赖..."

    case "$(detect_os)" in
        linux|macos)
            if ldconfig -p 2>/dev/null | grep -q "libyascli"; then
                print_success "找到 C 驱动库 (libyascli)"
                return 0
            else
                print_warning "未找到 C 驱动库 (libyascli)"
                return 1
            fi
            ;;
        windows)
            if where.exe yascli.dll 2>/dev/null | grep -q "yascli"; then
                print_success "找到 C 驱动库 (yascli.dll)"
                return 0
            else
                print_warning "未找到 C 驱动库 (yascli.dll)"
                return 1
            fi
            ;;
    esac
}

# 测试 6: 检查 yashandb-sqlalchemy 方言注册
test_dialect_registered() {
    print_status "测试 6: 检查 yashandb 方言注册..."

    PYTHON_CMD="python3"
    if ! command_exists python3; then
        PYTHON_CMD="python"
    fi

    # 检查方言是否注册
    if $PYTHON_CMD -c "from sqlalchemy.dialects import registry; print(registry.contains('yashandb', 'yaspy'))" 2>/dev/null | grep -q "True"; then
        print_success "yashandb 方言已注册"
        return 0
    else
        # 尝试直接导入
        if $PYTHON_CMD -c "from yashandb_sqlalchemy import yaspy" 2>/dev/null; then
            print_success "yashandb 方言可正常导入"
            return 0
        else
            print_warning "yashandb 方言可能未正确注册"
            return 1
        fi
    fi
}

# 运行所有测试
echo "正在运行测试..."
echo ""

passed=0
failed=0

if test_python_installed; then ((passed++)); else ((failed++)); fi
echo ""

if test_sqlalchemy_installed; then ((passed++)); else ((failed++)); fi
echo ""

if test_yaspy_driver; then ((passed++)); else ((failed++)); fi
echo ""

if test_yashandb_sqlalchemy; then ((passed++)); else ((failed++)); fi
echo ""

if test_c_driver; then ((passed++)); else ((failed++)); fi
echo ""

if test_dialect_registered; then ((passed++)); else ((failed++)); fi
echo ""

echo "========================================="
echo "测试摘要"
echo "========================================="
echo "passed: $passed"
echo "failed: $failed"
echo ""

if [ $failed -eq 0 ]; then
    print_success "所有测试passed！"
    echo ""
    echo "YashanDB SQLAlchemy 环境已就绪，可以使用以下连接字符串："
    echo "  yashandb+yaspy://用户名:密码@主机:端口/数据库名"
    exit 0
else
    print_warning "部分测试failed，请检查上述错误"
    exit 1
fi
