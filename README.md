# 同色连线 · iPhone App

这是一个 iPhone App，用 Xcode 打开后直接运行。支持 iPhone 和 iPad，iOS 16 及以上。玩法、规则和 20 个关卡与网页版一致。

## 在 iPhone 上运行

1. 用 Xcode 15 或更新版本打开 `ColorLink.xcodeproj`（打开这个文件，不要打开文件夹）
2. 窗口顶部的运行目标选一台 iPhone 模拟器，或插上你的 iPhone
3. 选中 `ColorLink` target → Signing & Capabilities，选择你的 Team（真机需要；模拟器不需要）
   - 如需上架，把 Bundle Identifier `com.simplegamesforiq.colorlink` 改成你自己的
4. 按 `⌘R`。Xcode 会编译 `ColorLink.app` 并装到那台 iPhone 上

## 目录

```
├── ColorLink.xcodeproj     iPhone App 工程。产品是 ColorLink.app
├── ColorLink/
│   ├── App/                SwiftUI 界面：关卡列表、棋盘、手势、过关弹窗、进度
│   ├── Core/               规则和 20 个关卡
│   └── Assets.xcassets     App 图标（源文件 icon.svg）
├── ColorLinkUITests/       在模拟器里用真实拖拽操作 App
├── Tests/ColorLinkCoreTests  规则引擎单元测试，挂在同一个 Xcode 工程里
└── icon.svg
```

## 测试

```bash
xcodebuild test -project ColorLink.xcodeproj -scheme ColorLink \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## 修改关卡

`npm run generate` 会同时重新生成网页版和 iOS 版的关卡；只想同步 iOS 用 `npm run generate:ios`。
