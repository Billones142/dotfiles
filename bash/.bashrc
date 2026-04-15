#
# ~/.bashrc
#
# Cargar ble.sh
[[ $- == *i* ]] && source /usr/share/blesh/ble.sh --noattach

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias modo_xbox='sudo inputplumber device 0 profile load ~/xbox_mode.yaml && echo "🎮 Modo Xbox Activado"'
alias modo_ps='sudo inputplumber device 0 profile load ~/ds4_mode.yaml && echo "🎮 Modo PlayStation Activado"'

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fixaudio='systemctl --user restart pipewire wireplumber'
alias nano='nvim'
alias update='~/scripts/update_all.sh'
alias config='git --git-dir="$HOME/dotfiles/.git" --work-tree="$HOME/dotfiles"'
alias rsync='rsync --progress'

export EDITOR=nvim
export VISUAL=nvim
export TERMINAL=alacritty
export NVM_DIR="$HOME/.nvm"

[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

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
fastfetch
[[ ${BLE_VERSION-} ]] && ble-attach

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path bash)"
