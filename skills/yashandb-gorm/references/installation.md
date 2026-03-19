# GORM 安装详细指南

## 前置依赖

GORM 依赖 Go 驱动和 C 驱动。请先完成：
1. `/yashandb-c` - C 驱动安装
2. `/yashandb-go` - Go 驱动安装

## 检查前置依赖

```bash
# 检查 Go 环境
go version

# 检查是否已安装 yasdb-go
go list -m github.com/yashan-technologies/yashandb-go
```

## 安装 GORM 适配插件

```bash
go get -u github.com/yashan-technologies/yashandb-gorm
```

## 在项目中使用

```bash
go mod init your-project-name
go mod tidy
go get github.com/yashan-technologies/yashandb-gorm
```