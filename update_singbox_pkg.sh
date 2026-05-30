#!/usr/bin/env bash
set -euo pipefail

# ===== 可配置参数 =====
REPO_URL="https://github.com/kenzok8/small.git"
BRANCH="master"
SUBDIR="sing-box"
TARGET_DIR="feeds/passwall_packages/sing-box"

# 固定替换的 init 文件（指定 commit）
INIT_OVERRIDE_URL="https://raw.githubusercontent.com/kenzok8/small/69f5314e26ebbc2627e88d25bd0e91453f386d58/sing-box/files/sing-box.init"
INIT_REL_PATH="files/sing-box.init"
# ======================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "[*] Root dir   : $ROOT_DIR"
echo "[*] Target dir : $TARGET_DIR"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# ---- 防呆：清理曾经误生成的“套娃 feeds/”目录（只在本目录下存在时清理）----
if [ -d "./feeds/passwall_packages/sing-box" ]; then
  echo "[!] Detected nested './feeds/passwall_packages/sing-box' (likely from old script). Removing './feeds'..."
  rm -rf ./feeds
fi

# ---- 初始化 / 校验 git sparse-checkout ----
if [ ! -d ".git" ]; then
  echo "[*] Initializing git repo (sparse-checkout)"
  git init
  git remote add origin "$REPO_URL"
  git config core.sparseCheckout true
  git sparse-checkout init --cone
  git sparse-checkout set "$SUBDIR"
else
  CURRENT_URL="$(git remote get-url origin 2>/dev/null || true)"
  if [ -z "$CURRENT_URL" ]; then
    git remote add origin "$REPO_URL"
  elif [ "$CURRENT_URL" != "$REPO_URL" ]; then
    echo "[!] Resetting origin url to $REPO_URL"
    git remote set-url origin "$REPO_URL"
  fi

  git config core.sparseCheckout true
  git sparse-checkout init --cone >/dev/null 2>&1 || true
  git sparse-checkout set "$SUBDIR"
fi

# ---- 强制清理（覆盖同名文件的关键）----
echo "[*] Cleaning local changes..."
git reset --hard
git clean -fd

# ---- 拉取 ----
echo "[*] Pulling $BRANCH (sparse: $SUBDIR)"
git pull origin "$BRANCH"

# ---- 抬平目录结构：把内层 sing-box/. 覆盖复制到当前目录 ----
if [ -d "$SUBDIR" ]; then
  echo "[*] Flattening directory structure..."
  cp -a "$SUBDIR"/. .
  rm -rf "$SUBDIR"
fi

# ---- 强制替换 init（写到正确位置：./files/sing-box.init）----
echo "[*] Overriding ./$INIT_REL_PATH with fixed commit version"
mkdir -p "$(dirname "./$INIT_REL_PATH")"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$INIT_OVERRIDE_URL" -o "./$INIT_REL_PATH"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "./$INIT_REL_PATH" "$INIT_OVERRIDE_URL"
else
  echo "[!] Error: neither curl nor wget found"
  exit 1
fi

chmod +x "./$INIT_REL_PATH"

echo "[+] Done. Key files:"
ls -lah "./$INIT_REL_PATH" ./Makefile 2>/dev/null || true
