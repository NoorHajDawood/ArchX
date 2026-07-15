#!/usr/bin/env bash
# shellcheck shell=bash
# gum-based bootstrap wizard

ensure_gum() {
	if command -v gum >/dev/null 2>&1; then
		return 0
	fi
	log "gum not found — installing from official repos"
	sudo pacman -S --needed --noconfirm gum
	command -v gum >/dev/null 2>&1 || die "failed to install gum"
}

run_tui() {
	ensure_gum

	local detected saved default_gpu
	detected="$(detect_gpu)"
	saved="$(load_gpu_state 2>/dev/null || true)"
	default_gpu="${saved:-$detected}"

	gum style --border rounded --padding "0 1" --border-foreground 212 \
		"ArchX bootstrap" "Detect: $detected · Saved: ${saved:-none}"

	local gpu
	gpu="$(
		gum choose --header "GPU profile" --selected="$default_gpu" \
			nvidia amd none
	)" || die "cancelled"
	ARCHX_GPU=$gpu
	export ARCHX_GPU
	save_gpu_state "$ARCHX_GPU"
	write_gpu_hypr_overlay "$ARCHX_GPU"

	local selected
	selected="$(
		gum choose --no-limit --header "Steps to run (tab/space to toggle, enter to confirm)" \
			--selected="packages,dots,services,system" \
			packages dots services system optional
	)" || die "cancelled"

	[[ -n "$selected" ]] || die "no steps selected"

	local -a steps=()
	mapfile -t steps <<<"$selected"

	gum style --border rounded --padding "0 1" \
		"GPU: $ARCHX_GPU" \
		"Steps: ${steps[*]}"

	gum confirm "Run bootstrap with these settings?" || die "cancelled"

	local step
	for step in "${steps[@]}"; do
		case "$step" in
		packages) cmd_packages ;;
		dots) cmd_dots ;;
		services) cmd_services ;;
		system) cmd_system ;;
		optional) cmd_optional ;;
		*) warn "unknown step: $step" ;;
		esac
	done

	log "TUI bootstrap finished — see docs/checklist.md for manual steps"
}
