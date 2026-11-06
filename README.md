# FlexMenu

macOS 径向菜单。菜单内容由 Shell 脚本按上下文生成，动作由独立脚本执行。

## 命令行入口

构建后，可执行文件位于 `FlexMenu.app/Contents/MacOS/flexmenu`。将该目录加入 `PATH`，即可在终端直接使用 `flexmenu`。例如 App 安装在 `/Applications` 时：

```sh
export PATH="/Applications/FlexMenu.app/Contents/MacOS:$PATH"
```

命令：

```text
flexmenu config init                 创建可编辑的初始配置，不覆盖现有文件
flexmenu config path                 显示 flexmenurc 路径
flexmenu config check [路径]          执行并校验配置及菜单脚本路径，不更新运行快照
flexmenu service start               加载配置并启动常驻服务
flexmenu service restart             重新加载配置并重启服务
flexmenu service stop                停止服务
flexmenu service status              查看服务状态
flexmenu menu                        呼出菜单
flexmenu run <ID> -- [文件路径...]     按当前上下文生成菜单并执行其中的动作
flexmenu --help                      查看帮助
```

`--` 表示选项结束；其后的每个文件路径会作为独立参数传给动作脚本，路径中的空格和以 `-` 开头的名称不会被拼入 Shell 命令。

## 配置脚本

`flexmenurc` 只在 `service start` 和 `service restart` 时执行。FlexMenu 使用 zsh 加载它，并提供 `flexmenu` Shell 函数，因此脚本内可直接写：

```sh
flexmenu config shortcut --key space --modifiers command,option
flexmenu config menu add --script menus/normal.sh
flexmenu config menu add --script menus/dragging.sh
```

快捷键目前支持 `space` 和字母 `a` 到 `z`；修饰键支持 `command`、`option`、`control`、`shift`，用逗号分隔。菜单脚本路径相对于 `flexmenurc` 所在目录解析，也可以使用绝对路径。

每次呼出菜单时，FlexMenu 把上下文 JSON 写入菜单脚本的标准输入，拖动的文件路径作为独立参数传入。菜单脚本从标准输出返回一个 JSON 对象：

```json
{
  "mode": "normal",
  "items": [
    { "id": "terminal", "title": "终端", "action": "actions/terminal.sh" }
  ]
}
```

`mode` 可省略；填写时须为 `normal` 或 `dragging`，与当前模式不一致则跳过该脚本。`items` 可以为空数组。FlexMenu 按登记顺序执行脚本，使用第一个匹配模式且返回非空 `items` 的菜单。菜单项的 `id`、`title`、`action` 必填，`id` 在同一菜单内不能重复。`action` 路径同样相对于 `flexmenurc` 所在目录解析。脚本输出必须是 JSON；调试信息请写到标准错误。菜单生成在后台进行，单个脚本限时 3 秒。

例如 `menus/dragging.sh` 可用 `(( $# == 0 ))` 判断是否拖入文件；有文件时返回 `{"mode":"dragging","items":[{"id":"reveal","title":"在 Finder 中定位","action":"actions/reveal.sh"}]}`。对应的 `reveal.sh` 可逐个执行 `open -R -- "$file"`。`config init` 会创建这两个示例脚本。

动作脚本只需执行动作，例如 `actions/terminal.sh` 可以写成 `#!/bin/zsh` 加 `open -a Terminal`。选中时，FlexMenu 把同一份上下文 JSON 写入动作脚本的标准输入，拖动文件路径作为独立命令行参数传入。动作脚本限时 60 秒。

`flexmenu run <ID> -- [文件路径...]` 会根据传入路径构造上下文、重新运行菜单脚本，再查找 ID。没有路径时使用 `normal` 模式，有路径时使用 `dragging` 模式。通过 `run` 调用时，`frontmostBundleID` 为空。配置输出只允许 `flexmenu config ...` 产生的 JSON 指令，其他调试信息请写到标准错误。

上下文 JSON 字段：`mode`、`frontmostBundleID`、`filePaths`、`text`、`url`。没有值的字段为 `null`，文件列表没有内容时为 `[]`。

运行时配置快照保存在用户的 Application Support 目录。修改 `flexmenurc` 后需运行 `flexmenu service restart`；修改菜单或动作脚本后，下次使用即可生效。`config check` 仅检查配置和菜单脚本路径；菜单 JSON 会在菜单呼出时校验。

App Sandbox 已关闭。需要访问受 macOS 隐私保护的内容时，仍须由系统授予相应权限。
