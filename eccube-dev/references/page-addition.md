# ページ追加

EC-CUBEで新規ページを追加するための手順。コントローラー/テンプレート作成に加え、`dtb_page` + `dtb_page_layout` へのDB登録が必要。

## 1. コントローラー作成

`app/Customize/Controller/` に配置。

```php
<?php
namespace Customize\Controller;

use Eccube\Controller\AbstractController;
use Sensio\Bundle\FrameworkExtraBundle\Configuration\Template;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;

class CustomPageController extends AbstractController
{
    /**
     * @Route("/custom_page", name="custom_page", methods={"GET"})
     * @Template("CustomPage/index.twig")
     */
    public function index(Request $request)
    {
        return [];
    }
}
```

- `AbstractController` を継承
- `@Route` でURL・ルート名・HTTPメソッドを定義
- `@Template` でTwigテンプレートパスを指定（`app/template/default/` からの相対パス）
- マイページ配下の場合は `Customize\Controller\Mypage\` 名前空間を使用

### マイページ配下の例

```php
namespace Customize\Controller\Mypage;

class CsvDownloadController extends AbstractController
{
    /**
     * @Route("/mypage/csv_download", name="mypage_csv_download", methods={"GET"})
     * @Template("Mypage/csv_download.twig")
     */
    public function index(Request $request)
    {
        return [];
    }
}
```

## 2. テンプレート作成

`app/template/default/` 配下に配置。`default_frame.twig` を継承する。

### 基本構造

```twig
{% extends 'default_frame.twig' %}

{% block main %}
    <div class="ec-layoutRole__main">
        {# ページコンテンツ #}
    </div>
{% endblock %}
```

### マイページ用テンプレート

マイページ配下では `mypageno` 変数でナビゲーションのアクティブ状態を制御し、`navi.twig` を含める。

```twig
{% extends 'default_frame.twig' %}
{% set mypageno = 'custom_page' %}
{% set body_class = 'mypage' %}

{% block main %}
    <div class="ec-layoutRole__main">
        <div class="ec-mypageRole">
            <div class="ec-pageHeader">
                {{ include('Mypage/loginname.twig') }}
                <h1>{{ 'マイページ'|trans }}/{{ 'ページタイトル'|trans }}</h1>
            </div>
            {% include 'Mypage/navi.twig' %}
        </div>
        <div class="ec-mypageRole">
            {# コンテンツ #}
        </div>
    </div>
{% endblock %}
```

## 3. ページDB登録（マイグレーション）

新規ページは `dtb_page` と `dtb_page_layout` への登録が必要。レイアウト登録がないとヘッダー/フッターが表示されない。

### dtb_page の主要カラム

| カラム | 説明 | 備考 |
|--------|------|------|
| `id` | ページID | `MAX(id) + 1` で自動採番 |
| `master_page_id` | マスタページID | NULL可 |
| `page_name` | ページ名 | 管理画面に表示 |
| `url` | ルート名 | `@Route` の `name` と一致させる |
| `file_name` | テンプレートパス | `@Template` と同じ（拡張子なし） |
| `edit_type` | 編集タイプ | 0: ユーザ定義, 2: デフォルト, 3: デフォルト確認 |
| `meta_robots` | robots設定 | `'noindex'` 等 |
| `discriminator_type` | 識別子 | 固定値 `'page'` |

### dtb_page_layout の主要カラム

| カラム | 説明 | 備考 |
|--------|------|------|
| `page_id` | ページID | `dtb_page.id` と一致 |
| `layout_id` | レイアウトID | 2: 下層ページ用レイアウト |
| `sort_no` | ソート順 | `MAX(sort_no) + 1` で自動採番 |
| `discriminator_type` | 識別子 | 固定値 `'pagelayout'` |

### layout_id の代表値

| ID | 説明 |
|----|------|
| 1 | トップページ用 |
| 2 | 下層ページ用（通常はこれを使用） |

### マイグレーション例

```php
<?php
namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version{YYYYMMDDHHmmss} extends AbstractMigration
{
    public function up(Schema $schema): void
    {
        // べき等性: 既に登録済みなら何もしない
        $count = $this->connection->fetchOne(
            "SELECT COUNT(*) FROM dtb_page WHERE url = 'custom_page'"
        );
        if ($count > 0) {
            return;
        }

        // ID自動採番
        $pageId = $this->connection->fetchOne('SELECT MAX(id) FROM dtb_page');
        $sortNo = $this->connection->fetchOne('SELECT MAX(sort_no) FROM dtb_page_layout');
        $pageId++;
        $sortNo++;

        // ページ登録
        $now = date('Y-m-d H:i:s');
        $this->addSql("INSERT INTO dtb_page (
            id, page_name, url, file_name, edit_type,
            create_date, update_date, meta_robots, discriminator_type
        ) VALUES (
            $pageId, 'カスタムページ', 'custom_page', 'CustomPage/index', 2,
            '$now', '$now', 'noindex', 'page'
        )");

        // レイアウト紐付け（layout_id=2: 下層ページ用）
        $this->addSql("INSERT INTO dtb_page_layout (
            page_id, layout_id, sort_no, discriminator_type
        ) VALUES (
            $pageId, 2, $sortNo, 'pagelayout'
        )");

        // PostgreSQLの場合はシーケンスも更新
        if ($this->platform->getName() === 'postgresql') {
            $this->addSql("SELECT setval('dtb_page_id_seq', $pageId)");
        }
    }

    public function down(Schema $schema): void
    {
        $this->addSql("DELETE FROM dtb_page_layout WHERE page_id = (SELECT id FROM dtb_page WHERE url = 'custom_page')");
        $this->addSql("DELETE FROM dtb_page WHERE url = 'custom_page'");
    }
}
```

### べき等性のポイント

- `url` カラムで既存チェック（`SELECT COUNT(*) ... WHERE url = 'route_name'`）
- `MAX(id) + 1` で安全にID採番（ハードコードしない）
- `MAX(sort_no) + 1` でソート順も動的に決定
- PostgreSQL環境ではシーケンス値の更新も必要

## 4. ナビゲーション追加（任意）

マイページやサイドメニュー等にリンクを追加する場合は、該当するTwigテンプレートを編集する。

### マイページナビ

`app/template/default/Mypage/navi.twig` にリンクを追加:

```twig
<a href="{{ url('mypage_csv_download') }}"
   class="ec-navlistRole__item{{ mypageno is defined and mypageno == 'csv_download' ? ' active' : '' }}">
    在庫CSVデータ
</a>
```

### サイドメニュー（ブロック）

`app/template/default/Block/` 配下のブロックテンプレートにリンクを追加。

## チェックリスト

1. [ ] コントローラー作成（`@Route` + `@Template`）
2. [ ] テンプレート作成（`default_frame.twig` 継承）
3. [ ] マイグレーション作成（`dtb_page` + `dtb_page_layout` INSERT）
4. [ ] ナビゲーションにリンク追加（必要な場合）
5. [ ] ステージング環境でマイグレーション実行
6. [ ] キャッシュクリア（`bin/console cache:clear`）
