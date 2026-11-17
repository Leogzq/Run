# iOS 重建测试版 0.2

目标设备 iPhone 15 Pro Max，iOS 26.1。界面依据用户 APK 的布局与配色重新实现。

包含开始/我的首页、地图绘制、闭合路线、本地保存/编辑/删除、原 APK WGS84 路线 JSON 导入导出、速度和循环模拟参数、开发定位服务连接、配对记录导入、公开 NDEF 标签读取。
定位使用 Waypoint 的开发服务连接代码，运行时需要本机配对记录、开发者模式、LocalDevVPN、Wi-Fi 和开发支持镜像。首次配对通过电脑上的 idevice_pair 完成，选择 RPPairing。配对凭据仅在设备本地保存，勿提交到仓库。

构建前运行 bash scripts/fetch-idevice.sh，然后运行 ./build-unsigned.sh。未签名 IPA 在 build/。GitHub Actions 自动执行这两个步骤。安装需要兼容的签名方案，NFC 读取需要签名配置支持 NFC entitlement。

仍待完成/验证：
- iPhone 15 Pro Max iOS 26.1 真机连接、定位更新与恢复。
- 原版步频模式、共享路线服务、隐私共享、路线录制、后台持续运行。
- Android NFC Intent 的等效 iOS 实现。
- 仅含百度坐标的旧路线文件转换。
- 原地图为百度地图，本版使用 Apple MapKit。
- 尚未完成像素级截图对比，当前为原布局结构与颜色的重建。
编译成功不等同上述功能已完成或真机验证通过。

源码及许可证位于本仓库，开源组件见 THIRD_PARTY_NOTICES.md。
