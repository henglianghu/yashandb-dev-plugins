# 故障排查

本文介绍使用 yashandb-sqlalchemy 时可能遇到的常见问题及解决方案。

## 安装问题

### 问题：ImportError: No module named 'yaspy'

**原因**：yaspy 驱动未安装

**解决**：
```bash
pip3 install yaspy
```

### 问题：ImportError: No module named 'yashandb_sqlalchemy'

**原因**：yashandb-sqlalchemy 未安装

**解决**：
```bash
pip3 install yashandb-sqlalchemy
```

## 连接问题

### 问题：Connection Refused

**原因**：YashanDB 服务未启动或端口错误

**解决**：
1. 检查 YashanDB 服务是否运行
2. 确认端口号（默认 1688）是否正确
3. 检查防火墙设置

```python
# 测试连接
from sqlalchemy import create_engine

try:
    engine = create_engine("yashandb+yaspy://sys:password@127.0.0.1:1688/test")
    conn = engine.connect()
    conn.close()
    print("连接成功")
except Exception as e:
    print(f"连接失败: {e}")
```

### 问题：Authentication Failed

**原因**：用户名或密码错误

**解决**：
1. 确认用户名和密码
2. 检查是否具有访问数据库的权限

### 问题：Database does not exist

**原因**：指定的数据库不存在

**解决**：
1. 确认数据库名称正确
2. 使用 sys 用户连接后创建数据库

## 驱动问题

### 问题：找不到 libyascli 库

**原因**：C 驱动未正确安装

**解决**：
1. 执行 `/yashandb-c` 安装 C 驱动
2. 配置环境变量：
   - Linux: `export LD_LIBRARY_PATH=/path/to/lib:$LD_LIBRARY_PATH`
   - Windows: 将 libyascli.dll 添加到 PATH

### 问题：ModuleNotFoundError: No module named 'sqlalchemy.dialects.yashandb'

**原因**：yashandb-sqlalchemy 未正确安装

**解决**：
```bash
pip3 install --upgrade yashandb-sqlalchemy
```

## SQL 执行问题

### 问题：Table does not exist

**原因**：表未创建

**解决**：
```python
# 创建表
Base.metadata.create_all(engine)
```

### 问题：Sequence does not exist

**原因**：序列未创建

**解决**：
```python
# 手动创建序列
from sqlalchemy import text

with engine.connect() as conn:
    conn.execute(text("CREATE SEQUENCE user_id_seq"))
    conn.commit()
```

### 问题：Column not found

**原因**：列名拼写错误或大小写问题

**解决**：
YashanDB 默认大写列名，SQLAlchemy 使用小写：
```python
# 方案1：使用大写列名
class User(Base):
    __tablename__ = "users"
    __table_args__ = {'quote': True}

    ID = Column(Integer, primary_key=True)
    NAME = Column(String(100))

# 方案2：设置列名映射
class User(Base):
    __tablename__ = "users"

    id = Column('ID', Integer, primary_key=True)
    name = Column('NAME', String(100))
```

## 事务问题

### 问题：Database is locked

**原因**：有未提交的事务或连接未关闭

**解决**：
1. 确保所有会话正确关闭
2. 检查是否有未提交的事务
3. 使用连接池的 `pool_pre_ping=True`

### 问题：Deadlock

**原因**：多个事务相互等待锁

**解决**：
1. 调整事务顺序，保持一致的锁获取顺序
2. 使用更短的事务
3. 设置超时时间

```python
engine = create_engine(
    "yashandb+yaspy://sys:password@127.0.0.1:1688/test",
    pool_timeout=30
)
```

## 类型问题

### 问题：Boolean 值存储错误

**原因**：Boolean 映射到 NUMBER(1)，但写入值不是 0/1

**解决**：
```python
# 确保布尔值为 0/1
user = User(name="test", is_active=1 if True else 0)
```

### 问题：日期时间格式错误

**原因**：日期时间格式不兼容

**解决**：
```python
from datetime import datetime

# 使用 datetime 对象
user = User(created_at=datetime.now())
```

### 问题：String 长度超限

**原因**：字符串长度超过定义

**解决**：
```python
# 增加字段长度
name = Column(String(500))  # 改为更长
# 或使用 Text 类型
content = Column(Text)  # 无长度限制
```

## 性能问题

### 问题：查询缓慢

**解决**：
1. 添加索引
2. 使用连接池
3. 使用批量操作

```python
# 添加索引
class User(Base):
    __tablename__ = "users"
    email = Column(String(255), index=True)  # 索引

# 使用连接池
engine = create_engine(
    "yashandb+yaspy://sys:password@127.0.0.1:1688/test",
    pool_size=10,
    max_overflow=20
)

# 批量插入
users = [User(name=f"user{i}") for i in range(1000)]
session.bulk_save_objects(users)
session.commit()
```

### 问题：内存占用过高

**解决**：
1. 使用分页查询
2. 使用流式处理

```python
# 分页查询
def query_all_users():
    offset = 0
    batch_size = 1000

    while True:
        users = session.query(User).offset(offset).limit(batch_size).all()
        if not users:
            break

        for user in users:
            yield user

        offset += batch_size

# 使用生成器
for user in query_all_users():
    process(user)
```

## 调试技巧

### 启用 SQL 日志

```python
import logging

logging.basicConfig()
logging.getLogger('sqlalchemy.engine').setLevel(logging.INFO)

engine = create_engine("yashandb+yaspy://sys:password@127.0.0.1:1688/test")
```

### 打印原生 SQL

```python
# 查看生成的 SQL
query = session.query(User).filter_by(status="active")
print(str(query))
```

### 使用 SQL 片段测试

```python
from sqlalchemy import text

# 直接执行 SQL 测试
result = session.execute(text("SELECT * FROM users LIMIT 1"))
print(result.fetchone())
```

## 常见错误码

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| ORA-00001 | 唯一约束冲突 | 检查唯一键是否重复 |
| ORA-00942 | 表或视图不存在 | 创建表或检查表名 |
| ORA-01000 | 超出最大打开游标数 | 增加游标数或关闭连接 |
| ORA-01017 | 用户名/密码无效 | 检查认证信息 |
| ORA-12541 | TNS：无监听程序 | 检查 YashanDB 服务 |

## 获取帮助

### 运行测试

```bash
# 运行完整测试
pytest test/test_suite.py -v

# 运行特定测试
pytest test/test_suite.py -v -k "BooleanTest"
```

### 查看日志

```bash
# 查看 SQLAlchemy 日志
PYTHONPATH=. python -c "
import logging
logging.basicConfig()
logging.getLogger('sqlalchemy.engine').setLevel(logging.DEBUG)

from sqlalchemy import create_engine
engine = create_engine('yashandb+yaspy://sys:password@127.0.0.1:1688/test')
print(engine.connect())
"
```

### 社区支持

- GitHub Issues: https://github.com/yashan-technologies/yashandb-sqlalchemy/issues
- YashanDB 官网: https://www.yashandb.com/
