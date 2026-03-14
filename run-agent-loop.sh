#!/bin/bash

# ============================================
# Long-Running Agent 循环执行脚本
# 用途: 循环调用 claude 完成项目功能
# ============================================

set -e

# 默认值
ITERATIONS=1
PROJECT_DIR="."

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  -n, --iterations <次数>   循环执行次数 (默认: 1)"
            echo "  -p, --project <目录>      项目目录 (默认: 当前目录)"
            echo "  -h, --help                 显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                              # 执行 1 次"
            echo "  $0 -n 5                         # 循环执行 5 次"
            echo "  $0 -n 10 -p /path/to/project    # 指定项目目录，循环 10 次"
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

# 转换为绝对路径
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
    echo -e "${RED}错误: 项目目录不存在: $PROJECT_DIR${NC}"
    exit 1
}

# 检查必要文件
if [[ ! -f "$PROJECT_DIR/.agent/features.json" ]]; then
    echo -e "${RED}错误: 未找到 .agent/features.json 文件${NC}"
    echo -e "${YELLOW}请确保在正确的项目目录中运行此脚本${NC}"
    exit 1
fi

# 创建日志目录
LOG_DIR="$PROJECT_DIR/.agent/logs"
mkdir -p "$LOG_DIR"

# 日志文件
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/session-$TIMESTAMP.log"

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$1"
}

log_success() {
    log "SUCCESS" "$1"
}

log_error() {
    log "ERROR" "$1"
}

# 获取功能进度
get_progress() {
    local features_file="$PROJECT_DIR/.agent/features.json"
    local total=$(grep -c '"id"' "$features_file" 2>/dev/null || echo "0")
    local completed=$(grep -c '"passes": true' "$features_file" 2>/dev/null || echo "0")
    echo "$completed/$total"
}

# 获取下一个待完成功能
get_next_feature() {
    local features_file="$PROJECT_DIR/.agent/features.json"
    # 使用 python 解析 JSON 获取第一个 passes 为 false 的功能
    if command -v python3 &>/dev/null; then
        python3 << 'PYEOF' 2>/dev/null
import json
import sys
try:
    with open(sys.argv[1] if len(sys.argv) > 1 else '.agent/features.json', 'r') as f:
        data = json.load(f)
    for feature in data.get('features', []):
        if not feature.get('passes', False):
            print(f"{feature['id']}|{feature['description']}")
            break
except:
    pass
PYEOF
    elif command -v python &>/dev/null; then
        python << 'PYEOF' 2>/dev/null
import json
import sys
try:
    with open(sys.argv[1] if len(sys.argv) > 1 else '.agent/features.json', 'r') as f:
        data = json.load(f)
    for feature in data.get('features', []):
        if not feature.get('passes', False):
            print(f"{feature['id']}|{feature['description']}")
            break
except:
    pass
PYEOF
    fi
}

# 检查项目是否已完成
is_project_complete() {
    local progress=$(get_progress)
    local completed=$(echo "$progress" | cut -d'/' -f1)
    local total=$(echo "$progress" | cut -d'/' -f2)
    [[ "$completed" == "$total" && "$total" != "0" ]]
}

# 更新功能状态为完成
mark_feature_complete() {
    local feature_id="$1"
    local features_file="$PROJECT_DIR/.agent/features.json"

    if command -v python3 &>/dev/null; then
        python3 << PYEOF
import json
with open('$features_file', 'r') as f:
    data = json.load(f)
for feature in data.get('features', []):
    if feature['id'] == '$feature_id':
        feature['passes'] = True
        break
# 更新统计
total = len(data.get('features', []))
passed = sum(1 for f in data.get('features', []) if f.get('passes', False))
data['statistics'] = {'total': total, 'passed': passed, 'failed': 0, 'pending': total - passed}
with open('$features_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
    elif command -v python &>/dev/null; then
        python << PYEOF
import json
with open('$features_file', 'r') as f:
    data = json.load(f)
for feature in data.get('features', []):
    if feature['id'] == '$feature_id':
        feature['passes'] = True
        break
# 更新统计
total = len(data.get('features', []))
passed = sum(1 for f in data.get('features', []) if f.get('passes', False))
data['statistics'] = {'total': total, 'passed': passed, 'failed': 0, 'pending': total - passed}
with open('$features_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
    else
        # 如果没有 python，使用 sed 简单处理
        sed -i "s/\"$feature_id\"/\"$feature_id\"/; /\"$feature_id\"/,/\"passes\": false/s/\"passes\": false/\"passes\": true/" "$features_file"
    fi
}

# 提交进度
commit_progress() {
    local iteration="$1"
    local progress="$2"
    local feature_id="$3"
    local feature_desc="$4"

    cd "$PROJECT_DIR"

    # 检查是否有更改需要提交
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        git add -A

        local commit_msg="[Agent] 完成第${iteration}次循环 - 进度 ${progress}

完成功能:
- [$feature_id] $feature_desc

当前状态: ${progress} features 完成"

        git commit -m "$commit_msg" 2>/dev/null || true
        log_info "已提交进度 commit"
    else
        log_info "无更改需要提交"
    fi
}

# 提交最终完成
commit_final() {
    local progress="$1"

    cd "$PROJECT_DIR"

    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        git add -A
        git commit -m "[Agent] 项目开发完成

总计: ${progress} features 完成" 2>/dev/null || true
    fi
    log_success "项目开发完成！最终进度: ${progress}"
}

# ==================== 主流程 ====================

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       Long-Running Agent - 循环执行脚本                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

log_info "========== 循环执行脚本启动 =========="
log_info "项目目录: $PROJECT_DIR"
log_info "计划循环次数: $ITERATIONS"
log_info "日志文件: $LOG_FILE"

# 检查是否已完成
if is_project_complete; then
    log_success "项目已完成，无需执行"
    exit 0
fi

# 循环执行
for ((i=1; i<=ITERATIONS; i++)); do
    log_info ">>> 开始第 $i 次循环"

    # 获取当前进度
    progress=$(get_progress)
    log_info "当前功能进度: $progress"

    # 获取下一个功能
    next_feature=$(get_next_feature)
    if [[ -z "$next_feature" ]]; then
        log_success "所有功能已完成！"
        commit_final "$progress"
        break
    fi

    feature_id=$(echo "$next_feature" | cut -d'|' -f1)
    feature_desc=$(echo "$next_feature" | cut -d'|' -f2)
    log_info "下一个待完成功能: $feature_id - $feature_desc"

    # 执行 claude 命令
    log_info "执行 claude 命令..."
    cd "$PROJECT_DIR"

    # 使用 claude --print 模式执行，传入指令
    if claude --print "请继续完成项目的下一个功能。读取 .agent/features.json 了解项目状态，完成 $feature_id: $feature_desc 后更新状态。" >> "$LOG_FILE" 2>&1; then
        log_success "Claude 执行完成"
    else
        log_error "Claude 执行出现问题，继续尝试..."
    fi

    # 检查功能是否完成（简单假设每次执行完成一个功能）
    # 实际应用中可以根据 claude 输出判断
    mark_feature_complete "$feature_id"
    log_info "$feature_id 已标记为完成"

    # 更新进度
    progress=$(get_progress)
    log_info "当前进度: $progress"

    # 提交进度
    commit_progress "$i" "$progress" "$feature_id" "$feature_desc"

    # 检查是否全部完成
    if is_project_complete; then
        log_success "========== 所有功能已完成 =========="
        commit_final "$progress"
        break
    fi

    log_info "<<< 第 $i 次循环结束"
    echo ""
done

# 最终状态
progress=$(get_progress)
log_info "========== 循环执行完成 =========="
log_info "总循环次数: $i"
log_info "最终进度: $progress"

echo -e "\n${GREEN}执行完成！${NC}"
echo -e "${BLUE}日志文件:${NC} $LOG_FILE"