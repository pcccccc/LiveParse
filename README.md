# LiveParse ![GitHub release](https://img.shields.io/badge/release-v1.2.7-green.svg)

## 介绍： 

解析 Bilibili/Douyu/Huya/NeteaseCC/YY/KuaiShou/Douyin 直播相关内容的 Swift Package（当前为纯 JS 插件解析模式）。

## 功能：

获取直播分类、对应分类主播列表、主播信息、直播源地址、模糊搜索、通过分享链接识别主播信息。

> 当前默认运行模式：**仅 JS 插件模式**（`enableJSPlugins = true`，`pluginFallbackToSwiftImplementation = false`）。

## 纯 JS 测试进度（2026-02-23）

- 已跑通：`bilibili`（16/16）、`douyin`（14/14，需手动填 Cookie）、`cc`（10/10）、`yy`（9/9）、`huya`、`douyu`、`ks`
- 已启用纯 JS 断言的平台测试：`huya`、`douyu`、`ks`、`bilibili`、`douyin`、`cc`、`yy`
- YouTube 已移除

## Swift Package Manager：
```swift
dependencies: [
    .package(url: "https://github.com/pcccccc/LiveParse.git", .upToNextMajor(from:"1.2.7"))
]
```
## 使用：

获取Bilibili所有分类列表：

```swift
do {
    let list = try await Bilibili.getCategoryList()
}catch let error {
    print(error)
}
```

通过抖音分享码获取直播地址：

```swift
do {
    try await Douyin.getRequestHeaders()
    let liveInfo = try await Douyin.getRoomInfoFromShareCode(shareCode: "2- #在抖音，记录美好生活#【交个朋友直播间】正在直播，来和我一起支持Ta吧。复制下方链接，打开【抖音】，直接观看直播！ https://v.douyin.com/i8rhQQ2t/ 2@4.com 12/18")
    let liveQualitys = try await Douyin.getPlayArgs(roomId: liveInfo.roomId, userId: nil)
    print(liveQualitys.debugDescription)
}catch let error {
    print(error)
}
```

通过抖音分享码获取弹幕信息：

```swift
class ViewModel: ObservableObject {
    
    var socketConnection: WebSocketConnection?
    
    func getDanmuInfo() {
        Task {

            let room = try await Douyin.getRoomInfoFromShareCode(shareCode: "2- #在抖音，记录美好生活#【中标标院】正在直播，来和我一起支持Ta吧。复制下方链接，打开【抖音】，直接观看直播！ https://v.douyin.com/i8gXjg1D/ 4@0.com 08/22")
            print(try await Douyin.getPlayArgs(roomId: room.roomId, userId: room.userId))
            let danmuArgs = try await Douyin.getDanmukuArgs(roomId: room.roomId)
            socketConnection = WebSocketConnection(parameters: danmuArgs.0, headers: danmuArgs.1, liveType: room.liveType)
            socketConnection!.delegate = self
            socketConnection!.connect()
//            //断开
//            socketConnection!.disconnect()
        }
    }
}

extension ViewModel: WebSocketConnectionDelegate {
    func webSocketDidConnect() {//连接成功
        
    }

    func webSocketDidDisconnect(error: Error?) {//连接失败
        
    }
    /// 接收到消息后的回调(String)
    func webSocketDidReceiveMessage(text: String, color: UInt32) {
        print("弹幕：==>\(text)" )
    }
}
```

## 各平台功能概览：

|  平台   | 分类列表 | 房间列表 | 地址解析 | 搜索 | 分享码/链接 | 弹幕（评论） |
| :-----: | :------: | :------: | :------: | :--: | :---------: | :----------: |
| B站直播 |    ✅     |    ✅     |    ✅     |  ✅   |      ✅      |      ✅       |
|  斗鱼   |    ✅     |    ✅     |    ✅     |  ✅   |      ✅      |      ✅       |
|  虎牙   |    ✅     |    ✅     |    ✅     |  ✅   |      ✅      |      ✅       |
|  抖音   |    ✅     |    ✅     |    ✅     |  ✅   |      ✅      |      ✅       |
|  快手   |    ✅     |    ✅     |    ✅     |  ✅   |      ✅      |      ❌       |
|   YY    |    ✅     |    ✅     |    ✅     |  ✅   |      ✅      |      ❌       |
| 网易CC  |    ✅     |    ✅     |    ✅     |  ✅   |      ✅      |      ❌       |




## 参考及引用：

[dart_simple_live](https://github.com/xiaoyaocz/dart_simple_live/) 

[iceking2nd/real-url](https://github.com/iceking2nd/real-url) `虎牙解析参考`

[wbt5/real-url](https://github.com/wbt5/real-url)

[ihmily/DouyinLiveRecorder](https://github.com/ihmily/DouyinLiveRecorder)

[wbt5/real-url](https://github.com/wbt5/real-url)

## 声明：

本项目的所有功能都是基于互联网上公开的资料开发，无任何破解、逆向工程等行为。

本项目仅用于学习交流编程技术，严禁将本项目用于商业目的。如有任何商业行为，均与本项目无关。

如果本项目存在侵犯您的合法权益的情况，请及时与开发者联系，开发者将会及时删除有关内容。
