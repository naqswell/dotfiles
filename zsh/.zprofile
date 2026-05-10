eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(/opt/homebrew/bin/mise activate zsh --shims)"

# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

# Java (managed by mise)
export JAVA_HOME="$HOME/.local/share/mise/installs/java/temurin-21.0.11+10.0.LTS/Contents/Home"
