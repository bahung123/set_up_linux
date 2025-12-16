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
# Tắt set -e để script không dừng khi gặp lỗi cài app (Soft Fail)
# set -e 
set -u
set -o pipefail
FAILED_APPS=()

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

# Hàm xử lý khi gặp lỗi (Chỉ dùng cho lỗi nghiêm trọng)
handle_error() {
    local lineno="$1"
    local msg="$2"
    echo -e "\n${RED}[CRITICAL] Lỗi hệ thống tại dòng $lineno: $msg${NC}"
    # Không exit ở đây nữa trừ khi cần thiết
}
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# --- HÀM THỰC THI LỆNH (EXECUTE WRAPPER) ---
execute() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would execute: $*${NC}"
    else
        "$@" || {
            echo -e "${RED}[FAIL] Lệnh thất bại: $*${NC}"
            FAILED_APPS+=("$*")
            return 1 # Trả về lỗi nhưng không dừng script
        }
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

# Hàm cài đặt Miniconda thủ công (cho Debian/Fedora)
install_miniconda_manual() {
    if [ -d "/opt/miniconda3" ]; then
        echo -e "${GREEN}[OK] Miniconda3 đã được cài đặt tại /opt/miniconda3${NC}"
        return
    fi
    
    echo -e "${YELLOW}[+] Đang tải và cài đặt Miniconda3 (Manual)...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would download and install Miniconda to /opt/miniconda3${NC}"
        return
    fi

    # Đảm bảo có wget
    if command -v dnf &> /dev/null; then execute sudo dnf install -y wget; fi
    if command -v apt &> /dev/null; then execute sudo apt install -y wget; fi

    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    execute sudo mkdir -p /opt/miniconda3
    execute sudo bash /tmp/miniconda.sh -b -u -p /opt/miniconda3
    rm -f /tmp/miniconda.sh
}

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
        "git" "base-devel" "docker" "docker-compose"
        "telegram-desktop" "fastfetch"
        "fcitx5-im" "fcitx5-bamboo"
        "texlive-meta"
    )
    
    PKGS_AUR=(
        "visual-studio-code-bin" "miniconda3" "rustdesk-bin"
        "proton-vpn-gtk-app" "brave-bin" "antigravity"
    )

    execute "${INSTALL_CMD[@]}" "${PKGS_OFFICIAL[@]}"
    echo -e "${YELLOW}[*] Cài đặt gói AUR...${NC}"
    execute "$AUR_HELPER" -S --needed --noconfirm "${PKGS_AUR[@]}"
}

install_debian_based() {
    echo -e "${YELLOW}[*] Đang chạy quy trình cho Ubuntu/Debian...${NC}"
    
    # Thêm fcitx5 và fcitx5-unikey (Bamboo khó cài tự động trên Debian/Ubuntu hơn)
    execute "${INSTALL_CMD[@]}" git curl wget build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release \
        fcitx5 fcitx5-unikey \
        texlive-full

    # VS Code Native
    echo -e "${YELLOW}[+] Installing VS Code (Native)...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would add VS Code repo and install${NC}"
    else
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        execute sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | execute sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        rm -f packages.microsoft.gpg
        execute sudo apt update
        execute sudo apt install -y code
    fi

    # Miniconda
    install_miniconda_manual 

    # Antigravity Setup
    echo -e "${YELLOW}[+] Adding Antigravity repo...${NC}"
    execute sudo mkdir -p /etc/apt/keyrings
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would add Antigravity GPG key and repo${NC}"
    else
        curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | execute sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
        echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | execute sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
        execute sudo apt update
    fi
    execute "${INSTALL_CMD[@]}" antigravity

    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}[+] Installing Docker...${NC}"
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BLUE}[DRY-RUN] Would run: curl -fsSL https://get.docker.com | sh${NC}"
        else
            curl -fsSL https://get.docker.com | sh
        fi
    fi

    if ! command -v flatpak &> /dev/null; then
        execute "${INSTALL_CMD[@]}" flatpak gnome-software-plugin-flatpak
    fi
    execute sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    echo -e "${YELLOW}[+] Installing GUI Apps via Flatpak...${NC}"
    execute flatpak install -y flathub \
        org.telegram.desktop com.brave.Browser \
        com.rustdesk.RustDesk \
        com.termius.Termius
}

install_fedora_based() {
    echo -e "${YELLOW}[*] Đang chạy quy trình cho Fedora...${NC}"
    
    # 1. Cài plugin cốt lõi (DNF tự bỏ qua nếu đã có)
    execute "${INSTALL_CMD[@]}" dnf-plugins-core
    
    # 2. Thêm Repo Docker (Dùng curl tải đè file -> An toàn khi chạy lại)
    echo -e "${YELLOW}[+] Checking Docker repo...${NC}"
    if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
        if [ "$DRY_RUN" = true ]; then
             echo -e "${BLUE}[DRY-RUN] Would download docker-ce.repo${NC}"
        else
             # Sửa: Dùng đúng link repo Fedora
             execute sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
        fi
    else
        echo -e "${GREEN}    -> Docker repo đã tồn tại. Bỏ qua.${NC}"
    fi
    
    # 3. Thêm Repo VS Code (Tạo file mới đè lên file cũ -> An toàn)
    echo -e "${YELLOW}[+] Checking VS Code repo...${NC}"
    if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BLUE}[DRY-RUN] Would add VS Code repo${NC}"
        else
            execute sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
            echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | execute sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
        fi
    else
        echo -e "${GREEN}    -> VS Code repo đã tồn tại. Bỏ qua.${NC}"
    fi

    # Antigravity Repo Check
    echo -e "${YELLOW}[+] Checking Antigravity repo...${NC}"
    if [ ! -f /etc/yum.repos.d/antigravity.repo ]; then
        if [ "$DRY_RUN" = true ]; then
             echo -e "${BLUE}[DRY-RUN] Would add Antigravity repo${NC}"
        else
            sudo tee /etc/yum.repos.d/antigravity.repo << EOL
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOL
        fi
    fi

    # Brave Browser Repo (Manual for Stability)
    echo -e "${YELLOW}[+] Checking Brave Browser repo...${NC}"
    if [ ! -f /etc/yum.repos.d/brave-browser.repo ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BLUE}[DRY-RUN] Would create /etc/yum.repos.d/brave-browser.repo${NC}"
        else
            sudo tee /etc/yum.repos.d/brave-browser.repo << EOL
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
EOL
            execute sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc || true
        fi
    else
        echo -e "${GREEN}    -> Brave repo đã tồn tại. Bỏ qua.${NC}"
    fi

    # 4. Refresh cache (Chạy nhiều lần cũng không sao, chỉ tốn chút thời gian)
    echo -e "${YELLOW}[+] Refreshing DNF cache...${NC}"
    execute sudo dnf clean all
    execute sudo dnf makecache

    # 5. Cài đặt App (DNF sẽ tự bỏ qua gói đã cài -> An toàn)
    execute "${INSTALL_CMD[@]}" antigravity
    execute "${INSTALL_CMD[@]}" code brave-browser docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        fcitx5 fcitx5-unikey fcitx5-autostart fcitx5-qt kcm-fcitx5 \

    # 5.1 LaTeX (Full scheme) - cài riêng theo yêu cầu
    execute sudo dnf install -y texlive-scheme-full

    # 6. Cài Miniconda (QUAN TRỌNG: Kiểm tra thư mục trước)
    # Đã có hàm install_miniconda_manual xử lý logic này rồi, gọi lại hàm đó cho gọn
    install_miniconda_manual

    # 7. Cài đặt các ứng dụng Native khác (Telegram, Termius, RustDesk, MySQL Workbench)
    echo -e "${YELLOW}[+] Installing Native Apps (RPM)...${NC}"
    
    # 7.1 RPM Fusion (Cần cho Telegram và nhiều codecs)
    echo -e "${YELLOW}    -> Configuring RPM Fusion...${NC}"
    if ! rpm -q rpmfusion-free-release &> /dev/null; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BLUE}[DRY-RUN] Would install RPM Fusion repos${NC}"
        else
            sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
        fi
    fi

    # [REMOVED] MySQL Workbench - Skipped per user request due to repo conflicts on Fedora 43

    # 7.2 Cài đặt Telegram và Termius qua Flatpak
    echo -e "${YELLOW}[+] Installing Apps via Flatpak (Telegram, Termius)...${NC}"
    if ! command -v flatpak &> /dev/null; then
        execute "${INSTALL_CMD[@]}" flatpak
    fi
    execute sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    execute flatpak install -y flathub org.telegram.desktop com.termius.Termius

    # 7.3 Cài đặt MySQL Workbench qua Snap (Fix lỗi trên Fedora)
    echo -e "${YELLOW}[+] Installing MySQL Workbench via Snap...${NC}"
    if ! command -v snap &> /dev/null; then
        echo -e "${YELLOW}    -> Installing Snapd...${NC}"
        execute "${INSTALL_CMD[@]}" snapd
        # Tạo symlink cho classic snap support (Bắt buộc trên Fedora)
        if [ ! -L /snap ]; then
             execute sudo ln -s /var/lib/snapd/snap /snap
        fi
        # Chờ snapd khởi động (quan trọng)
        if [ "$DRY_RUN" = false ]; then
             echo -e "${YELLOW}    -> Waiting for snapd to initialize...${NC}"
             execute sudo systemctl enable --now snapd.socket
             sleep 5 
        fi
    fi
    
    # Cài đặt MySQL Workbench
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would install mysql-workbench-community via snap${NC}"
    else
        # Kiểm tra xem đã cài chưa để tránh lỗi
        if ! snap list | grep -q "mysql-workbench-community"; then
             execute sudo snap install mysql-workbench-community
        else
             echo -e "${GREEN}    -> MySQL Workbench (Snap) đã được cài đặt.${NC}"
        fi
    fi

    # 7.4 RustDesk (Github Release)
    if ! command -v rustdesk &> /dev/null; then
        echo -e "${YELLOW}    -> Installing RustDesk (Latest)...${NC}"
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BLUE}[DRY-RUN] Would download and install RustDesk RPM${NC}"
        else
            # Lấy link download mới nhất từ GitHub API
            RUSTDESK_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest | grep "browser_download_url.*x86_64.rpm" | cut -d '"' -f 4 | head -n 1)
            
            if [ -z "$RUSTDESK_URL" ]; then
                RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/1.3.2/rustdesk-1.3.2-x86_64.rpm"
            fi
            
            echo -e "${YELLOW}       Downloading: $(basename "$RUSTDESK_URL")...${NC}"
            wget -q "$RUSTDESK_URL" -O /tmp/rustdesk.rpm
            
            if [ -s /tmp/rustdesk.rpm ]; then
                 execute sudo dnf install -y /tmp/rustdesk.rpm
            else
                 echo -e "${RED}[ERROR] Không tải được RustDesk.${NC}"
            fi
            rm -f /tmp/rustdesk.rpm
        fi
    fi
}

# ==============================================================================
# 3. CẤU HÌNH CHUNG SAU CÀI ĐẶT
# ==============================================================================
post_install_config() {
    echo -e "\n${BLUE}┌── POST INSTALL CONFIGURATION ──┐${NC}"
    
    # 1. Cấu hình Docker Group
    echo -e "${YELLOW}[+] Cấu hình Docker Group...${NC}"
    execute sudo systemctl enable --now docker
    
    # Thêm user vào group docker (Cần logout/login để có hiệu lực vĩnh viễn)
    execute sudo usermod -aG docker "$USER"
    
    # [FIX] Cấp quyền tạm thời cho socket để dùng được NGAY không cần logout
    # Quyền này sẽ reset sau khi reboot, lúc đó group permission ở trên sẽ có hiệu lực
    if [ -S /var/run/docker.sock ]; then
         echo -e "${YELLOW}    -> Cấp quyền nóng cho Docker Socket (Dùng ngay)...${NC}"
         execute sudo chmod 666 /var/run/docker.sock
    fi

    # 2. Cấu hình Fcitx5 (Chống ghi file environment nhiều lần)
    echo -e "${YELLOW}[+] Cấu hình Fcitx5...${NC}"
    
    # Chuyển bộ gõ (Có thể lỗi nếu daemon chưa chạy, nên dùng || true để không dừng script)
    if [ "$DRY_RUN" = false ] && command -v imsettings-switch &> /dev/null; then
        imsettings-switch fcitx5 || true
    fi

    # [QUAN TRỌNG] Kiểm tra kỹ trước khi ghi vào /etc/environment
    if [ "$DRY_RUN" = false ]; then
        if ! grep -q "GTK_IM_MODULE=fcitx" /etc/environment; then
            echo -e "${YELLOW}    -> Đang thêm biến môi trường...${NC}"
            echo "GTK_IM_MODULE=fcitx" | execute sudo tee -a /etc/environment > /dev/null
            echo "QT_IM_MODULE=fcitx" | execute sudo tee -a /etc/environment > /dev/null
            echo "XMODIFIERS=@im=fcitx" | execute sudo tee -a /etc/environment > /dev/null
        else
            echo -e "${GREEN}    -> Biến môi trường đã tồn tại. Bỏ qua.${NC}"
        fi
        
        # Tạo profile Unikey (ghi đè file profile nên an toàn)
        mkdir -p ~/.config/fcitx5
        if [ ! -f ~/.config/fcitx5/profile ]; then
             echo -e "[Groups/0]\nName=Default\nDefault Layout=us\nDefaultIM=unikey\n\n[Groups/0/Items/0]\nName=keyboard-us\nLayout=\n\n[Groups/0/Items/1]\nName=unikey\nLayout=" > ~/.config/fcitx5/profile
             echo -e "${GREEN}    -> Đã tạo profile Unikey.${NC}"
        fi
    fi

    # 3. Cấu hình Miniconda (Chống khởi tạo lại nhiều lần)
    if [ -d "/opt/miniconda3" ]; then
        echo -e "\n${YELLOW}[+] Cấu hình Miniconda3...${NC}"
        # Symlink dùng -sf (Force) để ghi đè nếu link cũ bị lỗi
        execute sudo ln -sf /opt/miniconda3/bin/conda /usr/local/bin/conda
        
        # Chỉ chạy conda init nếu chưa thấy đoạn code của conda trong .bashrc
        if ! grep -q ">>> conda initialize >>>" ~/.bashrc; then
             if [ "$DRY_RUN" = false ]; then
                set +u
                eval "$(/opt/miniconda3/bin/conda shell.bash hook)"
                conda config --set auto_activate_base false
                conda init bash zsh fish
                set -u
             fi
        else
             echo -e "${GREEN}    -> Conda đã được init trong .bashrc. Bỏ qua.${NC}"
        fi
    fi
} 

# ==============================================================================
# 5. DỌN DẸP HỆ THỐNG
# ==============================================================================
cleanup_system() {
    echo -e "\n${BLUE}┌── SYSTEM CLEANUP ──┐${NC}"
    echo -e "${YELLOW}[+] Cleaning package cache and unused dependencies...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY-RUN] Would clean package cache (apt autoremove/dnf clean/pacman -Sc)${NC}"
        return
    fi

    case $DISTRO in
        "debian_based")
            execute sudo apt autoremove -y
            execute sudo apt clean
            ;;
        "fedora_based")
            execute sudo dnf autoremove -y
            execute sudo dnf clean all
            ;;
        "arch_based")
             # Clean pacman cache
             # -Sc: Xóa tất cả gói không được cài đặt khỏi cache
             echo -e "${YELLOW}    -> Cleaning Arch pacman cache...${NC}"
             echo "y" | execute sudo pacman -Sc || true
             if command -v paccache &> /dev/null; then
                 execute sudo paccache -r
             fi
             ;;
    esac
    
    # Xóa file tạm nếu còn sót
    rm -f /tmp/miniconda.sh /tmp/Termius.rpm /tmp/rustdesk.rpm
    echo -e "${GREEN}[OK] System cleaned.${NC}"
}

# ==============================================================================
# 6. HÀM TỰ KIỂM TRA (VERIFICATION)
# ==============================================================================
verify_installation() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${BLUE}[DRY-RUN] Would verify installed applications now.${NC}"
        return
    fi

    echo -e "\n${BLUE}┌── VERIFYING INSTALLATION ──┐${NC}"
    declare -A CHECK_LIST=(
        ["Docker"]="docker" ["Git"]="git"
        ["VS Code"]="code" 
        ["Brave Browser"]="brave-browser"
        ["RustDesk"]="rustdesk" ["Miniconda"]="conda"
        ["Fcitx5"]="fcitx5"
        ["LaTeX (pdflatex)"]="pdflatex"
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
cleanup_system
verify_installation

echo -e "\n${GREEN}┌──────────────────────────────────────────────┐${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}│               ĐÃ HOÀN THÀNH                  │${NC}"
else
    echo -e "${GREEN}│             CÀI ĐẶT HOÀN TẤT!                │${NC}"
fi
echo -e "${GREEN}└──────────────────────────────────────────────┘${NC}"

if [ ${#FAILED_APPS[@]} -ne 0 ]; then
    echo -e "\n${RED}⚠️  CẢNH BÁO: Có ${#FAILED_APPS[@]} tác vụ bị lỗi:${NC}"
    for fail in "${FAILED_APPS[@]}"; do
        echo -e "${RED}  - $fail${NC}"
    done
    echo -e "${YELLOW}Hint: Hãy kiểm tra log để biết chi tiết hoặc cài thủ công các app trên.${NC}"
fi

echo -e "${YELLOW}[NOTE] Docker đã sẵn sàng! Nếu vẫn gặp lỗi Permission, hãy Logout và Login lại.${NC}"
echo -e "${YELLOW}[NOTE] Vui lòng khởi động lại máy để các thay đổi (như Fcitx5) có hiệu lực.${NC}"

# custom scrennshot spectacle -r -b 