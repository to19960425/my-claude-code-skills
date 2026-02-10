# マイグレーション

`app/DoctrineMigrations/` にマイグレーションファイルを配置する。

## 基本構造

```php
<?php
namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version{YYYYMMDDHHmmss} extends AbstractMigration
{
    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE dtb_customer ADD custom_column VARCHAR(255) DEFAULT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE dtb_customer DROP COLUMN custom_column');
    }
}
```

- クラス名: `Version` + タイムスタンプ（YYYYMMDDHHmmss）
- `up()`: マイグレーション適用
- `down()`: ロールバック
- `$this->addSql()` でSQL実行

## コマンド

```bash
# マイグレーション状態確認
bin/console doctrine:migrations:status

# 実行
bin/console doctrine:migrations:migrate

# ロールバック（1つ前に戻す）
bin/console doctrine:migrations:migrate prev
```

## パターン: カラム追加

```php
public function up(Schema $schema): void
{
    $this->addSql('ALTER TABLE dtb_product ADD custom_flag TINYINT(1) DEFAULT 0 NOT NULL');
    $this->addSql('ALTER TABLE dtb_product ADD custom_note TEXT DEFAULT NULL');
}

public function down(Schema $schema): void
{
    $this->addSql('ALTER TABLE dtb_product DROP COLUMN custom_flag');
    $this->addSql('ALTER TABLE dtb_product DROP COLUMN custom_note');
}
```

## パターン: データ移行（べき等性を確保）

```php
public function up(Schema $schema): void
{
    // 重複チェックしてからINSERT
    $exists = $this->connection->fetchOne(
        "SELECT COUNT(*) FROM dtb_csv WHERE field_name = 'custom_field'"
    );

    if ($exists == 0) {
        $this->addSql("INSERT INTO dtb_csv (...) VALUES (...)");
    }
}
```

`$this->connection->fetchOne()` でスカラー値を取得し、条件付き実行。同じマイグレーションが複数回実行されても安全にする。

## パターン: テーブル作成

```php
public function up(Schema $schema): void
{
    $this->addSql('CREATE TABLE dtb_custom_table (
        id INT UNSIGNED AUTO_INCREMENT NOT NULL,
        name VARCHAR(255) NOT NULL,
        sort_no INT NOT NULL DEFAULT 0,
        create_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        update_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        discriminator_type VARCHAR(255) NOT NULL,
        PRIMARY KEY(id)
    ) DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci ENGINE = InnoDB');
}

public function down(Schema $schema): void
{
    $this->addSql('DROP TABLE dtb_custom_table');
}
```

EC-CUBEのテーブルには `create_date`, `update_date`, `discriminator_type` カラムを含めるのが慣例。

## 方法: マイグレーションを使わず手動SQL

マイグレーションファイルを作成せず直接SQLを実行する場合は、実行SQLをドキュメントに記録しておくこと。

```bash
# スキーマ差分を自動生成SQLで確認
bin/console doctrine:schema:update --dump-sql

# 直接適用
bin/console doctrine:schema:update --force
```
