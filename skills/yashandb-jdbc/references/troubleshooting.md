# JDBC 故障排查

## 常见问题

### 1. ClassNotFoundException: com.yashandb.jdbc.Driver

**可能原因**：
- JDBC 驱动 jar 包未正确添加到 classpath
- Maven/Gradle 依赖未正确配置

**解决方案**：
- 确认 JDBC 驱动 jar 包已正确添加到 classpath
- 确认 Maven/Gradle 依赖已正确配置

### 2. Connection refused

**可能原因**：
- YashanDB 服务未运行
- 端口不正确
- 防火墙阻止

**解决方案**：
- 检查 YashanDB 服务是否运行
- 检查端口是否正确（默认 1688）
- 检查防火墙设置

### 3. Authentication failed

**可能原因**：
- 用户名或密码错误
- 用户没有登录权限

**解决方案**：
- 确认用户名密码正确
- 检查用户是否具有登录权限

### 4. SQLSyntaxErrorException

**可能原因**：
- SQL 语法错误
- 表名或列名不存在
- 使用了错误的 SQL 模式

**解决方案**：
- 检查 SQL 语法是否正确
- 确认表名和列名是否存在
- 检查是否使用了正确的 SQL 模式（Oracle/MySQL 兼容）

## 调试技巧

### 启用 JDBC 日志

```java
import java.util.logging.*;
Logger.getLogger("com.yashandb.jdbc").setLevel(Level.ALL);
Handler handler = new ConsoleHandler();
handler.setLevel(Level.ALL);
Logger.getLogger("com.yashandb.jdbc").addHandler(handler);
```

### 异常处理

```java
try {
    Class.forName("com.yashandb.jdbc.Driver");
    Connection conn = DriverManager.getConnection(url, user, password);
    // ...
} catch (ClassNotFoundException e) {
    System.err.println("JDBC 驱动未找到: " + e.getMessage());
} catch (SQLException e) {
    System.err.println("SQL 错误:");
    System.err.println("  错误码: " + e.getErrorCode());
    System.err.println("  SQL 状态: " + e.getSQLState());
    System.err.println("  错误信息: " + e.getMessage());
}
```