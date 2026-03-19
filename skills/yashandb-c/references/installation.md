# C 驱动安装详细指南

## 安装路径

默认安装目录：`~/.yashandb/client`（`{USER}/.yashandb/client`）

## 检测是否已安装

安装前先检查是否已安装：

```bash
ls ~/.yashandb/client/lib/libyascli.so 2>/dev/null && echo "已安装"
```

如果找到 libyascli，则 C 驱动已安装，跳到验证步骤。

## 下载地址

### 第一来源：GitHub Releases

**推荐优先使用**：https://github.com/yashan-technologies/yashandb-client/releases

使用 `gh` 命令获取下载 URL：

```bash
# Linux x86_64
gh release view latest -R yashan-technologies/yashandb-client --json assets --jq '.assets[] | select(.name | contains("linux") and contains("x86_64")) | .browser_download_url'

# Linux ARM64
gh release view latest -R yashan-technologies/yashandb-client --json assets --jq '.assets[] | select(.name | contains("linux") and contains("aarch64")) | .browser_download_url'

# Windows x64
gh release view latest -R yashan-technologies/yashandb-client --json assets --jq '.assets[] | select(.name | contains("windows") and contains("amd64")) | .browser_download_url'
```

### 第二来源：官网下载中心

如果 GitHub 无法访问，使用官网下载地址：

```bash
# Linux x86_64
curl -L -o /tmp/yashandb-client.tar.gz "https://linked.yashandb.com/upload1010/yashandb-client-23.4.1.102-linux-x86_64.tar.gz"

# Linux ARM64
curl -L -o /tmp/yashandb-client.tar.gz "https://linked.yashandb.com/upload1010/yashandb-client-23.4.1.102-linux-aarch64.tar.gz"

# Windows x64
curl -L -o /tmp/yashandb-client.zip "https://linked.yashandb.com/upload1010/yashandb-client-23.4.1.102-windows-amd64.zip"
```

## 安装步骤

### Linux 安装

```bash
# 创建目录
mkdir -p ~/.yashandb/client

# 解压（保留顶层目录结构）
tar -xzf /tmp/yashandb-client.tar.gz -C ~/.yashandb/client

# 验证
ls ~/.yashandb/client/lib/libyascli.so
```

### Windows 安装

```powershell
# 创建目录
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.yashandb\client"

# 解压
Expand-Archive -Path "$env:TEMP\yashandb-client.zip" -DestinationPath "$env:USERPROFILE\.yashandb\client" -Force

# 设置环境变量（当前会话）
$env:PATH = "$env:USERPROFILE\.yashandb\client\lib;$env:USERPROFILE\.yashandb\client\bin;$env:PATH"
```
