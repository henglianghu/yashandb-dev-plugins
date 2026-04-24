# YashanDB SQLAlchemy 测试脚本 (PowerShell)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "YashanDB SQLAlchemy 测试" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$通过 = 0
$失败 = 0

# 测试 1: 检查 Python 安装
function Test-PythonInstalled {
    Write-Host "测试 1: 检查 Python 安装..." -ForegroundColor Yellow

    $pythonCmd = $null
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $pythonCmd = "python3"
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonCmd = "python"
    }

    if ($pythonCmd) {
        $version = & $pythonCmd --version 2>&1
        Write-Success "Python 已安装: $version"
        return $true
    } else {
        Write-Error "Python 未安装"
        return $false
    }
}

# 测试 2: 检查 SQLAlchemy 安装
function Test-SQLAlchemyInstalled {
    Write-Host "测试 2: 检查 SQLAlchemy 安装..." -ForegroundColor Yellow

    $pythonCmd = "python3"
    if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $pythonCmd = "python"
    }

    try {
        $version = & $pythonCmd -c "import sqlalchemy; print(sqlalchemy.__version__)" 2>$null

        if ($version) {
            if ($version -like "1.4*") {
                Write-Success "SQLAlchemy 已安装: $version"
                return $true
            } else {
                Write-Warning "SQLAlchemy 版本: $version (需要 1.4.x)"
                return $false
            }
        }
    } catch {
        Write-Error "SQLAlchemy 未安装"
        return $false
    }
    return $false
}

# 测试 3: 检查 yaspy 驱动
function Test-YaspyDriver {
    Write-Host "测试 3: 检查 yaspy 驱动..." -ForegroundColor Yellow

    $pythonCmd = "python3"
    if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $pythonCmd = "python"
    }

    try {
        & $pythonCmd -c "import yaspy" 2>$null
        Write-Success "yaspy 模块已安装"
        return $true
    } catch {
        Write-Error "yaspy 模块未安装"
        return $false
    }
}

# 测试 4: 检查 yashandb-sqlalchemy 方言
function Test-YashandbSqlalchemy {
    Write-Host "测试 4: 检查 yashandb-sqlalchemy 方言..." -ForegroundColor Yellow

    $pythonCmd = "python3"
    if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $pythonCmd = "python"
    }

    try {
        & $pythonCmd -c "import yashandb_sqlalchemy" 2>$null
        Write-Success "yashandb-sqlalchemy 模块已安装"
        return $true
    } catch {
        Write-Error "yashandb-sqlalchemy 模块未安装"
        return $false
    }
}

# 测试 5: 检查 C 驱动依赖
function Test-CDriver {
    Write-Host "测试 5: 检查 C 驱动依赖..." -ForegroundColor Yellow

    # 检查 Windows 路径中的 yascli.dll
    $yascliPaths = @(
        "$env:YASDB_CLIENT\bin\yascli.dll",
        "$env:PATH\yascli.dll",
        "C:\yashandb\bin\yascli.dll"
    )

    $found = $false
    foreach ($path in $yascliPaths) {
        if (Test-Path $path) {
            Write-Success "找到 C 驱动库: $path"
            $found = $true
            break
        }
    }

    if (-not $found) {
        # 尝试在 PATH 中查找
        $yascli = Get-Command yascli.dll -ErrorAction SilentlyContinue
        if ($yascli) {
            Write-Success "找到 C 驱动库 (yascli.dll)"
            return $true
        } else {
            Write-Warning "未找到 C 驱动库 (yascli.dll)"
            return $false
        }
    }

    return $found
}

# 测试 6: 检查 yashandb-sqlalchemy 方言注册
function Test-DialectRegistered {
    Write-Host "测试 6: 检查 yashandb 方言注册..." -ForegroundColor Yellow

    $pythonCmd = "python3"
    if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $pythonCmd = "python"
    }

    try {
        & $pythonCmd -c "from yashandb_sqlalchemy import yaspy" 2>$null
        Write-Success "yashandb 方言可正常导入"
        return $true
    } catch {
        Write-Warning "yashandb 方言可能未正确注册"
        return $false
    }
}

# 运行所有测试
Write-Host "正在运行测试..." -ForegroundColor Cyan
Write-Host ""

if (Test-PythonInstalled) { $通过++ } else { $失败++ }
Write-Host ""

if (Test-SQLAlchemyInstalled) { $通过++ } else { $失败++ }
Write-Host ""

if (Test-YaspyDriver) { $通过++ } else { $失败++ }
Write-Host ""

if (Test-YashandbSqlalchemy) { $通过++ } else { $失败++ }
Write-Host ""

if (Test-CDriver) { $通过++ } else { $失败++ }
Write-Host ""

if (Test-DialectRegistered) { $通过++ } else { $失败++ }
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "测试摘要" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "通过: $通过" -ForegroundColor Green
Write-Host "失败: $失败" -ForegroundColor Red
Write-Host ""

if ($失败 -eq 0) {
    Write-Success "所有测试通过！"
    Write-Host ""
    Write-Host "YashanDB SQLAlchemy 环境已就绪，可以使用以下连接字符串：" -ForegroundColor Cyan
    Write-Host "  yashandb+yaspy://用户名:密码@主机:端口/数据库名" -ForegroundColor White
    exit 0
} else {
    Write-Warning "部分测试失败，请检查上述错误"
    exit 1
}
