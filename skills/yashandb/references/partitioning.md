---
title: YashanDB 分区
description: 分区类型、策略选择、分区裁剪优化及管理操作
tags: yashandb, partitioning, range, list, hash, partition-pruning, performance-tuning
---

# 分区

> **参考文档**：产品文档/概念手册/关系数据结构/模式对象/数据分区.md

分区是将大型表物理拆分为多个较小、更易管理的数据段的技术。YashanDB 支持多种分区策略，每种策略适用于不同的业务场景和数据访问模式。合理使用分区可以显著提升查询性能、简化数据管理并支持高效的数据归档策略。

> **官方说明**："YashanDB可以将大规模数据拆分成更小、更便于管理的对象，即分区。每个分区是一个独立的对象，拥有自己的段（Segment）和段属性，即使某个分区损坏也不影响其他分区。"

> **官方说明**："在YashanDB中，数据有表、索引和LOB三种存储形态，YashanDB对每种形态都提供了相应的分区能力。分区LOB：LOB数据是表数据的一种扩展存储，LOB数据需要随表数据的分区而分区，用户可以决定LOB分区的位置，但LOB分区的类型、分区数量仍由分区表统一管理。"

## 分区键与分区边界

### 分区键

> **官方说明**："分区键是由某一列或若干列组成的特征数据集合，用以决定对应的完整数据存储在哪个数据分区中，是数据分区的一个特征描述。虽分区键本身没有存储意义，但任何分区都有分区键，分区剪枝、分区定位均围绕分区键展开的。SQL引擎通过当前查询数据生成分区键，计算出数据可能落在哪个或哪些分区中。"

### 分区边界

> **官方说明**："分区边界是一个存储结构，用于存储分区边界的值，但只有范围分区（range）、列表分区（list）以及间隔分区（interval）有边界值。"

## 分区概述与优势

### 为什么使用分区

分区技术主要用于解决以下场景的问题：

1. **超大规模数据管理**：当表的数据量达到数百万甚至数十亿行时，全表操作（如备份、恢复、统计分析）会变得非常耗时。分区可以将这些操作限制在特定分区内，大幅减少处理时间。

2. **按时间或类别访问**：许多业务系统主要访问最近的数据，如报表系统查询当月数据、订单系统处理近期订单。分区可以将历史数据与当前数据分离，使近期数据保持高效访问。

3. **数据生命周期管理**：通过分区可以方便地实现数据归档和清理。例如，按月分区的大型日志表，可以简单地通过删除旧分区来清理历史数据，而无需执行耗时的 DELETE 操作。

4. **分区裁剪优化**：查询优化器可以识别查询条件中涉及的分区，只扫描相关分区而忽略其他分区，这种技术称为分区裁剪（Partition Pruning），可显著提升查询性能。

### 分区类型选择指南

| 业务场景 | 推荐分区类型 |
|----------|--------------|
| 按时间顺序访问的数据，如日志、订单、交易记录 | RANGE 分区 |
| 按固定类别或区域访问的数据，如地区、状态、产品线 | LIST 分区 |
| 需要均匀分布数据的场景，如用户ID、流水号 | HASH 分区 |
| 同时需要按两个维度访问的数据 | 复合分区（子分区） |

## RANGE 分区（范围分区）

> **官方说明**："在Range分区中，YashanDB根据分区键键值将数据按照区间分散到不同分区。Range分区是最常见的分区类型，通常与日期一起使用。每个分区的分区边界为当前分区的上限值（high value），分区键值属于[上一个分区的high value,当前分区high value]区间的数据属于当前分区。支持多列分区键，支持指定MAX VALUE。"

RANGE 分区是最常用的分区类型，根据分区键值的范围将数据分配到不同的分区。通常用于按时间维度组织的表，如日志表、交易记录表、订单表等。

### 按数值范围分区

```sql
-- 按用户ID范围分区，适合用户数据量巨大的场景
CREATE TABLE users (
    user_id    NUMBER(20) NOT NULL,
    username   VARCHAR2(100),
    email      VARCHAR2(200),
    created_at DATE,
    PRIMARY KEY (user_id)
)
PARTITION BY RANGE (user_id) (
    PARTITION p_users_1m   VALUES LESS THAN (1000000),
    PARTITION p_users_2m   VALUES LESS THAN (2000000),
    PARTITION p_users_3m   VALUES LESS THAN (3000000),
    PARTITION p_users_max  VALUES LESS THAN (MAXVALUE)
);
```

### 按日期范围分区

```sql
-- 按订单日期分区，按季度划分
CREATE TABLE orders (
    order_id     NUMBER(20) NOT NULL,
    user_id      NUMBER(20) NOT NULL,
    order_date   DATE NOT NULL,
    total_amount NUMBER(12, 2),
    status       VARCHAR2(20),
    PRIMARY KEY (order_id, order_date)
)
PARTITION BY RANGE (order_date) (
    PARTITION p_2024_q1 VALUES LESS THAN (TO_DATE('2024-04-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q2 VALUES LESS THAN (TO_DATE('2024-07-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q3 VALUES LESS THAN (TO_DATE('2024-10-01', 'YYYY-MM-DD')),
    PARTITION p_2024_q4 VALUES LESS THAN (TO_DATE('2025-01-01', 'YYYY-MM-DD')),
    PARTITION p_future  VALUES LESS THAN (MAXVALUE)
);
```

### 使用 RANGE COLUMNS 避免函数包装

```sql
-- RANGE COLUMNS 直接比较日期值，避免使用函数
CREATE TABLE event_logs (
    log_id      NUMBER(20) NOT NULL,
    event_time  TIMESTAMP NOT NULL,
    event_type  VARCHAR2(50),
    message     CLOB,
    PRIMARY KEY (log_id)
)
PARTITION BY RANGE COLUMNS (event_time) (
    PARTITION p_2025_01 VALUES LESS THAN ('2025-02-01'),
    PARTITION p_2025_02 VALUES LESS THAN ('2025-03-01'),
    PARTITION p_2025_03 VALUES LESS THAN ('2025-04-01'),
    PARTITION p_future   VALUES LESS THAN (MAXVALUE)
);
```

## LIST 分区（列表分区）

> **官方说明**："在List分区中，YashanDB根据定义的一些具体键值的列表作为每个分区的分区依据。根据分区键键值将数据按照枚举分散到不同分区。每个分区的分区边界即是当前分区可以存储的分区键键值，只有分区键键值在当前分区的数据属于当前分区。支持多列分区键，支持指定DEFAULT分区，不属于其他分区的数据都属于DEFAULT分区。"

LIST 分区根据预定义的值列表来分配数据，适合具有有限离散值集合的列，如地区编码、业务类型、状态字段等。

### 基本 LIST 分区

```sql
-- 按地区列表分区
CREATE TABLE sales (
    sale_id     NUMBER(20) NOT NULL,
    sale_date   DATE NOT NULL,
    region      VARCHAR2(10) NOT NULL,
    amount      NUMBER(12, 2),
    product_id  NUMBER(10),
    PRIMARY KEY (sale_id)
)
PARTITION BY LIST (region) (
    PARTITION p_north VALUES IN ('BJ', 'TJ', 'HE', 'SX', 'NM'),
    PARTITION p_south VALUES IN ('GD', 'GX', 'HN', 'HK', 'MO'),
    PARTITION p_east  VALUES IN ('SH', 'JS', 'ZJ', 'FJ', 'TW'),
    PARTITION p_west  VALUES IN ('SC', 'YN', 'GZ', 'XZ', 'QH'),
    PARTITION p_other VALUES IN (DEFAULT)
);
```

### LIST COLUMNS 分区

```sql
-- 使用多列 LIST 分区
CREATE TABLE products (
    product_id   NUMBER(10) NOT NULL,
    category     VARCHAR2(20) NOT NULL,
    sub_category VARCHAR2(20) NOT NULL,
    price        NUMBER(10, 2),
    stock        NUMBER(10),
    PRIMARY KEY (product_id)
)
PARTITION BY LIST COLUMNS (category, sub_category) (
    PARTITION p_electronics VALUES IN (
        ('electronics', 'phone'),
        ('electronics', 'tablet'),
        ('electronics', 'laptop')
    ),
    PARTITION p_clothing VALUES IN (
        ('clothing', 'shirt'),
        ('clothing', 'pants'),
        ('clothing', 'dress')
    ),
    PARTITION p_default VALUES IN (DEFAULT)
);
```

## HASH 分区（哈希分区）

> **官方说明**："在Hash分区中，YashanDB基于用户所指定的哈希算法，计算得到分区键对应的hash值，并根据hash值将行映射到相应分区中（即由应用于行的内部哈希函数决定每个行的目标分区）。使用线性哈希算法能够尽可能地确保每个分区中所包含的行数大致相同。根据分区键Hash值，将数据分散到不同分区。建表可以指定分区数。"

HASH 分区使用哈希函数将数据均匀分布到指定数量的分区中。当没有明显的分区键可以按范围或列表划分时，HASH 分区是很好的选择。它可以确保数据均匀分布，但无法利用分区裁剪进行范围查询优化。

### 基本 HASH 分区

```sql
-- 按用户ID哈希分区，将数据均匀分布到8个分区
CREATE TABLE user_sessions (
    session_id  NUMBER(20) NOT NULL,
    user_id     NUMBER(20) NOT NULL,
    login_time  TIMESTAMP NOT NULL,
    ip_address  VARCHAR2(50),
    PRIMARY KEY (session_id)
)
PARTITION BY HASH (user_id) PARTITIONS 8;
```

### 指定分区名称的 HASH 分区

```sql
-- 为每个分区指定名称
CREATE TABLE transactions (
    trans_id    NUMBER(20) NOT NULL,
    user_id     NUMBER(20) NOT NULL,
    trans_time  TIMESTAMP NOT NULL,
    amount      NUMBER(12, 2),
    trans_type  VARCHAR2(20),
    PRIMARY KEY (trans_id)
)
PARTITION BY HASH (trans_time) (
    PARTITION p_2025_01,
    PARTITION p_2025_02,
    PARTITION p_2025_03,
    PARTITION p_2025_04,
    PARTITION p_2025_05,
    PARTITION p_2025_06,
    PARTITION p_2025_07,
    PARTITION p_2025_08,
    PARTITION p_2025_09,
    PARTITION p_2025_10,
    PARTITION p_2025_11,
    PARTITION p_2025_12
);
```

## INTERVAL 分区（间隔分区）

> **官方说明**："Interval分区是一种特殊的Range分区，建表时无需指定所有的数据分区，只需指定扩展分区规则（interval值），在后续业务运行过程中自动扩展分区。"

### INTERVAL 分区特点

- 分区键只允许单列，且数据类型只能是数值类型或日期类型
- 当插入数据的分区键值不满足当前所有分区的范围时，Interval分区表可以根据指定的interval值自动新建一个分区
- 建表时同步创建的分区仍然为Range分区，在业务使用过程中扩展创建的分区才称为Interval分区
- Interval分区不能指定MAX VALUE

### INTERVAL 分区示例

```sql
-- 按月创建 Interval 分区，自动按月创建新分区
CREATE TABLE sales (
    sale_id     NUMBER(20) NOT NULL,
    sale_date   DATE NOT NULL,
    amount      NUMBER(12, 2),
    product_id  NUMBER(10),
    PRIMARY KEY (sale_id, sale_date)
)
PARTITION BY RANGE (sale_date)
INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(
    PARTITION p_init VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD'))
);
```

```sql
-- 按天创建 Interval 分区
CREATE TABLE event_logs (
    log_id      NUMBER(20) NOT NULL,
    event_time  TIMESTAMP NOT NULL,
    event_type  VARCHAR2(50),
    message     CLOB,
    PRIMARY KEY (log_id)
)
PARTITION BY RANGE (event_time)
INTERVAL (NUMTODSINTERVAL(1, 'DAY'))
(
    PARTITION p_init VALUES LESS THAN (TO_TIMESTAMP('2024-01-01', 'YYYY-MM-DD'))
);
```

## 分区裁剪（Partition Pruning）优化

分区裁剪是分区最重要的性能优化特性。优化器会自动分析查询条件，消除不相关的分区扫描，只扫描包含可能匹配数据的分区。

### 启用分区裁剪的条件

分区裁剪在以下情况下最为有效：

1. **等值查询**：WHERE partition_key = '某值'（适用于 HASH/LIST 分区）
2. **范围查询**：WHERE partition_key BETWEEN a AND b（适用于 RANGE 分区）
3. **IN 列表查询**：WHERE partition_key IN (值1, 值2, ...)（适用于 LIST 分区）

### 分区裁剪示例

```sql
-- 查询2024年第二季度订单
-- 优化器只会扫描 p_2024_q2 分区
SELECT * FROM orders
WHERE order_date >= TO_DATE('2024-04-01', 'YYYY-MM-DD')
  AND order_date < TO_DATE('2024-07-01', 'YYYY-MM-DD');

-- 查询北京和天津地区的销售记录
-- 优化器只会扫描 p_north 分区
SELECT * FROM sales WHERE region IN ('BJ', 'TJ');

-- 查询特定用户的所有订单
-- 优化器会计算哈希值，精确定位到某个分区
SELECT * FROM orders WHERE user_id = 1234567;
```

### 注意事项

- 分区裁剪依赖于查询条件直接使用分区键
- 如果在分区键上使用函数，将禁用分区裁剪
- 避免在 WHERE 子句中对分区键进行隐式类型转换

```sql
-- 错误的写法（无法使用分区裁剪）
SELECT * FROM orders WHERE TO_CHAR(order_date, 'YYYY-MM') = '2024-04';

-- 正确的写法（可以使用分区裁剪）
SELECT * FROM orders WHERE order_date >= '2024-04-01' AND order_date < '2024-05-01';
```

## 分区管理操作

### 添加新分区

```sql
-- 为包含 MAXVALUE 的分区添加新分区
ALTER TABLE orders
ADD PARTITION p_2025_q1 VALUES LESS THAN (TO_DATE('2025-04-01', 'YYYY-MM-DD'));

-- 重新组织分区以添加新分区
ALTER TABLE orders
REORGANIZE PARTITION p_future INTO (
    PARTITION p_2025_q1 VALUES LESS THAN (TO_DATE('2025-04-01', 'YYYY-MM-DD')),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);
```

### 删除历史分区

```sql
-- 删除指定分区（快速删除大量数据）
ALTER TABLE orders DROP PARTITION p_2024_q1;

-- 删除分区并合并数据到其他分区
ALTER TABLE orders
REORGANIZE PARTITION p_2024_q1, p_2024_q2 INTO (
    PARTITION p_2024_h1 VALUES LESS THAN (TO_DATE('2024-07-01', 'YYYY-MM-DD'))
);
```

### 拆分分区

```sql
-- 将大分区拆分为两个小分区
ALTER TABLE orders
SPLIT PARTITION p_future AT (TO_DATE('2025-07-01', 'YYYY-MM-DD'))
INTO (
    PARTITION p_2025_q2,
    PARTITION p_future
);
```

### 合并分区

```sql
-- 将多个相邻分区合并为一个
ALTER TABLE orders
MERGE PARTITIONS p_2025_q1, p_2025_q2 INTO PARTITION p_2025_h1;
```

### 分区重命名

```sql
ALTER TABLE orders RENAME PARTITION p_future TO p_2025_future;
```

## 分区索引设计

> **官方说明**："与分区表类似，索引也可以使用分区技术。YashanDB根据索引采用的分区策略与表采用的分区策略一致与否，将分区索引分为本地分区索引和全局索引。"

### 分区索引类型

1. **本地分区索引（Local Index）**

> **官方说明**："分区策略与表一致的索引称为本地分区索引，本地分区索引拥有与表分区相同的分区数目和分区边界，每个索引分区仅与底层表的一个分区相关联。在本地分区索引中，YashanDB可以自动同步索引分区与其关联的表分区。"

2. **全局索引（Global Index）**

> **官方说明**："全局索引的分区策略与表不同，当表为分区表时，全局索引采用与表不同的分区策略进行分区或直接不分区。在全局索引中，索引的段可能指向任意表分区或全部表分区。"

### 分区索引示例

```sql
-- 创建本地分区索引
CREATE INDEX idx_orders_date ON orders (order_date) LOCAL;

-- 创建全局索引
CREATE INDEX idx_orders_user ON orders (user_id) GLOBAL;

-- 创建全局分区索引
CREATE INDEX idx_orders_status ON orders (status) GLOBAL
PARTITION BY RANGE (status) (
    PARTITION p_pending VALUES LESS THAN ('COMPLETED'),
    PARTITION p_completed VALUES LESS THAN (MAXVALUE)
);
```

### 索引维护注意事项

- 分区操作（DROP、MERGE、SPLIT）会导致全局索引失效，需要重建
- 本地索引会自动维护，但会增加存储开销
- 建议在频繁查询的列上创建本地索引

## 分区表与普通表性能对比

### 查询性能对比

分区表在以下场景中性能优势明显：

1. **范围查询**：查询特定时间范围的数据时，只扫描相关分区
2. **分区裁剪**：优化器自动排除不相关的分区
3. **并行查询**：不同分区可以并行扫描

### 数据管理效率对比

| 操作 | 普通表 | 分区表 |
|------|--------|--------|
| 删除历史数据 | DELETE（慢、产生日志） | DROP PARTITION（快、几乎无日志） |
| 备份恢复 | 全表备份 | 可选择性备份特定分区 |
| 维护操作 | 全表操作 | 只影响相关分区 |
| 统计分析 | 全表扫描 | 可分区并行处理 |

### 适用场景总结

分区适用于：
- 数据量超过千万级的大表
- 有明确的数据生命周期管理需求
- 查询经常按特定维度过滤
- 需要高效归档和清理历史数据

分区不适用于：
- 小表（分区开销大于收益）
- 查询不涉及分区键的过滤
- 需要外键约束的场景

---

### 参考

- [产品文档/概念手册/关系数据结构/模式对象/数据分区.md](../../../产品文档/概念手册/关系数据结构/模式对象/数据分区.md)
