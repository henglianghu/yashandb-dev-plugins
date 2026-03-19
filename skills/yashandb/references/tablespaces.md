---
title: YashanDB 表空间管理
description: 表空间创建、存储参数、类型与扩容管理
tags: yashandb, tablespace, storage, initrans, maxtrans, pctfree
---

# 表空间管理

> **参考文档**：产品文档/数据库管理/存储管理/逻辑空间管理/表空间管理/00表空间管理.md

表空间是 YashanDB 中用于存储数据库对象（表、索引等）的逻辑存储单元。合理规划和管理表空间可以优化性能、提高存储效率、简化容量管理。

## 用户表空间管理准则

> **官方说明**："建议为业务用户创建特定的用户表空间，而不是使用默认的USERS表空间。"

对于用户表空间，建议按以下准则进行创建和维护：

- 将用户数据与数据字典数据分开，以减少I/O争用
- 将一个应用程序的数据与另一个应用程序的数据分开，以防止在表空间必须脱机时多个应用程序受到影响
- 将不同表空间的数据文件存储在不同的磁盘驱动器上，以减少I/O争用
- 单个表空间脱机时，其他表空间可以继续保持联机，无需全部表空间脱机或关闭数据库，从而提供更好的可用性
- 通过为特定类型的数据库使用保留表空间来优化表空间的使用，例如高更新活动、只读活动或临时段存储
- 按单个表空间执行逻辑备份

## YashanDB 默认表空间

> **官方说明**："YashanDB内置了如下表空间，其属性可以直接使用默认值或在建库时自定义指定。"

YashanDB 内置了以下默认表空间：

| 表空间类型 | 说明 |
|-----------|------|
| SYSTEM 表空间 | 数据字典和系统元数据 |
| SYSAUX 表空间 | 辅助系统表空间 |
| USERS 表空间 | 默认用户表空间（即 DEFAULT TABLESPACE） |
| TEMP 表空间 | 临时数据表空间 |
| UNDO 表空间 | 撤销数据表空间 |
| SWAP 表空间 | 交换表空间 |
| USERS_AIM 表空间 | 仅存在于存算一体分布式集群部署 |

## 表空间容量计算

> **官方说明**："表空间的容量计算方式如下：表空间数据文件大小由BLOCK大小及其数量决定。"

### BLOCK 大小

> **官方说明**："BLOCK大小由配置参数DB_BLOCK_SIZE决定，参数值可以为8192、16384或32768（即8KB、16KB或32KB），默认值为8192。"

### BLOCK 数量

> **官方说明**："BLOCK数量：默认值为8192个，开启自动扩展时默认扩展8192个/次。UNDO表空间BLOCK数量可以为[8192,8388608]个，其他永久表空间BLOCK数量可以为[8192,97108864]个。"

### 数据文件数量

> **官方说明**："表空间数据文件数量：可以为[1,64]个，默认值为1个。"

### 建库参数与表空间容量对应关系

> **官方说明**："安装过程中创建的初始数据库表空间容量与建库参数的对应关系及其初始默认值如下："

| 表空间类型 | 关联的建库参数 | 表空间默认容量 |
|-----------|--------------|--------------|
| SYSTEM 表空间 | SYSTEM_FILE_INIT_SIZE, SYSTEM_FILE_NUM | 64M * 1 = 64M |
| SYSAUX 表空间 | SYSAUX_FILE_INIT_SIZE, SYSAUX_FILE_NUM | 64M * 1 = 64M |
| SWAP 表空间 | SWAP_FILE_INIT_SIZE, SWAP_FILE_NUM | 64M * 1 = 64M |
| UNDO 表空间 | UNDO_FILE_INIT_SIZE, UNDO_FILE_NUM | 64M * 1 = 64M |
| TEMP 表空间 | TEMP_FILE_INIT_SIZE, TEMP_FILE_NUM | 64M * 1 = 64M |
| USERS 表空间 | DATA_FILE_INIT_SIZE, DATA_FILE_NUM | 64M * 1 = 64M |
| USERS_AIM 表空间 | MMS_DATA_FILE_SIZE, MMS_DATA_FILE_NUM | 32M * 1 = 32M |

## 表空间类型

YashanDB 支持多种类型的表空间：

### 1. 永久表空间

存储持久数据（表、索引等）：

```sql
-- 创建永久表空间
CREATE TABLESPACE users_tbs
    DATAFILE '/data/yashandb/users01.dbf'
    SIZE 100M
    AUTOEXTEND ON NEXT 50M MAXSIZE 10G;
```

### 2. 临时表空间

存储临时数据（排序操作、中间结果）：

```sql
-- 创建临时表空间
CREATE TEMPORARY TABLESPACE temp_tbs
    TEMPFILE '/data/yashandb/temp01.dbf'
    SIZE 500M
    AUTOEXTEND ON NEXT 100M;
```

### 3. UNDO 表空间

存储撤销数据，支持事务一致性：

```sql
-- 创建 UNDO 表空间
CREATE UNDO TABLESPACE undo_tbs
    DATAFILE '/data/yashandb/undo01.dbf'
    SIZE 1G
    AUTOEXTEND ON NEXT 200M;
```

## 创建表空间

### 基本语法

```sql
CREATE TABLESPACE tablespace_name
    DATAFILE 'path/filename.dbf'
    SIZE size [K|M|G]
    AUTOEXTEND ON|NEXT size [K|M|G] MAXSIZE UNLIMITED|size;
```

### 示例

```sql
-- 创建自动扩展的表空间
CREATE TABLESPACE app_data
    DATAFILE '/data/yashandb/app_data01.dbf'
    SIZE 1G
    AUTOEXTEND ON NEXT 100M MAXSIZE 50G;

-- 创建固定大小的表空间（适用于已知数据量）
CREATE TABLESPACE archive_tbs
    DATAFILE '/data/yashandb/archive01.dbf'
    SIZE 10G;
```

## 存储参数

### INITRANS 和 MAXTRANS

控制并发事务对数据块的访问：

```sql
CREATE TABLESPACE data_tbs
    DATAFILE '/data/yashandb/data01.dbf'
    SIZE 1G
    INITRANS 4
    MAXTRANS 255;
```

| 参数 | 说明 | 默认值 | 建议 |
|------|------|--------|------|
| INITRANS | 初始事务槽位数 | 2 | 高并发表适当增大 |
| MAXTRANS | 最大事务槽位数 | 255 | 通常无需修改 |

**事务槽位**：每个并发事务在数据块头部占用一个事务槽位。INITRANS 预分配槽位，MAXTRANS 允许动态扩展。

### PCTFREE

保留空间百分比，用于行更新：

```sql
CREATE TABLE orders (
    id BIGINT PRIMARY KEY,
    amount NUMBER(10,2)
) TABLESPACE data_tbs
    PCTFREE 20;
```

```sql
-- 修改现有表的 PCTFREE
ALTER TABLE orders PCTFREE 30;
```

| PCTFREE 值 | 适用场景 |
|------------|----------|
| 10（默认） | 插入为主，少量更新 |
| 20-30 | 有大量 UPDATE 操作的表 |
| 5 | 只读或几乎不更新的表 |

**原理**：PCTFREE 指定保留用于 UPDATE 的空间百分比。如果设置为 20%，则每个数据块只填充 80%，预留空间供已有行扩展。

### PCTUSED

数据块重新可用的阈值：

```sql
CREATE TABLE logs (
    id BIGINT,
    message CLOB
) TABLESPACE data_tbs
    PCTFREE 10 PCTUSED 60;
```

| 场景 | PCTFREE | PCTUSED |
|------|---------|----------|
| 高插入、低更新 | 10 | 40 |
| 均衡读写 | 10-20 | 40-60 |
| 低插入、高更新 | 20-30 | 60-80 |

**工作机制**：
- 当数据块使用率低于 PCTUSED 时，该块回到可用列表
- 当数据块使用率超过 PCTFREE 阈值后，不再接受新行

## 表空间扩容

### 自动扩展

```sql
-- 创建时启用自动扩展
CREATE TABLESPACE app_data
    DATAFILE '/data/yashandb/app_data01.dbf'
    SIZE 100M
    AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED;
```

### 手动添加数据文件

```sql
-- 为现有表空间添加新的数据文件
ALTER TABLESPACE app_data
    ADD DATAFILE '/data/yashandb/app_data02.dbf'
    SIZE 500M;
```

### 调整数据文件大小

```sql
-- 增大现有数据文件
ALTER DATABASE
    DATAFILE '/data/yashandb/app_data01.dbf'
    RESIZE 2G;

-- 减小数据文件（仅限文件末尾空闲空间）
ALTER DATABASE
    DATAFILE '/data/yashandb/app_data01.dbf'
    RESIZE 500M;
```

## 默认表空间设置

### 设置默认表空间

```sql
-- 设置默认永久表空间
ALTER DATABASE DEFAULT TABLESPACE users_tbs;

-- 设置默认临时表空间
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE temp_tbs;

-- 设置默认 UNDO 表空间
ALTER SYSTEM SET undo_tablespace = 'undo_tbs';
```

### 用户级别默认表空间

```sql
-- 创建用户时指定默认表空间
CREATE USER app_user IDENTIFIED BY password
    DEFAULT TABLESPACE app_data
    TEMPORARY TABLESPACE temp_tbs;
```

```sql
-- 修改现有用户的默认表空间
ALTER USER app_user DEFAULT TABLESPACE app_data;
```

## 表与表空间

### 创建表时指定表空间

```sql
-- 将表创建在指定表空间
CREATE TABLE orders (
    id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    order_date DATE,
    amount NUMBER(10,2)
) TABLESPACE orders_tbs
    PCTFREE 10;
```

### 将表移动到其他表空间

```sql
-- 移动表到新表空间
ALTER TABLE orders MOVE TABLESPACE app_data;

-- 移动索引到新表空间
ALTER INDEX idx_order_date REBUILD TABLESPACE idx_tbs;
```

### 查看表所在表空间

```sql
-- 查看表的表空间信息
SELECT table_name, tablespace_name
FROM user_tables
WHERE table_name = 'ORDERS';

-- 查看索引的表空间信息
SELECT index_name, tablespace_name
FROM user_indexes
WHERE table_name = 'ORDERS';
```

## 表空间监控

### 查看表空间使用情况

```sql
-- 查看表空间使用率
SELECT tablespace_name,
       ROUND((total_space - free_space) / total_space * 100, 2) as used_pct,
       total_space,
       free_space
FROM (
    SELECT tablespace_name,
           SUM(bytes) / 1024 / 1024 as total_space,
           SUM(DECODE(status, 'FREE', bytes, 0)) / 1024 / 1024 as free_space
    FROM dba_data_files
    GROUP BY tablespace_name
);
```

### 查看数据文件信息

```sql
-- 查看数据文件详细信息
SELECT file_name,
       tablespace_name,
       bytes / 1024 / 1024 as size_mb,
       autoextensible,
       maxbytes / 1024 / 1024 as max_size_mb
FROM dba_data_files
ORDER BY tablespace_name;
```

## 表空间规划最佳实践

### 1. 按业务分离表空间

```sql
-- 核心业务表
CREATE TABLESPACE core_tbs DATAFILE '/data/yashandb/core01.dbf' SIZE 10G;

-- 日志/归档表
CREATE TABLESPACE log_tbs DATAFILE '/data/yashandb/log01.dbf' SIZE 50G;

-- 索引表空间
CREATE TABLESPACE idx_tbs DATAFILE '/data/yashandb/idx01.dbf' SIZE 10G;
```

### 2. 合理设置存储参数

```sql
-- 高并发核心表：增加 INITRANS
CREATE TABLE accounts (
    id BIGINT PRIMARY KEY,
    balance NUMBER(15,2)
) TABLESPACE core_tbs
    INITRANS 4
    PCTFREE 10;

-- 频繁更新的表：增加 PCTFREE
CREATE TABLE user_sessions (
    user_id BIGINT,
    session_data CLOB,
    last_activity TIMESTAMP
) TABLESPACE core_tbs
    PCTFREE 20
    INITRANS 4;
```

### 3. 启用自动扩展但设置上限

```sql
CREATE TABLESPACE app_data
    DATAFILE '/data/yashandb/app_data01.dbf'
    SIZE 1G
    AUTOEXTEND ON NEXT 200M MAXSIZE 100G;  -- 设置合理上限
```

### 4. 定期监控和清理

- 监控表空间使用率，保持 20% 以上的空闲空间
- 定期清理无用数据，释放表空间
- 对历史归档数据进行归档或删除

---

### 参考

- [产品文档/数据库管理/存储管理/逻辑空间管理/表空间管理/00表空间管理.md](../../../产品文档/数据库管理/存储管理/逻辑空间管理/表空间管理/00表空间管理.md)
