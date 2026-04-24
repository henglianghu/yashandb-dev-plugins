# 事务处理

本文介绍 SQLAlchemy 与 YashanDB 的事务处理机制。

## YashanDB 事务特性

| 特性 | 支持情况 |
|------|----------|
| READ COMMITTED | ✅ 支持（默认） |
| READ UNCOMMITTED | ❌ 不支持 |
| REPEATABLE READ | ❌ 不支持 |
| SERIALIZABLE | ❌ 不支持 |
| 嵌套事务 | ✅ 支持（Savepoint） |

## 手动事务控制

### 基本使用

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

engine = create_engine("yashandb+yaspy://sys:password@127.0.0.1:1688/test")
Session = sessionmaker(bind=engine)
session = Session()

# 开始事务
session.begin()

try:
    # 执行多个操作
    user = User(name="张三", email="zhangsan@example.com")
    session.add(user)
    session.commit()  # 提交事务
except Exception as e:
    session.rollback()  # 回滚事务
    print(f"事务失败: {e}")
finally:
    session.close()
```

## 上下文管理器

### 使用 with 语句

```python
from sqlalchemy.orm import sessionmaker

Session = sessionmaker(bind=engine)

# 自动提交或回滚
with Session() as session:
    user = User(name="张三", email="zhangsan@example.com")
    session.add(user)
    session.commit()
# 自动关闭会话
```

### 事务回滚示例

```python
from sqlalchemy.orm import sessionmaker

Session = sessionmaker(bind=engine)

with Session() as session:
    try:
        # 创建用户
        user = User(name="张三", email="zhangsan@example.com")
        session.add(user)
        session.flush()

        # 创建订单
        order = Order(user_id=user.id, amount=1000)
        session.add(order)
        session.commit()

        print("创建成功")
    except Exception as e:
        session.rollback()
        print(f"创建失败: {e}")
```

## 嵌套事务（Savepoint）

### 保存点基本使用

```python
session.begin()

try:
    # 操作 1
    session.add(User(name="用户1", email="user1@example.com"))
    session.flush()

    # 创建保存点
    sp1 = session.begin_nested()

    try:
        # 操作 2
        session.add(User(name="用户2", email="user2@example.com"))
        session.flush()

        # 回滚到保存点
        session.rollback()
    except Exception:
        session.rollback()

    # 操作 3（继续主事务）
    session.add(User(name="用户3", email="user3@example.com"))
    session.commit()

except Exception:
    session.rollback()
```

### 使用 begin_nested()

```python
session.begin()

try:
    # 主事务操作
    session.add(User(name="用户1", email="user1@example.com"))

    # 嵌套事务
    nested = session.begin_nested()
    try:
        session.add(User(name="用户2", email="user2@example.com"))
        # 回滚嵌套事务
        session.rollback()
        nested.close()
    except Exception:
        session.rollback()

    # 主事务继续
    session.add(User(name="用户3", email="user3@example.com"))
    session.commit()

except Exception:
    session.rollback()
```

## 连接池与事务

### 配置连接池

```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    "yashandb+yaspy://sys:password@127.0.0.1:1688/test",
    poolclass=QueuePool,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,  # 使用前测试连接
)

Session = sessionmaker(bind=engine)
```

### 处理断开的连接

```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    "yashandb+yaspy://sys:password@127.0.0.1:1688/test",
    poolclass=QueuePool,
    pool_pre_ping=True,  # 自动检测断开连接
)

Session = sessionmaker(bind=engine)

# 连接断开时会自动重连
with Session() as session:
    result = session.query(User).all()
```

## 事务隔离级别

### 设置隔离级别

YashanDB 只支持 READ COMMITTED 隔离级别。

```python
from sqlalchemy import create_engine

engine = create_engine(
    "yashandb+yaspy://sys:password@127.0.0.1:1688/test",
    isolation_level="READ COMMITTED"  # 默认值
)
```

### 注意事项

- YashanDB **不支持**设置其他隔离级别
- 尝试设置不支持的隔离级别会报错
- 建议使用默认的 READ COMMITTED

## 错误处理

### 完整的事务处理模式

```python
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError

Session = sessionmaker(bind=engine)

def create_user_with_order(user_data, order_data):
    with Session() as session:
        try:
            # 创建用户
            user = User(**user_data)
            session.add(user)
            session.flush()  # 获取用户 ID

            # 创建订单
            order = Order(user_id=user.id, **order_data)
            session.add(order)

            # 提交
            session.commit()
            return user.id

        except SQLAlchemyError as e:
            session.rollback()
            raise e

# 使用
try:
    user_id = create_user_with_order(
        {"name": "张三", "email": "zhangsan@example.com"},
        {"amount": 1000, "status": "pending"}
    )
except Exception as e:
    print(f"创建失败: {e}")
```

## 并发控制

### 悲观锁（SELECT FOR UPDATE）

```python
# 获取用户并加锁
user = session.query(User).filter_by(id=1).with_for_update().first()

# 在事务中对用户进行操作
user.balance -= 100
session.commit()
```

### 乐观锁（版本号）

```python
from sqlalchemy import Column, Integer, String

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, Sequence('user_id_seq'), primary_key=True)
    name = Column(String(100))
    version = Column(Integer, default=1)
    __mapper_args__ = {"version_id_col": version}

# 更新时自动检查版本
user = session.query(User).get(1)
user.name = "新名字"  # 自动更新 version
session.commit()  # 如果版本冲突会抛出异常
```

## 最佳实践

1. **始终使用事务**：即使单个操作也要在事务中执行
2. **及时提交**：长时间持有事务会导致锁等待
3. **正确处理异常**：确保在异常时回滚事务
4. **使用上下文管理器**：简化资源管理和错误处理
5. **避免嵌套事务过深**：保存点过多影响性能
