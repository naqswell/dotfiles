# Source per-machine secrets and overrides (NOT in git)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ===== Aliases =====
alias cl='claude'

# ===== Subcommand wrappers: "<tool> vpn" запускает через VPN_PROXY, без vpn — обычно =====
claude() {
  if [[ "${1:-}" == "vpn" ]]; then
    shift
    HTTPS_PROXY="$VPN_PROXY" HTTP_PROXY="$VPN_PROXY" command claude "$@"
  else
    command claude "$@"
  fi
}

codex() {
  if [[ "${1:-}" == "vpn" ]]; then
    shift
    HTTPS_PROXY="$VPN_PROXY" HTTP_PROXY="$VPN_PROXY" command codex "$@"
  else
    command codex "$@"
  fi
}

claudedesk() {
  if [[ "${1:-}" == "vpn" ]]; then
    ~/bin/claude-desktop-vpn
  else
    open -na "/Applications/Claude.app"
  fi
}

codexdesk() {
  if [[ "${1:-}" == "vpn" ]]; then
    ~/.local/bin/codex-desktop-vpn
  else
    open -na "/Applications/Codex.app"
  fi
}

# ChatGPT.app — native Swift app, использует URLSession и игнорирует
# --proxy-server / HTTPS_PROXY. Для proxying нужен системный прокси
# macOS либо веб-версия через Zen. Wrapper-функция была удалена.

# ===== Proxy switchers (IP values come from ~/.zshrc.local) =====
proxy-home() {
  export VPN_PROXY="${PROXY_HOME_URL:?PROXY_HOME_URL not set in ~/.zshrc.local}"
  echo "set: $VPN_PROXY"
}
proxy-iphone() {
  export VPN_PROXY="${PROXY_IPHONE_URL:?PROXY_IPHONE_URL not set in ~/.zshrc.local}"
  echo "set: $VPN_PROXY"
}

_proxy_geo() {
  local ip="$1" json
  [[ -z "$ip" ]] && return 1
  json=$(curl -s --max-time 5 "https://ipinfo.io/$ip/json") || return 1
  local country org
  country=$(printf '%s' "$json" | sed -n 's/.*"country": *"\([^"]*\)".*/\1/p')
  org=$(printf '%s' "$json" | sed -n 's/.*"org": *"\([^"]*\)".*/\1/p')
  [[ -z "$country$org" ]] && return 1
  printf '%s / %s' "${country:-?}" "${org:-?}"
}

proxy-check() {
  emulate -L zsh
  local proxy="$VPN_PROXY"
  local hostport="${proxy#http://}"; hostport="${hostport##*@}"
  local host="${hostport%%:*}"
  local port="${hostport##*:}"
  echo "Proxy: $proxy"
  if [[ -z "$host" || -z "$port" ]]; then
    echo "  VPN_PROXY не задана корректно"; return 1
  fi

  local t0 t1 ping_out ping_avg port_ok direct_ip direct_geo via_ip via_geo via_code
  echo -n "  LAN ping:   "
  if ping_out=$(ping -c 3 -W 1500 "$host" 2>&1); then
    ping_avg=$(printf '%s\n' "$ping_out" | awk -F'/' '/min\/avg\/max/ {print $5 " ms"}')
    : ${ping_avg:=ok}
    echo "$ping_avg"
    if [[ "$ping_avg" == *ms ]]; then
      local avg_int=${ping_avg%%.*}
      if (( avg_int > 50 )); then
        echo "              ⚠ latency высокий — телефон, видимо, в Doze (Wi-Fi радио спит)"
      fi
    fi
  else
    echo "FAIL — телефон не отвечает на ping"
  fi

  echo -n "  TCP $port:   "
  if nc -vz -G 3 "$host" "$port" >/dev/null 2>&1; then
    echo "open (Every Proxy слушает)"; port_ok=1
  else
    echo "closed — Every Proxy не запущен или порт другой"; port_ok=0
  fi

  echo -n "  Direct IP:  "
  direct_ip=$(curl -s --max-time 5 https://api.ipify.org)
  if [[ -n "$direct_ip" ]]; then
    direct_geo=$(_proxy_geo "$direct_ip")
    echo "$direct_ip   [${direct_geo:-?}]"
  else
    echo "FAIL (норма для full-tunnel корпоративного VPN — не блокирует прокси)"
  fi

  echo -n "  Via proxy:  "
  t0=$(date +%s)
  via_ip=$(curl -s --max-time 20 -x "$proxy" https://api.ipify.org)
  via_code=$?
  t1=$(date +%s)
  if [[ -n "$via_ip" ]]; then
    via_geo=$(_proxy_geo "$via_ip")
    echo "$via_ip   [${via_geo:-?}]   ($((t1-t0))s)"
    if [[ -n "$direct_ip" && "$via_ip" == "$direct_ip" ]]; then
      echo "              ⚠ IP идентичен Direct — Amnezia точно выключена"
    else
      local via_country="${via_geo%% /*}"
      if [[ -n "$via_country" && "$via_country" != "?" ]]; then
        echo "              ✓ выход через $via_country (сверь со страной Amnezia-сервера)"
      fi
    fi
  else
    echo "FAIL (curl exit=$via_code, $((t1-t0))s)"
    if (( port_ok )); then
      echo "              ⚠ прокси отвечает (TCP), но HTTPS через туннель не вернулся."
      echo "                Возможные причины: AmneziaVPN не подключилась / упала;"
      echo "                Wi-Fi-канал флапает (Doze); CONNECT режется по пути."
      echo "                Сначала проверь ключик AmneziaVPN на телефоне, потом jitter LAN ping."
    fi
  fi
}

# ===== Prompt: HH:MM:SS  cwd  %# =====
autoload -Uz add-zsh-hook
_set_timestamp_prompt() { PROMPT='%F{240}%*%f %F{blue}%~%f %# '; }
add-zsh-hook precmd _set_timestamp_prompt

# ===== ZLE: Emacs keymap, line nav, shift-arrow region selection =====
bindkey -e
bindkey '^A' end-of-line
bindkey '^W' beginning-of-line

_r-delregion() {
  if (( REGION_ACTIVE )); then zle kill-region; else zle .${WIDGET}; fi
}
zle -N backward-delete-char _r-delregion
zle -N delete-char _r-delregion

_r-select-move() {
  local builtin_widget="$1"
  if (( ! REGION_ACTIVE )); then MARK=$CURSOR; REGION_ACTIVE=1; fi
  zle ".${builtin_widget}"
}
select-backward-word() { _r-select-move backward-word; }
select-forward-word()  { _r-select-move forward-word; }
zle -N select-backward-word
zle -N select-forward-word
select-backward-char() { _r-select-move backward-char; }
select-forward-char()  { _r-select-move forward-char; }
zle -N select-backward-char
zle -N select-forward-char
select-bol() { _r-select-move beginning-of-line; }
select-eol() { _r-select-move end-of-line; }
zle -N select-bol
zle -N select-eol
bindkey "\e[1;2D" select-backward-word
bindkey "\e[1;2C" select-forward-word
bindkey "\e[1;2H" select-bol
bindkey "\e[1;2F" select-eol

# ===== Plugins (after bindings) =====
SYNTAX_HL="$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -r "$SYNTAX_HL" ]] && source "$SYNTAX_HL"
AUTOSUG="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -r "$AUTOSUG" ]] && source "$AUTOSUG"

# ===== PATH =====
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$HOME/go/bin"

# ===== Android SDK =====
export ANDROID_HOME="$HOME/Library/Android/sdk"
export WORKDIR="$ANDROID_HOME"
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"

# ===== MTS GitLab — bypass Amnezia proxy =====
export GITLAB_HOST=gitlab.services.mts.ru
export NO_PROXY="gitlab.services.mts.ru,.mts.ru,.mtsbank.ru,localhost,127.0.0.1,11.0.0.0/8"
export no_proxy="$NO_PROXY"

# ===== JetBrains VM options (managed by Toolbox) =====
[ -f "$HOME/.jetbrains.vmoptions.sh" ] && source "$HOME/.jetbrains.vmoptions.sh"

# ===== Docker CLI completions =====
fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit
