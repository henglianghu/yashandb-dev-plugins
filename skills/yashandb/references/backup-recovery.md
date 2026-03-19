---
title: YashanDB 备份与恢复
description: 全量备份、增量备份、归档备份、备份恢复操作及最佳实践
tags: yashandb, backup, recovery, pitr, incremental-backup, full-backup, tablespace-backup, yasrman
---

# 备份与恢复

> **参考文档**：产品文档/数据库管理/备份与恢复/00备份与恢复.md

备份与恢复是数据库运维中最关键的环节之一。YashanDB 提供了多种备份恢复方案，以满足不同业务场景的需求。本文档将详细介绍各种备份恢复方法及其最佳实践。

## 备份恢复方式概述

YashanDB 支持两种备份恢复方式：

| 备份恢复方式 | 适用场景 |
|-------------|----------|
| SQL 语句备份恢复 | 单机/共享集群/分布式集群部署 |
| yasrman 工具备份恢复 | 所有部署形态（单机/共享集群/分布式集群/存算一体分布式集群） |

**说明**：
- 单机/共享集群/分布式集群部署时，可以使用 SQL 语句或 yasrman 工具进行备份恢复
- 存算一体分布式集群部署时只能采用 yasrman 工具进行备份恢复

## 备份类型概述

YashanDB 支持以下备份类型：

| 备份类型 | 说明 |
|----------|------|
| 全量备份 (FULL) | 对某一时间点上的所有数据进行完全复制，不依赖之前的备份集 |
| 增量备份 (INCREMENTAL) | 首次执行基线备份（LEVEL 0），后续每次只需备份增量数据（LEVEL 1） |
| 归档备份 (ARCHIVELOG) | 对当前正常运行的数据库产生的归档日志文件进行完全复制 |
| 压缩备份 | 通过 COMPRESSION 关键字指定备份集压缩策略 |
| 加密备份 | 通过 ENCRYPTION 关键字指定备份集加密策略 |

## 使用 SQL 语句备份恢复

通过 SQL 语句执行备份恢复操作适用于单机/共享集群/分布式集群部署的数据库。

### 备份数据库

#### 全量备份

```sql
-- 全量备份（单机、共享集群/分布式集群部署）
BACKUP DATABASE FULL FORMAT '/data/backup/full_20211209191000' TAG 'yas_full_backup' PARALLELISM 3;
```

#### 增量备份

```sql
-- LEVEL 0 基线备份
BACKUP DATABASE INCREMENTAL LEVEL 0 FORMAT '/data/backup/incr_0_20211209193516';

-- LEVEL 1 增量备份
BACKUP DATABASE INCREMENTAL LEVEL 1 FORMAT '/data/backup/incr_1_20211209193740';
```

#### 基于 TAG 的增量备份

```sql
-- 生成独立增量备份链路的 LEVEL 0 备份集
BACKUP DATABASE INCREMENTAL LEVEL 0 FORMAT '/data/backup/base_incr_0_20211209193516' TAG 'base_incr_0' INDEPEND;

-- 基于指定的 TAG 执行增量备份
BACKUP DATABASE INCREMENTAL LEVEL 1 FORMAT '/data/backup/base_incr_1_20211209193516' TAG 'base_incr_1' BASE ON 'base_incr_0';
```

#### 压缩备份

```sql
-- 压缩备份（算法：ZSTD/LZ4，级别：HIGH/MEDIUM/LOW）
BACKUP DATABASE COMPRESSION ALGORITHM ZSTD LOW;
```

#### 加密备份

```sql
-- 加密备份（算法：AES128/AES192/AES256/SM4）
BACKUP DATABASE ENCRYPTION AES256 IDENTIFIED BY yas2022;
```

### 备份归档日志

```sql
-- 全备份
BACKUP ARCHIVELOG ALL FORMAT '/data/backup/all_20211209191000' TAG 'yas_allarchive_backup';

-- 基于 SCN 备份
BACKUP ARCHIVELOG FROM SCN 505411989407080448 FORMAT '/data/backup/scn_20211209191000';

-- 基于 SEQUENCE 备份
BACKUP ARCHIVELOG UNTIL SEQUENCE 9 FORMAT '/data/backup/seq_20211209191000';

-- 基于时间备份
BACKUP ARCHIVELOG UNTIL TIME TO_DATE('2024-10-28 08:14:01','yyyy-mm-dd hh24:mi:ss') FORMAT '/data/backup/time_20211209191000';

-- 压缩归档备份
BACKUP ARCHIVELOG ALL COMPRESSION;

-- 加密归档备份
BACKUP ARCHIVELOG ALL ENCRYPTION IDENTIFIED BY 12345;
```

### 恢复数据库

#### 完整恢复

完整恢复是指将全库备份集中的备份文件恢复到数据库目录，然后回放归档日志将数据库恢复到一致性状态。

```sql
-- 1. 在 NOMOUNT 阶段执行 RESTORE DATABASE（执行完成后数据库会启动至 MOUNT 阶段）
RESTORE DATABASE FROM '/data/backup/full_20211209191000' PARALLELISM 6;

-- 基于加密的备份集恢复需指定 DECRYPTION 关键字
RESTORE DATABASE DECRYPTION yas2022 FROM '/data/backup/bak_20211209191100';

-- 2. 执行 RECOVER DATABASE（归档日志和在线日志连续且完整时，YashanDB 将自动应用所有日志）
RECOVER DATABASE;

-- 3. 打开数据库
ALTER DATABASE OPEN;
```

#### 基于增量备份集的连续恢复

```sql
-- 1. 在 NOMOUNT 阶段执行 RESTORE DATABASE
-- 首次基于增量备份集恢复必须恢复 LEVEL 0 的备份集，指定 INCREMENTAL NOREDO 参数可加快恢复速度
RESTORE DATABASE INCREMENTAL NOREDO FROM '/data/backup/incr_0_20211209193516';

-- 2. 连续恢复同一数据库的增量备份集（最后一次恢复时不可指定 INCREMENTAL NOREDO）
RESTORE DATABASE INCREMENTAL FROM '/data/backup/incr_1_20211209193740';

-- 3. 启动数据库至 MOUNT 阶段执行 RECOVER DATABASE
ALTER DATABASE MOUNT;
RECOVER DATABASE;

-- 4. 启动数据库至 OPEN 阶段
ALTER DATABASE OPEN;
```

### 归档恢复

归档恢复是指在 RESTORE DATABASE 后、RECOVER DATABASE 前，将归档备份集中的文件恢复到数据库的归档目录。

```sql
-- 全恢复
RESTORE ARCHIVELOG ALL FROM BACKUPSET '/data/backup/all_20211209191000';

-- 基于 SCN 恢复
RESTORE ARCHIVELOG FROM SCN 505411989407080448 FROM BACKUPSET '/data/backup/scn_20211209191000';

-- 基于 SEQUENCE 恢复
RESTORE ARCHIVELOG UNTIL SEQUENCE 10 FROM BACKUPSET '/data/backup/seq_20211209191000';

-- 基于时间恢复
RESTORE ARCHIVELOG UNTIL TIME TO_DATE('2024-10-28 08:14:01','yyyy-mm-dd hh24:mi:ss') FROM BACKUPSET '/data/backup/time_20211209191000';
```

### 基于时间点恢复 (PITR)

基于时间点的恢复（PITR）是指基于数据库备份集还原的数据库文件和归档日志文件将数据库恢复到备份时间点至最新时间点期间某一时刻的状态。

```sql
-- 1. 基于数据库备份集恢复数据库文件
RESTORE DATABASE FROM '/data/backup/full_20211209191000';

-- 2. 基于归档日志备份集恢复归档日志文件
RESTORE ARCHIVELOG ALL FROM BACKUPSET '/data/backup/all_20211209191000';

-- 3. 基于数据库文件和归档日志恢复数据库到指定时间点
-- 方案一：指定时间点
RECOVER DATABASE UNTIL TIME TO_DATE('2021-12-09 19:35:55','yyyy-mm-dd hh24:mi:ss');

-- 方案二：指定 SCN
SELECT CURRENT_SCN FROM V$DATABASE;
RECOVER DATABASE UNTIL SCN 258477020237086720;

-- 4. 重置 redo 时间线并打开数据库
ALTER DATABASE OPEN RESETLOGS;
```

## 使用 yasrman 工具备份恢复

yasrman 是 YashanDB 提供的备份恢复工具，适用于所有部署形态。

### 备份全库

```shell
# 单机/共享集群/分布式集群部署 - 全量备份
$ yasrman sys/********@192.168.1.2:1688 \
-c "BACKUP DATABASE TAG 'full_backup' FULL FORMAT 'full_001' PARALLELISM 3 DEST SERVER" \
-D /home/yashan/catalog

# 存算一体分布式集群部署 - 全量备份
$ yasrman sys/********@192.168.1.2:1688 \
-c "BACKUP CLUSTER TAG 'full_backup' FULL FORMAT 'full_001' PARALLELISM 3" \
-D /home/yashan/catalog
```

### 增量备份

```shell
# 单机/共享集群/分布式集群部署 - LEVEL 0
$ yasrman sys/********@192.168.1.2:1688 \
-c "BACKUP DATABASE TAG 'incr_0_backup' INCREMENTAL LEVEL 0 FORMAT 'incr_0_002'" \
-D /home/yashan/catalog

# 单机/共享集群/分布式集群部署 - LEVEL 1
$ yasrman sys/********@192.168.1.2:1688 \
-c "BACKUP DATABASE TAG 'incr_1_backup' INCREMENTAL LEVEL 1 FORMAT 'incr_1_002'" \
-D /home/yashan/catalog
```

### 备份表空间

表空间备份仅适用于单机部署。

```shell
$ yasrman sys/********@192.168.1.2:1688 \
-c "backup tablespace users tag 'user_bak'" \
-D /home/yashan/catalog
```

### 备份归档日志

```shell
$ yasrman sys/********@192.168.1.2:1688 \
-c "BACKUP ARCHIVELOG TIME BETWEEN '2023-10-28 08:14:01' AND '2023-11-28 11:14:01' FORMAT 'TIMERANGE' TAG 'TIMERANGE' COMPRESSION" \
-D /home/yashan/catalog
```

### 压缩备份

```shell
# 单机/共享集群/分布式集群部署
$ yasrman sys/********@192.168.1.2:1688 \
-c "BACKUP DATABASE TAG 'full_compress' COMPRESSION ALGORITHM ZSTD LOW" \
-D /home/yashan/catalog
```

### 加密备份

```shell
# 单机/共享集群/分布式集群部署
$ yasrman sys/********@192.168.1.2:1688 \
-c "BACKUP DATABASE TAG 'full_encryption' ENCRYPTION AES256 IDENTIFIED BY yas2022" \
-D /home/yashan/catalog
```

### 恢复整库

```shell
# 完整恢复（单机/共享集群/分布式集群部署）
$ yasrman sys/********@192.168.1.2:1688 \
-c "restore database from tag 'full_1'" \
-D /home/yashan/catalog

# 完整恢复（存算一体分布式集群部署）
$ yasrman sys/********@192.168.1.2:1688 \
-c "restore cluster from tag 'full_1'" \
-D /home/yashan/catalog

# 基于时间点恢复
$ yasrman sys/********@192.168.1.2:1688 \
-c "restore database from tag 'full_1' until time '2023-11-13'" \
-D /home/yashan/catalog

# 基于 SCN 恢复
$ yasrman sys/********@192.168.1.2:1688 \
-c "restore database from tag 'full_1' until scn 499833430256541696" \
-D /home/yashan/catalog
```

### 表空间恢复

表空间恢复仅适用于单机部署。

```shell
-- 1. 执行 RESTORE TABLESPACE
$ yasrman sys/********@192.168.1.2:1688 \
-c "restore tablespace spc_test from tag 'spc_test_bak'" \
-D /home/yashan/catalog

-- 2. 执行 RECOVER TABLESPACE
$ yasrman sys/********@192.168.1.2:1688 \
-c "recover tablespace spc_test maxsize 1280M" \
-D /home/yashan/catalog
```

### 归档恢复

```shell
$ yasrman sys/********@192.168.1.2:1688 \
-c "restore archivelog all" \
-D /home/yashan/catalog

$ yasrman sys/********@192.168.1.2:1688 \
-c "restore archivelog sequence between 10 and 20" \
-D /home/yashan/catalog
```

## 备份策略设计

根据业务需求设计合理的备份策略：

| 备份级别 | 频率 | 保留时间 | 说明 |
|----------|------|----------|------|
| Level 0 | 每周一次 | 30 天 | 完整基准备份 |
| Level 1 | 每天一次 | 7 天 | 增量备份 |
| 归档日志 | 每小时 | 24 小时 | 持续备份 |

### 增量备份使用规则

增量备份需遵循如下使用规则：

1. 同一个增量备份链路中，连续 LEVEL 1 增量备份次数不得超过 1000 次
2. 同一个增量备份链路中的多个备份集允许采用不同的压缩策略
3. 同一个增量备份链路中的多个备份集必须采用一致的加密策略（都加密或都不加密，都加密时密码相同），但可以采用不同的加密算法
4. 恢复时需要依次恢复基线备份集、增量备份集

## 备份监控

```sql
-- 查看备份任务状态
SELECT
    session_key,
    operation,
    start_time,
    end_time,
    status,
    input_bytes,
    output_bytes
FROM v$rman_backup_job_details
ORDER BY start_time DESC;

-- 查看备份文件信息
SELECT
    backup_type,
    file_type,
    file_name,
    bytes,
    completion_time
FROM v$backup_files
WHERE backup_type = 'BACKUP'
ORDER BY completion_time DESC;

-- 查看备份进度
SELECT * FROM v$backup_progress;

-- 查看归档日志信息
SELECT * FROM v$archived_log;
```

## 备份恢复的最佳实践

### 备份前准备

1. **归档模式**：数据库实例需处于 OPEN 阶段且已开启归档模式
2. **创建 catalog 路径**：用于记录备份元数据
3. **确保磁盘空间充足**：自定义备份路径时需确保路径为空且磁盘空间充足
4. **备份加密对象**：如需备份加密对象，需先手动备份密钥钱包文件

### 操作限制

- 备份操作仅 SYS 超级用户或拥有 SYSDBA、SYSBACKUP 权限的用户可执行
- 备份数据库不允许和表空间、redo 文件等数据文件的增删、resize 操作并发
- 共享集群/分布式集群部署中，同一时间只能在一个实例上执行备份操作

### 恢复前准备

1. 数据库实例需处于 NOMOUNT 阶段
2. 需手动清理已有数据文件
3. 如备份集采用加密备份，恢复时需指定解密密码

### 存储最佳实践

1. **多副本存储**：将备份存储在多个位置，防止单点故障
2. **离线存储**：将长期备份离线存储，防范勒索软件
3. **加密备份**：对敏感数据进行加密备份
4. **定期清理**：及时清理过期备份，释放存储空间

### 并发度设置

备份和恢复过程中，可通过 PARALLELISM 参数设置并发度来提高效率，默认值为 2。

---

### 参考

- [产品文档/数据库管理/备份与恢复/00备份与恢复.md](../../../产品文档/数据库管理/备份与恢复/00备份与恢复.md)
- [产品文档/数据库管理/备份与恢复/SQL语句备份恢复/备份.md](../../../产品文档/数据库管理/备份与恢复/SQL语句备份恢复/备份.md)
- [产品文档/数据库管理/备份与恢复/SQL语句备份恢复/恢复.md](../../../产品文档/数据库管理/备份与恢复/SQL语句备份恢复/恢复.md)
- [产品文档/数据库管理/备份与恢复/yasrman工具备份恢复/备份.md](../../../产品文档/数据库管理/备份与恢复/yasrman工具备份恢复/备份.md)
- [产品文档/数据库管理/备份与恢复/yasrman工具备份恢复/恢复.md](../../../产品文档/数据库管理/备份与恢复/yasrman工具备份恢复/恢复.md)
