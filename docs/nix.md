# Nix

この環境は Nix で管理されている。
Nix を使わない環境では、このセクションを `AGENTS.md` に追記する必要はない。

## devShell のルール

- 必要なツールは Nix Flake の `devShell` に導入する。
- `node` や `pnpm` は `devShell` が提供するため、`PATH` に直接入っていない。
- 実行コマンドは `nix develop -c` でラップする（例: `nix develop -c pnpm test`）。
- `flake.nix` を作成または変更したら即座に `git add` する。
  未トラックの `flake.nix` では `nix develop` が失敗するため。

## 注意事項

- `flake.nix` を `git add` する前に `nix develop` を実行すると失敗する。
  作成または変更後は、他の作業より先に `git add` する。
- `node` や `pnpm` はシェルの `PATH` にない。
  `pnpm` を直接実行せず、必ず `nix develop -c` を付ける。
- devShell の起動には時間がかかる。
  頻繁に実行する場合は `direnv` などで常駐させる方法もあるが、このテンプレートでは明示的な `nix develop -c` を標準とする。
