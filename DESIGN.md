# Design

This repository is a single-machine NixOS + home-manager flake for `PC`
(user `bitcrushing`). It is deliberately not a framework and not reusable: the
goal is that any change has one obvious home, and that the next reader can find
it from `configuration.nix`.

## Principles

1. **`configuration.nix` is a table of contents.** It imports every module
   explicitly and holds only the two `stateVersion` values. Settings live in
   modules. There is no auto-import.
2. **Group by domain, not by NixOS/home-manager.** A module owns both the
   system and user side of one topic, so changing a feature touches one file.
3. **One concern per file.** A file should be describable by its name. When a
   file grows a second unrelated concern, split it. Domains group modules in
   directories (`modules/desktop/niri.nix`); a module with non-Nix assets keeps
   its entry file next to the asset directory (`modules/hardware/numpad.nix` +
   `modules/hardware/numpad/`). A directory that is the module itself uses
   `default.nix` (`modules/pi/`).
4. **Non-Nix stays real.** Shell scripts, KDL, Lua, Python and TypeScript live
   in files next to their module and are pulled in with `source =` or
   `builtins.readFile`. Don't inline another language as a Nix string unless
   it is a few lines of glue.
5. **One source of truth for shared values.** Colours, fonts, opacity and the
   cursor live in `modules/theme.nix`; niri geometry and border colours in
   `modules/desktop/style.nix`; monitor order and dimensions in
   `modules/desktop/wallpaper.nix` and `niri/config.kdl` (keep them in sync).
6. **Local packages are packages; workarounds stay with their cause.**
   `pkgs/` contains only local derivations. A nixpkgs override that fixes a
   specific device or game lives in the module that needs it (for example
   `modules/gaming/compat.nix`), with a comment saying when it can go.
7. **Comments explain why, not what.** Hardware quirks, upstream bugs and
   workarounds state the symptom and the removal condition. Git history keeps
   the changelog. Don't leave comparisons to components that no longer exist
   unless they explain current behaviour.
8. **Retire cleanly.** When a component is replaced, remove its module and its
   obsolete references. Keep only the rationale that still affects the
   current configuration.

## Module style

- Home-manager options are written as `hm.<option>` (the alias defined in
  `flake.nix`), so a topic module reads the same whether it configures the
  system or the user.
- Use the function form `hm = { lib, ... }: { ... };` only when the module
  needs home-manager's `lib` (for example `lib.hm.dag` in an activation
  script). Otherwise the plain `hm.<option> = ...` form is shorter.
- Prefer `lib.mkForce` only when overriding a value another module also sets;
  explain why in a comment when it isn't obvious.
- Keep options close to the thing they configure. A module may hold both
  NixOS and home-manager settings for its topic.

## Layout

```text
configuration.nix              imports only + stateVersion
flake.nix                      inputs, outputs, formatter

modules/
  system/
    boot.nix                   boot loader, kernel, /tmp
    base.nix                   hostname, network, timezone, users, sudo, services
    nix.nix                    package overlay, flakes, store optimisation, GC
    storage.nix                extra filesystems, scrub, zram
    tailscale.nix              Tailscale VPN and Tailscale SSH
  theme.nix                    stylix: palette, fonts, cursor, icons, opacity
  shell/
    bash.nix                   interactive bash: prompt, aliases, helpers
    cli.nix                    CLI packages, git, nh, btop/jq/bat/eza/fzf/zoxide
    ghostty.nix                terminal font fallbacks and behaviour
  apps/
    default.nix                GUI apps without substantial custom config
    filebrowser.nix            web file manager on :8081
    qbittorrent.nix            qbittorrent-nox user service (headless Web UI)
    vesktop.nix                Vesktop theme and window transparency
  desktop/
    niri.nix                   compositor, login, session services, generated nix.kdl
    niri/config.kdl            hand-written niri configuration
    niri/binds.kdl             keybindings
    noctalia.nix               bar, launcher, notifications, lock/idle, OSD
    wayvnc.nix                 remote desktop over the tailnet
    wallpaper.nix              generated wallpaper + renderer service
    portals.nix                xdg-desktop-portal routing
    screenshots.nix            whole-layout capture and annotation helpers
    style.nix                  niri gaps and window-border colours
  hardware/
    bluetooth.nix              Bluetooth + DualSense quirks
    numpad.nix                 Magicforce NumLock/LED workaround
    numpad/led-responder.py    the workaround script
    drawing-keypad.nix         Krita keypad (kanata) + Krita wrapper
    drawing-keypad/            kanata config and helper scripts
    peripherals.nix            Razer mouse, input-remapper
    printing.nix               CUPS + HP drivers
  audio/
    pipewire.nix               low-latency PipeWire, Scarlett 6i6, mic mute
    production.nix             DAWs, plugins, PipeASIO
  gaming/
    compat.nix                 32-bit/FHS runtime, nix-ld, i686 libhwy fix
    steam.nix                  Steam, GE-Proton, Wine game tools
    opence.nix                 OpenCE package
    headtracking.nix           opentrack + phone camera setup
    headtracking/              helper scripts
  editors/
    neovim.nix                 Neovim editor integration
    neovim/init.lua            LazyVim configuration (runtime plugins)
    tooling.nix                LSPs, formatters and dev tools
  pi/
    default.nix                pi package, settings, theme, extensions

pkgs/                          local derivations + overlay
assets/wallpaper/              wallpaper generator and its design notes
installers/                    licensed Renoise tarball; never committed
```

## Where a change goes

| Change | Home |
| --- | --- |
| Boot loader, kernel, `/tmp` | `modules/system/boot.nix` |
| Hostname, network, timezone, users, sudo, always-on services | `modules/system/base.nix` |
| Nix settings, GC, package overlay, unfree packages | `modules/system/nix.nix` |
| Filesystems, scrub, zram | `modules/system/storage.nix` |
| Tailscale VPN or SSH access | `modules/system/tailscale.nix` |
| Colours, fonts, cursor, icons, opacity | `modules/theme.nix` |
| Prompt, aliases, shell helper functions | `modules/shell/bash.nix` |
| CLI packages, git, nh, file/text tools | `modules/shell/cli.nix` |
| Terminal appearance or font fallback | `modules/shell/ghostty.nix` |
| GUI app with no custom config | `modules/apps/default.nix` |
| GUI app with substantial custom config | `modules/apps/<app>.nix` |
| Web file manager | `modules/apps/filebrowser.nix` |
| Remote desktop (VNC) | `modules/desktop/wayvnc.nix` |
| niri behaviour | `modules/desktop/niri/config.kdl` |
| niri keybinding | `modules/desktop/niri/binds.kdl` |
| Generated/coloured niri settings | `modules/desktop/niri.nix` |
| Bar, launcher, notifications, lock, idle, OSD | `modules/desktop/noctalia.nix` |
| Wallpaper look or renderer | `modules/desktop/wallpaper.nix` + `assets/wallpaper/` |
| Portal routing | `modules/desktop/portals.nix` |
| Screenshot capture or annotation | `modules/desktop/screenshots.nix` |
| Device quirk | `modules/hardware/<device>.nix` |
| Game runtime compatibility | `modules/gaming/compat.nix` |
| Game-specific setup | `modules/gaming/<game>.nix` |
| LSP, formatter, dev tool | `modules/editors/tooling.nix` |
| Local package | `pkgs/<name>/` + `pkgs/default.nix` |

## Desktop stack

- **Compositor:** niri. Login is greetd with the Noctalia greeter.
- **Shell:** Noctalia owns the bar, launcher, notifications, clipboard UI,
  lock screen, idle handling, volume OSD, power menu and polkit agent.
  Keybindings call it through `noctalia msg ...`.
- **Theme:** stylix with Rosé Pine Moon. The wallpaper is generated from the
  same palette at build time and animated by `twilight-wallpaper`.
- **Retired:** waybar, mako, fuzzel, swaylock, swayidle, swayosd and
  lxqt-policykit-agent. Don't add them back; extend Noctalia or call it from a
  bind instead.
- **Portals:** niri's GNOME/GTK defaults, except ScreenCast which uses
  `xdg-desktop-portal-wlr` for Discord/Vesktop capture.

## Fonts and theming

- `modules/theme.nix` is the only place that chooses a family or size.
  `stylix.fonts.monospace` is Fira Mono, which is also the terminal font;
  `stylix.fonts.sansSerif` is Jost*. The terminal is 13.5pt (18px at 96 DPI).
- `modules/shell/ghostty.nix` adds the Nerd Font and emoji fallbacks but does
  not choose another family or size.
- Anything stylix cannot theme reads base16 slots through
  `config.lib.stylix.colors` (or `.withHashtag`). Never hardcode hex colours.
- Neovim is the exception: it uses the official Rosé Pine plugin with
  `variant = "moon"` so its editor colours stay consistent with stylix.

## Audio

- PipeWire is the sound server. JACK clients run through `pw-jack` from
  `pipewire.jack`; Renoise is wrapped in `pkgs/renoise`. Don't enable the
  deprecated `services.pipewire.jack`, which exports a global
  `LD_LIBRARY_PATH` to every session.
- The Scarlett 6i6 profile and low-latency clock settings live in
  `modules/audio/pipewire.nix`; DAWs, plugins and PipeASIO in
  `modules/audio/production.nix`.

## Packages and overlays

- `pkgs/default.nix` is a single overlay that exposes local derivations as
  `pkgs.<name>`; it is applied in `modules/system/nix.nix`.
- Local packages live in `pkgs/<name>/`. Licensed or non-redistributable
  installers stay in `installers/` and are never committed.
- Device-, kernel- or game-specific nixpkgs overrides live in the module that
  needs them, not in `pkgs/`.

## Verification

- Format: `nix fmt`.
- Build: `nixos-rebuild build --flake ~/nixos#PC` (or the `nrb` alias). This is
  the test suite.
- Validate niri after a switch, or against copies of the generated files:
  `niri validate`.
- Apply: the user runs `nrs`; agents can't sudo. `nrt` activates without a
  boot entry.
- New files must be tracked by git before the flake can see them.

## Invariants and exceptions

- Never edit `hardware-configuration.nix`; it is generated.
- Never change `system.stateVersion` or `hm.home.stateVersion` (both 26.05).
- Neovim plugins are installed by lazy.nvim at runtime; they are not Nix
  packages.
- LSP servers come from `modules/editors/tooling.nix`, not mason, and new
  servers are marked `mason = false` in `neovim/init.lua`.
- `~/.config/mimeapps.list` is app-managed, so default apps are set with
  `xdg-mime`, not Nix.
- Noctalia GUI settings in `~/.local/state/noctalia/settings.toml` override the
  Nix-managed base in `modules/desktop/noctalia.nix`.
- Activation scripts (PipeASIO copy, opentrack setup) run on every switch.
