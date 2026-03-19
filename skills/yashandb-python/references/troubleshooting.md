# Python 驱动故障排查

## 验证安装

```python
import yasdb  # 或 import yaspy

print(dir(yasdb))
```

应该看到：`connect`, `cursor`, `Error` 等属性。

## 常见问题

### 1. 找不到 yascli.dll / libyascli.so

**可能原因**：
- C 驱动未安装
- 环境变量 PATH 未包含 C 驱动路径

**解决方案**：
- 执行 `/yashandb-c` 检查 C 驱动安装
- 确认环境变量 PATH 包含 C 驱动的 bin 和 lib 目录

### 2. ImportError: Could not load yascli

**解决方案**：
- 执行 `/yashandb-c` 重新检查 C 驱动配置
- 可以在代码开头添加路径设置：

```python
import os
YASCLI_PATH = os.path.expanduser("~/yasdb_client")
os.environ["PATH"] = f"{YASCLI_PATH}\\lib;{YASCLI_PATH}\\bin;" + os.environ.get("PATH", "")
```

### 3. pip 安装失败

**可能原因**：
- whl 文件与 Python 版本不匹配

**解决方案**：
- 确认使用正确的 whl 文件
- Windows Python 3.12 需要 cp312 或更高版本

### 4. 连接超时

**可能原因**：
- YashanDB 服务未运行
- 端口不正确
- 防火墙阻止

**解决方案**：
- 检查 YashanDB 服务是否运行
- 检查端口是否正确（默认 1688）
- 验证 DSN 格式是否正确（格式：`user/password@host:port`）

### 5. 认证失败

**可能原因**：
- 用户名或密码错误
- 使用了错误的数据库用户

**解决方案**：
- 确认用户名密码正确

### 6. 编码问题

**可能原因**：
- 数据库字符集与代码编码不一致

**解决方案**：
- 确保数据库字符集为 UTF-8
- Python 文件使用 UTF-8 编码：`# -*- coding: utf-8 -*-`

## 调试技巧

```python
import yasdb
import logging

# 启用调试日志
logging.basicConfig(level=logging.DEBUG)

# 测试连接
conn = yasdb.connect(user="system", password="oracle", host="localhost")
print(f"连接成功: {conn}")
print(f"用户: {conn.user}")
print(f"DSN: {conn.dsn}")

cursor = conn.cursor()
cursor.execute("SELECT * FROM v$version")
print("数据库版本:")
for row in cursor.fetchall():
    print(row)

cursor.close()
conn.close()
```