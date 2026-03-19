---
title: YashanDB 查询模式优化
description: 分页查询、JOIN优化、聚合查询、子查询、批量插入等最佳实践
tags: yashandb, query-optimization, pagination, join, aggregation, batch-insert
---

# 查询模式优化

> **参考文档**：产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md

在实际业务开发中，我们经常会遇到各种常见的查询场景。本文将详细介绍 YashanDB 中几种典型查询模式的优化方法，帮助开发者编写更高效的 SQL 语句。

## 分页查询优化

分页查询是最常见的查询场景之一，常见的实现方式有两种：OFFSET 分页和游标分页。

### OFFSET 分页

```sql
SELECT * FROM orders
WHERE status = 'completed'
ORDER BY created_at DESC
LIMIT 10 OFFSET 1000;
```

**问题分析**：OFFSET 分页在偏移量较大时性能较差，因为数据库需要扫描并丢弃前 N 行数据后才能返回结果。当 OFFSET 达到数万甚至更多时，性能会急剧下降。

**优化建议**：
- 避免使用大 OFFSET 值
- 结合 WHERE 条件减少扫描范围
- 考虑使用游标分页代替

### 游标分页（推荐）

游标分页使用上一页的最后一条记录的某个唯一值作为起点，避免扫描已跳过的行：

```sql
-- 第一页
SELECT * FROM orders
WHERE status = 'completed'
ORDER BY created_at DESC, id DESC
LIMIT 10;

-- 下一页（使用上一页最后一条的 created_at 和 id）
SELECT * FROM orders
WHERE status = 'completed'
AND (created_at, id) < (timestamp '2024-01-15 10:30:00', 12345)
ORDER BY created_at DESC, id DESC
LIMIT 10;
```

**复合游标分页**：
```sql
-- 假设上一页最后一条记录是 created_at='2024-01-15 10:30:00', id=12345
SELECT * FROM orders
WHERE status = 'completed'
AND (created_at < '2024-01-15 10:30:00'
     OR (created_at = '2024-01-15 10:30:00' AND id < 12345))
ORDER BY created_at DESC, id DESC
LIMIT 10;
```

**索引优化**：确保分页查询使用的排序列和过滤列上有合适的索引：

```sql
CREATE INDEX idx_orders_status_created_id
ON orders (status, created_at DESC, id DESC);
```

## JOIN 优化模式

JOIN 操作是数据库查询中最消耗资源的操作之一，选择合适的连接方式至关重要。

### 嵌套循环连接（Nested Loop Join）

适用于小表驱动大表，且内层表有索引的场景：

```sql
-- 驱动表（小表）通过索引连接大表
SELECT /*+ ORDERED USE_NL(e d) */ *
FROM departments d
JOIN employees e ON e.dept_id = d.id
WHERE d.name = 'Engineering';
```

**适用场景**：
- 驱动表数据量小
- 连接列上有索引
- 返回结果较少

### 哈希连接（Hash Join）

适用于大表之间的等值连接，尤其当没有合适的索引时：

```sql
SELECT /*+ USE_HASH(e d) */ *
FROM employees e
JOIN departments d ON e.dept_id = d.id
WHERE e.salary > 10000;
```

**工作原理**：
1. 读取较小的表，在内存中构建哈希表
2. 扫描大表，查找匹配的行
3. 适合等值连接

**适用场景**：
- 大表之间的连接
- 没有合适的索引
- 内存足够容纳较小的表

**优化建议**：在哈希连接中，建议将小表放在右边（build 表）以降低建表的成本。

### 排序合并连接（Sort Merge Join）

适用于数据已经排序或可以快速排序的场景：

```sql
SELECT /*+ USE_MERGE(e d) */ *
FROM employees e
JOIN departments d ON e.dept_id = d.id;
```

**适用场景**：
- 连接列已经排序
- 数据量大但可以快速排序
- 非等值连接（如范围连接）

### JOIN 优化最佳实践

1. **选择正确的驱动表**：让小表作为驱动表
2. **确保连接列有索引**：尤其是嵌套循环连接
3. **使用 HINT 引导优化器**：在必要时强制使用特定连接方式
4. **避免过多表连接**：超过 5 个表的连接要考虑拆分

## 聚合查询优化

### GROUP BY 优化

```sql
-- 优化前：使用临时表和文件排序
SELECT department_id, COUNT(*), AVG(salary)
FROM employees
GROUP BY department_id;

-- 优化后：使用索引
CREATE INDEX idx_employees_dept_salary ON employees(department_id, salary);

-- 验证优化效果
EXPLAIN SELECT department_id, COUNT(*), AVG(salary)
FROM employees
GROUP BY department_id;
```

**优化策略**：
1. 确保 GROUP BY 列上有索引
2. 使用覆盖索引避免回表
3. 考虑使用分区表按 GROUP BY 列分区

### ORDER BY 优化

```sql
-- 优化前：使用文件排序
SELECT * FROM orders ORDER BY created_at DESC LIMIT 10;

-- 优化后：使用索引
CREATE INDEX idx_orders_created ON orders(created_at DESC);

-- 复合索引优化 WHERE + ORDER BY
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);

SELECT * FROM orders
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 10;
```

### DISTINCT 优化

```sql
-- 优化前
SELECT DISTINCT department_id FROM employees;

-- 优化后：使用索引
CREATE INDEX idx_employees_dept ON employees(department_id);
```

## 子查询优化

### 常见的子查询反模式

```sql
-- 反模式：子查询结果作为 IN 的参数
SELECT * FROM employees
WHERE department_id IN (
    SELECT department_id FROM departments WHERE name LIKE '%Sales%'
);

-- 优化：使用 JOIN 代替 IN 子查询
SELECT e.* FROM employees e
JOIN departments d ON e.department_id = d.id
WHERE d.name LIKE '%Sales%';
```

### EXISTS vs IN

```sql
--  EXISTS：适合检查是否存在
SELECT * FROM employees e
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.employee_id = e.id
);

-- IN：适合结果集较小的情况
SELECT * FROM employees
WHERE department_id IN (1, 2, 3);
```

### 派生表（FROM 子查询）优化

```sql
-- 为派生表添加索引或物化
SELECT * FROM (
    SELECT employee_id, salary FROM employees WHERE salary > 5000
) e
JOIN departments d ON e.department_id = d.id;
```

## 批量插入优化

### 批量插入

```sql
-- 逐条插入（不推荐）
INSERT INTO employees (name, salary, department_id) VALUES ('John', 5000, 1);
INSERT INTO employees (name, salary, department_id) VALUES ('Mary', 6000, 2);

-- 批量插入（推荐）
INSERT INTO employees (name, salary, department_id) VALUES
('John', 5000, 1),
('Mary', 6000, 2),
('Bob', 5500, 1),
('Alice', 7000, 3);

-- 大量数据插入（百万级）
INSERT /*+ APPEND */ INTO employees (name, salary, department_id)
SELECT name, salary, department_id FROM employees_temp;
```

### 批量更新

```sql
-- 批量更新
UPDATE employees SET salary = salary * 1.1
WHERE department_id = 10;

-- 批量删除
DELETE FROM employees WHERE status = 'inactive';
```

### 批量操作注意事项

1. **控制批量大小**：单次批量操作建议 1000-5000 条
2. **使用事务**：将批量操作放在事务中，保证原子性
3. **关闭索引**：大量插入时可考虑暂时关闭索引
4. **使用 APPEND 提示**：在数据仓库场景使用直接路径加载

## 常见查询模式最佳实践

### 1. 避免 SELECT *

```sql
-- 不推荐
SELECT * FROM employees WHERE department_id = 10;

-- 推荐：只查询需要的列
SELECT employee_id, name, salary FROM employees WHERE department_id = 10;
```

### 2. 使用预编译语句

```sql
-- 预编译语句可以重复使用执行计划，减少解析开销
PREPARE stmt FROM 'SELECT * FROM employees WHERE department_id = ?';
SET @dept_id = 10;
EXECUTE stmt USING @dept_id;
```

### 3. 合理使用 LIMIT

```sql
-- 添加合理的 LIMIT，避免返回过多数据
SELECT employee_id, name FROM employees
WHERE department_id = 10
LIMIT 100;
```

### 4. 避免函数操作索引列

```sql
-- 不推荐：函数导致索引失效
SELECT * FROM employees WHERE YEAR(created_at) = 2024;

-- 推荐：范围查询可以利用索引
SELECT * FROM employees
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';
```

### 5. 使用 UNION ALL 代替 UNION

```sql
-- UNION 会去重，有额外排序开销
SELECT name FROM employees WHERE department_id = 10
UNION
SELECT name FROM contractors WHERE department_id = 10;

-- UNION ALL 不去重，性能更好
SELECT name FROM employees WHERE department_id = 10
UNION ALL
SELECT name FROM contractors WHERE department_id = 10;
```

---

### 参考

- [产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md](../../../产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md)
