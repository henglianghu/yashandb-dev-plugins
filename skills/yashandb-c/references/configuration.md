# C 驱动配置指南

## 安装路径

默认安装目录：`~/.yashandb/client`（`{USER}/.yashandb/client`）

> **注意**：如果 C 驱动安装在默认路径，无需配置环境变量。Windows 下 DLL 通常与可执行文件同目录即可加载。

## 自定义安装路径

如果需要安装到非默认路径，可设置 `YASDB_CLIENT` 环境变量指定安装目录：

### Linux / macOS

```bash
export YASDB_CLIENT=/自定义路径/yasdb_client
export PATH=$YASDB_CLIENT/bin:$PATH
export LD_LIBRARY_PATH=$YASDB_CLIENT/lib:$LD_LIBRARY_PATH
```

添加到 `~/.bashrc` 或 `~/.zshrc` 使其永久生效：

```bash
echo 'export YASDB_CLIENT=/自定义路径/yasdb_client' >> ~/.bashrc
echo 'export PATH=$YASDB_CLIENT/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=$YASDB_CLIENT/lib:$LD_LIBRARY_PATH' >> ~/.bashrc

source ~/.bashrc
```

### Windows

```powershell
[Environment]::SetEnvironmentVariable("YASDB_CLIENT", "C:\自定义路径\yasdb_client", "User")
[Environment]::SetEnvironmentVariable("PATH", "C:\自定义路径\yasdb_client\lib;C:\自定义路径\yasdb_client\bin;" + [Environment]::GetEnvironmentVariable("PATH", "User"), "User")
```

## 验证环境变量

```bash
# Linux
echo $LD_LIBRARY_PATH
# 应该包含 yasdb_client/lib 路径

# Windows
echo %PATH%
# 应该包含 yasdb_client\lib 路径
```
