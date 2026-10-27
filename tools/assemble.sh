#!/usr/bin/env bash
# assemble — herdr のペインに opencode の leader / build / review を集結させる。
# レイアウト: leader=左, build=右上, review=右下（新しいタブに作る）
# 実行: tools/assemble.sh（herdr のペイン内で）
set -euo pipefail

[[ ${HERDR_ENV:-} == 1 ]] || {
  echo "herdr のペイン内で実行してください" >&2
  exit 1
}
cwd=$(cd -- "$(dirname -- "$0")/.." && pwd)

json_field() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" <<<"$2" | head -n1; }
agent_env() { printf 'OPENCODE_CONFIG_CONTENT={"default_agent":"%s"}' "$1"; }

tab=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$cwd" \
  --label team --env "$(agent_env leader)" --no-focus)
tab_id=$(json_field tab_id "$tab")
leader_pane=$(json_field pane_id "$tab")

build_pane=$(json_field pane_id "$(herdr pane split "$leader_pane" --direction right --ratio 0.5 \
  --cwd "$cwd" --env "$(agent_env build)" --no-focus)")
review_pane=$(json_field pane_id "$(herdr pane split "$build_pane" --direction down --ratio 0.5 \
  --cwd "$cwd" --env "$(agent_env review)" --no-focus)")

# 各ペインの default_agent を効かせるため、専用サーバーで起動する。
# 起動待ちが直列にならないよう、3 つを並列に起動してからまとめて待つ。
start_agent() {
  herdr agent start "$1" --kind opencode --pane "$2" -- --standalone >/dev/null
}

start_agent leader "$leader_pane" & leader_pid=$!
start_agent build "$build_pane" & build_pid=$!
start_agent review "$review_pane" & review_pid=$!

failed=0
wait "$leader_pid" || failed=1
wait "$build_pid" || failed=1
wait "$review_pid" || failed=1
((failed == 0)) || exit 1

herdr tab focus "$tab_id" >/dev/null
echo "leader=$leader_pane build=$build_pane review=$review_pane (tab=$tab_id)"
