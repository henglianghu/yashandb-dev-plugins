---
title: YashanDB 查询优化常见误区
description: 导致索引失效的常见反模式及优化方案
tags: yashandb, query-optimization, pitfalls, anti-patterns, performance
---

# 查询优化常见误区

> **参考文档**：产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md

在日常开发中，很多看似正常的 SQL 语句实际上会导致性能问题。本文将详细介绍 YashanDB 中常见的查询优化误区，帮助开发者识别并避免这些性能陷阱。

## 常见的索引扫描误区

**重要提示**：一种很流行的错误观点是无论任何扫描场景都应选择索引扫描，这是由于没有深层理解算子的实际执行过程所发生的误解。实际上，在需要回表时需采用 TABLE FULL SCAN，不需要回表时才采用 INDEX SCAN 效率更高。

### 典型场景分析

```sql
-- 场景1：查询需要返回所有列（需要回表）
SELECT * FROM area WHERE area_no = 1;
-- 执行计划会选择 TABLE ACCESS FULL，因为需要回表获取所有列

-- 场景2：只查询索引列（不需要回表）
SELECT area_no FROM area WHERE area_no = 1;
-- 执行计划会选择 INDEX FAST FULL SCAN，因为不需要回表，效率更高
```

### 优化原则

- **需要回表时**：采用 TABLE FULL SCAN 效率更高
- **不需要回表时**：采用 INDEX SCAN 效率更高
- 不要盲目追求索引扫描，应根据实际查询需求选择最优算子

## 函数作用于索引列

在 WHERE 条件中对索引列使用函数是最常见的导致索引失效的原因之一。

### 典型反模式

```sql
-- 反模式：对索引列使用函数
SELECT * FROM employees WHERE YEAR(created_at) = 2024;
SELECT * FROM employees WHERE MONTH(created_at) = 1;
SELECT * FROM employees WHERE UPPER(name) = 'JOHN';
SELECT * FROM employees WHERE salary * 1.1 > 5000;
```

这些查询都会导致全表扫描，因为数据库需要对每一行数据应用函数后才能进行比较。

### 优化方案

```sql
-- 使用范围查询代替函数
SELECT * FROM employees
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';

-- 预先计算并存储结果
ALTER TABLE employees ADD COLUMN created_year AS (EXTRACT(YEAR FROM created_at)) STORED;
CREATE INDEX idx_employees_created_year ON employees(created_year);

-- 使用表达式索引（如果数据库支持）
CREATE INDEX idx_employees_upper_name ON employees ((UPPER(name)));
```

### 注意事项

- YashanDB 支持表达式索引，可以利用函数索引优化此类查询
- 考虑在应用层预先计算，减少数据库计算负担
- 如果必须使用函数，考虑是否可以通过改写SQL避免

## 隐式类型转换

当查询条件的数据类型与列数据类型不匹配时，数据库会进行隐式类型转换，这可能导致索引失效。

### 典型反模式

```sql
-- phone 列为 VARCHAR 类型，但查询传入数字
SELECT * FROM employees WHERE phone = 1234567890;

-- 数值列使用字符串比较
SELECT * FROM products WHERE price = '99.99';

-- 日期格式不匹配
SELECT * FROM orders WHERE order_date = '2024-01-15';
```

### 优化方案

```sql
-- 确保数据类型匹配
SELECT * FROM employees WHERE phone = '1234567890';
SELECT * FROM products WHERE price = 99.99;

-- 使用正确的日期格式
SELECT * FROM orders WHERE order_date = DATE '2024-01-15';
```

### 注意事项

- 隐式类型转换不仅可能导致索引失效，还会增加 CPU 开销
- 在应用层做好类型校验，避免传入错误类型的数据
- 使用参数化查询，让数据库缓存执行计划

## 全表扫描的识别与避免

全表扫描是查询性能的最大杀手，需要及时识别并优化。

### 如何识别全表扫描

```sql
EXPLAIN SELECT * FROM employees WHERE salary > 5000;

-- 执行计划显示 type = ALL 表示全表扫描
-- | type   | key    | rows  |
-- |--------|--------|-------|
-- | ALL    | NULL   | 10000 |
```

### 常见导致全表扫描的场景

```sql
-- 1. WHERE 条件没有索引
SELECT * FROM employees WHERE department_name = 'Sales';

-- 2. 使用函数或运算
SELECT * FROM employees WHERE SUBSTR(name, 1, 1) = 'A';

-- 3. 使用 NOT 操作符
SELECT * FROM employees WHERE NOT status = 'active';

-- 4. 使用 OR 连接不同列的条件
SELECT * FROM employees WHERE department_id = 10 OR salary > 5000;
```

### 优化方案

```sql
-- 1. 创建合适的索引
CREATE INDEX idx_employees_dept_name ON employees(department_name);
CREATE INDEX idx_employees_salary ON employees(salary);
CREATE INDEX idx_employees_status ON employees(status);

-- 2. 改写 OR 为 UNION
SELECT * FROM employees WHERE department_id = 10
UNION ALL
SELECT * FROM employees WHERE salary > 5000;

-- 3. 使用 IN 代替 OR
SELECT * FROM employees WHERE department_id IN (10, 20, 30);

-- 4. 使用覆盖索引
CREATE INDEX idx_employees_dept_salary ON employees(department_id, salary);
```

## LIKE 前导通配符

LIKE 查询中使用前导通配符（%）会导致索引失效。

### 典型反模式

```sql
-- 前导通配符无法使用索引
SELECT * FROM employees WHERE name LIKE '%smith';
SELECT * FROM employees WHERE name LIKE '%mith%';
SELECT * FROM products WHERE description LIKE '%cheap%';
```

### 优化方案

```sql
-- 1. 尽量使用后缀通配符
SELECT * FROM employees WHERE name LIKE 'smith%';

-- 2. 存储反转字符串（适用于后缀查询）
ALTER TABLE employees ADD COLUMN name_reversed AS (REVERSE(name)) STORED;
CREATE INDEX idx_employees_name_rev ON employees(name_reversed);

SELECT * FROM employees WHERE name_reversed LIKE CONCAT(REVERSE('smith'), '%');

-- 3. 使用全文索引（适用于大量文本搜索）
CREATE FULLTEXT INDEX idx_employees_name ON employees(name);

SELECT * FROM employees WHERE MATCH(name) AGAINST('smith' IN NATURAL LANGUAGE MODE);

-- 4. 使用专用搜索引擎（如Elasticsearch）
```

## OR 条件导致索引失效

使用 OR 连接多个条件时，如果 OR 连接的列没有合适的组合索引，可能导致全表扫描。

### 典型反模式

```sql
-- OR 导致索引失效
SELECT * FROM employees WHERE department_id = 10 OR salary > 5000;

-- 即使有索引，OR 也可能导致全表扫描
SELECT * FROM employees WHERE department_id = 10 OR employee_id = 100;
```

### 优化方案

```sql
-- 1. 使用 UNION 改写
SELECT * FROM employees WHERE department_id = 10
UNION ALL
SELECT * FROM employees WHERE salary > 5000;

-- 2. 创建组合索引
CREATE INDEX idx_employees_dept_salary ON employees(department_id, salary);

-- 3. 使用 IN 代替 OR
SELECT * FROM employees WHERE department_id IN (10, 20, 30);
```

## 不当使用 SELECT *

SELECT * 会读取所有列数据，即使只需要几列，这会导致以下问题：

### 典型反模式

```sql
-- 不需要所有列但使用 SELECT *
SELECT * FROM employees WHERE department_id = 10;
```

### 问题分析

1. **增加网络传输**：传输更多不必要的数据
2. **无法使用覆盖索引**：必须回表读取数据
3. **增加内存消耗**：结果集更大，消耗更多内存

### 优化方案

```sql
-- 只查询需要的列
SELECT employee_id, name, salary FROM employees WHERE department_id = 10;

-- 使用覆盖索引
CREATE INDEX idx_employees_dept_cover ON employees (department_id, employee_id, name, salary);

-- 验证覆盖索引
EXPLAIN SELECT employee_id, name, salary FROM employees WHERE department_id = 10;
-- Extra 列应显示 "Using index"
```

## 常见反模式与改进方案

### 1. DISTINCT / GROUP BY 缺少索引

```sql
-- 反模式
SELECT DISTINCT department_id FROM employees;
SELECT department_id, COUNT(*) FROM employees GROUP BY department_id;

-- 优化：为排序列创建索引
CREATE INDEX idx_employees_dept ON employees(department_id);
```

### 2. LIMIT 配合 ORDER BY 但无索引

```sql
-- 反模式：需要排序所有数据
SELECT * FROM employees ORDER BY created_at DESC LIMIT 10;

-- 优化：创建索引
CREATE INDEX idx_employees_created ON employees(created_at DESC);
```

### 3. 派生表/子查询性能问题

```sql
-- 反模式：派生表可能被物化
SELECT * FROM (
    SELECT * FROM employees WHERE salary > 5000
) e JOIN departments d ON e.department_id = d.id;

-- 优化：确保派生表有索引支持
CREATE INDEX idx_employees_salary ON employees(salary);
```

### 4. COUNT(*) 误用

```sql
-- 统计非空值（如果 name 可能为 NULL）
SELECT COUNT(name) FROM employees;

-- 统计所有行（包括 NULL）
SELECT COUNT(*) FROM employees;

-- 统计唯一值
SELECT COUNT(DISTINCT department_id) FROM employees;
```

### 5. NOT IN 与 NULL

```sql
-- 反模式：NOT IN 遇到 NULL 结果可能不符合预期
SELECT * FROM employees WHERE department_id NOT IN (1, 2, NULL);

-- 优化：使用 NOT EXISTS
SELECT * FROM employees e
WHERE NOT EXISTS (
    SELECT 1 FROM departments d WHERE d.id = e.department_id
);

-- 或使用 NOT IN 并确保子查询无 NULL
SELECT * FROM employees WHERE department_id NOT IN (
    SELECT COALESCE(id, 0) FROM departments
);
```

## 性能优化检查清单

在实际开发中，可以按照以下清单检查 SQL 性能：

1. [ ] WHERE 条件是否使用了索引列？
2. [ ] 是否对索引列使用了函数或运算？
3. [ ] 数据类型是否匹配？
4. [ ] 是否使用了前导通配符的 LIKE？
5. [ ] SELECT 是否只查询需要的列？
6. [ ] ORDER BY 是否有索引支持？
7. [ ] JOIN 条件是否都有索引？
8. [ ] 是否避免了大量数据的 OFFSET 分页？

---

### 参考

- [产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md](../../../产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md)
