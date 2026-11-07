# FlexMenu

[简体中文](./docs/README.zh-CN.md)

A scriptable radial menu for macOS.

Press a shortcut, move your mouse, and click to run an action. FlexMenu also supports drag-and-drop: drag a file, open the menu, and release it over an action.

Menus and actions are defined with Shell scripts.

<!-- TODO: Demo GIF -->

## Installation

Requires an Apple Silicon Mac and `jq`.

```sh
installer=$(mktemp) && curl -fsSLo "$installer" https://raw.githubusercontent.com/hjy-233/FlexMenu/main/install.sh && zsh "$installer"
```

Use `--ref dev` for development builds.

The app is installed to `~/Applications`, with a CLI at `~/.local/bin/flexmenu`.

## Configuration

Configuration files live in `~/.config/flexmenu/`.

**flexmenurc**

```sh
flexmenu config shortcut --key space --modifiers command,option
flexmenu config menu add --script menus/normal.sh
```

**menus/normal.sh**

```sh
#!/bin/zsh
echo '{"mode":"normal","items":[{"id":"terminal","title":"Terminal","action":"actions/terminal.sh"}]}'
```

**actions/terminal.sh**

```sh
#!/bin/zsh
open -a Terminal
```

Menu scripts return JSON and are checked in registration order. The first matching, non-empty menu is used.

Scripts receive context JSON through stdin and dragged file paths through arguments.

Menu and action changes take effect immediately. After editing `flexmenurc`, run:

```sh
flexmenu service restart
```

## CLI

```text
flexmenu menu                     Show the menu
flexmenu run <ID> -- [files...]    Run a menu action

flexmenu config init              Create the example configuration
flexmenu config path              Print the configuration path
flexmenu config check             Validate the configuration

flexmenu service start            Start the background service
flexmenu service stop             Stop the service
flexmenu service restart          Reload flexmenurc
flexmenu service status           Show service status

flexmenu --help                    Show all commands
```

See [Releases](https://github.com/hjy-233/FlexMenu/releases) for available builds.
