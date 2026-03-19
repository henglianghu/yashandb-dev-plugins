# Python 驱动安装详细指南

## 检查环境

### 检查 Python

```bash
python --version
pip --version
```

### 检查 C 驱动

```bash
ls ~/.yashandb/client/lib/libyascli.so 2>/dev/null && echo "已安装"
```

### Windows (PowerShell)

```powershell
Test-Path "$env:USERPROFILE\.yashandb\client\lib\yascli.dll"
```

如果 C 驱动未安装，执行 `/yashandb-c` 安装。

## 安装 Python

### Windows

```powershell
winget install Python.Python.3.12 --accept-source-agreements --accept-package-agreements
```

### Linux

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install python3 python3-pip

# CentOS/RHEL
sudo yum install python3 python3-pip
```

## 安装 Python 驱动

**yaspy 和 yasdb 不在 PyPI 上**，需要从以下渠道获取：

1. **YashanDB 下载中心**：https://download.yashandb.com
2. **本地 wheel 文件**（如果有）

### 从本地文件安装

```bash
# 假设驱动文件在 ./scripts/ 目录下
pip install ./scripts/yasdb-1.2.0-py3-none-any.whl
```

### 从下载中心安装

从 YashanDB 下载中心获取对应的 whl 文件：
- **Windows**: `yaspy-xx.xx-cp38-cp38-win_amd64.whl` 或 `yasdb-xx.xx-py3-none-any.whl`
- **Linux x86_64**: `yaspy-xx.xx-cp36-cp36m-linux_x86_64.whl`
- **Linux aarch64**: `yaspy-xx.xx-cp36-cp36m-linux_aarch64.whl`

安装命令：

```bash
pip install yaspy-xx.xx-cp38-cp38-win_amd64.whl
```

### 驱动信息

| 属性 | 值 |
|------|-----|
| 推荐包名 | yaspy |
| 替代包名 | yasdb |
| Python 版本要求 | 3.6.0 及以上 |
| DB-API 版本 | 2.0 |
| 线程安全级别 | 2 |
| 参数风格 | 位置参数 (`:1`, `:2`) |
| 默认端口 | 1688 |
| 连接池支持 | 仅 yaspy 支持 |