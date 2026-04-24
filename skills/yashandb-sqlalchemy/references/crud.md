# CRUD 操作

本文介绍 SQLAlchemy 与 YashanDB 的 CRUD（创建、读取、更新、删除）操作。

## 基础查询

### 创建会话

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

engine = create_engine("yashandb+yaspy://sys:password@127.0.0.1:1688/test")
Session = sessionmaker(bind=engine)
session = Session()
```

### 查询所有记录

```python
# 查询所有用户
users = session.query(User).all()

# 遍历结果
for user in users:
    print(user.name, user.email)
```

### 按条件查询

```python
# 使用 filter_by（关键字参数）
user = session.query(User).filter_by(email="test@example.com").first()

# 使用 filter（更灵活）
user = session.query(User).filter(User.email == "test@example.com").first()

# 多条件
user = session.query(User).filter(
    User.email == "test@example.com",
    User.status == "active"
).first()
```

### 常用查询操作符

| 操作符 | 说明 | 示例 |
|--------|------|------|
| == | 等于 | User.name == "张三" |
| != | 不等于 | User.status != "deleted" |
| > | 大于 | User.id > 10 |
| < | 小于 | User.id < 100 |
| >= | 大于等于 | User.id >= 10 |
| <= | 小于等于 | User.id <= 100 |
| LIKE | 模糊匹配 | User.name.like("%张%") |
| IN | 在列表中 | User.id.in_([1, 2, 3]) |
| NOT IN | 不在列表中 | User.id.notin_([1, 2, 3]) |
| IS NULL | 为空 | User.email == None |
| IS NOT NULL | 不为空 | User.email != None |
| AND | 逻辑与 | and_(条件1, 条件2) |
| OR | 逻辑或 | or_(条件1, 条件2) |

### 排序

```python
# 按单个字段升序
users = session.query(User).order_by(User.created_at).all()

# 按单个字段降序
users = session.query(User).order_by(User.created_at.desc()).all()

# 多字段排序
users = session.query(User).order_by(
    User.status,
    User.created_at.desc()
).all()
```

### 分页

```python
# 第一页，每页 10 条
users = session.query(User).limit(10).all()

# 跳过前 10 条，取 10 条
users = session.query(User).offset(10).limit(10).all()

# 分页函数
def paginate(query, page=1, per_page=10):
    return query.offset((page - 1) * per_page).limit(per_page)

# 使用
users = paginate(session.query(User), page=2, per_page=20)
```

### 计数

```python
# 统计数量
count = session.query(User).count()

# 带条件统计
count = session.query(User).filter_by(status="active").count()
```

## 创建数据

### 添加单条记录

```python
# 方法 1：创建对象后添加
user = User(name="张三", email="zhangsan@example.com")
session.add(user)
session.commit()

# 方法 2：创建后立即提交
user = User(name="李四", email="lisi@example.com")
session.add(user)
session.flush()  # 刷新获取自增 ID
print(user.id)
session.commit()
```

### 添加多条记录

```python
# 批量添加
users = [
    User(name="张三", email="zhangsan@example.com"),
    User(name="李四", email="lisi@example.com"),
    User(name="王五", email="wangwu@example.com"),
]
session.add_all(users)
session.commit()
```

### 返回插入的 ID

```python
# YashanDB 使用序列，插入后自动获取 ID
user = User(name="张三", email="zhangsan@example.com")
session.add(user)
session.flush()  # 刷新以获取 ID
print(f"插入的用户ID: {user.id}")
session.commit()
```

## 更新数据

### 更新单条记录

```python
# 方法 1：查询后修改
user = session.query(User).filter_by(email="zhangsan@example.com").first()
if user:
    user.name = "张三（已修改）"
    session.commit()

# 方法 2：使用 update 语句
session.query(User).filter_by(status="inactive").update({"status": "active"})
session.commit()
```

### 批量更新

```python
# 更新所有活跃用户的状态
session.query(User).filter(
    User.status == "active"
).update({"status": "verified"}, synchronize_session=False)
session.commit()
```

## 删除数据

### 删除单条记录

```python
user = session.query(User).filter_by(email="zhangsan@example.com").first()
if user:
    session.delete(user)
    session.commit()
```

### 批量删除

```python
# 删除所有 status 为 'deleted' 的用户
session.query(User).filter_by(status="deleted").delete()
session.commit()
```

### 条件删除

```python
# 删除 ID 大于 100 的用户
session.query(User).filter(User.id > 100).delete()
session.commit()
```

## 原生 SQL 执行

### 执行查询

```python
from sqlalchemy import text

# 查询
result = session.execute(text("SELECT * FROM users WHERE status = :status"), {"status": "active"})
for row in result:
    print(row)

# 使用 ORM 映射结果
result = session.execute(
    text("SELECT id, name, email FROM users WHERE status = :status"),
    {"status": "active"}
)
users = result.fetchall()
for user in users:
    print(user.id, user.name, user.email)
```

### 执行插入

```python
session.execute(
    text("INSERT INTO users (name, email, status) VALUES (:name, :email, :status)"),
    {"name": "测试", "email": "test@example.com", "status": "active"}
)
session.commit()
```

### 执行更新

```python
session.execute(
    text("UPDATE users SET status = :status WHERE id > :id"),
    {"status": "inactive", "id": 100}
)
session.commit()
```

### 执行删除

```python
session.execute(
    text("DELETE FROM users WHERE status = :status"),
    {"status": "deleted"}
)
session.commit()
```

## 关联查询

### 懒加载

```python
# 查询用户及其订单
user = session.query(User).first()
orders = user.orders  # 触发额外查询
```

### 联表查询

```python
from sqlalchemy.orm import joinedload

# 使用 join 加载关联数据
user = session.query(User).options(joinedload(User.orders)).first()
```

### 使用 join

```python
# 查询用户及其订单
results = session.query(User, Order).join(
    Order, User.id == Order.user_id
).all()

for user, order in results:
    print(f"{user.name}: {order.amount}")
```

### 过滤关联数据

```python
# 查询有未完成订单的用户
users = session.query(User).join(Order).filter(
    Order.status == "pending"
).distinct().all()
```

## 完整示例

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from datetime import datetime

engine = create_engine("yashandb+yaspy://sys:password@127.0.0.1:1688/test")
Session = sessionmaker(bind=engine)
session = Session()

try:
    # 创建
    user = User(name="张三", email="zhangsan@example.com")
    session.add(user)
    session.flush()

    # 读取
    user = session.query(User).filter_by(id=user.id).first()
    print(f"创建用户: {user.name}")

    # 更新
    user.name = "张三（已更新）"
    session.commit()
    print("更新成功")

    # 删除
    session.delete(user)
    session.commit()
    print("删除成功")

except Exception as e:
    session.rollback()
    print(f"错误: {e}")
finally:
    session.close()
```
