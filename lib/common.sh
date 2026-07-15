#!/usr/bin/env bash
# shellcheck shell=bash
# Shared helpers for ArchX bootstrap

set -euo pipefail

_ARCHX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ARCHX_ROOT="$(cd "$_ARCHX_LIB_DIR/.." && pwd)"
export ARCHX_ROOT
unset _ARCHX_LIB_DIR

DOTFILES_REPO_HTTPS="${DOTFILES_REPO_HTTPS:-https://github.com/NoorHajDawood/dotfiles.git}"
DOTFILES_REPO_SSH="${DOTFILES_REPO_SSH:-git@github.com:NoorHajDawood/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
STOW_DIR="${STOW_DIR:-$HOME/.local/share/stow}"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

# Read package list files: strip comments/blank lines
read_pkg_list() {
	local file=$1
	[[ -f "$file" ]] || die "package list not found: $file"
	grep -vE '^\s*(#|$)' "$file" | sed 's/\s*#.*//' | awk 'NF' || true
}

ensure_paru() {
	if command -v paru >/dev/null 2>&1; then
		return 0
	fi

	log "paru not found — bootstrapping from AUR"
	need_cmd git
	need_cmd makepkg

	local tmp
	tmp="$(mktemp -d)"
	# shellcheck disable=SC2064
	trap "rm -rf '$tmp'" RETURN

	git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
	(cd "$tmp/paru-bin" && makepkg -si --noconfirm --needed)
	command -v paru >/dev/null 2>&1 || die "paru install failed"
}

pacman_install() {
	local -a pkgs=("$@")
	((${#pkgs[@]})) || return 0
	log "pacman: installing ${#pkgs[@]} package(s)"
	sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

paru_install() {
	local -a pkgs=("$@")
	((${#pkgs[@]})) || return 0
	ensure_paru
	log "paru: installing ${#pkgs[@]} package(s)"
	paru -S --needed --noconfirm "${pkgs[@]}"
}

clone_dotfiles() {
	if [[ -d "$DOTFILES_DIR/.git" ]]; then
		log "dotfiles already present at $DOTFILES_DIR"
		return 0
	fi
	if [[ -e "$DOTFILES_DIR" ]]; then
		die "$DOTFILES_DIR exists but is not a git repo"
	fi

	need_cmd git
	log "cloning dotfiles into $DOTFILES_DIR"
	if git ls-remote "$DOTFILES_REPO_SSH" &>/dev/null; then
		git clone "$DOTFILES_REPO_SSH" "$DOTFILES_DIR"
	else
		warn "SSH clone unavailable — using HTTPS"
		git clone "$DOTFILES_REPO_HTTPS" "$DOTFILES_DIR"
	fi
}

# GNU Stow 2.4+ refuses -d $HOME -t $HOME. Use an indirection directory.
stow_dotfiles() {
	need_cmd stow
	[[ -d "$DOTFILES_DIR" ]] || die "dotfiles dir missing: $DOTFILES_DIR"

	mkdir -p "$STOW_DIR" "$HOME/.local/bin"
	ln -sfn "$DOTFILES_DIR" "$STOW_DIR/dotfiles"

	log "stowing dotfiles via $STOW_DIR → $HOME"
	stow -d "$STOW_DIR" -t "$HOME" -R dotfiles
}

clone_powerlevel10k() {
	local dir="${POWERLEVEL10K_DIR:-$HOME/powerlevel10k}"
	if [[ -d "$dir/.git" ]]; then
		log "powerlevel10k already present"
		return 0
	fi
	need_cmd git
	log "cloning powerlevel10k"
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$dir"
}

enable_user_services() {
	systemctl --user daemon-reload

	# Distro OpenSSH user agent (socket-activated)
	if systemctl --user cat ssh-agent.socket &>/dev/null; then
		log "enabling user unit: ssh-agent.socket"
		systemctl --user enable ssh-agent.socket || warn "could not enable ssh-agent.socket"
		systemctl --user start ssh-agent.service 2>/dev/null || true
	fi

	local unit
	for unit in cycle-wallpaper.timer mpd.service; do
		if [[ -f "$HOME/.config/systemd/user/$unit" ]] || systemctl --user cat "$unit" &>/dev/null; then
			log "enabling user unit: $unit"
			systemctl --user enable --now "$unit" || warn "could not enable $unit"
		else
			warn "user unit not found (stow first?): $unit"
		fi
	done
}

backup_file() {
	local path=$1
	if [[ -e "$path" && ! -L "$path" ]]; then
		local bak="${path}.bak.$(date +%Y%m%d%H%M%S)"
		log "backing up $path → $bak"
		sudo cp -a "$path" "$bak"
	fi
}

install_system_greetd() {
	local src="$ARCHX_ROOT/system/greetd"
	[[ -d "$src" ]] || die "missing $src"

	sudo mkdir -p /etc/greetd
	local f
	for f in config.toml start-dms.sh dms-hypr.conf; do
		if [[ -f "$src/$f" ]]; then
			backup_file "/etc/greetd/$f"
			sudo install -m 644 "$src/$f" "/etc/greetd/$f"
			# start script should be executable
			if [[ "$f" == *.sh ]]; then
				sudo chmod 755 "/etc/greetd/$f"
			fi
		fi
	done

	# Prefer dms-greeter one-liner if package provides it; config.toml already set
	log "enabling greetd.service"
	sudo systemctl enable greetd.service
	warn "greetd enabled — reboot or switch to a greetd session to use the greeter"
}

set_default_shell_zsh() {
	if [[ "${SHELL:-}" == */zsh ]]; then
		log "default shell already zsh"
		return 0
	fi
	if command -v zsh >/dev/null 2>&1; then
		log "setting default shell to zsh"
		chsh -s "$(command -v zsh)" || warn "chsh failed — set shell manually"
	fi
}
