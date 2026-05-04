#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

CONFIG_PATH="${1:-${SCRIPT_DIR}/resources/config.yaml}"
MIXIN_PATH="${2:-${SCRIPT_DIR}/resources/mixin.yaml}"
RUNTIME_PATH="${3:-${SCRIPT_DIR}/resources/runtime.yaml}"

YQ_BIN="${YQ_BIN:-${SCRIPT_DIR}/bin/yq}"
if [ ! -x "$YQ_BIN" ]; then
  YQ_BIN=$(command -v yq)
fi

"$YQ_BIN" eval-all '
  select(fileIndex==0) as $config |
  select(fileIndex==1) as $mixin |

  $mixin |= del(._custom) |
  (($config // {}) * $mixin) as $runtime |
  $runtime |

  .rules = (
    ($mixin.rules.prefix // []) +
    ($config.rules // []) +
    ($mixin.rules.suffix // [])
  ) |

  .proxies = (
    ($mixin.proxies.prefix // []) +
    (
      ($config.proxies // []) as $configList |
      ($mixin.proxies.override // []) as $overrideList |
      $configList | map(
        . as $configItem |
        (
          $overrideList[] | select(.name == $configItem.name)
        ) // $configItem
      )
    ) +
    ($mixin.proxies.suffix // [])
  ) |

  .proxy-groups = (
    ($mixin.proxy-groups.prefix // []) +
    (
      ($config.proxy-groups // []) as $configList |
      ($mixin.proxy-groups.override // []) as $overrideList |
      $configList | map(
        . as $configItem |
        (
          $overrideList[] | select(.name == $configItem.name)
        ) // $configItem
      )
    ) +
    ($mixin.proxy-groups.suffix // [])
  )
' "$CONFIG_PATH" "$MIXIN_PATH" >"$RUNTIME_PATH"

echo "Merged ${CONFIG_PATH} and ${MIXIN_PATH} into ${RUNTIME_PATH}"
