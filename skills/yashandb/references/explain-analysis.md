---
title: YashanDB 执行计划分析
description: EXPLAIN 输出字段解读、执行计划分析、优化策略
tags: yashandb, explain, query-plan, execution-plan, performance
---

# 执行计划分析

执行计划是整个SQL语句执行过程的描述。一个执行计划的优秀与否，很大程度地决定了SQL执行的效率。也正是因为一条SQL语句可以由不同的计划来执行，SQL调优才有了意义。

本文档基于 YashanDB 官方文档编写，详细介绍执行计划的分析方法。

> **参考文档**：产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md

## EXPLAIN 命令基础

在 YashanDB 中，使用 EXPLAIN 命令可以查看查询的执行计划：

```sql
EXPLAIN SELECT * FROM area WHERE area_no = 1;
```

输出格式：

```
PLAN_DESCRIPTION
----------------------------------------------------------------
SQL hash value: 3728302104
Optimizer: ADOPT_C

+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+
| Id | Operation type                 | Name                 | Owner      | Rows     | Cost(%CPU)  | Partition info                 |
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+
|  0 | SELECT STATEMENT               |                      |            |          |             |                                |
|* 1 |  TABLE ACCESS FULL             | AREA                 | SALES      |         1|       13( 0)|                                |
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+

Operation Information (identified by operation id):
---------------------------------------------------

   1 - Predicate : filter("AREA"."AREA_NO" = 1)
```

## 执行计划列说明

### 1. Id

表示执行计划中每个操作的标识符。在简单查询中，所有操作的 Id 都相同；在复杂查询（如子查询或 UNION）中，每个操作有唯一的 Id。

### 2. Operation type（算子类型）

表示 YashanDB 访问表中数据的方式，常见的扫描算子包括：

| 算子类型 | 说明 |
|----------|------|
| TABLE ACCESS FULL | 全表扫描 |
| TABLE ACCESS BY INDEX ROWID | 通过索引 ROWID 访问表 |
| INDEX UNIQUE SCAN | 索引唯一扫描 |
| INDEX FAST FULL SCAN | 索引快速全扫描 |
| INDEX RANGE SCAN | 索引范围扫描 |
| INDEX SKIP SCAN | 索引跳跃扫描 |

### 3. Name

表示操作涉及的索引名或表名。

### 4. Owner

表示对象的所有者。

### 5. Rows

表示优化器估计需要扫描的行数。这个数值越小越好。

### 6. Cost(%CPU)

表示执行代价，括号内为 CPU 代价占比。代价越低越好。

### 7. Partition info

表示分区信息，用于分区表。

### 8. Predicate（谓词）

表示过滤条件，位于 "Operation Information" 部分。例如：
- `filter` - 过滤条件
- `access` - 访问条件

## 常见执行计划示例

### 示例1：全表扫描

```sql
EXPLAIN SELECT * FROM area WHERE area_no = 1;
```

```
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+
| Id | Operation type                 | Name                 | Owner      | Rows     | Cost(%CPU)  | Partition info                 |
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+
|  0 | SELECT STATEMENT               |                      |            |          |             |                                |
|* 1 |  TABLE ACCESS FULL             | AREA                 | SALES      |         1|       13( 0)|                                |
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+

Operation Information (identified by operation id):
---------------------------------------------------

   1 - Predicate : filter("AREA"."AREA_NO" = 1)
```

分析：TABLE ACCESS FULL 表示全表扫描，Cost 为 13。

### 示例2：索引唯一扫描

```sql
EXPLAIN SELECT area_no FROM area WHERE area_no = 1;
```

```
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+
| Id | Operation type                 | Name                 | Owner      | Rows     | Cost(%CPU)  | Partition info                 |
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+
|  0 | SELECT STATEMENT               |                      |            |          |             |                                |
|* 1 |  INDEX FAST FULL SCAN          | SYS_C_33             | SALES      |         1|        6( 0)|                                |
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+

Operation Information (identified by operation id):
---------------------------------------------------

   1 - Predicate : filter("AREA"."AREA_NO" = 1)
```

分析：INDEX FAST FULL SCAN 表示使用索引扫描，Cost 为 6，比全表扫描代价低。

### 示例3：嵌套循环连接

```sql
EXPLAIN SELECT * FROM area a, branches b WHERE a.area_no = b.area_no;
```

```
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+
| Id | Operation type                 | Name                 | Owner      | Rows     | Cost(%CPU)  | Partition info                 |
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+
|  0 | SELECT STATEMENT               |                      |            |          |             |                                |
|  1 |  NESTED LOOPS INNER            |                      |            |    100000|      211( 0)|                                |
|  2 |   TABLE ACCESS FULL            | BRANCHES             | SALES      |    100000|      132( 0)|                                |
|  3 |   TABLE ACCESS BY INDEX ROWID  | AREA                 | SALES      |          |             |                                |
|* 4 |    INDEX UNIQUE SCAN           | SYS_C_33             | SALES      |         1|       13( 0)|                                |
+----+--------------------------------+----------------------+------------+----------+-------------+--------------------------------+

Operation Information (identified by operation id):
---------------------------------------------------

   4 - Predicate : access("A"."AREA_NO" = "B"."AREA_NO")
```

分析：NESTED LOOPS INNER 表示嵌套循环连接，外层表 BRANCHES 全表扫描，内层表 AREA 通过索引唯一扫描。

## 算子效率评估

不同算子的效率不同，执行计划中展示的 Cost 是评估各个算子性能的标准。

### 扫描算子效率对比

| 算子类型 | 效率 | 适用场景 |
|----------|------|----------|
| INDEX UNIQUE SCAN | 最优 | 主键或唯一索引等值查询 |
| INDEX RANGE SCAN | 优 | 范围查询 |
| INDEX FAST FULL SCAN | 优 | 查询列在索引中，不需要回表 |
| TABLE ACCESS BY INDEX ROWID | 一般 | 需要回表获取数据 |
| TABLE ACCESS FULL | 较差 | 大表全表扫描 |

### 注意事项

**常见误解**：一种很流行的错误观点是无论任何扫描场景都应选择索引扫描，这是由于没有深层理解算子的实际执行过程所发生的误解。

**实际情况**：在需要回表时应采用 TABLE FULL SCAN，不需要回表时才采用 INDEX SCAN 效率更高。

### 执行代价模型的局限性

一套能够反应算子真实代价的模型是生成高效计划的关键。但执行代价模型也有可能失效，在一些较为复杂的语句上。执行代价模型可能会表现的不够准确，此时需要人工介入去判断是否存在某些算子的代价评估不准确并视情况进行相应调整，规避不优秀的计划，例如使用 HINT 的方式强行指定算子。

## 执行计划不稳定的原因

有时相同查询的执行计划会发生变化，主要原因包括：

1. **统计信息过期**：表数据大量变化后，统计信息未及时更新
2. **数据分布变化**：数据倾斜导致优化器选择不同的执行计划
3. **系统负载变化**：不同负载下可能选择不同计划
4. **参数设置**：某些会话级参数影响执行计划
5. **版本升级**：数据库升级后优化器行为可能变化

解决措施：

```sql
-- 收集统计信息
ANALYZE TABLE area;

-- 查看统计信息更新时间
SELECT table_name, last_analyzed FROM user_tables;
```

## 使用 HINT 优化执行计划

当执行代价模型表现不准确时，可以使用 HINT 强行指定算子：

```sql
-- 强制使用哈希连接
SELECT /*+ USE_HASH(a b) */ * FROM area a, branches b WHERE a.area_no = b.area_no;

-- 强制使用嵌套循环连接
SELECT /*+ USE_NL(a b) */ * FROM area a, branches b WHERE a.area_no = b.area_no;

-- 强制使用排序合并连接
SELECT /*+ USE_MERGE(a b) */ * FROM area a, branches b WHERE a.area_no = b.area_no;
```

## 执行计划优化步骤

1. **识别慢查询**：通过慢查询日志或监控识别
2. **分析执行计划**：使用 EXPLAIN 查看执行计划
3. **识别瓶颈**：关注 Operation type、Cost、Rows 字段
4. **制定优化方案**：根据瓶颈选择合适策略
5. **验证效果**：重新执行 EXPLAIN 确认优化效果

---

### 参考

- [产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md](../../../产品文档/性能调优/SQL调优/SQL调优入门知识/执行计划.md)
- 产品文档/性能调优/SQL调优/SQL调优原理与规则
