#!/usr/bin/env bash
# ArchX bootstrap — reproduce the daily-driver Hyprland setup after a base Arch install.
set -euo pipefail

ARCHX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ARCHX_ROOT/lib/common.sh"

usage() {
	cat <<'EOF'
Usage: ./bootstrap.sh <command>

Commands:
  packages   Install official + AUR package lists (core slice)
  optional   Install packages/optional.txt (official lines only; AUR commented)
  dots       Clone ~/dotfiles if needed and stow
  services   Enable user systemd units + clone powerlevel10k + ensure zsh
  system     Configure greetd/DMS under /etc (sudo; backs up first)
  all        packages + dots + services + system

Environment:
  DOTFILES_DIR            default: ~/dotfiles
  DOTFILES_REPO_HTTPS     default: https://github.com/NoorHajDawood/dotfiles.git
  DOTFILES_REPO_SSH       default: git@github.com:NoorHajDawood/dotfiles.git
EOF
}

cmd_packages() {
	local -a official=()
	local f
	for f in base hypr apps; do
		mapfile -t -O "${#official[@]}" official < <(read_pkg_list "$ARCHX_ROOT/packages/$f.txt")
	done
	pacman_install "${official[@]}"

	local -a aur=()
	mapfile -t aur < <(read_pkg_list "$ARCHX_ROOT/packages/aur.txt")
	paru_install "${aur[@]}"
}

cmd_optional() {
	local -a pkgs=()
	mapfile -t pkgs < <(read_pkg_list "$ARCHX_ROOT/packages/optional.txt")
	# optional.txt mixes notes; only install names that pacman knows (skip missing quietly? no — fail loud on unknown)
	# Filter to packages that exist in sync DBs to allow a mixed wishlist file
	local -a installable=()
	local p
	for p in "${pkgs[@]}"; do
		if pacman -Si "$p" &>/dev/null; then
			installable+=("$p")
		else
			warn "skipping non-official or unknown package (use paru manually): $p"
		fi
	done
	pacman_install "${installable[@]}"
}

cmd_dots() {
	clone_dotfiles
	stow_dotfiles
}

cmd_services() {
	clone_powerlevel10k
	set_default_shell_zsh
	enable_user_services
}

cmd_system() {
	install_system_greetd
}

cmd_all() {
	cmd_packages
	cmd_dots
	cmd_services
	cmd_system
	log "bootstrap all finished — see docs/checklist.md for manual steps"
}

main() {
	local cmd=${1:-}
	[[ -n "$cmd" ]] || { usage; exit 1; }
	shift || true

	case "$cmd" in
	packages) cmd_packages "$@" ;;
	optional) cmd_optional "$@" ;;
	dots) cmd_dots "$@" ;;
	services) cmd_services "$@" ;;
	system) cmd_system "$@" ;;
	all) cmd_all "$@" ;;
	-h | --help | help) usage ;;
	*) die "unknown command: $cmd" ;;
	esac
}

main "$@"
