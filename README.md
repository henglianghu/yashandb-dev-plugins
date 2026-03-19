# YashanDB Skills Plugin

YashanDB 数据库技能插件，为 Claude Code 提供 YashanDB 领域专业知识。

## 安装

### 方式一：npx一键安装

```bash
npx skills add https://github.com/yashan-technologies/yashandb-dev-plugins/tree/main/skills -- yashandb
```

### 方式二：类插件市场安装

```bash
# 添加仓库地址到marketplace
/plugins marketplace add git@github.com:yashan-technologies/yashandb-dev-plugins.git
# 或配置文件新增
`"yashandb-dev": {
      "source": {
        "source": "git",
        "url": "https://github.com/yashan-technologies/yashandb-dev-plugins.git"
      }
    },`

# 安装插件
/plugins add yashandb-dev
```

### 方式三：本地开发安装

```bash
# 克隆仓库
git clone https://github.com/yashan-technologies/yashandb-dev-plugins.git

# 安装插件
/plugins add /path/to/yashandb-dev
```

### 方式四：直接下载安装

```bash
# 下载插件包
curl -L -o plugin.tar.gz https://github.com/yashan-technologies/yashandb-dev-plugins/archive/refs/heads/main.tar.gz

# 解压
tar -xzf plugin.tar.gz

# 安装
/plugins add ./yashandb-dev-main
```

## 验证安装

安装完成后，在 Claude Code 中输入：

```
/yashandb
```

如果看到 YashanDB 技能菜单，说明安装成功。

## 可用技能

### /yashandb
核心数据库技能 - Schema 设计、索引优化、查询调优、事务、锁。

### /yashandb-c
C 驱动安装 - 安装和配置 YashanDB C 驱动（libyascli），Go 和 Python 驱动的前置依赖。

### /yashandb-go
Go 驱动开发环境搭建 - 使用 Go 语言连接 YashanDB。

### /yashandb-gorm
GORM ORM 使用指南 - 使用 GORM 框架操作 YashanDB。

### /yashandb-python
Python 驱动开发环境搭建 - 使用 Python 连接 YashanDB，包括 yaspy 和 yasdb 驱动。

### /yashandb-jdbc
Java JDBC 开发环境搭建 - 使用 Java JDBC 连接 YashanDB。

### /yashandb-docker
Docker 自动化部署 - 在 Linux 或 Windows 上自动化部署 YashanDB Docker 容器（支持 Docker Hub 拉取）。

### /docker-installer
Docker 安装 - 在 Windows、Linux（Ubuntu/Debian/CentOS/Fedora）或 macOS 环境下安装和配置 Docker。

### /yashandb-app-builder
应用构建 - 使用 YashanDB 构建应用程序，提供应用模板和最佳实践。

## 技能依赖关系

```
/yashandb-gorm ──► /yashandb-go ──┐
                            ├──► /yashandb-c
/yashandb-python ──────────────┘
```

Go 和 Python 驱动都依赖 C 驱动，GORM 依赖 Go 驱动。请先安装 `/yashandb-c`。

## 快速开始

```bash
/yashandb-c       # 先安装 C 驱动（Go/Python 的前置依赖）
/yashandb         # 获取数据库设计建议
/yashandb-go      # 搭建 Go 开发环境
/yashandb-gorm    # 使用 GORM ORM
/yashandb-python  # 搭建 Python 开发环境
/yashandb-jdbc    # 搭建 Java 开发环境
/yashandb-docker  # 部署 Docker 容器
/docker-installer # 安装 Docker（如未安装）
/yashandb-app-builder # 构建应用程序
```

## 许可证

Apache-2.0
