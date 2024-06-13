# Initial setup

[JetBrains Toolbox App](https://www.jetbrains.com/toolbox-app/)

[Save custom keyboard shortcuts in Gnome](https://unix.stackexchange.com/questions/119432/save-custom-keyboard-shortcuts-in-gnome)

```sh
dconf dump /org/gnome/desktop/wm/keybindings/ > ./gnome/hotkeys/wm-keybindings.conf
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > ./gnome/hotkeys/media-keys.conf
```

```sh
# Load the settings on another system:
dconf load /org/gnome/desktop/wm/keybindings/ < ./gnome/hotkeys/wm-keybindings.conf
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < ./gnome/hotkeys/media-keys.conf
```

