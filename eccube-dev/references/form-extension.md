# フォーム拡張（FormExtension）

`@FormAppend` では対応できない高度なフォームカスタマイズに使用する。

## 基本構造

```php
<?php
namespace Customize\Form\Extension\Admin;

use Eccube\Form\Type\Admin\{TargetType};
use Symfony\Component\Form\AbstractTypeExtension;
use Symfony\Component\Form\FormBuilderInterface;

class {Target}TypeExtension extends AbstractTypeExtension
{
    public static function getExtendedTypes(): iterable
    {
        yield {TargetType}::class;
    }

    public function buildForm(FormBuilderInterface $builder, array $options)
    {
        $builder->add('field_name', FieldType::class, [
            'label' => 'ラベル',
            'required' => false,
            'eccube_form_options' => [
                'auto_render' => true,
            ],
        ]);
    }
}
```

- 管理画面用: `app/Customize/Form/Extension/Admin/` に配置
- フロント用: `app/Customize/Form/Extension/` に配置
- `getExtendedTypes()` は `yield` で拡張対象を返す

## 主要な拡張対象フォーム

| フォームクラス | 画面 |
|-------------|------|
| `Eccube\Form\Type\Admin\CustomerType` | 管理画面 > 会員編集 |
| `Eccube\Form\Type\Admin\ProductType` | 管理画面 > 商品編集 |
| `Eccube\Form\Type\Admin\OrderType` | 管理画面 > 受注編集 |
| `Eccube\Form\Type\Admin\NewsType` | 管理画面 > 新着情報 |
| `Eccube\Form\Type\Admin\ShippingType` | 管理画面 > 配送編集 |
| `Eccube\Form\Type\AddCartType` | フロント > カート追加 |
| `Eccube\Form\Type\SearchProductType` | フロント > 商品検索 |
| `Eccube\Form\Type\Front\EntryType` | フロント > 会員登録 |
| `Eccube\Form\Type\Front\ContactType` | フロント > お問い合わせ |

## eccube_form_options

管理画面のフォーム自動描画を制御するオプション。

```php
'eccube_form_options' => [
    'auto_render' => true,          // 管理画面に自動表示
    'form_theme' => 'Form/custom.twig', // カスタムテーマ（省略可）
    'style_class' => 'ec-select',   // CSSクラス（省略可）
],
```

`auto_render => true` で管理画面の編集フォームに自動追加される。テンプレートの編集は不要。

## フィールドタイプ別の例

### テキスト入力

```php
use Symfony\Component\Form\Extension\Core\Type\TextType;

$builder->add('custom_field', TextType::class, [
    'label' => 'カスタムフィールド',
    'required' => false,
    'attr' => ['placeholder' => '入力してください'],
    'eccube_form_options' => ['auto_render' => true],
]);
```

### 選択肢（ドロップダウン）

```php
use Symfony\Component\Form\Extension\Core\Type\ChoiceType;

$builder->add('status', ChoiceType::class, [
    'label' => 'ステータス',
    'choices' => [
        '有効' => 1,
        '無効' => 0,
    ],
    'expanded' => false,  // false=ドロップダウン, true=ラジオボタン
    'eccube_form_options' => ['auto_render' => true],
]);
```

### チェックボックス（複数選択）

```php
$builder->add('options', ChoiceType::class, [
    'label' => 'オプション',
    'choices' => ['A' => 1, 'B' => 2, 'C' => 3],
    'multiple' => true,
    'expanded' => true,   // チェックボックス表示
    'required' => false,
    'eccube_form_options' => ['auto_render' => true],
]);
```

### 日時入力

```php
use Symfony\Component\Form\Extension\Core\Type\DateTimeType;

$builder->add('start_date', DateTimeType::class, [
    'label' => '開始日時',
    'required' => false,
    'input' => 'datetime',
    'widget' => 'single_text',
    'eccube_form_options' => ['auto_render' => true],
]);
```

## イベントリスナーによるバリデーション

フィールド間の依存関係チェック等、複雑なバリデーションに使用。

```php
use Symfony\Component\Form\FormEvents;
use Symfony\Component\Form\FormEvent;
use Symfony\Component\Form\FormError;

$builder->addEventListener(FormEvents::POST_SUBMIT, function (FormEvent $event) {
    $form = $event->getForm();
    $data = $event->getData();

    if ($data->getFieldA() && !$data->getFieldB()) {
        $form->get('field_b')->addError(
            new FormError('フィールドAが設定されている場合、フィールドBは必須です。')
        );
    }
});
```

## DI（依存性注入）

EccubeConfig、リポジトリ等を注入して動的な選択肢を構築できる。

```php
use Eccube\Common\EccubeConfig;

class CustomTypeExtension extends AbstractTypeExtension
{
    private $eccubeConfig;

    public function __construct(EccubeConfig $eccubeConfig)
    {
        $this->eccubeConfig = $eccubeConfig;
    }

    public function buildForm(FormBuilderInterface $builder, array $options)
    {
        $configValue = $this->eccubeConfig['parameter_key'];
        // ...
    }
}
```

`Customize\` 名前空間はautowiring有効のため、サービス登録不要で自動的にDIされる。
