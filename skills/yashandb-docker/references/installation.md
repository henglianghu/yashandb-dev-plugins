# Docker 安装详细指南

## 前置条件

- **操作系统**：Linux（x86_64 或 aarch64）/ Windows 10/11（x86_64）
- **Docker** 已安装并运行
- **Docker daemon** 可访问（无需 sudo）
- **网络连接** 用于拉取 Docker Hub 镜像
- **至少 5GB** 可用磁盘空间

## Windows 特殊要求

- Docker Desktop 已启用 WSL2 或 Hyper-V 后端
- 在 Docker Desktop 设置中将 C 盘添加到资源共享

## 安装 Docker（如需要）

### Ubuntu/Debian

```bash
sudo apt update
sudo apt install docker.io
sudo systemctl start docker
sudo systemctl enable docker
```

### CentOS/RHEL

```bash
sudo yum install docker-ce
sudo systemctl start docker
sudo systemctl enable docker
```

### 验证 Docker

```bash
docker --version
docker ps
```

## 推荐方式：使用 Docker Hub 拉取镜像

### 自动拉取脚本（Linux）

```bash
docker pull yasdb/yashandb:latest
```

### 自动拉取脚本（PowerShell）

```powershell
docker pull yasdb/yashandb:latest
```

## 备选方式：离线导入

如果无法访问 Docker Hub，请参阅 [离线导入](offline-import.md)。

## 验证镜像

```bash
docker images | grep yashandb
```

## 后续步骤

镜像拉取完成后，继续执行：

1. 创建数据目录
2. 启动容器

详见 [配置说明](configuration.md)