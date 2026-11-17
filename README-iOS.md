# 路线工具 · iOS 原型

根据 Android APK 的界面及功能线索，用 SwiftUI 与 Apple MapKit 重建。要求 iOS 17 或更新版本。支持搜索地点、地图选点、撤销、保存与删除本地路线，以及按速度在地图内回放。地点搜索和底图由 Apple 地图提供。APK 中的 Android 原生库、第三方服务凭据及资源未随工程分发。

## 编译

- 本地有完整 Xcode：打开 `RouteLab.xcodeproj`，选择 RouteLab scheme 和 iOS 模拟器，按 Run。
- 生成未签名 IPA：在装有 Xcode 的 Mac 上运行 `./build-unsigned.sh`，生成 `build/RouteLab-unsigned.ipa`。
- GitHub Actions：将整个工程（包括隐藏的 `.github` 目录）推到有权限的仓库，默认分支为 main 时会自动构建，也可从 Actions 手动运行 **Build unsigned iOS IPA**。从运行页面下载同名构建产物，解压即可得到 IPA。首次推送工作流时，需要允许仓库运行 Actions，并具备创建工作流文件的权限。

未签名 IPA 用于验证封包，无法直接安装到 iPhone。要真机测试，打开 Xcode，在 Signing & Capabilities 选择自己的团队和唯一 Bundle ID，然后选择设备运行。用于分发的 IPA 需要相应签名和配置描述文件。

回放只更新本应用内的地图标记，不替换设备定位。不包含 NFC 模拟、原应用的共享路线服务或历史数据。当前工程尚待完整 Xcode 编译和运行验证。
