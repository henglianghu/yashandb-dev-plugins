#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default configuration
PORT=${PORT:-1688}
PASSWORD=${SYS_PASSWD:-Cod-2022}
CLUSTER=${CLUSTER:-yashandb}
IMAGE_NAME="yasdb/yashandb:latest"
HOME_DIR="${HOME}"

echo -e "${GREEN}=== YashanDB Docker 部署脚本 ===${NC}"

# Step 1: Check Docker
echo -e "${YELLOW}[1/5] 检查 Docker...${NC}"
if ! command -v docker &> /dev/null; then
  echo -e "${RED}错误: Docker 未安装或不在 PATH 中${NC}"
  exit 1
fi

if ! docker info &> /dev/null; then
  echo -e "${RED}错误: Docker 守护进程未运行，请先启动 Docker${NC}"
  exit 1
fi
echo -e "${GREEN}Docker 已安装并运行${NC}"

# Step 2: Pull image from Docker Hub
echo -e "${YELLOW}[2/5] 拉取 YashanDB Docker 镜像...${NC}"
echo "镜像: ${IMAGE_NAME}"
docker pull "${IMAGE_NAME}"
if [ $? -ne 0 ]; then
  echo -e "${RED}错误: 拉取 Docker Hub 镜像失败，尝试离线导入...${NC}"
  echo "请参考: skills/yashandb-docker/references/offline-import.md"
  exit 1
fi
echo -e "${GREEN}镜像拉取成功${NC}"

# Step 3: Create directories
echo -e "${YELLOW}[3/5] 创建数据目录...${NC}"
mkdir -p "${HOME_DIR}/yashan/data"
mkdir -p "${HOME_DIR}/yashan/yasboot"
echo -e "${GREEN}目录创建完成:${NC}"
echo "  - ${HOME_DIR}/yashan/data"
echo "  - ${HOME_DIR}/yashan/yasboot"

# Step 4: Start container
echo -e "${YELLOW}[4/5] 启动 YashanDB 容器...${NC}"

# Check if container already exists
if docker ps -a | grep -q "^${CLUSTER}$"; then
  echo -e "${YELLOW}容器 '${CLUSTER}' 已存在，正在移除...${NC}"
  docker stop "${CLUSTER}" 2>/dev/null || true
  docker rm "${CLUSTER}" 2>/dev/null || true
fi

docker run -d \
  -p ${PORT}:1688 \
  -v "${HOME_DIR}/yashan/data:/data/yashan" \
  -v "${HOME_DIR}/yashan/yasboot:/home/yashan/.yasboot" \
  -e SYS_PASSWD="${PASSWORD}" \
  --name "${CLUSTER}" \
  "${IMAGE_NAME}"

if [ $? -ne 0 ]; then
  echo -e "${RED}错误: 启动容器失败${NC}"
  exit 1
fi

echo -e "${GREEN}容器启动成功${NC}"

# Step 5: Show info
echo -e "${YELLOW}[5/5] 部署完成${NC}"
echo ""
echo "容器信息:"
echo "  - 名称: ${CLUSTER}"
echo "  - 端口: ${PORT} (映射到容器端口 1688)"
echo "  - 密码: ${PASSWORD}"
echo "  - 镜像: ${IMAGE_NAME}"
echo ""
echo "数据目录:"
echo "  - ${HOME_DIR}/yashan/data"
echo "  - ${HOME_DIR}/yashan/yasboot"
echo ""
echo "常用命令:"
echo "  - 查看日志: docker logs ${CLUSTER}"
echo "  - 查看状态: docker ps | grep ${CLUSTER}"
echo "  - 连接数据库: docker exec -it ${CLUSTER} yasql sys/${PASSWORD}"
echo "  - 停止容器: docker stop ${CLUSTER}"
echo "  - 启动容器: docker start ${CLUSTER}"
echo ""
echo -e "${YELLOW}重要: 首次登录后请立即修改默认密码 '${PASSWORD}'！${NC}"