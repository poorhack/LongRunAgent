#!/bin/bash

# ============================================
# Web 项目开发环境启动脚本
# 用途: 安装依赖、初始化数据库、启动开发服务器
# ============================================

set -e

PROJECT_NAME="{{PROJECT_NAME}}"
echo "╔════════════════════════════════════════════╗"
echo "║   $PROJECT_NAME - 开发环境启动              ║"
echo "╚════════════════════════════════════════════╝"

# ===== 检测项目类型并安装依赖 =====

# Node.js 项目
if [ -f "package.json" ]; then
    echo "📦 检测到 Node.js 项目"
    if ! command -v node &> /dev/null; then
        echo "❌ 未安装 Node.js，请先安装"
        exit 1
    fi

    if [ ! -d "node_modules" ]; then
        echo "📥 安装依赖..."
        npm install
    fi

    # 检查是否有数据库初始化脚本
    if [ -f "scripts/init-db.js" ]; then
        echo "💾 初始化数据库..."
        node scripts/init-db.js
    fi

    # 启动开发服务器
    echo "🚀 启动开发服务器..."
    npm run dev
    exit 0
fi

# Python 项目
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    echo "📦 检测到 Python 项目"

    if ! command -v python3 &> /dev/null; then
        echo "❌ 未安装 Python3，请先安装"
        exit 1
    fi

    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        echo "📦 创建虚拟环境..."
        python3 -m venv venv
    fi

    echo "🔧 激活虚拟环境..."
    source venv/bin/activate

    # 安装依赖
    if [ -f "requirements.txt" ]; then
        echo "📥 安装依赖..."
        pip install -q --upgrade pip
        pip install -q -r requirements.txt
    fi

    # 初始化数据库
    if [ -f "src/init_db.py" ]; then
        echo "💾 初始化数据库..."
        python src/init_db.py
    fi

    # 启动开发服务器
    echo "🚀 启动开发服务器..."
    if [ -f "src/app.py" ]; then
        export FLASK_APP=src/app.py
        export FLASK_ENV=development
        flask run --host=0.0.0.0 --port=5000
    elif [ -f "manage.py" ]; then
        python manage.py runserver
    else
        echo "⚠️  未找到启动入口，请手动启动"
    fi
    exit 0
fi

# Go 项目
if [ -f "go.mod" ]; then
    echo "📦 检测到 Go 项目"

    if ! command -v go &> /dev/null; then
        echo "❌ 未安装 Go，请先安装"
        exit 1
    fi

    echo "📥 下载依赖..."
    go mod download

    echo "🚀 启动开发服务器..."
    go run main.go
    exit 0
fi

echo "❌ 无法识别项目类型"
echo "请手动配置 init.sh 脚本"
exit 1