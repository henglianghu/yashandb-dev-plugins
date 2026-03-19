# Python 驱动连接详细指南

## 基础连接方式

### 使用 yasdb

```python
import yasdb

# 方式一：使用参数
conn = yasdb.connect(
    host="192.168.1.2",
    port=1688,
    user="system",
    password="oracle"
)

# 方式二：使用 dsn 字符串
conn = yasdb.connect("system/oracle@192.168.1.2:1688")

# 执行查询
cursor = conn.cursor()
cursor.execute("SELECT 1 FROM dual")
result = cursor.fetchone()
print(f"YashanDB 连接成功! 查询结果: {result[0]}")

cursor.close()
conn.close()
```

### 使用 yaspy（推荐）

```python
import yaspy

conn = yaspy.connect(
    user="system",
    password="oracle",
    dsn="192.168.1.2:1688"
)

cursor = conn.cursor()
cursor.execute("SELECT 1 FROM dual")
print(cursor.fetchone())

cursor.close()
conn.close()
```

## 连接池（仅 yaspy 支持）

```python
import yaspy

pool = yaspy.SessionPool(
    user="system",
    password="oracle",
    dsn="192.168.1.2:1688",
    min=2,      # 最小连接数
    max=10,     # 最大连接数
    increment=1,  # 每次新增连接数
    getmode=0,    # 获取模式
)

# 获取连接
connection = pool.acquire()
cursor = connection.cursor()

# 执行操作
cursor.execute("SELECT * FROM users")
results = cursor.fetchall()

# 归还连接
cursor.close()
pool.release(connection)

# 关闭连接池
pool.close()
```

## 事务处理

```python
import yasdb

# 手动控制事务（默认）
conn = yasdb.connect(user="system", password="oracle", host="192.168.1.2")
cursor = conn.cursor()

try:
    cursor.execute("INSERT INTO users (name) VALUES ('Alice')")
    cursor.execute("INSERT INTO users (name) VALUES ('Bob')")
    conn.commit()  # 提交事务
    print("事务提交成功")
except Exception as e:
    conn.rollback()  # 回滚事务
    print(f"事务回滚: {e}")
finally:
    cursor.close()
    conn.close()

# 自动提交（仅 yaspy 支持）
import yaspy
conn = yaspy.connect(user="system", password="oracle", dsn="192.168.1.2:1688", autocommit=True)
cursor = conn.cursor()
cursor.execute("INSERT INTO users (name) VALUES ('Charlie')")
cursor.close()
conn.close()
```

## 使用参数绑定

```python
import yasdb

conn = yasdb.connect(user="system", password="oracle", host="192.168.1.2")
cursor = conn.cursor()

# 位置参数绑定（推荐，使用 :1, :2 格式）
cursor.execute(
    "SELECT * FROM users WHERE name = :1 AND status = :2",
    ("Alice", 1)
)

# 批量插入
data = [
    (1, "test1"),
    (2, "test2"),
    (3, "test3")
]
cursor.executemany("INSERT INTO example_table VALUES (:1, :2)", data)
conn.commit()

cursor.close()
conn.close()
```

## SQLAlchemy 使用

```bash
pip install sqlalchemy-yasdb
```

```python
from sqlalchemy import create_engine, text

dsn = "192.168.1.2:1688"

# 创建引擎
engine = create_engine(f"yasdb+yasdb://{dsn}")

# 执行查询
with engine.connect() as conn:
    result = conn.execute(text("SELECT 1 FROM dual"))
    for row in result:
        print(f"查询结果: {row[0]}")
```