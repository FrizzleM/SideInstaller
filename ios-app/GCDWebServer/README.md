# GCDWebServer（vendored，未改上游源码）

来源：https://github.com/swisspol/GCDWebServer ，commit `c6d118f`
（master，podspec 标 3.5.4），许可证 BSD（见同目录 LICENSE）。

文件：上游 `GCDWebServer/Core/`、`Requests/`、`Responses/` 全部 28 个
`.h`/`.m` 原样拷进本目录（摊平一层，因为 GCDWebServerPrivate.h
用裸文件名互相 import，分三层目录放 Xcode 找不到头文件）。
`diff` 对上游同名文件为空，即未改一行上游代码。

用途：企业安装的本地回环 HTTP 服务（LocalHTTPInstallServer）。
轻松签实证用的就是 GCDWebServer：localhost 双栈、动态端口、
Range/206、keep-alive、正确的 Content-Length/Content-Type。
不用 CocoaPods/SPM（离线构建、避免额外依赖解析），直接 vendor。

注意：不要手改这里的文件；要升级就整批重拷上游同 commit。
