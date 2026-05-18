# ~/.bashrc
# Запускаем только интерактивные сессии
[[ $- != *i* ]] && return

# ---------------------- История ----------------------
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r; ${PROMPT_COMMAND}"

# ---------------------- Встроенные фишки bash ----------------------
shopt -s autocd cdspell checkwinsize direxpand
set -o noclobber

# ---------------------- Алиасы (цвета и base-утилиты) ----------------------
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'

# Замена ls -> eza (как в твоём fish)
if command -v eza &>/dev/null; then
  alias ls='eza -aG --color=always --icons'
  alias ll='eza -l --color=always --icons --group-directories-first'
  alias la='eza -a --color=always --icons --group-directories-first'
  alias lt='eza -aT --color=always --icons --group-directories-first'
  alias l.="eza -a | grep -e '^\.'"
else
  alias ls='ls --color=auto'
  alias ll='ls -alF'
  alias la='ls -A'
fi

# cat -> bat (если есть)
command -v bat &>/dev/null && alias cat='bat'

# zoxide (инициализация для bash)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
  alias cd='z' # заменяем cd на zoxide, как в fish (осторожно: переопределяет встроенный cd)
fi

# Повседневное
alias c='clear'
alias h='history'
alias j='jobs -l'
alias please='sudo $(history -p !!)'
alias fuck='sudo $(history -p !!)'
alias se='sudoedit'
alias cls='clear'
alias ex='exit'
alias ff='fastfetch'
alias pubip='curl ifconfig.me && echo ""'
alias reload='source ~/.bashrc'

# Навигация
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Файлы и безопасность (mv/cp/rm с подтверждением)
alias mv='mv -i'
alias cp='cp -i'
alias rm='rm -i'

# Распаковка всего (extract)
extract() {
  if [ -f "$1" ]; then
    case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz) tar xzf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.rar) unrar e "$1" ;;
    *.gz) gunzip "$1" ;;
    *.tar) tar xf "$1" ;;
    *.tbz2) tar xjf "$1" ;;
    *.tgz) tar xzf "$1" ;;
    *.zip) unzip "$1" ;;
    *.Z) uncompress "$1" ;;
    *.7z) 7z x "$1" ;;
    *) echo "«${1}» нечем распаковать, брат." ;;
    esac
  else
    echo "«${1}» — не файл."
  fi
}

# ---------------------- Pacman / yay / paru (лаконично) ----------------------
alias p='sudo pacman'
alias y='yay'
alias syu='yay -Syu' # основное обновление
alias pacupg='sudo pacman -Syu'
alias pacin='sudo pacman -S'
alias pacre='sudo pacman -R'
alias pacrem='sudo pacman -Rns'
alias paclr='sudo pacman -Scc'
alias paclsorphans='sudo pacman -Qdt'
alias pacrmorphans='sudo pacman -Rs $(pacman -Qtdq)'
alias pacown='pacman -Qo'
alias pacfiles='pacman -F'
alias pkglist='pacman -Qs --color=always | less -R'

alias yaclean='yay -Sc'
alias yaclr='yay -Scc'
alias yaupg='yay -Syu'
alias yain='yay -S'
alias yare='yay -R'
alias yarem='yay -Rns'
alias yareps='yay -Ss'
alias yaloc='yay -Qi'
alias yaorph='yay -Qtd'
alias yamir='yay -Syy'

alias parin='paru -S'
alias parupg='paru -Syu'

# Системные утилиты (выборочно)
alias sctl='sudo systemctl'
alias start='sudo systemctl start'
alias stop='sudo systemctl stop'
alias restart='sudo systemctl restart'
alias enable='sudo systemctl enable'
alias disable='sudo systemctl disable'
alias sstatus='sudo systemctl status'
alias dmesgg='dmesg --human --follow-new --decode --kernel'
alias lsblkk='lsblk -o NAME,FSTYPE,PARTLABEL,LABEL,MOUNTPOINT,TYPE,TRAN,SIZE,MODEL,VENDOR'
alias lasterrors='journalctl -b -p err'
alias vacuum="journalctl --vacuum-size=100M"

# Редактор по умолчанию
export EDITOR=nvim
export VISUAL=nvim
export SUDO_EDITOR=nvim

# ---------------------- Промпт (твой, только переписан на bash) --------------
RESET="\[\033[0m\]"
BOLD="\[\033[1m\]"
GREEN="\[\033[32m\]"
YELLOW="\[\033[33m\]"
BLUE="\[\033[34m\]"
MAGENTA="\[\033[35m\]"

__git_prompt() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && echo " (${branch})"
}

PS1="${GREEN}\u${RESET}@${YELLOW}\h${RESET}:${BLUE}\w${MAGENTA}\$(__git_prompt)${RESET}\n${BOLD}λ ${RESET}"
export PS1

# ---------------------- Окружение и мелочи ----------------------
export PATH="$HOME/.local/bin:$PATH"
export LESS="-R"
# man с подсветкой через bat (если bat есть)
command -v bat &>/dev/null && export MANPAGER="sh -c 'col -bx | bat -l man -p'" 2>/dev/null

# mkdir + cd
mkcd() { mkdir -p "$1" && cd "$1" || return; }

# ---------------------- Bash-completion ----------------------
if [ -f /usr/share/bash-completion/bash_completion ]; then
  . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi

# ---------------------- Приветствие ----------------------
if shopt -q login_shell; then
  echo "I use Arch btw"
fi
