---
name: yashandb-sqlalchemy
name_for_command: yashandb-sqlalchemy
description: 指导用户使用 SQLAlchemy 连接 YashanDB。当用户提到 SQLAlchemy、ORM、yashandb-sqlalchemy 或需要使用 Python ORM 操作 YashanDB 时使用此技能。
---

# YashanDB SQLAlchemy 使用指南

## 依赖关系

```
SQLAlchemy 1.4.x + yashandb-sqlalchemy + yaspy + YashanDB
    │
    └──► yaspy 驱动 (yashandb-python)
              │
              └──► C 驱动 (libyascli) ← 执行 /yashandb-c 安装
```

## 版本要求

| 组件 | 版本要求 | 说明 |
|------|----------|------|
| **SQLAlchemy** | 1.4.* | 兼容 1.4.5 版本 |
| **yashandb-sqlalchemy** | 最新版 | YashanDB 方言包 |
| **yaspy** | 最新版 | YashanDB Python 驱动 |

> **Python 版本建议**：SQLAlchemy 1.4.x 支持 Python 3.6 ~ 3.11。建议使用 **Python 3.9**。

## 步骤概览

1. 安装 SQLAlchemy 1.4.x
2. 安装 yaspy 驱动
3. 安装 yashandb-sqlalchemy
4. 连接数据库
5. 定义模型
6. CRUD 操作

## 第一步：安装 SQLAlchemy

yashandb-sqlalchemy 是 SQLAlchemy 的方言扩展，需要先安装 SQLAlchemy 核心包：

```bash
pip3 install "SQLAlchemy==1.4.5"
```

## 第二步：检查前置依赖

确保已安装 yaspy 驱动：

```bash
pip3 install yaspy
```

如未安装，请先执行 `/yashandb-python` 安装 yaspy 驱动。

## 第三步：安装 yashandb-sqlalchemy

```bash
pip3 install yashandb-sqlalchemy
```

## 第四步：连接数据库

### 连接 URL 格式

```
yashandb+yaspy://用户名:密码@主机:端口/数据库名
```

### 示例

```python
from sqlalchemy import create_engine

# 基本连接
engine = create_engine("yashandb+yaspy://sys:password@127.0.0.1:1688/test")

# 带连接池
engine = create_engine(
    "yashandb+yaspy://sys:password@127.0.0.1:1688/test",
    pool_size=5,
    max_overflow=10
)
```

### 使用环境变量

```python
import os
from sqlalchemy import create_engine

DATABASE_URL = os.getenv(
    "YASHANDB_URL",
    "yashandb+yaspy://sys:password@127.0.0.1:1688/test"
)

engine = create_engine(DATABASE_URL)
```

## 第五步：定义模型（体现 YashanDB 最佳实践）

```python
from sqlalchemy import Column, Integer, String, DateTime, Sequence
from sqlalchemy.orm import declarative_base
from datetime import datetime

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    # 使用序列作为主键（YashanDB 最佳实践）
    id = Column(Integer, Sequence('user_id_seq'), primary_key=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, index=True)
    status = Column(String(20), default='active')
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
```

## 第六步：CRUD 操作

```python
from sqlalchemy.orm import sessionmaker

Session = sessionmaker(bind=engine)
session = Session()

# 创建
user = User(name="张三", email="zhangsan@example.com")
session.add(user)
session.commit()

# 查询
user = session.query(User).filter_by(email="zhangsan@example.com").first()

# 更新
user.name = "李四"
session.commit()

# 删除
session.delete(user)
session.commit()
```

## 事务处理

```python
# 手动事务
session.begin()
try:
    session.add(User(name="test"))
    session.commit()
except Exception:
    session.rollback()
    raise

# 上下文管理器
with session.begin():
    session.add(User(name="test"))
```

## 参考文档

- [installation](skills/yashandb-sqlalchemy/references/installation.md) - 安装指南
- [connection](skills/yashandb-sqlalchemy/references/connection.md) - 连接配置
- [models](skills/yashandb-sqlalchemy/references/models.md) - 模型定义
- [crud](skills/yashandb-sqlalchemy/references/crud.md) - CRUD 操作
- [transactions](skills/yashandb-sqlalchemy/references/transactions.md) - 事务处理
- [types](skills/yashandb-sqlalchemy/references/types.md) - 数据类型映射
- [troubleshooting](skills/yashandb-sqlalchemy/references/troubleshooting.md) - 故障排查

## 相关技能

- /yashandb-python - yaspy 驱动安装
- /yashandb - 数据库设计最佳实践

## 相关资源

- yashandb-sqlalchemy 源码：https://github.com/yashan-technologies/yashandb-sqlalchemy
- yaspy 驱动：https://pypi.org/project/yaspy/
- SQLAlchemy 官方文档：https://docs.sqlalchemy.org/
