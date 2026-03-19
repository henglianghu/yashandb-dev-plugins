#!/bin/bash
# YashanDB JDBC 驱动测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/detect-platform.sh"

echo "========================================="
echo "YashanDB JDBC 驱动测试"
echo "========================================="
echo ""

# 测试 1: 检查 Java 安装
test_java_installed() {
    print_status "测试 1: 检查 Java 安装..."

    if command_exists java; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        print_success "Java 已安装: $JAVA_VERSION"
        return 0
    else
        print_error "Java 未安装"
        return 1
    fi
}

# 测试 2: 检查 Java 编译器
test_javac_installed() {
    print_status "测试 2: 检查 Java 编译器..."

    if command_exists javac; then
        JAVAC_VERSION=$(javac -version 2>&1)
        print_success "Java 编译器已安装: $JAVAC_VERSION"
        return 0
    else
        print_warning "Java 编译器 (javac) 未安装"
        return 1
    fi
}

# 测试 3: 检查 Maven 或 Gradle
test_build_tool() {
    print_status "测试 3: 检查构建工具..."

    if command_exists mvn; then
        MVN_VERSION=$(mvn --version 2>&1 | head -n 1)
        print_success "Maven 已安装: $MVN_VERSION"
        return 0
    elif command_exists gradle; then
        GRADLE_VERSION=$(gradle --version 2>&1 | head -n 1)
        print_success "Gradle 已安装: $GRADLE_VERSION"
        return 0
    else
        print_warning "Maven 和 Gradle 都未安装"
        return 1
    fi
}

# 运行所有测试
echo "正在运行测试..."
echo ""

通过=0
失败=0

if test_java_installed; then ((通过++)); else ((失败++)); fi
echo ""

if test_javac_installed; then ((通过++)); else ((失败++)); fi
echo ""

if test_build_tool; then ((通过++)); else ((失败++)); fi
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