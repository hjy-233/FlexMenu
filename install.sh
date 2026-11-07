#!/bin/zsh
set -euo pipefail

usage='用法：install.sh [--ref dev|vMAJOR.MINOR.PATCH]'
if (( $# == 0 )); then
    ref=latest
elif (( $# == 1 )) && [[ "$1" == --help ]]; then
    print -r -- "$usage"
    exit 0
elif (( $# == 2 )) && [[ "$1" == --ref ]]; then
    ref="$2"
else
    print -u2 -- "$usage"
    exit 1
fi

if [[ "$ref" != latest && "$ref" != dev && ! "$ref" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 -- "不支持的版本：$ref；请使用 dev 或 vMAJOR.MINOR.PATCH"
    exit 1
fi
if [[ "$(uname -m)" != arm64 ]]; then
    print -u2 -- '当前发布包仅支持 Apple Silicon Mac'
    exit 1
fi
if ! command -v jq >/dev/null; then
    print -u2 -- '安装需要 jq'
    exit 1
fi

api='https://api.github.com/repos/hjy-233/FlexMenu'
if [[ "$ref" == dev ]]; then
    if ! branch=$(curl -fsSL --retry 3 -H 'Accept: application/vnd.github+json' "$api/branches/dev"); then
        print -u2 -- '无法查询 dev 分支'
        exit 1
    fi
    commit=$(print -r -- "$branch" | jq -er '.commit.sha | select(test("^[0-9a-f]{40}$"))')
    tag="dev-$commit"
elif [[ "$ref" == latest ]]; then
    if ! release=$(curl -fsSL --retry 3 -H 'Accept: application/vnd.github+json' "$api/releases/latest"); then
        print -u2 -- '尚无已发布的正式版本'
        exit 1
    fi
    tag=$(print -r -- "$release" | jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))')
else
    tag="$ref"
fi

if [[ "$ref" != latest ]]; then
    if ! release=$(curl -fsSL --retry 3 -H 'Accept: application/vnd.github+json' "$api/releases/tags/$tag"); then
        print -u2 -- "版本 $tag 尚无可下载的 Release"
        exit 1
    fi
fi

archive="FlexMenu-$tag-arm64.zip"
checksum="$archive.sha256"
if ! archive_url=$(print -r -- "$release" | jq -er --arg name "$archive" '.assets[] | select(.name == $name) | .browser_download_url'); then
    print -u2 -- "Release 缺少安装包：$archive"
    exit 1
fi
if ! checksum_url=$(print -r -- "$release" | jq -er --arg name "$checksum" '.assets[] | select(.name == $name) | .browser_download_url'); then
    print -u2 -- "Release 缺少校验文件：$checksum"
    exit 1
fi
installed_app="$HOME/Applications/FlexMenu.app"
command_link="$HOME/.local/bin/flexmenu"

if [[ -e "$command_link" && ! -L "$command_link" ]]; then
    print -u2 -- "已有非链接文件：$command_link"
    exit 1
fi

mkdir -p "$HOME/Applications" "$HOME/.local/bin"
staging_dir=$(mktemp -d "$HOME/Applications/.FlexMenu-install.XXXXXXXX")
staged_app="$staging_dir/FlexMenu.app"
previous_app="$staging_dir/previous.app"
curl -fsSL --retry 3 -o "$staging_dir/$archive" "$archive_url"
curl -fsSL --retry 3 -o "$staging_dir/$checksum" "$checksum_url"
(
    cd "$staging_dir"
    shasum -a 256 -c "$checksum"
)
ditto -x -k "$staging_dir/$archive" "$staging_dir"
if [[ ! -x "$staged_app/Contents/MacOS/flexmenu" ]]; then
    print -u2 -- "发布包中缺少 FlexMenu.app：$staging_dir"
    exit 1
fi
codesign --verify --deep --strict "$staged_app"
if [[ ! -e "$HOME/.config/flexmenu/flexmenurc" ]]; then
    "$staged_app/Contents/MacOS/flexmenu" config init
fi
"$staged_app/Contents/MacOS/flexmenu" config check

if [[ -d "$installed_app" ]]; then
    mv "$installed_app" "$previous_app"
fi
if ! mv "$staged_app" "$installed_app"; then
    if [[ -d "$previous_app" ]]; then
        mv "$previous_app" "$installed_app"
    fi
    print -u2 -- "安装版替换失败；排查文件保留在 $staging_dir"
    exit 1
fi
ln -sfn "$installed_app/Contents/MacOS/flexmenu" "$command_link"
if ! "$command_link" service restart; then
    if [[ -d "$previous_app" ]]; then
        mv "$installed_app" "$staged_app"
        mv "$previous_app" "$installed_app"
        "$command_link" service start || true
    fi
    print -u2 -- "服务重启失败；排查文件保留在 $staging_dir"
    exit 1
fi
rm -rf "$staging_dir"

print -r -- "已安装：$installed_app"
print -r -- "版本：$tag"
print -r -- "命令入口：$command_link"
