#!/usr/bin/env bash
# shellcheck shell=bash
# GPU profile: detect, persist, packages, Hypr overlay, NVIDIA system hooks

ARCHX_STATE_DIR="${ARCHX_STATE_DIR:-$HOME/.config/archx}"
ARCHX_GPU_STATE="${ARCHX_GPU_STATE:-$ARCHX_STATE_DIR/gpu}"
HYPR_ENV_D="${HYPR_ENV_D:-$HOME/.config/hypr/env.d}"

# Global set by resolve_gpu / TUI
ARCHX_GPU="${ARCHX_GPU:-}"

detect_gpu() {
	local has_nvidia=0 has_amd=0 pci
	if command -v lspci >/dev/null 2>&1; then
		pci="$(lspci -nn 2>/dev/null || true)"
		if grep -qi 'NVIDIA' <<<"$pci"; then
			has_nvidia=1
		fi
		if grep -qiE 'AMD/ATI|Radeon' <<<"$pci"; then
			has_amd=1
		fi
	fi
	if ((has_nvidia)); then
		printf '%s\n' nvidia
	elif ((has_amd)); then
		printf '%s\n' amd
	else
		printf '%s\n' none
	fi
}

load_gpu_state() {
	[[ -f "$ARCHX_GPU_STATE" ]] || return 1
	local v
	v="$(tr -d '[:space:]' <"$ARCHX_GPU_STATE")"
	case "$v" in
	nvidia | amd | none) printf '%s\n' "$v" ;;
	*) return 1 ;;
	esac
}

save_gpu_state() {
	local gpu=$1
	mkdir -p "$ARCHX_STATE_DIR"
	printf '%s\n' "$gpu" >"$ARCHX_GPU_STATE"
	log "saved GPU profile: $gpu → $ARCHX_GPU_STATE"
}

# Resolve order: explicit arg → saved state → detect
resolve_gpu() {
	local explicit=${1:-}
	if [[ -n "$explicit" ]]; then
		case "$explicit" in
		nvidia | amd | none) ARCHX_GPU=$explicit ;;
		*) die "invalid GPU profile: $explicit (want nvidia|amd|none)" ;;
		esac
	elif ARCHX_GPU="$(load_gpu_state)"; then
		:
	else
		ARCHX_GPU="$(detect_gpu)"
	fi
	export ARCHX_GPU
}

write_gpu_hypr_overlay() {
	local gpu=${1:-$ARCHX_GPU}
	[[ -n "$gpu" ]] || die "GPU profile not set"

	local src="$ARCHX_ROOT/templates/hypr/env-${gpu}.conf"
	[[ -f "$src" ]] || die "missing GPU env template: $src"

	mkdir -p "$HYPR_ENV_D"
	install -m 644 "$src" "$HYPR_ENV_D/gpu.conf"
	log "wrote Hypr GPU overlay → $HYPR_ENV_D/gpu.conf ($gpu)"
}

install_gpu_packages() {
	local gpu=${1:-$ARCHX_GPU}
	[[ -n "$gpu" ]] || die "GPU profile not set"
	[[ "$gpu" == none ]] && {
		log "GPU=none — skipping GPU packages"
		return 0
	}

	local list="$ARCHX_ROOT/packages/gpu-${gpu}.txt"
	[[ -f "$list" ]] || die "missing GPU package list: $list"

	local -a pkgs=()
	mapfile -t pkgs < <(read_pkg_list "$list")
	pacman_install "${pkgs[@]}"
}

# Ensure MODULES=(...) contains the NVIDIA early-load set
_ensure_mkinitcpio_nvidia_modules() {
	local conf=/etc/mkinitcpio.conf
	local need=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
	local content
	content="$(sudo cat "$conf")"

	local all_present=1 m
	for m in "${need[@]}"; do
		if ! grep -E "MODULES=\([^)]*\b${m}\b" <<<"$content" >/dev/null 2>&1; then
			all_present=0
			break
		fi
	done
	if ((all_present)); then
		log "mkinitcpio.conf already has NVIDIA MODULES"
		return 0
	fi

	backup_file "$conf"

	local tmp
	tmp="$(mktemp)"
	sudo cat "$conf" | awk -v need="nvidia nvidia_modeset nvidia_uvm nvidia_drm" '
		BEGIN {
			n = split(need, N, " ")
		}
		/^MODULES=\(/ {
			line = $0
			sub(/^MODULES=\(/, "", line)
			sub(/\)\s*$/, "", line)
			nparts = split(line, parts, /[[:space:]]+/)
			delete seen
			out = ""
			c = 0
			for (i = 1; i <= nparts; i++) {
				if (parts[i] == "") continue
				if (!(parts[i] in seen)) {
					seen[parts[i]] = 1
					out = (c++ ? out " " : "") parts[i]
				}
			}
			for (i = 1; i <= n; i++) {
				if (!(N[i] in seen)) {
					out = (c++ ? out " " : "") N[i]
					seen[N[i]] = 1
				}
			}
			print "MODULES=(" out ")"
			next
		}
		{ print }
	' >"$tmp"

	if ! grep -q '^MODULES=(' "$tmp"; then
		printf 'MODULES=(%s)\n' "${need[*]}" >>"$tmp"
	fi

	sudo install -m 644 "$tmp" "$conf"
	rm -f "$tmp"
	log "updated mkinitcpio.conf NVIDIA MODULES"
}

install_gpu_system() {
	local gpu=${1:-$ARCHX_GPU}
	[[ -n "$gpu" ]] || die "GPU profile not set"

	if [[ "$gpu" != nvidia ]]; then
		log "GPU=$gpu — skipping NVIDIA system hooks"
		return 0
	fi

	local src="$ARCHX_ROOT/system/nvidia/nvidia.conf"
	[[ -f "$src" ]] || die "missing $src"

	sudo mkdir -p /etc/modprobe.d
	backup_file /etc/modprobe.d/nvidia.conf
	sudo install -m 644 "$src" /etc/modprobe.d/nvidia.conf
	log "installed /etc/modprobe.d/nvidia.conf"

	_ensure_mkinitcpio_nvidia_modules

	if command -v mkinitcpio >/dev/null 2>&1; then
		log "regenerating initramfs (mkinitcpio -P)"
		sudo mkinitcpio -P
	else
		warn "mkinitcpio not found — regenerate initramfs after reboot tooling is available"
	fi
}
