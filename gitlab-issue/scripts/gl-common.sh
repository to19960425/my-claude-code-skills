#!/usr/bin/env bash
# 共通関数: 認証・プロジェクト推定

gl_load_env() {
  if [ -z "${GITLAB_TOKEN:-}" ] || [ -z "${GITLAB_URL:-}" ]; then
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local skill_dir="$(dirname "$script_dir")"
    for envfile in "$skill_dir/.env" "$HOME/.gitlab.env"; do
      if [ -f "$envfile" ]; then
        set -a
        source "$envfile"
        set +a
        break
      fi
    done
  fi

  if [ -z "${GITLAB_URL:-}" ]; then
    echo "Error: GITLAB_URL が設定されていません"
    echo "環境変数または ~/.gitlab.env に設定してください"
    exit 1
  fi

  if [ -z "${GITLAB_TOKEN:-}" ]; then
    echo "Error: GITLAB_TOKEN が設定されていません"
    echo "環境変数または ~/.gitlab.env に設定してください"
    exit 1
  fi
}

# git remoteからGitLabプロジェクト名を推定
gl_detect_project() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null) || {
    echo "Error: git remote が見つかりません。プロジェクト名を引数で指定してください" >&2
    return 1
  }

  # SSH: git@gitlab.m-green.co.jp:green/bldplanner.git
  # HTTPS: https://gitlab.m-green.co.jp/green/bldplanner.git
  local project_path
  project_path=$(echo "$remote_url" | sed -E 's#.*gitlab\.m-green\.co\.jp[:/](.+?)(\.git)?$#\1#' | sed 's/\.git$//')

  if [ -z "$project_path" ]; then
    echo "Error: GitLab URLを検出できません (remote: $remote_url)" >&2
    return 1
  fi

  # パスの最後の部分をプロジェクト名として返す
  basename "$project_path"
}

# プロジェクト名からプロジェクトIDを取得
gl_resolve_project_id() {
  local project="$1"

  local project_json
  project_json=$(curl -sf --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "$GITLAB_URL/api/v4/projects?search=$project&membership=true&per_page=5")

  local project_id
  project_id=$(echo "$project_json" | python3 -c "
import json, sys
projects = json.load(sys.stdin)
for p in projects:
    if '$project' in p['path']:
        print(p['id'])
        break
" 2>/dev/null)

  if [ -z "$project_id" ]; then
    echo "Error: プロジェクト '$project' が見つかりません" >&2
    echo "候補:" >&2
    echo "$project_json" | python3 -c "
import json, sys
for p in json.load(sys.stdin):
    print(f'  {p[\"path_with_namespace\"]}')
" >&2
    return 1
  fi

  echo "$project_id"
}
