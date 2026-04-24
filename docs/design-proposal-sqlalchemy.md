# YashanDB SQLAlchemy 技能与模板仓库设计方案

## 一、背景与目标

### 1.1 项目背景

`yashandb-dev-plugins` 是 YashanDB 的 Claude Code 插件，为 AI 编程助手提供 YashanDB 领域专业知识。目前已覆盖 C 驱动、Go 驱动、Python 驱动、GORM、Docker 部署等技能。

随着 YashanDB 用户使用 Python 进行应用开发的需求增长，需要补充 **SQLAlchemy 方言** 相关技能，帮助用户快速构建基于 YashanDB 的 Python Web 应用。

### 1.2 项目目标

1. 提供 `yashandb-sqlalchemy` skill，为用户提供 SQLAlchemy + yaspy + YashanDB 的使用指导
2. 提供 FastAPI 和 Django 两种技术栈的完整项目模板，用户可直接克隆运行
3. 与现有 `yashandb-app-builder` 技能无缝集成，形成完整的应用开发工作流

---

## 二、整体架构

### 2.1 技能依赖关系

```
yashandb-app-builder (主入口)
    │
    ├── yashandb-sqlalchemy (skill)      # SQLAlchemy 层面指导
    ├── yashandb-python (skill)           # yaspy 驱动安装
    ├── yashandb (skill)                   # 数据库设计最佳实践
    │
    └── FastAPI/Django 模板 (独立仓库)    # 可运行的项目代码
```

### 2.2 组件职责

| 组件 | 职责 |
|------|------|
| **yashandb-app-builder** | 整体协调：需求沟通、技术栈选择、任务生成、代码生成 |
| **yashandb-sqlalchemy** | SQLAlchemy 通用指南：安装、连接、模型、CRUD、事务 |
| **yashandb-python** | yaspy 驱动安装和环境配置 |
| **yashandb** | 数据库设计：主键、索引、分区、Oracle 兼容等最佳实践 |
| **模板仓库** | 可运行的完整项目代码 |

---

## 三、yashandb-sqlalchemy Skill 设计

### 3.1 目录结构

```
skills/yashandb-sqlalchemy/
├── SKILL.md                         # 技能主入口
└── references/                       # 参考文档
    ├── installation.md              # 安装指南
    ├── connection.md                # 连接配置
    ├── models.md                    # 模型定义
    ├── crud.md                      # CRUD 操作
    ├── transactions.md              # 事务处理
    ├── types.md                     # 数据类型映射
    └── troubleshooting.md           # 故障排查
```

### 3.2 SKILL.md 内容大纲

```markdown
---
name: yashandb-sqlalchemy
name_for_command: yashandb-sqlalchemy
description: 指导用户使用 SQLAlchemy 连接 YashanDB。当用户提到 SQLAlchemy、ORM、yashandb-sqlalchemy 或需要使用 Python ORM 操作 YashanDB 时使用此技能。
---

# YashanDB SQLAlchemy 使用指南

## 依赖关系

SQLAlchemy + yaspy + YashanDB
    │
    └──► yaspy 驱动 (yashandb-python)
              │
              └──► C 驱动 (libyascli) ← 执行 /yashandb-c 安装

## 步骤概览

1. 检查前置依赖（yaspy 驱动）
2. 安装 yashandb-sqlalchemy
3. 连接数据库
4. 定义模型
5. CRUD 操作

## 第一步：检查前置依赖

## 第二步：安装 yashandb-sqlalchemy

## 第三步：连接数据库

## 第四步：定义模型（体现 YashanDB 最佳实践）

## 第五步：CRUD 操作

## 参考文档
- [installation](skills/yashandb-sqlalchemy/references/installation.md)
- [connection](skills/yashandb-sqlalchemy/references/connection.md)
- [models](skills/yashandb-sqlalchemy/references/models.md)
- [crud](skills/yashandb-sqlalchemy/references/crud.md)
- [transactions](skills/yashandb-sqlalchemy/references/transactions.md)
- [types](skills/yashandb-sqlalchemy/references/types.md)
- [troubleshooting](skills/yashandb-sqlalchemy/references/troubleshooting.md)

## 相关技能
- /yashandb-python - yaspy 驱动安装
- /yashandb - 数据库设计最佳实践

## 相关资源
- yashandb-sqlalchemy 源码：https://github.com/yashan-technologies/yashandb-sqlalchemy
- SQLAlchemy 官方文档：https://docs.sqlalchemy.org/
```

### 3.3 核心内容要点

#### 3.3.1 安装指南 (installation.md)

- pip 安装方式
- 源码安装方式
- 依赖说明（SQLAlchemy 1.4.x、yaspy）

#### 3.3.2 连接配置 (connection.md)

- 连接 URL 格式：`yashandb+yaspy://user:password@host:port/database`
- 连接池配置
- 环境变量配置

#### 3.3.3 模型定义 (models.md)

- 声明式基类
- 主键设计（强调使用序列，符合 YashanDB 最佳实践）
- 字段类型映射（Oracle 兼容类型）
- 索引设计

#### 3.3.4 CRUD 操作 (crud.md)

- 基础增删改查
- 批量操作
- 关联关系
- 原生 SQL 执行

#### 3.3.5 事务处理 (transactions.md)

- 手动事务
- 上下文管理器事务
- 嵌套事务

#### 3.3.6 数据类型映射 (types.md)

| Python/SQLAlchemy 类型 | YashanDB 类型 |
|------------------------|---------------|
| Integer | INTEGER |
| BigInteger | BIGINT |
| String(n) | VARCHAR2(n) |
| DateTime | TIMESTAMP |
| Numeric | NUMBER |
| Boolean | NUMBER(1) |

#### 3.3.7 故障排查 (troubleshooting.md)

- 常见连接错误
- 驱动加载问题
- 类型映射问题

---

## 四、模板仓库设计

模板仓库采用 YashanDB 官网首页作为演示案例，首页数据从 YashanDB 数据库动态获取。用户可克隆后直接运行，作为 SQLAlchemy + YashanDB 开发的入门示例。

### 4.1 FastAPI 模板

- **仓库名称**：`yashandb-fastapi-template`
- **案例内容**：YashanDB 官网首页展示
- **数据来源**：产品特性信息存储在 YashanDB 中，页面动态加载
- **运行方式**：克隆后 `pip install -r requirements.txt`，配置数据库连接，启动服务即可访问

### 4.2 Django 模板

- **仓库名称**：`yashandb-django-template`
- **案例内容**：YashanDB 官网首页展示
- **数据来源**：产品特性信息存储在 YashanDB 中，页面动态加载
- **运行方式**：克隆后 `pip install -r requirements.txt`，配置数据库连接，执行迁移后启动服务

---

## 五、与 yashandb-app-builder 集成

### 5.1 工作流程

当用户通过 `/yashandb-app-builder` 构建应用并选择 **Python + FastAPI** 或 **Python + Django** 技术栈时：

1. **yashandb-app-builder** 引导用户选择技术栈
2. 调用 **yashandb-python** 安装 yaspy 驱动
3. 调用 **yashandb-sqlalchemy** 提供 SQLAlchemy 指南
4. 调用 **yashandb** 提供数据库设计建议
5. 从模板仓库生成项目代码到用户目录
6. 用户获得一个完整的、可运行的应用

### 5.2 集成方式

在 `yashandb-app-builder` SKILL.md 中添加：

```markdown
### 技术栈选择

| 技术栈 | 模板仓库 |
|--------|----------|
| Python + FastAPI | yashandb-fastapi-template |
| Python + Django | yashandb-django-template |

选择后，从对应模板仓库生成项目代码。
```

---

## 六、实施计划

### 6.1 阶段划分

| 阶段 | 任务 | 产出 |
|------|------|------|
| 第一阶段 | 创建 yashandb-sqlalchemy skill | skills/yashandb-sqlalchemy/ |
| 第二阶段 | 创建 FastAPI 模板仓库 | yashandb-fastapi-template |
| 第三阶段 | 创建 Django 模板仓库 | yashandb-django-template |
| 第四阶段 | 更新 yashandb-app-builder 集成 | yashandb-app-builder/ |

### 6.2 优先级

1. **高优先级**：yashandb-sqlalchemy skill + FastAPI 模板
2. **中优先级**：Django 模板
3. **低优先级**：后续可根据用户需求扩展

---

## 七、总结

本方案通过以下设计，帮助用户快速构建基于 YashanDB 的 Python Web 应用：

1. **yashandb-sqlalchemy skill**：提供 SQLAlchemy + YashanDB 的使用指南
2. **FastAPI 模板**：开箱即用的 FastAPI + SQLAlchemy + YashanDB 项目
3. **Django 模板**：开箱即用的 Django + SQLAlchemy + YashanDB 项目
4. **与现有技能集成**：与 yashandb-app-builder 无缝配合

用户可以通过 `/yashandb-app-builder` 作为入口，快速构建完整的 YashanDB 应用系统。

---

## 附录：相关资源

- yashandb-sqlalchemy 源码：https://github.com/yashan-technologies/yashandb-sqlalchemy
- yaspy 驱动：https://pypi.org/project/yaspy/
- SQLAlchemy 官方文档：https://docs.sqlalchemy.org/
- FastAPI 官方文档：https://fastapi.tiangolo.com/
- Django 官方文档：https://docs.djangoproject.com/
