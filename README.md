# ArchX

Bootstrap orchestrator for reproducing a daily-driver **Arch + Hyprland + DankMaterialShell** setup after a base install.

Living config stays in [`~/dotfiles`](https://github.com/NoorHajDawood/dotfiles) (GNU Stow). This repo owns package lists, greetd templates, and the install script.

## Quick start

```bash
git clone git@github.com:NoorHajDawood/ArchX.git
cd ArchX
./bootstrap.sh all
```

Then finish [docs/checklist.md](docs/checklist.md) (SSH keys, wallpapers, GPU, mounts).

## Commands

| Command | What it does |
|---------|----------------|
| `packages` | Official lists (`base`, `hypr`, `apps`) via `pacman`; AUR via `paru` |
| `optional` | Official packages from `packages/optional.txt` |
| `dots` | Clone `~/dotfiles` if missing, then stow |
| `services` | powerlevel10k clone, `chsh` to zsh, enable user units |
| `system` | Install greetd templates under `/etc` (backed up), enable greetd |
| `all` | `packages` + `dots` + `services` + `system` |

Slices are meant to be **idempotent** and safe to re-run. `system` backs up existing `/etc/greetd` files before overwrite.

## Layout

```
bootstrap.sh
lib/common.sh
packages/{base,hypr,apps,aur,optional}.txt
system/greetd/
docs/checklist.md
```

## Design choices

- Post base-install only (not bare-metal partitioning)
- Curated daily-driver package slice; wishlist lives in `optional.txt`
- `pacman` for official, `paru` for AUR (`paru` is bootstrapped from the AUR if missing)
- Noninteractive installs (`--needed --noconfirm`)
- Machine-specific display config stays local; secrets stay out of git
