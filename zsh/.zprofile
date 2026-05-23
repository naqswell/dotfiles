eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(/opt/homebrew/bin/mise activate zsh --shims)"

# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator"

# Java (managed by mise) — temurin-21 через стабильный симлинк, не привязан к патч-версии
export JAVA_HOME="$HOME/.local/share/mise/installs/java/temurin-21/Contents/Home"
