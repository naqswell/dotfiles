# Source per-machine secrets and overrides (NOT in git)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ===== Toolchain bootstrap for interactive non-login shells =====
typeset -U path PATH
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if [[ -x /opt/homebrew/bin/mise ]]; then
  eval "$(/opt/homebrew/bin/mise activate zsh --shims)"
fi

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
path=("$ANDROID_HOME/platform-tools" "$ANDROID_HOME/cmdline-tools/latest/bin" "$ANDROID_HOME/emulator" $path)
export PATH
# JAVA_HOME задаётся в .zprofile из mise (temurin-21). Раньше тут был
# override на java_home -v 17 — убран, источник правды один: mise.

# ── Удалённые Android-эмуляторы → этот макбук ───────────────────────────────
# orcaemu: мост «удалённый (или локальный) Android-эмулятор → этот мак». Поднимает
# ssh-туннель adb-порта, цепляет локальный adb и показывает экран либо во встроенной
# панели Orca (`ORCA emulator attach`), либо своим окном scrcpy. Гибко по host/порту,
# так что несколько эмуляторов и другие машины подключаются тем же механизмом.
# adb-ключ этого мака должен быть авторизован в mini-эмуляторе (Always allow); cold boot
# без снапшота может его потерять — тогда `adb devices` даёт unauthorized, см. miniemu --help.
# На mini функция не нужна.
#
# Снижение нагрузки на стрим (канал до mini идёт через туннель Hopper'а, ~99ms):
#   • режим Orca (attach) НЕ даёт внешних флагов fps/битрейта — единственный рычаг
#     тут `--light` (ужать разрешение самого эмулятора; помогает любому стримеру);
#   • режим scrcpy даёт полный контроль: --fps / --bitrate / --maxsize.
#
# Полная справка живёт в `orcaemu --help` / `miniemu --help` (функции _orcaemu_usage /
# _miniemu_usage ниже) — правишь флаги, правь и её.
if [[ "$USER" != "nqs-desktop" ]]; then
  _orcaemu_usage() {
    cat <<'EOF'
orcaemu — мост «удалённый (или локальный) Android-эмулятор → этот мак».

Usage: orcaemu [options] [-- <доп. флаги scrcpy>]

  --host H      ssh-хост туннеля (по умолч. mac-mini); "-" = не туннелировать (уже локальный)
  --rport N     adb-порт эмулятора на хосте (по умолч. 5555; второй эмулятор 5557, третий 5559 …)
  --lport N     локальный порт (по умолч. = rport)
  --avd NAME    если на --rport никто не слушает — headless-старт этого AVD на хосте
  --show M      scrcpy (своё окно, по умолч.) | orca (панель Orca) | none (только adb connect)
  --orca        шорткат = --show orca (встроенная панель Orca; привязана к worktree вкладки)
  --scrcpy      шорткат = --show scrcpy
  --light       ужать источник до 540x960/240 — легче стримить (реверс: --native)
  --native      вернуть эмулятору родное разрешение (wm size/density reset) и выйти
  --cold        coldboot: погасить эмулятор на хосте и поднять заново без снапшота (нужен --avd)
  --fps N       scrcpy: макс. fps (по умолч. 20)
  --bitrate B   scrcpy: битрейт видео (по умолч. 3M)
  --maxsize N   scrcpy: макс. сторона в px (0 = как есть)
  -h, --help    эта справка

Снижение нагрузки на стрим (канал до mini идёт через туннель Hopper'а, ~99ms):
  • режим Orca (attach) НЕ даёт внешних флагов fps/битрейта — единственный рычаг
    тут `--light` (ужать разрешение самого эмулятора; помогает любому стримеру);
  • режим scrcpy даёт полный контроль: --fps / --bitrate / --maxsize.
EOF
  }

  # Центр узла UI-дампа по точному text= (bounds="[x1,y1][x2,y2]") → "x y". Пусто → return 1.
  _orcaemu_node_center() {
    local xml=$1 label=$2 node bounds
    node=${xml#*text=\"$label\"}
    [[ $node == "$xml" ]] && return 1          # метки нет в дампе
    node=${node%%/>*}
    [[ $node == *bounds=\"* ]] || return 1
    bounds=${node##*bounds=\"}; bounds=${bounds%%\"*}
    local -a n=(${=${bounds//[\[\],]/ }})
    (( ${#n} == 4 )) || return 1
    echo $(( (n[1]+n[3])/2 )) $(( (n[2]+n[4])/2 ))
  }

  # Подтвердить диалог "Allow USB debugging" на экране удалённого эмулятора. Локальный adb в
  # этот момент unauthorized и shell выполнить не может, поэтому всё идёт по ssh с хоста, где
  # adb авторизован. Координаты берём из uiautomator-дампа — не зависят от разрешения экрана.
  _orcaemu_authorize() {
    local host=$1 console=$2
    local sdk='$HOME/Library/Android/sdk'
    local radb="$sdk/platform-tools/adb -s emulator-$console"
    local xml=$(ssh "$host" "$radb shell 'uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 && cat /sdcard/ui.xml'" </dev/null 2>/dev/null)
    [[ $xml == *"Allow USB debugging"* ]] || return 1
    local -a pt
    # чекбокс "Always allow" — чтобы не переспрашивало после каждого рестарта эмулятора
    pt=(${=$(_orcaemu_node_center "$xml" "Always allow from this computer")})
    (( ${#pt} == 2 )) && ssh "$host" "$radb shell input tap ${pt[1]} ${pt[2]}" </dev/null >/dev/null 2>&1
    pt=(${=$(_orcaemu_node_center "$xml" "Allow")})
    (( ${#pt} == 2 )) || return 1
    ssh "$host" "$radb shell input tap ${pt[1]} ${pt[2]}" </dev/null >/dev/null 2>&1
    sleep 2
  }

  # Какой adb-порт эмулятора реально занят на хосте. Порт «плывёт»: 5554 занят — следующий
  # инстанс берёт 5556, и т.д. Хардкод rport=5555 из-за этого указывал в пустоту рядом с
  # живым эмулятором: orcaemu считал его мёртвым и пытался поднять второй. Пусто — нет
  # запущенных, тогда остаётся дефолт вызывающего.
  _orcaemu_host_rport() {
    local console
    console=$(ssh -o ConnectTimeout=8 "$1" \
      '$HOME/Library/Android/sdk/platform-tools/adb devices 2>/dev/null' </dev/null 2>/dev/null \
      | sed -n 's/^emulator-\([0-9]*\)[[:space:]].*/\1/p' | head -1)
    [[ -n $console ]] && echo $(( console + 1 ))
  }

  # AVD на хосте могли удалить или переименовать (так исчез small_phone_api36). Без проверки
  # emulator уходит в /tmp/emu-*.log с "Unknown AVD name", а orcaemu печатает «поднимаю…» и
  # висит на wait-for-device — причина видна только в хвосте лога.
  _orcaemu_check_avd() {
    local host=$1 avd=$2 sdk='$HOME/Library/Android/sdk' avds
    avds=$(ssh -o ConnectTimeout=8 "$host" "$sdk/emulator/emulator -list-avds 2>/dev/null" \
      </dev/null 2>/dev/null | tr -d '\r')
    print -r -- "$avds" | grep -qx -- "$avd" && return 0
    echo "orcaemu: на $host нет AVD '$avd'. Есть: ${${(j:, :)${(f)avds}}:-—}" >&2
    return 1
  }

  orcaemu() {
    local host=mac-mini rport=5555 lport="" avd="" show=scrcpy light=0 native=0 cold=0
    local fps=20 bitrate=3M maxsize=0 extra=() rport_set=0
    while (( $# )); do
      case "$1" in
        --host)    host=$2;    shift 2 ;;
        --rport)   rport=$2; rport_set=1; shift 2 ;;
        --lport)   lport=$2;   shift 2 ;;
        --avd)     avd=$2;     shift 2 ;;
        --show)    show=$2;    shift 2 ;;
        --orca)    show=orca;   shift ;;
        --scrcpy)  show=scrcpy; shift ;;
        --fps)     fps=$2;     shift 2 ;;
        --bitrate) bitrate=$2; shift 2 ;;
        --maxsize) maxsize=$2; shift 2 ;;
        --light)   light=1;    shift ;;
        --native)  native=1;   shift ;;
        --cold)    cold=1;     shift ;;
        --)        shift; extra=("$@"); break ;;
        -h|--help) _orcaemu_usage; return 0 ;;
        *) echo "orcaemu: неизвестный аргумент: $1" >&2; echo "подсказка: orcaemu --help" >&2; return 2 ;;
      esac
    done
    # Порт не задан руками → спросить хост, где эмулятор на самом деле. Явный --rport
    # всегда сильнее: он же способ дотянуться до конкретного из нескольких эмуляторов.
    if (( ! rport_set )) && [[ $host != "-" ]]; then
      local detected=$(_orcaemu_host_rport "$host")
      if [[ -n $detected && $detected != $rport ]]; then
        echo "orcaemu: на $host эмулятор слушает adb-порт $detected (дефолт $rport пуст) — беру его"
        rport=$detected
      fi
    fi

    [[ -z $lport ]] && lport=$rport
    local serial="localhost:$lport"
    local sdk='$HOME/Library/Android/sdk'   # раскрывается на удалённой стороне
    local console=$(( rport - 1 ))          # порт консоли эмулятора: adb-порт минус 1
    local state i

    # 1) coldboot / туннель adb-порта (если host != "-")
    (( cold )) && [[ $host == "-" ]] && { echo "orcaemu: --cold требует удалённый --host (не '-')" >&2; return 2; }
    if [[ $host != "-" ]]; then
      # coldboot: гасим текущий эмулятор и поднимаем с чистой загрузки без снапшота.
      # Не зависит от туннеля (он привязан к порту хоста и переживает рестарт эмулятора).
      if (( cold )); then
        [[ -z $avd ]] && { echo "orcaemu: --cold требует --avd" >&2; return 2; }
        _orcaemu_check_avd "$host" "$avd" || return 1
        if ssh "$host" "nc -z 127.0.0.1 $rport" >/dev/null 2>&1; then
          echo "orcaemu: coldboot — гашу emulator-$console на $host…"
          ssh "$host" "$sdk/platform-tools/adb -s emulator-$console emu kill" </dev/null 2>/dev/null
          ssh "$host" "for i in \$(seq 1 30); do nc -z 127.0.0.1 $rport >/dev/null 2>&1 || exit 0; sleep 1; done; exit 1" </dev/null \
            || { echo "orcaemu: эмулятор не освободил порт $rport за 30с" >&2; return 1; }
        fi
        adb disconnect "$serial" >/dev/null 2>&1
        echo "orcaemu: cold-старт AVD '$avd' на $host (console $console, без снапшота)…"
        ssh "$host" "nohup $sdk/emulator/emulator @$avd -port $console -no-window -no-snapshot >/tmp/emu-$console.log 2>&1 &" </dev/null
        ssh "$host" "$sdk/platform-tools/adb -s emulator-$console wait-for-device && until [ \"\$($sdk/platform-tools/adb -s emulator-$console shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')\" = 1 ]; do sleep 1; done" </dev/null
      fi

      # Эмулятор на хосте проверяем ВСЕГДА, а не только когда туннеля нет: залипший туннель
      # раньше маскировал мёртвый эмулятор (локальный порт открыт, за ним пусто) — и весь
      # блок авто-старта AVD пропускался, отчего miniemu «не стартовал» молча.
      if [[ -n $avd ]] && ! ssh "$host" "nc -z 127.0.0.1 $rport" >/dev/null 2>&1; then
        _orcaemu_check_avd "$host" "$avd" || return 1
        echo "orcaemu: headless-старт AVD '$avd' на $host (console $console)…"
        ssh "$host" "nohup $sdk/emulator/emulator @$avd -port $console -no-window -no-snapshot-save >/tmp/emu-$console.log 2>&1 &" </dev/null
        ssh "$host" "$sdk/platform-tools/adb -s emulator-$console wait-for-device && until [ \"\$($sdk/platform-tools/adb -s emulator-$console shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')\" = 1 ]; do sleep 1; done" </dev/null
      fi

      if ! pgrep -f "L $lport:127.0.0.1:$rport" >/dev/null 2>&1; then
        ssh -f -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 \
            -L "$lport:127.0.0.1:$rport" "$host" || {
          echo "orcaemu: не удалось поднять туннель $lport→$host:$rport" >&2; return 1; }
      fi
    fi

    # 2) локальный adb видит устройство. Состояние проверяем явно: раньше scrcpy запускался
    # вслепую и молча падал на offline/unauthorized — окна нет, причины не видно.
    adb connect "$serial" >/dev/null 2>&1
    for i in {1..10}; do
      state=$(adb -s "$serial" get-state 2>/dev/null)
      [[ $state == (device|unauthorized) ]] && break
      sleep 1
    done

    # залипший туннель: локальный порт слушает, но за ним никого — пересоздаём и пробуем снова
    if [[ $state != (device|unauthorized) && $host != "-" ]]; then
      echo "orcaemu: $serial → '${state:-нет ответа}', пересоздаю туннель $lport→$host:$rport…"
      pkill -f "L $lport:127.0.0.1:$rport" >/dev/null 2>&1
      adb disconnect "$serial" >/dev/null 2>&1
      ssh -f -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 \
          -L "$lport:127.0.0.1:$rport" "$host" || {
        echo "orcaemu: не удалось поднять туннель $lport→$host:$rport" >&2; return 1; }
      adb connect "$serial" >/dev/null 2>&1
      for i in {1..10}; do
        state=$(adb -s "$serial" get-state 2>/dev/null)
        [[ $state == (device|unauthorized) ]] && break
        sleep 1
      done
    fi

    # unauthorized: эмулятор не принял ключ этого мака (новый AVD, wipe data, свежий adbkey).
    # Сами подтверждаем диалог на его экране — иначе scrcpy просто не откроется.
    if [[ $state == unauthorized && $host != "-" ]]; then
      echo "orcaemu: $serial unauthorized — подтверждаю 'Allow USB debugging' на экране эмулятора…"
      if _orcaemu_authorize "$host" "$console"; then
        adb disconnect "$serial" >/dev/null 2>&1
        adb connect "$serial" >/dev/null 2>&1
        state=$(adb -s "$serial" get-state 2>/dev/null)
      fi
    fi

    if [[ $state != device ]]; then
      echo "orcaemu: $serial не готов (state='${state:-нет ответа}') — экран не показываю." >&2
      echo "         диагностика и ручное лечение: miniemu --help" >&2
      return 1
    fi

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

  # mini-эмулятор одной командой (дефолты под Mac mini). ПО УМОЛЧАНИЮ — окно scrcpy
  # (не зависит от worktree Orca, всегда показывает экран). Всё уходит в orcaemu:
  #   miniemu                                     — окно scrcpy (дефолт)
  #   miniemu --fps 15 --bitrate 2M --maxsize 540 — scrcpy с контролем нагрузки на стрим
  #   miniemu --light                             — ужать источник (легче сквозь туннель)
  #   miniemu --orca                              — встроенная панель Orca (привязка к worktree вкладки)
  #   miniemu --native                            — вернуть родное разрешение
  #   miniemu coldboot                            — погасить эмулятор и поднять заново без снапшота (чистая загрузка)
  # Субкоманд `coldboot` — синоним `--cold` (позиционный, для мышечной памяти). AVD по
  # умолчанию (mts_mitm_api36) зашит в дефолты, поэтому miniemu ещё и сам поднимает
  # эмулятор, если на порту пусто. Порт НЕ зашит: orcaemu спрашивает у хоста, где живой
  # эмулятор (5554 занят → следующий берёт 5556), и 5555 остаётся лишь запасным дефолтом.
  # Правило: при каждой сборке APK поднимаем экран через `miniemu` (scrcpy) — см. память
  # feedback_apk_build_scrcpy и components/claude-on-mini.md в remote-work-setup.
  _miniemu_usage() {
    cat <<'EOF'
miniemu — эмулятор с Mac mini на экран этого макбука одной командой.
Обёртка над orcaemu с дефолтами: --host mac-mini --avd mts_mitm_api36.
Эмулятор физически живёт на mini; локально работают только ssh-туннель, adb и scrcpy.
adb-порт не зашит: берётся у запущенного на mini эмулятора (console+1), иначе 5555.

Usage: miniemu [coldboot] [опции orcaemu] [-- <доп. флаги scrcpy>]

  miniemu                                     окно scrcpy (дефолт)
  miniemu --fps 15 --bitrate 2M --maxsize 540 scrcpy с контролем нагрузки на стрим
  miniemu --light                             ужать источник (легче сквозь туннель)
  miniemu --orca                              встроенная панель Orca (привязка к worktree вкладки)
  miniemu --native                            вернуть родное разрешение
  miniemu coldboot                            погасить эмулятор и поднять заново без снапшота
  miniemu status                              что где сломано: эмулятор / туннель / adb / scrcpy
  miniemu --help                              эта справка

`coldboot` — позиционный синоним --cold (для мышечной памяти). AVD зашит в дефолты,
поэтому miniemu сам поднимает эмулятор на mini, если ни один не запущен. Если такого
AVD на mini уже нет (переименовали, пересоздали) — orcaemu скажет это прямо и покажет
список доступных, вместо молчаливого "Unknown AVD name" в /tmp/emu-*.log.

Самолечение (orcaemu делает это сам, молча падать окном scrcpy больше не должен):
  • мёртвый эмулятор на mini — поднимается, даже если ssh-туннель уже висит;
  • залипший туннель (порт слушает, за ним пусто) — убивается и создаётся заново;
  • unauthorized — диалог "Allow USB debugging" подтверждается автоматически по ssh
    (uiautomator dump → тап по "Always allow from this computer" и "Allow");
  • если устройство так и не стало `device` — печатается state и код возврата 1.

Ручная диагностика, если всё же не поднялось (порты ниже — дефолтные 5555/5554;
реальные показывает шапка `miniemu status`, они зависят от того, чем занят 5554):
    adb devices                                   # ждём: localhost:5555  device
    ssh mac-mini 'nc -z 127.0.0.1 5555; pgrep -fl qemu'   # жив ли эмулятор на mini
    ssh mac-mini 'tail -30 /tmp/emu-5554.log'     # лог старта эмулятора
    pkill -f 'L 5555:127.0.0.1:5555'; adb disconnect localhost:5555; miniemu
    ssh mac-mini '~/Library/Android/sdk/platform-tools/adb -s emulator-5554 exec-out screencap -p' > /tmp/s.png
                                                  # посмотреть, что на экране эмулятора
EOF
  }

  # Быстрый ответ на «почему нет экрана»: по слоям — эмулятор на mini, ssh-туннель, локальный
  # adb, окно scrcpy. Ничего не поднимает и не чинит, только смотрит и подсказывает.
  _miniemu_status() {
    local host=mac-mini console=5554 rport lport serial
    local sdk='$HOME/Library/Android/sdk'
    local remote port qemu radb state line pids log=""

    # Один ssh на все удалённые проверки, чтобы не платить RTT четыре раза; порт эмулятора
    # удалённая сторона вычисляет сама (та же логика, что в _orcaemu_host_rport). С хардкодом
    # 5555 статус рапортовал «эмулятор НЕ ЗАПУЩЕН» про живой эмулятор, поднятый на 5556.
    remote=$(ssh -o ConnectTimeout=8 "$host" "
      c=\$($sdk/platform-tools/adb devices 2>/dev/null | sed -n 's/^emulator-\\([0-9]*\\)[[:space:]].*/\\1/p' | head -1)
      c=\${c:-$console}
      echo \"console:\$c\"
      nc -z 127.0.0.1 \$((c + 1)) >/dev/null 2>&1 && echo port:up || echo port:down
      pgrep -f qemu-system >/dev/null 2>&1 && echo qemu:up || echo qemu:down
      echo \"radb:\$($sdk/platform-tools/adb devices 2>/dev/null | sed -n 2p | tr -d '\r' | tr '\t' ' ')\"
      tail -3 /tmp/emu-\$c.log 2>/dev/null | sed 's/^/log:/'
    " </dev/null 2>/dev/null)
    [[ -z $remote ]] && {
      print -r -- "miniemu status → $host"
      print -r -- "  ssh $host          НЕДОСТУПЕН — дальше смотреть нечего"; return 1; }
    for line in ${(f)remote}; do
      case $line in
        console:*) console=${line#console:} ;;
        port:*) port=${line#port:} ;;
        qemu:*) qemu=${line#qemu:} ;;
        radb:*) radb=${line#radb:} ;;
        log:*)  log+="    ${line#log:}"$'\n' ;;
      esac
    done
    rport=$(( console + 1 )); lport=$rport; serial="localhost:$rport"

    print -r -- "miniemu status → $host, adb-порт $rport, console emulator-$console"
    print -r -- "  ssh $host        OK"
    if [[ $port == up ]]; then
      print -r -- "  эмулятор на mini   порт $rport слушает (qemu:$qemu)"
    else
      print -r -- "  эмулятор на mini   НЕ ЗАПУЩЕН — порт $rport пуст (qemu:$qemu) → лечит: miniemu"
    fi
    print -r -- "  adb на mini        ${radb:-нет устройств}"

    pids=$(pgrep -f "L $lport:127.0.0.1:$rport" 2>/dev/null | tr '\n' ' ')
    [[ -n $pids ]] && print -r -- "  ssh-туннель        есть (pid ${pids% })" \
                   || print -r -- "  ssh-туннель        НЕТ → поднимет: miniemu"

    state=$(adb -s "$serial" get-state 2>/dev/null)
    case $state in
      device)       print -r -- "  локальный adb      $serial device" ;;
      unauthorized) print -r -- "  локальный adb      $serial UNAUTHORIZED → miniemu подтвердит диалог сам" ;;
      *)            print -r -- "  локальный adb      $serial ${state:-нет ответа} → miniemu пересоздаст туннель" ;;
    esac

    pids=$(pgrep -f "scrcpy -s $serial" 2>/dev/null | tr '\n' ' ')
    [[ -n $pids ]] && print -r -- "  окно scrcpy        запущено (pid ${pids% })" \
                   || print -r -- "  окно scrcpy        не запущено"

    [[ $port != up && -n $log ]] && { print -r -- "  хвост /tmp/emu-$console.log:"; print -rn -- "$log"; }
    return 0
  }

  miniemu() {
    local -a pre
    [[ $1 == (-h|--help|help) ]] && { _miniemu_usage; return 0; }
    [[ $1 == status ]] && { _miniemu_status; return $?; }
    [[ $1 == coldboot ]] && { pre=(--cold); shift; }
    # --rport сознательно НЕ передаём: явный флаг выключил бы автоопределение порта
    # в orcaemu, а именно из-за жёсткого 5555 miniemu ломался, когда эмулятор на mini
    # поднимался на 5556. Нужен конкретный — передавай --rport при вызове.
    orcaemu --host mac-mini --avd mts_mitm_api36 "${pre[@]}" "$@"
  }
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
