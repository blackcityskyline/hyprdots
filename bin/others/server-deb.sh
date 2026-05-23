#!/usr/bin/env bash
# =============================================================================
# Debian/Debian-based server setup script
# All packages install system-wide (/usr/local/bin or via apt/deb)
# ~/apps/tmp — temporary files only, removed on exit
# =============================================================================

# No set -e: we handle errors per-section so one failure doesn't kill the run.
# set -u catches undefined variables; pipefail catches silent pipe failures.
set -uo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✔${NC}  $*"; }
info() { echo -e "${BLUE}→${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "${RED}✖${NC}  $*" >&2; }
hdr()  { echo -e "\n${BOLD}${BLUE}══ $* ══${NC}"; }
dbg()  { echo -e "   ${YELLOW}·${NC} $*"; }   # verbose/debug line

# ── Dirs ─────────────────────────────────────────────────────────────────────
TMP_DIR="$HOME/apps/tmp"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"; echo ""' EXIT

INSTALL_DIR="/usr/local/bin"

# ── Architecture ─────────────────────────────────────────────────────────────
DEB_ARCH=$(dpkg --print-architecture)
case "$DEB_ARCH" in
    amd64) GNU_ARCH="x86_64"  ;;
    arm64) GNU_ARCH="aarch64" ;;
    armhf) GNU_ARCH="armv7"   ;;
    *)     GNU_ARCH="$DEB_ARCH" ;;
esac
dbg "Architecture: DEB=$DEB_ARCH  GNU=$GNU_ARCH"

# ── Sudo ─────────────────────────────────────────────────────────────────────
if [[ "$EUID" -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

# ── Helpers ──────────────────────────────────────────────────────────────────
has() { command -v "$1" &>/dev/null; }

apt_install() {
    info "apt-get install: $*"
    # Show full apt output for debugging
    if $SUDO apt-get install -y --no-install-recommends "$@"; then
        ok "apt: $* — done"
    else
        err "apt: failed to install $*"
        return 1
    fi
}

# Returns the download URL for the first matching asset in the latest release.
# grep exit code 1 (no match) is suppressed — returns empty string instead.
gh_asset_url() {
    local repo="$1" pattern="$2"
    local json
    json=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest") || {
        err "GitHub API request failed for $repo"
        echo ""; return
    }
    # Each step in the pipeline: suppress non-zero exit so set -o pipefail
    # doesn't kill the script when grep finds no matches.
    echo "$json" \
        | grep "browser_download_url" \
        | grep -Ev '\.sha256|\.sha512|\.asc|\.sig|checksums|sbom' \
        | { grep -E "$pattern" || true; } \
        | head -1 \
        | cut -d'"' -f4
}

# Install .deb via apt — resolves dependencies automatically.
install_deb() {
    local name="$1" url="$2"
    local deb="$TMP_DIR/${name}.deb"
    info "Downloading $name .deb from: $url"
    if curl -fsSL "$url" -o "$deb"; then
        dbg "Download OK ($(du -sh "$deb" | cut -f1))"
        if $SUDO apt install -y "$deb"; then
            ok "$name installed via deb"
        else
            err "$name: apt install deb failed"
        fi
        rm -f "$deb"
    else
        err "$name: download failed"
    fi
}

# Extract tar.gz → find binary → install to INSTALL_DIR.
install_from_targz() {
    local name="$1" url="$2"
    local archive="$TMP_DIR/${name}.tar.gz"
    local extract_dir="$TMP_DIR/${name}_extract"
    info "Downloading $name from: $url"
    if ! curl -fsSL "$url" -o "$archive"; then
        err "$name: download failed"; return 1
    fi
    dbg "Download OK ($(du -sh "$archive" | cut -f1))"
    mkdir -p "$extract_dir"
    if ! tar -xzf "$archive" -C "$extract_dir" 2>&1; then
        err "$name: tar extraction failed"; rm -rf "$archive" "$extract_dir"; return 1
    fi
    dbg "Extraction OK, contents:"
    find "$extract_dir" -type f | sed 's/^/     /' >&2

    local bin
    bin=$(find "$extract_dir" -type f -name "$name" -perm /111 2>/dev/null | head -1)
    if [[ -z "$bin" ]]; then
        dbg "Exact name '$name' not found, trying any executable…"
        bin=$(find "$extract_dir" -type f -perm /111 2>/dev/null \
              | grep -Ev '\.sh$|README|LICENSE|\.md|completions|doc' | head -1 || true)
    fi

    if [[ -n "$bin" ]]; then
        dbg "Found binary: $bin"
        $SUDO mv "$bin" "$INSTALL_DIR/$name"
        $SUDO chmod +x "$INSTALL_DIR/$name"
        ok "$name installed → $INSTALL_DIR/$name"
    else
        err "$name: no executable found in archive"
    fi
    rm -rf "$archive" "$extract_dir"
}

# Extract zip → find binary → install to INSTALL_DIR.
install_from_zip() {
    local name="$1" url="$2"
    local archive="$TMP_DIR/${name}.zip"
    local extract_dir="$TMP_DIR/${name}_extract"
    info "Downloading $name from: $url"
    if ! curl -fsSL "$url" -o "$archive"; then
        err "$name: download failed"; return 1
    fi
    dbg "Download OK ($(du -sh "$archive" | cut -f1))"
    mkdir -p "$extract_dir"
    if ! unzip -q "$archive" -d "$extract_dir" 2>&1; then
        err "$name: unzip failed"; rm -rf "$archive" "$extract_dir"; return 1
    fi
    dbg "Extraction OK, contents:"
    find "$extract_dir" -type f | sed 's/^/     /' >&2

    local bin
    bin=$(find "$extract_dir" -type f -name "$name" -perm /111 2>/dev/null | head -1)
    if [[ -z "$bin" ]]; then
        dbg "Exact name '$name' not found, trying any executable…"
        bin=$(find "$extract_dir" -type f -perm /111 2>/dev/null \
              | grep -Ev '\.sh$|README|LICENSE|\.md|completions|doc' | head -1 || true)
    fi

    if [[ -n "$bin" ]]; then
        dbg "Found binary: $bin"
        $SUDO mv "$bin" "$INSTALL_DIR/$name"
        $SUDO chmod +x "$INSTALL_DIR/$name"
        ok "$name installed → $INSTALL_DIR/$name"
    else
        err "$name: no executable found in archive"
    fi
    rm -rf "$archive" "$extract_dir"
}

# Unified GitHub installer: .deb → .tar.gz → .zip. Pass "" to skip a format.
gh_install() {
    local name="$1" repo="$2" deb_pat="$3" tgz_pat="$4" zip_pat="${5:-}"
    local url

    if [[ -n "$deb_pat" ]]; then
        dbg "Trying .deb pattern: $deb_pat"
        url=$(gh_asset_url "$repo" "$deb_pat")
        if [[ -n "$url" ]]; then
            dbg "Resolved: $url"
            install_deb "$name" "$url"; return
        else
            dbg "No .deb asset matched"
        fi
    fi

    if [[ -n "$tgz_pat" ]]; then
        dbg "Trying .tar.gz pattern: $tgz_pat"
        url=$(gh_asset_url "$repo" "$tgz_pat")
        if [[ -n "$url" ]]; then
            dbg "Resolved: $url"
            install_from_targz "$name" "$url"; return
        else
            dbg "No .tar.gz asset matched"
        fi
    fi

    if [[ -n "$zip_pat" ]]; then
        dbg "Trying .zip pattern: $zip_pat"
        url=$(gh_asset_url "$repo" "$zip_pat")
        if [[ -n "$url" ]]; then
            dbg "Resolved: $url"
            install_from_zip "$name" "$url"; return
        else
            dbg "No .zip asset matched"
        fi
    fi

    err "$name: could not resolve any download URL from $repo"
}

# Print current installed version (or "not found") for a binary.
check_version() {
    local bin="$1"
    if has "$bin"; then
        local ver
        ver=$("$bin" --version 2>/dev/null | head -1 || echo "version unknown")
        dbg "Current: $bin → $ver"
    else
        dbg "Current: $bin → not installed"
    fi
}

# =============================================================================
# 0. Preflight
# =============================================================================
hdr "Preflight"
[[ "$EUID" -eq 0 ]] && warn "Running as root"
dbg "TMP_DIR: $TMP_DIR"
dbg "INSTALL_DIR: $INSTALL_DIR"
$SUDO apt-get update
ok "Package lists updated"

# =============================================================================
# 1. Base — always in repos
# =============================================================================
hdr "Base packages"
apt_install \
    sudo curl wget git unzip zip rsync cron less tmux \
    htop ncdu tree jq strace lsof net-tools nmap \
    findutils ca-certificates gnupg lsb-release \
    build-essential

# ── 7zip ─────────────────────────────────────────────────────────────────────
hdr "7zip"
apt_install 7zip 2>/dev/null \
    || apt_install p7zip-full \
    || warn "7zip not found in repos"

# ── btop ─────────────────────────────────────────────────────────────────────
hdr "btop"
apt_install btop || warn "btop not in repos"

# =============================================================================
# 2. fish
# =============================================================================
hdr "fish"
if ! apt_install fish; then
    warn "fish not in default repos — adding PPA"
    $SUDO apt-add-repository -y ppa:fish-shell/release-3 || true
    $SUDO apt-get update
    apt_install fish
fi

# =============================================================================
# 3. Neovim AppImage
# =============================================================================
hdr "Neovim"
check_version nvim
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${GNU_ARCH}.appimage"
info "Downloading Neovim AppImage from: $NVIM_URL"
if curl -fsSL "$NVIM_URL" -o "$TMP_DIR/nvim"; then
    dbg "Download OK ($(du -sh "$TMP_DIR/nvim" | cut -f1))"
    $SUDO mv "$TMP_DIR/nvim" "$INSTALL_DIR/nvim"
    $SUDO chmod +x "$INSTALL_DIR/nvim"
    ok "nvim installed → $INSTALL_DIR/nvim"
    dbg "New: $("$INSTALL_DIR/nvim" --version 2>/dev/null | head -1 || true)"
else
    err "nvim: download failed"
fi

# =============================================================================
# 4. Tools with apt + GitHub fallback
# =============================================================================

# ── bat ───────────────────────────────────────────────────────────────────────
hdr "bat"
check_version batcat; check_version bat
apt_install bat 2>/dev/null \
    || gh_install bat "sharkdp/bat" \
           "bat_.*_${DEB_ARCH}\.deb$" \
           "bat-.*-${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"
if has batcat && ! has bat; then
    $SUDO ln -sf "$(command -v batcat)" "$INSTALL_DIR/bat"
    ok "bat → batcat symlink created"
fi

# ── ripgrep ───────────────────────────────────────────────────────────────────
hdr "ripgrep"
check_version rg
apt_install ripgrep 2>/dev/null \
    || gh_install ripgrep "BurntSushi/ripgrep" \
           "ripgrep_.*_${DEB_ARCH}\.deb$" \
           "ripgrep-.*-${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"

# ── fd ────────────────────────────────────────────────────────────────────────
hdr "fd"
check_version fdfind; check_version fd
apt_install fd-find 2>/dev/null \
    || gh_install fd "sharkdp/fd" \
           "fd_.*_${DEB_ARCH}\.deb$" \
           "fd-.*-${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"
if has fdfind && ! has fd; then
    $SUDO ln -sf "$(command -v fdfind)" "$INSTALL_DIR/fd"
    ok "fd → fdfind symlink created"
fi

# ── fzf ───────────────────────────────────────────────────────────────────────
hdr "fzf"
check_version fzf
apt_install fzf 2>/dev/null \
    || gh_install fzf "junegunn/fzf" \
           "" \
           "fzf-.*-linux_${DEB_ARCH}\.tar\.gz$"

# ── zoxide ────────────────────────────────────────────────────────────────────
hdr "zoxide"
check_version zoxide
apt_install zoxide 2>/dev/null \
    || gh_install zoxide "ajeetdsouza/zoxide" \
           "" \
           "zoxide-.*-${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"

# ── duf ───────────────────────────────────────────────────────────────────────
hdr "duf"
check_version duf
apt_install duf 2>/dev/null \
    || gh_install duf "muesli/duf" \
           "duf_.*_linux_${DEB_ARCH}\.deb$" \
           "duf_.*_linux_${GNU_ARCH}\.tar\.gz$"

# ── dust ──────────────────────────────────────────────────────────────────────
hdr "dust"
check_version dust
gh_install dust "bootandy/dust" \
    "du-dust_.*_${DEB_ARCH}\.deb$" \
    "dust-.*-${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"

# ── sd ────────────────────────────────────────────────────────────────────────
hdr "sd"
check_version sd
gh_install sd "chmln/sd" \
    "" \
    "sd-v.*-${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"

# =============================================================================
# 5. GitHub-only
# =============================================================================

# ── eza ───────────────────────────────────────────────────────────────────────
hdr "eza"
check_version eza
gh_install eza "eza-community/eza" \
    "" \
    "eza_${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"

# ── fastfetch ─────────────────────────────────────────────────────────────────
hdr "fastfetch"
check_version fastfetch
gh_install fastfetch "fastfetch-cli/fastfetch" \
    "fastfetch-linux-${DEB_ARCH}\.deb$" \
    "fastfetch-linux-${GNU_ARCH}\.tar\.gz$"

# ── yazi + ya ─────────────────────────────────────────────────────────────────
hdr "yazi"
check_version yazi
dbg "Trying .zip pattern: yazi-${GNU_ARCH}-unknown-linux-musl.zip"
URL=$(gh_asset_url "sxyazi/yazi" "yazi-${GNU_ARCH}-unknown-linux-musl\.zip$")
if [[ -n "$URL" ]]; then
    dbg "Resolved: $URL"
    archive="$TMP_DIR/yazi.zip"
    extract_dir="$TMP_DIR/yazi_extract"
    info "Downloading yazi from: $URL"
    if curl -fsSL "$URL" -o "$archive"; then
        dbg "Download OK ($(du -sh "$archive" | cut -f1))"
        mkdir -p "$extract_dir"
        unzip -q "$archive" -d "$extract_dir"
        dbg "Archive contents:"
        find "$extract_dir" -type f | sed 's/^/     /' >&2
        for bin_name in yazi ya; do
            bin=$(find "$extract_dir" -type f -name "$bin_name" -perm /111 2>/dev/null | head -1 || true)
            if [[ -n "$bin" ]]; then
                $SUDO mv "$bin" "$INSTALL_DIR/$bin_name"
                $SUDO chmod +x "$INSTALL_DIR/$bin_name"
                ok "$bin_name installed → $INSTALL_DIR/$bin_name"
            else
                err "yazi archive: '$bin_name' binary not found"
            fi
        done
        rm -rf "$archive" "$extract_dir"
    else
        err "yazi: download failed"
    fi
else
    err "yazi: could not resolve download URL"
fi

# ── television ────────────────────────────────────────────────────────────────
hdr "television (tv)"
check_version tv
gh_install tv "alexpasmantier/television" \
    "" \
    "tv-.*-${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"

# ── systemd-manager-tui ───────────────────────────────────────────────────────
hdr "systemd-manager-tui"
check_version systemd-manager-tui
gh_install systemd-manager-tui "matheus-git/systemd-manager-tui" \
    "" \
    "systemd-manager-tui.*${GNU_ARCH}.*linux.*\.tar\.gz$" \
    "systemd-manager-tui.*${GNU_ARCH}.*linux.*\.zip$"

# ── vimcat ────────────────────────────────────────────────────────────────────
hdr "vimcat"
check_version vimcat
VIMCAT_URL="https://raw.githubusercontent.com/ofavre/vimcat/master/vimcat"
info "Downloading vimcat from: $VIMCAT_URL"
if curl -fsSL "$VIMCAT_URL" -o "$TMP_DIR/vimcat"; then
    $SUDO mv "$TMP_DIR/vimcat" "$INSTALL_DIR/vimcat"
    $SUDO chmod +x "$INSTALL_DIR/vimcat"
    ok "vimcat installed → $INSTALL_DIR/vimcat"
else
    err "vimcat: download failed"
fi

# ── atuin ─────────────────────────────────────────────────────────────────────
hdr "atuin"
check_version atuin
gh_install atuin "atuinsh/atuin" \
    "" \
    "atuin-${GNU_ARCH}-unknown-linux-musl\.tar\.gz$"

# =============================================================================
# 6. Docker
# =============================================================================
hdr "Docker"
check_version docker
if ! has docker; then
    info "Adding Docker official repo…"
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

    DISTRO_ID=$(. /etc/os-release && echo "$ID")
    case "$DISTRO_ID" in
        ubuntu|linuxmint|pop) DOCKER_DISTRO="ubuntu" ;;
        *)                    DOCKER_DISTRO="debian"  ;;
    esac
    CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}")
    dbg "Docker distro channel: $DOCKER_DISTRO  codename: $CODENAME"

    echo "deb [arch=${DEB_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${DOCKER_DISTRO} ${CODENAME} stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    $SUDO apt-get update
    apt_install docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    $SUDO usermod -aG docker "$USER"
    ok "docker installed — re-login required for rootless"
else
    ok "docker already installed — skipping repo setup"
fi

if ! has docker-compose && has docker; then
    printf '#!/bin/sh\nexec docker compose "$@"\n' \
        | $SUDO tee /usr/local/bin/docker-compose > /dev/null
    $SUDO chmod +x /usr/local/bin/docker-compose
    ok "docker-compose shim created"
fi

# =============================================================================
# 7. Shell init hooks (zoxide, atuin)
# =============================================================================
hdr "Shell init hooks"

BASHRC="$HOME/.bashrc"
if [[ -f "$BASHRC" ]]; then
    if has zoxide && ! grep -qF "zoxide init" "$BASHRC"; then
        printf '\n# zoxide\neval "$(zoxide init bash)"\n' >> "$BASHRC"
        ok "zoxide init → .bashrc"
    fi
    if has atuin && ! grep -qF "atuin init" "$BASHRC"; then
        printf '\n# atuin\neval "$(atuin init bash)"\n' >> "$BASHRC"
        ok "atuin init → .bashrc"
    fi
fi

if has fish; then
    FISH_CONF="$HOME/.config/fish/conf.d"
    mkdir -p "$FISH_CONF"
    if has zoxide && [[ ! -f "$FISH_CONF/zoxide.fish" ]]; then
        echo 'zoxide init fish | source' > "$FISH_CONF/zoxide.fish"
        ok "zoxide init → fish"
    fi
    if has atuin && [[ ! -f "$FISH_CONF/atuin.fish" ]]; then
        echo 'atuin init fish | source' > "$FISH_CONF/atuin.fish"
        ok "atuin init → fish"
    fi
fi

# =============================================================================
# 8. Cleanup
# =============================================================================
hdr "Cleanup"
$SUDO apt-get autoremove -y -q &>/dev/null || true
# TMP_DIR cleaned by EXIT trap

# =============================================================================
# Summary
# =============================================================================
TOOLS=(sudo fd fzf rg bat eza nvim fish zoxide duf dust sd
       yazi ya tv fastfetch atuin vimcat btop htop tmux ncdu
       jq tree docker systemd-manager-tui)

echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  Setup complete — final status${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}⚠  Re-login (or newgrp docker) to use Docker without sudo${NC}"
echo -e "  ${YELLOW}⚠  Source your RC: source ~/.bashrc${NC}"
echo ""

OK_COUNT=0; FAIL_COUNT=0
for tool in "${TOOLS[@]}"; do
    if has "$tool"; then
        ver=$("$tool" --version 2>/dev/null | head -1 || echo "")
        echo -e "  ${GREEN}✔${NC} ${BOLD}$tool${NC}  ${ver}"
        (( OK_COUNT++ )) || true
    else
        echo -e "  ${RED}✖${NC} ${BOLD}$tool${NC}  — not found in PATH"
        (( FAIL_COUNT++ )) || true
    fi
done

echo ""
echo -e "  Installed: ${GREEN}${OK_COUNT}${NC}  Failed/missing: ${RED}${FAIL_COUNT}${NC}"
echo ""
