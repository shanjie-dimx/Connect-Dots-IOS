# 同色连线 · iOS

原生 SwiftUI 版本，玩法、规则和 20 个关卡与网页版完全一致。支持 iPhone 和 iPad，iOS 16 及以上。

## 在 Xcode 中运行

1. 用 Xcode 15 或更新版本打开 `ios/ColorLink.xcodeproj`
2. 选中 `ColorLink` target → Signing & Capabilities，选择你的 Team（真机运行需要；模拟器不需要）
   - 如需上架，把 Bundle Identifier `com.simplegamesforiq.colorlink` 改成你自己的
3. 选择模拟器或已连接的 iPhone，按 `⌘R`

## 目录

```
ios/
├── ColorLink.xcodeproj     Xcode 工程（App + UI 测试）
├── ColorLink/
│   ├── Core/               规则引擎，从 src/game.js、src/geometry.js 移植，不依赖 UIKit/SwiftUI
│   │   └── Levels.swift    由 tools/export-ios-levels.js 从 src/levels.js 生成，勿手改
│   ├── App/                SwiftUI 界面：关卡列表、棋盘绘制与手势、过关弹窗、进度保存
│   └── Assets.xcassets     App 图标（源文件 ios/icon.svg）
├── ColorLinkUITests/       在模拟器里用真实拖拽操作 App
├── Tests/ColorLinkCoreTests  规则引擎单元测试（含用参考解逐关通关）
└── Package.swift           仅用于 `swift test` 跑规则引擎测试
```

## 测试

```bash
cd ios
swift test                                  # 规则引擎，macOS 或 Linux 都能跑
xcodebuild test -project ColorLink.xcodeproj -scheme ColorLink \
  -destination 'platform=iOS Simulator,name=iPhone 16'   # UI 测试
```

`.github/workflows/ios.yml` 会在 macOS 上自动跑以上两项，并把模拟器截图作为 artifact 上传。

## 修改关卡

`npm run generate` 会同时重新生成网页版和 iOS 版的关卡；只想同步 iOS 用 `npm run generate:ios`。
