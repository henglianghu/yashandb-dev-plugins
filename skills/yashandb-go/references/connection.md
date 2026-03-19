# Go 驱动连接详细指南

## DSN 格式

`user/password@host:port`

## 完整测试程序

```go
package main

import (
    "database/sql"
    "fmt"
    _ "github.com/yashan-technologies/yashandb-go"
)

func main() {
    dsn := "user/password@192.168.1.2:1688"
    db, err := sql.Open("yasdb", dsn)
    if err != nil {
        panic(err)
    }
    defer db.Close()

    var result int
    err = db.QueryRow("SELECT 1 FROM dual").Scan(&result)
    if err != nil {
        panic(err)
    }
    fmt.Println("YashanDB 连接成功! 查询结果:", result)
}
```

## 执行测试

```bash
go run test.go
```

如果输出 `YashanDB 连接成功! 查询结果: 1`，说明环境搭建完成。

## 连接池配置

```go
import (
    "database/sql"
    "time"
    _ "github.com/yashan-technologies/yashandb-go"
)

func main() {
    db, err := sql.Open("yasdb", "user/password@192.168.1.2:1688")
    if err != nil {
        panic(err)
    }
    defer db.Close()

    // 设置连接池参数
    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)
}
```