# Go 驱动安装详细指南

## 使用 go get 安装

```bash
go get -u github.com/yashan-technologies/yashandb-go
```

## 使用 Go Modules

在项目中初始化 Go Modules 并添加依赖：

```bash
go mod init your-project-name
go mod tidy
go get github.com/yashan-technologies/yashandb-go
```

## 前置依赖检查

Go 驱动依赖 C 驱动（libyascli.so / yascli.dll）。

### 检查 C 驱动

```bash
ls ~/.yashandb/client/lib/libyascli.so 2>/dev/null && echo "已安装"
```

### Windows (PowerShell)

```powershell
Test-Path "$env:USERPROFILE\.yashandb\client\lib\yascli.dll"
```

### 如果未安装 C 驱动

执行 `/yashandb-c` 技能安装 C 驱动。