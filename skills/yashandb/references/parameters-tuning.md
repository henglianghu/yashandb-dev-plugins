---
title: YashanDB 参数调优
description: 内存参数、连接参数、日志参数及常见性能参数配置指南
tags: yashandb, parameters, tuning, sga, pga, memory-tuning, connection-tuning
---

# 参数调优

> **参考文档**：产品文档/参考手册/配置参数.md

YashanDB 的参数配置直接影响数据库的性能和稳定性。合理的参数设置可以充分发挥数据库的性能，而不当的设置可能导致性能下降甚至系统不稳定。本文档将详细介绍关键参数的配置方法和调优技巧。

## 参数管理基础

### 查看参数

```sql
-- 查看当前所有参数
SHOW PARAMETERS;

-- 查看特定参数
SHOW PARAMETER data_buffer;
SHOW PARAMETER work_area;

-- 查看参数详细信息
SELECT name, value, description, is_modifiable
FROM v$parameter
WHERE name LIKE '%data_buffer%';

-- 查看修改过的参数
SELECT name, value, is_modified
FROM v$parameter
WHERE is_modified = 'TRUE';
```

### 修改参数

```sql
-- 修改当前会话的参数
ALTER SESSION SET WORK_AREA_HEAP_SIZE = 2048000;

-- 修改系统级参数（需要 DBA 权限）
ALTER SYSTEM SET DATA_BUFFER_SIZE = 2G SCOPE = BOTH;
ALTER SYSTEM SET DATA_BUFFER_SIZE = 2G SCOPE = SPFILE;
ALTER SYSTEM SET DATA_BUFFER_SIZE = 2G SCOPE = MEMORY;
```

参数修改的 Scope 选项说明：
- **MEMORY**：只修改当前实例，重启后失效
- **SPFILE**：只修改参数文件，重启后生效
- **BOTH**：同时修改当前实例和参数文件（默认）

## 内存参数

内存参数是影响数据库性能最重要的参数类别。YashanDB 的内存管理主要包括数据缓冲区、共享池、工作区等组件。

### 数据缓冲区 (Data Buffer)

数据缓冲区是数据库实例共享的内存区域，用于缓存数据块、存储解析后的 SQL、执行计划等。数据缓冲区容量越大，数据库整体性能越好。

| 参数 | 说明 | 默认值 | 取值范围 |
|------|------|--------|----------|
| DATA_BUFFER_SIZE | 数据缓存区的大小 | 256M | [32M,64T] |

```sql
-- 配置数据缓冲区参数
ALTER SYSTEM SET DATA_BUFFER_SIZE = 4G SCOPE = SPFILE;

-- 查看数据缓冲区使用情况
SELECT * FROM v$sgastat;
```

### 共享池 (Shared Pool)

共享池用于存储游标、SQL 语句缓存等。

| 参数 | 说明 | 默认值 | 取值范围 |
|------|------|--------|----------|
| SHARE_POOL_SIZE | 共享池大小 | 320M | [256M,64T] (单机), [320M,64T] (共享集群) |
| CURSOR_POOL_SIZE | 游标缓存区大小 | 32M | [16M,64T] |
| LARGE_POOL_SIZE | 大数据块总大小 | 128M | [8M,1T] |

```sql
-- 配置共享池参数
ALTER SYSTEM SET SHARE_POOL_SIZE = 1G SCOPE = SPFILE;
ALTER SYSTEM SET CURSOR_POOL_SIZE = 64M SCOPE = SPFILE;
```

### 工作区 (Work Area)

工作区是每个服务器进程私有的内存区域，用于排序、哈希连接、位图操作等。

| 参数 | 说明 | 默认值 | 取值范围 | 修改立即生效 |
|------|------|--------|----------|--------------|
| WORK_AREA_HEAP_SIZE | 会话内执行内存区（私有内存）大小 | 512K | [128K,4M] | 否 |
| WORK_AREA_POOL_SIZE | 工作区池大小 | - | - | - |
| WORK_AREA_STACK_SIZE | 工作区栈大小 | - | - | - |

```sql
-- 配置工作区参数
ALTER SYSTEM SET WORK_AREA_HEAP_SIZE = 2M SCOPE = SPFILE;

-- 查看工作区使用情况
SELECT * FROM v$pgastat;
```

### 虚拟内存 (VM Buffer)

虚拟内存用于 SQL 标准计算，当计算中排序、物化、JOIN 等涉及的数据量较多时，建议调大此参数。

| 参数 | 说明 | 默认值 | 取值范围 |
|------|------|--------|----------|
| VM_BUFFER_SIZE | SQL标准计算使用的内存大小 | 128M | [8M,2T] |

```sql
-- 配置虚拟内存参数
ALTER SYSTEM SET VM_BUFFER_SIZE = 256M SCOPE = SPFILE;
```

### 重做日志缓冲区

| 参数 | 说明 | 默认值 | 取值范围 |
|------|------|--------|----------|
| REDO_BUFFER_SIZE | redo刷盘的内存大小 | 64M | [4M,128M] |

```sql
-- 配置重做日志缓冲区参数
ALTER SYSTEM SET REDO_BUFFER_SIZE = 128M SCOPE = SPFILE;
```

## 连接参数

连接参数控制客户端与数据库的连接行为，对并发性能和资源使用有重要影响。

### 最大连接数参数

| 参数 | 说明 | 默认值 | 取值范围 |
|------|------|--------|----------|
| MAX_SESSIONS | 最大会话数 | 1024 | [64 + MAX_PARALLEL_WORKERS, 50000] |
| MAX_PARALLEL_WORKERS | 并行worker池的worker数量 | 32 | [1, MIN(MAX_SESSIONS - 64, 4096)] |
| SESSION_MAX_OPEN_FILES | 会话最大打开文件数 | - | - |
| EXTSERVER_CONNS | 外部服务器连接数 | - | - |

```sql
-- 配置连接参数
ALTER SYSTEM SET MAX_SESSIONS = 2000 SCOPE = SPFILE;

-- 查看当前连接数
SELECT count(*) FROM v$session;
SELECT count(*) FROM v$process;
```

### 游标参数

| 参数 | 说明 | 默认值 | 取值范围 |
|------|------|--------|----------|
| OPEN_CURSORS | 打开游标的最大数量 | 310 | [0,65535] |

```sql
-- 配置游标参数
ALTER SYSTEM SET OPEN_CURSORS = 500 SCOPE = BOTH;
```

## 日志参数

日志参数控制数据库日志的生成、归档和存储，对数据安全和性能有重要影响。

### 归档日志参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| ARCHIVE_LOCAL_DEST | 存放归档文件的目录路径 | ?/archive (单机) 或 +DG0/arch_files (共享集群) |
| ARCHIVE_DEST_1 ~ 32 | 备库的配置 | - |
| ARCHIVELOG_DELETION_POLICY | 归档的自动清理和手动清理策略 | DEFAULT |

```sql
-- 查看归档模式
ARCHIVE LOG List;

-- 启用归档模式
ALTER SYSTEM SET ARCHIVE_LOCAL_DEST = '/archive1' SCOPE = SPFILE;

-- 配置归档清理策略
ALTER SYSTEM SET ARCHIVELOG_DELETION_POLICY = 'BACKED UP 2 TIMES, SHIPPED TO ALL STANDBY' SCOPE = BOTH;
```

### 慢查询日志参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| ENABLE_SLOW_LOG | 是否启用慢日志 | - |
| SLOW_LOG_TIME_THRESHOLD | 慢日志时间阈值 | - |
| SLOW_LOG_SQL_MAX_LEN | 慢日志SQL最大长度 | - |
| RUN_LOG_FILE_PATH | 运行日志文件路径 | - |
| RUN_LOG_LEVEL | 运行日志级别 | - |

```sql
-- 配置慢查询日志
ALTER SYSTEM SET ENABLE_SLOW_LOG = TRUE SCOPE = BOTH;
ALTER SYSTEM SET SLOW_LOG_TIME_THRESHOLD = 1000 SCOPE = BOTH;

-- 查看告警日志路径
SHOW PARAMETER DIAGNOSTIC_DEST;
```

### 重做日志参数

```sql
-- 查看日志组状态
SELECT group#, sequence#, bytes, status, archived
FROM v$log;

-- 添加日志组
ALTER DATABASE ADD LOGFILE
    GROUP 4 ('/oradata/redo04a.log', '/oradata/redo04b.log') SIZE 500M;

-- 删除日志组
ALTER DATABASE DROP LOGFILE GROUP 3;
```

## 常见性能参数调优

### 优化器参数

```sql
-- 动态采样
ALTER SESSION SET OPTIMIZER_DYNAMIC_SAMPLING = 2;

-- 实时统计信息
ALTER SESSION SET OPTIMIZER_REAL_TIME_STATISTICS = TRUE;

-- 统计信息收集
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('SCOTT');

-- 查看执行计划
EXPLAIN PLAN FOR SELECT * FROM employees WHERE department_id = 10;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

### 并行执行参数

```sql
-- 并行度设置
ALTER TABLE employees PARALLEL 8;
CREATE INDEX idx_emp_dept ON employees (department_id) PARALLEL 4;

-- 并行查询参数
ALTER SYSTEM SET MAX_PARALLEL_WORKERS = 64 SCOPE = SPFILE;
ALTER SYSTEM SET PQ_POOL_SIZE = 256M SCOPE = SPFILE;
```

### 检查点参数

| 参数 | 说明 | 默认值 | 取值范围 |
|------|------|--------|----------|
| CHECKPOINT_INTERVAL | 检查点间隔 | - | - |
| CHECKPOINT_TIMEOUT | 检查点超时 | - | - |

```sql
-- 配置检查点参数
ALTER SYSTEM SET CHECKPOINT_INTERVAL = 1000 SCOPE = SPFILE;
ALTER SYSTEM SET CHECKPOINT_TIMEOUT = 600 SCOPE = SPFILE;
```

## 参数修改注意事项

### 修改原则

1. **最小影响原则**：优先在会话级别修改，验证无误后再在系统级应用
2. **渐进调整原则**：每次只修改一个参数，观察效果后再调整其他参数
3. **记录变更**：记录所有参数修改及原因，便于问题追溯
4. **备份配置**：修改前备份当前参数配置

### 参数修改流程

```sql
-- 1. 查看当前配置
SHOW PARAMETER DATA_BUFFER_SIZE;

-- 2. 在会话级别测试
ALTER SESSION SET WORK_AREA_HEAP_SIZE = 4096000;

-- 3. 验证效果
-- 执行性能测试

-- 4. 应用到系统
ALTER SYSTEM SET parameter = new_value SCOPE = BOTH;

-- 5. 记录变更
-- 记录到文档或变更管理系统
```

### 常见问题处理

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 数据缓冲区不足 | DATA_BUFFER_SIZE 过小 | 增加 DATA_BUFFER_SIZE |
| 工作区不足 | WORK_AREA_HEAP_SIZE 过小 | 增加 WORK_AREA_HEAP_SIZE |
| 连接数不足 | MAX_SESSIONS 过小 | 增加 MAX_SESSIONS 参数 |
| 游标不足 | OPEN_CURSORS 过小 | 增加 OPEN_CURSORS |
| 并行度受限 | MAX_PARALLEL_WORKERS 过小 | 增加 MAX_PARALLEL_WORKERS |

### 性能监控

```sql
-- 查看等待事件
SELECT wait_class, total_waits, time_waited
FROM v$system_wait_class
ORDER BY time_waited DESC;

-- 查看系统统计信息
SELECT name, value
FROM v$sysstat
WHERE name IN ('db block gets', 'consistent gets', 'physical reads');

-- 计算缓存命中率
SELECT
    1 - (physical_reads / (db_block_gets + consistent_gets)) as hit_ratio
FROM v$sysstat
WHERE name IN ('db block gets', 'consistent gets', 'physical reads');
```

---

### 参考

- [产品文档/参考手册/配置参数.md](../数据库管理/实例管理/数据库参数配置.md)
