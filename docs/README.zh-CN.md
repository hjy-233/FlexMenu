# FlexMenu

一个可定制的环形菜单，专为 macOS 设计。 菜单与其动作全部使用 Shell 脚本配置。

<!-- TODO: Demo GIF -->

## 安装

需要一台 Apple 芯片的 Mac 和 `jq`

```sh
installer=$(mktemp) && curl -fsSLo "$installer" https://raw.githubusercontent.com/hjy-233/FlexMenu/main/install.sh && zsh "$installer"
```

使用 `--ref dev` 参数来安装最新开发版本

App 会被安装到 `~/Applications`，而命令行工具将会被安装到 `~/.local/bin/flexmenu`

## 配置

配置文件在 `~/.config/flexmenu/` 文件夹。

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

菜单脚本需返回 JSON 数据，并按照注册顺序依次检查。系统会使用第一个匹配当前模式且非空的菜单。

动作脚本会通过 stdin 收到上下文信息、通过参数收到正在拖动的文件路径

菜单脚本和操作脚本的修改会立即生效。修改 `flexmenurc` 后，需要重启服务：

```sh
flexmenu service restart
```

## 命令行工具（CLI）

```text
flexmenu menu                     显示菜单
flexmenu run <ID> -- [files...]    执行指定菜单操作

flexmenu config init              创建示例配置
flexmenu config path              显示配置文件路径
flexmenu config check             检查配置是否有效

flexmenu service start            启动后台服务
flexmenu service stop             停止后台服务
flexmenu service restart          重启服务并重新加载 flexmenurc
flexmenu service status           查看服务状态

flexmenu --help                    查看所有命令
```

可在 [Releases](https://github.com/hjy-233/FlexMenu/releases) 页面获取已发布的版本。
