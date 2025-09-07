#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 设置变量
UNPACKBOOTIMG_REPO="https://github.com/anestisb/android-unpackbootimg.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USE_SUDO="true" # 默认使用sudo

# 询问用户是否使用sudo
ask_sudo_usage() {
    echo -e "${YELLOW}脚本需要安装一些依赖包。${NC}"
    read -p "是否使用sudo权限安装依赖? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        USE_SUDO="false"
        echo -e "${YELLOW}将不使用sudo安装依赖。${NC}"
    else
        USE_SUDO="true"
        echo -e "${YELLOW}将使用sudo安装依赖。${NC}"
    fi
}

# 检查并安装必要工具
check_dependencies() {
    local missing_deps=()
    
    # 检查命令是否存在
    local commands=("git" "python3" "pip3" "dtc" "make" "hexdump")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}所有必要工具都已安装。${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}缺少以下工具: ${missing_deps[*]}${NC}"
    
    # 检测发行版
    local distro
    if [ -f /etc/os-release ]; then
        distro=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    else
        echo -e "${YELLOW}无法检测Linux发行版，按Debian处理。${NC}"
        distro="debian"
    fi
    
    # 根据发行版设置安装命令
    local install_cmd
    case "$distro" in
        "ubuntu"|"debian")
            if [ "$USE_SUDO" = "true" ]; then
                install_cmd="sudo apt-get install -y"
            else
                install_cmd="apt-get install -y"
            fi
            ;;
        "fedora")
            if [ "$USE_SUDO" = "true" ]; then
                install_cmd="sudo dnf install -y"
            else
                install_cmd="dnf install -y"
            fi
            ;;
        "centos"|"rhel")
            if [ "$USE_SUDO" = "true" ]; then
                install_cmd="sudo yum install -y"
            else
                install_cmd="yum install -y"
            fi
            ;;
        "arch")
            if [ "$USE_SUDO" = "true" ]; then
                install_cmd="sudo pacman -S --noconfirm"
            else
                install_cmd="pacman -S --noconfirm"
            fi
            ;;
        *)
            echo -e "${YELLOW}不支持的发行版: $distro, 按Debian处理。${NC}"
            if [ "$USE_SUDO" = "true" ]; then
                install_cmd="sudo apt-get install -y"
            else
                install_cmd="apt-get install -y"
            fi
            ;;
    esac
    
    # 构建安装包列表
    local packages=()
    for dep in "${missing_deps[@]}"; do
        case "$dep" in
            "dtc")
                if [ "$distro" = "arch" ]; then
                    packages+=("dtc")
                else
                    packages+=("device-tree-compiler")
                fi
                ;;
            "pip3")
                if [ "$distro" = "arch" ]; then
                    packages+=("python-pip")
                else
                    packages+=("python3-pip")
                fi
                ;;
            "hexdump")
                if [ "$distro" = "arch" ]; then
                    packages+=("util-linux")
                else
                    packages+=("bsdmainutils")
                fi
                ;;
            *)
                packages+=("$dep")
                ;;
        esac
    done
    
    # 询问用户是否安装
    read -p "是否安装缺失的依赖? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}正在安装依赖: ${packages[*]}${NC}"
        if ! $install_cmd "${packages[@]}"; then
            echo -e "${RED}安装失败。${NC}"
            return 1
        fi
        echo -e "${GREEN}依赖安装成功。${NC}"
        return 0
    else
        echo -e "${RED}用户取消安装，脚本无法继续。${NC}"
        return 1
    fi
}

# 检查必要文件是否存在
check_required_files() {
    local required_files=("boot.img")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${YELLOW}请将以下文件放置在脚本目录 ($SCRIPT_DIR):${NC}"
        printf '%s\n' "${missing_files[@]}"
        echo -e "${YELLOW}可选文件: qcom,msm-id, qcom,board-id, model${NC}"
        return 1
    fi
    
    echo -e "${GREEN}所有必要文件都已就位。${NC}"
    return 0
}

# 克隆并编译unpackbootimg
setup_unpackbootimg() {
    echo -e "${BLUE}正在克隆unpackbootimg工具...${NC}"
    if [ -d "android-unpackbootimg" ]; then
        echo -e "${YELLOW}android-unpackbootimg目录已存在，跳过克隆。${NC}"
        return 0
    fi
    
    if ! git clone "$UNPACKBOOTIMG_REPO"; then
        echo -e "${RED}克隆unpackbootimg失败。${NC}"
        return 1
    fi
    
    echo -e "${GREEN}unpackbootimg克隆成功。${NC}"
    return 0
}

# 编译unpackbootimg
compile_unpackbootimg() {
    echo -e "${BLUE}正在编译unpackbootimg...${NC}"
    cd android-unpackbootimg || return 1
    
    if ! make; then
        echo -e "${RED}编译unpackbootimg失败。${NC}"
        cd ..
        return 1
    fi
    
    cd ..
    echo -e "${GREEN}unpackbootimg编译成功。${NC}"
    return 0
}

# 解压boot.img
unpack_bootimg() {
    echo -e "${BLUE}正在解压boot.img...${NC}"
    cd android-unpackbootimg || return 1
    
    # 复制boot.img到工作目录
    cp "$SCRIPT_DIR/boot.img" .
    
    # 创建输出目录
    mkdir -p output
    
    # 解压boot.img
    if ! ./unpackbootimg -i boot.img -o output; then
        echo -e "${RED}解压boot.img失败。${NC}"
        cd ..
        return 1
    fi
    
    # 复制output目录到上级目录
    cp -r output ..
    
    cd ..
    echo -e "${GREEN}boot.img解压成功。${NC}"
    return 0
}

# 安装extract-dtb工具
install_extract_dtb() {
    echo -e "${BLUE}正在安装extract-dtb工具...${NC}"
    if [ "$USE_SUDO" = "true" ]; then
        if ! sudo pip3 install extract-dtb; then
            echo -e "${RED}安装extract-dtb失败。${NC}"
            return 1
        fi
    else
        if ! pip3 install --user extract-dtb; then
            echo -e "${RED}安装extract-dtb失败。${NC}"
            return 1
        fi
    fi
    echo -e "${GREEN}extract-dtb安装成功。${NC}"
    return 0
}

# 提取设备树
extract_dtb() {
    echo -e "${BLUE}正在提取设备树...${NC}"
    cd output || return 1
    
    local dtb_file
    if [ -f "boot.img-dtb" ]; then
        dtb_file="boot.img-dtb"
    elif [ -f "boot.img-zImage" ]; then
        dtb_file="boot.img-zImage"
    else
        echo -e "${RED}未找到boot.img-dtb或boot.img-zImage文件。${NC}"
        cd ..
        return 1
    fi
    
    # 使用extract-dtb提取设备树
    if ! extract-dtb "$dtb_file"; then
        echo -e "${RED}提取设备树失败。${NC}"
        cd ..
        return 1
    fi
    
    # 创建dtb目录（如果extract-dtb没有自动创建）
    mkdir -p dtb
    mv *.dtb dtb/ 2>/dev/null || true
    
    cd ..
    echo -e "${GREEN}设备树提取成功。${NC}"
    return 0
}

# 反编译设备树
decompile_dtb() {
    echo -e "${BLUE}正在反编译设备树...${NC}"
    cd output/dtb || return 1
    
    # 创建输出目录
    mkdir -p output
    
    # 批量反编译.dtb文件
    for i in *.dtb; do
        if [ -f "$i" ]; then
            echo -e "${BLUE}正在反编译 $i${NC}"
            if ! dtc -I dtb -O dts "$i" -o "output/${i}.dts"; then
                echo -e "${RED}反编译 $i 失败。${NC}"
            fi
        fi
    done
    
    cd ../..
    echo -e "${GREEN}设备树反编译成功。${NC}"
    return 0
}

# 读取二进制文件的16进制值
read_binary_id() {
    local file_path="$1"
    local id_type="$2"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${YELLOW}未找到$id_type文件${NC}"
        return 1
    fi
    
    # 使用hexdump读取二进制文件的16进制值
    local hex_value=$(hexdump -v -e '/1 "%02X "' "$file_path" | sed 's/ $//')
    
    if [ -z "$hex_value" ]; then
        echo -e "${RED}读取$id_type文件失败。${NC}"
        return 1
    fi
    
    # 将十六进制值转换为设备树格式
    # 假设格式为: 00 00 01 53 00 02 00 00 -> 0x153 0x20000
    # 分成两部分，每部分4字节
    local part1=$(echo $hex_value | cut -d' ' -f1-4 | tr -d ' ')
    local part2=$(echo $hex_value | cut -d' ' -f5-8 | tr -d ' ')
    
    # 转换为十进制，然后再转回十六进制（去掉前导零）
    local dec1=$((16#$part1))
    local dec2=$((16#$part2))
    
    local hex1=$(printf "0x%X" $dec1)
    local hex2=$(printf "0x%X" $dec2)
    
    local result="${hex1}${hex2}"
    
    echo "$result"
    return 0
}

# 读取文本文件内容
read_text_file() {
    local file_path="$1"
    local file_type="$2"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${YELLOW}未找到$file_type文件${NC}"
        return 1
    fi
    
    local content=$(cat "$file_path")
    echo "$content"
    return 0
}

# 读取MSM-ID、Board-ID和Model信息
read_device_info() {
    local msm_id_file="$SCRIPT_DIR/qcom,msm-id"
    local board_id_file="$SCRIPT_DIR/qcom,board-id"
    local model_file="$SCRIPT_DIR/model"
    
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}              设备信息                  ${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # 读取MSM-ID
    MSM_ID=$(read_binary_id "$msm_id_file" "MSM-ID")
    if [ $? -ne 0 ]; then
        MSM_ID="未提供"
    else
        echo -e "${GREEN}MSM-ID文件内容: $(hexdump -v -e '/1 "%02X "' "$msm_id_file" | sed 's/ $//')${NC}"
    fi
    
    # 读取Board-ID
    BOARD_ID=$(read_binary_id "$board_id_file" "Board-ID")
    if [ $? -ne 0 ]; then
        BOARD_ID="未提供"
    else
        echo -e "${GREEN}Board-ID文件内容: $(hexdump -v -e '/1 "%02X "' "$board_id_file" | sed 's/ $//')${NC}"
    fi
    
    # 读取Model
    MODEL=$(read_text_file "$model_file" "Model")
    if [ $? -ne 0 ]; then
        MODEL="未提供"
    else
        echo -e "${GREEN}Model文件内容: $(cat "$model_file")${NC}"
    fi
    
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}MSM-ID: $MSM_ID${NC}"
    echo -e "${GREEN}Board-ID: $BOARD_ID${NC}"
    echo -e "${GREEN}Model: $MODEL${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# 从设备树文件中提取信息
extract_info_from_dts() {
    local dts_file="$1"
    
    # 提取设备树中的MSM-ID
    local dts_msm_id=$(grep -o "qcom,msm-id\s*=\s*<[^>]*>" "$dts_file" | head -1 | sed 's/.*<\([^>]*\)>.*/\1/' | tr -d '[:space:]')
    
    # 提取设备树中的Board-ID
    local dts_board_id=$(grep -o "qcom,board-id\s*=\s*<[^>]*>" "$dts_file" | head -1 | sed 's/.*<\([^>]*\)>.*/\1/' | tr -d '[:space:]')
    
    # 提取设备树中的Model
    local dts_model=$(grep -o "model\s*=\s*\"[^\"]*\"" "$dts_file" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
    
    # 提取设备树中的兼容性信息
    local dts_compatible=$(grep -o "compatible\s*=\s*\"[^\"]*\"" "$dts_file" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
    
    echo "$dts_msm_id|$dts_board_id|$dts_model|$dts_compatible"
}

# 显示设备树文件信息
display_dts_info() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}          设备树文件信息                ${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    cd output/dtb/output || return 1
    
    # 创建信息汇总文件
    local summary_file="$SCRIPT_DIR/device_tree_summary.txt"
    echo "设备树文件信息汇总" > "$summary_file"
    echo "==================" >> "$summary_file"
    echo "" >> "$summary_file"
    
    echo "提供的设备信息:" >> "$summary_file"
    echo "MSM-ID: $MSM_ID" >> "$summary_file"
    echo "Board-ID: $BOARD_ID" >> "$summary_file"
    echo "Model: $MODEL" >> "$summary_file"
    echo "" >> "$summary_file"
    echo "设备树文件信息:" >> "$summary_file"
    echo "" >> "$summary_file"
    
    # 遍历所有.dts文件
    for dts_file in *.dts; do
        if [ -f "$dts_file" ]; then
            echo -e "${BLUE}文件: $dts_file${NC}"
            
            # 提取设备树中的信息
            local dts_info=$(extract_info_from_dts "$dts_file")
            local dts_msm_id=$(echo "$dts_info" | cut -d'|' -f1)
            local dts_board_id=$(echo "$dts_info" | cut -d'|' -f2)
            local dts_model=$(echo "$dts_info" | cut -d'|' -f3)
            local dts_compatible=$(echo "$dts_info" | cut -d'|' -f4)
            
            # 显示信息
            echo -e "${GREEN}  MSM-ID: $dts_msm_id${NC}"
            echo -e "${GREEN}  Board-ID: $dts_board_id${NC}"
            echo -e "${GREEN}  Model: $dts_model${NC}"
            echo -e "${GREEN}  Compatible: $dts_compatible${NC}"
            echo ""
            
            # 写入汇总文件
            echo "文件: $dts_file" >> "$summary_file"
            echo "MSM-ID: $dts_msm_id" >> "$summary_file"
            echo "Board-ID: $dts_board_id" >> "$summary_file"
            echo "Model: $dts_model" >> "$summary_file"
            echo "Compatible: $dts_compatible" >> "$summary_file"
            echo "" >> "$summary_file"
        fi
    done
    
    echo -e "${GREEN}详细信息已保存到: $summary_file${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    cd ../../..
    return 0
}

# 主函数
main() {
    echo -e "${GREEN}=== 高通设备设备树提取脚本 ===${NC}"
    
    # 询问是否使用sudo
    ask_sudo_usage
    
    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi
    
    # 检查必要文件
    if ! check_required_files; then
        exit 1
    fi
    
    # 读取设备信息
    read_device_info
    
    # 设置unpackbootimg
    if ! setup_unpackbootimg; then
        exit 1
    fi
    
    # 编译unpackbootimg
    if ! compile_unpackbootimg; then
        exit 1
    fi
    
    # 解压boot.img
    if ! unpack_bootimg; then
        exit 1
    fi
    
    # 安装extract-dtb
    if ! install_extract_dtb; then
        exit 1
    fi
    
    # 提取设备树
    if ! extract_dtb; then
        exit 1
    fi
    
    # 反编译设备树
    if ! decompile_dtb; then
        exit 1
    fi
    
    # 显示设备树文件信息
    display_dts_info
    
    echo -e "${GREEN}=== 设备树提取完成 ===${NC}"
    echo -e "${GREEN}提取的设备树文件位于: $SCRIPT_DIR/output/dtb/output/${NC}"
}

# 执行主函数
main "$@"
