# LBR Trio テンプレート

`leader` / `build` / `review` の3ロールを `herdr` で連携させる、OpenCode V2 向けのチーム開発ワークフローテンプレートです。
アプリケーションコードは含みません。
新しいリポジトリに、エージェントの運用ルールと権限設定を導入するための土台を配布します。

## 参照構造

- 運用ルールと報告書式の原典: [AGENTS.md](AGENTS.md)
- 改善原則（根拠集。規則ではない）: [docs/principles.md](docs/principles.md)
- 権限設定の原典: [.opencode/opencode.json](.opencode/opencode.json)
- 導入手順と全体像: 本 README
- Nix 環境向けの追記: [docs/nix.md](docs/nix.md)

README は案内役です。
日々の判断と報告の書き方は AGENTS.md、根拠は principles.md、権限の実効性は opencode.json を参照してください。
README と原典が食い違う場合は原典を優先します。

## 1. LBR Trio の概要

LBR Trio は Leader-Build-Review の3ロールで開発を進めるワークフローです。
各ロールは `herdr` 上の独立したペインで動作し、自分のロールを `herdr` の登録名から判断します。

| ロール | 担当 | ペイン |
|---|---|---|
| `leader` | 要件定義と全体統括。`build` へタスクを依頼し、`review` の最終報告を集約する。実装とレビューは行わない | 左 |
| `build` | 実装。不明点は `leader` に確認し、完了後は起点コミットを明記して `review` へ報告する | 右上 |
| `review` | コードレビュー。ファイルは変更せず、検証コマンドは自分で実行する。最終報告は `leader` へ直接送る | 右下 |

`leader` は Plan 役を担いますが、ロール名に `plan` は使いません。
OpenCode 組み込みの `plan` エージェント（Plan モード）と ID が衝突すると、毎ターン「Plan モード」の制約リマインダーが注入され、`herdr` による `build` への委任まで拒否する誤認が起きます。

### 完全非同期プロトコル

エージェント間の相互待ちによるデッドロックを防ぐため、連絡は完全非同期に統一します。

- `herdr agent prompt <ロール> "<メッセージ>"` を `--wait` なしで実行し、送信後は自分のターンを終了します。
- 返答や完了通知は、自分のペインに届くメッセージとして受け取ります。
- 送信直後に返る `idle` は相手の着手前の状態であり、完了ではありません。
- どのロールも、相手の完了を待つターンを持ちません。待つ必要がある場面は人間に回します。
- 受領の返信（ACK）は送りません。沈黙＝受領とみなし、連絡するのは異常時（起点が存在しない、範囲が読めない等）だけにします。
- 長文の報告やレビュー結果は Markdown ファイルに出力し、そのパスを共有します。

### 報告経路

- `build` から `review` へ、作業内容と範囲（`起点..終点SHA`）を報告します。
- `review` から `leader` へ、最終報告を直接送ります。`build` への委託はしません。
- `review` の指摘事項は「要修正」と「提案」に分類します。
- 報告は AGENTS.md の「報告ヘッダ」3項目（範囲 / 検証 / 未確認事項）で行い、数値・外部仕様・実機挙動の断定には根拠タグを付けます。
- `leader` は人間から実装指示を受けたら、自力実装を試みず、即座に `build` へ委任します。人間へは委任内容と報告経路を1行で返します。

### 権限はガードレール

`.opencode/opencode.json` の `permissions` は、ロールごとの事故を減らすためのガードレールです。
完全な封じ込め装置ではありません。

- `leader` はファイル編集を `~/.opencode/leader/*` と `PLAN.md` に限定し、シェルでは `tee` / `rm` / `mv`、書き込み系 `git`（`add` / `commit` / `push`）、破壊的な `git` 操作（`reset` / `clean` / `checkout` / `restore` / `stash` / `merge` / `rebase`）を拒否します。
- `review` は `edit` 系ツールをすべて拒否し、`tee` / `rm` / `mv`、書き込み系 `git`、破壊的な `git` 操作の通常形式を拒否します。検証と調査のコマンドは自由に使えます。
- `leader` と `review` の権限では、`herdr *` を最後の `allow` に置き、報告の送信が権限判定で止まらないようにします。
- `build` は制限なしとします。実装を止めないことを優先します。
- 組み込みの `plan` は `disabled: true` にして、誤って Plan モードで起動しないようにします。

リダイレクトや `touch` による新規作成、`sh -c` や `git -C` を前置きした迂回は、権限設定では塞ぎません。
これらは AGENTS.md のロール規律で防ぎます。
機械的に拒否する対象を「取り返しのつかない破壊的操作」に絞ることで、正規のコマンドを誤って止めにくくしています。

## 2. 新リポジトリへの導入

### ① AGENTS.md をコピーする

テンプレートの `AGENTS.md` を、新しいリポジトリのルートにコピーします。

```sh
cp /path/to/lbr-trio/AGENTS.md ./AGENTS.md
```

`AGENTS.md` は環境に依存しない運用ルールです。
Nix 環境で使う場合だけ、手順④で Nix セクションを追記します。

### ② opencode.json をコピーし、model を調整する

`.opencode/opencode.json` を同じパスにコピーします。

```sh
mkdir -p .opencode
cp /path/to/lbr-trio/.opencode/opencode.json .opencode/opencode.json
```

`agents.<role>.model` は、利用する環境で使えるモデルに合わせて変更します。
テンプレートの実績値は次のとおりです。

| ロール | model |
|---|---|
| `leader` | `opencode-go/glm-5.3` |
| `build` | `opencode-go/deepseek-v4.1-flash` |
| `review` | `opencode-go/claude-haiku-5-5` |

プロバイダーを変える場合は `provider/model` の形式で指定します。
`agents` と `permissions` の V2 形式は維持してください。

### ③ 改善原則を参照する

報告書式は `AGENTS.md` に統合済みのため、コピーする docs はありません。
改善原則の原典は `docs/principles.md` です。各プロジェクトは写しを置かず、原典を参照します。

### ④ Nix 環境では docs/nix.md を追記する

Nix で管理された環境では、`docs/nix.md` の内容を `AGENTS.md` の末尾に追記します。

```sh
# 末尾に空行を足してから追記する
printf '\n' >> AGENTS.md
cat /path/to/lbr-trio/docs/nix.md >> AGENTS.md
```

Nix を使わない環境では、この手順は不要です。

### ⑤ herdr に3エージェントを登録する

プロジェクト名に即したチーム名（例: `my-app`）で `herdr` のワークスペースを開き、次のペイン構成にします。
ワークスペース名は `herdr workspace create --label <チーム名>` または `herdr workspace rename <ワークスペースID> <チーム名>` で設定できます。

```text
┌──────────────┬──────────────┐
│              │    build     │
│    leader    ├──────────────┤
│              │    review    │
└──────────────┴──────────────┘
```

エージェント名はロール判定に使うため、`leader` / `build` / `review` から変えません。
OpenCode を使う場合の起動例を示します。
以下のコマンドは `herdr` のペイン内で実行します。

```sh
# 左のペインを用意した状態で、右上と右下を分割する
herdr pane split --current --direction right --cwd "$PWD" --no-focus
herdr pane split --pane "<右上のペインID>" --direction down --cwd "$PWD" --no-focus

# 実際のペインIDに置き換えて、各ペインで OpenCode を起動する
herdr agent start leader --kind opencode --pane "<左のペインID>"
herdr agent start build --kind opencode --pane "<右上のペインID>"
herdr agent start review --kind opencode --pane "<右下のペインID>"
```

すでに各ペインでエージェントを起動済みの場合は、`herdr agent rename <対象> <ロール名>` で登録名を付けます。
OpenCode 側では、各ペインで対応するエージェント設定（`leader` / `build` / `review`）を選択してください。
`opencode.json` の権限は、選択中のエージェント設定にだけ適用されます。
登録後は `herdr agent list` で3つの名前と状態を確認できます。
最初の指示は `leader` に送ります。

```sh
herdr agent prompt leader "このリポジトリの実装を始めてください。"
```

## 3. カスタマイズポイント

### model

`agents.<role>.model` を、利用環境で使えるモデルに置き換えます。
テンプレートの値は実績値であり、必須ではありません。
3ロールで同じモデルを使っても構いません。
役割ごとにモデルを変える場合は、要件整理、実装、レビューそれぞれの作業量と相性で選びます。

### 権限

`permissions` は、ロールの事故を減らすための最小限の拒否リストとして保守します。
新しいツールや危険なコマンドを追加するときは、`leader` と `review` の `deny` を検討します。
`herdr *` の `allow` は末尾に残してください。
権限設定は封じ込め装置ではないため、ロール規律を緩める場合は AGENTS.md の該当節も合わせて見直します。

### コミット規約

コミットは Conventional Commits に従います。
代表的な type は `feat:`、`fix:`、`docs:`、`test:`、`chore:` です。
標準の運用では `main` ブランチへ直接コミットし、`push` は行いません。
`build` は `review` へ報告するとき、範囲を `起点..終点SHA` で明記します。
要件・計測・実装・文書は1コミット1役割に分け、コミットメッセージの prefix（`要件:` `計測:` `実装:` `文書:`）で役割を表します。

### 報告書式

報告書式は [AGENTS.md](AGENTS.md) の「報告の書式」に集約しています。
`build` → `review` と `review` → `leader` は共通の3項目ヘッダ（範囲 / 検証 / 未確認事項）を使い、`review` → `leader` は判定（合格 / 要修正残）を添えます。
数値・外部仕様・実機挙動の断定には根拠タグ（`[source: path:line]` / `[test: コマンド]` / `[unverified]`）を付けます。

`leader` から人間への要約は3項目（判断材料 / 未確認 / 次の action）に固定します。
人間が読む量を増やすと、判断に必要な情報が埋もれます。
