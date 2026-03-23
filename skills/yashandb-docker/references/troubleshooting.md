---
variables:
  image: docker.1ms.run/yasdb/yashandb:23.4.7.100
  password: Cod-2022
---

# Docker 故障排查

## 验证部署

### 检查容器状态

**Linux**
```bash
docker ps | grep yashandb
```

**Windows PowerShell**
```powershell
docker ps | Select-String yashandb
```

### 检查容器日志

```bash
docker logs yashandb
```

## 常见问题

### 1. Docker Hub 拉取失败

**原因**：网络问题或 Docker Hub 不可访问

**解决方案**：
- 检查网络连接
- 使用离线导入方式：参考 [离线导入](offline-import.md)
- 配置 Docker 镜像代理

### 2. "Unsupported platform"

**原因**：运行在非 Linux 或不支持的架构上

**解决方案**：
- Linux 使用 x86_64 或 aarch64
- Windows 使用 x86_64（通过 WSL2）

### 3. "Failed to download"

**原因**：网络问题或 URL 无效

**解决方案**：
- 检查网络连接
- 验证 Docker Hub 是否可访问：`docker pull hello-world`

### 4. "Failed to import Docker image"

**原因**：
- 下载的文件损坏
- Docker 未运行

**解决方案**：
- 重新下载镜像
- 确认 Docker daemon 正在运行

### 5. "Directory creation failed"

**原因**：
- 权限不足
- 磁盘空间不足

**解决方案**：
- 检查权限
- 检查可用磁盘空间

### 6. "Container exited immediately"

**原因**：
- 端口冲突
- 配置无效

**解决方案**：
- 检查端口 1688 是否被占用
- 查看容器日志

### 7. Windows 上 Docker 无法启动

**原因**：WSL2 或 Hyper-V 未正确配置

**解决方案**：
- 确保已启用 WSL2：`wsl --install`
- 在 Docker Desktop 设置中启用 WSL2 后端
- 在 Docker Desktop 资源共享设置中添加 C 盘

### 8. 端口 1688 被占用

**解决方案**：
修改启动命令中的端口映射：
```bash
docker run -d -p 1689:1688 ...
```

## 清理

### 停止和删除容器

```bash
docker stop yashandb
docker rm yashandb
```

### 删除 Docker 镜像

```bash
docker rmi {{image}}
```

### 删除数据目录

**Linux**
```bash
rm -rf ~/yashan
```

**Windows PowerShell**
```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\yashan"
```

## 安全注意事项

- 默认密码 `{{password}}` 仅用于初始部署
- 首次部署后立即修改密码
- 生产环境不要公开暴露端口 1688
- 使用 Docker secrets 或环境文件管理敏感数据