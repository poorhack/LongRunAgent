#!/bin/bash

# ============================================
# 整体功能测试脚本
# 用途: 在所有功能开发完成后执行整体功能测试
# ============================================

# 不使用 set -e，手动处理错误
# set -e

# 默认值
PROJECT_DIR="."
FIX_ON_FAILURE=false
MAX_FIX_ATTEMPTS=3

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --fix)
            FIX_ON_FAILURE=true
            shift
            ;;
        --max-fix-attempts)
            MAX_FIX_ATTEMPTS="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  -p, --project <目录>        项目目录 (默认: 当前目录)"
            echo "  --fix                       测试失败时尝试自动修复"
            echo "  --max-fix-attempts <次数>   最大修复尝试次数 (默认: 3)"
            echo "  -h, --help                  显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                              # 执行测试"
            echo "  $0 --fix                        # 测试失败时尝试修复"
            echo "  $0 -p /path/to/project --fix    # 指定项目目录并启用修复"
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
FEATURES_FILE="$PROJECT_DIR/.agent/features.json"
if [[ ! -f "$FEATURES_FILE" ]]; then
    echo -e "${RED}错误: 未找到 .agent/features.json 文件${NC}"
    exit 1
fi

# 测试结果文件
TEST_RESULTS_FILE="$PROJECT_DIR/.agent/test-results.json"
TEST_LOG_DIR="$PROJECT_DIR/.agent/logs"
mkdir -p "$TEST_LOG_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_LOG_FILE="$TEST_LOG_DIR/test-$TIMESTAMP.log"

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[$timestamp] [$level] $message"
    echo "$log_line" >> "$TEST_LOG_FILE"
    case $level in
        INFO) echo -e "${BLUE}$log_line${NC}" ;;
        SUCCESS) echo -e "${GREEN}$log_line${NC}" ;;
        ERROR) echo -e "${RED}$log_line${NC}" ;;
        WARN) echo -e "${YELLOW}$log_line${NC}" ;;
        *) echo "$log_line" ;;
    esac
}

log_info() { log "INFO" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_error() { log "ERROR" "$1"; }
log_warn() { log "WARN" "$1"; }

# 读取测试用例
get_integration_tests() {
    if command -v python3 &>/dev/null; then
        python3 - "$FEATURES_FILE" << 'PYEOF'
import json
import sys
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    tests = data.get('integration_tests', [])
    for test in tests:
        print(f"{test['id']}|{test.get('name', test['id'])}|{test.get('command', '')}|{test.get('critical', False)}|{test.get('description', '')}")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
    else
        echo "ERROR: python3 is required" >&2
        exit 1
    fi
}

# 更新测试状态到 features.json
update_test_status() {
    local status="$1"
    local summary="$2"

    if command -v python3 &>/dev/null; then
        python3 << PYEOF
import json
with open('$FEATURES_FILE', 'r') as f:
    data = json.load(f)

if 'integration_test' not in data:
    data['integration_test'] = {}

data['integration_test']['status'] = '$status'
data['integration_test']['executed_at'] = '$(date -Iseconds)'
data['integration_test']['log_file'] = '$TEST_LOG_FILE'
data['integration_test']['summary'] = '''$summary'''

with open('$FEATURES_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
    fi
}

# 执行单个测试用例
run_single_test() {
    local test_id="$1"
    local test_name="$2"
    local test_command="$3"
    local test_critical="$4"
    local test_desc="$5"

    log_info "执行测试: [$test_id] $test_name" >&2
    log_info "  描述: $test_desc" >&2
    log_info "  命令: $test_command" >&2

    # 切换到项目目录执行测试
    cd "$PROJECT_DIR"

    # 执行测试命令
    local start_time=$(date +%s)
    local output_file=$(mktemp)

    if eval "$test_command" > "$output_file" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "  测试通过 (${duration}s)" >&2
        rm -f "$output_file"
        echo "pass|$duration"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local error_output=$(cat "$output_file" | tr '\n' ' ' | sed 's/"/\\"/g' | head -c 500)
        log_error "  测试失败 (${duration}s)" >&2
        log_error "  错误输出:" >&2
        cat "$output_file" | head -20 | while read line; do
            log_error "    $line" >&2
        done
        rm -f "$output_file"
        echo "fail|$duration|$error_output"
    fi
}

# 诊断失败原因并尝试修复
diagnose_and_fix() {
    local failed_tests="$1"
    local fix_attempt="$2"

    log_warn "========== 开始诊断和修复 (尝试 $fix_attempt/$MAX_FIX_ATTEMPTS) =========="

    # 收集失败信息
    local diagnosis_file=$(mktemp)
    echo "失败的测试用例:" > "$diagnosis_file"
    echo "$failed_tests" >> "$diagnosis_file"
    echo "" >> "$diagnosis_file"

    # 写入详细错误信息
    while IFS='|' read -r test_id test_name test_command test_critical error_output; do
        echo "[$test_id] $test_name" >> "$diagnosis_file"
        echo "命令: $test_command" >> "$diagnosis_file"
        echo "错误: $error_output" >> "$diagnosis_file"
        echo "" >> "$diagnosis_file"
    done <<< "$failed_tests"

    log_info "诊断信息已收集，尝试调用 Claude 进行修复..."

    cd "$PROJECT_DIR"

    # 调用 Claude 进行诊断和修复
    local prompt="你是一个专业的软件工程师。以下是测试失败的诊断信息，请分析问题原因并修复代码。

$(cat "$diagnosis_file")

请执行以下步骤:
1. 分析错误日志，定位问题根因
2. 检查相关代码文件
3. 修复问题代码
4. 不要修改测试用例本身，只修复代码逻辑

完成后使用 /exit 退出。"

    rm -f "$diagnosis_file"

    # 执行 Claude 进行修复
    if claude "$prompt"; then
        log_info "Claude 修复执行完成"
        return 0
    else
        log_error "Claude 执行失败"
        return 1
    fi
}

# ==================== 主流程 ====================

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║            整体功能测试 - Integration Test                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

log_info "========== 整体功能测试启动 =========="
log_info "项目目录: $PROJECT_DIR"
log_info "特性文件: $FEATURES_FILE"
log_info "日志文件: $TEST_LOG_FILE"

# 获取测试用例
log_info "读取测试用例..."
tests_output=$(get_integration_tests 2>&1)

if [[ "$tests_output" == ERROR* ]]; then
    log_error "读取测试用例失败: $tests_output"
    update_test_status "error" "无法读取测试用例"
    exit 1
fi

if [[ -z "$tests_output" ]]; then
    log_warn "未定义任何测试用例 (integration_tests 为空)"
    log_info "跳过测试，标记为通过"
    update_test_status "skipped" "未定义测试用例"
    # 直接写入空结果
    echo '{"timestamp": "'$(date -Iseconds)'", "project_dir": "'$PROJECT_DIR'", "summary": {"total": 0, "passed": 0, "failed": 0, "success_rate": 0}, "tests": []}' > "$TEST_RESULTS_FILE"
    exit 0
fi

# 解析测试用例
declare -a test_ids
declare -a test_names
declare -a test_commands
declare -a test_criticals
declare -a test_descs

while IFS='|' read -r id name command critical desc; do
    test_ids+=("$id")
    test_names+=("$name")
    test_commands+=("$command")
    test_criticals+=("$critical")
    test_descs+=("$desc")
done <<< "$tests_output"

total_tests=${#test_ids[@]}
log_info "共发现 $total_tests 个测试用例"

# 测试统计
total=0
passed=0
failed=0
failed_tests_info=""
TEST_RESULTS_TEMP=$(mktemp)

# 执行测试循环（支持修复后重试）
fix_attempt=0
all_passed=false

while [[ $fix_attempt -le $MAX_FIX_ATTEMPTS ]]; do
    if [[ $fix_attempt -gt 0 ]]; then
        log_info "重新执行测试 (修复后第 $fix_attempt 次尝试)..."
    fi

    total=0
    passed=0
    failed=0
    failed_tests_info=""
    echo "[]" > "$TEST_RESULTS_TEMP"

    for ((i=0; i<total_tests; i++)); do
        total=$((total + 1))

        result=$(run_single_test "${test_ids[$i]}" "${test_names[$i]}" "${test_commands[$i]}" "${test_criticals[$i]}" "${test_descs[$i]}")
        status=$(echo "$result" | cut -d'|' -f1)
        duration=$(echo "$result" | cut -d'|' -f2)

        if [[ "$status" == "pass" ]]; then
            passed=$((passed + 1))
            # 使用 Python 添加测试结果
            python3 - "$TEST_RESULTS_TEMP" "${test_ids[$i]}" "${test_names[$i]}" "passed" "$duration" "${test_criticals[$i]}" "" << 'PYEOF' 2>/dev/null
import json
import sys

results_file = sys.argv[1]
test_id = sys.argv[2]
test_name = sys.argv[3]
status = sys.argv[4]
duration = int(sys.argv[5])
critical = sys.argv[6].lower() == 'true'
error = sys.argv[7] if len(sys.argv) > 7 else ""

with open(results_file, 'r') as f:
    results = json.load(f)

results.append({
    "id": test_id,
    "name": test_name,
    "status": status,
    "duration": duration,
    "critical": critical,
    "error": error
})

with open(results_file, 'w') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
PYEOF
        else
            failed=$((failed + 1))
            error_output=$(echo "$result" | cut -d'|' -f3- | head -c 200)
            failed_tests_info+="${test_ids[$i]}|${test_names[$i]}|${test_commands[$i]}|${test_criticals[$i]}|$error_output"$'\n'
            # 使用 Python 添加测试结果
            python3 - "$TEST_RESULTS_TEMP" "${test_ids[$i]}" "${test_names[$i]}" "failed" "$duration" "${test_criticals[$i]}" "$error_output" << 'PYEOF' 2>/dev/null
import json
import sys

results_file = sys.argv[1]
test_id = sys.argv[2]
test_name = sys.argv[3]
status = sys.argv[4]
duration = int(sys.argv[5])
critical = sys.argv[6].lower() == 'true'
error = sys.argv[7] if len(sys.argv) > 7 else ""

with open(results_file, 'r') as f:
    results = json.load(f)

results.append({
    "id": test_id,
    "name": test_name,
    "status": status,
    "duration": duration,
    "critical": critical,
    "error": error
})

with open(results_file, 'w') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
PYEOF
        fi
    done

    # 检查是否全部通过
    if [[ $failed -eq 0 ]]; then
        all_passed=true
        break
    fi

    # 如果启用了修复且还有修复次数
    if [[ "$FIX_ON_FAILURE" == "true" && $fix_attempt -lt $MAX_FIX_ATTEMPTS ]]; then
        fix_attempt=$((fix_attempt + 1))
        if diagnose_and_fix "$failed_tests_info" "$fix_attempt"; then
            log_info "修复完成，准备重新测试..."
        else
            log_error "修复失败，无法继续尝试"
            break
        fi
    else
        break
    fi
done

# 输出测试结果
echo ""
echo -e "${BLUE}========== 测试结果 ==========${NC}"
echo "总计: $total 个测试"
echo -e "通过: ${GREEN}$passed${NC} 个"
echo -e "失败: ${RED}$failed${NC} 个"
if [[ $total -gt 0 ]]; then
    success_rate=$(echo "scale=2; $passed * 100 / $total" | bc)
    echo "成功率: ${success_rate}%"
fi

# 生成最终测试结果文件
python3 - "$TEST_RESULTS_TEMP" "$TEST_RESULTS_FILE" "$PROJECT_DIR" "$total" "$passed" "$failed" << 'PYEOF' 2>/dev/null
import json
import sys
from datetime import datetime

temp_file = sys.argv[1]
output_file = sys.argv[2]
project_dir = sys.argv[3]
total = int(sys.argv[4])
passed = int(sys.argv[5])
failed = int(sys.argv[6])

with open(temp_file, 'r') as f:
    tests = json.load(f)

results = {
    "timestamp": datetime.now().isoformat(),
    "project_dir": project_dir,
    "summary": {
        "total": total,
        "passed": passed,
        "failed": failed,
        "success_rate": round(passed / total * 100, 2) if total > 0 else 0
    },
    "tests": tests
}

with open(output_file, 'w') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
PYEOF

rm -f "$TEST_RESULTS_TEMP"
log_info "测试结果已保存到: $TEST_RESULTS_FILE"

# 更新状态并返回
if [[ "$all_passed" == "true" ]]; then
    update_test_status "passed" "所有测试通过 ($passed/$total)"
    log_success "========== 整体测试通过 =========="
    exit 0
else
    update_test_status "failed" "测试失败: $passed 通过, $failed 失败"
    log_error "========== 整体测试失败 =========="

    # 输出失败的测试
    if [[ -n "$failed_tests_info" ]]; then
        echo ""
        log_error "失败的测试用例:"
        while IFS='|' read -r id name _ _ _; do
            [[ -n "$id" ]] && log_error "  - [$id] $name"
        done <<< "$failed_tests_info"
    fi

    exit 1
fi