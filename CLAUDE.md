# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本项目中工作时提供指导。

## 项目概述

这是一个 **YashanDB 的 Claude Code 插件** - YashanDB 是支持 Oracle 和 MySQL 兼容模式的关系型数据库。本插件为 AI 编码助手提供领域专业知识，以帮助进行 YashanDB 操作。

**这不是可构建的软件项目** - 没有构建、测试或 lint 命令。它是一个知识库，包含以下技能模块：

- `skills/yashandb/` - 核心数据库技能（SKILL.md + references 目录）
- `skills/yashandb-c/` - C 驱动（前置依赖）
- `skills/yashandb-go/` - Go 客户端库技能
- `skills/yashandb-gorm/` - GORM ORM 技能
- `skills/yashandb-jdbc/` - Java JDBC 客户端库技能
- `skills/yashandb-python/` - Python 客户端库技能
- `skills/yashandb-docker/` - Docker 自动化部署技能
- `skills/docker-installer/` - Docker 安装技能
- `skills/yashandb-app-builder/` - 应用构建技能

## 使用此插件

安装插件后，通过 slash 命令调用技能：

- **/yashandb**: Schema 设计、索引、查询调优、事务、锁
- **/yashandb-c**: C 驱动安装和配置（Go/Python 驱动的前置依赖）
- **/yashandb-go**: 使用 Go 语言连接 YashanDB
- **/yashandb-gorm**: 使用 GORM ORM 框架操作 YashanDB
- **/yashandb-python**: 使用 Python 连接 YashanDB
- **/yashandb-jdbc**: 使用 Java JDBC 连接 YashanDB
- **/yashandb-docker**: Linux/Windows 系统上自动化部署 YashanDB Docker 容器（支持 Docker Hub）
- **/docker-installer**: 在 Windows/Linux/macOS 上安装 Docker
- **/yashandb-app-builder**: 使用 YashanDB 构建应用程序

## 技能依赖关系

```
/yashandb-gorm ──► /yashandb-go ──┐
                          ├──► /yashandb-c
/yashandb-python ──────────────┘
```

Go 和 Python 驱动都依赖 C 驱动，GORM 依赖 Go 驱动。安装前请先执行 `/yashandb-c`。

## 关键工作流

进行任何 YashanDB 变更时：
1. 定义工作负载约束（读写比例、延迟目标、数据量、YashanDB 版本）
2. 阅读 `skills/yashandb/references/` 中的相关参考文档
3. 提出最小化改动方案，包含权衡分析
4. 用证据验证（`EXPLAIN`、执行计划分析、锁指标）
5. 包含回滚和发布后验证步骤

## 重要约定

- 主键设计：使用窄单调主键（`BIGINT` 配合 `SEQUENCE`），避免使用随机 UUID
- 字符集：`UTF-8`
- 尽量使用 `NOT NULL`，时间相关列优先使用 `TIMESTAMP` 而非 `DATE`
- 数值类型使用 `NUMBER`，变长字符串使用 `VARCHAR2`（Oracle 兼容）
- 复合索引列顺序：等值条件优先，然后是范围/排序（最左前缀规则）
- 默认隔离级别：`READ COMMITTED`
- 危险操作（drop/delete/truncate）前需人工明确确认

## 测试脚本

每个技能都有对应的测试脚本，位于 `scripts/` 目录下：

```
scripts/
├── common/                  # 公共工具
│   ├── detect-platform.sh  # 平台检测 (bash)
│   └── detect-platform.ps1 # 平台检测 (PowerShell)
├── yashandb-c/              # C 驱动测试
├── yashandb-go/             # Go 驱动测试
├── yashandb-gorm/           # GORM 测试
├── yashandb-jdbc/           # JDBC 测试
├── yashandb-python/         # Python 驱动测试
└── yashandb-docker/         # Docker 测试
```

运行测试：
- Linux/macOS: `bash scripts/yashandb-xxx/test-xxx.sh`
- Windows: `powershell -File scripts\yashandb-xxx\test-xxx.ps1`

## 参考文档

`skills/yashandb/references/` 中的关键参考：
- `primary-keys.md` - 使用序列的主键设计
- `data-types.md` - 数据类型选择
- `tablespaces.md` - 表空间管理
- `composite-indexes.md` - 复合索引设计
- `partitioning.md` - 表分区策略
- `explain-analysis.md` - 执行计划分析
- `isolation-levels.md` - 事务隔离级别
- `deadlocks.md` - 死锁预防
- `oracle-compatibility.md` - Oracle 语法支持