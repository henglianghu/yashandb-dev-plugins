# C 驱动故障排查

## 验证安装

### 验证库文件

```bash
# Linux
ls ~/.yashandb/client/lib/libyascli.so
# 应该输出：/home/user/.yashandb/client/lib/libyascli.so

# Windows
where.exe yascli.dll
# 应该输出：C:\Users\user\.yashandb\client\lib\yascli.dll
```

## 常见问题

### 1. 找不到 libyascli.so / yascli.dll

**解决方案**：
- 确认已解压到正确目录（`~/.yashandb/client`）
- `yascli` 动态库已在 `~/.yashandb/client/lib` 路径下
- 确认 `LD_LIBRARY_PATH`（Linux）或 `PATH`（Windows）包含对应路径(`~/.yashandb/client/lib`)
- 重新打开终端/命令行窗口

### 2. Windows 下 DLL 加载失败

**解决方案**：
- 确认 PATH 环境变量包含 `C:\Users\你的用户名\.yashandb\client\lib`
- 尝试将 `yascli.dll` 复制到 `C:\Windows\System32`

### 3. GitHub 下载失败

**解决方案**：
- 使用备用下载地址：`https://linked.yashandb.com`
- 或手动从 https://github.com/yashan-technologies/yashandb-client/releases 下载后上传到服务器
