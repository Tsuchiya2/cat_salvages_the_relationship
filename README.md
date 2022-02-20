# ReLINE 【"猫さん"】

https://www.cat-reline.com/

!["猫さん"](/readme-images/cat.jpg)

## サービス概要

休止状態に陥ったLINEグループに対して、ある期間休止状態が経過すると、不定期に交流のきっかけになるようなメッセージを"猫さん"が送信してくれます。そのLINE通知をきっかけに交流の発生を促してくれるサービスになります。

## 使用例のイメージ

![使用例のイメージ](/readme-images/example.jpg)

## 使用開始に関連する画面

| Webトップページ | QRコード(Web) | LINEアプリ |
|:---:|:---:|:---:|
| ![Webトップページ](/readme-images/web-top-page.jpg) | ![QRコード](/readme-images/qr-code.jpg) |  ![LINEページ](/readme-images/line-page.jpg) |
|Webのトップ画面です。キャラクター画像の下にある`友だち追加`ボタンで友だち追加画面に遷移します。|`友だち追加`ボタンを押すと、Webの場合はこちらのページに遷移します。|スマートフォンで`友だち追加`ボタンを押す、もしくは`QRコード`をスマートフォンで読み取った場合はこちらのようなページに遷移します。|

## 使用技術

## バックエンド

- Ruby 3.0.2
- Rails 6.1.4.1
- RSpec 3.10.1
- LINE Messaging API
- Heroku Scheduler

## 機能における主要な Gem

- line-bot-api（LINE Messageing API）
- sorcery（管理運営のログイン）
- pundit（認可）

## ER図

![ER図](/readme-images/reline-er.jpg)

## フロントエンド

- Bootstrap 5
- JavaScript

## インフラ図

![インフラ図](/readme-images/reline-infra.jpg)

## カバレッジ（ model / system )

![カバレッジ](/readme-images/coverage.jpg)

## 苦労した部分

エンドポイント(URL)が１つに対して、LINE Messaging API で発生する多数のイベント(リクエスト)処理をコードに書き起こすのに苦労しました。Fat Controllerにならないように、関連する記述をlinesフォルダに切り出してみたり、Rubocopの制約の中でコードを書き直してみたりと試行錯誤を行いながら開発を進めてきました。


実際にエンジニアとして働いている方々から意見をいただいたり、書籍「パーフェクトRuby on Rails」などの学習を経て、Fat Modelにならないように注意しながら、Rubocopの規約にも引っかからないようにしながら以下の図のような処理を実装しています。

![LINE Botのリアクション](/readme-images/line-bot-reaction.jpg)

## 執筆したQiita記事

- [【LINE×Rails】Rails初学者も作れるLINE Botアプリケーション](https://qiita.com/Tsuchiy_2/items/4e8c038f58c23b57b0be)

## セットアップ

- Ruby：3.0.2
- Rails：6.1.4.1

＊ `master.key` は開発責任者が管理しております。開発に加わる際はご連絡ください。

```bash
# クローン後
$ bundle install
$ bin/rails db:create
$ bin/rails db:migrate
$ bin/rails db:seed
$ bin/rails s

# ルーティング確認
$ bin/rails routes
```
