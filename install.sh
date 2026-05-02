#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# speed-open: ติดตั้ง OpenCode + Zsh (p10k) + NvChad บน Termux
# รันครั้งเดียว: bash install.sh
# ครั้งแรกเปิด -> nvim auto
# ครั้งสองเปิด -> p10k configure auto
# ครั้งสามเปิด -> Hint: opencode
# ============================================================

set -e

export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export TMPDIR="${TMPDIR:-$PREFIX/tmp}"
mkdir -p "$TMPDIR"

PROJECT_DIR="$HOME/.config/speed-open"
LOG_DIR="$PROJECT_DIR"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR"

log_info()  { echo "[INFO] $*" | tee -a "$LOG_FILE"; }
log_error() { echo "[ERROR] $*" | tee -a "$LOG_FILE" >&2; }
log_ok()    { echo "[OK] $*" | tee -a "$LOG_FILE"; }

# ตรวจสอบ Termux
if [ -z "$TERMUX_VERSION" ]; then
    log_error "ต้องรันบน Termux เท่านั้น"
    exit 1
fi

# ======================= DEPENDENCIES =======================
install_deps() {
    log_info "ติดตั้งแพ็กเกจพื้นฐานที่จำเป็น..."
    pkg update -y
    pkg install -y curl tar proot-distro git zsh neovim termux-tools \
        fzf ripgrep fd lua54 luarocks nodejs python 2>&1 | tee -a "$LOG_FILE"
    log_ok "ติดตั้ง dependencies เสร็จ"
}

# ======================= OPencode ===========================
install_opencode() {
    if command -v opencode &>/dev/null; then
        log_info "OpenCode มีอยู่แล้ว --- ข้าม"
        return 0
    fi

    log_info "ติดตั้ง OpenCode..."

    LATEST_VERSION=$(curl -sI https://github.com/anomalyco/opencode/releases/latest \
        | grep -i location | sed -E 's#.*/tag/([^[:space:]]+).*#\1#')
    [ -z "$LATEST_VERSION" ] && { log_error "หาเวอร์ชันล่าสุดไม่เจอ"; return 1; }

    TAR_NAME="opencode-linux-arm64-musl.tar.gz"
    REPO="https://github.com/anomalyco/opencode/releases/download/$LATEST_VERSION/$TAR_NAME"
    ALPINE_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/alpine"

    if [ ! -d "$ALPINE_ROOT" ]; then
        proot-distro install alpine 2>&1 | tee -a "$LOG_FILE"
    fi

    proot-distro login alpine --shared-tmp -- /bin/ash -c \
        "apk update && apk upgrade && apk add --no-cache musl ca-certificates libstdc++ libgcc gcompat" 2>&1 | tee -a "$LOG_FILE"

    curl -L "$REPO" -o "$TMPDIR/$TAR_NAME"
    tar -zxf "$TMPDIR/$TAR_NAME" -C "$ALPINE_ROOT/bin"
    chmod +x "$ALPINE_ROOT/bin/opencode"

    # สร้าง wrapper
    cat <<'EOF' > "$PREFIX/bin/opencode"
#!/bin/bash
EXCLUDE_REGEX="^(PATH|LD_PRELOAD|LD_LIBRARY_PATH|PREFIX|HOME|PWD|OLDPWD|SHELL|IFS|_|SHLVL|PROMPT_COMMAND|TERMCAP|LS_COLORS|TERM)="
ENV_ARGS=()
while IFS= read -r line; do
    [[ -n "$line" && ! "$line" =~ $EXCLUDE_REGEX ]] && ENV_ARGS+=("--env" "$line")
done < <(env)
ENV_ARGS+=( "--env" "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt" "--env" "TERM=$TERM" "--env" "HOME=/root")
unset LD_PRELOAD
proot-distro login "${ENV_ARGS[@]}" --termux-home --shared-tmp --work-dir "$PWD" alpine -- /bin/opencode "$@"
EOF
    chmod +x "$PREFIX/bin/opencode"

    log_ok "OpenCode ติดตั้งแล้ว (ใช้คำสั่ง: opencode)"
    return 0
}

# ======================= ZSH + P10K ========================
install_zsh() {
    # Oh-My-Zsh
    if [ -f ~/.oh-my-zsh/oh-my-zsh.sh ]; then
        log_info "Oh-My-Zsh มีอยู่แล้ว --- ข้าม"
    else
        log_info "ติดตั้ง Oh-My-Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Powerlevel10k
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
        log_info "ติดตั้ง Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
            ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    else
        log_info "P10k มีอยู่แล้ว"
    fi

    # ตั้ง theme ใน .zshrc
    if ! grep -q "powerlevel10k/powerlevel10k" ~/.zshrc; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
    fi

    # Plugins
    PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    plugins=(
        zsh-autosuggestions
        zsh-syntax-highlighting
        zsh-completions
        zsh-history-substring-search
        fzf
    )
    for plugin in "${plugins[@]}"; do
        if [ ! -d "$PLUGIN_DIR/$plugin" ]; then
            log_info "ติดตั้ง plugin: $plugin"
            case $plugin in
                zsh-autosuggestions)
                    git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR/$plugin" ;;
                zsh-syntax-highlighting)
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGIN_DIR/$plugin" ;;
                zsh-completions)
                    git clone https://github.com/zsh-users/zsh-completions "$PLUGIN_DIR/$plugin" ;;
                zsh-history-substring-search)
                    git clone https://github.com/zsh-users/zsh-history-substring-search "$PLUGIN_DIR/$plugin" ;;
                fzf)
                    git clone https://github.com/unixorn/fzf-zsh-plugin.git "$PLUGIN_DIR/fzf" ;;
                *) ;;
            esac
        fi
    done

    # เพิ่ม plugin list ใน .zshrc
    plugin_list="git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search fzf"
    if grep -q "^plugins=" ~/.zshrc; then
        sed -i "s/^plugins=.*/plugins=($plugin_list)/" ~/.zshrc
    else
        echo "plugins=($plugin_list)" >> ~/.zshrc
    fi

    # ---- เพิ่ม Stage Manager ต่อท้าย .zshrc ----
    STAGE_BLOCK=$(cat <<'STAGE_EOF'

# --- speed-open stage manager ---
if [[ -f ~/.speed-open-stage ]]; then
  STAGE=$(cat ~/.speed-open-stage)
  if [[ "$STAGE" = "1" ]]; then
    echo -e "\n\033[1;36m[SETUP] Powerlevel10k configuration wizard\033[0m"
    p10k configure
    echo "2" > ~/.speed-open-stage
    echo -e "\n\033[1;32m[OK] p10k configured. Restart shell to continue.\033[0m"
  elif [[ "$STAGE" = "2" ]]; then
    echo -e "\n\033[1;33m[HINT] พิมพ์ 'opencode' เพื่อเปิด Editor\033[0m"
    echo "3" > ~/.speed-open-stage
  fi
fi
STAGE_EOF
)

    if ! grep -q "speed-open stage manager" ~/.zshrc; then
        echo "$STAGE_BLOCK" >> ~/.zshrc
        log_info "เพิ่ม Stage Manager ใน .zshrc"
    else
        log_info "Stage Manager มีอยู่แล้วใน .zshrc"
    fi

    # เปลี่ยน shell default เป็น zsh
    if [ "$SHELL" != "$PREFIX/bin/zsh" ]; then
        log_info "เปลี่ยน shell default เป็น zsh..."
        chsh -s "$PREFIX/bin/zsh" 2>/dev/null || log_error "ไม่สามารถเปลี่ยน shell ได้ (ลอง chsh เอง)"
    fi

    log_ok "Zsh + P10k + plugins + Stage Manager ติดตั้งแล้ว"
    return 0
}

# ======================= NVCHAD ============================
install_nvchad() {
    if [ -d ~/.config/nvim ]; then
        log_info "~/.config/nvim มีอยู่แล้ว --- ข้าม NvChad"
        return 0
    fi

    log_info "ติดตั้ง NvChad..."
    git clone https://github.com/NvChad/starter ~/.config/nvim --depth 1
    log_ok "NvChad ติดตั้งแล้ว"
    return 0
}

# ======================== MAIN =============================
main() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   speed-open: automated installer    ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    install_deps
    install_opencode
    install_zsh
    install_nvchad

    # ตั้งค่า stage ครั้งแรก (เฉพาะเมื่อยังไม่มี)
    if [ ! -f ~/.speed-open-stage ]; then
        echo "1" > ~/.speed-open-stage
        NEED_NVIM=true
    else
        NEED_NVIM=false
        log_info "Stage file มีอยู่แล้ว ข้ามการเปิด nvim อัตโนมัติ"
    fi

    log_info "ติดตั้งทั้งหมดเสร็จ!"

    if [ "$NEED_NVIM" = true ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  🚀 กำลังเปิด Neovim (NvChad) ให้อัตโนมัติ"
        echo "     หลังจากออกจาก nvim → ปิด Termux"
        echo "     แล้วเปิดใหม่เพื่อตั้งค่า p10k"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        sleep 2
        nvim
    else
        echo ""
        echo "✅ เปิด Termux ครั้งต่อไป Zsh จะพาคุณไป p10k configure โดยอัตโนมัติ"
    fi
}

# รองรับ --help, --all, หรือไม่มีอะไรก็รันเลย
case "${1:-}" in
    --help|-h)
        echo "วิธีใช้: bash install.sh [--all]"
        echo "  --all   ติดตั้งทุกอย่าง (เป็น default อยู่แล้ว)"
        exit 0
        ;;
    --all|"")
        main
        ;;
    *)
        echo "ตัวเลือกไม่รู้จัก ใช้ --help สำหรับวิธีใช้"
        exit 1
        ;;
esac
