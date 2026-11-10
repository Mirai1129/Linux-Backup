#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
PYTHON_VERSION=3.15
FONT_URL=https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.tar.xz

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
  --help|-h)
    printf 'Usage: bash install.sh [--check]\n\n--check checks the platform and bundled configuration without installing anything.\n'
    exit 0 ;;
  --check|'') ;;
  *) die "Unknown option: $1" ;;
esac

[[ -f "$SCRIPT_DIR/.tmux.conf" ]] || die 'Missing .tmux.conf'
[[ -f "$CONFIG_DIR/markbull.omp.json" ]] || die 'Missing config/markbull.omp.json'
[[ -f "$CONFIG_DIR/gitconfig" ]] || die 'Missing config/gitconfig'

OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM=macos ;;
  Linux)
    PLATFORM=linux
    if command -v apt-get >/dev/null 2>&1; then
      MANAGER=apt
    elif command -v dnf >/dev/null 2>&1; then
      MANAGER=dnf
    elif command -v pacman >/dev/null 2>&1; then
      MANAGER=pacman
    else
      die 'Linux package manager not supported. Use Debian/Ubuntu, Fedora, or Arch.'
    fi ;;
  *) die "Unsupported operating system: $OS" ;;
esac

if [[ "${1:-}" == --check ]]; then
  printf 'Platform: %s%s\n' "$PLATFORM" "${MANAGER:+ ($MANAGER)}"
  printf 'Bundled configurations: tmux, oh-my-posh, and Git\n'
  printf 'Selected tools: git, tmux, btop, lsd, oh-my-posh, gh, uv, Python %s, OpenJDK\n' "$PYTHON_VERSION"
  printf 'Selected font: CaskaydiaMono Nerd Font\n'
  exit 0
fi

command -v curl >/dev/null 2>&1 || die 'curl is required to bootstrap this setup.'
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
export PATH="$HOME/.local/bin:$PATH"

sudo_cmd() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || die 'sudo is required for system packages.'
    sudo "$@"
  fi
}

install_packages() {
  if [[ "$PLATFORM" == macos ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      log 'Installing Homebrew'
      curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$WORK_DIR/homebrew-install.sh"
      /bin/bash "$WORK_DIR/homebrew-install.sh"
    fi
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$candidate" ]]; then
        eval "$("$candidate" shellenv)"
        break
      fi
    done
    command -v brew >/dev/null 2>&1 || die 'Homebrew installation did not put brew on PATH.'
    log 'Installing selected Homebrew tools'
    brew install git tmux btop lsd gh uv openjdk jandedobbeleer/oh-my-posh/oh-my-posh
  else
    log "Installing selected $MANAGER packages"
    case "$MANAGER" in
      apt)
        sudo_cmd apt-get update
        sudo_cmd apt-get install -y ca-certificates curl git tar xz-utils unzip coreutils fontconfig tmux btop lsd gh default-jdk ;;
      dnf)
        sudo_cmd dnf install -y ca-certificates curl git tar xz unzip coreutils fontconfig tmux btop lsd gh java-latest-openjdk-devel ;;
      pacman)
        sudo_cmd pacman -Sy --needed --noconfirm ca-certificates curl git tar xz unzip coreutils fontconfig tmux btop lsd github-cli jdk-openjdk ;;
    esac

    log 'Installing uv'
    curl -fsSL https://astral.sh/uv/install.sh -o "$WORK_DIR/uv-install.sh"
    sh "$WORK_DIR/uv-install.sh"

    log 'Installing oh-my-posh'
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://ohmyposh.dev/install.sh -o "$WORK_DIR/oh-my-posh-install.sh"
    bash "$WORK_DIR/oh-my-posh-install.sh" -d "$HOME/.local/bin"
  fi
}

install_python() {
  log "Installing Python $PYTHON_VERSION and python/python3 commands"
  command -v uv >/dev/null 2>&1 || die 'uv installation failed.'
  uv python install "$PYTHON_VERSION" --default
  [[ -x "$HOME/.local/bin/python" ]] || die 'uv did not create ~/.local/bin/python.'
}

install_font() {
  log 'Installing CaskaydiaMono Nerd Font'
  local font_dir count
  if [[ "$PLATFORM" == macos ]]; then
    font_dir="$HOME/Library/Fonts"
  else
    font_dir="$HOME/.local/share/fonts/CaskaydiaMono"
  fi
  mkdir -p "$font_dir" "$WORK_DIR/font"
  curl -fL --retry 3 "$FONT_URL" -o "$WORK_DIR/CascadiaMono.tar.xz"
  tar -xJf "$WORK_DIR/CascadiaMono.tar.xz" -C "$WORK_DIR/font"
  count=0
  while IFS= read -r -d '' font_file; do
    install -m 644 "$font_file" "$font_dir/$(basename "$font_file")"
    count=$((count + 1))
  done < <(find "$WORK_DIR/font" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)
  [[ "$count" -gt 0 ]] || die 'Font archive did not contain font files.'
  if [[ "$PLATFORM" == linux ]]; then fc-cache -f "$font_dir"; fi
  printf 'Installed %s font files to %s\n' "$count" "$font_dir"
}

install_config_file() {
  local source_file="$1" target_file="$2"
  mkdir -p "$(dirname "$target_file")"
  if [[ -e "$target_file" || -L "$target_file" ]]; then
    if cmp -s "$source_file" "$target_file"; then
      printf 'Already current: %s\n' "$target_file"
      return
    fi
    local backup_file="${target_file}.backup.$(date +%Y%m%d-%H%M%S)"
    mv "$target_file" "$backup_file"
    printf 'Saved prior configuration: %s\n' "$backup_file"
  fi
  install -m 644 "$source_file" "$target_file"
}

configure_shell() {
  local rc_file="$1" shell_name="$2" marker='# mac-linux-setup oh-my-posh'
  touch "$rc_file"
  if grep -Fq "$marker" "$rc_file"; then return; fi
  cat >> "$rc_file" <<EOF

$marker
export PATH="\$HOME/.local/bin:\$PATH"
if [[ "\$(uname -s)" == Darwin ]] && command -v brew >/dev/null 2>&1; then
  export JAVA_HOME="\$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home"
  export PATH="\$JAVA_HOME/bin:\$PATH"
fi
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "\$(oh-my-posh init $shell_name --config "\$HOME/.config/oh-my-posh/markbull.omp.json")"
fi
EOF
}

install_configs() {
  log 'Restoring tmux, oh-my-posh, and Git configuration'
  install_config_file "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
  install_config_file "$CONFIG_DIR/markbull.omp.json" "$HOME/.config/oh-my-posh/markbull.omp.json"
  install_config_file "$CONFIG_DIR/gitconfig" "$HOME/.gitconfig"
  configure_shell "$HOME/.zshrc" zsh
  configure_shell "$HOME/.bashrc" bash

  log 'Installing tmux plugin manager and configured plugins'
  if [[ ! -d "$HOME/.tmux/plugins/tpm/.git" ]]; then
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi
  "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

install_packages
install_python
install_font
install_configs

log 'Done. Open a new terminal and select CaskaydiaMono Nerd Font in its font settings.'
printf 'Check commands: python --version; tmux -V; oh-my-posh version\n'
