# JDBC 连接详细指南

## URL 格式

```
jdbc:yasdb://host:port/database?param1=value1&param2=value2
```

## 常用参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| connectTimeout | 连接超时时间（秒） | 10 |
| socketTimeout | Socket 超时时间（秒） | 0（无限等待） |
| loginTimeout | 登录认证超时时间（秒） | 300 |
| autoCommit | 自动提交（true/false） | true |
| serverMode | 连接模式（dedicated/shared） | shared |
| mapDateToTimestamp | 日期转 Timestamp（true/false） | false |
| allowMultiStmt | 允许多条 SQL（true/false） | false |

## 基础连接示例

### DriverManager 连接

```java
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

public class App {
    public static void main(String[] args) {
        String driver = "com.yashandb.jdbc.Driver";
        String url = "jdbc:yasdb://127.0.0.1:1688/yasdb";
        String user = "system";
        String password = "oracle";

        try {
            Class.forName(driver);
            Connection conn = DriverManager.getConnection(url, user, password);
            System.out.println("连接成功！");

            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT 1 FROM dual");

            if (rs.next()) {
                System.out.println("查询结果: " + rs.getInt(1));
            }

            rs.close();
            stmt.close();
            conn.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

### YasDataSource 连接（推荐生产环境）

```java
import javax.sql.DataSource;
import com.yashandb.jdbc.YasDataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;

public class App {
    public static void main(String[] args) {
        try {
            YasDataSource dataSource = new YasDataSource();
            dataSource.setURL("jdbc:yasdb://127.0.0.1:1688/yasdb");
            dataSource.setUser("system");
            dataSource.setPassword("oracle");

            Connection conn = dataSource.getConnection();
            System.out.println("连接成功！");

            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT 1 FROM dual");

            if (rs.next()) {
                System.out.println("查询结果: " + rs.getInt(1));
            }

            rs.close();
            stmt.close();
            conn.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

## 使用 PreparedStatement

```java
String url = "jdbc:yasdb://127.0.0.1:1688/yasdb";
String user = "system";
String password = "oracle";

try (Connection conn = DriverManager.getConnection(url, user, password)) {
    // 插入数据
    String insertSql = "INSERT INTO users (id, name, email) VALUES (?, ?, ?)";
    try (PreparedStatement pstmt = conn.prepareStatement(insertSql)) {
        pstmt.setInt(1, 1);
        pstmt.setString(2, "张三");
        pstmt.setString(3, "zhangsan@example.com");
        int rows = pstmt.executeUpdate();
        System.out.println("插入 " + rows + " 行");
    }

    // 查询数据
    String querySql = "SELECT * FROM users WHERE id = ?";
    try (PreparedStatement pstmt = conn.prepareStatement(querySql)) {
        pstmt.setInt(1, 1);
        try (ResultSet rs = pstmt.executeQuery()) {
            while (rs.next()) {
                System.out.println("ID: " + rs.getInt("id"));
                System.out.println("Name: " + rs.getString("name"));
            }
        }
    }
}
```

## 事务处理

```java
String url = "jdbc:yasdb://127.0.0.1:1688/yasdb";
String user = "system";
String password = "oracle";

Connection conn = DriverManager.getConnection(url, user, password);
conn.setAutoCommit(false);

Statement stmt = conn.createStatement();
stmt.execute("INSERT INTO accounts (id, balance) VALUES (1, 1000)");
stmt.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1");

conn.commit();
System.out.println("事务提交成功！");
```

## 数据类型映射

### Java → YashanDB

| Java 类型 | YashanDB 类型 |
|-----------|---------------|
| int/Integer | INTEGER |
| long/Long | BIGINT |
| float/Float | FLOAT |
| double/Double | DOUBLE |
| boolean/Boolean | NUMBER(1) |
| String | VARCHAR2 |
| java.sql.Date | DATE |
| java.sql.Timestamp | TIMESTAMP |

### YashanDB → Java

| YashanDB 类型 | Java 类型 |
|---------------|-----------|
| INTEGER | int |
| BIGINT | long |
| DOUBLE | double |
| DATE | java.sql.Date |
| TIMESTAMP | java.sql.Timestamp |
| VARCHAR2 | String |