---
title: YashanDB 死锁处理
description: 死锁诊断与预防
tags: yashandb, deadlocks, transactions, locking, concurrency
---

# 死锁处理

> **参考文档**：产品文档/概念手册/事务机制/并发控制和一致性.md

死锁是并发数据库系统中常见的问题，当两个或多个事务相互等待对方持有的锁时就会发生死锁。YashanDB 自动检测死锁并回滚其中一个事务（牺牲事务）以解除死锁状态。

## 死锁的成因与原理

死锁通常发生在以下几种场景：

### 1. 循环等待

最常见的死锁类型。事务 A 持有锁 X 并等待锁 Y，而事务 B 持有锁 Y 并等待锁 X，形成循环等待。

```sql
-- 场景：两个事务以不同顺序访问相同的行

-- Session 1
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;  -- 持有 id=1 的锁
-- 等待 id=2 的锁

-- Session 2 (同时执行)
BEGIN;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;  -- 持有 id=2 的锁
-- 尝试更新 id=1，等待 id=1 的锁（被 Session 1 持有）
UPDATE accounts SET balance = balance + 50 WHERE id = 1;   -- 死锁发生
```

### 2. 间隙锁冲突

在 REPEATABLE READ 隔离级别下，Next-Key 锁（行锁 + 间隙锁）可能导致更复杂的死锁情况。

```sql
-- Session 1
BEGIN;
SELECT * FROM orders WHERE id BETWEEN 5 AND 10 FOR UPDATE;
-- 锁定 5-10 的行及间隙

-- Session 2 (同时执行)
BEGIN;
SELECT * FROM orders WHERE id = 7 FOR UPDATE;
-- 尝试锁定 id=7，但被 Session 1 阻塞

-- Session 1 尝试插入 id=8，死锁可能发生
INSERT INTO orders (id, amount) VALUES (8, 100);
```

### 3. 索引缺失导致的锁扩大

当 UPDATE 或 DELETE 语句的 WHERE 条件缺少索引时，数据库可能需要扫描全表，从而锁定大量行，增加死锁风险。

```sql
-- status 字段没有索引
UPDATE orders SET processed = 1 WHERE status = 'pending';

-- 这会锁定表中所有行，其他并发事务更容易发生死锁
```

## 死锁检测机制

> **官方说明**："当多个事务获取并修改同一数据库资源时，会产生资源等待（例如等待表锁释放、等待行锁释放等）。当多个事务互相等待彼此释放资源时会产生死锁现象。此时单靠并发事务自身无法识别并解除死锁，YashanDB支持对产生死锁的事务进行检测并处理。"

YashanDB 内置死锁检测器，定期检查事务等待图是否存在环。当检测到死锁时，会自动选择其中一个事务作为牺牲者（victim）并回滚。

### 表锁死锁

> **官方说明**："以显式加表锁为例，构造表锁死锁场景。"

表锁死锁发生在多个事务以不同的顺序请求表级排他锁时：

```sql
-- Session 1
LOCK TABLE t1 IN EXCLUSIVE MODE;  -- 持有t1的排他锁

-- Session 2 (同时执行)
LOCK TABLE t2 IN EXCLUSIVE MODE;  -- 持有t2的排他锁

-- Session 1 尝试获取t2的排他锁，等待Session 2
LOCK TABLE t2 IN EXCLUSIVE MODE;

-- Session 2 尝试获取t1的排他锁，等待Session 1
LOCK TABLE t1 IN EXCLUSIVE MODE;

-- 死锁检测：数据库检测到互相等待，报死锁错误并解除死锁
```

### 行锁死锁

> **官方说明**："以更新事务为例，构造行锁死锁场景。"

行锁死锁发生在多个事务以不同的顺序更新多行数据时：

```sql
-- 创建测试表
CREATE TABLE t (id int);
INSERT INTO t VALUES (1);
INSERT INTO t VALUES (2);
COMMIT;

-- Session 1: 更新row1
UPDATE t SET id = -id WHERE id = 1;

-- Session 2: 更新row2
UPDATE t SET id = id * 10 WHERE id = 2;

-- Session 1: 尝试更新row2，等待Session 2
UPDATE t SET id = -id WHERE id = 2;

-- Session 2: 尝试更新row1，等待Session 1
UPDATE t SET id = id * 10 WHERE id = 1;

-- 死锁检测：数据库检测到互相等待，报死锁错误并解除死锁
```

### 牺牲者选择策略

YashanDB 通常选择回滚成本较低的事务作为牺牲者：
- 修改行数较少的事务
- 执行时间较短的事务
- 隔离级别较低的事务

### 死锁检测频率

死锁检测不是实时进行的，存在一定的延迟。在高并发场景下，可能发生：
- 死锁检测之前的短暂阻塞
- 多个事务同时等待同一锁

## 如何分析与解决死锁

### 查看死锁信息

```sql
-- 查看最近的死锁信息
SELECT * FROM V$DEADLOCK_INFO;

-- 查看当前锁等待情况
SELECT * FROM V$LOCK_WAIT;

-- 查看活动事务的锁持有情况
SELECT * FROM V$LOCK WHERE type = 'TX';
```

### 死锁日志

YashanDB 会在日志中记录死锁的详细信息，包括：

1. 参与死锁的事务 ID
2. 等待的锁信息（表名、行ID、锁类型）
3. 持有锁的信息
4. 牺牲的事务

```sql
-- 查看系统日志中的死锁记录
SELECT message, timestamp
FROM V$LOG
WHERE message LIKE '%deadlock%';
```

### 分析死锁步骤

1. **获取死锁信息**：从 V$DEADLOCK_INFO 或日志中获取
2. **识别冲突的 SQL**：找出导致死锁的具体语句
3. **分析锁等待顺序**：确定事务获取锁的顺序
4. **优化访问模式**：调整 SQL 或事务顺序

## 死锁日志解读

典型的死锁日志包含以下关键信息：

```
DEADLOCK DETECTED
Transaction 1: SID=100, SQL=UPDATE accounts SET balance=...
Transaction 2: SID=101, SQL=UPDATE orders SET amount=...
Lock wait:
  Transaction 100 waiting for TX lock on row id=5 of table accounts
  Transaction 101 holding TX lock on row id=5 of table accounts
Victim: Transaction 100
```

解读要点：
- 识别参与死锁的事务（通常有两个或更多）
- 找出每个事务正在等待的锁
- 找出每个事务持有的锁
- 分析锁冲突的原因

## 预防死锁的最佳实践

### 1. 保持一致的访问顺序

确保所有事务以相同的顺序访问资源（表和行）。

```sql
-- 不推荐：不同的事务以不同顺序访问
-- Session 1: 先更新 id=1，再更新 id=2
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance - 100 WHERE id = 2;

-- Session 2: 先更新 id=2，再更新 id=1
UPDATE accounts SET balance = balance + 50 WHERE id = 2;
UPDATE accounts SET balance = balance + 50 WHERE id = 1;
-- 可能导致死锁

-- 推荐：所有事务按相同顺序访问
-- Session 1 和 Session 2 都先更新 id=1，再更新 id=2
```

### 2. 减少锁持有时间

将锁持有时间控制在最短范围内：

- 避免在事务中执行用户交互操作
- 将非数据库操作移到事务外
- 使用批量操作减少数据库往返

```sql
-- 不推荐：事务中包含耗时操作
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;  -- 获取锁
-- 这里做一些耗时的业务处理（如调用外部API）
UPDATE accounts SET balance = 500 WHERE id = 1;   -- 释放锁
COMMIT;

-- 推荐：快速获取锁，快速释放
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET balance = 500 WHERE id = 1;
COMMIT;
-- 耗时操作在事务外进行
```

### 3. 合理使用索引

确保 UPDATE/DELETE 的 WHERE 条件使用索引，避免全表扫描导致的锁扩大。

```sql
-- 确保索引存在
CREATE INDEX idx_orders_status ON orders(status);

-- 使用索引的查询
UPDATE orders SET processed = 1 WHERE status = 'pending';
-- 只锁定匹配的行，而不是全表
```

### 4. 使用较低的隔离级别

在合适场景下使用 READ COMMITTED 隔离级别，减少间隙锁的使用。

```sql
-- 对于不需要防止幻读的场景，使用 READ COMMITTED
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

### 5. 避免长时间事务

保持事务简短，避免跨多个业务步骤的长事务。

```sql
-- 不推荐：长事务
BEGIN;
-- 步骤1：更新库存
UPDATE inventory SET count = count - 1 WHERE product_id = 100;
-- 步骤2：记录日志
INSERT INTO logs (...) VALUES (...);
-- 步骤3：发送通知
-- 步骤4：更新订单状态
-- ... 更多操作
COMMIT;  -- 事务持续时间长，锁持有时间长

-- 推荐：拆分成长事务为多个短事务
UPDATE inventory SET count = count - 1 WHERE product_id = 100;
COMMIT;

INSERT INTO logs (...) VALUES (...);
COMMIT;
```

## 死锁重试机制

应用程序应该实现死锁重试逻辑，当捕获到死锁错误时自动重试。

### 错误处理

```sql
-- YashanDB 死锁错误码
-- 错误码 4022: Deadlock detected
```

### 应用层重试模式

```python
# Python 示例：死锁重试
import time

def execute_with_retry(func, max_retries=3, base_delay=0.1):
    """执行函数，死锁时自动重试"""
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if "deadlock" in str(e).lower() and attempt < max_retries - 1:
                # 指数退避
                delay = base_delay * (2 ** attempt)
                time.sleep(delay)
                continue
            raise

# 使用示例
def transfer_funds(from_id, to_id, amount):
    def _transfer():
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("BEGIN")
                cur.execute("UPDATE accounts SET balance = balance - ? WHERE id = ?", (amount, from_id))
                cur.execute("UPDATE accounts SET balance = balance + ? WHERE id = ?", (amount, to_id))
                cur.execute("COMMIT")
    return execute_with_retry(_transfer)
```

### 重试注意事项

1. **幂等性**：确保操作可以安全重试
2. **退避策略**：使用指数退避避免连续冲突
3. **最大重试次数**：设置合理的重试次数限制
4. **日志记录**：记录重试次数和原因用于分析

## 常见死锁场景与解决方案

### 场景 1：转账业务

```sql
-- 死锁：两个转账同时进行
-- 转账A: 账户1 -> 账户2
-- 转账B: 账户2 -> 账户1

-- 解决方案：始终按账户ID顺序获取锁
-- 转账A
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
SELECT * FROM accounts WHERE id = 2 FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;

-- 转账B（修改为相同顺序）
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
SELECT * FROM accounts WHERE id = 2 FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 2;
UPDATE accounts SET balance = balance + 100 WHERE id = 1;
COMMIT;
```

### 场景 2：库存扣减

```sql
-- 死锁：多个并发扣减同一商品库存

-- 解决方案：使用单条 UPDATE 语句
UPDATE inventory SET count = count - 1
WHERE product_id = 100 AND count > 0;

-- 或者使用 SELECT FOR UPDATE 先锁定记录
BEGIN;
SELECT * FROM inventory WHERE product_id = 100 FOR UPDATE;
UPDATE inventory SET count = count - 1 WHERE product_id = 100;
COMMIT;
```

### 场景 3：批量更新

```sql
-- 死锁：批量更新多条记录

-- 解决方案 1：按主键排序
UPDATE accounts SET status = 'processed'
WHERE id IN (1, 2, 3, 4, 5)
ORDER BY id;

-- 解决方案 2：分批处理
BEGIN;
UPDATE accounts SET status = 'processed' WHERE id BETWEEN 1 AND 100;
COMMIT;

BEGIN;
UPDATE accounts SET status = 'processed' WHERE id BETWEEN 101 AND 200;
COMMIT;
```

### 参考

- [产品文档/概念手册/事务机制/并发控制和一致性.md](../../../产品文档/概念手册/事务机制/并发控制和一致性.md)
