---
title: YashanDB 闪回技术
description: 闪回查询、闪回表、闪回删除及闪回事务功能详解
tags: yashandb, flashback, flashback-query, flashback-table, flashback-drop, recycle-bin, undo
---

# 闪回技术

> **参考文档**：产品文档/概念手册/高可用/闪回.md

闪回技术是 YashanDB 提供的一组强大的数据恢复功能，允许用户快速恢复到过去的某个时间点，或撤销错误的操作。与传统的基于备份的恢复不同，闪回技术基于 undo 数据实现，操作更为高效和灵活。

## 闪回技术概述

YashanDB 的闪回技术主要包括以下几种：

| 闪回类型 | 用途 | 数据来源 |
|----------|------|----------|
| 闪回查询 | 查看历史数据 | Undo 表空间 |
| 闪回表 | 将表恢复到某个时间点 | Undo 表空间 |
| 闪回删除 | 恢复被删除的表 | 回收站 |
| 闪回事务 | 撤销特定事务 | Undo 表空间 + 日志 |

## 闪回查询（Flashback Query）

闪回查询允许用户查询表中某个历史时间点的数据，无需从备份恢复。这对于以下场景特别有用：

- 误更新了数据，需要查看原来的值
- 了解数据在某个时间点的状态
- 审计数据的变更历史

### 基本语法

```sql
-- 查询过去某个时间点的数据
SELECT * FROM employees AS OF TIMESTAMP
    TO_TIMESTAMP('2024-03-15 10:30:00', 'YYYY-MM-DD HH24:MI:SS');

-- 使用 SCN 号查询
SELECT * FROM employees AS OF SCN 1234567;

-- 查看字段变更前后的对比
SELECT employee_id, salary,
    (SELECT salary FROM employees AS OF TIMESTAMP
        SYSDATE - INTERVAL '1' HOUR e2
        WHERE e2.employee_id = employees.employee_id) as salary_1h_ago
FROM employees
WHERE department_id = 10;
```

### 闪回版本查询

可以查看指定时间范围内数据的所有版本：

```sql
-- 查询过去1小时内数据的所有版本变化
SELECT versions_xid, versions_operation,
    employee_id, last_name, salary
FROM employees
    VERSIONS BETWEEN TIMESTAMP SYSDATE - INTERVAL '1' HOUR AND SYSDATE
WHERE department_id = 10
ORDER BY versions_starttime;
```

### 使用场景示例

**场景1：误更新数据后的数据恢复**

```sql
-- 1. 确认错误发生的时间
SELECT * FROM employees AS OF TIMESTAMP
    TO_TIMESTAMP('2024-03-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS')
WHERE employee_id = 1001;

-- 2. 恢复到正确的数据
UPDATE employees
SET salary = (SELECT salary FROM employees AS OF TIMESTAMP
    TO_TIMESTAMP('2024-03-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS')
    WHERE employee_id = 1001)
WHERE employee_id = 1001;

-- 3. 提交更改
COMMIT;
```

**场景2：审计数据变更**

```sql
-- 查看特定记录的所有变更历史
SELECT versions_xid, versions_operation, versions_starttime, versions_endtime,
    employee_id, salary, hire_date
FROM employees
    VERSIONS BETWEEN TIMESTAMP
        TO_DATE('2024-01-01', 'YYYY-MM-DD') AND SYSDATE
WHERE employee_id = 1001;
```

## 闪回表（Flashback Table）

闪回表可以将整个表快速恢复到某个过去的时间点，而无需执行耗时的表恢复操作。

### 基本语法

```sql
-- 将表恢复到指定时间点
FLASHBACK TABLE employees TO
    TIMESTAMP TO_TIMESTAMP('2024-03-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS');

-- 将表恢复到指定 SCN
FLASHBACK TABLE employees TO SCN 1234567;

-- 恢复到删除之前的状态（需要回收站功能）
FLASHBACK TABLE employees TO BEFORE DROP;
```

### 闪回表的前提条件

1. 需要足够的 undo 表空间存储所需的历史数据
2. 表结构在闪回期间不能发生 DDL 变更
3. 需要 FLASHBACK 权限

```sql
-- 授予闪回权限
GRANT FLASHBACK ANY TABLE TO username;

-- 或授予特定表的闪回权限
GRANT FLASHBACK ON employees TO username;
```

### 闪回表示例

```sql
-- 场景：误删除大量数据，需要恢复到之前的状态

-- 1. 查看当前时间
SELECT SYSDATE FROM DUAL;
-- 假设当前时间是 2024-03-15 15:30:00

-- 2. 闪回表到错误操作之前的时间点
FLASHBACK TABLE employees TO
    TIMESTAMP TO_TIMESTAMP('2024-03-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS');

-- 3. 验证恢复结果
SELECT COUNT(*) FROM employees;
-- 确认数据已恢复
```

### 注意事项

- 闪回表是 DDL 操作，会获取排他锁
- 闪回表不能用于恢复被删除的表（应使用 FLASHBACK TABLE TO BEFORE DROP）
- 闪回表不会恢复索引、触发器等依赖对象的状态变化

## 闪回删除（Flashback Drop）

闪回删除利用回收站机制，允许恢复被 DROP 删除的表。

### 回收站机制

当执行 DROP TABLE 操作时，表不会被立即删除，而是被重命名并放入回收站。回收站中的对象会占用存储空间，直到被彻底清除或存储空间不足。

```sql
-- 查看回收站内容
SELECT object_name, original_name, type, drop_time, space
FROM user_recyclebin;

-- 查看所有用户的回收站（需要相应权限）
SELECT * FROM dba_recyclebin;
```

### 恢复被删除的表

```sql
-- 1. 查看回收站中的表
SELECT original_name, object_name, drop_time
FROM user_recyclebin
WHERE type = 'TABLE';

-- 2. 恢复表（使用原始名称）
FLASHBACK TABLE employees TO BEFORE DROP;

-- 3. 如果原名称已被使用，可以重命名恢复
FLASHBACK TABLE "BIN$1234567890ABC$0" TO employees RESTORE AS employees_new;
```

### 管理回收站

```sql
-- 清空特定表的回收站
PURGE TABLE employees;

-- 清空当前用户的回收站
PURGE RECYCLEBIN;

-- 清空所有用户的回收站（需要 DBA 权限）
PURGE DBA_RECYCLEBIN;

-- 释放表空间
ALTER TABLE employees PURGE TABLESPACE users;
```

### 禁用回收站

如果不需要闪回删除功能，可以禁用回收站：

```sql
-- 设置回收站参数（需要 DBA 权限）
ALTER SYSTEM SET recyclebin = OFF SCOPE = SPFILE;

-- 重新启动数据库后生效
SHUTDOWN IMMEDIATE;
STARTUP;
```

## 闪回事务（Flashback Transaction）

闪回事务可以撤销某个特定事务及其所有相关事务的影响，或者生成撤销语句用于手动执行。

### 基本语法

```sql
-- 查看事务信息
SELECT xid, start_time, commit_time, operation
FROM v$transaction;

-- 查看事务的撤销 SQL
SELECT undo_sql
FROM flashback_transaction_report(
    table_name => 'EMPLOYEES',
    xid => '05001200340E0000'
);
```

### 闪回事务示例

```sql
-- 场景：某个误操作导致数据错误，需要撤销

-- 1. 查找问题事务
SELECT xid, undo_sql
FROM flashback_transaction_report(
    table_name => 'EMPLOYEES',
    start_time => TO_TIMESTAMP('2024-03-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    end_time => TO_TIMESTAMP('2024-03-15 15:00:00', 'YYYY-MM-DD HH24:MI:SS')
);

-- 2. 或者使用 UNDO_SQL 显示具体的撤销语句
SELECT UNDO_SQL FROM V$UNDOSTAT WHERE xid = '05001200340E0000';

-- 3. 执行闪回事务
FLASHBACK TABLE employees TO BEFORE SCN 1234567;
```

## 闪回前提条件与限制

### 前提条件

1. **Undo 表空间**：必须有足够的 undo 表空间存储历史数据
2. **Undo 保留时间**：undo 数据必须被保留足够长的时间
3. **权限**：需要 FLASHBACK ANY TABLE 权限或特定表的 FLASHBACK 权限

```sql
-- 查看 undo 表空间使用情况
SELECT tablespace_name, status, sum(bytes) / 1024 / 1024 as size_mb
FROM dba_undo_extents
GROUP BY tablespace_name, status;

-- 查看 undo 保留策略
SHOW PARAMETER undo_retention;
```

### 限制条件

- 闪回查询不能访问被覆盖的 undo 数据
- 闪回表不能用于恢复 DDL 操作（如 TRUNCATE）
- 闪回删除不能恢复包含 LOB 列的表（完整行为）
- 受限于 undo 表空间大小和保留时间

## 使用场景示例

### 场景1：误删除数据

```sql
-- 误执行 DELETE 但未提交
DELETE FROM employees WHERE department_id = 99;

-- 使用闪回查询确认数据
SELECT * FROM employees AS OF TIMESTAMP SYSDATE - INTERVAL '5' MINUTE
WHERE department_id = 99;

-- 闪回表到删除之前
FLASHBACK TABLE employees TO TIMESTAMP SYSDATE - INTERVAL '5' MINUTE;

-- 或者回滚事务
ROLLBACK;
```

### 场景2：批量误更新

```sql
-- 错误地更新了所有员工的工资
UPDATE employees SET salary = salary * 0.9;

-- 查看受影响的数据量
SELECT COUNT(*) FROM employees;

-- 闪回表到更新之前
FLASHBACK TABLE employees TO TIMESTAMP SYSDATE - INTERVAL '10' MINUTE;
```

### 场景3：恢复误删除的表

```sql
-- 误删除了表
DROP TABLE audit_log;

-- 从回收站恢复
FLASHBACK TABLE audit_log TO BEFORE DROP;

-- 如果表名已存在，创建新名称
FLASHBACK TABLE audit_log TO BEFORE DROP RENAME TO audit_log_restored;
```

### 场景4：数据审计

```sql
-- 查看某段时间内的所有数据变更
SELECT versions_xid, versions_operation, versions_starttime,
    employee_id, salary, department_id
FROM employees
    VERSIONS BETWEEN TIMESTAMP
        TO_DATE('2024-03-01', 'YYYY-MM-DD')
        AND TO_DATE('2024-03-31', 'YYYY-MM-DD')
WHERE employee_id = 1001;
```

---

### 参考

- [产品文档/概念手册/高可用/闪回.md](../../../产品文档/概念手册/高可用/闪回.md)
