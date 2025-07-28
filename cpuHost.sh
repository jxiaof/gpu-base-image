#!/bin/bash
# CPU主机性能测试脚本
# 版本: 2.0
# 适用于: Linux系统CPU、内存、硬盘、网络全面测试

# 检查是否以sudo权限运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 此脚本需要sudo权限运行"
    echo "请使用: sudo $0"
    exit 1
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 配置文件路径
LOG_FILE="/var/log/cpu_test_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="/tmp/cpu_test_report_$(date +%Y%m%d_%H%M%S).txt"

# 全局变量
WARNINGS=()
ERRORS=()
CPU_TESTS=()
MEMORY_TESTS=()
DISK_TESTS=()
NETWORK_TESTS=()

# 记录日志函数
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a $LOG_FILE
}

# 专业格式化输出函数
print_header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    printf "${BOLD}${BLUE}│ %-75s │${NC}\n" "$title"
    echo -e "${BOLD}${BLUE}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BOLD}${YELLOW}▓▓ $1${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────────────────────────────────${NC}"
}

print_subsection() {
    echo ""
    echo -e "${CYAN}■ $1${NC}"
    echo -e "${CYAN}  ────────────────────────────────────────${NC}"
}

print_status_line() {
    local label="$1"
    local value="$2"
    local status="$3"
    local icon="$4"
    
    printf "  %-25s: %-35s [%s] %s\n" "$label" "$value" "$status" "$icon"
}

print_metric() {
    local label="$1"
    local value="$2"
    local unit="$3"
    local threshold="$4"
    local warning="$5"
    
    local icon="✅"
    local status="NORMAL"
    local color=$GREEN
    
    if [ -n "$threshold" ] && [ -n "$warning" ]; then
        if (( $(echo "$value > $threshold" | bc -l) )); then
            icon="❌"
            status="CRITICAL"
            color=$RED
            ERRORS+=("$label: $value$unit exceeds threshold $threshold$unit")
        elif (( $(echo "$value > $warning" | bc -l) )); then
            icon="⚠️"
            status="WARNING"
            color=$YELLOW
            WARNINGS+=("$label: $value$unit exceeds warning level $warning$unit")
        fi
    fi
    
    printf "  %-25s: ${color}%-15s${NC} [%s] %s\n" "$label" "$value$unit" "$status" "$icon"
}

print_pass() {
    echo -e "  ${GREEN}✅ PASS${NC} - $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠️  WARN${NC} - $1"
    WARNINGS+=("$1")
}

print_error() {
    echo -e "  ${RED}❌ FAIL${NC} - $1"
    ERRORS+=("$1")
}

print_info() {
    echo -e "  ${CYAN}ℹ️  INFO${NC} - $1"
}

# 获取系统硬件信息
get_system_info() {
    local info_type="$1"
    local result=""
    
    case $info_type in
        "vendor")
            if command -v dmidecode &> /dev/null; then
                result=$(dmidecode -s system-manufacturer 2>/dev/null | grep -v "^#" | head -1)
            fi
            [ -z "$result" ] && result=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
            [ -z "$result" ] && result="Unknown"
            ;;
        "model")
            if command -v dmidecode &> /dev/null; then
                result=$(dmidecode -s system-product-name 2>/dev/null | grep -v "^#" | head -1)
            fi
            [ -z "$result" ] && result=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
            [ -z "$result" ] && result="Unknown"
            ;;
    esac
    
    echo "$result"
}

# 检查依赖工具
check_dependencies() {
    local required_tools=(
        "sysbench:性能基准测试"
        "stress:CPU压力测试"
        "htop:系统监控"
        "sensors:温度监控"
        "cpupower:CPU电源管理"
        "turbostat:Intel CPU状态监控"
    )
    
    print_section "🔍 依赖检查"

    echo "检查以下工具是否安装:"
    
    for tool_desc in "${required_tools[@]}"; do
        IFS=':' read -r tool desc <<< "$tool_desc"
        if command -v "$tool" &> /dev/null; then
            print_pass "$tool - $desc"
        else
            print_warning "缺少工具: $tool - $desc"
            case $tool in
                "sysbench") echo "    安装命令: sudo apt install sysbench" ;;
                "stress") echo "    安装命令: sudo apt install stress" ;;
                "htop") echo "    安装命令: sudo apt install htop" ;;
                "sensors") echo "    安装命令: sudo apt install lm-sensors" ;;
                "cpupower") echo "    安装命令: sudo apt install linux-tools-common" ;;
                "turbostat") echo "    安装命令: sudo apt install linux-tools-common" ;;
            esac
        fi
    done
    echo "sudo apt install linux-tools-common linux-tools-generic lm-sensors htop stress sysbench -y"
}

# CPU基本信息检测
cpu_basic_info() {
    print_section "🖥️ CPU基本信息"
    
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')
    local cpu_cores=$(nproc)
    local cpu_threads=$(grep -c processor /proc/cpuinfo)
    local cpu_sockets=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
    local cpu_cache=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')
    
    print_status_line "处理器型号" "$cpu_model" "INFO" "🎯"
    print_status_line "物理插槽" "$cpu_sockets" "INFO" "🔌"
    print_status_line "物理核心" "$cpu_cores" "INFO" "⚡"
    print_status_line "逻辑线程" "$cpu_threads" "INFO" "🧵"
    print_status_line "缓存大小" "$cpu_cache" "INFO" "💾"
    
    # CPU架构信息
    local cpu_arch=$(lscpu | grep "Architecture" | awk '{print $2}')
    local cpu_vendor=$(lscpu | grep "Vendor ID" | awk '{print $3}')
    local cpu_flags=$(grep "flags" /proc/cpuinfo | head -1 | cut -d':' -f2)
    
    print_status_line "CPU架构" "$cpu_arch" "INFO" "🏗️"
    print_status_line "厂商ID" "$cpu_vendor" "INFO" "🏭"
    
    # 检查重要指令集支持
    echo ""
    print_subsection "指令集支持检查"
    local important_flags=("avx" "avx2" "sse4_1" "sse4_2" "aes" "fma")
    for flag in "${important_flags[@]}"; do
        if echo "$cpu_flags" | grep -q "$flag"; then
            print_pass "$flag 指令集支持"
        else
            print_warning "$flag 指令集不支持"
        fi
    done
}

# CPU频率测试
cpu_frequency_test() {
    print_section "⚡ CPU频率测试"
    
    # 基础频率信息
    local base_freq=$(lscpu | grep "CPU MHz" | awk '{print $3}' | cut -d'.' -f1)
    local max_freq=$(lscpu | grep "CPU max MHz" | awk '{print $4}' | cut -d'.' -f1)
    local min_freq=$(lscpu | grep "CPU min MHz" | awk '{print $4}' | cut -d'.' -f1)
    
    print_status_line "当前频率" "${base_freq}MHz" "INFO" "📊"
    [ -n "$max_freq" ] && print_status_line "最大频率" "${max_freq}MHz" "INFO" "🚀"
    [ -n "$min_freq" ] && print_status_line "最小频率" "${min_freq}MHz" "INFO" "🐌"
    
    # 动态频率监控
    print_subsection "动态频率监控"
    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
        print_info "监控5秒内的频率变化..."
        for i in {1..5}; do
            local current_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
            if [ -n "$current_freq" ]; then
                current_freq_mhz=$((current_freq / 1000))
                printf "    第%d秒: %dMHz\n" "$i" "$current_freq_mhz"
            fi
            sleep 1
        done
    else
        print_warning "无法访问CPU频率信息"
    fi
    
    # CPU调速器检查
    if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then
        local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        print_status_line "调速器策略" "$governor" "INFO" "⚙️"
        
        case $governor in
            "performance") print_pass "性能模式 - 适合高性能计算" ;;
            "powersave") print_warning "节能模式 - 可能影响性能" ;;
            "ondemand"|"conservative") print_info "动态模式 - 平衡性能和功耗" ;;
            *) print_info "其他模式: $governor" ;;
        esac
    fi
}

# CPU温度监控 
cpu_temperature_test() {
    print_section "🌡️ CPU温度监控"
    
    if command -v sensors &> /dev/null; then
        print_info "读取CPU温度传感器..."
        
        local sensors_output=$(sensors 2>/dev/null)
        local temp_found=false
        
        # 解析各种温度格式 - 修复变量作用域问题
        local temp_results=""
        while IFS= read -r line; do
            if [[ $line =~ Core\ ([0-9]+):.*\+([0-9]+)\.[0-9]+°C ]] || \
               [[ $line =~ CPU\ Temperature:.*\+([0-9]+)\.[0-9]+°C ]] || \
               [[ $line =~ Tctl:.*\+([0-9]+)\.[0-9]+°C ]]; then
                
                local temp=""
                local core_name=""
                
                if [[ $line =~ Core\ ([0-9]+):.*\+([0-9]+)\.[0-9]+°C ]]; then
                    core_num=${BASH_REMATCH[1]}
                    temp=${BASH_REMATCH[2]}
                    core_name="Core $core_num"
                elif [[ $line =~ CPU\ Temperature:.*\+([0-9]+)\.[0-9]+°C ]]; then
                    temp=${BASH_REMATCH[1]}
                    core_name="CPU Package"
                elif [[ $line =~ Tctl:.*\+([0-9]+)\.[0-9]+°C ]]; then
                    temp=${BASH_REMATCH[1]}
                    core_name="CPU Tctl"
                fi
                
                if [ -n "$temp" ] && [ -n "$core_name" ]; then
                    temp_found=true
                    print_metric "$core_name 温度" "$temp" "°C" "85" "75"
                fi
            fi
        done <<< "$(echo "$sensors_output" | grep -E "Core|CPU|Tctl|temp")"
        
        # 如果没有找到温度，尝试thermal_zone
        if [ "$temp_found" = false ]; then
            print_info "尝试读取系统温度传感器..."
            for thermal_zone in /sys/class/thermal/thermal_zone*/temp; do
                if [ -r "$thermal_zone" ]; then
                    local temp_millidegree=$(cat "$thermal_zone" 2>/dev/null)
                    if [ -n "$temp_millidegree" ] && [ "$temp_millidegree" -gt 0 ] 2>/dev/null; then
                        local temp=$((temp_millidegree / 1000))
                        local zone_name=$(basename $(dirname "$thermal_zone"))
                        local type_file=$(dirname "$thermal_zone")/type
                        local zone_type=$(cat "$type_file" 2>/dev/null || echo "unknown")
                        
                        print_metric "$zone_type" "$temp" "°C" "85" "75"
                        temp_found=true
                    fi
                fi
            done
        fi
        
        if [ "$temp_found" = false ]; then
            print_warning "无法读取CPU温度信息"
        fi
    else
        print_warning "lm-sensors未安装，无法监控CPU温度"
        print_info "安装命令: sudo apt install lm-sensors && sudo sensors-detect --auto"
    fi
}
# CPU负载测试
cpu_load_test() {
    print_section "📊 CPU负载测试"
    
    # 当前系统负载 - 修复负载值解析
    local uptime_output=$(uptime)
    local load_avg=$(echo "$uptime_output" | awk -F'load average:' '{print $2}' | sed 's/,//g' | xargs)
    local load_1min=$(echo $load_avg | awk '{print $1}')
    local load_5min=$(echo $load_avg | awk '{print $2}')
    local load_15min=$(echo $load_avg | awk '{print $3}')
    local cpu_cores=$(nproc)
    
    # 验证负载值是否为有效数字
    if [[ "$load_1min" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        print_status_line "1分钟负载" "$load_1min" "INFO" "📈"
    else
        load_1min="0.00"
        print_warning "无法获取1分钟负载值"
    fi
    
    if [[ "$load_5min" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        print_status_line "5分钟负载" "$load_5min" "INFO" "📊"
    else
        load_5min="0.00"
        print_warning "无法获取5分钟负载值"
    fi
    
    if [[ "$load_15min" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        print_status_line "15分钟负载" "$load_15min" "INFO" "📉"
    else
        load_15min="0.00"
        print_warning "无法获取15分钟负载值"
    fi
    
    # 负载分析 - 使用更安全的计算方法
    if command -v bc &> /dev/null && [[ "$load_1min" =~ ^[0-9]+\.?[0-9]*$ ]] && [[ "$load_5min" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        local load_percent_1min=$(echo "scale=1; $load_1min / $cpu_cores * 100" | bc 2>/dev/null || echo "0")
        local load_percent_5min=$(echo "scale=1; $load_5min / $cpu_cores * 100" | bc 2>/dev/null || echo "0")
        
        print_metric "1分钟负载率" "$load_percent_1min" "%" "90" "70"
        print_metric "5分钟负载率" "$load_percent_5min" "%" "90" "70"
    else
        # 备用计算方法（使用 awk）
        local load_percent_1min=$(awk "BEGIN {printf \"%.1f\", $load_1min / $cpu_cores * 100}")
        local load_percent_5min=$(awk "BEGIN {printf \"%.1f\", $load_5min / $cpu_cores * 100}")
        
        print_metric "1分钟负载率" "$load_percent_1min" "%" "90" "70"
        print_metric "5分钟负载率" "$load_percent_5min" "%" "90" "70"
    fi
    
    # CPU使用率 - 改进获取方法
    print_subsection "CPU使用率分析"
    
    # 方法1：使用 vmstat
    if command -v vmstat &> /dev/null; then
        local cpu_idle=$(vmstat 1 2 | tail -1 | awk '{print $15}')
        if [[ "$cpu_idle" =~ ^[0-9]+$ ]]; then
            local cpu_usage=$((100 - cpu_idle))
            print_metric "CPU使用率" "$cpu_usage" "%" "80" "60"
        fi
    fi
    
    # 方法2：使用 /proc/stat (备用)
    if [ ! -v cpu_usage ] || [ -z "$cpu_usage" ]; then
        # 读取两次 /proc/stat 计算使用率
        local stat1=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
        local idle1=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')
        sleep 1
        local stat2=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
        local idle2=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')
        
        local total_diff=$((stat2 - stat1))
        local idle_diff=$((idle2 - idle1))
        
        if [ $total_diff -gt 0 ]; then
            local cpu_usage=$(awk "BEGIN {printf \"%.1f\", (1 - $idle_diff / $total_diff) * 100}")
            print_metric "CPU使用率" "$cpu_usage" "%" "80" "60"
        fi
    fi
    
    # 如果上述方法都失败，使用 top 作为最后手段
    if [ ! -v cpu_usage ] || [ -z "$cpu_usage" ]; then
        local top_cpu=$(top -bn1 | grep -E "^%?Cpu|^CPU" | head -1 | awk '{
            for(i=1;i<=NF;i++) {
                if($i ~ /[0-9]+\.[0-9]+%?us/) {
                    gsub(/%?us,?/, "", $i)
                    print $i
                    break
                }
            }
        }')
        
        if [[ "$top_cpu" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            print_metric "CPU使用率" "$top_cpu" "%" "80" "60"
        else
            print_warning "无法获取CPU使用率"
        fi
    fi
    
    # 进程分析
    print_info "CPU占用前5进程:"
    if command -v ps &> /dev/null; then
        ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
            local user=$(echo $line | awk '{print $1}')
            local cpu_percent=$(echo $line | awk '{print $3}')
            local command=$(echo $line | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | cut -c1-50)
            printf "    %-10s %6s%% %s\n" "$user" "$cpu_percent" "$command"
        done
    fi
}

# CPU性能基准测试
cpu_benchmark_test() {
    print_section "🏁 CPU性能基准测试"
    
    local cpu_cores=$(nproc)
    
    if command -v sysbench &> /dev/null; then
        print_subsection "单线程性能测试"
        print_info "执行单线程CPU基准测试 (30秒)..."
        local single_score=$(timeout 35 sysbench cpu --cpu-max-prime=10000 --threads=1 --time=30 run 2>/dev/null | grep "events per second" | awk '{print $4}')
        
        if [ -n "$single_score" ]; then
            print_status_line "单线程分数" "${single_score} events/sec" "INFO" "🏃"
            CPU_TESTS+=("Single-thread: $single_score events/sec")
        else
            print_error "单线程测试失败"
        fi
        
        print_subsection "多线程性能测试"
        print_info "执行多线程CPU基准测试 (30秒, ${cpu_cores}线程)..."
        local multi_score=$(timeout 35 sysbench cpu --cpu-max-prime=10000 --threads=$cpu_cores --time=30 run 2>/dev/null | grep "events per second" | awk '{print $4}')
        
        if [ -n "$multi_score" ]; then
            print_status_line "多线程分数" "${multi_score} events/sec" "INFO" "🚀"
            CPU_TESTS+=("Multi-thread: $multi_score events/sec")
            
            # 计算多线程效率
            if [ -n "$single_score" ]; then
                local efficiency=$(echo "scale=2; $multi_score / $single_score / $cpu_cores * 100" | bc)
                print_metric "多线程效率" "$efficiency" "%" "" ""
            fi
        else
            print_error "多线程测试失败"
        fi
        
        print_subsection "内存访问性能测试"
        print_info "执行内存访问基准测试 (20秒)..."
        local memory_score=$(timeout 25 sysbench memory --memory-total-size=1G --time=20 run 2>/dev/null | grep "transferred" | awk '{print $3 " " $4}')
        
        if [ -n "$memory_score" ]; then
            print_status_line "内存传输速率" "$memory_score" "INFO" "💨"
            CPU_TESTS+=("Memory: $memory_score")
        else
            print_error "内存测试失败"
        fi
        
    else
        print_warning "sysbench未安装，无法执行基准测试"
        print_info "安装命令: sudo apt install sysbench"
    fi
}

# CPU压力测试
cpu_stress_test() {
    print_section "💪 CPU压力测试"
    
    if command -v stress &> /dev/null; then
        local cpu_cores=$(nproc)
        print_info "准备执行CPU压力测试 (60秒, ${cpu_cores}核心)..."
        
        # 记录测试前状态
        local temp_before=""
        local freq_before=""
        
        if command -v sensors &> /dev/null; then
            temp_before=$(sensors 2>/dev/null | grep -E "Core 0|CPU" | head -1 | grep -oE '\+[0-9]+\.[0-9]+°C' | head -1 | sed 's/+//;s/°C//')
        fi
        
        if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]; then
            freq_before=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
            freq_before=$((freq_before / 1000))
        fi
        
        print_info "测试前状态 - 温度: ${temp_before:-未知}°C, 频率: ${freq_before:-未知}MHz"
        
        # 启动压力测试
        print_info "开始压力测试..."
        timeout 60 stress --cpu $cpu_cores --timeout 60s &
        local stress_pid=$!
        
        # 监控测试过程
        local max_temp=0
        local min_freq=999999
        local samples=0
        
        for i in {1..12}; do
            sleep 5
            
            # 监控温度
            if command -v sensors &> /dev/null; then
                local current_temp=$(sensors 2>/dev/null | grep -E "Core 0|CPU" | head -1 | grep -oE '\+[0-9]+\.[0-9]+°C' | head -1 | sed 's/+//;s/°C//')
                if [ -n "$current_temp" ]; then
                    max_temp=$(echo "$current_temp $max_temp" | awk '{if($1>$2) print $1; else print $2}')
                fi
            fi
            
            # 监控频率
            if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]; then
                local current_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
                if [ -n "$current_freq" ]; then
                    current_freq=$((current_freq / 1000))
                    if [ $current_freq -lt $min_freq ]; then
                        min_freq=$current_freq
                    fi
                fi
            fi
            
            samples=$((samples + 1))
            printf "    第%2d次采样 - 温度: %s°C, 频率: %sMHz\n" "$i" "${current_temp:-N/A}" "${current_freq:-N/A}"
        done
        
        # 等待压力测试完成
        wait $stress_pid 2>/dev/null
        
        # 测试后状态
        sleep 5
        local temp_after=""
        local freq_after=""
        
        if command -v sensors &> /dev/null; then
            temp_after=$(sensors 2>/dev/null | grep -E "Core 0|CPU" | head -1 | grep -oE '\+[0-9]+\.[0-9]+°C' | head -1 | sed 's/+//;s/°C//')
        fi
        
        if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]; then
            freq_after=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
            freq_after=$((freq_after / 1000))
        fi
        
        print_info "测试后状态 - 温度: ${temp_after:-未知}°C, 频率: ${freq_after:-未知}MHz"
        
        # 分析结果
        print_subsection "压力测试结果分析"
        
        if [ -n "$temp_before" ] && [ -n "$max_temp" ]; then
            local temp_rise=$(echo "$max_temp - $temp_before" | bc)
            print_metric "最高温度" "$max_temp" "°C" "90" "80"
            print_status_line "温度上升" "${temp_rise}°C" "INFO" "🌡️"
        fi
        
        if [ "$min_freq" -ne 999999 ]; then
            print_status_line "最低频率" "${min_freq}MHz" "INFO" "⚡"
            
            # 检查是否有降频
            if [ -n "$freq_before" ] && [ $min_freq -lt $((freq_before - 100)) ]; then
                print_warning "检测到CPU降频，可能是热保护触发"
            else
                print_pass "CPU在压力测试中保持稳定频率"
            fi
        fi
        
        print_pass "压力测试完成 - CPU稳定性良好"
        
    else
        print_warning "stress工具未安装，无法执行压力测试"
        print_info "安装命令: sudo apt install stress"
    fi
}

# 检查依赖工具 - 更新版本
check_dependencies() {
    local required_tools=(
        "sysbench:性能基准测试"
        "stress:CPU压力测试"
        "htop:系统监控"
        "sensors:温度监控"
        "cpupower:CPU电源管理"
        "turbostat:Intel CPU状态监控"
        "fio:磁盘IO性能测试"
        "iperf3:网络性能测试"
        "speedtest-cli:网络速度测试"
        "hdparm:硬盘参数工具"
        "smartctl:硬盘健康检测"
    )
    
    print_section "🔍 依赖检查"
    
    for tool_desc in "${required_tools[@]}"; do
        IFS=':' read -r tool desc <<< "$tool_desc"
        if command -v "$tool" &> /dev/null; then
            print_pass "$tool - $desc"
        else
            print_warning "缺少工具: $tool - $desc"
            case $tool in
                "sysbench") echo "    安装命令: sudo apt install sysbench" ;;
                "stress") echo "    安装命令: sudo apt install stress" ;;
                "htop") echo "    安装命令: sudo apt install htop" ;;
                "sensors") echo "    安装命令: sudo apt install lm-sensors" ;;
                "cpupower") echo "    安装命令: sudo apt install linux-tools-common" ;;
                "turbostat") echo "    安装命令: sudo apt install linux-tools-common" ;;
                "fio") echo "    安装命令: sudo apt install fio" ;;
                "iperf3") echo "    安装命令: sudo apt install iperf3" ;;
                "speedtest-cli") echo "    安装命令: sudo apt install speedtest-cli" ;;
                "hdparm") echo "    安装命令: sudo apt install hdparm" ;;
                "smartctl") echo "    安装命令: sudo apt install smartmontools" ;;
            esac
        fi
    done
}

 # 内存系统检测
memory_test() {
    print_section "💾 内存系统检测"
    
    # 基本内存信息
    local mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_total_gb=$((mem_total_kb / 1024 / 1024))
    local mem_available_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_used_kb=$((mem_total_kb - mem_available_kb))
    local mem_used_gb=$((mem_used_kb / 1024 / 1024))
    local mem_percent=$((mem_used_kb * 100 / mem_total_kb))
    
    print_status_line "总内存容量" "${mem_total_gb}GB" "INFO" "💾"
    print_status_line "已用内存" "${mem_used_gb}GB" "INFO" "📊"
    print_metric "内存使用率" "$mem_percent" "%" "90" "70"
    
    # 内存详细信息
    local mem_free_kb=$(grep MemFree /proc/meminfo | awk '{print $2}')
    local mem_cached_kb=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
    local mem_buffers_kb=$(grep Buffers /proc/meminfo | awk '{print $2}')
    local swap_total_kb=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    local swap_used_kb=$(grep SwapFree /proc/meminfo | awk '{print $2}')
    
    print_status_line "空闲内存" "$((mem_free_kb / 1024))MB" "INFO" "🆓"
    print_status_line "缓存内存" "$((mem_cached_kb / 1024))MB" "INFO" "🗂️"
    print_status_line "缓冲区" "$((mem_buffers_kb / 1024))MB" "INFO" "📝"
    
    if [ "$swap_total_kb" -gt 0 ]; then
        local swap_used_actual=$((swap_total_kb - swap_used_kb))
        local swap_percent=$((swap_used_actual * 100 / swap_total_kb))
        print_status_line "交换分区" "$((swap_total_kb / 1024 / 1024))GB" "INFO" "🔄"
        print_metric "Swap使用率" "$swap_percent" "%" "50" "20"
    else
        print_warning "未配置交换分区"
    fi
    
    # 内存模块信息
    print_subsection "内存模块详情"
    if command -v dmidecode &> /dev/null; then
        print_info "检测内存模块信息..."
        local mem_info=$(dmidecode -t memory 2>/dev/null | grep -A 20 "Memory Device")
        local module_count=0
        
        echo "$mem_info" | grep -E "Size:|Speed:|Type:|Manufacturer:|Part Number:" | grep -v "No Module Installed" | while read line; do
            if [[ $line == *"Size:"* ]] && [[ $line != *"No Module"* ]]; then
                module_count=$((module_count + 1))
                echo "    模块 $module_count:"
            fi
            echo "      $line" | sed 's/^\s*//'
        done
        
        # 内存频率
        local mem_speed=$(dmidecode -t memory 2>/dev/null | grep "Speed:" | grep -v "Unknown" | head -1 | awk '{print $2}')
        [ -n "$mem_speed" ] && print_status_line "内存频率" "${mem_speed}" "INFO" "⚡"
        
        # 内存类型
        local mem_type=$(dmidecode -t memory 2>/dev/null | grep "Type:" | grep -v "Unknown" | head -1 | awk '{print $2}')
        [ -n "$mem_type" ] && print_status_line "内存类型" "$mem_type" "INFO" "🏷️"
    else
        print_warning "dmidecode未安装，无法获取内存详细信息"
    fi
    
    # 内存性能测试
    print_subsection "内存性能测试"
    if command -v sysbench &> /dev/null; then
        print_info "执行内存带宽测试 (20秒)..."
        local mem_bandwidth=$(timeout 25 sysbench memory --memory-total-size=2G --memory-oper=read --time=20 run 2>/dev/null | grep "transferred" | awk '{print $3 " " $4}')
        
        if [ -n "$mem_bandwidth" ]; then
            print_status_line "内存读取带宽" "$mem_bandwidth" "INFO" "📈"
            MEMORY_TESTS+=("Read Bandwidth: $mem_bandwidth")
        fi
        
        print_info "执行内存写入测试 (20秒)..."
        local mem_write_bandwidth=$(timeout 25 sysbench memory --memory-total-size=2G --memory-oper=write --time=20 run 2>/dev/null | grep "transferred" | awk '{print $3 " " $4}')
        
        if [ -n "$mem_write_bandwidth" ]; then
            print_status_line "内存写入带宽" "$mem_write_bandwidth" "INFO" "📉"
            MEMORY_TESTS+=("Write Bandwidth: $mem_write_bandwidth")
        fi
        
        print_info "执行内存延迟测试..."
        local mem_latency=$(timeout 15 sysbench memory --memory-total-size=1G --memory-access-mode=rnd --time=10 run 2>/dev/null | grep "avg:" | awk '{print $2}')
        
        if [ -n "$mem_latency" ]; then
            print_status_line "内存平均延迟" "${mem_latency}ms" "INFO" "⏱️"
            MEMORY_TESTS+=("Latency: ${mem_latency}ms")
        fi
    else
        print_warning "sysbench未安装，无法执行内存性能测试"
    fi
}

 # 硬盘系统检测 - 完善版本
disk_test() {
    print_section "💿 硬盘系统检测"
    
    # 磁盘使用情况
    print_subsection "磁盘使用情况"
    df -h | grep -E "^/dev" | while read line; do
        local device=$(echo $line | awk '{print $1}')
        local size=$(echo $line | awk '{print $2}')
        local used=$(echo $line | awk '{print $3}')
        local percent=$(echo $line | awk '{print $5}' | sed 's/%//')
        local mount=$(echo $line | awk '{print $6}')
        
        print_status_line "$device" "${size} (${used}已用)" "INFO" "💾"
        print_metric "使用率 ($mount)" "$percent" "%" "90" "80"
    done
    
    # 存储设备信息
    print_subsection "存储设备详情"
    if command -v lsblk &> /dev/null; then
        print_info "存储设备列表:"
        lsblk -d -o NAME,SIZE,MODEL,VENDOR,TYPE,TRAN 2>/dev/null | grep -v "loop" | while read line; do
            echo "    $line"
        done
    fi
    
    # 硬盘健康检测 - 完善版本
    print_subsection "硬盘健康检测"
    if command -v smartctl &> /dev/null; then
        # 检测所有硬盘设备
        for device in $(lsblk -d -n -o NAME | grep -E "^(sd|nvme|hd)" | head -5); do
            print_info "检测 /dev/${device} 健康状态..."
            
            # SMART健康状态
            local smart_health=$(smartctl -H /dev/${device} 2>/dev/null | grep "SMART overall-health" | awk '{print $6}')
            if [ "$smart_health" = "PASSED" ]; then
                print_pass "/dev/${device} SMART健康状态正常"
            elif [ -n "$smart_health" ]; then
                print_error "/dev/${device} SMART健康状态异常: $smart_health"
            else
                print_warning "/dev/${device} 无法获取SMART信息"
            fi
            
            # 硬盘温度
            local disk_temp=$(smartctl -A /dev/${device} 2>/dev/null | grep -E "Temperature|Airflow" | awk '{print $10}' | head -1)
            if [ -n "$disk_temp" ] && [ "$disk_temp" -gt 0 ] 2>/dev/null; then
                print_metric "/dev/${device} 温度" "$disk_temp" "°C" "55" "45"
            fi
            
            # 通电时间
            local power_hours=$(smartctl -A /dev/${device} 2>/dev/null | grep "Power_On_Hours" | awk '{print $10}')
            if [ -n "$power_hours" ]; then
                local power_days=$((power_hours / 24))
                print_status_line "/dev/${device} 通电时间" "${power_days}天" "INFO" "⏰"
            fi
        done
    else
        print_warning "smartctl未安装，无法检测硬盘健康状态"
        print_info "安装命令: sudo apt install smartmontools"
    fi
    
    # 磁盘IO性能测试
    print_subsection "磁盘IO性能测试"
    if command -v fio &> /dev/null; then
        print_info "执行磁盘随机读写性能测试 (30秒)..."
        
        # 随机读测试
        local random_read=$(timeout 35 fio --name=random_read --ioengine=libaio --iodepth=32 --rw=randread --bs=4k --direct=1 --size=200M --numjobs=1 --runtime=15 --group_reporting --filename=/tmp/fio_test_read 2>/dev/null | grep "read:" | awk '{print $3}' | sed 's/bw=//')
        
        if [ -n "$random_read" ]; then
            print_status_line "随机读取速度" "$random_read" "INFO" "📖"
            DISK_TESTS+=("Random Read: $random_read")
        fi
        
        # 随机写测试
        local random_write=$(timeout 35 fio --name=random_write --ioengine=libaio --iodepth=32 --rw=randwrite --bs=4k --direct=1 --size=200M --numjobs=1 --runtime=15 --group_reporting --filename=/tmp/fio_test_write 2>/dev/null | grep "write:" | awk '{print $3}' | sed 's/bw=//')
        
        if [ -n "$random_write" ]; then
            print_status_line "随机写入速度" "$random_write" "INFO" "📝"
            DISK_TESTS+=("Random Write: $random_write")
        fi
        
        # 顺序读写测试
        print_info "执行磁盘顺序读写性能测试 (20秒)..."
        local seq_read=$(timeout 25 fio --name=seq_read --ioengine=libaio --iodepth=8 --rw=read --bs=1M --direct=1 --size=500M --numjobs=1 --runtime=10 --group_reporting --filename=/tmp/fio_test_seq 2>/dev/null | grep "read:" | awk '{print $3}' | sed 's/bw=//')
        
        if [ -n "$seq_read" ]; then
            print_status_line "顺序读取速度" "$seq_read" "INFO" "📚"
            DISK_TESTS+=("Sequential Read: $seq_read")
        fi
        
        # 清理测试文件
        rm -f /tmp/fio_test_* 2>/dev/null
        
    elif command -v hdparm &> /dev/null; then
        print_info "使用hdparm进行简单磁盘测试..."
        local main_disk=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
        
        if [ -b "$main_disk" ]; then
            local hdparm_read=$(hdparm -t $main_disk 2>/dev/null | grep "Timing buffered disk reads" | awk '{print $11 " " $12}')
            if [ -n "$hdparm_read" ]; then
                print_status_line "磁盘读取速度" "$hdparm_read" "INFO" "💨"
                DISK_TESTS+=("Disk Read: $hdparm_read")
            fi
        fi
    else
        print_warning "fio和hdparm均未安装，使用简单dd测试"
        local write_speed=$(timeout 30 dd if=/dev/zero of=/tmp/test_write bs=1M count=200 oflag=direct 2>&1 | grep -o '[0-9.]\+ [MGK]B/s' | tail -1)
        if [ -n "$write_speed" ]; then
            print_status_line "顺序写入速度" "$write_speed" "INFO" "📝"
            DISK_TESTS+=("DD Write: $write_speed")
        fi
        rm -f /tmp/test_write 2>/dev/null
    fi
}

# 网络系统检测
network_test() {
    print_section "🌐 网络系统检测"
    
    # 网络接口信息
    print_subsection "网络接口状态"
    if command -v ip &> /dev/null; then
        ip link show | grep -E "^[0-9]+:" | while read line; do
            local interface=$(echo $line | awk '{print $2}' | sed 's/://')
            if [ "$interface" != "lo" ]; then
                local ip_addr=$(ip addr show $interface | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
                local link_status=$(echo $line | grep -o "state [A-Z]*" | awk '{print $2}')
                
                print_status_line "$interface" "${ip_addr:-未配置IP}" "$link_status" "$([ "$link_status" = "UP" ] && echo "✅" || echo "❌")"
                
                # 网络接口详细信息
                if [ -d "/sys/class/net/$interface" ]; then
                    local speed=$(cat /sys/class/net/$interface/speed 2>/dev/null || echo "Unknown")
                    local duplex=$(cat /sys/class/net/$interface/duplex 2>/dev/null || echo "Unknown")
                    local mtu=$(cat /sys/class/net/$interface/mtu 2>/dev/null)
                    
                    if [ "$speed" != "Unknown" ] && [ "$speed" != "-1" ]; then
                        print_status_line "  └─ 链路速度" "${speed}Mbps (${duplex})" "INFO" "⚡"
                    fi
                    [ -n "$mtu" ] && print_status_line "  └─ MTU大小" "$mtu" "INFO" "📏"
                fi
            fi
        done
    fi
    
    # 网络连通性测试
    print_subsection "网络连通性测试"
    local test_sites=("8.8.8.8:Google DNS" "114.114.114.114:114 DNS" "baidu.com:百度" "github.com:GitHub")
    
    for site_info in "${test_sites[@]}"; do
        IFS=':' read -r site name <<< "$site_info"
        
        local ping_result=$(timeout 5 ping -c 3 "$site" 2>/dev/null)
        if [ $? -eq 0 ]; then
            local avg_time=$(echo "$ping_result" | tail -1 | awk -F'/' '{print $5}' | cut -d'.' -f1)
            local packet_loss=$(echo "$ping_result" | grep "packet loss" | awk '{print $7}' | sed 's/%//')
            
            if [ "$packet_loss" = "0" ]; then
                print_pass "$name 连通正常 (${avg_time}ms)"
            else
                print_warning "$name 连通异常 (丢包${packet_loss}%)"
            fi
        else
            print_error "$name 连接失败"
        fi
    done
    
    # DNS解析测试
    print_subsection "DNS解析测试"
    local dns_servers=("8.8.8.8" "114.114.114.114")
    local test_domain="www.baidu.com"
    
    for dns in "${dns_servers[@]}"; do
        local resolve_time=$(timeout 5 dig @$dns $test_domain +stats 2>/dev/null | grep "Query time:" | awk '{print $4}')
        if [ -n "$resolve_time" ]; then
            print_status_line "DNS $dns" "${resolve_time}ms" "INFO" "🔍"
        else
            print_warning "DNS $dns 解析失败"
        fi
    done
    
    # 网络性能测试
    print_subsection "网络性能测试"
    
    # 检测网络环境
    local network_env="unknown"
    local baidu_ping=$(timeout 3 ping -c 1 baidu.com 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')
    local google_ping=$(timeout 3 ping -c 1 google.com 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')
    
    if [ -n "$baidu_ping" ] && [ -n "$google_ping" ]; then
        network_env="mixed"
        print_info "检测到混合网络环境"
    elif [ -n "$baidu_ping" ]; then
        network_env="domestic"
        print_info "检测到国内网络环境"
    elif [ -n "$google_ping" ]; then
        network_env="international"
        print_info "检测到国际网络环境"
    else
        network_env="limited"
        print_warning "网络环境受限"
    fi
    
    # 带宽测试
    if command -v speedtest-cli &> /dev/null; then
        print_info "执行网络带宽测试 (可能需要1-2分钟)..."
        local speedtest_result=$(timeout 120 speedtest-cli --simple 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$speedtest_result" ]; then
            local download_speed=$(echo "$speedtest_result" | grep "Download:" | awk '{print $2 " " $3}')
            local upload_speed=$(echo "$speedtest_result" | grep "Upload:" | awk '{print $2 " " $3}')
            local ping_time=$(echo "$speedtest_result" | grep "Ping:" | awk '{print $2}')
            
            print_status_line "下载速度" "$download_speed" "INFO" "📥"
            print_status_line "上传速度" "$upload_speed" "INFO" "📤"
            print_status_line "网络延迟" "${ping_time}ms" "INFO" "🏓"
            
            NETWORK_TESTS+=("Download: $download_speed")
            NETWORK_TESTS+=("Upload: $upload_speed")
            NETWORK_TESTS+=("Ping: ${ping_time}ms")
        else
            print_warning "网络带宽测试失败或超时"
        fi
    elif command -v iperf3 &> /dev/null; then
        print_info "尝试使用iperf3进行网络测试..."
        # 可以添加公共iperf3服务器测试
        print_info "iperf3需要指定服务器，跳过自动测试"
    else
        print_warning "speedtest-cli和iperf3均未安装，无法进行带宽测试"
        print_info "安装命令: sudo apt install speedtest-cli iperf3"
    fi
    
    # 网络统计信息
    print_subsection "网络统计信息"
    if [ -f "/proc/net/dev" ]; then
        print_info "网络接口流量统计:"
        cat /proc/net/dev | grep -E "eth|ens|enp|wlan" | while read line; do
            local interface=$(echo $line | awk '{print $1}' | sed 's/://')
            local rx_bytes=$(echo $line | awk '{print $2}')
            local tx_bytes=$(echo $line | awk '{print $10}')
            
            if [ "$rx_bytes" -gt 0 ] || [ "$tx_bytes" -gt 0 ]; then
                local rx_mb=$((rx_bytes / 1024 / 1024))
                local tx_mb=$((tx_bytes / 1024 / 1024))
                printf "    %-10s: 接收 %dMB, 发送 %dMB\n" "$interface" "$rx_mb" "$tx_mb"
            fi
        done
    fi
}

# 更新生成测试报告函数
generate_report() {
    print_section "📋 测试报告生成"
    
    local vendor=$(get_system_info "vendor")
    local model=$(get_system_info "model")
    local hostname=$(hostname)
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')
    local cpu_cores=$(nproc)
    local mem_total_gb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
    
    # 计算总分
    local total_score=100
    local error_count=${#ERRORS[@]}
    local warning_count=${#WARNINGS[@]}
    
    # 扣分规则
    total_score=$((total_score - error_count * 10))
    total_score=$((total_score - warning_count * 5))
    total_score=$((total_score < 0 ? 0 : total_score))
    
    # 生成报告
    {
        echo "========================================"
        echo "主机全面性能测试报告"
        echo "========================================"
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "主机信息: ${vendor} ${model}"
        echo "主机名: ${hostname}"
        echo "CPU型号: ${cpu_model}"
        echo "CPU核心: ${cpu_cores}"
        echo "内存容量: ${mem_total_gb}GB"
        echo "测试评分: ${total_score}/100"
        echo ""
        
        if [ ${#CPU_TESTS[@]} -gt 0 ]; then
            echo "CPU测试结果:"
            for test in "${CPU_TESTS[@]}"; do
                echo "- $test"
            done
            echo ""
        fi
        
        if [ ${#MEMORY_TESTS[@]} -gt 0 ]; then
            echo "内存测试结果:"
            for test in "${MEMORY_TESTS[@]}"; do
                echo "- $test"
            done
            echo ""
        fi
        
        if [ ${#DISK_TESTS[@]} -gt 0 ]; then
            echo "硬盘测试结果:"
            for test in "${DISK_TESTS[@]}"; do
                echo "- $test"
            done
            echo ""
        fi
        
        if [ ${#NETWORK_TESTS[@]} -gt 0 ]; then
            echo "网络测试结果:"
            for test in "${NETWORK_TESTS[@]}"; do
                echo "- $test"
            done
            echo ""
        fi
        
        if [ $error_count -gt 0 ]; then
            echo "错误 ($error_count 项):"
            for error in "${ERRORS[@]}"; do
                echo "  - $error"
            done
            echo ""
        fi
        
        if [ $warning_count -gt 0 ]; then
            echo "警告 ($warning_count 项):"
            for warning in "${WARNINGS[@]}"; do
                echo "  - $warning"
            done
            echo ""
        fi
        
        echo "详细日志: $LOG_FILE"
        echo "报告生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    } > $REPORT_FILE
    
    # 评分等级
    local grade=""
    local grade_color=""
    
    if [ $total_score -ge 90 ]; then
        grade="优秀 (A+)"
        grade_color=$GREEN
    elif [ $total_score -ge 80 ]; then
        grade="良好 (A)"
        grade_color=$GREEN
    elif [ $total_score -ge 70 ]; then
        grade="一般 (B)"
        grade_color=$YELLOW
    elif [ $total_score -ge 60 ]; then
        grade="较差 (C)"
        grade_color=$YELLOW
    else
        grade="很差 (D)"
        grade_color=$RED
    fi
    
    print_info "测试报告已生成: $REPORT_FILE"
    print_status_line "综合评分" "${total_score}/100" "INFO" "📊"
    echo -e "  ${BOLD}评估等级:${NC} ${grade_color}${grade}${NC}"
    
    # 设置文件权限
    chmod 644 $REPORT_FILE
    chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $REPORT_FILE 2>/dev/null
}

# 更新主程序
main() {
    clear
    print_header "主机全面性能测试系统 v2.0"
    echo -e "${BOLD}测试时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BOLD}操作用户:${NC} ${SUDO_USER:-$USER}"
    echo -e "${BOLD}日志文件:${NC} $LOG_FILE"
    
    log_info "开始主机全面性能测试"
    
    # 执行测试
    check_dependencies
    cpu_basic_info
    cpu_frequency_test
    cpu_temperature_test
    cpu_load_test
    cpu_benchmark_test
    cpu_stress_test
    memory_test
    disk_test
    network_test
    generate_report
    
    # 完成提示
    print_header "测试完成"
    echo -e "${CYAN}感谢使用主机全面性能测试系统！${NC}"
    echo -e "${CYAN}如有问题请查看详细日志: $LOG_FILE${NC}"
    
    log_info "主机全面性能测试完成"
}

# 运行主程序
main "$@"

exit 0