#!/usr/bin/env bash
# =============================================================================
#  install.sh — интерактивный установщик пакетов
#  Парсит pkglist и cachyos-pkglist, устанавливает через pacman / paru / cargo
# =============================================================================

set -euo pipefail

# ── Цвета ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'

# ── Утилиты вывода ────────────────────────────────────────────────────────────
info()    { echo -e "${B}::${N} $*"; }
success() { echo -e "${G}✓${N} $*"; }
warn()    { echo -e "${Y}⚠${N} $*"; }
error()   { echo -e "${R}✗${N} $*"; }
header()  { echo -e "\n${W}════════════════════════════════════════${N}"; \
            echo -e "${W}  $*${N}"; \
            echo -e "${W}════════════════════════════════════════${N}"; }

# ── Директория скрипта ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGS_DIR="$SCRIPT_DIR/pkgs"

# ── Аргументы: ./install.sh [base|extra] ────────────────────────────────────────
MODE="${1:-}"
case "$MODE" in
    base)
        PKGLIST="$PKGS_DIR/pkglist-base"
        CACHYOS_PKGS="$PKGS_DIR/cachyos-pkglist-base"
        MODE_LABEL="Базовая система"
        ;;
    extra)
        PKGLIST="$PKGS_DIR/pkglist-extra"
        CACHYOS_PKGS="$PKGS_DIR/cachyos-pkglist-extra"
        MODE_LABEL="EXTRA"
        ;;
    all)
        PKGLIST="$PKGS_DIR/pkglist-base"
        CACHYOS_PKGS="$PKGS_DIR/cachyos-pkglist-base"
        MODE_LABEL="Полная установка (base + extra)"
        ;;
    "")
        echo -e "\n\033[1;37m  Выбери режим установки:\033[0m"
        echo -e "  \033[0;32m1)\033[0m base — базовая система (ядро, драйверы, аудио, сеть)"
        echo -e "  \033[0;34m2)\033[0m extra   — extra (hyprland, приложения, TUI)"
        echo -e "  \033[1;37m3)\033[0m all  — полная установка (base + extra)"
        echo -ne "\n  Введи 1, 2 или 3: "
        read -r choice
        case "$choice" in
            1) MODE="base"; PKGLIST="$PKGS_DIR/pkglist-base"; CACHYOS_PKGS="$PKGS_DIR/cachyos-pkglist-base"; MODE_LABEL="Базовая система" ;;
            2) MODE="extra";   PKGLIST="$PKGS_DIR/pkglist-extra";   CACHYOS_PKGS="$PKGS_DIR/cachyos-pkglist-extra";   MODE_LABEL="Extra" ;;
            3) MODE="all";  PKGLIST="$PKGS_DIR/pkglist-base"; CACHYOS_PKGS="$PKGS_DIR/cachyos-pkglist-base"; MODE_LABEL="Полная установка (base + extra)" ;;
            *) echo "Неверный выбор. Используй: ./install.sh [base|extra|all]"; exit 1 ;;
        esac
        ;;
    *)
        echo "Использование: ./install.sh [base|extra|all]"
        exit 1
        ;;
esac

LOG_FILE="$SCRIPT_DIR/install-${MODE}.log"

# ── Пакеты которые устанавливаются через cargo install ────────────────────────
CARGO_PKGS=(
    hygg gyr dstl twt chatterm bookokrat maze-tui rebels depot
    rsfrac traceview rucola sigye ttysvr catnip chamber bbcli
    subtui tracker tv tera
)

# ── Лог ──────────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

# ── Парсер файла со списком пакетов ──────────────────────────────────────────
# Убирает: пустые строки, комментарии (#...), inline-комментарии, пробелы
parse_pkglist() {
    local file="$1"
    grep -v '^\s*#' "$file" \
        | grep -v '^\s*$' \
        | sed 's/#.*//' \
        | sed 's/[[:space:]]*$//' \
        | sed 's/^[[:space:]]*//' \
        | grep -v '^\s*$' \
        | sort -u
}

# Парсер cachyos-packages — извлекает только имена пакетов
parse_cachyos() {
    local file="$1"
    grep -v '^\s*#' "$file" \
        | grep -v '^\s*$' \
        | grep -v '^sudo' \
        | sed 's/#.*//' \
        | sed "s/[[:space:]]*\\\\[[:space:]]*$//" \
        | sed 's/^[[:space:]]*//' \
        | sed 's/[[:space:]]*$//' \
        | grep -v '^[[:space:]]*$' \
        | sort -u
}

# ── Проверка — cargo пакет? ───────────────────────────────────────────────────
is_cargo_pkg() {
    local pkg="$1"
    for cp in "${CARGO_PKGS[@]}"; do
        [[ "$pkg" == "$cp" ]] && return 0
    done
    return 1
}

# ── Проверка доступности в pacman ─────────────────────────────────────────────
in_pacman() { pacman -Si "$1" &>/dev/null; }

# ── Проверка установлен ли пакет ─────────────────────────────────────────────
is_installed() { pacman -Qi "$1" &>/dev/null; }

# ── Интерактивный выбор (y/n/s = yes/no/skip all) ────────────────────────────
ask() {
    local prompt="$1"
    local answer
    while true; do
        echo -ne "${C}?${N} ${prompt} ${W}[y/n/q]${N} "
        read -r answer
        case "$answer" in
            y|Y|yes) return 0 ;;
            n|N|no)  return 1 ;;
            q|Q)     info "Выход."; exit 0 ;;
        esac
    done
}

# ── Fuzzy поиск пакета через fzf ─────────────────────────────────────────────
# Ищет в pacman+AUR по ключевому слову, возвращает выбранное имя или пусто
fzf_search_pkg() {
    local query="$1"
    if ! command -v fzf &>/dev/null; then
        warn "fzf не установлен — fuzzy поиск недоступен"
        return 1
    fi
    # Собираем кандидатов из pacman и AUR (paru)
    local candidates
    candidates=$(
        { pacman -Ss "$query" 2>/dev/null | grep -E '^[^ ]' | awk '{print $1}' | sed 's|.*/||'
          command -v paru &>/dev/null && paru -Ss "$query" 2>/dev/null | grep -E '^[^ ]' | awk '{print $1}' | sed 's|.*/||'
        } | sort -u
    )
    if [[ -z "$candidates" ]]; then
        warn "Ничего не найдено по запросу: $query"
        return 1
    fi
    echo "$candidates" | fzf         --prompt="Выбери пакет (${query}): "         --height=40%         --border=rounded         --preview='pacman -Si {} 2>/dev/null || paru -Si {} 2>/dev/null'         --preview-window=right:50%
}

# ── Безопасная установка одного пакета через pacman ──────────────────────────
safe_install_pacman() {
    local pkg="$1"
    # Проверяем что пакет существует
    if pacman -Si "$pkg" &>/dev/null; then
        info "Устанавливаю: $pkg"
        log "pacman install: $pkg"
        sudo pacman -S --needed --noconfirm "$pkg" 2>&1 | tee -a "$LOG_FILE" && return 0
        warn "Ошибка при установке $pkg"
        log "ERROR: pacman install failed: $pkg"
        return 1
    fi
    # Пакет не найден — предлагаем fuzzy поиск
    warn "Пакет ${W}$pkg${N} не найден в репозиториях"
    if command -v fzf &>/dev/null; then
        ask "Найти похожий пакет через fzf?" || return 1
        local found
        found=$(fzf_search_pkg "$pkg")
        if [[ -n "$found" ]]; then
            ask "Установить ${W}$found${N} вместо ${Y}$pkg${N}?" || return 1
            log "pacman install (fzf replacement: $pkg -> $found): $found"
            sudo pacman -S --needed --noconfirm "$found" 2>&1 | tee -a "$LOG_FILE"
        fi
    else
        warn "Пропускаю $pkg. Установи fzf для fuzzy поиска: pacman -S fzf"
        log "SKIP (not found): $pkg"
    fi
}

# ── Безопасная установка одного пакета через paru ────────────────────────────
safe_install_aur() {
    local pkg="$1"
    if ! command -v paru &>/dev/null; then
        warn "paru не найден"
        return 1
    fi
    if paru -Si "$pkg" &>/dev/null; then
        info "Устанавливаю (AUR): $pkg"
        log "paru install: $pkg"
        paru -S --needed --noconfirm "$pkg" 2>&1 | tee -a "$LOG_FILE" && return 0
        warn "Ошибка при установке $pkg"
        log "ERROR: paru install failed: $pkg"
        return 1
    fi
    warn "Пакет ${W}$pkg${N} не найден в AUR"
    if command -v fzf &>/dev/null; then
        ask "Найти похожий пакет через fzf?" || return 1
        local found
        found=$(fzf_search_pkg "$pkg")
        if [[ -n "$found" ]]; then
            ask "Установить ${W}$found${N} вместо ${Y}$pkg${N}?" || return 1
            log "paru install (fzf replacement: $pkg -> $found): $found"
            paru -S --needed --noconfirm "$found" 2>&1 | tee -a "$LOG_FILE"
        fi
    else
        warn "Пропускаю $pkg"
        log "SKIP (not found): $pkg"
    fi
}

# ── Установка через pacman (bulk) ─────────────────────────────────────────────
install_pacman() {
    local pkgs=("$@")
    info "Установка через pacman: ${pkgs[*]}"
    log "pacman install: ${pkgs[*]}"
    # При bulk установке не прерываемся на ошибках
    sudo pacman -S --needed --noconfirm "${pkgs[@]}" 2>&1 | tee -a "$LOG_FILE" || {
        warn "Некоторые пакеты не установились — попробуй поштучно"
        log "ERROR: bulk pacman install partial failure"
    }
}

# ── Установка через paru (bulk) ───────────────────────────────────────────────
install_aur() {
    local pkgs=("$@")
    if ! command -v paru &>/dev/null; then
        warn "paru не найден. Устанавливаю paru..."
        bootstrap_paru
    fi
    info "Установка через paru (AUR): ${pkgs[*]}"
    log "paru install: ${pkgs[*]}"
    paru -S --needed --noconfirm "${pkgs[@]}" 2>&1 | tee -a "$LOG_FILE" || {
        warn "Некоторые AUR пакеты не установились — попробуй поштучно"
        log "ERROR: bulk paru install partial failure"
    }
}

# ── Установка через cargo ─────────────────────────────────────────────────────
install_cargo() {
    local pkg="$1"
    if ! command -v cargo &>/dev/null; then
        warn "cargo не найден. Установи rustup сначала."
        return 1
    fi
    info "cargo install $pkg"
    log "cargo install: $pkg"
    cargo install "$pkg" 2>&1 | tee -a "$LOG_FILE"
}

# ── Bootstrap paru ────────────────────────────────────────────────────────────
bootstrap_paru() {
    # Если CachyOS репо уже подключены — ставим через pacman (быстрее)
    if grep -q '\[cachyos\]' /etc/pacman.conf 2>/dev/null; then
        info "CachyOS репо доступны — устанавливаю paru через pacman..."
        sudo pacman -S --needed --noconfirm paru
    else
        # Иначе собираем из AUR через makepkg (требует base-devel и git)
        if ! pacman -Qi base-devel &>/dev/null; then
            warn "base-devel не установлен, ставлю..."
            sudo pacman -S --needed --noconfirm base-devel git
        fi
        local tmp
        tmp=$(mktemp -d)
        info "Собираю paru из AUR (git clone)..."
        git clone https://aur.archlinux.org/paru.git "$tmp/paru"
        (cd "$tmp/paru" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi
    success "paru установлен"
}

# ── Bootstrap CachyOS репозиториев ────────────────────────────────────────────
bootstrap_cachyos() {
    header "Bootstrap CachyOS репозиториев"

    # Проверяем уже ли подключены
    if grep -q '\[cachyos\]' /etc/pacman.conf 2>/dev/null; then
        success "CachyOS репозитории уже подключены"
        return 0
    fi

    warn "CachyOS репозитории не найдены в /etc/pacman.conf"
    ask "Установить keyring и подключить репозитории CachyOS?" || return 1

    # Скачать и установить keyring напрямую
    info "Устанавливаю cachyos-keyring..."
    local mirror="https://mirror.cachyos.org/repo/x86_64/cachyos"
    local tmpdir
    tmpdir=$(mktemp -d)

    local keyring_pkg
    keyring_pkg=$(curl -s "$mirror/" | grep -oP 'cachyos-keyring-[^"]+\.pkg\.tar\.zst' | head -1)

    if [[ -z "$keyring_pkg" ]]; then
        error "Не удалось найти cachyos-keyring на зеркале"
        rm -rf "$tmpdir"
        return 1
    fi

    curl -Lo "$tmpdir/$keyring_pkg" "$mirror/$keyring_pkg"
    sudo pacman-key --init
    sudo pacman -U --noconfirm "$tmpdir/$keyring_pkg"

    local mirrorlist_pkg
    mirrorlist_pkg=$(curl -s "$mirror/" | grep -oP 'cachyos-mirrorlist-[^"]+\.pkg\.tar\.zst' | head -1)
    curl -Lo "$tmpdir/$mirrorlist_pkg" "$mirror/$mirrorlist_pkg"
    sudo pacman -U --noconfirm "$tmpdir/$mirrorlist_pkg"

    rm -rf "$tmpdir"

    # Добавить репозитории в pacman.conf
    info "Добавляю репозитории в /etc/pacman.conf..."
    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

# CachyOS repos
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

[cachyos-core-addons]
Include = /etc/pacman.d/cachyos-mirrorlist

[cachyos-extra-addons]
Include = /etc/pacman.d/cachyos-mirrorlist

[cachyos-community-addons]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF

    sudo pacman -Syy
    success "CachyOS репозитории подключены"
}

# ── Главная логика ────────────────────────────────────────────────────────────
main() {
    clear
    echo -e "${W}"
    echo "  ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     "
    echo "  ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     "
    echo "  ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     "
    echo "  ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     "
    echo "  ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗"
    echo "  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝"
    echo -e "${N}"
    echo -e "  ${C}Интерактивный установщик пакетов${N}"
    echo -e "  Режим: ${W}${MODE_LABEL}${N}"
    echo -e "  Лог:   ${Y}$LOG_FILE${N}\n"

    # Проверить файлы
    [[ -f "$PKGLIST" ]] || { error "Файл pkglist не найден: $PKGLIST"; exit 1; }
    [[ -f "$CACHYOS_PKGS" ]] || { error "Файл cachyos-pkglist не найден: $CACHYOS_PKGS"; exit 1; }

    # ── Шаг 1: CachyOS ──────────────────────────────────────────────────────
    # Делаем до paru — если репо подключены, paru ставится через pacman
    if grep -q '\[cachyos\]' /etc/pacman.conf 2>/dev/null; then
        success "CachyOS репозитории уже подключены"
    else
        ask "Подключить CachyOS репозитории? (рекомендуется — нужно для paru и оптимизированных пакетов)" \
            && bootstrap_cachyos
    fi

    # ── Шаг 2: AUR хелпер ───────────────────────────────────────────────────
    if command -v paru &>/dev/null; then
        success "paru уже установлен"
    else
        ask "Установить paru? (нужен для AUR пакетов)" && bootstrap_paru
    fi

    # ── Шаг 3: fzf (нужен для fuzzy поиска пакетов) ─────────────────────────
    if command -v fzf &>/dev/null; then
        success "fzf уже установлен"
    else
        info "Устанавливаю fzf (нужен для поиска пакетов при ошибках)..."
        if sudo pacman -S --needed --noconfirm fzf 2>&1 | tee -a "$LOG_FILE"; then
            echo -e "${G}"
            echo -e "  ╔══════════════════════════════════════╗"
            echo -e "  ║   ✓  fzf успешно установлен          ║"
            echo -e "  ║      fuzzy поиск пакетов активен     ║"
            echo -e "  ╚══════════════════════════════════════╝"
            echo -e "${N}"
            log "fzf installed OK"
        else
            echo -e "${R}"
            echo -e "  ╔══════════════════════════════════════╗"
            echo -e "  ║   ✗  fzf не удалось установить       ║"
            echo -e "  ║      fuzzy поиск будет недоступен    ║"
            echo -e "  ╚══════════════════════════════════════╝"
            echo -e "${N}"
            log "ERROR: fzf install failed"
        fi
    fi

    # ── Шаг 3: Разбиваем пакеты на категории ────────────────────────────────
    header "Анализ пакетов"

    local all_pkgs=()
    mapfile -t all_pkgs < <(parse_pkglist "$PKGLIST")

    local cachyos_pkgs=()
    mapfile -t cachyos_pkgs < <(parse_cachyos "$CACHYOS_PKGS")

    local pacman_list=()
    local aur_list=()
    local cargo_list=()
    local unknown_list=()
    local installed_list=()

    info "Проверяю ${#all_pkgs[@]} пакетов из pkglist..."
    for pkg in "${all_pkgs[@]}"; do
        if is_cargo_pkg "$pkg"; then
            cargo_list+=("$pkg")
        elif is_installed "$pkg"; then
            installed_list+=("$pkg")
        elif in_pacman "$pkg"; then
            pacman_list+=("$pkg")
        else
            # Пробуем через paru -Si (AUR)
            if command -v paru &>/dev/null && paru -Si "$pkg" &>/dev/null; then
                aur_list+=("$pkg")
            else
                unknown_list+=("$pkg")
            fi
        fi
    done

    # CachyOS пакеты — отдельная группа
    local cachyos_install=()
    local cachyos_installed=()
    for pkg in "${cachyos_pkgs[@]}"; do
        if is_installed "$pkg"; then
            cachyos_installed+=("$pkg")
        else
            cachyos_install+=("$pkg")
        fi
    done

    # ── Шаг 4: Показать сводку ───────────────────────────────────────────────
    header "Сводка"
    local total_installed=$(( ${#installed_list[@]} + ${#cachyos_installed[@]} ))
    echo -e "  ${G}✓ уже установлено${N} — ${total_installed} пакетов"
    echo -e "  ${G}pacman${N}   — ${#pacman_list[@]} пакетов (к установке)"
    echo -e "  ${Y}AUR${N}      — ${#aur_list[@]} пакетов (к установке)"
    echo -e "  ${C}cargo${N}    — ${#cargo_list[@]} пакетов (к установке)"
    echo -e "  ${B}CachyOS${N}  — ${#cachyos_install[@]} пакетов (к установке)"
    [[ ${#unknown_list[@]} -gt 0 ]] && \
        echo -e "  ${R}unknown${N}  — ${#unknown_list[@]} пакетов (не найдены)"

    # Показать список уже установленных
    echo
    ask "Показать список уже установленных пакетов?" && {
        if [[ ${#installed_list[@]} -gt 0 ]]; then
            echo -e "\n${G}Уже установлены (pkglist):${N}"
            printf '  ✓ %s\n' "${installed_list[@]}"
        fi
        if [[ ${#cachyos_installed[@]} -gt 0 ]]; then
            echo -e "\n${B}Уже установлены (CachyOS):${N}"
            printf '  ✓ %s\n' "${cachyos_installed[@]}"
        fi
        echo
    }

    # ── Шаг 5: Установка pacman пакетов ─────────────────────────────────────
    if [[ ${#pacman_list[@]} -gt 0 ]]; then
        header "pacman пакеты (${#pacman_list[@]})"
        printf '  %s\n' "${pacman_list[@]}"
        echo
        if ask "Установить все pacman пакеты?"; then
            install_pacman "${pacman_list[@]}"
            success "pacman пакеты установлены"
        else
            # Поштучно
            for pkg in "${pacman_list[@]}"; do
                ask "Установить ${W}$pkg${N}?" && safe_install_pacman "$pkg"
            done
        fi
    fi

    # ── Шаг 6: Установка CachyOS пакетов ────────────────────────────────────
    if [[ ${#cachyos_install[@]} -gt 0 ]]; then
        header "CachyOS пакеты (${#cachyos_install[@]})"
        printf '  %s\n' "${cachyos_install[@]}"
        echo
        if ask "Установить все CachyOS пакеты?"; then
            install_pacman "${cachyos_install[@]}"
            success "CachyOS пакеты установлены"
        else
            for pkg in "${cachyos_install[@]}"; do
                ask "Установить ${W}$pkg${N}?" && safe_install_pacman "$pkg"
            done
        fi
    fi

    # ── Шаг 7: Установка AUR пакетов ────────────────────────────────────────
    if [[ ${#aur_list[@]} -gt 0 ]]; then
        header "AUR пакеты (${#aur_list[@]})"
        printf '  %s\n' "${aur_list[@]}"
        echo
        if ask "Установить все AUR пакеты?"; then
            install_aur "${aur_list[@]}"
            success "AUR пакеты установлены"
        else
            for pkg in "${aur_list[@]}"; do
                ask "Установить ${W}$pkg${N} (AUR)?" && safe_install_aur "$pkg"
            done
        fi
    fi

    # ── Шаг 8: Установка cargo пакетов ──────────────────────────────────────
    if [[ ${#cargo_list[@]} -gt 0 ]]; then
        header "Cargo пакеты (${#cargo_list[@]})"
        printf '  %s\n' "${cargo_list[@]}"
        echo
        if ! command -v cargo &>/dev/null; then
            warn "cargo не найден. Установи rustup: pacman -S rustup && rustup default stable"
        else
            if ask "Установить все cargo пакеты?"; then
                for pkg in "${cargo_list[@]}"; do
                    install_cargo "$pkg" || warn "Не удалось установить $pkg"
                done
                success "cargo пакеты установлены"
            else
                for pkg in "${cargo_list[@]}"; do
                    ask "cargo install ${W}$pkg${N}?" && install_cargo "$pkg"
                done
            fi
        fi
    fi

    # ── Шаг 9: Неизвестные пакеты ───────────────────────────────────────────
    if [[ ${#unknown_list[@]} -gt 0 ]]; then
        header "Не найдены в pacman/AUR"
        warn "Следующие пакеты не найдены — возможно нужен cargo install или другой источник:"
        printf '  %s\n' "${unknown_list[@]}"
        log "unknown packages: ${unknown_list[*]}"
    fi

    # ── Финал ────────────────────────────────────────────────────────────────
    header "Готово"
    success "Установка завершена. Лог: $LOG_FILE"
}

main "$@"

# ── Если all — запускаем вторую фазу (extra) ───────────────────────────────────
if [[ "${MODE}" == "all" ]]; then
    PKGLIST="$PKGS_DIR/pkglist-extra"
    CACHYOS_PKGS="$PKGS_DIR/cachyos-pkglist-extra"
    MODE_LABEL="EXTRA"
    MODE="extra"
    LOG_FILE="$SCRIPT_DIR/install-extra.log"
    main "$@"
fi
