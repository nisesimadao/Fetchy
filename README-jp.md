# Fetchy

![SwiftUI](https://img.shields.io/badge/SwiftUI-5-orange.svg)
![Node.js](https://img.shields.io/badge/Node.js-16+-green.svg)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg)

Fetchy は、Node.js バックエンドと `yt-dlp` を利用した **モダンな iOS
向け動画ダウンローダー** です。

動画処理の負荷をすべてサーバー側に任せる設計により、iOS
アプリは軽量・高速・省バッテリーで快適に動作します。

------------------------------------------------------------------------

## 🖼️ スクリーンショット

`<img width="195" alt="Shared Extension Download Screen" src="https://github.com/user-attachments/assets/91a0d835-5c03-4bfd-89ca-1e6bf27692b4" />`{=html}
`<img width="195" alt="Shared Extension Download Progress Screen" src="https://github.com/user-attachments/assets/73d8e366-b294-497f-aeb9-9c8c8ddec4aa" />`{=html}
`<img width="195" alt="Download Screen" src="https://github.com/user-attachments/assets/11280d76-10f2-4ca0-955f-2c8a6bdccab4" />`{=html}
`<img width="195" alt="History Screen" src="https://github.com/user-attachments/assets/a3e662be-aeb6-4668-99e1-edaaf4c78307" />`{=html}

------------------------------------------------------------------------

## ✨ 主な機能

### 🔧 サーバーサイド処理

`yt-dlp` の実行をサーバー側で処理することで、iOS デバイスの CPU
使用率やバッテリー消費を大幅に抑えます。

### 🌐 幅広いサイトに対応

`yt-dlp`
を利用しているため、数百種類以上の動画サイトからダウンロード可能です。

### 📊 リアルタイム進捗表示

アプリはバックエンドにポーリングを行い、ダウンロード進捗をリアルタイムで表示します。

### 🎛️ 豊富なダウンロード設定

画質、フォーマット、メタデータ埋め込みなどを自由にカスタマイズできます。

### 📱 SwiftUIによるネイティブUI

SwiftUI を使用した、シンプルでモダンなインターフェースを採用しています。

### 📤 Share Extension 対応

Safari
など他アプリの共有メニューから、直接動画ダウンロードを開始できます。

### ⚡ 非同期ジョブ設計

ジョブベースの構造により、アプリの操作性を損なわずスムーズに処理を行います。

------------------------------------------------------------------------

## 🏗️ アーキテクチャ

Fetchy は、UI と動画処理を分離した **クライアント・サーバー構成**
を採用しています。

### 処理の流れ

1.  **iOSアプリ（クライアント）**
    -   動画URLを入力、または共有メニューから取得
2.  **APIリクエスト送信**
    -   「ダウンロード開始」リクエストを Node.js サーバーへ送信
3.  **Node.js API（サーバー）**
    -   ユニークなジョブIDを発行
    -   `yt-dlp` をバックグラウンドで実行
    -   ジョブIDをアプリへ返却
4.  **進捗確認**
    -   アプリが `/api/status/:jobId` を定期的にポーリング
    -   進捗情報を取得してUIを更新
5.  **ファイル取得**
    -   処理完了後、`/api/download/:jobId`
        から動画ファイルをダウンロード

------------------------------------------------------------------------

## 🛠️ 技術スタック

### クライアント（iOS）

-   SwiftUI

### サーバー（バックエンド）

-   Node.js
-   Express.js

### コア依存ライブラリ

-   `yt-dlp`

------------------------------------------------------------------------

## 🚀 セットアップ方法

Fetchy を動作させるには、**バックエンドサーバー** と **iOSアプリ**
の両方をセットアップする必要があります。

------------------------------------------------------------------------

### 1️⃣ バックエンドサーバー（fetchy-api）

``` bash
cd fetchy-api
npm install
npm start
```

------------------------------------------------------------------------

### 2️⃣ iOSアプリ（Fetchy）

#### 手順

``` bash
open Fetchy.xcodeproj
```

`Fetchy/Shared/Managers/APIClient.swift` を開き、`baseURL`
を自分のサーバーURLへ変更してください。

``` swift
private let baseURL = "https://your-backend-service-url.com"
```

------------------------------------------------------------------------

## 📄 ライセンス

本プロジェクトは **MIT License** のもとで公開されています。 詳細は
[LICENSE](LICENSE) を参照してください。