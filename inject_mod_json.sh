#!/bin/bash

# ==============================================================================
# 脚本功能: 向 ZIP 压缩包中的 boot.json 添加"modLoaderManageable"。
# 使用方法:
#   ./inject_mod_json.sh <zip文件路径>
# 示例:
#   ./inject_mod_json.sh my-archive.zip
# ==============================================================================

# --- 参数定义 ---
ZIP_FILE="$1"
JSON_FILE_IN_ZIP="boot.json"
NEW_KEY="modLoaderManageable"
NEW_VALUE="true"

# --- 脚本设置 ---
# -e: 如果任何命令失败，立即退出脚本
# -u: 如果使用未定义的变量，视为错误并退出
# -o pipefail: 如果管道中的任何命令失败，则整个管道的返回值为失败
set -euo pipefail

# --- 参数校验 ---
if [ "$#" -ne 1 ]; then
    echo "错误: 需要提供 1 个参数。"
    echo "用法: $0 <zip文件>"
    exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo "错误: ZIP 文件 '$ZIP_FILE' 不存在。"
    exit 1
fi

# --- 检查依赖工具 ---
for cmd in zip unzip jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "错误: 依赖工具 '$cmd' 未安装，请先安装它。"
        exit 1
    fi
done

# --- 核心逻辑 ---

# 1. 创建一个安全的临时目录
# mktemp -d 会创建一个唯一的临时目录，避免冲突
# trap 命令确保无论脚本是正常结束、出错还是被中断，临时目录都会被删除
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "1. 创建临时目录: $TEMP_DIR"

# 2. 从 ZIP 包中解压目标 JSON 文件到临时目录
# -j 选项可以忽略原有的目录结构，但这里我们不使用，以保留正确的路径
echo "2. 解压 '$JSON_FILE_IN_ZIP' 从 '$ZIP_FILE'..."
unzip -q "$ZIP_FILE" "$JSON_FILE_IN_ZIP" -d "$TEMP_DIR"

# 检查文件是否真的被解压出来了
EXTRACTED_FILE="$TEMP_DIR/$JSON_FILE_IN_ZIP"
if [ ! -f "$EXTRACTED_FILE" ]; then
    echo "错误: 无法在 '$ZIP_FILE' 中找到文件 '$JSON_FILE_IN_ZIP'。"
    exit 1
fi

# 3. 使用 jq 添加键值对
# 创建一个新的临时 JSON 文件来存放修改后的内容
MODIFIED_FILE="${EXTRACTED_FILE}.modified"
echo "3. 正在向 JSON 文件添加键值对: '$NEW_KEY': '$NEW_VALUE'..."
jq --arg key "$NEW_KEY" --arg value "$NEW_VALUE" '. + {($key): $value}' "$EXTRACTED_FILE" > "$MODIFIED_FILE"

# 4. 将修改后的文件更新回 ZIP 压缩包
# 首先，我们需要进入临时目录，这样 zip 命令才能使用正确的相对路径
echo "4. 正在将修改后的文件更新回 '$ZIP_FILE'..."
(
    cd "$TEMP_DIR"
    # 将修改后的文件覆盖原文件
    mv "$MODIFIED_FILE" "$JSON_FILE_IN_ZIP"
    # 使用 zip 命令更新压缩包中的文件
    # -u 选项表示只更新修改过的文件或添加新文件
    zip -q -u "$ZIP_FILE" "$JSON_FILE_IN_ZIP"
)

# 5. 清理工作由 trap 命令自动完成
echo "5. 操作成功！临时目录将自动清理。"

exit 0