#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# speed-open: One-Liner Setup (No Menu)
# วิธีใช้:curl -sL https://raw.githubusercontent.com/Nn-2499/speed-open/main/setup.sh | bash 
# ============================================================

set -e

# ---- สี ----
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 speed-open: Auto Setup${NC}"

# ---- 1. ติดตั้ง Dependencies ----
echo -e "${YELLOW}📦 ติดตั้ง dependencies...${NC}"
pkg update -y
pkg install -y curl tar proot-distro git zsh neovim termux-tools fzf ripgrep fd

# ---- 2. ฟอนต์ Powerline ----
mkdir -p ~/.termux
curl -L "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf" \
    -o ~/.termux/font.ttf

# ---- 3. OpenCode (ผ่าน proot-distro) ----
echo -e "${YELLOW}📦 ติดตั้ง OpenCode...${NC}"
proot-distro install alpine
proot-distro login alpine -- /bin/ash -c "apk update && apk upgrade && apk add --no-cache musl ca-certificates libstdc++ libgcc gcompat"

LATEST_VERSION=$(curl -sI https://github.com/anomalyco/opencode/releases/latest | grep -i location | sed -E 's#.*/tag/([^[:space:]]+).*#\1#')
TAR_NAME="opencode-linux-arm64-musl.tar.gz"
curl -L "https://github.com/anomalyco/opencode/releases/download/$LATEST_VERSION/$TAR_NAME" -o "$PREFIX/tmp/$TAR_NAME"
tar -zxf "$PREFIX/tmp/$TAR_NAME" -C "$PREFIX/var/lib/proot-distro/installed-rootfs/alpine/bin"
chmod +x "$PREFIX/var/lib/proot-distro/installed-rootfs/alpine/bin/opencode"

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

# ---- 4. Oh-My-Zsh + P10k ----
echo -e "${YELLOW}📦 ติดตั้ง Zsh + P10k...${NC}"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc

# Plugins
PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGIN_DIR/zsh-syntax-highlighting"
git clone https://github.com/zsh-users/zsh-completions "$PLUGIN_DIR/zsh-completions"
git clone https://github.com/zsh-users/zsh-history-substring-search "$PLUGIN_DIR/zsh-history-substring-search"
git clone https://github.com/unixorn/fzf-zsh-plugin.git "$PLUGIN_DIR/fzf"

sed -i "s/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search fzf)/" ~/.zshrc

# ---- 5. เปลี่ยน Shell เป็น zsh (Termux Way) ----
mkdir -p ~/.termux
echo "shell_command = $PREFIX/bin/zsh -l" >> ~/.termux/termux.properties

# ---- 6. NvChad ----
echo -e "${YELLOW}📦 ติดตั้ง NvChad...${NC}"
git clone https://github.com/NvChad/starter ~/.config/nvim --depth 1

# ---- 7. Git Global ----
git config --global init.defaultBranch main
git config --global pull.rebase false

# ---- 8. เปลี่ยน Prompt เป็น "opencode" ----
echo "export PROMPT='opencode %~ %# '" >> ~/.zshrc

# ---- 9. เปิด nvim + p10k configure อัตโนมัติ ----
echo -e "${GREEN}✅ ติดตั้งเสร็จ!${NC}"
echo -e "${BLUE}🔹 กำลังเปิด nvim เพื่อติดตั้ง plugins...${NC}"
nvim +"Lazy sync" +qa

echo -e "${BLUE}🔹 กำลังเปิด p10k configure...${NC}"
echo -e "${YELLOW}⚠️ กรุณาตั้งค่าธีมตามต้องการ${NC}"
zsh -c "source ~/.zshrc && p10k configure"

# ---- 10. สรุป ----
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✅ ติดตั้งสมบูรณ์!${NC}"
echo ""
echo -e "${BLUE}🔹 เปิดโปรเจ็ค: opencode${NC}"
echo -e "${BLUE}🔹 เปิด nvim: nvim${NC}"
echo -e "${BLUE}🔹 ตั้งค่า p10k: p10k configure${NC}"
echo ""
echo -e "${YELLOW}⚠️ ปิด-เปิด Termux ใหม่เพื่อให้ฟอนต์มีผล${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
