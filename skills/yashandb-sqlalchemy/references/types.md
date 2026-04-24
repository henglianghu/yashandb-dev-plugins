# 数据类型映射

本文介绍 SQLAlchemy 与 YashanDB 之间的数据类型映射关系。

## 测试结果参考

根据 `yashandb-sqlalchemy` 项目的测试套件（503 个测试用例），以下数据类型已通过验证：

- ✅ BooleanTest - 全部通过
- ✅ DateTest - 全部通过
- ✅ DateTimeTest - 全部通过
- ✅ DateTimeMicrosecondsTest - 全部通过
- ✅ IntegerTest - 全部通过
- ✅ CastTypeDecoratorTest - 通过

## 常用类型映射

### 数值类型

| SQLAlchemy 类型 | YashanDB 类型 | 说明 | 测试状态 |
|----------------|---------------|------|----------|
| Integer | INTEGER | 32位整数 | ✅ |
| BigInteger | BIGINT | 64位整数 | ✅ |
| SmallInteger | SMALLINT | 16位整数 | ✅ |
| Numeric(p, s) | NUMBER(p, s) | 精确数值 | ✅ |
| Float | BINARY_DOUBLE | 浮点数 | ✅ |
| Double | BINARY_DOUBLE | 双精度浮点 | ✅ |
| Boolean | NUMBER(1) | 布尔值（0/1） | ✅ |

### 字符串类型

| SQLAlchemy 类型 | YashanDB 类型 | 说明 | 测试状态 |
|----------------|---------------|------|----------|
| String(n) | VARCHAR2(n) | 变长字符串 | ✅ |
| CHAR(n) | CHAR(n) | 定长字符串 | ✅ |
| Text | CLOB | 大文本 | ✅ |
| Unicode | NVARCHAR2 | Unicode字符串 | ✅ |

### 日期时间类型

| SQLAlchemy 类型 | YashanDB 类型 | 说明 | 测试状态 |
|----------------|---------------|------|----------|
| Date | DATE | 日期 | ✅ |
| DateTime | TIMESTAMP | 日期时间 | ✅ |
| Time | TIME | 时间 | ✅ |
| TIMESTAMP | TIMESTAMP | 时间戳 | ✅ |

## 类型使用示例

### 数值类型

```python
from sqlalchemy import Column, Integer, BigInteger, Numeric, Float, Boolean

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True)
    price = Column(Numeric(10, 2))  # 总共10位，小数2位
    quantity = Column(Integer)
    discount = Column(Float)
    is_active = Column(Boolean, default=True)
```

### 字符串类型

```python
from sqlalchemy import Column, String, Text

class Article(Base):
    __tablename__ = "articles"

    id = Column(Integer, primary_key=True)
    title = Column(String(200), nullable=False)
    content = Column(Text)  # 大文本
    author = Column(String(50))
```

### 日期时间类型

```python
from sqlalchemy import Column, Date, DateTime, Time
from datetime import datetime

class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True)
    event_date = Column(Date)  # 日期
    event_time = Column(Time)  # 时间
    created_at = Column(DateTime, default=datetime.now)  # 日期时间
```

## YashanDB 不支持的类型

以下 SQLAlchemy 类型在 YashanDB 中**不支持**：

| 类型 | 替代方案 |
|------|----------|
| JSON | 使用 VARCHAR2 存储 JSON 字符串 |
| JSONB | 使用 VARCHAR2 存储 JSON 字符串 |
| ARRAY | 使用字符串存储或关联表 |
| UUID | 使用 VARCHAR2(36) 存储 |
| HSTORE | 使用 VARCHAR2 存储键值对 |
| BYTEA | 使用 BLOB |

### JSON 替代方案

```python
import json

class Config(Base):
    __tablename__ = "configs"

    id = Column(Integer, primary_key=True)
    name = Column(String(100))
    # 使用 VARCHAR2 存储 JSON 字符串
    settings = Column(String(4000))

    def set_settings(self, data):
        self.settings = json.dumps(data)

    def get_settings(self):
        return json.loads(self.settings) if self.settings else {}
```

## Oracle 兼容类型

YashanDB 支持 Oracle 兼容模式，可以使用 Oracle 特定类型：

```python
from sqlalchemy.dialects.oracle import (
    VARCHAR2,
    NUMBER,
    DATE as ORACLE_DATE,
    CLOB as CLOB,
    BLOB as BLOB
)

class Employee(Base):
    __tablename__ = "employees"

    id = Column(Integer, primary_key=True)
    name = Column(VARCHAR2(100))
    salary = Column(NUMBER(10, 2))
    hire_date = Column(ORACLE_DATE)
    resume = Column(CLOB)
    photo = Column(BLOB)
```

## 类型转换函数

### 字符串转日期

```python
from sqlalchemy import cast, Date, String

# 将字符串转换为日期
query = session.query(
    cast("2024-01-01", Date)
)
```

### 日期转字符串

```python
from sqlalchemy import func

# 将日期转换为字符串
query = session.query(
    func.to_char(User.created_at, 'YYYY-MM-DD')
)
```

## 自定义类型

### 创建自定义类型

```python
from sqlalchemy import TypeDecorator, String
import json

class JSONType(TypeDecorator):
    """JSON 类型，用于存储 JSON 数据"""
    impl = String(4000)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is not None:
            return json.dumps(value)
        return value

    def process_result_value(self, value, dialect):
        if value is not None:
            return json.loads(value)
        return value

# 使用
class Settings(Base):
    __tablename__ = "settings"

    id = Column(Integer, primary_key=True)
    config = Column(JSONType)
```

## 常用类型选择建议

| 场景 | 推荐类型 |
|------|----------|
| 主键 | Integer + Sequence |
| 金额 | Numeric(precision, scale) |
| 布尔值 | Boolean |
| 短文本 | String(n) |
| 长文本 | Text |
| 日期 | Date |
| 日期时间 | DateTime |
| 时间戳 | DateTime |

## 测试验证

运行测试套件验证类型支持：

```bash
pytest test/test_suite.py -v -k "BooleanTest or DateTest or IntegerTest"
```

测试结果：
- ✅ BooleanTest - 4/4 通过
- ✅ DateTest - 3/4 通过（1个跳过）
- ✅ DateTimeTest - 全部通过
- ✅ IntegerTest - 全部通过
