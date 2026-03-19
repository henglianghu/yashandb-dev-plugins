---
title: YashanDB 子分区
description: 复合分区策略、RANGE-LIST、RANGE-HASH 子分区设计与管理
tags: yashandb, subpartitioning, composite-partitioning, range-list, range-hash, partition-management
---

# 子分区

> **参考文档**：产品文档/概念手册/关系数据结构/模式对象/数据分区.md

子分区（Subpartitioning）是复合分区（Composite Partitioning）的实现方式，允许在分区的基础上进一步将每个分区划分为更小的子分区。这种二层结构特别适合需要同时按多个维度进行数据管理和查询优化的场景。

## 复合分区策略概述

复合分区结合了两种分区策略的优势：主分区（First-Level Partition）提供粗粒度的数据管理能力，子分区（Second-Level Partition）提供细粒度的数据分布控制。这种设计特别适合具有复杂访问模式的大型表。

### 复合分区的优势

1. **多维度数据管理**：可以同时按两个维度（如时间和地区）管理数据
2. **更灵活的裁剪**：查询可以同时利用主分区和子分区键进行裁剪
3. **均匀数据分布**：子分区可以避免某些分区过度膨胀
4. **细粒度维护**：可以针对特定子分区进行独立操作

### 常见的复合分区组合

| 主分区类型 | 子分区类型 | 适用场景 |
|------------|------------|----------|
| RANGE | LIST | 按时间分区，按地区/类别列表子分区 |
| RANGE | HASH | 按时间分区，Hash 均匀分布子分区 |
| LIST | LIST | 按主要类别分区，按子类别子分区 |
| LIST | HASH | 按地区分区，用户ID哈希子分区 |

## RANGE-LIST 子分区

RANGE-LIST 是最常用的复合分区类型。主分区通常按时间或数值范围划分，子分区按预定义的类别列表划分。这种设计非常适合同时需要按时间管理和按业务类别分析的数据。

### 基本 RANGE-LIST 分区

```sql
-- 按季度分区，按地区列表子分区
CREATE TABLE sales_records (
    sale_id     NUMBER(20) NOT NULL,
    sale_date   DATE NOT NULL,
    region      VARCHAR2(10) NOT NULL,
    amount      NUMBER(12, 2),
    product_id  NUMBER(10),
    PRIMARY KEY (sale_id, sale_date, region)
)
PARTITION BY RANGE (sale_date)
SUBPARTITION BY LIST (region) (
    PARTITION p_2024_q1 VALUES LESS THAN (TO_DATE('2024-04-01', 'YYYY-MM-DD'))
        (SUBPARTITION p_2024_q1_north VALUES IN ('BJ', 'TJ', 'HE'),
         SUBPARTITION p_2024_q1_south VALUES IN ('GD', 'GX', 'HN'),
         SUBPARTITION p_2024_q1_east VALUES IN ('SH', 'JS', 'ZJ'),
         SUBPARTITION p_2024_q1_other VALUES IN (DEFAULT)),
    PARTITION p_2024_q2 VALUES LESS THAN (TO_DATE('2024-07-01', 'YYYY-MM-DD'))
        (SUBPARTITION p_2024_q2_north VALUES IN ('BJ', 'TJ', 'HE'),
         SUBPARTITION p_2024_q2_south VALUES IN ('GD', 'GX', 'HN'),
         SUBPARTITION p_2024_q2_east VALUES IN ('SH', 'JS', 'ZJ'),
         SUBPARTITION p_2024_q2_other VALUES IN (DEFAULT)),
    PARTITION p_2024_q3 VALUES LESS THAN (TO_DATE('2024-10-01', 'YYYY-MM-DD'))
        (SUBPARTITION p_2024_q3_north VALUES IN ('BJ', 'TJ', 'HE'),
         SUBPARTITION p_2024_q3_south VALUES IN ('GD', 'GX', 'HN'),
         SUBPARTITION p_2024_q3_east VALUES IN ('SH', 'JS', 'ZJ'),
         SUBPARTITION p_2024_q3_other VALUES IN (DEFAULT)),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
        (SUBPARTITION p_future_north VALUES IN ('BJ', 'TJ', 'HE'),
         SUBPARTITION p_future_south VALUES IN ('GD', 'GX', 'HN'),
         SUBPARTITION p_future_east VALUES IN ('SH', 'JS', 'ZJ'),
         SUBPARTITION p_future_other VALUES IN (DEFAULT))
);
```

### 使用 SUBPARTITION TEMPLATE 简化子分区定义

当多个分区需要定义相同的子分区结构时，可以使用 SUBPARTITION TEMPLATE 为所有分区定义统一的子分区模板。

```sql
-- 使用 SUBPARTITION TEMPLATE 定义统一的子分区模板
CREATE TABLE order_details (
    order_id    NUMBER(20) NOT NULL,
    order_date  DATE NOT NULL,
    status      VARCHAR2(20) NOT NULL,
    amount      NUMBER(12, 2),
    PRIMARY KEY (order_id, order_date, status)
)
PARTITION BY RANGE (order_date)
SUBPARTITION BY LIST (status)
SUBPARTITION TEMPLATE (
    SUBPARTITION p_pending VALUES IN ('PENDING', 'PROCESSING'),
    SUBPARTITION p_completed VALUES IN ('COMPLETED', 'SHIPPED'),
    SUBPARTITION p_cancelled VALUES IN ('CANCELLED', 'REFUNDED'),
    SUBPARTITION p_other VALUES IN (DEFAULT)
) (
    PARTITION p_2024 VALUES LESS THAN (TO_DATE('2025-01-01', 'YYYY-MM-DD')),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);
```

## RANGE-HASH 子分区

RANGE-HASH 分区使用范围分区作为主分区，哈希分区作为子分区。哈希子分区可以将数据均匀分布到多个子分区中，避免某些子分区因数据倾斜而过度膨胀。

### 基本 RANGE-HASH 分区

```sql
-- 按月份分区，按用户ID哈希子分区（每个分区指定2个子分区）
CREATE TABLE user_transactions (
    trans_id    NUMBER(20) NOT NULL,
    user_id     NUMBER(20) NOT NULL,
    trans_date  DATE NOT NULL,
    amount      NUMBER(12, 2),
    trans_type  VARCHAR2(20),
    PRIMARY KEY (trans_id, trans_date, user_id)
)
PARTITION BY RANGE (trans_date)
SUBPARTITION BY HASH (user_id) (
    PARTITION p_2024_01 VALUES LESS THAN (TO_DATE('2024-02-01', 'YYYY-MM-DD'))
        (SUBPARTITION sp_1, SUBPARTITION sp_2),
    PARTITION p_2024_02 VALUES LESS THAN (TO_DATE('2024-03-01', 'YYYY-MM-DD'))
        (SUBPARTITION sp_3, SUBPARTITION sp_4),
    PARTITION p_2024_03 VALUES LESS THAN (TO_DATE('2024-04-01', 'YYYY-MM-DD'))
        (SUBPARTITION sp_5, SUBPARTITION sp_6),
    PARTITION p_2024_04 VALUES LESS THAN (TO_DATE('2024-05-01', 'YYYY-MM-DD'))
        (SUBPARTITION sp_7, SUBPARTITION sp_8),
    PARTITION p_2024_05 VALUES LESS THAN (TO_DATE('2024-06-01', 'YYYY-MM-DD'))
        (SUBPARTITION sp_9, SUBPARTITION sp_10),
    PARTITION p_2024_06 VALUES LESS THAN (TO_DATE('2024-07-01', 'YYYY-MM-DD'))
        (SUBPARTITION sp_11, SUBPARTITION sp_12),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
        (SUBPARTITION sp_13, SUBPARTITION sp_14)
);
```

### 使用 SUBPARTITIONS 指定哈希子分区数量

当所有分区需要相同数量的哈希子分区时，可以使用 SUBPARTITIONS 关键字简化定义。

```sql
-- 使用 SUBPARTITIONS 为所有分区创建相同数量的哈希子分区
CREATE TABLE event_logs (
    log_id      NUMBER(20) NOT NULL,
    event_time  TIMESTAMP NOT NULL,
    user_id     NUMBER(20) NOT NULL,
    event_type  VARCHAR2(50),
    message     CLOB,
    PRIMARY KEY (log_id, event_time, user_id)
)
PARTITION BY RANGE (event_time)
SUBPARTITION BY HASH (user_id) SUBPARTITIONS 8
(
    PARTITION p_2024_q1 VALUES LESS THAN (TO_DATE('2024-04-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q2 VALUES LESS THAN (TO_DATE('2024-07-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q3 VALUES LESS THAN (TO_DATE('2024-10-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q4 VALUES LESS THAN (TO_DATE('2025-01-01', 'YYYY-MM-DD')),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);
```

### 使用 SUBPARTITION TEMPLATE 定义哈希子分区

当需要为每个子分区指定名称和表空间时，可以使用 SUBPARTITION TEMPLATE。

```sql
-- 使用 SUBPARTITION TEMPLATE 定义统一的哈希子分区模板
CREATE TABLE event_logs_template (
    log_id      NUMBER(20) NOT NULL,
    event_time  TIMESTAMP NOT NULL,
    user_id     NUMBER(20) NOT NULL,
    event_type  VARCHAR2(50),
    message     CLOB,
    PRIMARY KEY (log_id, event_time, user_id)
)
PARTITION BY RANGE (event_time)
SUBPARTITION BY HASH (user_id)
SUBPARTITION TEMPLATE (
    SUBPARTITION sp_1,
    SUBPARTITION sp_2,
    SUBPARTITION sp_3,
    SUBPARTITION sp_4,
    SUBPARTITION sp_5,
    SUBPARTITION sp_6,
    SUBPARTITION sp_7,
    SUBPARTITION sp_8
) (
    PARTITION p_2024_q1 VALUES LESS THAN (TO_DATE('2024-04-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q2 VALUES LESS THAN (TO_DATE('2024-07-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q3 VALUES LESS THAN (TO_DATE('2024-10-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q4 VALUES LESS THAN (TO_DATE('2025-01-01', 'YYYY-MM-DD')),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);
```

## 子分区设计原则

### 分区键选择

1. **主分区键**：选择数据访问频率最高的维度，通常是时间字段
2. **子分区键**：选择数据分布需要更均匀的维度，或次要查询条件

### 子分区数量规划

- 子分区数量应与磁盘 I/O 并行能力匹配
- 每个子分区应足够大以提高扫描效率，但也不能太大
- 考虑数据增长，预留足够的子分区空间

### 分区命名规范

```sql
-- 建议的命名规范：主分区_子分区
-- 例如：p2024_q1_north 表示2024年第一季度北方区
PARTITION p_2024_q1 VALUES LESS THAN (TO_DATE('2024-04-01', 'YYYY-MM-DD'))
    SUBPARTITION p_2024_q1_north VALUES IN ('BJ', 'TJ', 'HE'),
    SUBPARTITION p_2024_q1_south VALUES IN ('GD', 'GX', 'HN')
```

## 子分区管理

### 查看分区和子分区信息

```sql
-- 查看表的分区信息
SELECT
    partition_name,
    partition_position,
    high_value,
    num_rows
FROM user_tab_partitions
WHERE table_name = 'SALES_RECORDS'
ORDER BY partition_position;

-- 查看表的子分区信息
SELECT
    partition_name,
    subpartition_name,
    high_value,
    num_rows
FROM user_tab_subpartitions
WHERE table_name = 'SALES_RECORDS'
ORDER BY partition_name, subpartition_position;
```

### 添加新分区和子分区

```sql
-- 为 RANGE-LIST 分区表添加新分区
ALTER TABLE sales_records
ADD PARTITION p_2024_q4 VALUES LESS THAN (TO_DATE('2024-11-01', 'YYYY-MM-DD'))
    (SUBPARTITION p_2024_q4_north VALUES IN ('BJ', 'TJ', 'HE'),
     SUBPARTITION p_2024_q4_south VALUES IN ('GD', 'GX', 'HN'),
     SUBPARTITION p_2024_q4_east VALUES IN ('SH', 'JS', 'ZJ'),
     SUBPARTITION p_2024_q4_other VALUES IN (DEFAULT));
```

### 删除子分区

```sql
-- 删除指定子分区（保留该子分区中的数据）
ALTER TABLE sales_records
DROP SUBPARTITION p_2024_q1_other;
```

### 合并子分区

```sql
-- 合并同一主分区下的子分区
ALTER TABLE sales_records
MERGE SUBPARTITIONS p_2024_q1_north, p_2024_q1_south
INTO SUBPARTITION p_2024_q1_merged;
```

### 拆分子分区

```sql
-- 拆分指定的子分区
ALTER TABLE sales_records
SPLIT SUBPARTITION p_2024_q1_other VALUES IN ('BJ', 'TJ')
INTO (
    SUBPARTITION p_2024_q1_bjtj VALUES IN ('BJ', 'TJ'),
    SUBPARTITION p_2024_q1_other_new VALUES IN (DEFAULT)
);
```

### 子分区数据归档示例

```sql
-- 将特定子分区的数据交换到归档表
-- 步骤1：创建与源表结构相同的归档表
CREATE TABLE sales_archive (
    sale_id     NUMBER(20) NOT NULL,
    sale_date   DATE NOT NULL,
    region      VARCHAR2(10) NOT NULL,
    amount      NUMBER(12, 2),
    product_id  NUMBER(10),
    PRIMARY KEY (sale_id, sale_date, region)
);

-- 步骤2：将子分区数据交换到归档表
ALTER TABLE sales_records
EXCHANGE SUBPARTITION p_2024_q1_north
WITH TABLE sales_archive;

-- 步骤3：现在可以对归档表进行独立管理
-- 可以选择备份、清理或保留归档表
```

## 使用场景分析

### 场景一：电商订单系统

```sql
-- 按月分区，按订单状态子分区
-- 适合需要同时按时间和状态管理订单的场景
CREATE TABLE orders (
    order_id    NUMBER(20) NOT NULL,
    order_date  DATE NOT NULL,
    status      VARCHAR2(20) NOT NULL,
    user_id     NUMBER(20) NOT NULL,
    total_amount NUMBER(12, 2),
    PRIMARY KEY (order_id, order_date, status)
)
PARTITION BY RANGE (order_date)
SUBPARTITION BY LIST (status)
SUBPARTITION TEMPLATE (
    SUBPARTITION p_pending VALUES IN ('PENDING', 'PAID'),
    SUBPARTITION p_processing VALUES IN ('PROCESSING', 'SHIPPED'),
    SUBPARTITION p_done VALUES IN ('COMPLETED'),
    SUBPARTITION p_other VALUES IN (DEFAULT)
) (
    PARTITION p_2024_01 VALUES LESS THAN (TO_DATE('2024-02-01', 'YYYY-MM-DD')),
    PARTITION p_2024_02 VALUES LESS THAN (TO_DATE('2024-03-01', 'YYYY-MM-DD')),
    -- 其他月份类似定义
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);
```

**适用分析**：
- 主分区按月，便于历史数据归档和清理
- 子分区按状态，可以快速查询特定状态的订单
- 适合报表统计和订单状态跟踪

### 场景二：用户行为日志

```sql
-- 按日期分区，按用户ID哈希子分区
-- 适合需要均匀分布且经常按用户查询的场景
CREATE TABLE user_behavior_logs (
    log_id      NUMBER(20) NOT NULL,
    log_time    TIMESTAMP NOT NULL,
    user_id     NUMBER(20) NOT NULL,
    action_type VARCHAR2(50),
    page_url    VARCHAR2(500),
    PRIMARY KEY (log_id, log_time, user_id)
)
PARTITION BY RANGE (log_time)
SUBPARTITION BY HASH (user_id) SUBPARTITIONS 16
(
    PARTITION p_2024_01 VALUES LESS THAN (TO_DATE('2024-02-01', 'YYYY-MM-DD')),
    PARTITION p_2024_02 VALUES LESS THAN (TO_DATE('2024-03-01', 'YYYY-MM-DD')),
    -- 其他月份类似
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);
```

**适用分析**：
- 主分区按天/周/月，便于日志保留管理
- 哈希子分区确保用户数据均匀分布
- 适合用户行为分析和个性化推荐

### 场景三：多地区销售数据（LIST-RANGE 复合分区）

```sql
-- 按地区主分区，按时间子分区
-- 适合需要按地区隔离且按时间分析的场景
CREATE TABLE regional_sales (
    sale_id     NUMBER(20) NOT NULL,
    region      VARCHAR2(20) NOT NULL,
    sale_date   DATE NOT NULL,
    amount      NUMBER(12, 2),
    product_id  NUMBER(10),
    PRIMARY KEY (sale_id, region, sale_date)
)
PARTITION BY LIST (region)
SUBPARTITION BY RANGE (sale_date) (
    PARTITION p_north VALUES IN ('BJ', 'TJ', 'HE', 'SX', 'NM')
        (SUBPARTITION p_north_q1 VALUES LESS THAN (TO_DATE('2024-04-01', 'YYYY-MM-DD')),
         SUBPARTITION p_north_q2 VALUES LESS THAN (TO_DATE('2024-07-01', 'YYYY-MM-DD')),
         SUBPARTITION p_north_q3 VALUES LESS THAN (TO_DATE('2024-10-01', 'YYYY-MM-DD')),
         SUBPARTITION p_north_future VALUES LESS THAN (MAXVALUE)),
    PARTITION p_south VALUES IN ('GD', 'GX', 'HN', 'HK')
        (SUBPARTITION p_south_q1 VALUES LESS THAN (TO_DATE('2024-04-01', 'YYYY-MM-DD')),
         SUBPARTITION p_south_q2 VALUES LESS THAN (TO_DATE('2024-07-01', 'YYYY-MM-DD')),
         SUBPARTITION p_south_q3 VALUES LESS THAN (TO_DATE('2024-10-01', 'YYYY-MM-DD')),
         SUBPARTITION p_south_future VALUES LESS THAN (MAXVALUE)),
    PARTITION p_other VALUES IN (DEFAULT)
        (SUBPARTITION p_other_current VALUES LESS THAN (TO_DATE('2024-10-01', 'YYYY-MM-DD')),
         SUBPARTITION p_other_future VALUES LESS THAN (MAXVALUE))
);
```

**适用分析**：
- 主分区按地区隔离，适合数据主权或合规要求
- 子分区按时间，便于各地区数据的独立分析
- 适合地区销售报表和区域管理

---

### 参考

- [产品文档/概念手册/关系数据结构/模式对象/数据分区.md](../../../产品文档/概念手册/关系数据结构/模式对象/数据分区.md)
