---
title: YashanDB Oracle 兼容性
description: SQL 语法兼容、数据类型兼容、PL/SQL 兼容
tags: yashandb, oracle-compatibility, sql-compatibility, pl/sql
---

# Oracle 兼容性

> **参考文档**：产品文档/产品描述/兼容性说明/与Oracle兼容性说明.md

YashanDB 提供 Oracle 兼容语法，使得从 Oracle 迁移到 YashanDB 的应用能够最小化代码修改。本文详细介绍各项兼容性特性及使用注意事项。

## SQL 语法兼容

### DECODE 函数

```sql
-- DECODE 语法（与 Oracle 完全兼容）
SELECT
    deptno,
    DECODE(deptno, 10, '财务部', 20, '研发部', 30, '市场部', '其他部门') AS dept_name
FROM emp;

-- 多值匹配
SELECT DECODE(status, 'A', '活跃', 'I', '非活跃', '未知') FROM orders;
```

### NVL 和 NVL2 函数

```sql
-- NVL：如果值为 NULL 则返回替代值
SELECT NVL(comm, 0) FROM emp;

-- NVL2：如果第一个值不为 NULL 返回第二个值，否则返回第三个值
SELECT NVL2(comm, comm + 100, 0) FROM emp;

-- COALESCE：返回第一个非 NULL 值（Oracle 也支持）
SELECT COALESCE(phone_mobile, phone_home, phone_work, '未登记') FROM customers;
```

### CONNECT BY 层级查询

```sql
-- 递归查询组织结构
SELECT employee_id, last_name, manager_id, LEVEL
FROM employees
START WITH manager_id IS NULL
CONNECT BY PRIOR employee_id = manager_id
ORDER BY LEVEL;

-- 限制递归深度
SELECT employee_id, last_name, LEVEL
FROM employees
START WITH employee_id = 100
CONNECT BY PRIOR employee_id = manager_id
AND LEVEL <= 3;

-- SYS_CONNECT_BY_PATH 获取路径
SELECT employee_id, SYS_CONNECT_BY_PATH(last_name, '/') AS path
FROM employees
START WITH manager_id IS NULL
CONNECT BY PRIOR employee_id = manager_id;
```

### LIMIT 和 OFFSET 分页

```sql
-- MySQL/PostgreSQL 风格的分页（Oracle 兼容模式下也支持）
SELECT * FROM orders
ORDER BY order_date DESC
LIMIT 10 OFFSET 20;

-- Oracle 风格的 ROWNUM（始终支持）
SELECT * FROM (
    SELECT ROWNUM AS rn, t.* FROM (
        SELECT * FROM orders ORDER BY order_date DESC
    ) t WHERE ROWNUM <= 30
) WHERE rn > 20;

-- Oracle 12c+ 风格的 FETCH（始终支持）
SELECT * FROM orders
ORDER BY order_date DESC
OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY;
```

### 其他兼容语法

```sql
-- 序列（Oracle 风格）
CREATE SEQUENCE seq_order_id
    START WITH 1000
    INCREMENT BY 1
    MAXVALUE 999999999
    NOCYCLE;

-- 使用序列
INSERT INTO orders (order_id, order_date) VALUES (seq_order_id.NEXTVAL, SYSDATE);
SELECT seq_order_id.CURRVAL FROM DUAL;

-- 伪列 ROWNUM
SELECT ROWNUM, ename FROM emp WHERE ROWNUM <= 10;

-- 伪列 ROWID（物理行地址）
SELECT ROWID, ename FROM emp;
```

## 数据类型兼容

### VARCHAR2 类型

```sql
-- VARCHAR2 是 Oracle 标准的变长字符串类型
CREATE TABLE products (
    product_id BIGINT PRIMARY KEY,
    product_name VARCHAR2(100),
    description VARCHAR2(2000),
    price NUMBER(10, 2)
);
```

### NUMBER 类型

```sql
-- NUMBER 与 Oracle 完全兼容
col number(10)         -- 10 位整数
col number(10, 2)     -- 10 位数字，2 位小数
col number(*)         -- 变长浮点数
```

### ROWID 类型

```sql
-- ROWID 用于访问特定的物理行
SELECT ROWID, ename FROM emp WHERE empno = 7369;

-- 通过 ROWID 更新行
UPDATE emp SET sal = sal * 1.1 WHERE ROWID = 'AAAR3sAABAAAVQjAAA';
```

### 日期类型

```sql
-- DATE 类型存储日期和时间
CREATE TABLE orders (
    order_id BIGINT PRIMARY KEY,
    order_date DATE,
    shipped_date DATE
);

-- TIMESTAMP 高精度时间戳
CREATE TABLE events (
    event_id BIGINT PRIMARY KEY,
    event_time TIMESTAMP(9)
);
```

## 系统函数兼容

### 字符串函数

```sql
-- LENGTH（字符长度，支持多字节）
SELECT LENGTH('中国') FROM DUAL;  -- 返回 2

-- SUBSTR（ substring）
SELECT SUBSTR('Hello World', 1, 5) FROM DUAL;  -- 返回 Hello
SELECT SUBSTR('Hello World', -5) FROM DUAL;   -- 返回 World

-- INSTR（查找位置）
SELECT INSTR('Hello World', 'o') FROM DUAL;   -- 返回 5

-- LPAD/RPAD（填充）
SELECT LPAD('abc', 10, '*') FROM DUAL;  -- 返回 *******abc
```

### 数值函数

```sql
-- ROUND（四舍五入）
SELECT ROUND(123.456, 2) FROM DUAL;  -- 返回 123.46

-- TRUNC（截断）
SELECT TRUNC(123.456, 2) FROM DUAL;  -- 返回 123.45

-- MOD（取模）
SELECT MOD(10, 3) FROM DUAL;  -- 返回 1
```

### 日期函数

```sql
-- ADD_MONTHS
SELECT ADD_MONTHS(SYSDATE, 6) FROM DUAL;

-- MONTHS_BETWEEN
SELECT MONTHS_BETWEEN(SYSDATE, TO_DATE('2024-01-01', 'YYYY-MM-DD')) FROM DUAL;

-- LAST_DAY
SELECT LAST_DAY(SYSDATE) FROM DUAL;

-- NEXT_DAY
SELECT NEXT_DAY(SYSDATE, '星期一') FROM DUAL;
```

## PL/SQL 兼容

YashanDB 兼容了 Oracle 数据库大部分的 PL 功能，包括：

### 数据类型与子类型

```sql
-- 使用 SUBTYPE 定义子类型
DECLARE
    SUBTYPE name_type IS VARCHAR2(50);
    v_name name_type := '张三';
BEGIN
    DBMS_OUTPUT.PUT_LINE('姓名: ' || v_name);
END;
/
```

### 流程控制

```sql
-- 条件判断
IF v_sal > 10000 THEN
    DBMS_OUTPUT.PUT_LINE('高收入');
ELSIF v_sal > 5000 THEN
    DBMS_OUTPUT.PUT_LINE('中等收入');
ELSE
    DBMS_OUTPUT.PUT_LINE('低收入');
END IF;

-- 循环
FOR i IN 1..10 LOOP
    DBMS_OUTPUT.PUT_LINE(i);
END LOOP;
```

### 存储过程

```sql
-- 创建存储过程（Oracle PL/SQL 语法）
CREATE OR REPLACE PROCEDURE update_salary(
    p_emp_id IN NUMBER,
    p_raise IN NUMBER
) AS
    v_new_sal NUMBER;
BEGIN
    UPDATE employees
    SET salary = salary + p_raise
    WHERE employee_id = p_emp_id
    RETURNING salary INTO v_new_sal;

    DBMS_OUTPUT.PUT_LINE('员工 ' || p_emp_id || ' 新工资: ' || v_new_sal);
END;
/

-- 调用存储过程
CALL update_salary(100, 500);
EXEC update_salary(100, 500);
```

### 触发器

```sql
-- 创建行级触发器
CREATE OR REPLACE TRIGGER trg_emp_salary_audit
BEFORE UPDATE OF salary ON employees
FOR EACH ROW
BEGIN
    INSERT INTO salary_audit (emp_id, old_sal, new_sal, change_date)
    VALUES (:OLD.employee_id, :OLD.salary, :NEW.salary, SYSDATE);
END;
/

-- 创建 INSTEAD OF DML 触发器
CREATE OR REPLACE TRIGGER trg_view_insert
INSTEAD OF INSERT ON emp_view
FOR EACH ROW
BEGIN
    INSERT INTO employees (employee_id, last_name, salary)
    VALUES (:NEW.employee_id, :NEW.last_name, :NEW.salary);
END;
/
```

### 匿名块

```sql
-- 匿名块
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM employees WHERE department_id = 10;
    DBMS_OUTPUT.PUT_LINE('部门 10 员工数: ' || v_count);
END;
/
```

### 游标与批量处理

```sql
-- 显式游标支持 FOR UPDATE
DECLARE
    CURSOR emp_cursor IS
        SELECT employee_id, salary
        FROM employees
        WHERE department_id = 10
        FOR UPDATE;
BEGIN
    FOR emp_rec IN emp_cursor LOOP
        UPDATE employees SET salary = salary * 1.1
        WHERE CURRENT OF emp_cursor;
    END LOOP;
END;
/

-- BULK COLLECT 批量绑定
DECLARE
    TYPE emp_id_array IS TABLE OF employees.employee_id%TYPE;
    v_ids emp_id_array;
BEGIN
    SELECT employee_id BULK COLLECT INTO v_ids
    FROM employees WHERE department_id = 10;

    FORALL i IN 1..v_ids.COUNT
        UPDATE employees SET salary = salary * 1.05
        WHERE employee_id = v_ids(i);
END;
/
```

### 用户自定义类型

```sql
-- OBJECT TYPE
CREATE OR REPLACE TYPE person_type AS OBJECT (
    name VARCHAR2(50),
    age NUMBER,
    MEMBER FUNCTION get_info RETURN VARCHAR2
);
/

CREATE OR REPLACE TYPE BODY person_type AS
    MEMBER FUNCTION get_info RETURN VARCHAR2 IS
    BEGIN
        RETURN name || ', ' || age || '岁';
    END;
END;
/

-- VARRAY TYPE
CREATE OR REPLACE TYPE phone_list_type AS VARRAY(10) OF VARCHAR2(20);
/

-- TABLE TYPE
CREATE OR REPLACE TYPE email_list_type AS TABLE OF VARCHAR2(100);
/
```

### 用户自定义函数

```sql
-- 创建函数
CREATE OR REPLACE FUNCTION get_annual_sal(p_sal NUMBER) RETURN NUMBER IS
BEGIN
    RETURN p_sal * 12;
END;
/

-- SQL 中调用 UDF
SELECT employee_id, get_annual_sal(salary) AS annual_sal FROM employees;
```

## 限制与差异说明

### 语法差异

1. **字符串字面量**：Oracle 使用单引号，YashanDB 也使用单引号
2. **日期字面量**：Oracle 使用 `DATE '2024-01-01'`，YashanDB 支持
3. **注释语法**：支持 `--` 和 `/* */`
4. **PL/SQL 块结束符**：使用 `/` 结束块（与 Oracle 相同）

### 性能注意事项

1. **批量绑定**：使用 FORALL 和 BULK COLLECT 提高性能
2. **绑定变量**：建议使用绑定变量提高执行计划复用
3. **动态 SQL**：使用 EXECUTE IMMEDIATE 执行动态 SQL

---

### 参考

- [产品文档/产品描述/兼容性说明/与Oracle兼容性说明.md](../../../产品文档/产品描述/兼容性说明/与Oracle兼容性说明.md)
