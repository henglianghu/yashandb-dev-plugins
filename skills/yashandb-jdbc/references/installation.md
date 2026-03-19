# JDBC 驱动安装详细指南

## 检查环境

```bash
# 检查 Java 版本
java -version

# 检查 JDK 安装路径
echo $JAVA_HOME  # Linux/Mac
echo %JAVA_HOME%  # Windows

# 检查 Maven
mvn --version

# 检查 Gradle
gradle --version
```

## 安装 JDK

### Windows

```powershell
winget install Oracle.JDK.17 --accept-source-agreements --accept-package-agreements
```

或安装 OpenJDK：

```powershell
winget install EclipseAdoptium.Temurin.17.JDK
```

### Linux

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install openjdk-17-jdk

# CentOS/RHEL
sudo yum install java-17-openjdk java-17-openjdk-devel
```

### macOS

```bash
# 使用 Homebrew 安装
brew install openjdk@17

# 创建符号链接
sudo ln -sfn $(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

# 配置环境变量
echo 'export JAVA_HOME=$(/usr/libexec/java_home)' >> ~/.zshrc
source ~/.zshrc
```

## JDK 版本要求

| JDK 版本 | 支持情况 |
|----------|----------|
| JDK 1.8 (Java 8) | ✅ 支持 |
| JDK 9-16 | ✅ 支持 |
| JDK 17+ | ✅ 推荐使用 LTS 版本 |

## 安装 JDBC 驱动

### 使用 Maven（推荐）

在项目的 `pom.xml` 中添加 YashanDB JDBC 依赖：

```xml
<dependency>
    <groupId>com.yashandb</groupId>
    <artifactId>yashandb-jdbc</artifactId>
    <version>1.6.1</version>
</dependency>
```

> **注意**：版本号 `1.6.1` 为示例版本，请访问 [Maven Central](https://mvnrepository.com/artifact/com.yashandb/yashandb-jdbc) 获取最新版本。

### 使用 Gradle

```groovy
dependencies {
    implementation 'com.yashandb:yashandb-jdbc:1.6.1'
}
```

### 手动安装（离线）

1. 从 [YashanDB 官网下载中心](https://download.yashandb.com) 获取 JDBC 驱动 jar 包
2. 将 jar 包添加到项目：
   - **IDE**：在 IDEA 中选择「File」→「Project Structure」→「Libraries」，添加 jar 包
   - **命令行**：使用 `-cp` 参数指定 classpath