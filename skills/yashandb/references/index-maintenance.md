---
title: YashanDB 索引维护
description: 索引重建、碎片处理、未使用索引识别、统计信息更新
tags: yashandb, indexes, maintenance, index-fragmentation, performance-tuning
---

# 索引维护

> **参考文档**：产品文档/概念手册/关系数据结构/模式对象/索引.md

在一个数据库系统中，索引是一个独立对象，是表的一个可选结构。索引包含表的索引列的所有数据（包括NULL）。索引数据是有序的，给表创建合适的索引相当于给表创建了一个目录，可以提高该表关于索引列的访问效率。

索引维护是数据库性能优化的重要环节。合理的索引维护可以保持查询性能，防止因索引碎片化导致的性能下降。本文档介绍 YashanDB 中索引维护的最佳实践。

索引与表一样，随着数据的不断变化，也需要定期进行维护。忽视索引维护可能导致查询性能逐渐下降，最终影响整个应用的响应时间。

## 索引重建时机与指征

### 索引的可用性和可见性

**可用性**：索引可以是可用（usable）的（默认值），也可以是不可用（unusable）的。YashanDB在DML操作中不维护不可用索引，且优化器也不会选择不可用索引执行查询操作。当一个索引从可用状态变更为不可用状态时，YashanDB会把这个索引对应的segment删除，即不可用索引不会占用物理空间。不可用索引或索引分区可以通过rebuild语句调整状态为可用。

**可见性**：索引可以是可见（visible）的（默认值），也可以是不可见（invisible）的。YashanDB在DML操作中依然维护不可见索引，但优化器不会选择不可见索引执行查询操作。

### 需要重建索引的典型场景

1. **索引碎片化严重**：逻辑顺序与物理顺序严重不匹配
2. **索引体积膨胀**：索引占用空间异常增大
3. **查询性能下降**：原本使用索引的查询变慢
4. **大量数据删除后**：表删除大量数据后，索引空间未回收
5. **频繁的数据加载**：批量数据导入或批量更新后
6. **索引从不可用状态恢复**：使用REBUILD将不可用索引重新变为可用

### 如何判断索引是否需要重建

```sql
-- 查看索引统计信息（YashanDB 特定视图）
-- 注意：具体视图名称可能因版本不同而有所差异
SELECT
    index_name,
    blevel,
    leaf_blocks,
    distinct_keys,
    clustering_factor
FROM user_indexes
WHERE table_name = 'ORDERS';

-- 查看索引占用空间
SELECT
    segment_name,
    bytes / 1024 / 1024 AS size_mb
FROM user_segments
WHERE segment_name LIKE 'IDX_%'
ORDER BY bytes DESC;
```

### 重建索引的方法

```sql
-- 方法一：重建单个索引
ALTER INDEX idx_orders_user REBUILD;

-- 方法二：重建单个索引（指定表空间）
ALTER INDEX idx_orders_user REBUILD TABLESPACE users_ts;

-- 方法三：重建表的所有索引
ALTER TABLE orders REBUILD INDEXES;

-- 方法四：在线重建（如果版本支持）
ALTER INDEX idx_orders_user REBUILD ONLINE;
```

### 重建索引的注意事项

- **时间选择**：在业务低峰期进行
- **空间需求**：重建过程中需要额外空间存储临时数据
- **并发影响**：非 ONLINE 重建可能会阻塞写操作
- **进度监控**：大型索引重建可能需要较长时间

```sql
-- 查看索引状态
SELECT
    index_name,
    status,
    tablespace_name
FROM user_indexes
WHERE table_name = 'ORDERS';
```

### 索引重建的自动化

在生产环境中，可以考虑将索引重建纳入定期维护任务：

```sql
-- 创建定期维护任务（根据版本不同，语法可能有差异）
BEGIN
    DBMS_JOB.SUBMIT(
        job       => :jobno,
        what      => 'BEGIN
            FOR rec IN (SELECT index_name FROM user_indexes
                        WHERE table_name = ''ORDERS'') LOOP
                EXECUTE IMMEDIATE ''ALTER INDEX '' || rec.index_name || '' REBUILD'';
            END LOOP;
        END;',
        next_date => SYSDATE + 1,  -- 每天执行一次
        interval  => 'TRUNC(SYSDATE) + 1'
    );
END;
/
```

## 索引碎片处理

### 索引碎片化的原因

1. **大量 INSERT/DELETE**：频繁的数据增删导致索引页面不满
2. **页面分裂**：数据插入导致索引页面分裂，产生碎片
3. **随机更新**：非顺序更新导致索引逻辑结构变化
4. **主键不是自增**：随机主键值会导致索引频繁分裂

### 索引碎片的类型

**物理碎片**：
- 索引页面在物理存储上不连续
- 增加磁盘 I/O 时间

**逻辑碎片**：
- 索引条目在逻辑上不连续
- 影响索引扫描效率

```sql
-- 通过分析 clustering_factor 判断索引逻辑顺序与表数据的匹配程度
SELECT
    index_name,
    clustering_factor,
    num_rows,
    leaf_blocks,
    ROUND(clustering_factor / num_rows, 2) AS cf_ratio
FROM user_indexes
WHERE table_name = 'EMPLOYEES';

-- clustering_factor 越接近 num_rows，说明索引与表数据顺序差异越大
-- clustering_factor 越接近 leaf_blocks，说明索引效率越高
```

### 碎片化程度的判断

```sql
-- 查看索引的深度和叶子节点信息
-- 这些信息可以帮助判断索引效率
SELECT
    index_name,
    blevel AS tree_level,
    leaf_blocks,
    num_rows,
    clustering_factor
FROM user_indexes
WHERE table_name = 'EMPLOYEES';

-- 查看表和索引的统计信息
ANALYZE TABLE employees COMPUTE STATISTICS;
-- 或
EXEC DBMS_STATS.GATHER_TABLE_STATS('USER', 'EMPLOYEES');
```

### 碎片处理方案

#### 方案一：重建索引

```sql
-- 重建索引以消除碎片
ALTER INDEX idx_employees_dept REBUILD;
```

#### 方案二：表重建同时重建索引

```sql
-- 移动表到新的表空间（同时重建索引）
ALTER TABLE employees MOVE TABLESPACE new_ts;

-- 重建索引（表移动后索引会失效）
ALTER INDEX idx_employees_dept REBUILD;
```

#### 方案三：使用 DBMS_STATS 收集统计信息

```sql
-- 收集表和索引的统计信息
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname          => 'USER',
        tabname          => 'EMPLOYEES',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
        degree           => DBMS_STATS.AUTO_DEGREE,
        cascade          => TRUE
    );
END;
/
```

## 未使用索引的识别方法

### 通过查询视图识别

```sql
-- 查看索引使用情况（需要先启用审计或统计收集）
-- 查找从未被使用的索引
SELECT
    i.index_name,
    i.table_name,
    i.tablespace_name
FROM user_indexes i
WHERE i.index_name NOT IN (
    SELECT DISTINCT index_name
    FROM user_ind_columns
    WHERE table_name = i.table_name
)
AND i.index_type = 'NORMAL'
AND i.status = 'VALID';

-- 查找主键索引（通常不使用，但仍需保留）
AND i.index_name NOT LIKE 'SYS%';
```

### 通过监控识别

```sql
-- 启用索引使用统计（如果在系统级别启用）
-- 查看索引访问统计
SELECT
    index_name,
    table_name,
    blevel,
    leaf_blocks,
    num_rows,
    last_analyzed
FROM user_indexes
WHERE table_name = 'ORDERS'
ORDER BY last_analyzed;
```

### 识别冗余索引

```sql
-- 查找可能冗余的索引
-- 如果索引 (a, b) 存在，则索引 (a) 是冗余的
SELECT
    a.index_name AS redundant_index,
    a.column_name AS redundant_column,
    b.index_name AS dominant_index,
    b.column_name AS dominant_column
FROM user_ind_columns a
JOIN user_ind_columns b
    ON a.index_name != b.index_name
    AND a.table_name = b.table_name
WHERE a.column_position = 1
  AND b.column_position = 1
  AND a.column_name = b.column_name;
```

### 删除未使用索引的步骤

1. **确认索引未被使用**：通过监控确认
2. **评估约束需求**：确认不是唯一约束或外键所需的索引
3. **测试删除**：在测试环境验证删除后的影响
4. **谨慎删除**：生产环境删除前备份

### 未使用索引对性能的影响

未使用的索引不仅浪费存储空间，还会影响写入性能：

```sql
-- 查看索引数量过多的表
SELECT
    table_name,
    COUNT(*) AS index_count,
    SUM(bytes) / 1024 / 1024 AS total_index_mb
FROM user_indexes i
JOIN user_segments s ON i.index_name = s.segment_name
WHERE s.segment_type = 'INDEX'
GROUP BY table_name
HAVING COUNT(*) > 5
ORDER BY COUNT(*) DESC;
```

每次 DML 操作都需要更新所有相关索引，索引越多，写入性能越差。

```sql
-- 在测试环境中可以先禁用索引，观察影响
ALTER INDEX idx_orders_status DISABLE;

-- 如果没有问题，再删除
DROP INDEX idx_orders_status;

-- 如果需要恢复，从备份恢复或重建
CREATE INDEX idx_orders_status ON orders (status);
```

## 索引的维护

索引是表的一个可选结构，跟随表的变动而变动：

- 当表插入一行数据，索引也在合适位置插入一行数据（只存储索引列）
- 当表删除一行数据，索引也删除对应行数据
- 当表没有更新索引列时，索引不需要维护
- 当表更新索引列时，为了保持索引的有序性，索引不能像表那样在原位更新，而是先删除老数据构造的索引行然后在合适的位置插入新值构造的索引行

## 索引统计信息更新

### 为什么需要更新统计信息

优化器依赖统计信息来选择最优执行计划。当数据发生大量变化后，旧统计信息可能导致优化器做出错误的执行计划选择。

统计信息包括：
- 表的行数
- 列的唯一值数量（Cardinality）
- 列值的分布情况
- 索引的深度和叶子节点数
- 数据在表中的物理存储顺序

### 何时更新统计信息

1. **大量数据变更后**：超过表数据量 10% 的 DML 操作
2. **查询性能异常**：发现执行计划突变
3. **定期维护**：按计划进行统计信息收集
4. **新索引创建后**：确保优化器了解新索引的存在
5. **系统升级后**：验证优化器行为

### 统计信息更新方法

```sql
-- 方法一：分析单个表
ANALYZE TABLE orders COMPUTE STATISTICS;

-- 方法三：分析表和索引
ANALYZE TABLE orders COMPUTE STATISTICS FOR ALL INDEXES;
```

### 验证统计信息是否过期

```sql
-- 查看表的统计信息
SELECT
    table_name,
    num_rows,
    blocks,
    last_analyzed
FROM user_tables
WHERE table_name = 'ORDERS';

-- 查看索引统计信息
SELECT
    index_name,
    num_rows,
    blevel,
    leaf_blocks,
    clustering_factor,
    last_analyzed
FROM user_indexes
WHERE table_name = 'ORDERS';
```

## 索引与查询性能的关系

### 索引对查询的影响

**正面影响**：
- 快速定位数据，减少全表扫描
- 避免排序操作（如果索引顺序与 ORDER BY 匹配）
- 支持覆盖索引，减少 I/O

**负面影响**：
- 增加存储空间
- 降低写入性能（每次 DML 需要更新索引）
- 优化器可能选择错误的执行计划

### 索引数量的建议

- **常规表**：3-5 个索引通常足够
- **高频写入表**：尽量减少索引
- **高频查询表**：可以适当增加索引

```sql
-- 查看表的索引数量
SELECT
    table_name,
    COUNT(*) AS index_count
FROM user_indexes
WHERE table_name NOT LIKE 'BIN$%'
GROUP BY table_name
ORDER BY index_count DESC;
```

### 索引维护的监控指标

```sql
-- 监控表空间使用情况
SELECT
    tablespace_name,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS size_mb
FROM user_segments
WHERE segment_type = 'INDEX'
GROUP BY tablespace_name;

-- 监控大表上的索引
SELECT
    i.table_name,
    i.index_name,
    i.num_rows,
    s.bytes / 1024 / 1024 AS index_size_mb
FROM user_indexes i
JOIN user_segments s ON i.index_name = s.segment_name
WHERE s.segment_type = 'INDEX'
ORDER BY s.bytes DESC;
```

## 最佳实践建议

### 日常维护

1. **定期收集统计信息**：确保优化器有准确的决策依据
2. **监控慢查询**：识别缺失索引的情况
3. **定期审查索引使用情况**：删除未使用的索引
4. **关注表空间使用**：防止索引空间过度膨胀

### 索引设计原则

1. **按需创建**：只为高频查询创建索引
2. **复合索引优先**：优先考虑复合索引而非多个单列索引
3. **列顺序重要**：遵循等值优先、范围次之、排序最后的原则
4. **避免过度索引**：每个写入频繁的表，索引数量控制在 5 个以内

### 性能调优流程

```sql
-- 步骤1：分析查询性能
EXPLAIN SELECT * FROM orders WHERE user_id = 100 AND status = 'pending';

-- 步骤2：检查执行计划是否使用索引
-- 确认 type、key、rows 等指标

-- 步骤3：检查统计信息
SELECT last_analyzed, num_rows FROM user_tables WHERE table_name = 'ORDERS';

-- 步骤4：如果统计信息过期，收集统计信息
ANALYZE TABLE orders COMPUTE STATISTICS;

-- 步骤5：重新分析查询
EXPLAIN SELECT * FROM orders WHERE user_id = 100 AND status = 'pending';

-- 步骤6：如有必要，创建或调整索引
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
```

### 常见问题处理

**问题一：索引存在但未使用**

```sql
-- 可能原因：
-- 1. 统计信息过期
ANALYZE TABLE orders COMPUTE STATISTICS;

-- 2. 查询写法问题（如使用函数）
-- 避免：WHERE YEAR(created_at) = 2024
-- 改用：WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'

-- 3. 数据量太小，优化器选择全表扫描
-- 可以强制使用索引（不推荐，仅用于测试）
-- SELECT /*+ INDEX(orders idx_orders_user) */ ...
```

**问题二：索引导致写入变慢**

```sql
-- 解决方案：
-- 1. 减少不必要的索引
-- 2. 合并冗余索引
-- 3. 评估索引选择性
```

### 索引维护检查清单

建议定期进行以下检查：

```sql
-- 1. 检查过期统计信息的表
SELECT
    table_name,
    num_rows,
    last_analyzed,
    SYSDATE - last_analyzed AS days_since_analyzed
FROM user_tables
WHERE SYSDATE - last_analyzed > 7  -- 超过7天未分析
ORDER BY SYSDATE - last_analyzed DESC;

-- 2. 检查索引大小异常增长
SELECT
    index_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    last_analyzed
FROM user_segments
WHERE segment_type = 'INDEX'
  AND bytes > 1024 * 1024 * 100  -- 超过100MB
ORDER BY bytes DESC;

-- 3. 检查失效的索引
SELECT
    index_name,
    status,
    table_name
FROM user_indexes
WHERE status != 'VALID';

-- 4. 检查大表的索引数量
SELECT
    table_name,
    COUNT(*) AS index_count
FROM user_indexes i
JOIN user_tables t ON i.table_name = t.table_name
WHERE t.num_rows > 1000000  -- 百万级大表
GROUP BY table_name
HAVING COUNT(*) > 10;
```

## 索引维护自动化建议

为了保持数据库性能稳定，建议实施以下自动化任务：

1. **每日任务**：
   - 收集新增数据的统计信息
   - 监控慢查询日志

2. **每周任务**：
   - 审查未使用的索引
   - 检查索引碎片情况

3. **每月任务**：
   - 全面分析所有表的统计信息
   - 评估索引有效性
   - 清理冗余索引

4. **按需任务**：
   - 大批量数据导入后重建索引
   - 表空间不足时清理无用索引

## 索引维护脚本示例

### 自动化分析脚本

```sql
-- 定期分析所有表的统计信息
DECLARE
    CURSOR tables_to_analyze IS
        SELECT table_name
        FROM user_tables
        WHERE num_rows > 0
        ORDER BY num_rows DESC;

    v_sample_size NUMBER;
BEGIN
    FOR rec IN tables_to_analyze LOOP
        BEGIN
            -- 根据表大小动态选择采样比例
            EXECUTE IMMEDIATE
                'BEGIN DBMS_STATS.GATHER_TABLE_STATS(' ||
                '''USER''', '''' || rec.table_name || ''''', ' ||
                'estimate_percent => 10, cascade => TRUE); END;';
        EXCEPTION
            WHEN OTHERS THEN
                NULL;  -- 跳过失败的表
        END;
    END LOOP;
END;
/
```

### 索引健康检查脚本

```sql
-- 综合索引健康检查
SELECT
    'Index Health Check' AS check_type,
    COUNT(*) AS issue_count
FROM (
    -- 检查1：长期未分析的表
    SELECT table_name
    FROM user_tables
    WHERE SYSDATE - last_analyzed > 30

    UNION ALL

    -- 检查2：失效的索引
    SELECT index_name AS table_name
    FROM user_indexes
    WHERE status != 'VALID'

    UNION ALL

    -- 检查3：索引过多的表
    SELECT table_name
    FROM user_indexes
    GROUP BY table_name
    HAVING COUNT(*) > 10
);
```

### 索引重建建议脚本

```sql
-- 生成索引重建建议
SELECT
    'REBUILD INDEX ' || index_name || ';' AS rebuild_command,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    clustering_factor
FROM user_indexes i
JOIN user_segments s ON i.index_name = s.segment_name
WHERE s.segment_type = 'INDEX'
  AND i.clustering_factor > i.num_rows * 0.5  -- clustering factor 较高
ORDER BY bytes DESC;
```

---

### 参考

- [产品文档/概念手册/关系数据结构/模式对象/索引.md](../../../产品文档/概念手册/关系数据结构/模式对象/索引.md)
