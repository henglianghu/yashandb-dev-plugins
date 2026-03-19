---
title: YashanDB 复合索引设计
description: 多列索引设计原则、左前缀规则、列顺序优化
tags: yashandb, indexes, composite-index, query-optimization, leftmost-prefix
---

# 复合索引设计

> **参考文档**：产品文档/概念手册/关系数据结构/模式对象/索引.md

复合索引（Composite Index）是指在表的多列上创建的索引。与单列索引相比，复合索引能够更高效地支持多列过滤条件的查询，但在设计时需要遵循一定的原则才能发挥其最大效用。

## 左前缀规则（Leftmost Prefix Rule）

左前缀规则是复合索引最核心的概念。它决定了索引在哪些查询条件下可以被使用。

```sql
-- 创建复合索引 (a, b, c)
CREATE INDEX idx_table_abc ON my_table (a, b, c);
```

对于上述索引，以下查询可以使用索引：

- `WHERE a = 1` —— 使用索引列 a
- `WHERE a = 1 AND b = 2` —— 使用索引列 a 和 b
- `WHERE a = 1 AND b = 2 AND c = 3` —— 使用全部索引列
- `WHERE a = 1 AND c = 3` —— 只能使用索引列 a（跳过 b 后，c 无法用于过滤）

以下查询无法使用索引：

- `WHERE b = 2` —— 从索引中间开始，无法定位
- `WHERE b = 2 AND c = 3` —— 未使用最左列

## 复合索引列顺序原则

选择复合索引列顺序时，应遵循 **等值（Equality）-> 范围（Range）-> 排序（Sort）** 的原则。

### 等值优先原则

等值条件（=、IN）应该放在范围条件之前，因为等值条件可以充分利用索引进行精确匹配。

```sql
-- 查询：WHERE tenant_id = ? AND status = ? AND created_at > ?
-- 正确：等值列在前，范围列在后
CREATE INDEX idx_orders_tenant_status_created
    ON orders (tenant_id, status, created_at);

-- 不推荐：范围列在前，导致后续列无法用于过滤
CREATE INDEX idx_orders_created_tenant_status
    ON orders (created_at, tenant_id, status);
```

### 范围列的影响

以下操作符会触发范围扫描，导致其右侧的索引列无法用于过滤：

- `>`、`<`、`>=、<=`
- `BETWEEN`
- `LIKE 'prefix%'`（前导通配符）
- 大列表的 `IN (...)`

```sql
-- 范围列后的列仍可用于排序，但不能用于过滤
CREATE INDEX idx_orders_status_created ON orders (status, created_at);

-- 查询：WHERE status = 'pending' AND created_at > '2024-01-01'
-- 索引使用情况：status 用于过滤，created_at 用于范围扫描
-- 注意：此查询可以利用索引，但 created_at 列无法进一步过滤其他列
```

### 排序与复合索引

当 ORDER BY 列与复合索引列顺序完全匹配时，可以避免额外的排序操作。

```sql
-- 索引：(status, created_at)
-- 可以利用索引的排序查询
SELECT * FROM orders
WHERE status = 'completed'
ORDER BY created_at DESC;  -- 匹配索引顺序

-- 无法利用索引的排序查询
SELECT * FROM orders
WHERE status = 'completed'
ORDER BY created_at ASC;   -- 排序方向与索引相反（某些版本可能支持反向扫描）
```

## 索引列选择建议

### 考虑因素

选择复合索引列时，应综合考虑以下因素：

1. **查询频率**：优先为高频查询设计索引
2. **选择性**：在等值条件中，选择性高的列放在前面
3. **覆盖度**：考虑是否能同时覆盖查询的 WHERE 和 SELECT 列
4. **维护成本**：避免创建过多复合索引

```sql
-- 高选择性列优先：tenant_id 有 10000 个不同值，status 只有 5 个
-- 查询：WHERE tenant_id = ? AND status = ?
CREATE INDEX idx_orders_tenant_status ON orders (tenant_id, status);
-- 优于：CREATE INDEX idx_orders_status_tenant ON orders (status, tenant_id);
```

### 复合索引 vs 多个单列索引

YashanDB 优化器在某些情况下可以使用索引合并（Index Merge），但复合索引通常比多个单列索引更高效：

- 复合索引只需一次索引查找
- 索引合并需要多次查找并合并结果

```sql
-- 复合索引
CREATE INDEX idx_orders_user_status ON orders (user_id, status);

-- 替代多个单列索引（通常不推荐）
CREATE INDEX idx_orders_user ON orders (user_id);
CREATE INDEX idx_orders_status ON orders (status);
```

## 什么情况下复合索引无效

复合索引虽然强大，但在某些情况下会失效或不发挥作用。理解这些场景可以帮助避免常见的索引设计错误。

### 跳过最左列

复合索引遵循严格的左前缀规则。如果查询条件没有使用最左边的列，索引将无法发挥作用。

```sql
-- 索引：(a, b, c)
-- 以下查询无法使用复合索引
SELECT * FROM t WHERE b = 1;
SELECT * FROM t WHERE c = 1;
SELECT * FROM t WHERE b = 1 AND c = 1;

-- 正确使用索引的方式
SELECT * FROM t WHERE a = 1;           -- 使用列 a
SELECT * FROM t WHERE a = 1 AND b = 2; -- 使用列 a 和 b
SELECT * FROM t WHERE a = 1 AND b = 2 AND c = 3; -- 使用全部列
```

**实际业务场景示例**：

假设有一个用户表，用户ID和邮箱都是常用的查询条件：

```sql
-- 索引设计：(user_id, email)
CREATE INDEX idx_users_id_email ON users (user_id, email);

-- 有效的查询
SELECT * FROM users WHERE user_id = 1001;
SELECT * FROM users WHERE user_id = 1001 AND email = 'test@example.com';

-- 无效的查询（跳过了最左列 user_id）
SELECT * FROM users WHERE email = 'test@example.com';
```

### 索引列参与运算

当索引列参与算术运算或函数运算时，数据库无法使用索引，因为索引中存储的是原始值而非计算后的值。

```sql
-- 索引无效：索引列参与运算
SELECT * FROM orders WHERE YEAR(created_at) = 2024;
SELECT * FROM orders WHERE status + 1 = 2;
SELECT * FROM products WHERE price * 1.1 > 100;

-- 正确方式：将运算移到常量一侧
SELECT * FROM orders WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';
SELECT * FROM orders WHERE status = 1;  -- 不使用 status + 1
SELECT * FROM products WHERE price > 100 / 1.1;
```

### 使用函数或表达式

对索引列使用函数会阻止索引使用，这是开发中常见的错误。

```sql
-- 索引无效：对列使用函数
SELECT * FROM users WHERE LOWER(username) = 'admin';
SELECT * FROM orders WHERE CONCAT(order_no, '') = 'ORD001';
SELECT * FROM products WHERE SUBSTRING(category, 1, 3) = ' ELE';

-- 解决方案一：使用函数索引（如果版本支持）
CREATE INDEX idx_users_lower_username ON users (LOWER(username));

-- 解决方案二：改写查询
SELECT * FROM users WHERE username = 'ADMIN';  -- 假设不区分大小写存储
```

### 前导通配符的 LIKE 查询

LIKE 查询中的前导通配符（%）会使索引失效，因为数据库无法通过索引定位匹配的行。

```sql
-- 索引无效：前导通配符
SELECT * FROM orders WHERE order_no LIKE '%123';
SELECT * FROM products WHERE name LIKE '%phone%';

-- 可以使用索引：后置通配符
SELECT * FROM orders WHERE order_no LIKE 'ORD123%';
SELECT * FROM products WHERE name LIKE 'iPhone%';
```

### 数据类型不匹配

当查询条件的数据类型与索引列的数据类型不匹配时，索引可能无法使用。

```sql
-- 假设 user_id 是 BIGINT 类型
CREATE INDEX idx_orders_user ON orders (user_id);

-- 可能导致索引失效的类型转换
SELECT * FROM orders WHERE user_id = '1001';  -- 字符串与数字比较

-- 正确做法：使用匹配的数据类型
SELECT * FROM orders WHERE user_id = 1001;    -- 使用数字类型
```

### 混合使用索引列和不使用索引列

当查询中混合了索引列和非索引列的过滤条件时，索引可能无法完全发挥作用。

```sql
-- 索引：(status, created_at)
CREATE INDEX idx_orders_status_created ON orders (status, created_at);

-- 部分有效：status 使用索引，created_at 可以用于过滤
SELECT * FROM orders WHERE status = 'pending' AND created_at > '2024-01-01';

-- 可能无效：非索引列导致全表扫描
SELECT * FROM orders WHERE status = 'pending' AND remark = 'urgent';
```

## 索引条件下推（Index Condition Pushdown, ICP）

索引条件下推（Index Condition Pushdown，简称 ICP）是查询优化器的一种重要优化策略。它的核心思想是将过滤条件下推到存储引擎层面执行，而不是在服务器层过滤，从而减少不必要的数据读取。

### ICP 的工作原理

在没有 ICP 的情况下，查询执行流程如下：
1. 通过索引找到匹配的索引项
2. 根据索引项中的主键值回表读取完整数据行
3. 在服务器层应用 WHERE 条件过滤

启用 ICP 后，执行流程变为：
1. 通过索引找到匹配的索引项
2. 在索引层面直接应用 WHERE 条件过滤
3. 只对满足条件的行回表读取数据

ICP 可以显著减少回表次数，提高查询性能。

```sql
-- 创建索引
CREATE INDEX idx_orders_status_created ON orders (status, created_at);

-- 查询
SELECT id, created_at FROM orders
WHERE status = 'pending'
  AND created_at > '2024-01-01';

-- 使用 ICP 时：status 和 created_at 都在索引中过滤
-- 不使用 ICP 时：先通过 status 找到记录，再回表过滤 created_at
```

### ICP 的适用条件

ICP 并非在所有情况下都适用，以下条件需要满足：

1. 索引列必须包含 WHERE 条件中的列
2. 条件必须是可下推的类型（如比较运算）
3. 存储引擎支持 ICP（YashanDB 的主要存储引擎通常支持）

### 如何判断是否使用 ICP

在 YashanDB 中，可以通过 EXPLAIN 查看是否使用了 ICP 优化：

```sql
EXPLAIN SELECT id, created_at FROM orders
WHERE status = 'pending'
  AND created_at > '2024-01-01';
```

执行计划中可能显示相关提示，表明优化器正在使用 ICP。

## 复合索引与查询优化器的交互

### 优化器如何选择索引

YashanDB 的查询优化器会基于统计信息评估不同索引的成本，然后选择最优的执行计划。理解优化器的行为有助于设计更高效的索引。

```sql
-- 查看表的统计信息
SELECT
    table_name,
    num_rows,
    blocks,
    last_analyzed
FROM user_tables
WHERE table_name = 'ORDERS';

-- 查看索引的统计信息
SELECT
    index_name,
    blevel,
    leaf_blocks,
    distinct_keys,
    clustering_factor
FROM user_indexes
WHERE table_name = 'ORDERS';
```

### 强制使用特定索引

在某些情况下，可能需要强制优化器使用特定索引：

```sql
-- 使用 HINT 强制使用索引
SELECT /*+ INDEX(orders idx_orders_user_status) */ *
FROM orders
WHERE user_id = 1001 AND status = 'pending';
```

注意：通常不建议强制使用索引，这应该是经过充分测试后的最后手段。

## 复合索引设计实战

### 场景一：电商订单系统

假设订单表有以下常用查询：

```sql
-- 查询1：查询某用户的所有订单
SELECT * FROM orders WHERE user_id = ?;

-- 查询2：查询某用户的待处理订单
SELECT * FROM orders WHERE user_id = ? AND status = 'pending';

-- 查询3：查询某用户的历史订单（按时间倒序）
SELECT * FROM orders
WHERE user_id = ?
ORDER BY created_at DESC;

-- 查询4：查询某用户在某时间段内的订单
SELECT * FROM orders
WHERE user_id = ?
  AND created_at BETWEEN ? AND ?;
```

针对以上查询模式，可以设计复合索引：

```sql
-- 最佳复合索引设计
CREATE INDEX idx_orders_user_created ON orders (user_id, created_at DESC);

-- 解释：
-- 1. user_id 是等值条件，放在最前面
-- 2. created_at 支持排序和时间范围查询
-- 3. status 条件可以通过在查询时添加来覆盖查询2
--    但如果查询2非常高频，可以考虑单独索引或调整设计

-- 如果查询2非常高频，可以添加：
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
```

### 场景二：日志分析系统

```sql
-- 常用查询：按时间范围和日志级别查询
SELECT * FROM logs
WHERE log_time >= ? AND log_time < ?
  AND level IN ('ERROR', 'WARN');

-- 复合索引设计
CREATE INDEX idx_logs_time_level ON logs (log_time, level);
```

此索引支持：
- 时间范围查询（log_time）
- 级别过滤（level）
- 组合条件查询

## 设计复合索引的最佳实践

1. **分析查询模式**：首先分析业务中的高频查询，了解 WHERE、ORDER BY、GROUP BY 列
2. **遵循左前缀规则**：确保常用查询能从索引中受益
3. **等值优先**：将等值条件列放在范围条件列之前
4. **考虑覆盖**：将 SELECT 列也纳入复合索引（覆盖索引）
5. **避免过度索引**：每个表 3-5 个索引通常足够，过多索引影响写入性能

```sql
-- 综合示例：为订单查询设计复合索引
-- 常见查询：
-- SELECT * FROM orders WHERE user_id = ? AND status = ? ORDER BY created_at DESC;
-- SELECT * FROM orders WHERE user_id = ? AND status = ? AND created_at > ?;

CREATE INDEX idx_orders_user_status_created
    ON orders (user_id, status, created_at DESC);
```

此索引同时支持上述两种查询模式：等值过滤 + 排序，以及等值过滤 + 范围查询。

---

### 参考

- [产品文档/概念手册/关系数据结构/模式对象/索引.md](../../../产品文档/概念手册/关系数据结构/模式对象/索引.md)
