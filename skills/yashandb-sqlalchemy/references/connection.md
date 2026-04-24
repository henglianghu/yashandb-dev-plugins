# 连接配置

本文介绍如何配置 SQLAlchemy 与 YashanDB 的连接。

## 连接 URL 格式

```
yashandb+yaspy://用户名:密码@主机:端口/数据库名
```

### 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| 用户名 | 数据库连接用户名 | sys、test |
| 密码 | 数据库密码 | password |
| 主机 | 数据库服务器地址 | 127.0.0.1、localhost |
| 端口 | YashanDB 监听端口 | 1688 |
| 数据库 | 要连接的数据库名 | test |

## 基本连接示例

### 最简连接

```python
from sqlalchemy import create_engine

engine = create_engine("yashandb+yaspy://sys:password@127.0.0.1:1688/test")
```

### 使用 SQLAlchemy URI

```python
from sqlalchemy import create_engine

# 标准格式
engine = create_engine(
    "yashandb+yaspy://sys:your_password@localhost:1688/test"
)
```

## 连接池配置

```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    "yashandb+yaspy://sys:password@127.0.0.1:1688/test",
    poolclass=QueuePool,
    pool_size=5,           # 最小连接数
    max_overflow=10,       # 最大额外连接数
    pool_timeout=30,        # 获取连接超时时间
    pool_recycle=3600,     # 连接回收时间（秒）
)
```

## 使用环境变量

### 方法一：直接读取环境变量

```python
import os
from sqlalchemy import create_engine

DATABASE_URL = os.getenv("YASHANDB_DATABASE_URL")
engine = create_engine(DATABASE_URL)
```

### 方法二：Pydantic Settings

```python
from pydantic_settings import BaseSettings
from sqlalchemy import create_engine

class Settings(BaseSettings):
    yashandb_host: str = "127.0.0.1"
    yashandb_port: int = 1688
    yashandb_user: str = "sys"
    yashandb_password: str = ""
    yashandb_database: str = "test"

    @property
    def database_url(self) -> str:
        return f"yashandb+yaspy://{self.yashandb_user}:{self.yashandb_password}@{self.yashandb_host}:{self.yashandb_port}/{self.yashandb_database}"

    class Config:
        env_file = ".env"

settings = Settings()
engine = create_engine(settings.database_url)
```

### .env 文件示例

```
YASHANDB_HOST=127.0.0.1
YASHANDB_PORT=1688
YASHANDB_USER=sys
YASHANDB_PASSWORD=your_password
YASHANDB_DATABASE=test
```

## 创建会话

```python
from sqlalchemy.orm import sessionmaker

Session = sessionmaker(bind=engine)
session = Session()

# 使用后关闭
session.close()
```

## 使用上下文管理器

```python
from sqlalchemy.orm import sessionmaker

Session = sessionmaker(bind=engine)

with Session() as session:
    result = session.query(User).all()
    # session 自动关闭
```
