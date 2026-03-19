# 离线导入 YashanDB Docker 镜像

当无法访问 Docker Hub 时，可以采用离线方式部署 YashanDB。

## 下载镜像

### 官方下载链接

| 平台 | 下载链接 |
|------|----------|
| x86_64 (Linux) | https://linked.yashandb.com/upload1010/yashandb-image-23.4.1.109-linux-x86_64.tar.gz |
| aarch64 (Linux) | https://linked.yashandb.com/upload1010/yashandb-image-23.4.1.109-linux-aarch64.tar.gz |

### Linux 下载命令

```bash
PLATFORM="x86_64"  # 或 "aarch64"
IMAGE_NAME="yashandb-image-23.4.1.109-linux-${PLATFORM}.tar.gz"
DOWNLOAD_URL="https://linked.yashandb.com/upload1010/${IMAGE_NAME}"

curl -fL -o "${IMAGE_NAME}" "${DOWNLOAD_URL}"
```

### Windows 下载命令（PowerShell）

```powershell
$IMAGE_NAME = "yashandb-image-23.4.1.109-linux-x86_64.tar.gz"
$DOWNLOAD_URL = "https://linked.yashandb.com/upload1010/$IMAGE_NAME"

Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $IMAGE_NAME
```

> **注意**：Windows 版 Docker 容器实际运行在 Linux 虚拟机内，因此使用 Linux x86_64 镜像。

## 导入 Docker

### Linux 导入命令

```bash
docker load -i "${IMAGE_NAME}"
```

### Windows 导入命令（PowerShell）

```powershell
docker load -i $IMAGE_NAME
```

## 验证导入结果

```bash
docker images | grep yashandb
```

## 后续步骤

镜像导入成功后，继续执行以下步骤：

1. 创建数据目录
2. 启动容器

详见 [安装指南](installation.md)