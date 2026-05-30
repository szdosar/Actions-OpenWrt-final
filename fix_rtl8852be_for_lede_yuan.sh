#!/usr/bin/env bash
set -euo pipefail

LEDE_DIR="${1:-${LEDE_DIR:-$HOME/lede}}"
REALTEK_MK="$LEDE_DIR/package/kernel/mac80211/realtek.mk"

if [[ ! -f "$REALTEK_MK" ]]; then
  echo "Error: cannot find realtek.mk at: $REALTEK_MK" >&2
  echo "Usage: $0 [LEDE_DIR]" >&2
  exit 1
fi

if ! grep -q 'define KernelPackage/rtw89-8852be' "$REALTEK_MK"; then
  echo "Error: this tree does not contain kmod-rtw89-8852be in $REALTEK_MK" >&2
  exit 1
fi

backup="$REALTEK_MK.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$REALTEK_MK" "$backup"

perl -0pi -e '
  s{^(config-\$\(call config_package,rtw89-8852be\) \+=)([^\n]*)$}{
    my ($prefix, $symbols) = ($1, $2);
    $symbols =~ /\bRTW89_8852B_COMMON\b/ ? "$prefix$symbols" : "$prefix RTW89_8852B_COMMON$symbols";
  }gme;

  s{(define KernelPackage/rtw89-8852be\n.*?endef)}{
    my $block = $1;
    if ($block !~ /rtw89_8852b_common\.ko/) {
      $block =~ s{(  FILES:= \\\n)}{$1\t\$(PKG_BUILD_DIR)/drivers/net/wireless/realtek/rtw89/rtw89_8852b_common.ko \\\n};
    }
    $block;
  }gse;
' "$REALTEK_MK"

if cmp -s "$REALTEK_MK" "$backup"; then
  rm -f "$backup"
  echo "No change needed: RTL8852BE common module fix is already present."
else
  echo "Patched: $REALTEK_MK"
  echo "Backup:  $backup"
fi

echo
printf 'Verify with:\n  cd %q && make package/kernel/mac80211/compile V=s -j1\n' "$LEDE_DIR"
