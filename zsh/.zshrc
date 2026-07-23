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

builder() {
  if [[ "${1:-}" == "vpn" ]]; then
    shift
    HTTPS_PROXY="$VPN_PROXY" HTTP_PROXY="$VPN_PROXY" command builder "$@"
  else
    command builder "$@"
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

notion() {
  if [[ "${1:-}" == "vpn" ]]; then
    ~/.local/bin/notion-desktop-vpn
  else
    open -na "/Applications/Notion.app"
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
# JAVA_HOME задаётся в .zprofile из mise (temurin-21). Раньше тут был
# override на java_home -v 17 — убран, источник правды один: mise.

# ── Удалённые Android-эмуляторы → этот макбук ───────────────────────────────
# orcaemu: мост «удалённый (или локальный) Android-эмулятор → этот мак». Поднимает
# ssh-туннель adb-порта, цепляет локальный adb и показывает экран либо во встроенной
# панели Orca (`ORCA emulator attach`), либо своим окном scrcpy. Гибко по host/порту,
# так что несколько эмуляторов и другие машины подключаются тем же механизмом.
# adb-ключ этого мака уже авторизован в mini-эмуляторе (Always allow). На mini не нужна.
#
# Снижение нагрузки на стрим (канал до mini идёт через туннель Hopper'а, ~99ms):
#   • режим Orca (attach) НЕ даёт внешних флагов fps/битрейта — единственный рычаг
#     тут `--light` (ужать разрешение самого эмулятора; помогает любому стримеру);
#   • режим scrcpy даёт полный контроль: --fps / --bitrate / --maxsize.
#
# Usage: orcaemu [options] [-- <доп. флаги scrcpy>]
#   --host H      ssh-хост туннеля (по умолч. mac-mini); "-" = не туннелировать (уже локальный)
#   --rport N     adb-порт эмулятора на хосте (по умолч. 5555; второй эмулятор 5557, третий 5559 …)
#   --lport N     локальный порт (по умолч. = rport)
#   --avd NAME    если на --rport никто не слушает — headless-старт этого AVD на хосте
#   --show M      orca (панель Orca, по умолч.) | scrcpy (своё окно) | none (только adb connect)
#   --light       ужать источник до 540x960/240 — легче стримить (реверс: --native)
#   --native      вернуть эмулятору родное разрешение (wm size/density reset) и выйти
#   --fps N       scrcpy: макс. fps (по умолч. 20)
#   --bitrate B   scrcpy: битрейт видео (по умолч. 3M)
#   --maxsize N   scrcpy: макс. сторона в px (0 = как есть)
if [[ "$USER" != "nqs-desktop" ]]; then
  orcaemu() {
    local host=mac-mini rport=5555 lport="" avd="" show=orca light=0 native=0
    local fps=20 bitrate=3M maxsize=0 extra=()
    while (( $# )); do
      case "$1" in
        --host)    host=$2;    shift 2 ;;
        --rport)   rport=$2;   shift 2 ;;
        --lport)   lport=$2;   shift 2 ;;
        --avd)     avd=$2;     shift 2 ;;
        --show)    show=$2;    shift 2 ;;
        --fps)     fps=$2;     shift 2 ;;
        --bitrate) bitrate=$2; shift 2 ;;
        --maxsize) maxsize=$2; shift 2 ;;
        --light)   light=1;    shift ;;
        --native)  native=1;   shift ;;
        --)        shift; extra=("$@"); break ;;
        *) echo "orcaemu: неизвестный аргумент: $1" >&2; return 2 ;;
      esac
    done
    [[ -z $lport ]] && lport=$rport
    local serial="localhost:$lport"
    local sdk='$HOME/Library/Android/sdk'   # раскрывается на удалённой стороне

    # 1) туннель adb-порта (если host != "-")
    if [[ $host != "-" ]]; then
      if ! pgrep -f "L $lport:127.0.0.1:$rport" >/dev/null 2>&1; then
        # опционально стартуем AVD на хосте, если на adb-порту пусто (console = rport-1)
        if [[ -n $avd ]] && ! ssh "$host" "nc -z 127.0.0.1 $rport" >/dev/null 2>&1; then
          local console=$(( rport - 1 ))
          echo "orcaemu: headless-старт AVD '$avd' на $host (console $console)…"
          ssh "$host" "nohup $sdk/emulator/emulator @$avd -port $console -no-window -no-snapshot-save >/tmp/emu-$console.log 2>&1 &" </dev/null
          ssh "$host" "$sdk/platform-tools/adb -s emulator-$console wait-for-device && until [ \"\$($sdk/platform-tools/adb -s emulator-$console shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')\" = 1 ]; do sleep 1; done" </dev/null
        fi
        ssh -f -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 \
            -L "$lport:127.0.0.1:$rport" "$host" || {
          echo "orcaemu: не удалось поднять туннель $lport→$host:$rport" >&2; return 1; }
      fi
    fi

    # 2) локальный adb видит устройство
    adb connect "$serial" >/dev/null 2>&1
    adb -s "$serial" wait-for-device 2>/dev/null

    # 3) нагрузка на стрим: даунскейл источника / реверс
    if (( native )); then
      adb -s "$serial" shell wm size reset; adb -s "$serial" shell wm density reset
      echo "orcaemu: $serial → родное разрешение"; return 0
    fi
    (( light )) && { adb -s "$serial" shell wm size 540x960; adb -s "$serial" shell wm density 240; }

    # 4) показ
    case "$show" in
      orca)   ORCA emulator attach --device "$serial" --focus ;;
      scrcpy) local args=(-s "$serial" --window-title "$serial" --max-fps "$fps" --video-bit-rate "$bitrate")
              (( maxsize )) && args+=(--max-size "$maxsize")
              scrcpy "${args[@]}" "${extra[@]}" & ;;
      none)   echo "orcaemu: $serial готов (adb connect)" ;;
      *) echo "orcaemu: --show ждёт orca|scrcpy|none" >&2; return 2 ;;
    esac
  }

  # mini-эмулятор одной командой (дефолты под Mac mini). Всё уходит в orcaemu:
  #   miniemu                                     — показать в панели Orca
  #   miniemu --light                             — то же, ужав источник (легче сквозь туннель)
  #   miniemu --show scrcpy --fps 15 --bitrate 2M --maxsize 540  — своё окно, полный контроль
  #   miniemu --native                            — вернуть родное разрешение
  miniemu() { orcaemu --host mac-mini --rport 5555 "$@"; }
fi

# ===== Proxy bypass — corp domains + private nets никогда не идут в xray =====
# ТОЛЬКО на mini (RU-узел, $USER=nqs-desktop). На макбуке (заграница) корп-работы
# нет вообще — корп-байты не должны исходить с не-РФ IP (R9/F6), поэтому корп-хуки
# тут не задаются. Defense-in-depth: даже если CLI уважает HTTPS_PROXY, корп-хост
# не уйдёт в EU-экзит. См. components/claude-on-mini.md, xray routing — второй слой.
if [[ "$USER" == "nqs-desktop" ]]; then
  export GITLAB_HOST=gitlab.services.mts.ru
  export NO_PROXY="gitlab.services.mts.ru,.mts.ru,.mtsbank.ru,.mtsbnk.ru,.mtsdigital.ru,localhost,127.0.0.1,10.0.0.0/8,11.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,.corp,.intranet,.internal,.lan,.local"
  export no_proxy="$NO_PROXY"
fi

# ===== JetBrains VM options (managed by Toolbox) =====
[ -f "$HOME/.jetbrains.vmoptions.sh" ] && source "$HOME/.jetbrains.vmoptions.sh"

# ===== Docker CLI completions =====
fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit
