// SideInstaller-Bridging-Header.h
//
// Swift 侧用 GCDWebServer（企业安装本地回环服务）的桥接头。
// GCDWebServer.h 只 import Request/Response 基类，DataResponse
// 和 FileResponse 要另外 import，Swift 才能在 handler 里构造它们。
// 上游源码在 ios-app/GCDWebServer/（vendored，未改）。

#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerFileResponse.h"
#import "GCDWebServerDataRequest.h"
#import "GCDWebServerFileRequest.h"  // C21-1：WebDAV PUT 流式上传要用。
