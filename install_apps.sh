#!/bin/bash

# ==============================================================================
# UNIVERSAL SETUP SCRIPT - SMART OS DETECTION
# Hỗ trợ: Arch/CachyOS, Ubuntu/Debian, Fedora
# Tác giả: BaHung (Multi-OS Version)
# ==============================================================================

# --- MÀU SẮC ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- [AN TOÀN] CẤU HÌNH BẮT LỖI ---
set -e
set -u
set -o pipefail

# --- CHẾ ĐỘ DRY-RUN (GIẢ LẬP) ---
DRY_RUN=false

# Kiểm tra tham số đầu vào
if [[ "${1-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${BLUE}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│             ĐANG TIEN HANH CAI DAT           │${NC}"
    echo -e "${BLUE}│                                              │${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────┘${NC}"
fi

# Hàm xử lý khi gặp lỗi
handle_error() {
    local lineno="$1"
    local msg="$2"
    echo -e "\n${RED}[ERROR] Script gặp lỗi tại dòng $lineno: $msg${NC}"
    echo -e "${RED}[ABORT] Quá trình cài đặt đã bị hủy để bảo vệ hệ thống.${NC}"
    exit 1
}
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# --- HÀM THỰC THI LỆNH (EXECUTE WRAPPER) ---
execute() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would execute: $*${NC}"
    else
        "$@"
    fi
}

# --- BIẾN TOÀN CỤC ---
DISTRO=""
INSTALL_CMD=()
UPDATE_CMD=()

# ==============================================================================
# 1. HÀM PHÁT HIỆN HỆ ĐIỀU HÀNH
# ==============================================================================
detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        DISTRO=$ID
        if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" || "$DISTRO" == "linuxmint" || "$DISTRO" == "kali" || "$DISTRO" == "pop" ]]; then
            DISTRO="debian_based"
            INSTALL_CMD=(sudo apt install -y)
            UPDATE_CMD=(sudo apt update "&&" sudo apt upgrade -y)
        elif [[ "$DISTRO" == "arch" || "$DISTRO" == "cachyos" || "$DISTRO" == "manjaro" || "$DISTRO" == "endeavouros" ]]; then
            DISTRO="arch_based"
            INSTALL_CMD=(sudo pacman -S --needed --noconfirm)
            UPDATE_CMD=(sudo pacman -Syu --noconfirm)
        elif [[ "$DISTRO" == "fedora" || "$DISTRO" == "rhel" || "$DISTRO" == "centos" ]]; then
            DISTRO="fedora_based"
            INSTALL_CMD=(sudo dnf install -y)
            UPDATE_CMD=(sudo dnf update -y)
        else
            echo -e "${RED}[ERROR] Không hỗ trợ distro này: $ID${NC}"
            exit 1
        fi
    else
        echo -e "${RED}[ERROR] Không tìm thấy /etc/os-release.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  HỆ THỐNG PHÁT HIỆN: ${GREEN}${DISTRO^^}             ${BLUE}│${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────┘${NC}"
}

# ==============================================================================
# 2. HÀM CÀI ĐẶT CHO TỪNG HỆ (MODULES)
# ==============================================================================

install_arch_based() {
    echo -e "${YELLOW}[*] Đang chạy quy trình cho Arch Linux...${NC}"
    
    if command -v paru &> /dev/null; then AUR_HELPER="paru"; 
    elif command -v yay &> /dev/null; then AUR_HELPER="yay"; 
    else
        echo -e "${YELLOW}[+] Cần cài đặt yay...${NC}"
        if [ "$DRY_RUN" = true ]; then
             echo -e "${BLUE}[DRY-RUN] Would install yay-bin from AUR${NC}"
             AUR_HELPER="yay"
        else
             sudo pacman -S --needed --noconfirm git base-devel
             git clone https://aur.archlinux.org/yay-bin.git
             cd yay-bin && makepkg -si --noconfirm && cd .. && rm -rf yay-bin
             AUR_HELPER="yay"
        fi
    fi

    # Thêm fcitx5-im (trọn bộ) và fcitx5-bamboo (gõ tiếng Việt tốt nhất)
    PKGS_OFFICIAL=(
        "git" "base-devel" "docker" "docker-compose" "mariadb"
        "dbeaver" "telegram-desktop" "fastfetch"
        "fcitx5-im" "fcitx5-bamboo"
    )
    
    PKGS_AUR=(
        "visual-studio-code-bin" "miniconda3" "rustdesk-bin"
        "proton-vpn-gtk-app" "termius-app" "brave-bin"
        "wps-office" "ttf-wps-fonts"
    )

    execute "${INSTALL_CMD[@]}" "${PKGS_OFFICIAL[@]}"
    echo -e "${YELLOW}[*] Cài đặt gói AUR...${NC}"
    execute "$AUR_HELPER" -S --needed --noconfirm "${PKGS_AUR[@]}"
}

install_debian_based() {
    echo -e "${YELLOW}[*] Đang chạy quy trình cho Ubuntu/Debian...${NC}"
    
    # Thêm fcitx5 và fcitx5-unikey (Bamboo khó cài tự động trên Debian/Ubuntu hơn)
    execute "${INSTALL_CMD[@]}" git curl build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release \
        fcitx5 fcitx5-unikey

    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}[+] Installing Docker...${NC}"
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BLUE}[DRY-RUN] Would run: curl -fsSL https://get.docker.com | sh${NC}"
        else
            curl -fsSL https://get.docker.com | sh
        fi
    fi

    execute "${INSTALL_CMD[@]}" mariadb-server mariadb-client

    if ! command -v flatpak &> /dev/null; then
        execute "${INSTALL_CMD[@]}" flatpak gnome-software-plugin-flatpak
    fi
    execute sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    echo -e "${YELLOW}[+] Installing GUI Apps via Flatpak...${NC}"
    execute flatpak install -y flathub \
        com.visualstudio.code org.telegram.desktop com.brave.Browser \
        com.wps.Office com.rustdesk.RustDesk \
        io.dbeaver.DBeaverCommunity com.termius.Termius
}

install_fedora_based() {
    echo -e "${YELLOW}[*] Đang chạy quy trình cho Fedora...${NC}"
    
    execute "${INSTALL_CMD[@]}" dnf-plugins-core
    execute sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    
    # Thêm fcitx5 fcitx5-unikey
    execute "${INSTALL_CMD[@]}" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        fcitx5 fcitx5-unikey fcitx5-autostart

    execute "${INSTALL_CMD[@]}" mariadb mariadb-server

    if ! command -v flatpak &> /dev/null; then
        execute "${INSTALL_CMD[@]}" flatpak
    fi
    execute flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    echo -e "${YELLOW}[+] Installing GUI Apps via Flatpak...${NC}"
    execute flatpak install -y flathub \
        com.visualstudio.code org.telegram.desktop com.brave.Browser \
        com.wps.Office com.rustdesk.RustDesk \
        io.dbeaver.DBeaverCommunity com.termius.Termius
}

# ==============================================================================
# 3. CẤU HÌNH CHUNG SAU CÀI ĐẶT
# ==============================================================================
post_install_config() {
    echo -e "\n${BLUE}┌── POST INSTALL CONFIGURATION ──┐${NC}"
    
    echo -e "${YELLOW}[+] Cấu hình Docker Group...${NC}"
    execute sudo systemctl enable --now docker
    execute sudo usermod -aG docker "$USER" || true

    echo -e "${YELLOW}[+] Cấu hình Fcitx5 (Gõ tiếng Việt)...${NC}"
    # Tạo biến môi trường để Fcitx5 hoạt động tốt trên mọi ứng dụng
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would add environment variables to /etc/environment${NC}"
    else
        # Kiểm tra xem đã có cấu hình chưa để tránh ghi đè nhiều lần
        if ! grep -q "GTK_IM_MODULE=fcitx" /etc/environment; then
            echo -e "${YELLOW}    -> Thêm biến môi trường vào /etc/environment...${NC}"
            echo "GTK_IM_MODULE=fcitx" | execute sudo tee -a /etc/environment > /dev/null
            echo "QT_IM_MODULE=fcitx" | execute sudo tee -a /etc/environment > /dev/null
            echo "XMODIFIERS=@im=fcitx" | execute sudo tee -a /etc/environment > /dev/null
        else
            echo -e "${GREEN}    -> Cấu hình Fcitx5 đã tồn tại.${NC}"
        fi
    fi

    echo -e "${YELLOW}[+] Cấu hình MariaDB...${NC}"
    if [ ! -d "/var/lib/mysql/mysql" ] && command -v mariadb-install-db &> /dev/null; then
        echo -e "${YELLOW}    -> Khởi tạo database ban đầu...${NC}"
        execute sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    fi
    
    execute sudo systemctl enable --now mariadb
    
    if [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}    -> Đang chờ MariaDB khởi động...${NC}"
        sleep 5
        echo -e "\n${GREEN}[?] Bạn có muốn thiết lập mật khẩu ROOT cho MariaDB ngay không? (y/n)${NC}"
        if read -r -t 10 SETUP_DB_PASS && [[ "$SETUP_DB_PASS" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Nhập mật khẩu mới cho user 'root':${NC}"
            read -rsp "Password: " DB_ROOT_PASS
            echo ""
            if sudo mariadb -e "FLUSH PRIVILEGES;" &>/dev/null; then
                sudo mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}'; FLUSH PRIVILEGES;"
                echo -e "${GREEN}[OK] Đã thiết lập mật khẩu root!${NC}"
            else
                echo -e "${RED}[WARN] Không kết nối được DB.${NC}"
            fi
        fi
    else
        echo -e "${BLUE}[DRY-RUN] Would ask for MariaDB password setup here.${NC}"
    fi

    # Miniconda Config
    if [ -f "/opt/miniconda3/bin/conda" ] || [ "$DRY_RUN" = true ]; then
        echo -e "\n${YELLOW}[+] Cấu hình Miniconda3...${NC}"
        execute sudo ln -sf /opt/miniconda3/bin/conda /usr/local/bin/conda
        
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BLUE}[DRY-RUN] Would run conda init and config${NC}"
        else
            set +u
            eval "$(/opt/miniconda3/bin/conda shell.bash hook)"
            conda config --set auto_activate_base false
            conda init bash zsh fish
            set -u
        fi
    fi
}

# ==============================================================================
# 4. HÀM TỰ KIỂM TRA (VERIFICATION)
# ==============================================================================
verify_installation() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${BLUE}[DRY-RUN] Would verify installed applications now.${NC}"
        return
    fi

    echo -e "\n${BLUE}┌── VERIFYING INSTALLATION ──┐${NC}"
    declare -A CHECK_LIST=(
        ["Docker"]="docker" ["Git"]="git" ["MariaDB"]="mariadb"
        ["VS Code"]="code" ["DBeaver"]="dbeaver" ["Telegram"]="telegram-desktop"
        ["Fastfetch"]="fastfetch" ["Brave Browser"]="brave"
        ["WPS Office"]="wps" ["Termius"]="termius-app"
        ["RustDesk"]="rustdesk" ["Miniconda"]="conda"
        ["Fcitx5"]="fcitx5"
    )
    local errors=0
    for name in "${!CHECK_LIST[@]}"; do
        cmd="${CHECK_LIST[$name]}"
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}[OK] $name đã được cài đặt ($cmd)${NC}"
        elif command -v flatpak &> /dev/null && flatpak list | grep -q "$cmd"; then
             echo -e "${GREEN}[OK] $name đã được cài đặt (Flatpak)${NC}"
        else
             echo -e "${RED}[MISSING] Không tìm thấy: $name${NC}"
             ((errors++))
        fi
    done
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

detect_os
echo -e "${YELLOW}[*] Updating System...${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}[DRY-RUN] Would execute system update${NC}"
else
    eval "${UPDATE_CMD[*]}"
fi

case $DISTRO in
    "arch_based") install_arch_based ;;
    "debian_based") install_debian_based ;;
    "fedora_based") install_fedora_based ;;
esac

post_install_config
verify_installation

echo -e "\n${GREEN}┌──────────────────────────────────────────────┐${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}│               ĐÃ HOÀN THÀNH                  │${NC}"
else
    echo -e "${GREEN}│             CÀI ĐẶT HOÀN TẤT!                │${NC}"
fi
echo -e "${GREEN}└──────────────────────────────────────────────┘${NC}"
