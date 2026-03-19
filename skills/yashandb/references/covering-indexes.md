---
title: YashanDB 索引扫描与查询优化
description: 索引扫描方式、避免回表查询、查询优化
tags: yashandb, indexes, index-scan, query-optimization
---

# 索引扫描与查询优化

> **参考文档**：产品文档/概念手册/关系数据结构/模式对象/索引.md

在YashanDB中，索引扫描是优化查询性能的重要手段。当查询所需的数据可以直接从索引中获取时，可以避免回表操作，从而显著提升查询效率。

## 索引扫描概述

根据官方文档的描述，当采用索引列作为查询的过滤条件时，YashanDB可以通过索引来加速查找。如果待查询的数据本身就是索引列，则只需在索引数据块中查询即可快速获取数据。

YashanDB支持多种索引扫描方式，每种方式适用于不同的查询场景。

### 索引扫描方式

YashanDB支持以下索引扫描方式：

- **索引全扫描（Index Full Scan）**：当一个查询需要扫描一个表的所有数据，同时需要使用索引列的前导列排序时执行
- **索引快速全扫描（Index Fast Full Scan）**：扫描结果不需要有序时执行，适用于count(*)、sum()等与顺序无关的扫描
- **索引范围扫描（Index Range Scan）**：当索引的前导列参与查询并且返回结果可能不止一条时执行
- **索引唯一扫描（Index Unique Scan）**：当过滤条件使用相等运算符，并且包含了唯一索引的所有列时执行
- **索引跳跃扫描（Index Skip Scan）**：当索引的前导列基数非常小，且查询条件在索引前导列后面的索引列上时执行

### 避免回表查询

在YashanDB中，索引的结构特点决定了查询的性能表现。索引中的行与表一一对应，用于存储索引列的值以及对应表中的RowId。索引严格按照索引列的值（值相同时按照RowId）有序存储。

当查询的数据本身就在索引列中时，可以实现"避免回表"的效果：

```sql
-- 假设表idxtest上建有a列的索引
-- 查询只需要索引列的数据，无需回表
SELECT a FROM idxtest ORDER BY a;
```

上述查询会执行索引全扫描，利用索引的有序性直接返回结果，无需访问数据表。

## 避免回表的索引设计

### 设计原则

要实现查询无需回表，需要满足以下条件：

1. **查询列在索引中**：SELECT子句中需要返回的列必须包含在索引定义中
2. **WHERE条件列在索引中**：查询的过滤条件必须使用索引列
3. **ORDER BY列在索引中**（如适用）：排序所需的列也应在索引中

```sql
-- 表结构
CREATE TABLE products (
    id BIGINT PRIMARY KEY,
    category_id BIGINT,
    name VARCHAR(200),
    price NUMBER(10,2),
    description VARCHAR(1000),
    created_at TIMESTAMP
);

-- 设计索引：(category_id, price, name)
-- 索引列顺序：过滤列 -> 排序列 -> 查询列
CREATE INDEX idx_products_cat_price_name ON products (category_id, price, name);

-- 可以实现索引扫描：WHERE、SELECT、ORDER BY的列都在索引中
SELECT name, price
FROM products
WHERE category_id = 10
ORDER BY price;
```

### 复合索引列顺序设计

复合索引的列顺序设计至关重要，应遵循以下原则：

1. **过滤列优先**：WHERE条件中使用的列放在前面
2. **等值条件优先**：等值条件（=）的列优先于范围条件（>、<、BETWEEN）
3. **排序列靠前**：如果查询需要排序，排序列应尽量放在前面
4. **高选择性列优先**：选择性高的列放在前面

```sql
-- 查询：SELECT name, email FROM users WHERE status = 'active' AND type = 'vip'
-- 正确设计：过滤列在前，查询列在后
CREATE INDEX idx_users_status_type_name_email
    ON users (status, type, name, email);

-- 不推荐：查询列放在过滤列之前
CREATE INDEX idx_users_wrong_order
    ON users (name, email, status, type);
```

### 主键与二级索引

在YashanDB中，主键索引的特点会影响二级索引的回表行为：

```sql
-- orders表，主键为id
CREATE TABLE orders (
    id BIGINT PRIMARY KEY,
    user_id BIGINT,
    status VARCHAR(20)
);

-- 创建二级索引
CREATE INDEX idx_orders_user ON orders (user_id);

-- 此查询可以利用索引：
-- 二级索引的叶子节点存储了主键值(id)
SELECT id, user_id FROM orders WHERE user_id = 42;
```

这是因为二级索引的叶子节点自动存储了主键值，使得主键列天然具有"被覆盖"的特性。

## 执行计划分析

使用EXPLAIN查看执行计划，可以判断查询是否实现了索引扫描：

```sql
-- 创建测试表和索引
CREATE TABLE orders (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    total NUMBER(10,2),
    created_at TIMESTAMP
);

CREATE INDEX idx_orders_user_status_total ON orders (user_id, status, total);

-- 查看执行计划
EXPLAIN SELECT user_id, status, total FROM orders WHERE user_id = 100;
```

### 执行计划关键信息

| 信息 | 含义 |
|------|------|
| type | 访问类型，如ref、range等 |
| key | 实际使用的索引 |
| rows | 预计扫描的行数 |

### 索引范围扫描示例

假设有表idxtest，其上建有a列的索引：

```sql
SELECT * FROM idxtest WHERE a > 50 AND a < 1020;
```

上述查询会执行索引范围扫描。如果表idxtest只有a列，则不需要额外的IO回表查询。如果表idxtest有多个列，则上述扫描还需要对满足条件的每一行数据产生额外的IO回表查询。

### 索引全扫描示例

```sql
-- 索引全扫描：需要使用索引列排序
SELECT a FROM idxtest ORDER BY a;
```

索引全扫描利用索引的有序性，可直接跳过排序的过程。

### 索引快速全扫描示例

```sql
-- 索引快速全扫描：不需要有序的聚合查询
SELECT SUM(a) FROM idxtest;
```

索引快速全扫描会根据索引数据块在物理存储的顺序去扫描数据。

## 与索引条件下推（ICP）的区别

索引条件下推（ICP）和避免回表是两种不同的优化策略：

- **索引条件下推（ICP）**：在索引层面进行条件过滤，但仍需要回表读取数据行
- **避免回表**：查询所需的所有数据都在索引中，无需回表

## 索引设计最佳实践

### 适合创建索引的场景

1. **列被频繁查询**：经常出现在SELECT子句中
2. **列作为查询条件**：经常出现在WHERE子句中
3. **外键列**：在外键列上创建索引，可以避免操作父表带来的子表的排他锁
4. **需要保持唯一的列**：可以创建唯一索引

### 索引扫描的性能优势

- **减少I/O开销**：只需访问索引数据块，无需访问表数据块
- **提高查询速度**：索引数据有序，可以快速定位
- **提升缓存命中率**：索引通常比表小，更容易加载到内存

### 需要注意的问题

1. **额外的空间开销**：索引是独立对象，会占用额外空间
2. **增加DML语句的执行开销**：插入、删除、更新时需要维护索引
3. **可能的性能损失**：滥用索引可能导致性能下降

### 避免过度索引

```sql
-- 错误示例：试图创建一个覆盖所有查询的索引
-- 这个索引会变得非常大，写入性能会很差
CREATE INDEX idx_orders_everything
    ON orders (user_id, status, created_at, order_no, total, customer_id);
```

覆盖索引越宽，查询性能越好，但维护成本越高：
- **优点**：支持更多查询，覆盖更多场景
- **缺点**：索引体积大，占用更多磁盘和内存空间；写入性能下降

## 实际案例

### 案例一：订单列表查询

```sql
-- 常见查询：分页查询用户订单
SELECT id, order_no, total, status, created_at
FROM orders
WHERE user_id = ?
ORDER BY created_at DESC
LIMIT 20;

-- 索引设计
CREATE INDEX idx_orders_user_created
    ON orders (user_id, created_at DESC, order_no, total, status, id);
```

### 案例二：聚合查询优化

```sql
-- 聚合查询：统计各类别订单数量
SELECT status, COUNT(*) AS cnt, SUM(total) AS total_amount
FROM orders
WHERE created_at >= '2024-01-01'
GROUP BY status;

-- 索引设计
CREATE INDEX idx_orders_status_created
    ON orders (status, created_at, total);
```

### 案例三：唯一性查询

```sql
-- 唯一性查询：使用索引唯一扫描
SELECT * FROM orders WHERE order_no = 'ORD20240304001';
-- 需要在order_no上创建唯一索引
CREATE UNIQUE INDEX idx_orders_order_no ON orders (order_no);
```

## 监控与维护

定期监控索引的使用情况：

```sql
-- 查看表上的索引
SELECT
    i.index_name,
    i.index_type,
    i.table_name,
    LISTAGG(c.column_name, ', ') WITHIN GROUP (ORDER BY c.column_position) AS index_columns
FROM user_indexes i
JOIN user_ind_columns c ON i.index_name = c.index_name AND i.table_name = c.table_name
WHERE i.table_name = 'ORDERS'
GROUP BY i.index_name, i.index_type, i.table_name;
```

## 总结

1. **利用索引有序性**：当查询需要排序时，索引全扫描可以利用索引的有序性跳过排序
2. **合理设计索引列**：将过滤列、排序列、查询列纳入索引设计
3. **避免SELECT ***：只选择需要的列，更容易实现索引扫描
4. **平衡读写成本**：索引会加重写入负担，需要根据读写比例权衡
5. **使用EXPLAIN验证**：确保查询使用了预期的索引扫描方式

---

### 参考

- [产品文档/概念手册/关系数据结构/模式对象/索引.md](../产品文档/概念手册/关系数据结构/模式对象/索引.md)
