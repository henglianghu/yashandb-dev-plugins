---
title: YashanDB 存储过程与函数
description: 存储过程、函数、触发器、事务控制、错误处理
tags: yashandb, stored-procedure, function, trigger, pl/sql, exception
---

# 存储过程与函数

> **参考文档**：产品文档/开发手册/PL参考手册/00PL参考手册.md

YashanDB 支持使用 PL/SQL 创建存储过程、函数和触发器，实现业务逻辑的服务器端执行。本文详细介绍这些对象的创建、使用和最佳实践。

**重要说明**：在 YashanDB 中，PL 相关功能不论在何种语法模式下均采用 yashan 语法进行解析。

## 存储过程

存储过程是一组预编译的 SQL 语句，可以接受参数、执行复杂操作并返回结果。

### 创建存储过程

```sql
-- 创建简单的存储过程
CREATE OR REPLACE PROCEDURE update_employee_salary(
    p_emp_id IN NUMBER,
    p_new_salary IN NUMBER
) AS
BEGIN
    UPDATE employees
    SET salary = p_new_salary,
        updated_at = SYSDATE
    WHERE employee_id = p_emp_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, '员工不存在: ' || p_emp_id);
    END IF;

    COMMIT;
END;
/
```

### 参数模式

```sql
-- 参数模式说明
CREATE OR REPLACE PROCEDURE proc_example (
    p_in IN NUMBER,        -- 仅输入参数
    p_out OUT NUMBER,      -- 仅输出参数
    p_in_out IN OUT VARCHAR2  -- 输入输出参数
) AS
BEGIN
    -- p_in：只读
    -- p_out：可赋值后输出
    -- p_in_out：读取后修改再输出
    p_out := p_in * 2;
    p_in_out := p_in_out || '_modified';
END;
/
```

### 调用存储过程

```sql
-- 使用 CALL 调用
CALL update_employee_salary(100, 15000);

-- 使用 EXEC 调用
EXEC update_employee_salary(100, 15000);

-- 在 PL/SQL 块中调用
BEGIN
    update_employee_salary(100, 15000);
END;
/
```

## 函数

函数与存储过程类似，但必须返回值。

### 创建函数

```sql
-- 创建返回单个值的函数
CREATE OR REPLACE FUNCTION get_employee_name(
    p_emp_id IN NUMBER
) RETURN VARCHAR2 AS
    v_name VARCHAR2(100);
BEGIN
    SELECT last_name || ' ' || first_name
    INTO v_name
    FROM employees
    WHERE employee_id = p_emp_id;

    RETURN v_name;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;
/

-- 在 SQL 中使用函数
SELECT employee_id, get_employee_name(employee_id) AS full_name
FROM employees;
```

### 创建表值函数

```sql
-- 创建返回结果集的函数
CREATE OR REPLACE FUNCTION get_employees_by_dept(
    p_dept_id IN NUMBER
) RETURN SYS_REFCURSOR AS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT employee_id, last_name, salary
        FROM employees
        WHERE department_id = p_dept_id;

    RETURN v_cursor;
END;
/
```

### 聚合函数

```sql
-- 创建自定义聚合函数（简化示例）
CREATE OR REPLACE FUNCTION concat_names(
    p_str1 IN VARCHAR2,
    p_str2 IN VARCHAR2
) RETURN VARCHAR2
DETERMINISTIC
AS
BEGIN
    RETURN p_str1 || ', ' || p_str2;
END;
/
```

## 触发器

触发器是在特定数据库事件发生时自动执行的代码块。

### DML 触发器

```sql
-- 创建行级触发器
CREATE OR REPLACE TRIGGER trg_emp_salary_change
BEFORE UPDATE OF salary ON employees
FOR EACH ROW
WHEN (NEW.salary <> OLD.salary)
DECLARE
    v_change NUMBER;
BEGIN
    v_change := :NEW.salary - :OLD.salary;

    INSERT INTO salary_history (
        employee_id, old_salary, new_salary, change_amount, change_date
    ) VALUES (
        :NEW.employee_id, :OLD.salary, :NEW.salary, v_change, SYSDATE
    );
END;
/

-- 创建语句级触发器
CREATE OR REPLACE TRIGGER trg_emp_delete
BEFORE DELETE ON employees
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM employees;
    IF v_count <= 5 THEN
        RAISE_APPLICATION_ERROR(-20001, '不能删除最后一个员工');
    END IF;
END;
/
```

### INSTEAD OF 触发器

```sql
-- 为视图创建 INSTEAD OF 触发器
CREATE OR REPLACE VIEW v_emp_dept AS
SELECT e.employee_id, e.last_name, d.department_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id;

CREATE OR REPLACE TRIGGER trg_v_emp_dept_insert
INSTEAD OF INSERT ON v_emp_dept
FOR EACH ROW
DECLARE
    v_dept_id NUMBER;
BEGIN
    -- 获取部门 ID
    SELECT department_id INTO v_dept_id
    FROM departments
    WHERE department_name = :NEW.department_name;

    -- 插入员工记录
    INSERT INTO employees (employee_id, last_name, department_id)
    VALUES (:NEW.employee_id, :NEW.last_name, v_dept_id);
END;
/
```

### 系统事件触发器

```sql
-- 创建登录触发器
CREATE OR REPLACE TRIGGER trg_after_logon
AFTER LOGON ON SCHEMA
BEGIN
    DBMS_OUTPUT.PUT_LINE('用户 ' || USER || ' 已登录');
END;
/

-- 创建 DDL 触发器
CREATE OR REPLACE TRIGGER trg_ddl_protect
BEFORE DROP ON SCHEMA
DECLARE
    v_object_name VARCHAR2(100);
BEGIN
    v_object_name := ORA_DICT_OBJ_NAME;
    IF ORA_DICT_OBJ_TYPE = 'TABLE' THEN
        RAISE_APPLICATION_ERROR(-20001, '禁止删除表: ' || v_object_name);
    END IF;
END;
/
```

## 事务控制

### 自主事务（AUTONOMOUS_TRANSACTION）

自主事务允许在存储过程中创建独立的事务，与主事务分离：

```sql
-- 创建自主事务的存储过程
CREATE OR REPLACE PROCEDURE log_operation(
    p_operation IN VARCHAR2,
    p_details IN VARCHAR2
) AS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO operation_logs (operation, details, log_time)
    VALUES (p_operation, p_details, SYSDATE);

    COMMIT;  -- 自主事务需要单独提交
END;
/

-- 主事务回滚不影响日志记录
BEGIN
    INSERT INTO temp_data VALUES (1);
    log_operation('INSERT', 'Inserted to temp_data');
    ROLLBACK;  -- temp_data 回滚，但日志已提交
END;
/
```

### 事务控制语句

```sql
-- 在存储过程中使用事务控制
CREATE OR REPLACE PROCEDURE transfer_funds(
    p_from_acc IN NUMBER,
    p_to_acc IN NUMBER,
    p_amount IN NUMBER
) AS
    v_balance NUMBER;
BEGIN
    -- 检查转出账户余额
    SELECT balance INTO v_balance FROM accounts WHERE account_id = p_from_acc;

    IF v_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20001, '余额不足');
    END IF;

    -- 扣款
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_acc;

    -- 收款
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to_acc;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
```

## 错误处理

### 异常类型

```sql
-- 预定义异常
DECLARE
    v_emp employees%ROWTYPE;
BEGIN
    SELECT * INTO v_emp FROM employees WHERE employee_id = 9999;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('未找到员工');
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('返回多行');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('错误: ' || SQLERRM);
END;
/
```

### 自定义异常

```sql
-- 声明和使用自定义异常
DECLARE
    e_insufficient_balance EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_insufficient_balance, -20001);
    v_balance NUMBER := 100;
BEGIN
    IF v_balance < 1000 THEN
        RAISE e_insufficient_balance;
    END IF;
EXCEPTION
    WHEN e_insufficient_balance THEN
        DBMS_OUTPUT.PUT_LINE('余额不足');
END;
/
```

### 错误码范围

| 错误码范围 | 说明 |
|-----------|------|
| -20000 ~ -20999 | 用户自定义错误码 |
| -1 ~ -20999 | 系统保留错误码 |

## 性能注意事项

### 批量处理

```sql
-- 使用 FORALL 和 BULK COLLECT 提高性能
CREATE OR REPLACE PROCEDURE batch_update_salary(
    p_emp_ids IN SYS.ODCINUMBERLIST,
    p_increase_rate IN NUMBER
) AS
BEGIN
    FORALL i IN 1..p_emp_ids.COUNT
        UPDATE employees
        SET salary = salary * (1 + p_increase_rate)
        WHERE employee_id = p_emp_ids(i);

    COMMIT;
END;
/

-- 调用批量处理
DECLARE
    v_ids SYS.ODCINUMBERLIST;
BEGIN
    v_ids := SYS.ODCINUMBERLIST(100, 101, 102, 103, 104);
    batch_update_salary(v_ids, 0.1);
END;
/
```

### 绑定变量

```sql
-- 使用绑定变量提高执行效率
CREATE OR REPLACE PROCEDURE find_employee(
    p_emp_id IN NUMBER
) AS
    v_name VARCHAR2(100);
BEGIN
    EXECUTE IMMEDIATE
        'SELECT last_name FROM employees WHERE employee_id = :1'
        INTO v_name
        USING p_emp_id;

    DBMS_OUTPUT.PUT_LINE('员工姓名: ' || v_name);
END;
/
```

### 递归优化

```sql
-- 使用递归 CTE 而非递归存储过程（更高效）
WITH RECURSIVE dept_tree AS (
    SELECT department_id, department_name, manager_id, 1 AS level
    FROM departments
    WHERE manager_id IS NULL

    UNION ALL

    SELECT d.department_id, d.department_name, d.manager_id, dt.level + 1
    FROM departments d
    JOIN dept_tree dt ON d.manager_id = dt.department_id
)
SELECT * FROM dept_tree;
```

## 与 Oracle PL/SQL 的差异

### 不支持的特性

1. **包（PACKAGE）**：YashanDB 不支持 Oracle 的包对象
2. **对象类型（OBJECT TYPE）**：不支持用户定义的对象类型
3. **管道表函数**：有限支持
4. **多态表函数**：不支持

### 语法差异

```sql
-- YashanDB 中可用的替代方案
-- 替代包：使用独立的存储过程和函数
-- 替代包变量：使用全局临时表或配置表

-- 变量声明
DECLARE
    v_counter INTEGER := 0;  -- 与 Oracle 相同
BEGIN
    NULL;
END;
/
```

### 代码迁移建议

1. **移除包封装**：将包中的过程和函数拆分为独立对象
2. **使用临时表替代包变量**：使用全局临时表存储包级变量
3. **测试所有触发器**：确保触发器行为一致

---

### 参考

- [产品文档/开发手册/PL参考手册/00PL参考手册.md](../../../产品文档/开发手册/PL参考手册/00PL参考手册.md)
