#!/usr/bin/env bash
# ArchX bootstrap — reproduce the daily-driver Hyprland setup after a base Arch install.
set -euo pipefail

ARCHX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ARCHX_ROOT/lib/common.sh"
# shellcheck source=lib/gpu.sh
source "$ARCHX_ROOT/lib/gpu.sh"
# shellcheck source=lib/tui.sh
source "$ARCHX_ROOT/lib/tui.sh"

usage() {
	cat <<'EOF'
Usage: ./bootstrap.sh [<command>] [options]

No command → interactive gum TUI (GPU + step picker).

Commands:
  packages   Install official + AUR + GPU package lists
  optional   Install packages/optional.txt (official lines only)
  dots       Clone ~/dotfiles if needed and stow
  services   powerlevel10k, chsh zsh, enable user units
  system     greetd templates + GPU system hooks (NVIDIA mkinitcpio/modprobe)
  all        packages + dots + services + system
  tui        Force the interactive TUI

Options:
  --gpu=nvidia|amd|none   GPU profile (default: saved state → auto-detect)
  -h, --help              Show this help

Environment:
  DOTFILES_DIR, DOTFILES_REPO_HTTPS, DOTFILES_REPO_SSH
  ARCHX_STATE_DIR         default: ~/.config/archx
EOF
}

ARCHX_GPU_FLAG=""

parse_global_args() {
	local -a keep=()
	local a
	for a in "$@"; do
		case "$a" in
		--gpu=*)
			ARCHX_GPU_FLAG="${a#--gpu=}"
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			keep+=("$a")
			;;
		esac
	done
	PARSED_ARGS=("${keep[@]}")
}

cmd_packages() {
	resolve_gpu "${ARCHX_GPU_FLAG}"
	[[ -n "$ARCHX_GPU_FLAG" ]] && save_gpu_state "$ARCHX_GPU"
	write_gpu_hypr_overlay "$ARCHX_GPU"

	local -a official=()
	local f
	for f in base hypr apps; do
		mapfile -t -O "${#official[@]}" official < <(read_pkg_list "$ARCHX_ROOT/packages/$f.txt")
	done
	pacman_install "${official[@]}"
	install_gpu_packages "$ARCHX_GPU"

	local -a aur=()
	mapfile -t aur < <(read_pkg_list "$ARCHX_ROOT/packages/aur.txt")
	paru_install "${aur[@]}"
}

cmd_optional() {
	local -a pkgs=()
	mapfile -t pkgs < <(read_pkg_list "$ARCHX_ROOT/packages/optional.txt")
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
	# Re-apply overlay after stow in case env.d was empty / recreated
	resolve_gpu "${ARCHX_GPU_FLAG}"
	write_gpu_hypr_overlay "$ARCHX_GPU"
}

cmd_services() {
	clone_powerlevel10k
	set_default_shell_zsh
	enable_user_services
}

cmd_system() {
	resolve_gpu "${ARCHX_GPU_FLAG}"
	[[ -n "$ARCHX_GPU_FLAG" ]] && save_gpu_state "$ARCHX_GPU"
	install_system_greetd
	install_gpu_system "$ARCHX_GPU"
}

cmd_all() {
	resolve_gpu "${ARCHX_GPU_FLAG}"
	save_gpu_state "$ARCHX_GPU"
	write_gpu_hypr_overlay "$ARCHX_GPU"
	cmd_packages
	cmd_dots
	cmd_services
	cmd_system
	log "bootstrap all finished — see docs/checklist.md for manual steps"
}

main() {
	local -a PARSED_ARGS=()
	parse_global_args "$@"
	set -- "${PARSED_ARGS[@]+"${PARSED_ARGS[@]}"}"

	local cmd=${1:-}
	if [[ -z "$cmd" ]]; then
		run_tui
		return
	fi
	shift || true

	# Allow --gpu after the command too
	parse_global_args "$@"
	set -- "${PARSED_ARGS[@]+"${PARSED_ARGS[@]}"}"

	case "$cmd" in
	packages) cmd_packages "$@" ;;
	optional) cmd_optional "$@" ;;
	dots) cmd_dots "$@" ;;
	services) cmd_services "$@" ;;
	system) cmd_system "$@" ;;
	all) cmd_all "$@" ;;
	tui) run_tui ;;
	-h | --help | help) usage ;;
	*) die "unknown command: $cmd" ;;
	esac
}

main "$@"
