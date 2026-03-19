---
title: YashanDB 事务隔离级别
description: 事务隔离级别最佳实践
tags: yashandb, transactions, isolation, locking, concurrency
---

# 事务隔离级别

> **参考文档**：产品文档/概念手册/事务机制/并发控制和一致性.md

**默认使用 READ COMMITTED。** 这是 YashanDB 的默认隔离级别，在大多数场景下能够提供较好的并发性能与数据一致性平衡。仅在明确了解后果的情况下才更改隔离级别。

> **官方说明**："YashanDB支持的事务隔离级别为读已提交和可串行化。"

```sql
-- 查看当前隔离级别
SELECT @@transaction_isolation;

-- 设置会话级隔离级别
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- 设置全局隔离级别（仅影响新会话）
SET GLOBAL transaction_isolation = 'READ-COMMITTED';
```

## 事务隔离级别概述

> **官方说明**："数据库事务的并发可能会对事务之间的读写产生一定影响。事务隔离级别能确保多个并发执行时的行为，影响数据的一致性和并发性能。在ANSI标准中定义了四种事务隔离级别。"

### 事务并发问题

| 问题 | 说明 |
|------|------|
| 脏读 | 一个事务读取了另外一个尚未提交事务修改的数据 |
| 不可重复读 | 同一个事务内，多条语句重复读取同一行数据，读取到的**数据**发生变化 |
| 幻读 | 同一事务内，多条语句重复读取同一条件的数据，读取到的**结果集数量**发生变化 |

### 隔离级别与并发问题

| 隔离级别 | 脏读 | 不可重复读 | 幻读 |
|----------|------|----------|------|
| 读未提交 (READ UNCOMMITTED) | 可能 | 可能 | 可能 |
| 读已提交 (READ COMMITTED) | 不可能 | 可能 | 可能 |
| 可重复读 (REPEATABLE READ) | 不可能 | 不可能 | 可能 |
| 可串行化 (SERIALIZABLE) | 不可能 | 不可能 | 不可能 |

> **注意**：YashanDB 只支持 READ COMMITTED 和 SERIALIZABLE 两种隔离级别。

## READ COMMITTED（读已提交）

READ COMMITTED 是 YashanDB 的默认隔离级别。

> **官方说明**："此隔离级别保证事务访问其他事务修改数据时，只能读取已提交的数据版本。避免出现脏读，但存在不可重复读现象。类级别还包含读当前提交（Current Committed），只能读取已提交的数据版本，不存在脏读和幻读，但无法保证语句内的读一致性，且可能存在不可重复读场景。"

### 主要特点

- **快照读取**：每次 SELECT 执行时都会创建新的快照，读取最新的已提交数据
- **避免脏读**：只能读取已提交的数据，不会读取到未提交的数据
- **可能出现不可重复读**：同一事务中两次相同的 SELECT 可能返回不同的结果
- **可能出现幻读**：新的记录可能被其他事务插入，导致查询结果集变化

### 适用场景

- 报表查询和数据分析
- 并发写入较多的 OLTP 系统
- 对数据实时性要求较高的场景

## SERIALIZABLE（可串行化）

> **官方说明**："最严格的隔离级别，事务之间完全隔离，保证了并发事务之间不会产生冲突，避免了脏读、不可重复读和幻读。"

> **官方说明**："YashanDB支持的串行化属于快照级串行化，提供了事务级一致性读能力，并提供写写串行化冲突检测机制。"

这是最严格的隔离级别，事务之间完全串行执行。虽然提供了最强的数据一致性，但会显著降低并发性能，应谨慎使用。

### SERIALIZABLE 主要特点

> **官方说明**："事务内的每条语句严格按照事务级一致性读进行，事务启动时会获取当前系统的SCN作为当前事务查询的SCN。整个可串行化事务运行过程中采用同一个SCN进行查询，生成一致性的结果集。"

- **事务级快照**：事务启动时获取当前系统的SCN作为查询SCN，整个事务期间使用同一SCN
- **避免不可重复读**：同一事务中多次 SELECT 返回相同结果
- **避免幻读**：新插入的记录不会被其他事务添加
- **写冲突检测**：如果等待的事务提交，会触发串行化写冲突错误

### SERIALIZABLE 适用场景

- 金融交易处理
- 需要严格数据一致性保证的业务逻辑
- check-then-act 模式（检查后操作）

## MVCC 机制

> **官方说明**："YashanDB通过多版本并发控制、事务隔离级别以及锁来维护数据库的一致性。多版本并发控制：主要处理读写之间的并发。"

YashanDB 的 MVCC 实现通过以下方式工作：

1. 每条记录都包含隐藏的版本信息
2. 读取时根据事务视图选择合适的版本
3. 过期的版本通过后台进程清理

### 读一致性

> **官方说明**："YashanDB通过数据多版本实现读一致性，在修改数据时，会在UNDO表空间中保留数据的历史版本，使读写互不阻塞，并发事务可以访问一致版本。"

- 查询一致性：用户执行SQL语句查询到的都是已经提交的、可见的、一致的数据版本
- 读写不阻塞：用户执行SQL语句修改数据时，不阻塞并发事务查询正在修改的数据

### 锁与 MVCC 的交互

- 普通的 SELECT 语句（非锁定读取）使用 MVCC 快照，不会获取锁
- SELECT FOR UPDATE、UPDATE、DELETE 等语句会获取行锁
- 行锁与 MVCC 可以共存，锁用于防止并发修改，MVCC 用于提供一致性读取

## 隔离级别选择建议

| 场景 | 推荐隔离级别 | 说明 |
|------|-------------|------|
| 一般 OLTP 业务 | READ COMMITTED | 默认值，并发性能好 |
| 金融转账 | SERIALIZABLE | 保证数据一致性 |
| 报表查询 | READ COMMITTED | 读取最新数据 |
| check-then-insert | SERIALIZABLE | 防止重复插入 |
| 大批量导入 | READ COMMITTED | 减少锁竞争 |

## 设置隔离级别的语法

### 会话级设置

```sql
-- 设置当前会话的隔离级别
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- 或使用 SET SESSION
SET SESSION transaction_isolation = 'READ-COMMITTED';
SET SESSION transaction_isolation = 'SERIALIZABLE';
```

### 全局设置

```sql
-- 设置全局隔离级别（影响新会话）
SET GLOBAL transaction_isolation = 'READ-COMMITTED';

-- 查看全局设置
SELECT @@global.transaction_isolation;
```

### 事务开始时设置

```sql
-- 在事务开始时设置
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- 事务操作...
COMMIT;
```

### 注意事项

1. 隔离级别的设置应在事务开始之前或事务开始时进行
2. 已在执行中的事务无法更改隔离级别
3. 全局设置只影响新建立的连接，不影响当前连接
4. 在生产环境中修改全局隔离级别需谨慎，建议先在测试环境验证
5. YashanDB 只支持 READ COMMITTED 和 SERIALIZABLE 两种隔离级别

---

### 参考

- [产品文档/概念手册/事务机制/并发控制和一致性.md](../../../产品文档/概念手册/事务机制/并发控制和一致性.md)
- 产品文档/概念手册/事务机制/事务管理.md
