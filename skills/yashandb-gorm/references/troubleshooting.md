# GORM 故障排查

## 常见问题

### 1. 不支持的 GORM 功能

YashanDB GORM 适配器可能有部分 GORM 功能不支持，遇到问题时：
- 检查 YashanDB 官方文档确认功能支持情况
- 使用原生 SQL 替代

### 2. 连接失败

**可能原因**：
- C 驱动未安装
- Go 驱动未安装
- 数据库服务未运行

**解决方案**：
- 执行 `/yashandb-c` 检查 C 驱动
- 执行 `/yashandb-go` 检查 Go 驱动
- 检查 YashanDB 服务是否运行

### 3. 数据类型不支持

**可能原因**：
- 某些 Go 类型在 YashanDB 中没有对应类型

**解决方案**：
- 使用原生 SQL 处理复杂类型
- 咨询 YashanDB 官方文档