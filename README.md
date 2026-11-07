# FlexMenu

macOS 上的上下文径向菜单：按快捷键、移动鼠标选方向，再点击；拖动内容时松开即可执行。菜单和动作由 Shell 脚本定义，Esc 可取消。

## 安装

在 Apple Silicon Mac 上安装最新正式版：

```sh
installer=$(mktemp) && curl -fsSLo "$installer" https://raw.githubusercontent.com/hjy-233/FlexMenu/main/install.sh && zsh "$installer"
```

安装开发版或指定版本时，在命令末尾分别添加 `--ref dev` 或 `--ref v1.2.3`。安装器只下载已构建的 Release；正式版需要已公开发布，开发版需要该提交的 CI 构建完成。

App 会安装到 `~/Applications/FlexMenu.app`，`flexmenu` 命令会链接到 `~/.local/bin`。若终端找不到命令，请把该目录加入 `PATH`：

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## 配置

首次安装会在 `~/.config/flexmenu` 创建示例配置。`flexmenurc` 只在服务启动或重启时执行，例如：

```sh
flexmenu config shortcut --key space --modifiers command,option
flexmenu config menu add --script menus/normal.sh
flexmenu config menu add --script menus/dragging.sh
```

菜单脚本向标准输出返回 JSON，菜单项的 `action` 指向动作脚本：

```json
{"mode":"normal","items":[{"id":"terminal","title":"终端","action":"actions/terminal.sh"}]}
```

`mode` 可省略；可填 `normal` 或 `dragging`。脚本路径相对于 `~/.config/flexmenu` 解析。菜单脚本和动作脚本都从标准输入接收上下文 JSON，拖动文件路径作为独立参数传入。上下文字段为 `mode`、`frontmostBundleID`、`filePaths`、`text`、`url`。示例脚本由 `config init` 创建。

## 常用命令

```text
flexmenu config init            创建缺失的示例配置
flexmenu config path            显示配置路径
flexmenu config check           校验配置与菜单脚本
flexmenu service start          启动服务
flexmenu service restart        重新加载 flexmenurc
flexmenu service stop|status    停止服务或查看状态
flexmenu menu                   呼出菜单
flexmenu run <ID> -- [文件...]   从命令行执行菜单动作
flexmenu --help                 查看完整用法
```

CI 在 `dev`、`main` 和发往 `main` 的 PR 上检查构建；`dev` 提交通过后发布开发版，从 `main` 推送 `vMAJOR.MINOR.PATCH` tag 后创建正式版草稿。
