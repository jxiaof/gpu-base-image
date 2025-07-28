#!/bin/bash
# filepath: /home/soovv/base/check_host.sh

# 企业级GPU服务器交付检查脚本
# 版本: 3.0 Professional
# 适用于: 企业级GPU服务器交付验收 (Ubuntu 22.04)

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
LOG_FILE="/var/log/server_check_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="/tmp/server_delivery_report_$(date +%Y%m%d_%H%M%S).txt"

# 全局变量
MISSING_TOOLS=()
WARNINGS=()
ERRORS=()

# 记录日志函数
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a $LOG_FILE
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a $LOG_FILE
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" | tee -a $LOG_FILE
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
    log_warning "$1"
}

print_error() {
    echo -e "  ${RED}❌ FAIL${NC} - $1"
    ERRORS+=("$1")
    log_error "$1"
}

print_info() {
    echo -e "  ${CYAN}ℹ️  INFO${NC} - $1"
}

# 检查依赖工具
check_dependencies() {
    local required_tools=(
        "dmidecode:硬件信息检测"
        "sensors:温度监控(lm-sensors包)"
        "sysbench:性能基准测试"
        "fio:磁盘IO性能测试"
        "iperf3:网络性能测试"
        "speedtest-cli:网络速度测试"
        "nvidia-smi:NVIDIA GPU管理"
        "nvcc:CUDA开发工具包"

        "sudo apt install dmidecode lm-sensors sysbench fio iperf3 speedtest-cli "
    )
    
    print_section "🔍 依赖检查"
    
    for tool_desc in "${required_tools[@]}"; do
        IFS=':' read -r tool desc <<< "$tool_desc"
        if command -v "$tool" &> /dev/null; then
            print_pass "$tool - $desc"
        else
            print_warning "缺少工具: $tool - $desc"
            MISSING_TOOLS+=("$tool")
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️  建议安装缺失工具以获得完整检测结果:${NC}"
        for tool in "${MISSING_TOOLS[@]}"; do
            case $tool in
                "dmidecode") echo "    sudo apt install dmidecode" ;;
                "sensors") echo "    sudo apt install lm-sensors && sudo sensors-detect --auto" ;;
                "sysbench") echo "    sudo apt install sysbench" ;;
                "fio") echo "    sudo apt install fio" ;;
                "iperf3") echo "    sudo apt install iperf3" ;;
                "speedtest-cli") echo "    sudo apt install speedtest-cli" ;;
                "nvidia-smi") echo "    安装NVIDIA驱动程序" ;;
                "nvcc") echo "    安装CUDA Toolkit" ;;
            esac
        done
    fi
}

# 获取系统硬件信息（增强兼容性）
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
        "serial")
            if command -v dmidecode &> /dev/null; then
                result=$(dmidecode -s system-serial-number 2>/dev/null | grep -v "^#" | head -1)
            fi
            [ -z "$result" ] && result=$(cat /sys/class/dmi/id/product_serial 2>/dev/null)
            [ -z "$result" ] && result="Unknown"
            ;;
        "bios")
            if command -v dmidecode &> /dev/null; then
                result=$(dmidecode -s bios-version 2>/dev/null | grep -v "^#" | head -1)
            fi
            [ -z "$result" ] && result=$(cat /sys/class/dmi/id/bios_version 2>/dev/null)
            [ -z "$result" ] && result="Unknown"
            ;;
    esac
    
    echo "$result"
}

# 开始检查
clear
print_header "企业级GPU服务器交付验收检测系统 v3.0"
echo -e "${BOLD}检查时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BOLD}操作人员:${NC} ${SUDO_USER:-$USER}"
echo -e "${BOLD}日志文件:${NC} $LOG_FILE"
echo -e "${BOLD}报告文件:${NC} $REPORT_FILE"

log_info "开始企业级服务器交付检查"

# 依赖检查
check_dependencies

# 1. 服务器基本信息
print_section "🏢 服务器基本信息"
hostname=$(hostname)
vendor=$(get_system_info "vendor")
model=$(get_system_info "model")
serial=$(get_system_info "serial")
bios_version=$(get_system_info "bios")
os_info=$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
kernel=$(uname -r)
uptime_info=$(uptime -p)

print_status_line "主机名" "$hostname" "INFO" "🖥️"
print_status_line "厂商" "$vendor" "INFO" "🏭"
print_status_line "型号" "$model" "INFO" "📋"
print_status_line "序列号" "$serial" "INFO" "🏷️"
print_status_line "BIOS版本" "$bios_version" "INFO" "⚙️"
print_status_line "操作系统" "$os_info" "INFO" "💿"
print_status_line "内核版本" "$kernel" "INFO" "🔧"
print_status_line "运行时间" "$uptime_info" "INFO" "⏰"

# 2. CPU详细检查
print_section "💻 CPU系统检查"
cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')
cpu_cores=$(nproc)
cpu_threads=$(grep -c processor /proc/cpuinfo)
cpu_sockets=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
cpu_freq_max=$(grep "cpu MHz" /proc/cpuinfo | awk '{print $4}' | sort -n | tail -1 | cut -d'.' -f1)
cpu_cache=$(grep "cache size" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')

# CPU使用率
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d'.' -f1)
load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

print_status_line "处理器型号" "$cpu_model" "INFO" "🎯"
print_status_line "物理插槽" "$cpu_sockets" "INFO" "🔌"
print_status_line "物理核心" "$cpu_cores" "INFO" "⚡"
print_status_line "逻辑线程" "$cpu_threads" "INFO" "🧵"
print_status_line "最大频率" "${cpu_freq_max}MHz" "INFO" "📊"
print_status_line "缓存大小" "$cpu_cache" "INFO" "💾"

print_metric "CPU使用率" "$cpu_usage" "%" "80" "60"
print_metric "系统负载" "$load_avg" "" "$cpu_cores" "$(echo "$cpu_cores * 0.7" | bc -l | cut -d'.' -f1)"

# CPU温度检查
print_subsection "温度监控"
if command -v sensors &> /dev/null; then
    # 初始化温度数组，避免重复显示
    declare -A temp_cores
    
    # 获取所有温度信息
    sensors_output=$(sensors 2>/dev/null)
    
    # 解析CPU温度
    echo "$sensors_output" | grep -E "Core|CPU|Tctl|temp" | while read line; do
        # 匹配不同的温度格式
        if [[ $line =~ Core\ ([0-9]+):.*\+([0-9]+)\.[0-9]+°C ]] || \
           [[ $line =~ CPU\ Temperature:.*\+([0-9]+)\.[0-9]+°C ]] || \
           [[ $line =~ Tctl:.*\+([0-9]+)\.[0-9]+°C ]] || \
           [[ $line =~ temp[0-9]+:.*\+([0-9]+)\.[0-9]+°C ]]; then
            
            # 提取温度值和核心信息
            temp=""
            core_name=""
            
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
            elif [[ $line =~ temp([0-9]+):.*\+([0-9]+)\.[0-9]+°C ]]; then
                temp_num=${BASH_REMATCH[1]}
                temp=${BASH_REMATCH[2]}
                core_name="Sensor $temp_num"
            fi
            
            # 检查温度值是否有效
            if [ -n "$temp" ] && [ -n "$core_name" ]; then
                # 检查是否已经记录过这个核心
                if [[ -z "${temp_cores[$core_name]}" ]]; then
                    temp_cores[$core_name]=$temp
                    
                    # 温度状态判断
                    status="NORMAL"
                    icon="✅"
                    color=$GREEN
                    
                    if [ "$temp" -gt 85 ] 2>/dev/null; then
                        status="CRITICAL"
                        icon="❌"
                        color=$RED
                        ERRORS+=("$core_name 温度过高: ${temp}°C")
                    elif [ "$temp" -gt 75 ] 2>/dev/null; then
                        status="WARNING"
                        icon="⚠️"
                        color=$YELLOW
                        WARNINGS+=("$core_name 温度偏高: ${temp}°C")
                    fi
                    
                    printf "  %-25s: ${color}%-15s${NC} [%s] %s\n" "$core_name 温度" "${temp}°C" "$status" "$icon"
                fi
            fi
        fi
    done
    
    # 如果没有检测到温度，尝试其他方法
    if [ ${#temp_cores[@]} -eq 0 ]; then
        echo ""
        echo -e "${CYAN}  尝试从系统温度传感器读取:${NC}"
        # 尝试从thermal_zone读取
        for thermal_zone in /sys/class/thermal/thermal_zone*/temp; do
            if [ -r "$thermal_zone" ]; then
                temp_millidegree=$(cat "$thermal_zone" 2>/dev/null)
                if [ -n "$temp_millidegree" ] && [ "$temp_millidegree" -gt 0 ] 2>/dev/null; then
                    temp=$((temp_millidegree / 1000))
                    zone_name=$(basename $(dirname "$thermal_zone"))
                    type_file=$(dirname "$thermal_zone")/type
                    zone_type=$(cat "$type_file" 2>/dev/null || echo "unknown")
                    
                    status="NORMAL"
                    icon="✅"
                    color=$GREEN
                    
                    if [ "$temp" -gt 85 ] 2>/dev/null; then
                        status="CRITICAL"
                        icon="❌"
                        color=$RED
                        ERRORS+=("$zone_type 温度过高: ${temp}°C")
                    elif [ "$temp" -gt 75 ] 2>/dev/null; then
                        status="WARNING"
                        icon="⚠️"
                        color=$YELLOW
                        WARNINGS+=("$zone_type 温度偏高: ${temp}°C")
                    fi
                    
                    printf "    %-20s: ${color}%-10s${NC} [%s] %s (%s)\n" "$zone_type" "${temp}°C" "$status" "$icon" "$zone_name"
                fi
            fi
        done
    fi
    
    # 温度警告和建议
    max_temp=$(echo "$sensors_output" | grep -oE '\+[0-9]+\.[0-9]+°C' | grep -oE '[0-9]+' | sort -n | tail -1)
    if [ -n "$max_temp" ] && [ "$max_temp" -gt 90 ] 2>/dev/null; then
        echo ""
        echo -e "${RED}${BOLD}⚠️  严重警告: CPU温度过高 (${max_temp}°C)${NC}"
        echo -e "${RED}   立即采取措施:${NC}"
        echo -e "${RED}   1. 检查CPU散热器是否正常工作${NC}"
        echo -e "${RED}   2. 清理灰尘，检查散热片${NC}"
        echo -e "${RED}   3. 检查导热硅脂是否需要更换${NC}"
        echo -e "${RED}   4. 检查机箱风扇工作状态${NC}"
        echo -e "${RED}   5. 考虑降低CPU负载或频率${NC}"
        echo ""
        ERRORS+=("CPU温度危险: ${max_temp}°C - 需要立即处理")
    elif [ -n "$max_temp" ] && [ "$max_temp" -gt 80 ] 2>/dev/null; then
        echo ""
        echo -e "${YELLOW}${BOLD}⚠️  警告: CPU温度偏高 (${max_temp}°C)${NC}"
        echo -e "${YELLOW}   建议检查散热系统${NC}"
        echo ""
    fi
    
else
    print_warning "lm-sensors未安装，无法监控CPU温度"
    print_info "安装命令: sudo apt install lm-sensors && sudo sensors-detect --auto"
    
    # 尝试直接读取thermal_zone
    echo ""
    echo -e "${CYAN}  尝试读取系统温度传感器:${NC}"
    for thermal_zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -r "$thermal_zone" ]; then
            temp_millidegree=$(cat "$thermal_zone" 2>/dev/null)
            if [ -n "$temp_millidegree" ] && [ "$temp_millidegree" -gt 0 ] 2>/dev/null; then
                temp=$((temp_millidegree / 1000))
                zone_name=$(basename $(dirname "$thermal_zone"))
                type_file=$(dirname "$thermal_zone")/type
                zone_type=$(cat "$type_file" 2>/dev/null || echo "unknown")
                
                status="NORMAL"
                icon="✅"
                color=$GREEN
                
                if [ "$temp" -gt 85 ] 2>/dev/null; then
                    status="CRITICAL"
                    icon="❌"
                    color=$RED
                    ERRORS+=("$zone_type 温度过高: ${temp}°C")
                elif [ "$temp" -gt 75 ] 2>/dev/null; then
                    status="WARNING"
                    icon="⚠️"
                    color=$YELLOW
                    WARNINGS+=("$zone_type 温度偏高: ${temp}°C")
                fi
                
                printf "    %-20s: ${color}%-10s${NC} [%s] %s (%s)\n" "$zone_type" "${temp}°C" "$status" "$icon" "$zone_name"
            fi
        fi
    done
fi

# 3. 内存系统检查
print_section "💾 内存系统检查"
mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
mem_total_gb=$((mem_total_kb / 1024 / 1024))
mem_used_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
mem_used_gb=$(((mem_total_kb - mem_used_kb) / 1024 / 1024))
mem_percent=$(((mem_total_kb - mem_used_kb) * 100 / mem_total_kb))

print_metric "总内存容量" "$mem_total_gb" "GB" "" ""
print_metric "内存使用率" "$mem_percent" "%" "90" "70"
print_status_line "已用内存" "${mem_used_gb}GB" "INFO" "📊"

# 内存条详细信息
print_subsection "内存模块信息"
if command -v dmidecode &> /dev/null; then
    mem_modules=$(dmidecode -t memory 2>/dev/null | grep -A 20 "Memory Device" | grep -E "Size:|Speed:|Type:|Manufacturer:" | grep -v "No Module Installed" | wc -l)
    if [ $mem_modules -gt 0 ]; then
        print_pass "检测到 $((mem_modules / 4)) 个内存模块"
        dmidecode -t memory 2>/dev/null | grep -A 20 "Memory Device" | grep -E "Size:|Speed:|Type:|Manufacturer:" | grep -v "No Module" | head -8 | sed 's/^/    /'
    else
        print_warning "无法检测到内存模块信息"
    fi
else
    print_warning "dmidecode未安装，无法获取内存详细信息"
fi

# 4. 存储系统检查
print_section "💿 存储系统检查"

print_subsection "磁盘使用情况"
df -h | grep -E "^/dev" | while read line; do
    device=$(echo $line | awk '{print $1}')
    size=$(echo $line | awk '{print $2}')
    used=$(echo $line | awk '{print $3}')
    percent=$(echo $line | awk '{print $5}' | sed 's/%//')
    mount=$(echo $line | awk '{print $6}')
    
    if [ $percent -lt 70 ]; then
        status="NORMAL"
        icon="✅"
        color=$GREEN
    elif [ $percent -lt 90 ]; then
        status="WARNING"
        icon="⚠️"
        color=$YELLOW
        WARNINGS+=("磁盘使用率 $device: ${percent}%")
    else
        status="CRITICAL"
        icon="❌"
        color=$RED
        ERRORS+=("磁盘使用率 $device: ${percent}%")
    fi
    
    printf "  %-15s: ${color}%-15s${NC} [%s] %s → %s\n" "$device" "${percent}%" "$status" "$icon" "$mount"
done

print_subsection "存储设备信息"
if command -v lsblk &> /dev/null; then
    lsblk -d -o NAME,SIZE,MODEL,VENDOR,TYPE | grep -v "loop" | sed 's/^/    /'
else
    print_warning "lsblk未安装，无法获取存储设备信息"
fi

print_subsection "存储性能测试"
if command -v fio &> /dev/null; then
    print_info "执行磁盘IO性能测试..."
    fio --name=test --ioengine=libaio --iodepth=32 --rw=randrw --bs=4k --direct=1 --size=100M --numjobs=1 --runtime=10 --group_reporting --filename=/tmp/fio_test 2>/dev/null | grep -E "read:|write:" | head -2 | sed 's/^/    /'
    rm -f /tmp/fio_test* 2>/dev/null
else
    print_warning "fio未安装，使用简单dd测试"
    write_speed=$(timeout 30 dd if=/dev/zero of=/tmp/test_write bs=1M count=100 oflag=direct 2>&1 | grep -o '[0-9.]\+ [MGK]B/s' | tail -1)
    if [ -n "$write_speed" ]; then
        print_status_line "顺序写入速度" "$write_speed" "INFO" "📝"
    else
        print_error "磁盘性能测试失败"
    fi
    rm -f /tmp/test_write 2>/dev/null
fi

# 5. GPU系统检查
print_section "🎮 GPU系统检查"

if command -v nvidia-smi &> /dev/null; then
    gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    if [ $gpu_count -gt 0 ]; then
        print_pass "检测到 $gpu_count 个NVIDIA GPU"
        
        print_subsection "GPU硬件清单"
        nvidia-smi -L 2>/dev/null | sed 's/^/    /'
        
        print_subsection "GPU详细规格"
        nvidia-smi --query-gpu=index,name,memory.total,pci.bus_id,compute_cap,driver_version --format=csv,noheader 2>/dev/null | while IFS=',' read index name memory_total pci_bus compute_cap driver_version; do
            echo "    GPU $index: $name"
            echo "      显存容量: $memory_total"
            echo "      PCI总线ID: $pci_bus"
            echo "      计算能力: $compute_cap"
            echo "      驱动版本: $driver_version"
            echo ""
        done
        
        print_subsection "GPU运行状态"
        nvidia-smi --query-gpu=index,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,power.limit --format=csv,noheader,nounits 2>/dev/null | while IFS=',' read index temp util mem_used mem_total power_draw power_limit; do
            if [ -n "$mem_total" ] && [ "$mem_total" != "0" ]; then
                mem_percent=$((mem_used * 100 / mem_total))
            else
                mem_percent=0
            fi
            
            echo "    GPU $index 状态监控:"
            printf "      %-15s: %-10s [%s] %s\n" "温度" "${temp}°C" "$([ $temp -lt 75 ] && echo "NORMAL" || ([ $temp -lt 85 ] && echo "WARNING" || echo "CRITICAL"))" "$([ $temp -lt 75 ] && echo "✅" || ([ $temp -lt 85 ] && echo "⚠️" || echo "❌"))"
            printf "      %-15s: %-10s [%s] %s\n" "GPU使用率" "${util}%" "$([ $util -lt 80 ] && echo "NORMAL" || echo "HIGH")" "$([ $util -lt 80 ] && echo "✅" || echo "⚠️")"
            printf "      %-15s: %-10s [%s] %s\n" "显存使用率" "${mem_percent}%" "$([ $mem_percent -lt 80 ] && echo "NORMAL" || echo "HIGH")" "$([ $mem_percent -lt 80 ] && echo "✅" || echo "⚠️")"
            [ "$power_draw" != "[Not Supported]" ] && printf "      %-15s: %-10s [%s] %s\n" "功耗" "${power_draw}W" "INFO" "⚡"
            echo ""
        done
        
        # CUDA环境检查
        if command -v nvcc &> /dev/null; then
            cuda_version=$(nvcc --version | grep "release" | awk '{print $6}' | sed 's/V//')
            print_pass "CUDA Toolkit已安装 (版本: $cuda_version)"
            
            # CUDA运行时测试
            if [ -f /usr/local/cuda/extras/demo_suite/deviceQuery ]; then
                print_info "执行CUDA设备查询测试"
                /usr/local/cuda/extras/demo_suite/deviceQuery | grep -E "CUDA Capability|Global memory" | head -5 | sed 's/^/    /'
            fi
        else
            print_warning "CUDA Toolkit未安装"
        fi
        
        # Python GPU库检查
        if python3 -c "import pynvml" 2>/dev/null; then
            print_pass "Python NVIDIA-ML库已安装"
        else
            print_warning "Python NVIDIA-ML库未安装 (pip3 install pynvml)"
        fi
        
        if python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null | grep -q "True"; then
            print_pass "PyTorch GPU支持正常"
        else
            print_warning "PyTorch GPU支持异常或未安装"
        fi
        
    else
        print_error "nvidia-smi未检测到GPU设备"
    fi
else
    print_error "NVIDIA驱动未安装或nvidia-smi不可用"
    
    # 检查是否有其他GPU
    if lspci | grep -i "vga\|3d\|display" >/dev/null 2>&1; then
        print_info "检测到其他显示设备:"
        lspci | grep -i "vga\|3d\|display" | sed 's/^/    /'
    fi
fi

# 6. 网络系统检查
print_section "🌐 网络系统检查"

print_subsection "网络接口状态"
if command -v ip &> /dev/null; then
    ip link show | grep -E "^[0-9]+:" | while read line; do
        interface=$(echo $line | awk '{print $2}' | sed 's/://')
        if [ "$interface" != "lo" ]; then
            ip_addr=$(ip addr show $interface | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
            link_status=$(ip link show $interface | grep -o "state [A-Z]*" | awk '{print $2}')
            
            if [ -d "/sys/class/net/$interface" ]; then
                speed=$(cat /sys/class/net/$interface/speed 2>/dev/null || echo "Unknown")
                duplex=$(cat /sys/class/net/$interface/duplex 2>/dev/null || echo "Unknown")
                
                status_icon="✅"
                [ "$link_status" != "UP" ] && status_icon="❌"
                
                printf "  %-12s: %-15s [%s] %s\n" "$interface" "${ip_addr:-未配置IP}" "$link_status" "$status_icon"
                if [ "$speed" != "Unknown" ] && [ "$speed" != "-1" ]; then
                    printf "    %-10s: %sMbps (%s)\n" "链路速度" "$speed" "$duplex"
                fi
            fi
        fi
    done
else
    print_warning "ip命令不可用，无法检查网络接口"
fi

print_subsection "网络性能测试"

# 检测网络环境（国内外）
print_info "检测网络环境..."
network_env="unknown"
domestic_latency=""
international_latency=""

# 同时测试国内外连通性以确定网络环境
baidu_ping=$(timeout 3 ping -c 1 baidu.com 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')
google_ping=$(timeout 3 ping -c 1 google.com 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')

if [ -n "$baidu_ping" ] && [ -n "$google_ping" ]; then
    # 两者都能访问，根据延迟判断主要环境
    baidu_time=$(echo "$baidu_ping" | sed 's/ms//')
    google_time=$(echo "$google_ping" | sed 's/ms//')
    if (( $(echo "$baidu_time < $google_time" | bc -l) )); then
        network_env="domestic_with_international"
        print_info "检测到国内网络环境 (可访问国际网络)"
        print_info "国内延迟: ${baidu_time}ms, 国际延迟: ${google_time}ms"
    else
        network_env="international_with_domestic"
        print_info "检测到国际网络环境 (可访问国内网络)"
        print_info "国际延迟: ${google_time}ms, 国内延迟: ${baidu_time}ms"
    fi
elif [ -n "$baidu_ping" ]; then
    network_env="domestic_only"
    print_info "检测到国内网络环境 (国际网络受限)"
    print_info "国内延迟: $baidu_ping"
elif [ -n "$google_ping" ]; then
    network_env="international_only"
    print_info "检测到国际网络环境 (国内网络受限)"
    print_info "国际延迟: $google_ping"
else
    network_env="limited"
    print_warning "网络环境检测异常，连通性受限"
fi

print_subsection "网络性能测试"

# 检测网络环境并选择最佳测试方法
print_info "检测网络环境..."

# 根据环境选择最专业的测试方法
case $network_env in
    "domestic_only"|"domestic_with_international")
        print_subsection "国内网络性能测试"
        
        # 方法1: 使用官方 Speedtest CLI (最推荐)
        # if command -v speedtest &> /dev/null; then
        #     print_info "使用官方 Speedtest CLI 进行测试..."
        #     echo "    🚀 官方 Speedtest 测试结果:"
            
        #     # 获取国内最佳服务器列表
        #     print_info "获取国内优质测试服务器..."
        #     speedtest_result=$(timeout 60 speedtest --accept-license --accept-gdpr --format=json 2>/dev/null)
            
        #     if [ $? -eq 0 ] && [ -n "$speedtest_result" ]; then
        #         # 解析JSON结果
        #         download_bps=$(echo "$speedtest_result" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['download']['bandwidth'])" 2>/dev/null)
        #         upload_bps=$(echo "$speedtest_result" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['upload']['bandwidth'])" 2>/dev/null)
        #         ping_ms=$(echo "$speedtest_result" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['ping']['latency'])" 2>/dev/null)
        #         server_name=$(echo "$speedtest_result" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['server']['name'])" 2>/dev/null)
        #         server_location=$(echo "$speedtest_result" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['server']['location'])" 2>/dev/null)
                
        #         if [ -n "$download_bps" ] && [ -n "$upload_bps" ]; then
        #             download_mbps=$(echo "scale=2; $download_bps / 1000000 * 8" | bc)
        #             upload_mbps=$(echo "scale=2; $upload_bps / 1000000 * 8" | bc)
                    
        #             echo "      📊 测试服务器: $server_name, $server_location"
        #             echo "      📥 下载速度: ${download_mbps} Mbps"
        #             echo "      📤 上传速度: ${upload_mbps} Mbps"
        #             echo "      🏓 延迟: ${ping_ms} ms"
                    
        #             # 智能评价
        #             download_num=$(echo "$download_mbps" | cut -d'.' -f1)
        #             if [ "$download_num" -gt 500 ]; then
        #                 echo "      🚀 网络性能: 千兆级别 (优秀)"
        #             elif [ "$download_num" -gt 100 ]; then
        #                 echo "      ✅ 网络性能: 百兆+ (良好)"
        #             elif [ "$download_num" -gt 50 ]; then
        #                 echo "      🟡 网络性能: 标准宽带 (一般)"
        #             else
        #                 echo "      ⚠️  网络性能: 较慢"
        #                 WARNINGS+=("网络下载速度较慢: ${download_mbps} Mbps")
        #             fi
        #         else
        #             echo "      ❌ 结果解析失败"
        #         fi
        #     else
        #         print_warning "官方 Speedtest CLI 测试失败，尝试备用方法"
        #     fi
            
        # 方法2: 使用 iperf3 (最专业)
        if command -v iperf3 &> /dev/null; then
            print_info "使用 iperf3 进行专业网络测试..."
            echo "    🔧 iperf3 专业带宽测试:"
            
            # 国内公共 iperf3 服务器列表
            iperf_servers=(
                "speedtest.tele2.net:5201:Tele2 Sweden"
                "ping.online.net:5201:Online.net France"
                "iperf.scottlinux.com:5201:ScottLinux US"
                "speedtest.serverius.net:5201:Serverius Netherlands"
            )
            
            for server_info in "${iperf_servers[@]}"; do
                IFS=':' read -r server port name <<< "$server_info"
                echo "      测试服务器: $name ($server:$port)"
                
                # TCP 下载测试
                download_result=$(timeout 20 iperf3 -c "$server" -p "$port" -t 10 -f M 2>/dev/null | grep "receiver" | awk '{print $(NF-1) " " $NF}')
                if [ -n "$download_result" ]; then
                    echo "        📥 下载: $download_result"
                    
                    # TCP 上传测试
                    upload_result=$(timeout 20 iperf3 -c "$server" -p "$port" -t 10 -R -f M 2>/dev/null | grep "receiver" | awk '{print $(NF-1) " " $NF}')
                    [ -n "$upload_result" ] && echo "        📤 上传: $upload_result"
                    
                    break
                else
                    echo "        ❌ 连接失败"
                fi
            done
            
        # 方法3: 使用 curl 多线程测试 (备用方案)
        else
            print_info "使用 curl 多线程下载测试..."
            echo "    📦 多线程下载性能测试:"
            
            # 国内优质CDN测试
            test_urls=(
                "https://mirrors.aliyun.com/ubuntu/ls-lR.gz:阿里云镜像"
                "https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ls-lR.gz:清华大学镜像"
                "http://mirror.lzu.edu.cn/ubuntu/ls-lR.gz:兰州大学镜像"
            )
            
            for url_info in "${test_urls[@]}"; do
                IFS=':' read -r url name <<< "$url_info"
                echo "      测试源: $name"
                
                # 多连接并发下载测试
                total_speed=0
                for i in {1..3}; do
                    speed=$(timeout 15 curl -o /dev/null -s -w '%{speed_download}' "$url" 2>/dev/null)
                    if [ -n "$speed" ] && [ "$speed" != "0" ]; then
                        speed_mb=$(echo "scale=2; $speed / 1024 / 1024" | bc)
                        total_speed=$(echo "scale=2; $total_speed + $speed_mb" | bc)
                        echo "        线程 $i: ${speed_mb} MB/s"
                    fi
                done
                
                if [ "$total_speed" != "0" ]; then
                    avg_speed=$(echo "scale=2; $total_speed / 3" | bc)
                    echo "        📊 平均速度: ${avg_speed} MB/s"
                    break
                fi
            done
        fi
        
        # 网络质量深度分析
        print_info "网络质量深度分析..."
        echo "    🔍 网络连通性矩阵测试:"
        
        # 多运营商节点测试
        quality_test_sites=(
            "114.114.114.114:114DNS:电信"
            "223.5.5.5:阿里DNS:阿里云"
            "119.29.29.29:腾讯DNS:腾讯云"
            "1.2.4.8:CNNIC:中科院"
            "180.76.76.76:百度DNS:百度"
        )
        
        for site_info in "${quality_test_sites[@]}"; do
            IFS=':' read -r ip name provider <<< "$site_info"
            
            # 测试延迟、丢包率、抖动
            ping_stats=$(ping -c 10 -i 0.2 "$ip" 2>/dev/null | tail -2)
            
            if [ -n "$ping_stats" ]; then
                # 解析ping统计
                loss_rate=$(echo "$ping_stats" | head -1 | grep -o '[0-9]*% packet loss' | cut -d'%' -f1)
                rtt_stats=$(echo "$ping_stats" | tail -1 | cut -d'=' -f2)
                
                if [ -n "$rtt_stats" ]; then
                    IFS='/' read -r min avg max mdev <<< "$rtt_stats"
                    
                    # 网络质量评价
                    avg_int=$(echo "$avg" | cut -d'.' -f1)
                    loss_int=${loss_rate:-0}
                    
                    if [ "$loss_int" -eq 0 ] && [ "$avg_int" -lt 30 ]; then
                        quality="🟢 优秀"
                    elif [ "$loss_int" -le 1 ] && [ "$avg_int" -lt 50 ]; then
                        quality="🟡 良好"
                    else
                        quality="🔴 一般"
                    fi
                    
                    printf "      %-12s %-8s: %6sms 丢包%2s%% 抖动%4sms [%s]\n" "$name" "($provider)" "$avg" "$loss_rate" "$mdev" "$quality"
                else
                    printf "      %-12s %-8s: %6s [🔴 异常]\n" "$name" "($provider)" "超时"
                fi
            fi
        done
        ;;
        
    "international_only"|"international_with_domestic")
        print_subsection "国际网络性能测试"
        
        # 使用官方 Speedtest CLI (国际节点)
        if command -v speedtest &> /dev/null; then
            print_info "使用官方 Speedtest CLI (国际节点)..."
            
            # 指定优质国际服务器
            international_servers=("1181" "24215" "28910" "21541")  # 知名国际节点ID
            
            for server_id in "${international_servers[@]}"; do
                speedtest_result=$(timeout 60 speedtest --accept-license --accept-gdpr --server-id="$server_id" --format=json 2>/dev/null)
                
                if [ $? -eq 0 ] && [ -n "$speedtest_result" ]; then
                    # 解析结果 (与国内版本相同的解析逻辑)
                    download_bps=$(echo "$speedtest_result" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['download']['bandwidth'])" 2>/dev/null)
                    upload_bps=$(echo "$speedtest_result" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['upload']['bandwidth'])" 2>/dev/null)
                    
                    if [ -n "$download_bps" ] && [ -n "$upload_bps" ]; then
                        download_mbps=$(echo "scale=2; $download_bps / 1000000 * 8" | bc)
                        upload_mbps=$(echo "scale=2; $upload_bps / 1000000 * 8" | bc)
                        
                        echo "      📊 国际带宽测试结果:"
                        echo "      📥 下载速度: ${download_mbps} Mbps"
                        echo "      📤 上传速度: ${upload_mbps} Mbps"
                        
                        # 国际网络评价标准
                        download_num=$(echo "$download_mbps" | cut -d'.' -f1)
                        if [ "$download_num" -gt 100 ]; then
                            echo "      🚀 国际带宽: 优秀"
                        elif [ "$download_num" -gt 25 ]; then
                            echo "      ✅ 国际带宽: 良好"
                        else
                            echo "      ⚠️  国际带宽: 一般"
                        fi
                        break
                    fi
                fi
            done
        fi
        ;;
esac

# 高级网络诊断
print_info "高级网络诊断..."
echo "    🔬 网络协议栈分析:"

# TCP 窗口大小和缓冲区检查
tcp_rmem=$(cat /proc/sys/net/core/rmem_max 2>/dev/null)
tcp_wmem=$(cat /proc/sys/net/core/wmem_max 2>/dev/null)
tcp_congestion=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)

if [ -n "$tcp_rmem" ]; then
    tcp_rmem_mb=$(echo "scale=1; $tcp_rmem / 1024 / 1024" | bc)
    echo "      TCP接收缓冲区: ${tcp_rmem_mb}MB"
fi

if [ -n "$tcp_wmem" ]; then
    tcp_wmem_mb=$(echo "scale=1; $tcp_wmem / 1024 / 1024" | bc)
    echo "      TCP发送缓冲区: ${tcp_wmem_mb}MB"
fi

[ -n "$tcp_congestion" ] && echo "      TCP拥塞算法: $tcp_congestion"

# 网络接口性能检查
echo ""
echo "    🔌 网络接口性能分析:"
for interface in $(ip link show | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/://' | grep -v lo); do
    if [ -d "/sys/class/net/$interface" ]; then
        # 获取接口统计
        rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo "0")
        tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo "0")
        rx_errors=$(cat /sys/class/net/$interface/statistics/rx_errors 2>/dev/null || echo "0")
        tx_errors=$(cat /sys/class/net/$interface/statistics/tx_errors 2>/dev/null || echo "0")
        
        # 转换为易读格式
        rx_gb=$(echo "scale=2; $rx_bytes / 1024 / 1024 / 1024" | bc)
        tx_gb=$(echo "scale=2; $tx_bytes / 1024 / 1024 / 1024" | bc)
        
        printf "      %-8s: 接收 %8.2fGB, 发送 %8.2fGB, 错误 %s/%s\n" "$interface" "$rx_gb" "$tx_gb" "$rx_errors" "$tx_errors"
        
        # 错误率检查
        if [ "$rx_errors" -gt 0 ] || [ "$tx_errors" -gt 0 ]; then
            WARNINGS+=("网络接口 $interface 存在传输错误")
        fi
    fi
done

# 安装建议
echo ""
print_info "网络测试工具推荐:"
echo "    📦 安装官方 Speedtest CLI (最推荐):"
echo "       curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash"
echo "       snap apt install speedtest"
echo ""
echo "    📦 安装专业网络工具:"
echo "       sudo apt install iperf3 mtr-tiny nload vnstat"
echo ""
echo "    📦 Python网络分析工具:"
echo "       pip3 install speedtest-cli psutil scapy"

# 通用网络质量评估
echo ""
print_info "网络环境综合评估..."

# 专业网络测试工具提示
if command -v iperf3 &> /dev/null; then
    print_pass "iperf3已安装 - 可进行专业带宽测试"
    echo "    💡 使用方法: iperf3 -c <测试服务器IP> -t 30"
    
    # 根据网络环境推荐测试服务器
    case $network_env in
        "domestic"*) 
            echo "    📍 推荐国内测试服务器:"
            echo "       • iperf3 -c speedtest.tele2.net -p 5201"
            echo "       • iperf3 -c ping.online.net -p 5201"
            ;;
        "international"*)
            echo "    📍 推荐国际测试服务器:"
            echo "       • iperf3 -c iperf.scottlinux.com -p 5201"
            echo "       • iperf3 -c speedtest.tele2.net -p 5201"
            ;;
    esac
else
    print_warning "建议安装iperf3进行专业网络性能测试"
    echo "    安装命令: sudo apt install iperf3"
fi

# MTU和网络配置检测
echo ""
mtu_size=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'mtu \K\d+' | head -1)
if [ -n "$mtu_size" ]; then
    if [ "$mtu_size" -eq 1500 ]; then
        print_status_line "网络MTU大小" "${mtu_size}字节" "OPTIMAL" "🟢"
    elif [ "$mtu_size" -lt 1500 ]; then
        print_status_line "网络MTU大小" "${mtu_size}字节" "SUBOPTIMAL" "🟡"
        print_warning "MTU大小低于标准值1500，可能影响网络性能"
    else
        print_status_line "网络MTU大小" "${mtu_size}字节" "JUMBO" "🔵"
        print_info "使用Jumbo Frame，适合高性能网络"
    fi
else
    print_info "无法检测MTU大小"
fi

# 网络性能总结
echo ""
case $network_env in
    "domestic_with_international")
        print_pass "===================网络环境优秀: 国内外双向连通==================="
        ;;
    "domestic_only")
        print_info "===================网络环境: 国内网络正常，国际网络受限==================="
        ;;
    "international_only")
        print_info "===================网络环境: 国际网络正常，国内网络受限==================="
        ;;
    "international_with_domestic")
        print_pass "===================网络环境良好: 国际网络为主，可访问国内==================="
        ;;
    "limited")
        print_warning "===================网络环境受限: 建议检查网络配置==================="
        ;;
esac

# 网络延迟测试
if command -v ping &> /dev/null; then
    print_info "测试网络延迟..."
    ping_result=$(ping -c 4 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{print "平均延迟: " $5 "ms"}')
    [ -n "$ping_result" ] && echo "    $ping_result"
fi

# 7. 系统服务检查
print_section "🔧 系统服务检查"

print_subsection "关键系统服务"
critical_services=("ssh" "cron" "systemd-resolved")
for service in "${critical_services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        print_pass "$service 服务运行正常"
    else
        # 检查替代服务
        case $service in
            "systemd-resolved")
                if systemctl is-active --quiet "NetworkManager" 2>/dev/null; then
                    print_pass "NetworkManager 服务运行正常"
                else
                    print_warning "DNS解析服务异常"
                fi
                ;;
            *)
                print_warning "$service 服务未运行"
                ;;
        esac
    fi
done

print_subsection "GPU相关服务"
gpu_services=("nvidia-persistenced" "nvidia-fabricmanager")
for service in "${gpu_services[@]}"; do
    if systemctl list-unit-files 2>/dev/null | grep -q "$service"; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_pass "$service 服务运行正常"
        else
            print_warning "$service 服务未运行"
        fi
    else
        print_info "$service 服务未安装"
    fi
done

# 8. 性能基准测试
print_section "📊 性能基准测试"

print_subsection "CPU性能基准"
if command -v sysbench &> /dev/null; then
    print_info "执行CPU基准测试 (10秒)..."
    cpu_bench=$(sysbench cpu --cpu-max-prime=10000 --threads=$cpu_cores --time=10 run 2>/dev/null | grep "events per second" | awk '{print $4}')
    if [ -n "$cpu_bench" ]; then
        print_status_line "CPU基准分数" "${cpu_bench} events/sec" "INFO" "🏃"
    else
        print_warning "CPU基准测试失败"
    fi
else
    print_warning "sysbench未安装，跳过CPU基准测试"
fi

print_subsection "内存性能基准"
if command -v sysbench &> /dev/null; then
    print_info "执行内存基准测试 (10秒)..."
    mem_bench=$(sysbench memory --memory-total-size=1G --time=10 run 2>/dev/null | grep "transferred" | awk '{print $3 " " $4}')
    if [ -n "$mem_bench" ]; then
        print_status_line "内存传输速率" "$mem_bench" "INFO" "💨"
    else
        print_warning "内存基准测试失败"
    fi
else
    print_warning "sysbench未安装，跳过内存基准测试"
fi

# 9. 软件环境检查
print_section "🐍 软件环境检查"

print_subsection "Python环境"
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version | awk '{print $2}')
    print_pass "Python3 版本: $python_version"
    
    if command -v pip3 &> /dev/null; then
        pip_version=$(pip3 --version | awk '{print $2}')
        print_pass "pip3 版本: $pip_version"
    else
        print_warning "pip3未安装"
    fi
    
    # 检查重要Python包
    important_packages=("numpy" "torch" "tensorflow" "pandas" "scikit-learn" "matplotlib" "jupyter")
    for package in "${important_packages[@]}"; do
        if python3 -c "import $package" 2>/dev/null; then
            version=$(python3 -c "import $package; print($package.__version__)" 2>/dev/null || echo "未知版本")
            print_pass "$package: $version"
        else
            print_info "$package: 未安装"
        fi
    done
else
    print_error "Python3未安装"
fi

print_subsection "容器环境"
if command -v docker &> /dev/null; then
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_pass "Docker 版本: $docker_version"
    
    if systemctl is-active --quiet docker 2>/dev/null; then
        print_pass "Docker服务运行正常"
        
        if docker ps >/dev/null 2>&1; then
            print_pass "Docker权限配置正确"
        else
            print_warning "Docker权限配置需要检查"
        fi
    else
        print_warning "Docker服务未运行"
    fi
    
    # 检查NVIDIA容器支持
    if docker info 2>/dev/null | grep -q "nvidia" || command -v nvidia-container-runtime &> /dev/null; then
        print_pass "NVIDIA容器运行时已配置"
    else
        print_warning "NVIDIA容器运行时未配置"
    fi
else
    print_warning "Docker未安装"
fi

# 10. 安全配置检查
print_section "🔒 安全配置检查"

print_subsection "系统安全状态"
if command -v ufw &> /dev/null; then
    ufw_status=$(ufw status 2>/dev/null | grep "Status:" | awk '{print $2}' || echo "unknown")
    case $ufw_status in
        "active") print_pass "UFW防火墙: 已启用" ;;
        "inactive") print_warning "UFW防火墙: 未启用" ;;
        *) print_info "UFW防火墙: 状态未知" ;;
    esac
elif command -v firewall-cmd &> /dev/null; then
    firewall_status=$(firewall-cmd --state 2>/dev/null || echo "inactive")
    case $firewall_status in
        "running") print_pass "Firewalld: 运行中" ;;
        *) print_warning "Firewalld: 未运行" ;;
    esac
else
    print_warning "未检测到防火墙配置"
fi

print_subsection "SSH配置"
if [ -f /etc/ssh/sshd_config ]; then
    root_login=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' 2>/dev/null || echo "默认")
    password_auth=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}' 2>/dev/null || echo "默认")
    
    case $root_login in
        "no"|"prohibit-password") print_pass "Root登录: $root_login (安全)" ;;
        "yes") print_warning "Root登录: $root_login (不推荐)" ;;
        *) print_info "Root登录: $root_login" ;;
    esac
    
    case $password_auth in
        "no") print_pass "密码认证: $password_auth (推荐密钥认证)" ;;
        "yes") print_warning "密码认证: $password_auth (建议使用密钥)" ;;
        *) print_info "密码认证: $password_auth" ;;
    esac
else
    print_warning "SSH配置文件不存在"
fi

# 11. 综合评估
print_section "📈 综合评估与交付建议"

# 计算评分
total_score=0
max_score=100

# 基础系统评分 (30分)
basic_score=30
if [ ${#ERRORS[@]} -gt 0 ]; then
    basic_score=$((basic_score - ${#ERRORS[@]} * 5))
fi
if [ ${#WARNINGS[@]} -gt 0 ]; then
    basic_score=$((basic_score - ${#WARNINGS[@]} * 2))
fi
basic_score=$((basic_score < 0 ? 0 : basic_score))
total_score=$((total_score + basic_score))

# GPU评分 (25分)
gpu_score=0
if command -v nvidia-smi &> /dev/null; then
    gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    if [ $gpu_count -gt 0 ]; then
        gpu_score=25
        # 检查GPU温度扣分
        max_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | sort -n | tail -1)
        if [ -n "$max_temp" ]; then
            if [ $max_temp -gt 85 ]; then
                gpu_score=15
            elif [ $max_temp -gt 75 ]; then
                gpu_score=20
            fi
        fi
    else
        gpu_score=5
    fi
fi
total_score=$((total_score + gpu_score))

# 性能评分 (25分)
perf_score=25
[ $cpu_usage -gt 80 ] && perf_score=$((perf_score - 5))
[ $mem_percent -gt 90 ] && perf_score=$((perf_score - 5))
total_score=$((total_score + perf_score))

# 软件环境评分 (20分)
soft_score=0
command -v python3 &> /dev/null && soft_score=$((soft_score + 5))
command -v docker &> /dev/null && soft_score=$((soft_score + 5))
command -v nvcc &> /dev/null && soft_score=$((soft_score + 5))
python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null | grep -q "True" && soft_score=$((soft_score + 5))
total_score=$((total_score + soft_score))

# 生成最终评估
print_subsection "最终评估结果"
echo ""
echo -e "${BOLD}  系统评分: ${total_score}/100${NC}"

# 评估等级
if [ $total_score -ge 90 ]; then
    grade="A+"
    grade_color=$GREEN
    delivery_status="✅ 推荐交付"
    delivery_color=$GREEN
elif [ $total_score -ge 80 ]; then
    grade="A"
    grade_color=$GREEN
    delivery_status="✅ 可以交付"
    delivery_color=$GREEN
elif [ $total_score -ge 70 ]; then
    grade="B"
    grade_color=$YELLOW
    delivery_status="⚠️  有条件交付"
    delivery_color=$YELLOW
elif [ $total_score -ge 60 ]; then
    grade="C"
    grade_color=$YELLOW
    delivery_status="⚠️  需要优化"
    delivery_color=$YELLOW
else
    grade="D"
    grade_color=$RED
    delivery_status="❌ 不建议交付"
    delivery_color=$RED
fi

echo -e "${BOLD}  评估等级: ${grade_color}${grade}${NC}"
echo -e "${BOLD}  交付建议: ${delivery_color}${delivery_status}${NC}"

# 问题汇总
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}${BOLD}严重问题 (${#ERRORS[@]}项):${NC}"
    for error in "${ERRORS[@]}"; do
        echo -e "  ${RED}❌${NC} $error"
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}警告事项 (${#WARNINGS[@]}项):${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo -e "  ${YELLOW}⚠️${NC} $warning"
    done
fi

# 生成详细报告
{
    echo "========================================"
    echo "企业级GPU服务器交付验收报告"
    echo "========================================"
    echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "服务器信息: ${vendor} ${model}"
    echo "序列号: ${serial}"
    echo "主机名: ${hostname}"
    echo "系统评分: ${total_score}/100"
    echo "评估等级: ${grade}"
    echo "交付状态: ${delivery_status}"
    echo ""
    echo "硬件配置:"
    echo "- CPU: ${cpu_model}"
    echo "- 内存: ${mem_total_gb}GB"
    echo "- GPU: $(nvidia-smi -L 2>/dev/null | wc -l) x NVIDIA GPU"
    echo ""
    echo "问题统计:"
    echo "- 严重问题: ${#ERRORS[@]} 项"
    echo "- 警告事项: ${#WARNINGS[@]} 项"
    echo ""
    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo "严重问题列表:"
        for error in "${ERRORS[@]}"; do
            echo "  - $error"
        done
        echo ""
    fi
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo "警告事项列表:"
        for warning in "${WARNINGS[@]}"; do
            echo "  - $warning"
        done
        echo ""
    fi
    echo "详细检查日志: $LOG_FILE"
    echo "报告生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
} > $REPORT_FILE

# 维护建议
print_section "🔧 维护建议"
echo "  🔹 定期监控GPU温度，保持工作温度 <80°C"
echo "  🔹 建议配置专业监控系统 (Prometheus + Grafana)"
echo "  🔹 定期更新NVIDIA驱动和CUDA版本"
echo "  🔹 保持系统安全补丁更新"
echo "  🔹 定期检查磁盘空间使用率 <85%"
echo "  🔹 建议建立自动化运维流程"

# 完成报告
print_header "检查完成"
echo -e "${BOLD}最终评估:${NC} ${grade_color}${grade} (${total_score}/100)${NC}"
echo -e "${BOLD}交付建议:${NC} ${delivery_color}${delivery_status}${NC}"
echo -e "${BOLD}详细报告:${NC} ${REPORT_FILE}"
echo -e "${CYAN}技术支持: 如有疑问请联系系统管理团队${NC}"

# 设置报告文件权限
chmod 644 $REPORT_FILE
chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $REPORT_FILE 2>/dev/null

log_info "服务器交付检查完成 - 评分: ${total_score}/100, 等级: ${grade}"

exit 0