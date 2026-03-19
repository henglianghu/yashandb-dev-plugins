# YashanDB Docker 部署脚本 (Windows PowerShell)

param(
    [int]$PORT = 1688,
    [string]$PASSWORD = "Cod-2022",
    [string]$CLUSTER = "yashandb"
)

$ErrorActionPreference = "Stop"
$IMAGE_NAME = "yasdb/yashandb:latest"
$HOME_DIR = $env:USERPROFILE

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "YashanDB Docker 部署脚本" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Docker
Write-Host "[1/5] 检查 Docker..." -ForegroundColor Yellow

if (-not (Test-Command docker)) {
    Write-ErrorMsg "Docker 未安装或不在 PATH 中"
    exit 1
}

try {
    $null = docker info 2>$null
} catch {
    Write-ErrorMsg "Docker 守护进程未运行，请先启动 Docker Desktop"
    exit 1
}
Write-Success "Docker 已安装并运行"

# Step 2: Pull image from Docker Hub
Write-Host "[2/5] 拉取 YashanDB Docker 镜像..." -ForegroundColor Yellow
Write-Host "镜像: $IMAGE_NAME"

try {
    docker pull $IMAGE_NAME
    if ($LASTEXITCODE -ne 0) { throw "拉取失败" }
} catch {
    Write-ErrorMsg "拉取 Docker Hub 镜像失败"
    Write-Host "请参考: skills/yashandb-docker/references/offline-import.md" -ForegroundColor Yellow
    exit 1
}
Write-Success "镜像拉取成功"

# Step 3: Create directories
Write-Host "[3/5] 创建数据目录..." -ForegroundColor Yellow

$YASHAN_DIR = "$HOME_DIR\yashan"
New-Item -ItemType Directory -Force -Path "$YASHAN_DIR\data" | Out-Null
New-Item -ItemType Directory -Force -Path "$YASHAN_DIR\yasboot" | Out-Null

Write-Success "目录创建完成:"
Write-Host "  - $YASHAN_DIR\data"
Write-Host "  - $YASHAN_DIR\yasboot"

# Step 4: Start container
Write-Host "[4/5] 启动 YashanDB 容器..." -ForegroundColor Yellow

# Check if container already exists
$existing = docker ps -a --filter "name=^${CLUSTER}$" --format "{{.Names}}"
if ($existing) {
    Write-Host "容器 '$CLUSTER' 已存在，正在移除..." -ForegroundColor Yellow
    docker stop $CLUSTER 2>$null
    docker rm $CLUSTER 2>$null | Out-Null
}

# Windows path mapping: Windows path -> Linux container path
docker run -d `
    -p ${PORT}:1688 `
    -v "${HOME_DIR}\yashan\data:C:\data\yashan" `
    -v "${HOME_DIR}\yashan\yasboot:C:\home\yashan\.yasboot" `
    -e SYS_PASSWD="${PASSWORD}" `
    --name "${CLUSTER}" `
    "${IMAGE_NAME}"

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "启动容器失败"
    exit 1
}

Write-Success "容器启动成功"

# Step 5: Show info
Write-Host "[5/5] 部署完成" -ForegroundColor Yellow
Write-Host ""
Write-Host "容器信息:" -ForegroundColor Cyan
Write-Host "  - 名称: $CLUSTER"
Write-Host "  - 端口: $PORT (映射到容器端口 1688)"
Write-Host "  - 密码: $PASSWORD"
Write-Host "  - 镜像: $IMAGE_NAME"
Write-Host ""
Write-Host "数据目录:" -ForegroundColor Cyan
Write-Host "  - $HOME_DIR\yashan\data"
Write-Host "  - $HOME_DIR\yashan\yasboot"
Write-Host ""
Write-Host "常用命令:" -ForegroundColor Cyan
Write-Host "  - 查看日志: docker logs $CLUSTER"
Write-Host "  - 查看状态: docker ps | Select-String $CLUSTER"
Write-Host "  - 连接数据库: docker exec -it $CLUSTER yasql sys/$PASSWORD"
Write-Host "  - 停止容器: docker stop $CLUSTER"
Write-Host "  - 启动容器: docker start $CLUSTER"
Write-Host ""
Write-Host "重要: 首次登录后请立即修改默认密码 '$PASSWORD'！" -ForegroundColor Yellow