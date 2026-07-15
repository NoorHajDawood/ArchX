# ArchX

Bootstrap orchestrator for reproducing a daily-driver **Arch + Hyprland + DankMaterialShell** setup after a base install.

Living config stays in [`~/dotfiles`](https://github.com/NoorHajDawood/dotfiles) (GNU Stow). This repo owns package lists, greetd/NVIDIA templates, and the install script.

## Quick start

```bash
git clone git@github.com:NoorHajDawood/ArchX.git
cd ArchX
./bootstrap.sh          # gum TUI: pick GPU + steps
# or
./bootstrap.sh all --gpu=nvidia
```

Then finish [docs/checklist.md](docs/checklist.md) (SSH keys, wallpapers, mounts).

## TUI

Running with **no arguments** opens a **gum** wizard:

1. Choose GPU: `nvidia` / `amd` / `none` (auto-detect prefers NVIDIA if present; saved under `~/.config/archx/gpu`)
2. Multi-select steps (defaults: packages, dots, services, system)
3. Confirm and run

Writes `~/.config/hypr/env.d/gpu.conf` immediately from `templates/hypr/`.

## Commands

| Command | What it does |
|---------|----------------|
| *(none)* / `tui` | Interactive gum TUI |
| `packages` | Official + GPU profile + AUR lists |
| `optional` | Official packages from `packages/optional.txt` |
| `dots` | Clone/stow `~/dotfiles`, refresh GPU overlay |
| `services` | powerlevel10k, `chsh` zsh, enable user units |
| `system` | greetd + NVIDIA modprobe/mkinitcpio when GPU=nvidia |
| `all` | packages + dots + services + system |

### Options

- `--gpu=nvidia|amd|none` — profile for packages/system/overlay (else saved state → detect)

## Layout

```
bootstrap.sh
lib/{common,gpu,tui}.sh
packages/{base,hypr,apps,aur,optional,gpu-nvidia,gpu-amd}.txt
templates/hypr/env-{nvidia,amd,none}.conf
system/{greetd,nvidia}/
docs/checklist.md
```

## Design choices

- Post base-install only
- `gum` TUI by default; CLI remains for scripting
- GPU packages + Hypr env overlay + NVIDIA `/etc` hooks (folded into `system`)
- `paru-bin` bootstrapped from AUR if `paru` missing
- Noninteractive package installs (`--needed --noconfirm`)
