# GORM 基础使用详细指南

## 连接数据库

```go
package main

import (
    "fmt"
    "log"

    yasdb "github.com/yashan-technologies/yashandb-gorm"
    "gorm.io/gorm"
)

func main() {
    dsn := "user/password@192.168.1.2:1688"
    db, err := gorm.Open(yasdb.Open(dsn), &gorm.Config{})
    if err != nil {
        log.Fatalf("连接失败: %v", err)
    }
    fmt.Println("YashanDB 连接成功!")
}
```

## 定义模型

```go
type User struct {
    ID    uint   `gorm:"primaryKey"`
    Name  string `gorm:"size:100"`
    Email string `gorm:"size:100"`
}

func (User) TableName() string {
    return "users"
}
```

## 自动迁移

```go
// 自动创建表
db.AutoMigrate(&User{})
```

## CRUD 操作

### 创建

```go
user := User{Name: "张三", Email: "zhangsan@example.com"}
result := db.Create(&user)
fmt.Printf("插入 ID: %d\n", user.ID)
```

### 查询

```go
var user User
db.First(&user, 1) // 根据主键查询
db.First(&user, "name = ?", "张三") // 条件查询

// 查询多条
var users []User
db.Find(&users)
```

### 更新

```go
db.Model(&user).Update("Email", "newemail@example.com")
db.Model(&user).Updates(User{Name: "李四", Email: "lisi@example.com"})
```

### 删除

```go
db.Delete(&user, 1)
```

## 关联关系

```go
type User struct {
    ID      uint
    Name    string
    Orders  []Order `gorm:"foreignKey:UserID"`
}

type Order struct {
    ID     uint
    UserID uint
    Amount float64
}

// 预加载
db.Preload("Orders").Find(&users)
```

## 事务

```go
err := db.Transaction(func(tx *gorm.DB) error {
    if err := tx.Create(&User{Name: "用户1"}).Error; err != nil {
        return err
    }
    if err := tx.Create(&Order{UserID: 1, Amount: 100}).Error; err != nil {
        return err
    }
    return nil
})
```

## 原生 SQL

```go
// 查询
var result int
db.Raw("SELECT 1 FROM dual").Scan(&result)

// 执行
db.Exec("INSERT INTO users (name, email) VALUES (?, ?)", "王五", "wangwu@example.com")
```

## 分页查询

```go
page := 1
pageSize := 10

var users []User
var total int64

db.Model(&User{}).Count(&total)
db.Offset((page - 1) * pageSize).Limit(pageSize).Find(&users)
```

## 数据类型映射

| Go 类型 | YashanDB 类型 |
|---------|---------------|
| int, uint | INTEGER, BIGINT |
| float64 | DOUBLE |
| string | VARCHAR2 |
| time.Time | TIMESTAMP |
| bool | NUMBER(1) |

## 连接池配置

```go
import (
    yasdb "github.com/yashan-technologies/yashandb-gorm"
)

sqlDB, err := db.DB()
if err != nil {
    log.Fatal(err)
}

sqlDB.SetMaxIdleConns(10)
sqlDB.SetMaxOpenConns(100)
sqlDB.SetConnMaxLifetime(time.Hour)
```