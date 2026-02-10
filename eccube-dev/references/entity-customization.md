# エンティティカスタマイズ

公式: https://doc4.ec-cube.net/customize_entity

## Trait によるエンティティ拡張

既存エンティティにカラムを追加する標準的な方法。

```php
<?php
namespace Customize\Entity;

use Doctrine\ORM\Mapping as ORM;
use Eccube\Annotation\EntityExtension;

/**
 * @EntityExtension("Eccube\Entity\{TargetEntity}")
 */
trait {TargetEntity}Trait
{
    /**
     * @ORM\Column(name="column_name", type="{type}", nullable=true)
     */
    private $propertyName;

    public function getPropertyName()
    {
        return $this->propertyName;
    }

    public function setPropertyName($value): self
    {
        $this->propertyName = $value;
        return $this;
    }
}
```

- `@EntityExtension` の引数にTrait適用先のFQCN を指定
- setter は fluent interface (`return $this`) で実装
- ファイル配置: `app/Customize/Entity/{TargetEntity}Trait.php`

### 拡張可能なコアエンティティ

`Customer`, `Order`, `OrderItem`, `Product`, `ProductClass`, `Shipping`, `Category`, `CartItem` 等

### ORM型リファレンス

| Doctrine型 | PHP型 | 用途 |
|-----------|------|------|
| `string` | string | VARCHAR(255) |
| `text` | string | 長いテキスト |
| `integer` | int | 整数 |
| `smallint` | int | 小さい整数 |
| `boolean` | bool | 真偽値（TINYINT） |
| `datetime` | \DateTime | 日時 |
| `date` | \DateTime | 日付のみ |
| `decimal` | string | 金額等（precision, scale指定） |
| `json` | array | JSON配列・オブジェクト |

### decimal型の例（金額）

```php
/**
 * @ORM\Column(type="decimal", precision=12, scale=2, nullable=true, options={"default":0})
 */
private $customPrice;
```

### リレーション定義

#### ManyToOne

```php
/**
 * @ORM\ManyToOne(targetEntity="Eccube\Entity\Master\Sex")
 * @ORM\JoinColumn(name="sex_id", referencedColumnName="id")
 */
private $Sex;
```

#### OneToMany

```php
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;

/**
 * @ORM\OneToMany(targetEntity="Customize\Entity\ChildEntity", mappedBy="parent")
 */
private $children;

// TraitではコンストラクタでCollectionを初期化できない → getterでnullチェック
public function getChildren(): Collection
{
    return $this->children ?? new ArrayCollection();
}
```

#### ManyToMany

```php
/**
 * @ORM\ManyToMany(targetEntity="Eccube\Entity\Category")
 * @ORM\JoinTable(name="dtb_custom_category",
 *     joinColumns={@ORM\JoinColumn(name="custom_id", referencedColumnName="id")},
 *     inverseJoinColumns={@ORM\JoinColumn(name="category_id", referencedColumnName="id")}
 * )
 */
private $Categories;
```

## @FormAppend による簡易フォーム追加

Traitプロパティに直接アノテーションを付けて管理画面フォームを自動生成。

```php
use Eccube\Annotation\FormAppend;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @ORM\Column(type="string", nullable=true)
 * @FormAppend(
 *     auto_render=true,
 *     type="\Symfony\Component\Form\Extension\Core\Type\TextType",
 *     options={"required": false, "label": "表示ラベル"}
 * )
 * @Assert\Length(max=255)
 */
private $fieldName;
```

`auto_render=true` で管理画面に自動描画される。複雑なフォームが必要な場合は FormExtension を使う（[form-extension.md](form-extension.md) 参照）。

## スタンドアロンエンティティ（新規テーブル）

```php
<?php
namespace Customize\Entity;

use Doctrine\ORM\Mapping as ORM;
use Eccube\Entity\AbstractEntity;

/**
 * @ORM\Table(name="dtb_custom_table")
 * @ORM\Entity(repositoryClass="Customize\Repository\CustomTableRepository")
 * @ORM\InheritanceType("SINGLE_TABLE")
 * @ORM\DiscriminatorColumn(name="discriminator_type", type="string", length=255)
 * @ORM\HasLifecycleCallbacks()
 */
class CustomTable extends AbstractEntity
{
    /**
     * @ORM\Column(name="id", type="integer", options={"unsigned":true})
     * @ORM\Id
     * @ORM\GeneratedValue(strategy="IDENTITY")
     */
    private $id;

    // getter / setter ...
}
```

- `AbstractEntity` を継承（EC-CUBEの基本機能を取得）
- `@InheritanceType("SINGLE_TABLE")` と `@DiscriminatorColumn` はEC-CUBEのプロキシ機構に必要
- テーブル名: データ系 `dtb_`、マスタ系 `mtb_`
- リポジトリクラスを別途作成する場合は `repositoryClass` に指定

### リポジトリの作成

```php
<?php
namespace Customize\Repository;

use Customize\Entity\CustomTable;
use Eccube\Repository\AbstractRepository;
use Symfony\Bridge\Doctrine\RegistryInterface;

class CustomTableRepository extends AbstractRepository
{
    public function __construct(RegistryInterface $registry)
    {
        parent::__construct($registry, CustomTable::class);
    }
}
```

## Trait変更後のデプロイ手順

```bash
# 1. プロキシ再生成
bin/console eccube:generate:proxies

# 2. キャッシュクリア
bin/console cache:clear --no-warmup

# 3. スキーマ反映
bin/console doctrine:schema:update --dump-sql  # 確認
bin/console doctrine:schema:update --force      # 実行
```
