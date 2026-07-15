# Manual checklist (secrets & big assets)

ArchX does **not** automate these. Do them on a fresh box before or after `./bootstrap.sh` (TUI or `all`).

## Before bootstrap (recommended)

- [ ] Base Arch installed with a user, sudo, NetworkManager up
- [ ] Multilib enabled in `/etc/pacman.conf` if you want `lib32-*` GPU/Steam packages
- [ ] Restore SSH keys to `~/.ssh/` (e.g. `personal_ed25519`) when you care about SSH remotes

## After bootstrap

- [ ] Reboot into greetd / DMS greeter (especially after NVIDIA mkinitcpio changes)
- [ ] Confirm `~/.config/hypr/env.d/gpu.conf` matches your GPU (`cat` it)
- [ ] Confirm `~/.local/bin` is on `PATH` (zshrc + Hypr `env.conf`)
- [ ] `ssh-add` keys once `ssh-agent.socket` is running
- [ ] Restore wallpapers to `~/Pictures/Wallpapers` (or change `WALLPAPER_DIRECTORY`)
- [ ] First zsh login lets Zinit fetch plugins; powerlevel10k is cloned by `services`
- [ ] Machine-specific mounts (e.g. `/mnt/hdd/Media/Music` for `MUSIC_DIRECTORY`)
- [ ] Edit `~/.config/hypr/monitors.conf` for this machine’s outputs if needed
- [ ] Remove leftover `/usr/local/bin/{next_shuffled_wallpaper,list_keybinds,toggle_gaps_out,grimblast,fastfetch.sh}` if present
- [ ] Review `packages/optional.txt` (`./bootstrap.sh optional` or TUI)
- [ ] If Steam autostart errors before optional install, either install optional or comment the steam line in `startup.conf`

## GPU notes

- Profile is stored in `~/.config/archx/gpu`
- Override anytime: `./bootstrap.sh packages --gpu=amd`
- NVIDIA `system` step installs `/etc/modprobe.d/nvidia.conf` and ensures mkinitcpio `MODULES=`, then `mkinitcpio -P`
- Hypr GPU env is **not** in the shared dots commit — only `env.d/gpu.conf` on disk (gitignored)

## Dotfiles note

GNU Stow 2.4+ refuses `-d $HOME -t $HOME`. ArchX stows via:

`~/.local/share/stow/dotfiles` → symlink to `~/dotfiles`
