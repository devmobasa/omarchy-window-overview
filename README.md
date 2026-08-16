# Window Overview

Mission-Control-style exposé for [Omarchy](https://omarchy.org) v4: every
workspace as a card with **live** thumbnails of its windows.

- **Click** a window to focus it; click a workspace header to switch there.
- **Drag** a window onto another workspace card to move it (silently — the
  overview stays put so you can keep rearranging).
- **Keyboard**: arrows/Tab walk the windows, Enter focuses, `1`–`9`,`0`
  jumps straight to a workspace, Esc closes.

Fully reactive: workspaces and windows come from the compositor's own event
stream, thumbnails from the Hyprland toplevel-export protocol, and the
plugin spawns no subprocess at all. Everything unloads when closed.

## Install

```sh
omarchy plugin add https://github.com/devmobasa/omarchy-window-overview --enable
```

Toggle it:

```sh
omarchy-shell shell toggle community.window-overview '{}'
```

Keybinding for `~/.config/hypr/bindings.lua` (`SUPER + TAB` is Omarchy's
next-workspace bind — pick a free chord or unbind it first):

```lua
o.bind("SUPER + GRAVE", "Window overview", "omarchy-shell shell toggle community.window-overview '{}'")
```

## Requirements

Hyprland with `hyprland_toplevel_export_manager_v1` (any current version)
and Omarchy's Lua config provider — dispatches use the `hl.dsp` syntax.

## Tests

```sh
OMARCHY_PATH=/path/to/omarchy ./test/all
```

## License

[MIT](LICENSE)
