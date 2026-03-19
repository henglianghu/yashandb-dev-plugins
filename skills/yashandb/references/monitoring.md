---
title: YashanDB 监控与诊断
description: 关键系统视图、性能指标采集、常见问题诊断及监控最佳实践
tags: yashandb, monitoring, diagnostic, v$session, v$sql, performance-tuning, wait-events
---

# 监控与诊断

> **参考文档**：产品文档/数据库管理/运行监控/00运行监控.md

运行监控主要是指在数据库运行过程中，DBA可以对会话、日志等进行日常巡检、监控，以便及时发现异常。

有效的监控和诊断是保障 YashanDB 数据库稳定运行的关键。通过系统视图可以获取数据库的运行状态、性能指标和资源使用情况，帮助 DBA 及时发现和解决性能问题。

## 关键系统视图

YashanDB 提供了丰富的系统视图，用于监控数据库的各个方面。以下是常用的关键视图。

### 会话管理视图

```sql
-- 查看当前所有会话
SELECT sid, serial#, username, status, machine, program
FROM v$session
ORDER BY logon_time;

-- 查看会话详情
SELECT * FROM v$session WHERE sid = 123;

-- 查看会话执行的 SQL
SELECT s.sid, s.username, q.sql_text
FROM v$session s
JOIN v$sql q ON s.sql_address = q.address
WHERE s.status = 'ACTIVE';
```

### 等待事件视图

```sql
-- 查看当前等待事件
SELECT sid, event, wait_time, seconds_in_wait, state
FROM v$session_wait
WHERE sid = 123;

-- 查看系统级等待事件统计
SELECT wait_class, total_waits, time_waited, average_wait
FROM v$system_wait_class
ORDER BY time_waited DESC;

-- 查看详细等待事件
SELECT event, total_waits, time_waited, max_wait
FROM v$event_name
ORDER BY total_waits DESC;
```

### SQL 执行视图

```sql
-- 查看正在执行的 SQL
SELECT sid, sql_text, elapsed_time, cpu_time
FROM v$sql
WHERE status = 'EXECUTING'
ORDER BY elapsed_time DESC;

-- 查看历史 SQL 执行统计
SELECT sql_text, executions, elapsed_time, rows_processed
FROM v$sqlarea
ORDER BY elapsed_time DESC;

-- 查看特定用户的 SQL
SELECT * FROM v$sql
WHERE parsing_user_id = (
    SELECT user_id FROM all_users WHERE username = 'SCOTT'
);
```

### 内存使用视图

```sql
-- 查看 SGA 使用情况
SELECT * FROM v$sgastat;

-- 查看 PGA 使用情况
SELECT * FROM v$pgastat;

-- 查看缓冲区命中率
SELECT
    name,
    value,
    CASE
        WHEN name = 'buffer hit ratio' AND value < 90 THEN 'NEED TUNING'
        ELSE 'OK'
    END as status
FROM v$sysstat
WHERE name LIKE '%hit%';

-- 查看表空间使用
SELECT tablespace_name,
    round(sum(bytes) / 1024 / 1024, 2) as size_mb,
    round(sum(free_bytes) / 1024 / 1024, 2) as free_mb
FROM (
    SELECT tablespace_name, bytes, 0 as free_bytes
    FROM dba_data_files
    UNION ALL
    SELECT tablespace_name, 0, bytes
    FROM dba_free_space
)
GROUP BY tablespace_name;
```

## 性能指标采集

### 关键性能指标

```sql
-- 计算缓存命中率
SELECT
    1 - (a.value / (b.value + c.value)) as buffer_hit_ratio
FROM v$sysstat a, v$sysstat b, v$sysstat c
WHERE a.name = 'physical reads'
    AND b.name = 'db block gets'
    AND c.name = 'consistent gets';

-- 计算库缓存命中率
SELECT
    sum(pins) as total_pins,
    sum(reloads) as total_reloads,
    1 - sum(reloads) / sum(pins) as library_hit_ratio
FROM v$librarycache;

-- 计算字典缓存命中率
SELECT
    sum(gets) as gets,
    sum(getmisses) as getmisses,
    1 - sum(getmisses) / sum(gets) as dict_hit_ratio
FROM v$rowcache;

-- 查看排序统计
SELECT name, value
FROM v$sysstat
WHERE name LIKE 'sort%';
```

### 实时性能监控

```sql
-- 查看当前负载
SELECT * FROM v$sysmetric WHERE group_id = 2;

-- 查看系统资源使用
SELECT * FROM v$osstat;

-- 查看磁盘 I/O 统计
SELECT * FROM v$filestat;

-- 查看回滚段使用
SELECT usn, rssize, xacts, gets,FROM v$roll waits
stat;
```

### 性能基线采集

```sql
-- 创建性能基线
BEGIN
    DBMS_WORKLOAD_REPOSITORY.create_baseline(
        start_time => SYSDATE - 1,
        end_time => SYSDATE,
        baseline_name => 'baseline_20240315'
    );
END;
/

-- 查看基线
SELECT * FROM dba_hist_baseline;

-- 比较性能差异
SELECT * FROM dba_histsnap
WHERE begin_interval_time BETWEEN SYSDATE - 2 AND SYSDATE;
```

## 常见问题的诊断方法

### 性能问题诊断

```sql
-- 1. 查看当前最慢的 SQL
SELECT sql_text, elapsed_time, cpu_time, executions
FROM v$sql
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;

-- 2. 查看等待最多的会话
SELECT sid, event, wait_time
FROM v$session_wait
WHERE wait_time > 0
ORDER BY wait_time DESC;

-- 3. 查看锁等待
SELECT l.session_id, l.lock_type, l.mode_held, l.mode_requested,
    o.object_name
FROM v$lock l
JOIN dba_objects o ON l.id1 = o.object_id
WHERE l.request > 0;

-- 4. 查看阻塞会话
SELECT blocking_session, sid, wait_class, seconds_in_wait
FROM v$session
WHERE blocking_session IS NOT NULL;
```

### 锁问题诊断

```sql
-- 查看当前锁
SELECT
    l.session_id as sid,
    l.lock_type,
    l.id1,
    l.id2,
    l.lmode,
    l.request,
    o.object_name
FROM v$lock l
JOIN dba_objects o ON l.id1 = o.object_id
WHERE l.type = 'TX';

-- 查看锁等待链
SELECT
    s1.username || '(' || s1.sid || ')' as blocking_user,
    s2.username || '(' || s2.sid || ')' as waiting_user,
    o1.name || '->' || o2.name as lock_dependencies
FROM v$lock l1,
    v$lock l2,
    v$session s1,
    v$session s2,
    dba_objects o1,
    dba_objects o2
WHERE l1.block = 1
    AND l2.request > 0
    AND l1.id1 = l2.id1
    AND l1.id2 = l2.id2
    AND s1.sid = l1.sid
    AND s2.sid = l2.sid
    AND o1.object_id = l1.id1
    AND o2.object_id = l2.id1;

-- 终止阻塞会话
ALTER SYSTEM KILL SESSION '123,456';
```

### 存储问题诊断

```sql
-- 查看表空间使用率
SELECT
    tablespace_name,
    round(total_space / 1024 / 1024, 2) as total_mb,
    round(free_space / 1024 / 1024, 2) as free_mb,
    round((total_space - free_space) / total_space * 100, 2) as used_pct
FROM (
    SELECT tablespace_name,
        sum(bytes) as total_space,
        sum(decode(maxbytes, 0, bytes, maxbytes)) as max_space
    FROM dba_data_files
    GROUP BY tablespace_name
) f
JOIN (
    SELECT tablespace_name, sum(bytes) as free_space
    FROM dba_free_space
    GROUP BY tablespace_name
) u USING (tablespace_name);

-- 查看大对象
SELECT segment_name, segment_type, bytes / 1024 / 1024 as size_mb
FROM dba_segments
WHERE bytes > 1024 * 1024 * 100
ORDER BY bytes DESC;

-- 查看索引使用情况
SELECT index_name, table_name, blevel, leaf_blocks, distinct_keys
FROM dba_indexes
WHERE owner = 'SCOTT';
```

### 连接问题诊断

```sql
-- 查看连接数统计
SELECT status, count(*) as count
FROM v$session
GROUP BY status;

-- 查看达到最大连接数
SELECT 'current connections: ' || count(*) ||
    ', max ever: ' || max(value)
FROM v$sysstat
WHERE name = 'logins cumulative';

-- 查看空闲会话
SELECT sid, serial#, username, machine
FROM v$session
WHERE status = 'INACTIVE'
    AND last_call_et > 3600;  -- 超过1小时

-- 终止空闲会话
ALTER SYSTEM KILL SESSION 'sid,serial#';
```

## 监控最佳实践

### 日常监控脚本

```sql
-- 1. 系统健康检查
SELECT 'Database Status' as check_item,
    CASE WHEN status = 'OPEN' THEN 'OK' ELSE 'ERROR' END as status
FROM v$instance;

-- 2. 表空间检查
SELECT tablespace_name,
    CASE
        WHEN used_pct > 90 THEN 'CRITICAL'
        WHEN used_pct > 80 THEN 'WARNING'
        ELSE 'OK'
    END as status
FROM (
    SELECT tablespace_name,
        (total_space - free_space) / total_space * 100 as used_pct
    FROM (
        SELECT tablespace_name, sum(bytes) as total_space
        FROM dba_data_files GROUP BY tablespace_name
    )
    JOIN (
        SELECT tablespace_name, sum(bytes) as free_space
        FROM dba_free_space GROUP BY tablespace_name
    ) USING (tablespace_name)
);

-- 3. 性能指标汇总
SELECT
    ROUND((1 - (SELECT value FROM v$sysstat WHERE name = 'physical reads') /
        ((SELECT value FROM v$sysstat WHERE name = 'db block gets') +
         (SELECT value FROM v$sysstat WHERE name = 'consistent gets'))) * 100, 2) || '%' as buffer_hit,
    ROUND((SELECT sum(value) FROM v$sysstat WHERE name LIKE 'sort%' AND name LIKE '%disk') /
        DECODE((SELECT sum(value) FROM v$sysstat WHERE name LIKE 'sort%'), 0, 1,
            (SELECT sum(value) FROM v$sysstat WHERE name LIKE 'sort%')), 2) * 100, 2) || '%' as disk_sort_ratio
FROM dual;
```

### 告警设置

```sql
-- 创建告警阈值
BEGIN
    DBMS_SERVER_ALERT.SET_THRESHOLD(
        metrics_id => DBMS_SERVER_ALERT.TABLESPACE_PCT_USED,
        warning_operator => DBMS_SERVER_ALERT.OPERATOR_GE,
        warning_value => 80,
        critical_operator => DBMS_SERVER_ALERT.OPERATOR_GE,
        critical_value => 90,
        observation_period => 30,
        consecutive_occurrences => 3
    );
END;
/

-- 查看告警
SELECT * FROM dba_outstanding_alerts;
SELECT * FROM dba_alert_history;
```

### AWR 报告分析

```sql
-- 生成 AWR 报告
@?/rdbms/admin/awrrpt.sql

-- 查看 AWR 基线
SELECT baseline_name, start_time, end_time
FROM dba_hist_baseline;

-- 查看快照信息
SELECT snap_id, begin_interval_time, end_interval_time
FROM dba_hist_snapshot
ORDER BY snap_id;
```

### 自动化监控建议

1. **定时任务**：使用定时任务执行监控脚本
2. **告警通知**：配置邮件或短信告警
3. **历史趋势**：保存历史性能数据用于趋势分析
4. **容量规划**：基于历史数据进行容量规划

---

### 参考

- [产品文档/数据库管理/运行监控/00运行监控.md](../../../产品文档/数据库管理/运行监控/00运行监控.md)
