---
title: YashanDB 在线 DDL
description: 在线索引创建、列类型变更、DDL与并发事务的交互及最佳实践
tags: yashandb, ddl, online-ddl, alter-table, index-creation, locking
---

# 在线 DDL

> **参考文档**：产品文档/开发手册/SQL参考手册/SQL语句/ALTER TABLE.md

在线 DDL 是 YashanDB 提供的关键功能，允许在表上进行 schema 变更操作时，不阻塞并发的事务 DML（INSERT、UPDATE、DELETE）操作。正确理解和使用在线 DDL 功能，对于保障生产环境业务连续性至关重要。

## 在线索引创建

在线索引创建允许在不影响业务的情况下为表添加新的索引。YashanDB 的在线索引创建采用两阶段方式：首先创建索引结构，然后逐步填充数据，整个过程对业务透明。

### 基本语法

```sql
-- 创建在线索引
CREATE INDEX idx_emp_name ON employees (last_name, first_name) ONLINE;

-- 创建唯一索引
CREATE UNIQUE INDEX idx_emp_email ON employees (email) ONLINE;

-- 创建组合索引
CREATE INDEX idx_orders_user_date ON orders (user_id, order_date) ONLINE;
```

### 在线索引创建的工作原理

在线索引创建分为以下阶段：

1. **准备阶段**：验证索引定义的合法性，检查表是否存在
2. **索引定义阶段**：在系统表 中记录索引元数据，此时索引尚不可用
3. **数据填充阶段**：遍历表数据，构建索引键值并写入索引
4. **索引生效阶段**：完成索引构建，将其状态设置为可用

在数据填充阶段，系统会记录表的增量变更（DML 操作），并在索引完成后将这些变更合并到索引中，确保索引数据的完整性。

### 注意事项

- 在线索引创建会占用额外的存储空间，因为在索引构建期间需要维护临时数据
- 建议在业务低峰期执行大量索引的创建操作，以减少对系统的压力
- 如果表正在执行其他 DDL 操作，在线索引创建可能会被阻塞

## 列类型变更

YashanDB 支持在线进行列类型变更，但具体行为取决于变更的类型和数据库版本。

### MODIFY 操作

```sql
-- 扩大列长度
ALTER TABLE employees MODIFY (email VARCHAR2(200));

-- 缩小列长度（需要确保现有数据符合新长度）
ALTER TABLE employees MODIFY (phone VARCHAR2(20));

-- 变更数据类型（需要确保兼容）
ALTER TABLE orders MODIFY (total_amount NUMBER(15, 2));

-- 设置默认值
ALTER TABLE products MODIFY (status VARCHAR2(20) DEFAULT 'ACTIVE');

-- 删除默认值
ALTER TABLE employees MODIFY (owner DEFAULT NULL);

-- 允许/禁止 NULL 值
ALTER TABLE employees MODIFY (department_id NUMBER(10) NOT NULL);

-- 修改多个列字段
ALTER TABLE branches MODIFY (branch_no CHAR(10), branch_name VARCHAR2(100));
```

### 数据类型修改规则

LSC 表不允许修改列字段的数据类型。HEAP 表和 TAC 表列字段数据类型修改规则如下：

**外键约束所在列**：不允许修改子表和父表中相应列的数据类型。

**虚拟列依赖的数据列**：不允许修改数据类型，修改将返回错误提示。

**索引所在列**：
- 若为空表（即无数据），允许将其修改为除 LOB/JSON/UDT 外的其他数据类型
- 若为非空表，则不允许修改其数据类型

**使用字典编码的列（仅适用于 TAC 表）**：仅允许将其修改为字符型

**变长存储的字符型列（仅适用于 TAC 表）**：不允许在数据库进行回滚时修改其数据类型

**分区键、函数索引或 AC 所在列**：不允许修改其数据类型

**原数据类型为 LOB/JSON/UDT 的列**：不允许修改其数据类型

**原数据类型为字符型的其他空列**：允许将其修改为除 LOB/JSON/UDT 外的其他数据类型

**原数据类型为字符型的其他非空列**：
- 不允许 CHAR/VARCHAR 与 NCHAR/NVARCHAR 交叉修改
- 当按长度属性从大向小修改时，必须保证该列现有数据的长度均未超过目标数据类型的上限
- HEAP 表不允许跨存储方式修改数据类型

**原数据类型为其他数据类型的其他非空列**：
- 不允许跨大类修改数据类型，例如不允许将数值型修改为字符型
- 同一数据大类中，除字符型外其他类型只允许按值域、精度、长度等属性从小向大修改

### 约束修改限制条件

#### modify NULL/NOT NULL

- 不允许对未定义 NOT NULL 约束项的列字段执行 modify NULL
- 不允许对已定义 NOT NULL 约束项的列字段执行 modify NOT NULL
- 不允许对已存在 NULL 数据的列字段执行 modify NOT NULL
- 不允许对已定义 ON DELETE SET NULL 或 ON UPDATE SET NULL 外键的列字段执行 modify NOT NULL

#### modify UNIQUE

- 不允许对已定义 UNIQUE 约束项的列字段执行 modify UNIQUE
- 不允许对已存在重复数据的列字段执行 modify UNIQUE
- 不允许对多个列字段同时执行 modify UNIQUE

#### modify PRIMARY KEY

- 不允许对已有主键的表执行任意列字段的 modify PRIMARY KEY
- 不允许对已定义 UNIQUE 约束项的列字段执行 modify PRIMARY KEY
- 不允许对不符合创建主键要求的列字段执行 modify PRIMARY KEY

#### modify CHECK

- 如新的 CHECK 与表中现有其他的 CHECK 冲突，无法执行修改
- 如表中现有的数据不符合 CHECK，无法执行修改

#### modify FOREIGN KEY

- 不允许对不符合创建外键要求的列字段执行 modify FOREIGN KEY

## DDL 与并发事务的交互

在线 DDL 设计上允许与并发 DML 操作共存，但两者之间存在复杂的交互关系。

### 元数据锁

DDL 操作需要获取表的元数据锁（MDL），用于保护表结构的变更。元数据锁有以下几种级别：

| 锁类型 | 说明 | 允许的并发操作 |
|--------|------|---------------|
| SHARED_READ | 允许读操作，阻塞写操作 | 读 |
| SHARED_WRITE | 允许读写，阻塞结构变更 | 读写 |
| EXCLUSIVE | 独占锁，完全阻塞所有操作 | 无 |

### DDL 执行期间的 DML 行为

```sql
-- 会话1：开始一个长事务
START TRANSACTION;
UPDATE employees SET salary = salary * 1.1 WHERE department_id = 10;
-- 不提交，保持事务打开

-- 会话2：尝试执行 DDL（会被阻塞，等待会话1的事务结束）
ALTER TABLE employees ADD COLUMN new_column VARCHAR2(50);

-- 会话3：尝试 DML（可能成功，取决于 DDL 阶段）
INSERT INTO employees (employee_id, last_name) VALUES (1000, 'Smith');
```

### 事务边界的重要性

执行 DDL 操作前，应确保没有长时间运行的事务。原因如下：

1. DDL 需要获取排他锁来修改表结构
2. 长时间运行的事务会持有共享锁，阻止 DDL 获取排他锁
3. DDL 操作本身会触发隐式提交，在 DDL 之前提交所有未提交的事务

## 在线 DDL 的限制

虽然在线 DDL 提供了很大的灵活性，但存在以下限制：

### 不支持在线操作的场景

- 修改主键列
- 修改分区键列
- 对有外键约束的表进行某些操作
- 修改列的顺序
- 某些涉及 LOB 列的操作

### 资源限制

- 在线 DDL 会占用额外的 CPU、内存和磁盘 I/O 资源
- 在系统资源紧张时，在线 DDL 可能会被取消或失败
- 建议在系统负载较低时执行在线 DDL 操作

### 并发限制

- 同时执行的在线 DDL 数量有限制
- 多个在线 DDL 操作同一表时会串行执行

## DDL 执行期间的锁行为

理解 DDL 执行期间的锁行为对于避免生产环境问题至关重要。

### 锁获取阶段

```sql
-- 典型的 DDL 锁获取顺序
-- 1. 尝试获取 SHARED 锁（检查是否可访问）
-- 2. 等待所有并发事务结束
-- 3. 升级为 EXCLUSIVE 锁
-- 4. 执行 DDL 操作
-- 5. 释放锁
```

### 监控锁等待

```sql
-- 查看当前会话的锁等待情况
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.status,
    l.lock_type,
    l.mode_held,
    l.mode_requested,
    o.object_name,
    l.wait_time
FROM v$session s
JOIN v$lock l ON s.sid = l.sid
JOIN user_objects o ON l.id1 = o.object_id
WHERE s.username = 'YOUR_SCHEMA';
```

### 处理锁等待

如果 DDL 操作因锁等待而停滞，可以：

1. **等待事务自动提交**：最安全的做法
2. **识别并终止阻塞事务**：
   ```sql
   -- 查看阻塞的会话
   SELECT * FROM v$session WHERE sid IN (
       SELECT blocking_session FROM v$session WHERE state = 'WAITING'
   );

   -- 终止阻塞会话（谨慎使用）
   ALTER SYSTEM KILL SESSION 'sid,serial#';
   ```

## 最佳实践与注意事项

### 执行前准备

```sql
-- 1. 检查表的基本信息
SELECT num_rows, blocks, last_analyzed
FROM user_tables
WHERE table_name = 'EMPLOYEES';

-- 2. 检查是否有长时间运行的事务
SELECT sid, serial#, username, status, start_time
FROM v$session
WHERE status = 'ACTIVE' AND username = 'YOUR_SCHEMA';

-- 3. 检查当前的锁情况
SELECT * FROM v$locked_object;

-- 4. 估算操作所需时间（基于表大小和系统负载）
```

### 操作原则

1. **选择低峰期执行**：尽量在业务低峰期执行 DDL 操作
2. **小批量操作**：对于大表，考虑分批处理或使用在线工具
3. **预留回滚方案**：准备回滚脚本或数据备份
4. **监控执行进度**：关注系统资源和锁等待情况

### 推荐的操作顺序

```sql
-- 1. 执行前确认
SET TRANSACTION READ ONLY;

-- 2. 开始 DDL（某些操作可在线执行）
ALTER TABLE employees ADD COLUMN manager_id NUMBER(10);

-- 3. 验证结果
DESC employees;
SELECT * FROM employees WHERE ROWNUM <= 1;

-- 4. 创建相关索引
CREATE INDEX idx_emp_manager ON employees (manager_id) ONLINE;
```

### 常见问题处理

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| DDL 被长时间阻塞 | 有长时间运行的事务 | 等待事务结束或终止阻塞事务 |
| 索引创建失败 | 磁盘空间不足 | 清理空间后重试 |
| DDL 执行缓慢 | 系统负载高 | 在低峰期重试 |
| 锁死锁 | 并发 DDL | 串行化 DDL 操作 |

---

### 参考

- [ALTER TABLE - 产品文档/开发手册/SQL参考手册/SQL语句/ALTER TABLE.md](file:///home/yangdeliu/gitlab/dbdoc/doc/产品文档/开发手册/SQL参考手册/SQL语句/ALTER TABLE.md)
