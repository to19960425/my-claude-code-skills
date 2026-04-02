---
name: gitlab-issue
description: >
  社内GitLab (gitlab.m-green.co.jp) のイシュー操作スキル。
  イシュー単体取得と一覧取得に対応。対象リポジトリ内で実行すればプロジェクト名を自動推定する。
  トリガー: イシュー, issue, チケット, タスク確認, gitlab, イシュー一覧,
  「〇〇の#XX見て」, 「イシュー取得して」, 「未完了のイシュー一覧」
---

# GitLab Issue スキル

スクリプトは `~/.claude/skills/gitlab-issue/scripts/` にある。
認証情報は `~/.gitlab.env` から自動読み込み（`GITLAB_URL`, `GITLAB_TOKEN`）。

## コマンド

### イシュー単体取得

```bash
# 対象リポジトリ内（プロジェクト自動推定）
~/.claude/skills/gitlab-issue/scripts/gl-issue <issue-number>

# プロジェクト明示指定
~/.claude/skills/gitlab-issue/scripts/gl-issue <project-name> <issue-number>
```

### イシュー一覧取得（未完了のみ）

```bash
# 対象リポジトリ内（プロジェクト自動推定）
~/.claude/skills/gitlab-issue/scripts/gl-issues

# プロジェクト明示指定
~/.claude/skills/gitlab-issue/scripts/gl-issues <project-name>
```

## プロジェクト自動推定

引数が省略された場合、`git remote get-url origin` から GitLab プロジェクト名を自動推定する。
対象リポジトリ外から実行する場合はプロジェクト名を引数で明示指定する。

## イシュー取得後の想定アクション

- イシュー内容をもとにコード実装の相談・見積もり
- イシューの要約
- 関連コードの調査
