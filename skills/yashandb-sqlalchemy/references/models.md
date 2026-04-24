# 模型定义

本文介绍如何在 SQLAlchemy 中定义 YashanDB 数据模型。

## 声明式基类

```python
from sqlalchemy.orm import declarative_base

Base = declarative_base()
```

## 主键设计（YashanDB 最佳实践）

YashanDB 推荐使用**序列（Sequence）**作为主键，而非自增列。

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

### 序列说明

| 方式 | 说明 | 适用场景 |
|------|------|----------|
| Sequence | YashanDB 原生序列，支持跨库唯一 | 生产环境（推荐） |
| Identity | YashanDB 不支持 | 不推荐 |

## 字段类型映射

### 常用类型映射

| SQLAlchemy 类型 | YashanDB 类型 | 说明 |
|----------------|---------------|------|
| Integer | INTEGER | 整数 |
| BigInteger | BIGINT | 大整数 |
| String(n) | VARCHAR2(n) | 变长字符串 |
| Text | CLOB | 大文本 |
| DateTime | TIMESTAMP | 日期时间 |
| Date | DATE | 日期 |
| Time | TIME | 时间 |
| Numeric(p,s) | NUMBER(p,s) | 数值 |
| Float | BINARY_DOUBLE | 浮点数 |
| Boolean | NUMBER(1) | 布尔值（0/1） |

### Oracle 兼容类型

```python
from sqlalchemy.dialects.oracle import VARCHAR2, NUMBER, DATE as ORACLE_DATE

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, Sequence('product_id_seq'), primary_key=True)
    name = Column(VARCHAR2(100))
    price = Column(NUMBER(10, 2))
    created_date = Column(ORACLE_DATE)
```

## 索引设计

### 单列索引

```python
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, Sequence('user_id_seq'), primary_key=True)
    email = Column(String(255), index=True)  # 单列索引
```

### 复合索引

```python
from sqlalchemy import Index

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, Sequence('order_id_seq'), primary_key=True)
    user_id = Column(Integer)
    status = Column(String(20))
    created_at = Column(DateTime)

    __table_args__ = (
        Index('idx_user_status', 'user_id', 'status'),  # 复合索引
    )
```

### 唯一索引

```python
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, Sequence('user_id_seq'), primary_key=True)
    email = Column(String(255), unique=True)  # 唯一约束
```

## 外键关系

### 一对多关系

```python
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, Sequence('user_id_seq'), primary_key=True)
    name = Column(String(100))

    orders = relationship("Order", back_populates="user")

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, Sequence('order_id_seq'), primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    amount = Column(Integer)

    user = relationship("User", back_populates="orders")
```

### 多对多关系

```python
from sqlalchemy import Table, Column, Integer, String, ForeignKey

association_table = Table(
    'user_roles',
    Base.metadata,
    Column('user_id', Integer, ForeignKey('users.id')),
    Column('role_id', Integer, ForeignKey('roles.id'))
)

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, Sequence('user_id_seq'), primary_key=True)
    name = Column(String(100))

    roles = relationship("Role", secondary=association_table, back_populates="users")

class Role(Base):
    __tablename__ = "roles"

    id = Column(Integer, Sequence('role_id_seq'), primary_key=True)
    name = Column(String(50))

    users = relationship("User", secondary=association_table, back_populates="roles")
```

## 创建表

```python
from sqlalchemy import create_engine

engine = create_engine("yashandb+yaspy://sys:password@127.0.0.1:1688/test")

# 创建所有表
Base.metadata.create_all(engine)

# 删除所有表
Base.metadata.drop_all(engine)
```

## YashanDB 不支持的特性

以下 SQLAlchemy 特性在 YashanDB 中**不支持**：

| 特性 | 替代方案 |
|------|----------|
| 计算列 (Computed Column) | 在应用层计算 |
| 标识列 (Identity) | 使用 Sequence |
| JSON 类型 | 使用 VARCHAR2 存储 JSON 字符串 |
| CTE (公共表表达式) | 使用子查询 |

## 完整示例

```python
from sqlalchemy import Column, Integer, String, DateTime, Sequence, Index
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, Sequence('user_id_seq'), primary_key=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, index=True)
    status = Column(String(20), default='active')
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    orders = relationship("Order", back_populates="user")

    __table_args__ = (
        Index('idx_status_created', 'status', 'created_at'),
    )

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, Sequence('order_id_seq'), primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    amount = Column(Integer)
    status = Column(String(20), default='pending')
    created_at = Column(DateTime, default=datetime.now)

    user = relationship("User", back_populates="orders")
```
