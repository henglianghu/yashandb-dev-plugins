---
title: YashanDB 物化视图
description: 物化视图创建、刷新方式、查询重写、刷新策略
tags: yashandb, materialized-view, query-rewrite, complete-refresh
---

# 物化视图

> **参考文档**：产品文档/开发手册/SQL参考手册/SQL语句/CREATE MATERIALIZED VIEW.md

物化视图是一种特殊的表，它存储查询结果而非查询定义。物化视图能够显著提升复杂查询的性能，特别适用于数据仓库、报表生成和汇总数据场景。

物化视图只能基于单机部署或共享集群/分布式集群部署中的 HEAP 表创建，存算一体分布式集群部署中无物化视图相关功能。

## 物化视图创建语法

```ebnf
= CREATE MATERIALIZED VIEW [SCHEMA "."] materialized_view_name
["("(column_name {"," column_name})")"]
[TABLESPACE tablespace_name]
[BUILD (IMMEDIATE | DEFERRED)]
[create_mv_refresh_clause]
[query_rewrite_clause]
AS subquery.
```

### create_mv_refresh_clause

```ebnf
= REFRESH ([COMPLETE | FORCE]
| [ON DEMAND | ON COMMIT]
| [((START WITH date) | NEXT date)]){" "([COMPLETE | FORCE]
| [ON DEMAND | ON COMMIT]
| [((START WITH date) | NEXT date)])}
| (NEVER REFRESH).
```

### query_rewrite_clause

```ebnf
= (ENABLE | DISABLE) QUERY REWRITE.
```

## 物化视图创建

### 基本语法

```sql
-- 创建简单的物化视图
CREATE MATERIALIZED VIEW mv_dept_salary AS
SELECT d.department_name, COUNT(e.employee_id) AS emp_count, AVG(e.salary) AS avg_salary
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_name;
```

### 带表空间指定

```sql
-- 指定物化视图存储的表空间
CREATE MATERIALIZED VIEW mv1 TABLESPACE USERS AS SELECT * FROM area;
```

### BUILD IMMEDIATE | DEFERRED

- **BUILD IMMEDIATE**：创建时立即填充数据（默认）
- **BUILD DEFERRED**：创建时不填充数据，首次刷新时填充

```sql
-- BUILD IMMEDIATE：创建时刷新数据
CREATE MATERIALIZED VIEW mv2 BUILD IMMEDIATE AS SELECT * FROM area;
```

### 带列字段别名

```sql
-- 指定物化视图列字段别名
CREATE MATERIALIZED VIEW mv_subquery(mya,myb) AS SELECT b.branch_name, a.area_name
FROM branches b, area a
WHERE a.area_no=b.area_no AND b.branch_no LIKE '01%';

-- 列字段数量不匹配时返回错误
CREATE MATERIALIZED VIEW mv_colmismatch(c1,c2,c3) AS SELECT area_no,area_name FROM area;
-- YAS-04304 the count of column is mismatched
```

## 刷新方式

> **注意**：YashanDB 目前不论指定 COMPLETE 或 FORCE，均以全量刷新生效。

### COMPLETE 完全刷新

完全刷新会删除物化视图中的所有数据并重新执行查询：

```sql
-- 创建完全刷新的物化视图
CREATE MATERIALIZED VIEW mv_annual_summary
REFRESH COMPLETE
AS
SELECT EXTRACT(YEAR FROM hire_date) AS hire_year,
       COUNT(*) AS headcount
FROM employees
GROUP BY EXTRACT(YEAR FROM hire_date);
```

### FORCE 刷新

自动选择刷新方式（目前等价于完全刷新）：

```sql
-- 创建自动刷新的物化视图
CREATE MATERIALIZED VIEW mv_sales_summary
REFRESH FORCE
AS
SELECT region, SUM(amount) AS total
FROM sales
GROUP BY region;
```

### ON DEMAND | ON COMMIT

- **ON DEMAND**：手动刷新，即通过 DBMS_MVIEW 高级包刷新（默认）
- **ON COMMIT**：事务提交时自动刷新

```sql
-- ON DEMAND：按需刷新（默认）
CREATE MATERIALIZED VIEW mv_refresh(mya,myb) BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
NEXT SYSDATE + 10/(24*60)
AS SELECT area_no,area_name FROM area;

-- ON COMMIT：事务提交时刷新
CREATE MATERIALIZED VIEW mv_daily_stats
REFRESH ON COMMIT
ENABLE QUERY REWRITE AS
SELECT department_id, COUNT(*) AS emp_count
FROM employees
GROUP BY department_id;
```

**注意**：当物化视图的基表包含 DBLINK 远端表时，不支持配置刷新模式为 ON COMMIT。

### 定时刷新 START WITH...NEXT

- **START WITH date**：指定第一次刷新时间
- **NEXT date**：指定刷新时间间隔

下一次刷新时间计算后必须是未来某个时间。

```sql
-- 每天凌晨 2 点刷新
CREATE MATERIALIZED VIEW mv_hourly_stats
START WITH SYSDATE NEXT TRUNC(SYSDATE) + 2/24
REFRESH FORCE AS
SELECT TRUNC(created_at, 'HH') AS hour, COUNT(*) AS cnt
FROM logs
GROUP BY TRUNC(created_at, 'HH');
```

### NEVER REFRESH

指定不刷新，保护物化视图不被任何自动刷新、高级包机制刷新：

```sql
-- 创建永不刷新的物化视图
CREATE MATERIALIZED VIEW mv_static_data
NEVER REFRESH AS
SELECT * FROM static_table;
```

## 查询重写（Query Rewrite）

查询重写是物化视图最重要的优化特性。当用户查询基表时，数据库自动将查询重写为使用物化视图，避免重复计算。

### 启用查询重写

```sql
-- 创建启用查询重写的物化视图
CREATE MATERIALIZED VIEW mv_product_sales
ENABLE QUERY REWRITE
AS
SELECT p.product_name, SUM(s.quantity) AS total_qty, SUM(s.amount) AS total_amt
FROM products p
JOIN sales s ON p.product_id = s.product_id
GROUP BY p.product_name;
```

### 查询重写示例

```sql
-- 用户查询（会自动使用物化视图）
SELECT product_name, SUM(quantity) AS total_qty
FROM products p
JOIN sales s ON p.product_id = s.product_id
GROUP BY product_name;

-- 数据库自动重写为：
SELECT product_name, total_qty
FROM mv_product_sales;
```

### 查询重写限制

- 物化视图不允许包含可变的内置函数（例如时间相关函数）、自定义函数和自定义高级包等
- 物化视图不允许包含表函数
- 物化视图不允许包含伪列
- 物化视图的基表不允许为 dblink 远端表
- 当物化视图基于的表定义修改，导致物化视图失效，此时该物化视图不可进行查询重写。表定义修改包括：
  - 选中的基表列字段数据类型更改
  - 选中的基表列字段删除
  - 选中的基表列字段名称更改

可通过查询 `QUERY_REWRITE_ENABLED` 参数查看当前物化视图查询重写功能的具体情况。

## 刷新策略选择

### ON COMMIT 提交时刷新

适用于数据变更频繁但查询也要求最新数据的场景：

```sql
CREATE MATERIALIZED VIEW mv_daily_stats
REFRESH ON COMMIT
ENABLE QUERY REWRITE AS
SELECT department_id, COUNT(*) AS emp_count
FROM employees
GROUP BY department_id;
```

**注意**：ON COMMIT 会增加事务提交的开销，不适合大事务量场景。

### ON DEMAND 按需刷新

适用于数据更新频率低、查询时间要求不高的场景：

```sql
CREATE MATERIALIZED VIEW mv_monthly_sales
REFRESH ON DEMAND AS
SELECT region, SUM(amount) AS total
FROM sales
GROUP BY region;
```

手动刷新使用 DBMS_MVIEW 高级包：

```sql
-- 刷新单个物化视图
BEGIN
    DBMS_MVIEW.REFRESH('mv_monthly_sales');
END;
/

-- 刷新多个物化视图
BEGIN
    DBMS_MVIEW.REFRESH_LIST('mv_monthly_sales', 'mv_weekly_summary');
END;
/
```

## 管理与维护

### 查看物化视图信息

```sql
-- 查看物化视图列表
SELECT mview_name, refresh_mode, refresh_method, build_mode, fast_refreshable
FROM USER_MVIEWS;

-- 查看物化视图定义
SELECT text FROM USER_MVIEWS WHERE mview_name = 'MV_EMP_DEPT';
```

### 刷新物化视图

```sql
-- 刷新单个物化视图
EXEC DBMS_MVIEW.REFRESH('mv_emp_dept');

-- 刷新所有物化视图
EXEC DBMS_MVIEW.REFRESH_ALL_MVIEWS;

-- 强制刷新（COMPLETE 方式）
EXEC DBMS_MVIEW.REFRESH('mv_emp_dept', 'C');
```

### 重建物化视图

```sql
-- 完全重建筑物化视图
ALTER MATERIALIZED VIEW mv_emp_dept COMPILE;

-- 改变刷新方式
ALTER MATERIALIZED VIEW mv_emp_dept REFRESH COMPLETE;
```

### 删除物化视图

```sql
-- 删除物化视图
DROP MATERIALIZED VIEW mv_emp_dept;
```

## 性能最佳实践

### 何时使用物化视图

- 复杂的多表连接查询
- 聚合查询（SUM、AVG、COUNT 等）
- 频繁执行的相同查询
- 数据仓库的汇总表

### 注意事项

1. **空间开销**：物化视图会占用额外的存储空间
2. **刷新开销**：定期刷新需要计算资源
3. **一致性**：确保刷新策略满足数据一致性要求
4. **维护**：定期检查物化视图状态，及时刷新失效的视图

### 监控物化视图使用

```sql
-- 查看物化视图刷新历史
SELECT mview_name, refresh_id, refresh_method, start_time, end_time
FROM USER_MVIEW_REFRESH_TIMES;

-- 查看查询是否使用了物化视图
EXPLAIN PLAN FOR <查询语句>;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

---

### 参考

- [产品文档/开发手册/SQL参考手册/SQL语句/CREATE MATERIALIZED VIEW.md](../../../产品文档/开发手册/SQL参考手册/SQL语句/CREATE MATERIALIZED VIEW.md)
