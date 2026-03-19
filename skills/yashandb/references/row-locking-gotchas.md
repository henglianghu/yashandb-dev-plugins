---
title: YashanDB 行锁陷阱
description: 行锁与并发控制
tags: yashandb, locking, row-locks, concurrency, transactions
---

# 行锁陷阱

> **参考文档**：产品文档/概念手册/事务机制/并发控制和一致性.md

YashanDB 使用行级锁来实现并发控制，但锁的实际作用范围往往比预期更广。理解这些细节对于编写高效且安全的并发应用至关重要。

## SELECT FOR UPDATE 的使用

SELECT FOR UPDATE 用于获取行的独占锁，防止其他事务同时修改这些行。

### 基本语法

```sql
-- 锁定单行
SELECT * FROM accounts WHERE id = 5 FOR UPDATE;

-- 锁定多行（IN 子句）
SELECT * FROM accounts WHERE id IN (1, 2, 3) FOR UPDATE;

-- 锁定范围
SELECT * FROM orders WHERE created_at < '2024-01-01' FOR UPDATE;
```

### 典型用途

```sql
-- 1. 防止重复插入（需结合业务逻辑）
BEGIN;
SELECT * FROM accounts WHERE email = 'test@example.com' FOR UPDATE;
-- 检查是否存在，执行相应操作
INSERT INTO accounts (id, email, name) VALUES (seq_accounts.NEXTVAL, 'test@example.com', 'Test');
-- 或执行 UPDATE
UPDATE accounts SET name = 'Test' WHERE email = 'test@example.com';
COMMIT;

-- 2. 库存扣减
BEGIN;
SELECT * FROM inventory WHERE product_id = 100 FOR UPDATE;
UPDATE inventory SET stock = stock - 1 WHERE product_id = 100;
COMMIT;

-- 3. 账户余额更新
BEGIN;
SELECT * FROM accounts WHERE id = 5 FOR UPDATE;
UPDATE accounts SET balance = balance + 100 WHERE id = 5;
COMMIT;
```

## 锁粒度控制（行锁 vs 表锁）

YashanDB 主要使用行级锁，但在某些情况下会使用表锁。

### 行锁

行锁主要发生在 DML 语句修改数据时，事务修改数据时会锁定要修改的行记录。在 YashanDB 中行锁是一种物理锁，通过 Block 上的 Xslot（事务槽位）登记锁信息。

**重要特性**：
- 行锁只有排他锁（Exclusive Lock）一种类型，不支持行级共享锁
- 行锁在事务提交或回滚时自动释放

### 何时使用行锁

- 大多数并发写入场景
- 需要细粒度锁控制的业务

### 何时使用表锁

- DDL 语句（如 ALTER TABLE）需要表锁
- 可以通过显式语句锁定整张表

```sql
-- 显式表锁（排他模式）
LOCK TABLE accounts IN EXCLUSIVE MODE;

-- 解锁（事务结束时自动释放）
COMMIT;
```

**说明**：与 MySQL 的 `LOCK TABLES ... READ/WRITE` 语法不同，YashanDB 使用 `LOCK TABLE ... IN EXCLUSIVE MODE` 语法。

## 隐式锁与显式锁

### 隐式锁

隐式锁由 UPDATE、DELETE、INSERT 等语句自动获取，无需显式声明：

```sql
-- UPDATE 自动对修改的行加排他锁
UPDATE accounts SET balance = 500 WHERE id = 1;

-- DELETE 自动对删除的行加排他锁
DELETE FROM accounts WHERE id = 1;

-- INSERT 自动对插入的行加排他锁
INSERT INTO accounts (id, balance) VALUES (10, 1000);
```

### 显式锁

显式锁通过 SELECT FOR UPDATE 或 LOCK TABLE 语句显式声明：

```sql
-- 显式行锁
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;

-- 显式表锁（排他模式）
LOCK TABLE accounts IN EXCLUSIVE MODE;
```

### 隐式锁与显式锁的转换

隐式锁和显式锁可以共存，SELECT FOR UPDATE 语句可以在已存在隐式锁的基础上添加显式锁。

## 锁与并发性能的关系

锁机制在保证数据一致性的同时，也会影响并发性能。

### 锁竞争

锁竞争发生在多个事务同时请求相同的锁：

```sql
-- Session 1
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
-- 持有锁，等待用户确认

-- Session 2
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
-- 被阻塞，等待 Session 1 释放锁
```

### 减少锁竞争的方法

1. **缩小锁范围**：只锁定必要的行，而不是整个表
2. **减少锁持有时间**：快速获取锁，快速释放
3. **使用合适的隔离级别**：根据业务需求选择最低隔离级别
4. **优化索引**：确保 WHERE 条件使用索引，避免全表扫描

```sql
-- 不佳：锁定整个表
BEGIN;
SELECT * FROM orders FOR UPDATE;
-- 锁定所有订单

-- 良好：只锁定需要的行
BEGIN;
SELECT * FROM orders WHERE status = 'pending' FOR UPDATE;
-- 只锁定待处理的订单
```

## 乐观锁 vs 悲观锁

### 悲观锁

假设冲突会发生，在操作前先获取锁：

```sql
-- 悲观锁：先锁定，再修改
BEGIN;
SELECT * FROM accounts WHERE id = 5 FOR UPDATE;
-- 检查余额
UPDATE accounts SET balance = balance - 100 WHERE id = 5;
COMMIT;
```

适用场景：
- 冲突概率高的场景
- 短事务
- 需要强一致性保证

### 乐观锁

假设冲突较少发生，在提交时检查是否有冲突：

```sql
-- 乐观锁：使用版本号
ALTER TABLE accounts ADD COLUMN version INT DEFAULT 0;

-- 读取数据
SELECT balance, version FROM accounts WHERE id = 5;
-- 假设 balance=1000, version=1

-- 更新时检查版本
UPDATE accounts
SET balance = balance - 100, version = version + 1
WHERE id = 5 AND version = 1;

-- 如果版本不匹配（被其他事务修改），更新0行，需要重试
```

适用场景：
- 冲突概率低的场景
- 读多写少的场景
- 长事务

### 性能对比

| 特性 | 悲观锁 | 乐观锁 |
|------|--------|--------|
| 冲突处理 | 获取锁时 | 提交时 |
| 等待时间 | 长（等待锁） | 短（可能回滚重试） |
| 适用场景 | 高并发写入 | 低并发写入 |
| 实现复杂度 | 低 | 中 |

## 常见陷阱与最佳实践

### 陷阱 1：无索引 UPDATE 锁定多行

```sql
-- 错误：没有索引，会锁定多行
UPDATE orders SET status = 'processed' WHERE status = 'pending';

-- 正确：确保有索引
CREATE INDEX idx_orders_status ON orders(status);
UPDATE orders SET status = 'processed' WHERE status = 'pending';
```

### 陷阱 2：长事务持有锁

```sql
-- 错误：事务中包含耗时操作
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
-- 发送邮件、调用API等耗时操作
UPDATE accounts SET balance = 500 WHERE id = 1;
COMMIT;

-- 正确：保持事务简短
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET balance = 500 WHERE id = 1;
COMMIT;
-- 耗时操作在事务外
```

### 陷阱 3：混用锁与 MVCC

```sql
-- 陷阱：混用锁定读取和快照读取
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

BEGIN;
-- 快照读取
SELECT balance FROM accounts WHERE id = 1;
-- 结果：1000

-- 锁定读取
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
-- 结果：1500（可能是其他事务已提交的最新值）

-- 两个查询返回不同结果，可能导致业务逻辑错误
COMMIT;

-- 解决：明确使用一致的方式读取
BEGIN;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
-- 处理业务
COMMIT;
```

### 最佳实践总结

1. **始终使用索引**：确保 UPDATE/DELETE 的 WHERE 条件有索引
2. **保持事务简短**：快速获取锁，快速释放
3. **一致的访问顺序**：所有事务按相同顺序访问资源
4. **选择合适的锁策略**：悲观锁还是乐观锁根据场景选择
5. **避免长事务**：长事务会长时间持有锁，影响并发性能
6. **实现重试机制**：死锁时能够自动重试

### 参考

- [产品文档/概念手册/事务机制/并发控制和一致性.md](../产品文档/概念手册/事务机制/并发控制和一致性.md)
