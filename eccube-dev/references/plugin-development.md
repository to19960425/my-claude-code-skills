# プラグイン開発

公式: https://doc4.ec-cube.net/plugin

## プラグイン基本構成

### ディレクトリ構造

`bin/console eccube:plugin:generate` でスケルトンを生成できる。

```
app/Plugin/{PluginCode}/
  ├── composer.json              # プラグイン定義（type: eccube-plugin, extra.code 必須）
  ├── PluginManager.php          # ライフサイクル管理（任意）
  ├── Nav.php                    # 管理画面ナビゲーション（任意）
  ├── TwigBlock.php              # Twigブロック登録（任意）
  ├── Event.php                  # イベント購読（任意）
  ├── Controller/
  │   └── Admin/                 # 管理画面コントローラー
  ├── Entity/                    # プラグイン独自エンティティ / Trait
  ├── Repository/                # リポジトリ
  ├── Form/Type/Admin/           # 管理画面用フォーム
  ├── Service/                   # ビジネスロジック
  ├── DoctrineMigrations/        # プラグイン固有マイグレーション
  └── Resource/
      ├── config/
      │   └── services.yaml      # サービス定義（autowiring済みのため通常は不要）
      ├── locale/
      │   └── messages.ja.yaml   # 翻訳ファイル
      └── template/
          ├── admin/             # 管理画面テンプレート
          └── default/           # フロントテンプレート
```

### composer.json

`type` と `extra.code` が必須。

```json
{
  "name": "ec-cube/salesreport42",
  "version": "4.3.0",
  "description": "売上集計プラグイン",
  "type": "eccube-plugin",
  "require": {
    "ec-cube/plugin-installer": "^2.0"
  },
  "extra": {
    "code": "SalesReport42",
    "id": null
  }
}
```

- `extra.code`: プラグインコード（PascalCase）。名前空間 `Plugin\{code}` と一致させる
- `extra.id`: EC-CUBEオーナーズストアのプラグインID（ストア非公開なら `null`）

### PluginManager

`AbstractPluginManager` を継承し、ライフサイクルフックを実装する。

```php
namespace Plugin\{Code};

use Eccube\Plugin\AbstractPluginManager;
use Psr\Container\ContainerInterface;

class PluginManager extends AbstractPluginManager
{
    public function install(array $meta, ContainerInterface $container)
    {
        // インストール時の処理
    }

    public function update(array $meta, ContainerInterface $container)
    {
        // バージョンアップ時にマイグレーション実行
        $em = $container->get('doctrine')->getManager();
        $this->migration($em->getConnection(), $meta['code']);
    }

    public function enable(array $meta, ContainerInterface $container)
    {
        // 有効化時の処理（ページ登録等）
    }

    public function disable(array $meta, ContainerInterface $container)
    {
        // 無効化時の処理
        // マイグレーションを巻き戻す場合:
        // $em = $container->get('doctrine')->getManager();
        // $this->migration($em->getConnection(), $meta['code'], '0');
    }

    public function uninstall(array $meta, ContainerInterface $container)
    {
        // アンインストール時の処理（ページ削除等）
    }
}
```

### ライフサイクル順序

| 操作 | 呼び出し順 |
|------|-----------|
| インストール＆有効化 | `install()` -> `enable()` |
| 無効化 | `disable()` |
| 再有効化 | `enable()` |
| 無効化＆アンインストール | `disable()` -> `uninstall()` |
| バージョンアップ | `update()` |

### migration() ヘルパー

`AbstractPluginManager` が提供する `migration()` メソッドで、`DoctrineMigrations/` 配下のマイグレーションを実行できる。

```php
// 最新まで適用
$this->migration($connection, $meta['code']);

// 全てロールバック
$this->migration($connection, $meta['code'], '0');
```

マイグレーションファイルの配置先は `app/Plugin/{Code}/DoctrineMigrations/`。基本的な書き方は [migration.md](migration.md) を参照。

## コントローラーとルーティング

### 管理画面コントローラー

```php
namespace Plugin\ChatworkApi\Controller\Admin;

use Eccube\Controller\AbstractController;
use Plugin\ChatworkApi\Form\Type\Admin\ConfigType;
use Plugin\ChatworkApi\Repository\ConfigRepository;
use Sensio\Bundle\FrameworkExtraBundle\Configuration\Template;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;

class ConfigController extends AbstractController
{
    protected $configRepository;

    public function __construct(ConfigRepository $configRepository)
    {
        $this->configRepository = $configRepository;
    }

    /**
     * @Route("/%eccube_admin_route%/chatwork_api/config", name="chatwork_api_admin_config")
     * @Template("@ChatworkApi/admin/config.twig")
     */
    public function index(Request $request)
    {
        $Config = $this->configRepository->get();
        $form = $this->createForm(ConfigType::class, $Config);

        $form->handleRequest($request);
        if ($form->isSubmitted() && $form->isValid()) {
            $this->entityManager->flush();
            $this->addSuccess('保存しました。', 'admin');
            return $this->redirectToRoute('chatwork_api_admin_config');
        }

        return [
            'form' => $form->createView(),
        ];
    }
}
```

### テンプレート配置ルール

| 画面 | ルートパス | `@Template` 記法 |
|------|-----------|-----------------|
| 管理画面 | `Resource/template/admin/` | `@{Code}/admin/...` |
| フロント | `Resource/template/default/` | `@{Code}/default/...` または `{Code}/Resource/template/default/...` |

### 管理画面URL

管理画面のURLは `/%eccube_admin_route%/` プレフィックスを使用する。これにより環境変数 `ECCUBE_ADMIN_ROUTE` の値に自動追従する。

## 管理画面ナビゲーション（Nav）

`EccubeNav` インターフェースを実装し、管理画面サイドメニューに項目を追加する。

```php
namespace Plugin\FaqManager;

use Eccube\Common\EccubeNav;

class Nav implements EccubeNav
{
    public static function getNav()
    {
        return [
            'FaqManager' => [
                'name' => 'faq_manager.admin.nav.001',  // 翻訳キー
                'icon' => 'fa-question',                  // Font Awesome アイコン
                'children' => [
                    'faq_manager_faq' => [
                        'id' => 'admin_faq_manager_faq',
                        'url' => 'admin_faq_manager_faq',   // ルート名
                        'name' => 'faq_manager.admin.nav.002',
                    ],
                    'faq_manager_new' => [
                        'id' => 'admin_faq_manager_new',
                        'url' => 'admin_faq_manager_new',
                        'name' => 'faq_manager.admin.nav.005',
                    ],
                ],
            ],
        ];
    }
}
```

- `name` は翻訳キー（`Resource/locale/messages.ja.yaml` で定義）
- `icon` は Font Awesome のクラス名
- `url` は `@Route` の `name` と一致させる

## イベント（EventSubscriber）

### テンプレートイベント

既存テンプレートにスニペットを挿入したり、テンプレート変数を操作する。

```php
namespace Plugin\OrderInquiry;

use Eccube\Event\TemplateEvent;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

class Event implements EventSubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [
            'Mypage/history.twig' => 'onHistoryDetail',
            'Contact/index.twig'  => 'onContactIndex',
        ];
    }

    public function onHistoryDetail(TemplateEvent $event): void
    {
        // スニペット（部分テンプレート）を追加
        $event->addSnippet('@OrderInquiry/default/Mypage/history.twig');
    }

    public function onContactIndex(TemplateEvent $event): void
    {
        // テンプレート変数を操作
        $data = $event->getParameter('data');
        $data['extra_field'] = 'value';
        $event->setParameter('data', $data);
    }
}
```

`TemplateEvent` の主なメソッド:

| メソッド | 用途 |
|---------|------|
| `addSnippet($twig)` | テンプレートの末尾にスニペットを挿入 |
| `setParameter($key, $value)` | テンプレート変数を設定・上書き |
| `getParameter($key)` | テンプレート変数を取得 |
| `addAsset($css_or_js)` | CSS/JSアセットを追加 |

### EC-CUBEイベント

メール送信や注文処理など、コアのビジネスロジックにフックする。

```php
namespace Plugin\ChatworkApi;

use Eccube\Event\EccubeEvents;
use Eccube\Event\EventArgs;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

class Event implements EventSubscriberInterface
{
    public static function getSubscribedEvents()
    {
        return [
            EccubeEvents::MAIL_CONTACT => 'onMailSend',
            EccubeEvents::MAIL_ORDER   => 'onMailSend',
        ];
    }

    public function onMailSend(EventArgs $event)
    {
        $message = $event->getArgument('message');
        // 処理
    }
}
```

利用可能なイベント定数は `Eccube\Event\EccubeEvents` クラスに定義されている。

## エンティティ

### プラグイン独自エンティティ

テーブル名に `plg_` プレフィックスを使用し、`class_exists` ガードで囲む。

```php
namespace Plugin\ChatworkApi\Entity;

use Doctrine\ORM\Mapping as ORM;

if (!class_exists('\Plugin\ChatworkApi\Entity\Config', false)) {
    /**
     * @ORM\Table(name="plg_chatwork_api_config")
     * @ORM\Entity(repositoryClass="Plugin\ChatworkApi\Repository\ConfigRepository")
     */
    class Config
    {
        /**
         * @ORM\Column(name="id", type="integer", options={"unsigned":true})
         * @ORM\Id
         * @ORM\GeneratedValue(strategy="IDENTITY")
         */
        private $id;

        /**
         * @ORM\Column(name="api_key", type="string", length=255, nullable=true)
         */
        private $apiKey;

        // getter / setter ...
    }
}
```

- `plg_` プレフィックス: コアテーブル（`dtb_` / `mtb_`）との衝突を防ぐ
- `class_exists` ガード: プロキシ生成時のクラス重複エラーを防ぐ
- プラグイン独自エンティティでは `AbstractEntity` 継承や `@InheritanceType` は不要

### エンティティ拡張（Trait）

コアエンティティにカラムを追加する場合は Trait を使用する。詳細は [entity-customization.md](entity-customization.md) を参照。

プラグインでの Trait の例:

```php
namespace Plugin\EntityExtension\Entity;

use Doctrine\ORM\Mapping as ORM;
use Eccube\Annotation\EntityExtension;

/**
 * @EntityExtension("Eccube\Entity\Customer")
 */
trait CustomerSortNoTrait
{
    /**
     * @ORM\Column(type="smallint", nullable=true)
     */
    public $sort_no;
}
```

## フォーム

### 独自フォームタイプ（ConfigType パターン）

プラグイン設定画面など、プラグイン固有のフォームを定義する。

```php
namespace Plugin\ChatworkApi\Form\Type\Admin;

use Plugin\ChatworkApi\Entity\Config;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\Extension\Core\Type\TextType;
use Symfony\Component\Form\Extension\Core\Type\CheckboxType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolver;

class ConfigType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options)
    {
        $builder
            ->add('api_key', TextType::class, [
                'label' => 'APIキー',
                'required' => true,
            ])
            ->add('enabled', CheckboxType::class, [
                'label' => false,
                'required' => false,
            ]);
    }

    public function configureOptions(OptionsResolver $resolver)
    {
        $resolver->setDefaults([
            'data_class' => Config::class,
        ]);
    }
}
```

### 既存フォーム拡張

コアのフォーム（CustomerType, ProductType 等）にフィールドを追加する場合は FormExtension を使用する。詳細は [form-extension.md](form-extension.md) を参照。

## リポジトリ

`AbstractRepository` を継承し、`ManagerRegistry` をコンストラクタで受け取る。

```php
namespace Plugin\ChatworkApi\Repository;

use Doctrine\Persistence\ManagerRegistry;
use Eccube\Repository\AbstractRepository;
use Plugin\ChatworkApi\Entity\Config;

class ConfigRepository extends AbstractRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Config::class);
    }

    public function get($id = 1)
    {
        $Config = $this->find($id);
        if (null === $Config) {
            $Config = new Config();
            $this->_em->persist($Config);
            $this->_em->flush();
        }
        return $Config;
    }
}
```

設定系エンティティでは、レコードが存在しない場合に自動生成する `get()` パターンがよく使われる。

## マイグレーション

プラグイン固有のマイグレーションは `app/Plugin/{Code}/DoctrineMigrations/` に配置する。`PluginManager::migration()` メソッドで実行される。

```php
namespace Plugin\MigrationSample\DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20181101012712 extends AbstractMigration
{
    public function up(Schema $schema): void
    {
        $Table = $schema->getTable('dtb_base_info');
        if ($Table->hasColumn('migration_sample')) {
            $this->addSql('UPDATE dtb_base_info SET migration_sample = ? WHERE id = 1', ['up']);
        }
    }

    public function down(Schema $schema): void
    {
        $Table = $schema->getTable('dtb_base_info');
        if ($Table->hasColumn('migration_sample')) {
            $this->addSql('UPDATE dtb_base_info SET migration_sample = ? WHERE id = 1', ['down']);
        }
    }
}
```

マイグレーションの基本的な書き方は [migration.md](migration.md) を参照。

## TwigBlock

`EccubeTwigBlock` インターフェースを実装し、Twigブロックを登録する。

```php
namespace Plugin\FaqManager;

use Eccube\Common\EccubeTwigBlock;

class TwigBlock implements EccubeTwigBlock
{
    public static function getTwigBlock()
    {
        return [
            // '@{Code}/path/to/block.twig',
        ];
    }
}
```

管理画面のブロック管理に独自ブロックを追加する場合に使用する。

## PurchaseFlow 拡張

`@CartFlow` / `@ShoppingFlow` / `@OrderFlow` アノテーションで対象フローを指定し、プロセッサーを追加する。

```php
namespace Plugin\PurchaseProcessors\Service\PurchaseFlow\Processor;

use Eccube\Annotation\CartFlow;
use Eccube\Annotation\OrderFlow;
use Eccube\Annotation\ShoppingFlow;
use Eccube\Entity\ItemInterface;
use Eccube\Service\PurchaseFlow\InvalidItemException;
use Eccube\Service\PurchaseFlow\ItemValidator;
use Eccube\Service\PurchaseFlow\PurchaseContext;

/**
 * @CartFlow
 * @ShoppingFlow
 * @OrderFlow
 */
class SaleLimitOneValidator extends ItemValidator
{
    protected function validate(ItemInterface $item, PurchaseContext $context)
    {
        if (!$item->isProduct()) {
            return;
        }
        if (1 < $item->getQuantity()) {
            $this->throwInvalidItemException('商品は１個しか購入できません。');
        }
    }

    protected function handle(ItemInterface $item, PurchaseContext $context)
    {
        $item->setQuantity(1);
    }
}
```

### 追加可能なプロセッサー

| クラス/インターフェース | 用途 |
|---------------------|------|
| `ItemPreprocessor` | 商品前処理 |
| `ItemValidator` | 商品バリデーション（`validate` + `handle`） |
| `ItemHolderPreprocessor` | カート/注文全体の前処理 |
| `ItemHolderValidator` | カート/注文全体のバリデーション |
| `DiscountProcessor` | 割引処理 |
| `PurchaseProcessor` | 購入完了処理（`prepare` + `commit` + `rollback`） |

### フロー指定アノテーション

| アノテーション | 対象フロー |
|-------------|----------|
| `@CartFlow` | カート画面 |
| `@ShoppingFlow` | 購入フロー |
| `@OrderFlow` | 管理画面の受注編集 |

## クエリカスタマイズ

`WhereCustomizer` を継承し、検索クエリに条件を追加する。

```php
namespace Plugin\QueryCustomize\Repository;

use Eccube\Doctrine\Query\WhereClause;
use Eccube\Doctrine\Query\WhereCustomizer;
use Eccube\Repository\QueryKey;

class AdminCustomerCustomizer extends WhereCustomizer
{
    protected function createStatements($params, $queryKey)
    {
        return [WhereClause::gte('c.buy_times', ':buy_times', ['buy_times' => 1])];
    }

    public function getQueryKey()
    {
        return QueryKey::CUSTOMER_SEARCH;
    }
}
```

### 主なQueryKey定数

| 定数 | 検索対象 |
|------|---------|
| `QueryKey::CUSTOMER_SEARCH` | 管理画面 > 会員検索 |
| `QueryKey::PRODUCT_SEARCH` | 商品検索 |
| `QueryKey::ORDER_SEARCH` | 受注検索 |

### WhereClause メソッド

| メソッド | SQL条件 |
|---------|--------|
| `WhereClause::eq($col, $param, $values)` | `=` |
| `WhereClause::neq(...)` | `!=` |
| `WhereClause::gte(...)` | `>=` |
| `WhereClause::lte(...)` | `<=` |
| `WhereClause::like(...)` | `LIKE` |
| `WhereClause::in(...)` | `IN` |
| `WhereClause::isNull(...)` | `IS NULL` |
| `WhereClause::isNotNull(...)` | `IS NOT NULL` |

## 多言語対応

`Resource/locale/messages.ja.yaml` に翻訳キーを定義する。

```yaml
# Plugin/{Code}/Resource/locale/messages.ja.yaml
chatwork_api.admin.nav.001: Chatwork API
chatwork_api.admin.nav.002: Chatwork API設定
```

- キーは `{plugin_code_snake}.{area}.{category}.{seq}` の命名規則を推奨
- Twigでは `{{ 'key'|trans }}` で参照
- PHPでは `$translator->trans('key')` で参照

## services.yaml

`Resource/config/services.yaml` でサービス定義やパラメータを設定できる。

```yaml
# Plugin/{Code}/Resource/config/services.yaml
parameters:
    sales_report_product_maximum_display: 20
```

`Plugin\{Code}\` 名前空間はautowiringが有効なため、通常はサービス登録不要。パラメータ定義やサードパーティライブラリの設定が必要な場合に使用する。

## チェックリスト

1. [ ] `composer.json` に `type: eccube-plugin` と `extra.code` を設定
2. [ ] 名前空間が `Plugin\{Code}\` で統一されている
3. [ ] エンティティに `plg_` プレフィックス + `class_exists` ガード
4. [ ] 管理画面URLに `/%eccube_admin_route%/` を使用
5. [ ] `PluginManager` でライフサイクル管理（マイグレーション実行等）
6. [ ] 翻訳キーを `messages.ja.yaml` に定義
7. [ ] `Nav` で管理画面メニューを追加（管理画面がある場合）
8. [ ] テンプレートの配置パスが規約どおり
9. [ ] テスト環境でインストール/有効化/無効化/アンインストールの全サイクル確認
