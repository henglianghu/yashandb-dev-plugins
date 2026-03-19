---
title: YashanDB 数据类型
description: 数值类型、字符类型、日期时间类型、LOB 类型的选择与使用
tags: yashandb, data-types, number, varchar, timestamp, lob
---

# 数据类型选择

选择正确的数据类型可以减少存储空间、提高查询性能、增强数据完整性。选择最小的正确类型——每页能存放更多行，缓存效率更高，查询更快。

> **参考文档**：产品文档/开发手册/SQL参考手册/数据类型/数值型.md

## 数值类型

### 整数类型

YashanDB 支持多种整数类型，与 MySQL 兼容：

```sql
col TINYINT           -- 1 字节
col SMALLINT          -- 2 字节
col INTEGER           -- 4 字节，PLS_INTEGER 为别名
col BIGINT            -- 8 字节
```

> **官方说明**："整数类型为定长、精确数值类型，是没有小数部分的整数，具体包括TINYINT、SMALLINT、INT、BIGINT四种数据类型。PLS_INTEGER、INT为INTEGER的别名，行为完全同INTEGER。INT类型在语法上支持定义时带精度信息，精度范围为 0 ~ 255。"

| 类型 | 字节 | 值域 |
|------|------|------|
| TINYINT | 1 | \[-2<sup>7</sup> , 2<sup>7</sup> - 1\] = -128 ~ 127 |
| SMALLINT | 2 | \[-2<sup>15</sup>, 2<sup>15</sup> - 1\] = -32768 ~ 32767 |
| INT | 4 | \[-2<sup>31</sup>, 2<sup>31</sup> - 1\] = -2147483648 ~ 2147483647 |
| BIGINT | 8 | \[-2<sup>63</sup>, 2<sup>63</sup> - 1\] = -9223372036854775808 ~ 9223372036854775807 |

**主键推荐**：对于插入量大的表，优先使用 BIGINT 自增主键，确保不会达到上限。

> **注意**：当配置参数 USE_NATIVE_TYPE 为 FALSE 时，TINYINT、SMALLINT、INT、BIGINT 返回值类型为 NUMBER，precision 为 38，scale 为 0。

### NUMBER

NUMBER 是 YashanDB 的高精度数值类型，用于存储整数和浮点数：

```sql
-- 整数
col NUMBER(10)        -- 最多 10 位整数
col NUMBER            -- 变长高精度整数

-- 定点数
col NUMBER(10, 2)     -- 总共 10 位，其中 2 位小数（99999999.99）

-- 浮点数
col NUMBER(*)         -- 变长浮点数，精度为 38
```

> **官方说明**："NUMBER类型为非定长、精确的数值类型，它可以自由指定精度（P，Precision）和刻度（S，Scale）。P：精度，表示数字的有效位数（不包含小数点、正负符号的位数），取值范围[1,38]；也可以为*，表示精度为38。S：刻度，表示数字从小数点到最右侧有效数字的位数，取值范围[-84,127]。DECIMAL、NUMERIC为NUMBER的别名，行为完全同NUMBER。"

### FLOAT 和 DOUBLE（浮点类型）

浮点类型为定长、非精确数值类型，行为与行业标准 IEEE Standard 754 一致。

> **官方说明**："浮点类型拥有更宽广的值域，可以表达特殊值 Inf、-Inf、NaN，对小数点的位置也无法限制。无法避免由于二进制精度转换至十进制精度所带来的误差，所以一些数字无法被浮点数类型准确的表达（例如 0.1）。"

```sql
col FLOAT             -- 4 字节，单精度浮点
col DOUBLE            -- 8 字节，双精度浮点
col REAL              -- FLOAT 的别名
```

| 类型 | 字节 | 值域 | 可保证准确的十进制精度 |
|------|------|------|---------------------|
| FLOAT | 4 | \[-3.402823E38, -1.401298E-45\] / 0 / \[1.401298E-45, 3.402823E38\] | 6位 |
| DOUBLE | 8 | \[-1.79769313486232E308, -4.94065645841247E-324\] / 0 / \[4.94065645841247E-324, 1.79769313486232E308\] | 15位 |

**使用场景**：
- FLOAT/DOUBLE：科学计算，对精度要求不高的场景
- NUMBER：金融计算、需要精确结果的场景

### BIT 类型

BIT 类型支持 1-64 位宽度的二进制位图：

```sql
col BIT               -- 默认 1 位
col BIT(8)            -- 8 位二进制
col BIT(64)           -- 64 位二进制
```

> **官方说明**："BIT类型支持1-64位宽度（Size）的二进制位图，每BIT位只允许存放0/1值，其他值将视为非法BIT类型。BIT类型仅适用于HEAP表，分布式行表不支持Bit类型。"

## 字符类型

> **参考文档**：产品文档/开发手册/SQL参考手册/数据类型/字符型.md

### CHAR 和 VARCHAR

YashanDB 字符型包括 CHAR、VARCHAR、NCHAR 和 NVARCHAR 四种数据类型。

```sql
-- 定长字符串
col CHAR(10)          -- 始终占用 10 个字符位置，不足部分用空格填充
col CHAR(10 BYTE)    -- 按字节定长，Size 范围 [1,8000]
col CHAR(10 CHAR)    -- 按字符定长（支持多字节字符集）

-- 变长字符串（Oracle 兼容模式推荐）
col VARCHAR(50)       -- 最多 50 个字符，Size 范围 [1,65534]
col VARCHAR(50 BYTE) -- 按字节限制
col VARCHAR(50 CHAR) -- 按字符限制
```

> **官方说明**："CHARACTER可作为CHAR别名使用，含义与CHAR含义相同。VARCHAR2、CHARACTER VARYING可作为VARCHAR别名使用，含义与VARCHAR含义相同。"

**VARCHAR vs VARCHAR2**：VARCHAR2 在 Oracle 兼容模式下是标准类型，语义更明确，YashanDB 推荐使用 VARCHAR。

> **注意**：在 HEAP 表中，长度超过 8000 字节的 VARCHAR 列会转换成 LOB 类型进行存储。

### NCHAR 和 NVARCHAR

Unicode 固定/变长字符类型：

```sql
col NCHAR(10)         -- 定长 Unicode，Size 范围 [1,4000]
col NVARCHAR(50)      -- 变长 Unicode，Size 范围 [1,32767]
```

> **官方说明**："NCHAR和NVARCHAR类型仅适用于HEAP表。NVARCHAR2可作为NVARCHAR别名使用，含义与NVARCHAR含义相同。"

### CLOB 和 NCLOB

大文本类型，用于存储大量文本数据：

```sql
col CLOB              -- 最多 4G*DB_BLOCK_SIZE 字节
col NCLOB             -- Unicode 大文本，仅 HEAP 表支持
```

```sql
-- 创建包含大文本的表
CREATE TABLE articles (
    id BIGINT PRIMARY KEY,
    title VARCHAR2(200),
    content CLOB
);
```

> **官方说明**："YashanDB对大对象类型的存储包含行内存储和行外存储两种方式：当一行的LOB列的数据小于一定的字节限制时，LOB数据将存储在行内。对于HEAP表，该限制是4000字节；对于TAC/LSC表，该限制是32000字节。"

**使用限制**：
- 不能作为索引列
- 不能作为排序列
- 不能修改 LOB 列的数据类型
- 不能作为分区键
- 不能与其他数据类型进行四则运算和取余运算
- 不能作为比较条件
- 不能使用 DISTINCT 去重
- 不能用于 GROUP BY 分组查询

## 日期时间类型

> **参考文档**：产品文档/开发手册/SQL参考手册/数据类型/日期时间型.md

### DATE

存储日期和时间，精确到秒：

```sql
col DATE              -- 8 字节
```

> **官方说明**："日期类型存储了与时区无关的逻辑日历信息，其信息包括年、月、日（时、分、秒）。DATE类型的默认格式为YYYY-MM-DD，也可以按类似YYYY-MM-DD [HH[24]][:MI][:SS]的标准格式进行指定。"

| 类型 | 字节长度 | 取值范围 | 精度 |
|------|----------|----------|------|
| DATE | 8 | 0001-01-01 00:00:00 ~ 9999-12-31 23:59:59 | 秒 |

```sql
-- 日期示例
CREATE TABLE orders (
    order_id BIGINT PRIMARY KEY,
    order_date DATE,
    shipped_date DATE
);

-- 插入日期
INSERT INTO orders VALUES (1, SYSDATE, NULL);
```

### TIME

表示一日以内的时间，包含时、分、秒和微秒：

```sql
col TIME              -- 8 字节
```

| 类型 | 字节长度 | 取值范围 | 精度 |
|------|----------|----------|------|
| TIME | 8 | 0:0:0.000000 ~ 23:59:59.999999 | 微秒 |

### TIMESTAMP

高精度时间戳，精确到微秒：

```sql
col TIMESTAMP                    -- 默认 6 位小数秒，8 字节
col TIMESTAMP(0)                 -- 无小数秒
col TIMESTAMP(9)                 -- 9 位小数秒（实际存储精度最大值为 6）
```

> **官方说明**："在定义时间戳类型时，微秒精度可定义范围为 0 ~ 9，但实际存储的精度最大值为 6。"

```sql
-- 带时区的时间戳
col TIMESTAMP WITH TIME ZONE     -- 10 字节（时间戳 8 + 时区 2）
col TIMESTAMP WITH LOCAL TIME ZONE -- 8 字节，仅 HEAP 表支持
```

| 类型 | 字节长度 | 取值范围 | 精度 |
|------|----------|----------|------|
| TIMESTAMP | 8 | 1-1-1 00:00:00.000000 ~ 9999-12-31 23:59:59.999999 | 微秒 |
| TIMESTAMP WITH TIME ZONE | 10 | 时间戳 8 + 时区 2 | 微秒 + 时区 |
| TIMESTAMP WITH LOCAL TIME ZONE | 8 | 1-1-1 00:00:00.000000 ~ 9999-12-31 23:59:59.999999 | 微秒 |

### INTERVAL 类型

表示两个日期或时刻之间的间隔长度：

```sql
col INTERVAL YEAR TO MONTH       -- 4 字节，表示年月间隔
col INTERVAL DAY TO SECOND       -- 8 字节，表示天到秒间隔
```

| 类型 | 字节长度 | 取值范围 | 精度 |
|------|----------|----------|------|
| INTERVAL YEAR TO MONTH | 4 | -178000000-00 ~ 178000000-00 | 月 |
| INTERVAL DAY TO SECOND | 8 | -100000000 00:00:00.000000 ~ 100000000 00:00:00.000000 | 微秒 |

**使用建议**：
- 存储用户本地时间：使用 TIMESTAMP WITH TIME ZONE
- 存储服务器时间：使用 TIMESTAMP
- 仅需日期不需要时间：使用 DATE

## JSON 类型

> **参考文档**：产品文档/开发手册/SQL参考手册/数据类型/JSON.md

YashanDB 支持 JSON 数据类型，用于存储半结构化数据：

```sql
col JSON                    -- JSON 数据类型
col JSON VIRTUAL           -- 虚拟列（计算得出，不存储）
```

```sql
-- 创建 JSON 列
CREATE TABLE products (
    id BIGINT PRIMARY KEY,
    name VARCHAR2(200),
    attributes JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 插入 JSON 数据
INSERT INTO products (id, name, attributes) VALUES
(1, '手机', '{"color": "黑色", "storage": "256GB", "price": 4999}');

-- 查询 JSON 字段
SELECT name, attributes->>'$.color' as color FROM products;
```

**使用建议**：
- 仅在数据结构不确定或经常变化时使用 JSON
- 对 JSON 字段频繁查询的属性，考虑使用生成列索引
- 大量结构化数据应使用标准列而非 JSON

## LOB 类型

> **参考文档**：产品文档/开发手册/SQL参考手册/数据类型/大对象型.md

### BLOB

用于存储二进制数据：

```sql
col BLOB                  -- 二进制大对象，最大 4G*DB_BLOCK_SIZE
```

> **官方说明**："BLOB表示二进制大对象，例如照片、视频、音频等文件。"

```sql
-- 存储图片、文件等二进制数据
CREATE TABLE documents (
    id BIGINT PRIMARY KEY,
    file_name VARCHAR2(255),
    file_content BLOB,
    mime_type VARCHAR2(50)
);
```

### CLOB

用于存储大文本数据：

```sql
col CLOB                  -- 文本大对象，最大 4G*DB_BLOCK_SIZE
```

> **官方说明**："CLOB表示可变长度文本，与VARCHAR类型类似，而VARCHAR类型的最大存储规格为65534字节，对于预计可能会存储超过该规格数据的字段，可将其设为CLOB类型。"

### NCLOB

用于存储 Unicode 大文本数据：

```sql
col NCLOB                 -- Unicode 大文本，仅 HEAP 表支持
```

> **官方说明**："NCLOB存储UNICODE可变长度数据，与CLOB类型功能类似，最大支持存储1~4G*DB_BLOCK_SIZE数据。NCLOB类型仅适用于HEAP表。"

### CLOB vs BLOB 选择

| 类型 | 用途 | 示例 |
|------|------|------|
| CLOB | 文本内容 | 文章、评论、日志 |
| BLOB | 二进制数据 | 图片、音频、文件 |
| NCLOB | Unicode 文本 | 多语言内容 |

## 数据类型选择原则

### 1. 选择最小类型

```sql
-- 不推荐
col VARCHAR2(255)         -- 浪费空间

-- 推荐
col VARCHAR2(50)          -- 按实际需求选择长度
col VARCHAR2(11)           -- 中国手机号 11 位
```

### 2. 主键使用 BIGINT

```sql
-- 主键使用 BIGINT 避免上限问题
CREATE TABLE large_table (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    -- ...
);
```

### 3. 货币使用 NUMBER

```sql
-- 金融计算使用 NUMBER，精度准确
amount NUMBER(19, 4)      -- 最多 19 位数字，4 位小数
price NUMBER(10, 2)       -- 价格，最多 10 位，2 位小数
```

### 4. 时间使用 TIMESTAMP

```sql
-- 推荐：包含创建时间和更新时间
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP
```

---

### 参考

- [产品文档/开发手册/SQL参考手册/数据类型/数值型.md](../../../产品文档/开发手册/SQL参考手册/数据类型/数值型.md)
- [产品文档/开发手册/SQL参考手册/数据类型/字符型.md](../../../产品文档/开发手册/SQL参考手册/数据类型/字符型.md)
- [产品文档/开发手册/SQL参考手册/数据类型/日期时间型.md](../../../产品文档/开发手册/SQL参考手册/数据类型/日期时间型.md)
- [产品文档/开发手册/SQL参考手册/数据类型/大对象型.md](../../../产品文档/开发手册/SQL参考手册/数据类型/大对象型.md)
- [产品文档/开发手册/SQL参考手册/数据类型/JSON.md](../../../产品文档/开发手册/SQL参考手册/数据类型/JSON.md)
