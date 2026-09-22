# ~/.bashrc

# bash complete alias
source /usr/share/bash-complete-alias/complete_alias

# Cargar ble.sh
[[ $- == *i* ]] && source /usr/share/blesh/ble.sh --noattach

# If not running interactively, don't do anything
[[ $- != *i* ]] && return


alias ls='ls --color=auto'
alias grep='grep --color=auto'
#alias hyprctl='hyprctl -j'
alias nano='nvim'
alias update='~/scripts/update_all.sh'
alias config='git --git-dir="$HOME/dotfiles/.git" --work-tree="$HOME/dotfiles"'
alias rsync='rsync --progress'
alias ministack='AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566'
alias load_conda='source /opt/miniconda3/etc/profile.d/conda.sh'

alias clearclear='/usr/bin/clear'
alias clear='echo "Casi, pero mejor CTRL + L"'

complete -C /usr/bin/terraform terraform
# autocompletado para alias
complete -F _complete_alias "${!BASH_ALIASES[@]}"

export EDITOR=nvim
export VISUAL=nvim
export TERMINAL=alacritty
export PAGER=moor
# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# OpenClaw Completion
[ -f '/home/stefano/.openclaw/completions/openclaw.bash' ] && source '/home/stefano/.openclaw/completions/openclaw.bash'


# Colores de texto (foreground)
BLACK="$(tput setaf 0)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 5)"
CYAN="$(tput setaf 6)"
WHITE="$(tput setaf 7)"
GRAY="$(tput setaf 8)"     # Gris
LIGHT_RED="$(tput setaf 9)" # Rojo claro
LIGHT_GREEN="$(tput setaf 10)" # Verde claro
LIGHT_YELLOW="$(tput setaf 11)" # Amarillo claro
LIGHT_BLUE="$(tput setaf 12)" # Azul claro
LIGHT_MAGENTA="$(tput setaf 13)" # Magenta claro
LIGHT_CYAN="$(tput setaf 14)" # Cian claro
LIGHT_WHITE="$(tput setaf 15)" # Blanco brillante

# Colores de fondo (background)
BG_BLACK="$(tput setab 0)"
BG_RED="$(tput setab 1)"
BG_GREEN="$(tput setab 2)"
BG_YELLOW="$(tput setab 3)"
BG_BLUE="$(tput setab 4)"
BG_MAGENTA="$(tput setab 5)"
BG_CYAN="$(tput setab 6)"
BG_WHITE="$(tput setab 7)"
BG_GRAY="$(tput setab 8)"     # Fondo gris
BG_LIGHT_RED="$(tput setab 9)" # Fondo rojo claro
BG_LIGHT_GREEN="$(tput setab 10)" # Fondo verde claro
BG_LIGHT_YELLOW="$(tput setab 11)" # Fondo amarillo claro
BG_LIGHT_BLUE="$(tput setab 12)" # Fondo azul claro
BG_LIGHT_MAGENTA="$(tput setab 13)" # Fondo magenta claro
BG_LIGHT_CYAN="$(tput setab 14)" # Fondo cian claro
BG_LIGHT_WHITE="$(tput setab 15)" # Fondo blanco brillante

BOLD="$(tput bold)"          # Texto en negrita
UNDERLINE="$(tput smul)"     # Texto subrayado
RESET="$(tput sgr0)"         # Restablecer todos los atributos
ITALICS="$(tput sitm)"       # Texto en cursiva (no siempre soportado)

# Configurar:
# PS1='[\u@\h \W]\$ ' # Default
PS1="\[${GREEN}\]\u\[${RESET}\]@\[${BLUE}\]\h\[${RESET}\]:\[${LIGHT_BLUE}\]\w\[${RESET}\]\$ "

# Ejecutar fastfetch al iniciar sesión interactiva
if [ -x "$(command -v fastfetch)" ] && { [ "$TERM_PROGRAM" != "vscode" ] && [ "$TERM_PROGRAM" != "zed" ]; }; then
    fastfetch
fi

[[ ${BLE_VERSION-} ]] && ble-attach

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path bash)"


export PATH="$HOME/.scripts:$PATH"
# pnpm
export PNPM_HOME="/home/stefano/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

export PATH="/home/stefano/.local/share/gem/ruby/3.4.0/bin:$PATH"

explorer() {
    local fm="${FILEMANAGER:-xdg-open}"
    local path="${1:-.}"

    # Soporte para expandir tilde si se pasa entre comillas
    path="${path/#\~/$HOME}"

    if [ -d "$path" ]; then
        nohup "$fm" "$path" > /dev/null 2>&1 &
    else
        echo "Error: '$path' no es un directorio válido"
        return 1
    fi
}

# Conda prepends its own bin dirs to PATH, shadowing system tools with the
# same name (e.g. 'tput' from conda's bundled ncurses lacks terminfo entries
# like 'alacritty' that the system ncurses has). Push them to the end of PATH
# instead: conda tools stay reachable, but system tools take priority.
for _conda_dir in /opt/miniconda3/condabin /opt/miniconda3/bin; do
    PATH="$(printf '%s' "$PATH" | awk -v d="$_conda_dir" -v RS=: -v ORS=: '$0 != d' | sed 's/:$//'):$_conda_dir"
done
unset _conda_dir

