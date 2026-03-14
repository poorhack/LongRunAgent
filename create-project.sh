#!/bin/bash

# ============================================
# Long-Running Agent 项目初始化脚本
# 用途: 从模板创建新的 Web 项目
# ============================================

set -e

# 默认目标目录为当前目录
TARGET_DIR="."

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  -d, --dir <目录>   指定项目创建目录 (默认: 当前目录)"
            echo "  -h, --help         显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                           # 当前目录创建"
            echo "  $0 -d /path/to/projects      # 指定目录创建"
            echo "  $0 --dir ../projects          # 使用相对路径"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 -h 或 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       Long-Running Agent - 项目初始化向导                  ║"
echo "║   基于 Anthropic 最佳实践，构建可持续的 Web 项目            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 显示目标目录
echo -e "${BLUE}目标目录:${NC} $TARGET_DIR"
echo ""

# 获取项目信息
read -p "项目名称 (英文，用于目录名): " PROJECT_NAME
read -p "项目描述: " PROJECT_DESC
read -p "技术栈 (如: Flask/SQLite/Pytest 或 React/Node/Jest): " TECH_STACK
read -p "目标功能列表 (逗号分隔): " FEATURES_INPUT

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# 创建项目目录
PROJECT_DIR="${TARGET_DIR}/${PROJECT_NAME}"
mkdir -p "$PROJECT_DIR"

echo -e "\n${YELLOW}正在创建项目结构...${NC}"

# 创建目录结构
mkdir -p "$PROJECT_DIR/src"
mkdir -p "$PROJECT_DIR/tests"
mkdir -p "$PROJECT_DIR/.agent"

# 复制模板文件
TEMPLATE_DIR="$(dirname "$0")"
cp "$TEMPLATE_DIR/.gitignore" "$PROJECT_DIR/"
cp "$TEMPLATE_DIR/init.sh" "$PROJECT_DIR/"
cp "$TEMPLATE_DIR/README.md" "$PROJECT_DIR/"

# 创建 features.json
FEATURES_JSON="$PROJECT_DIR/.agent/features.json"
cat > "$FEATURES_JSON" << EOF
{
  "project": {
    "name": "$PROJECT_NAME",
    "description": "$PROJECT_DESC",
    "tech_stack": [$(echo "$TECH_STACK" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')],
    "created_at": "$(date +%Y-%m-%d)"
  },
  "features": [
    {
      "id": "F001",
      "category": "setup",
      "description": "项目基础结构搭建",
      "steps": [
        "创建项目目录结构",
        "初始化包管理配置",
        "配置开发环境"
      ],
      "passes": false,
      "priority": "critical"
    },
EOF

# 解析功能列表并生成 features
IFS=',' read -ra FEATURES <<< "$FEATURES_INPUT"
PRIORITY_LEVELS=("critical" "high" "medium" "low")
INDEX=2

for feature in "${FEATURES[@]}"; do
    feature=$(echo "$feature" | xargs) # 去除首尾空格
    if [ -n "$feature" ]; then
        # 确定优先级
        if [ $INDEX -le 3 ]; then
            PRIORITY="high"
        elif [ $INDEX -le 6 ]; then
            PRIORITY="medium"
        else
            PRIORITY="low"
        fi

        cat >> "$FEATURES_JSON" << EOF
    {
      "id": "F$(printf "%03d" $INDEX)",
      "category": "core",
      "description": "$feature",
      "steps": [
        "实现 $feature",
        "编写测试用例",
        "验证功能正常"
      ],
      "passes": false,
      "priority": "$PRIORITY"
    },
EOF
        ((INDEX++))
    fi
done

# 移除最后的逗号并闭合 JSON
sed -i '$ s/,$//' "$FEATURES_JSON"
echo '  ]' >> "$FEATURES_JSON"
echo '}' >> "$FEATURES_JSON"

# 更新 features.json 统计
TOTAL=$(($INDEX - 1))
sed -i "s/\"total\": 2/\"total\": $TOTAL/" "$FEATURES_JSON" 2>/dev/null || true

# 创建 progress.md
cat > "$PROJECT_DIR/.agent/progress.md" << EOF
# $PROJECT_NAME 进度日志

> 自动记录每次会话的工作进度

---

## 元信息

- **项目名称**: $PROJECT_NAME
- **描述**: $PROJECT_DESC
- **创建时间**: $(date +%Y-%m-%d)
- **技术栈**: $TECH_STACK
- **当前进度**: 0/$TOTAL features

---

## 会话日志

### 会话 1 - $(date +%Y-%m-%d)

**启动状态**: 新项目初始化

**完成工作**:
- 项目结构创建

**当前进度**: 0/$TOTAL features

**下一步工作**:
- F001 项目基础结构搭建

---

## 统计

| 状态 | 数量 |
|------|------|
| 已完成 | 0 |
| 进行中 | 0 |
| 待开始 | $TOTAL |
EOF

# 创建 state.json
cat > "$PROJECT_DIR/.agent/state.json" << EOF
{
  "last_session": {
    "date": "$(date +%Y-%m-%d)",
    "session_id": 1,
    "completed_features": [],
    "current_focus": null,
    "commit_hash": null
  },
  "environment": {
    "dev_server_running": false,
    "dev_server_port": 3000,
    "database_initialized": false
  },
  "next_actions": [
    {
      "priority": 1,
      "feature_id": "F001",
      "action": "项目基础结构搭建"
    }
  ],
  "blockers": [],
  "notes": []
}
EOF

# 自定义 init.sh
sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$PROJECT_DIR/init.sh" 2>/dev/null || true

# 更新 README.md
sed -i "s/项目名称/$PROJECT_NAME/g" "$PROJECT_DIR/README.md" 2>/dev/null || true
sed -i "s/\[描述项目要实现的目标\]/$PROJECT_DESC/g" "$PROJECT_DIR/README.md" 2>/dev/null || true

# 初始化 Git
cd "$PROJECT_DIR"
git init
git add .
git commit -m "初始化项目结构"

echo -e "\n${GREEN}✅ 项目创建成功！${NC}"
echo -e "\n${BLUE}项目位置:${NC} $PROJECT_DIR"
echo -e "${BLUE}功能总数:${NC} $TOTAL 个"
echo -e "\n${YELLOW}下一步:${NC}"
echo -e "  cd $PROJECT_DIR"
echo -e "  claude  # 启动 Claude Code，Agent 将自动开始工作"
echo -e "\n${BLUE}提示:${NC} Agent 会自动读取 .agent/ 目录中的文件，按功能逐个完成开发。"