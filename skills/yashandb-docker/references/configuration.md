# Docker 配置详细指南

## 默认配置

| 参数 | 默认值 |
|------|--------|
| 镜像 | yasdb/yashandb:latest |
| 端口 | 1688 |
| 密码 | Cod-2022 |
| 集群名称 | yashandb |
| 数据目录 | ~/yashan/data |
| 配置目录 | ~/yashan/yasboot |

## 创建目录

### Linux

```bash
mkdir -p ~/yashan/data ~/yashan/yasboot
```

### Windows PowerShell

```powershell
$YASHAN_DIR = "$env:USERPROFILE\yashan"
New-Item -ItemType Directory -Force -Path "$YASHAN_DIR\data", "$YASHAN_DIR\yasboot" | Out-Null
```

## 启动容器

### 基本启动

**Linux**
```bash
docker run -d \
  -p 1688:1688 \
  -v ~/yashan/data:/data/yashan \
  -v ~/yashan/yasboot:/home/yashan/.yasboot \
  -e SYS_PASSWD=Cod-2022 \
  --name yashandb \
  yasdb/yashandb:latest
```

**Windows PowerShell**
```powershell
docker run -d `
  -p 1688:1688 `
  -v ${env:USERPROFILE}\yashan\data:C:\data\yashan `
  -v ${env:USERPROFILE}\yashan\yasboot:C:\home\yashan\.yasboot `
  -e SYS_PASSWD=Cod-2022 `
  --name yashandb `
  yasdb/yashandb:latest
```

### 自定义端口

```bash
docker run -d \
  -p 16888:1688 \
  -v ~/yashan/data:/data/yashan \
  -v ~/yashan/yasboot:/home/yashan/.yasboot \
  -e SYS_PASSWD=YourPassword \
  --name yashandb \
  yasdb/yashandb:latest
```

### 自定义数据目录

```bash
docker run -d \
  -p 1688:1688 \
  -v /your/custom/path/data:/data/yashan \
  -v /your/custom/path/yasboot:/home/yashan/.yasboot \
  -e SYS_PASSWD=Cod-2022 \
  --name yashandb \
  yasdb/yashandb:latest
```

## 环境变量

| 环境变量 | 说明 | 默认值 |
|----------|------|--------|
| SYS_PASSWD | 系统管理员密码 | Cod-2022 |
| YASDB_PORT | 端口 | 1688 |

## 查看容器状态

```bash
# 查看运行中的容器
docker ps

# 查看所有容器
docker ps -a

# 查看容器日志
docker logs yashandb
```

## 连接测试

```bash
docker exec -it yashandb yasql sys/Cod-2022
```

## 停止和启动

```bash
# 停止容器
docker stop yashandb

# 启动容器
docker start yashandb

# 重启容器
docker restart yashandb
```