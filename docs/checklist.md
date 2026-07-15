# Manual checklist (secrets & big assets)

ArchX does **not** automate these. Do them on a fresh box before or after `./bootstrap.sh all`.

## Before bootstrap (recommended)

- [ ] Base Arch installed with a user, sudo, NetworkManager up
- [ ] `git` + `base-devel` available (bootstrap also installs them)
- [ ] Restore SSH keys to `~/.ssh/` (e.g. `personal_ed25519`) when you care about SSH remotes
- [ ] Optional: create local Hyprland overrides after dots are stowed:
  - `~/.config/hypr/monitors.local.conf` (if you adopt local-override sourcing later)
  - Or edit `monitors.conf` locally and keep it uncommitted / overridden

## After bootstrap

- [ ] Reboot into greetd / DMS greeter
- [ ] Confirm `~/.local/bin` is on `PATH` (zshrc + Hypr `env.conf`)
- [ ] `ssh-add` keys once `ssh-agent.socket` is running (`systemctl --user status ssh-agent`)
- [ ] Restore wallpapers to `~/Pictures/Wallpapers` (or change `WALLPAPER_DIRECTORY`)
- [ ] First zsh login lets Zinit fetch plugins; powerlevel10k is cloned by `services`
- [ ] Machine-specific mounts (e.g. `/mnt/hdd/Media/Music` for `MUSIC_DIRECTORY`)
- [ ] GPU / NVIDIA packages if needed — see comments in `packages/optional.txt`
- [ ] Remove leftover `/usr/local/bin/{next_shuffled_wallpaper,list_keybinds,toggle_gaps_out,grimblast,fastfetch.sh}` if present from an old install
- [ ] Review `packages/optional.txt` and install what you want (`./bootstrap.sh optional` + paru for AUR lines)
- [ ] `grimblast-git` (AUR) and/or stowed `~/.local/bin/grimblast` — both provide screenshots; `.local/bin` wins on PATH if both exist
- [ ] Enable `mpd.service` user unit after dots if you use rmpc (`systemctl --user enable --now mpd`)

## Dotfiles note

GNU Stow 2.4+ refuses `-d $HOME -t $HOME`. ArchX stows via:

`~/.local/share/stow/dotfiles` → symlink to `~/dotfiles`
