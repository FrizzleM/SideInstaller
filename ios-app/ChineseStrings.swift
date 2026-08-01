import Foundation

/// Simplified Chinese (zh-Hans) copy, keyed by the English source string every
/// call site passes to `L(_:)` — same contract as the other tables: same keys,
/// same placeholders, product and third-party UI names left in English.
///
/// A few notes specific to Chinese. iOS Settings path labels use Apple's own
/// zh-Hans wording (设置 › 通用 › 软件更新, 隐私与安全性 › 开发者模式, VPN 与设备管理,
/// 开发者 App…) so the text matches what the user actually sees in the system UI.
/// "tap" is 轻点 to match iOS, and prose uses full-width punctuation (。，：（）
/// "") the way Apple's Chinese localizations do. Nouns don't inflect for number,
/// so the singular and plural app-count strings share one wording. Note that 设置
/// covers both the Settings app (in paths) and generic "setup" ("Finish setup" →
/// 完成设置); context keeps them apart. Certificate "revoke" is 吊销 (the PKI term),
/// not 撤销. Second person is the warmer 你 throughout, to fit an indie tool.
let chineseStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "取消",
    "Copy": "复制",
    "Email": "电子邮件",
    "Password": "密码",
    "Install": "安装",
    "Installing": "正在安装",
    "Installed": "已安装",
    "Something went wrong": "出了点问题",
    "an app by Frizzle": "由 Frizzle 打造的应用",
    "device": "设备",

    // MARK: - Welcome

    "I have accepted the": "我已接受",
    "Start": "开始",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "配对",
    "Certificates": "证书",
    "Two-Factor Code": "双重认证验证码",
    "6-digit code": "6 位验证码",
    "Submit": "提交",
    "Enter the code Apple just sent to your trusted device.":
        "请输入 Apple 刚刚发送到你受信任设备的验证码。",

    // MARK: - Install tab

    "Tunnel connected": "隧道已连接",
    "Tunnel off": "隧道已关闭",
    "Update available": "有可用更新",
    "SideInstaller %@ is available — you're on %@.":
        "SideInstaller %@ 已发布 —— 你当前使用的是 %@。",
    "Get the latest version": "获取最新版本",
    "Release": "渠道",
    "Reinstall": "重新安装",
    "Install %@": "安装 %@",
    "Custom .ipa": "自定义 .ipa",
    "Import .ipa": "导入 .ipa",
    "Replace": "更换",
    "iOS %@ required": "需要 iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "此 iPhone 运行的是 iOS %@，SideInstaller 无法在该版本上安装。请在 设置 › 通用 › 软件更新 中更新到 iOS %@ 或更高版本。",
    "Wi-Fi required": "需要 Wi-Fi",
    "Connect to a Wi-Fi network. The loopback tunnel and the install run over it.":
        "请连接到 Wi-Fi 网络。回环隧道和安装过程都通过它运行。",
    "Loopback VPN required": "需要回环隧道 VPN",
    "Turn on a loopback VPN — LocalDevVPN, ClashMi, or any app that tunnels to this iPhone. The install runs over it.":
        "开启一个回环隧道 VPN —— LocalDevVPN、ClashMi 或任何能向本机建立隧道的应用都可以。安装过程通过它运行。",
    "Pairing code": "配对码",
    "Type this into the prompt in Settings.":
        "将它输入到 设置 中的提示框内。",
    "Install stopped": "安装已停止",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ 已安装。完成上面的信任步骤即可打开。",
    "Action needed": "需要操作",

    // MARK: - Install steps

    "Connect the VPN": "连接 VPN",
    "Pair with this iPhone": "与此 iPhone 配对",
    "Open the device link": "打开设备连接",
    "Sign in to Apple ID": "登录 Apple ID",
    "Download %@": "下载 %@",
    "Use your imported IPA": "使用已导入的 IPA",
    "Sign the app": "为应用签名",
    "Finish setup": "完成设置",

    // MARK: - Pairing tab

    "Pairing file ready": "配对文件已就绪",
    "No pairing file": "没有配对文件",
    "Pairing file": "配对文件",
    "Pairing…": "正在配对…",
    "Regenerate": "重新生成",
    "Generate pairing file": "生成配对文件",
    "Export pairing file": "导出配对文件",
    "Pair in Settings": "在 设置 中配对",
    "Install into an app": "安装到应用",
    "Scanning": "正在扫描",
    "Rescan apps": "重新扫描应用",
    "Scan installed apps": "扫描已安装的应用",
    "Connect to Wi-Fi to scan and install. The loopback tunnel runs over it.":
        "连接 Wi-Fi 以扫描和安装。回环隧道通过它运行。",
    "Turn on a loopback VPN to scan and install. The write runs over its tunnel.":
        "开启一个回环隧道 VPN 以扫描和安装。写入操作通过它的隧道进行。",
    "%d supported app installed": "已安装 %d 个受支持的应用",
    "%d supported apps installed": "已安装 %d 个受支持的应用",
    "No supported apps found": "未找到受支持的应用",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "请先安装 SideStore、StikDebug 或 Feather 之类的应用，然后重新扫描。",
    "Install pairing": "安装配对文件",
    "Pairing file ready. You can export it or install it into an app below.":
        "配对文件已就绪。你可以导出，或安装到下面的某个应用中。",
    "Pairing file installed into %@.": "配对文件已安装到 %@。",

    // MARK: - Pairing service status

    "not paired": "未配对",
    "connected": "已连接",
    "requesting Local Network…": "正在请求本地网络权限…",
    "Local Network denied": "本地网络权限被拒绝",
    "waiting for device…": "正在等待设备…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "正在广播 —— 打开 设置 › 隐私与安全性 › 开发者模式",
    "enter PIN %@ in Settings": "在 设置 中输入 PIN 码 %@",
    "paired: %@ (%dB)": "已配对：%@（%d B）",
    "failed: empty pairing file": "失败：配对文件为空",
    "failed: %@": "失败：%@",
    "Pairing is already in progress.": "配对已在进行中。",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "本地网络权限已关闭。请在 设置 › SideInstaller › 本地网络 中开启，然后重试。",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "配对生成了一个空文件。请确认你已同意配对请求，然后重试。",

    // MARK: - Certificates tab

    "Revoke this certificate?": "吊销此证书？",
    "Revoke": "吊销",
    "Revoking": "正在吊销",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "“%@”将被吊销。已用它签名的应用将无法在任何设备上启动。此操作无法撤销。",
    "Refreshing": "正在刷新",
    "Signing in": "正在登录",
    "Refresh": "刷新",
    "Load certificates": "加载证书",
    "%d of 3 certificates": "%d / 3 个证书",
    "No certificates": "没有证书",
    "This Apple ID has no development certificates to revoke.":
        "此 Apple ID 没有可吊销的开发证书。",
    "Expired": "已过期",
    "Expires %@": "%@ 到期",
    "Unnamed certificate": "未命名的证书",
    "Enter your Apple ID email and password first.":
        "请先输入你的 Apple ID 电子邮件和密码。",
    "This certificate has no serial number, so it can't be revoked.":
        "此证书没有序列号，因此无法吊销。",

    // MARK: - Settings

    "Settings": "设置",
    "Done": "完成",
    "Language": "语言",
    "App language": "应用语言",
    "Auto": "自动",
    "Downloaded IPAs": "已下载的 IPA",
    "%@ used": "已用 %@",
    "imported": "已导入",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "还没有已下载的 IPA。你从“安装”标签页安装的 IPA 会缓存在这里。",
    "Downloaded %@": "下载于 %@",
    "Added %@": "添加于 %@",
    "Delete this download?": "删除此下载项？",
    "Delete": "删除",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "“%@”（%@）将被移除。你随时可以从“安装”标签页重新下载。",
    "Couldn't delete %@: %@": "无法删除 %@：%@",
    "Server": "服务器",
    "Custom…": "自定义…",
    "Server URL": "服务器 URL",
    "Anisette Server": "Anisette 服务器",
    "Device IP": "设备 IP",
    "Advanced": "高级",
    "Clear": "清除",
    "Activity Log (%d)": "活动日志（%d）",

    // MARK: - Release channels & downloads

    "Stable": "稳定版",
    "Nightly": "Nightly",
    "couldn't find the IPA in the %@ %@ release":
        "在 %@ 渠道的 %@ 发行版中找不到 IPA 文件",
    "%@ has no %@ release right now": "%@ 目前没有任何 %@ 发行版",
    "bad asset URL": "下载资源的 URL 无效",

    // MARK: - Engine failures

    "Enter your Apple ID email + password.":
        "请输入你的 Apple ID 电子邮件和密码。",
    "Two-factor verification was cancelled.": "双重认证验证已取消。",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID 或密码不正确。请检查你的 Apple 账户电子邮件和密码，然后重试。",
    "Apple ID sign-in failed: %@": "Apple ID 登录失败：%@",
    "Apple ID sign-in failed on %@. Last error: %@":
        "在 %@ 上登录 Apple ID 失败。最后的错误：%@",
    "the anisette server": "anisette 服务器",
    "all %d anisette servers": "全部 %d 个 anisette 服务器",
    "Not signed in.": "尚未登录。",
    "No SideStore IPA downloaded.": "尚未下载 SideStore 的 IPA。",
    "Signing failed: %@": "签名失败：%@",
    "No signed bundle to install.": "没有可安装的已签名程序包。",
    "Device link dropped — reconnect.":
        "与设备的连接已断开 —— 请重新连接。",
    "Pairing didn't finish — no pairing file yet.":
        "配对未完成 —— 还没有配对文件。",
    "Pairing file missing — pairing must run first.":
        "缺少配对文件 —— 必须先进行配对。",
    "Pairing file missing — generate it first.":
        "缺少配对文件 —— 请先生成。",
    "No pairing file yet — tap “Generate pairing file” first.":
        "还没有配对文件 —— 请先轻点“生成配对文件”。",
    "%@ isn't installed yet — install must run first.":
        "%@ 尚未安装 —— 必须先进行安装。",
    "Wi-Fi is off. Connect to a Wi-Fi network, then try again.":
        "Wi-Fi 已关闭。请连接到 Wi-Fi 网络，然后重试。",
    "No loopback VPN is connected. Turn one on, then try again.":
        "尚未连接任何回环隧道 VPN。请开启一个，然后重试。",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ 不是有效的 IPA —— 多半是下载时返回了一个错误页面，或者复制中途中断。请替换它，然后再次轻点“安装”。",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ 不是 IPA。请选择 .ipa 文件本身；如果看起来没错，可能是下载时保存的是错误页面，或者中途中断了。",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "还没有导入任何 IPA。请轻点“导入 .ipa”并选择一个文件。",
    "Couldn't import %@: %@": "无法导入 %@：%@",
    "there's nothing to download for a custom IPA — import one first":
        "自定义 IPA 没有可下载的内容 —— 请先导入一个文件",
    "your app": "你的应用",
    "Apple allows only 3 signing certificates per Apple ID and this one already has 3, so a new one can't be made. Open the Certificates tab, tap “Load certificates”, and revoke an old or expired one to free a slot — then tap Install again. See the steps above.":
        "Apple 规定每个 Apple ID 最多只能有 3 个签名证书，而此 Apple ID 已经有 3 个了，因此无法再创建新的。请打开“证书”标签页，轻点“加载证书”，然后吊销一个旧的或已过期的证书来腾出名额 —— 之后再次轻点“安装”。请参见上面的步骤。",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "无法将此 iPhone%@ 注册到你 Apple ID 的开发者团队，因此 Apple 不会签发描述文件。%@ —— 请参见上面的步骤。",

    // MARK: - Guide cards

    "Connect to Wi-Fi": "连接 Wi-Fi",
    "Open Settings › Wi-Fi and join a network.":
        "打开 设置 › Wi-Fi 并加入一个网络。",
    "The loopback tunnel — and the whole install — run over Wi-Fi.":
        "回环隧道 —— 以及整个安装过程 —— 都通过 Wi-Fi 运行。",
    "Then come back here — this continues automatically.":
        "然后回到这里 —— 接下来会自动继续。",

    "Turn on a loopback VPN": "开启回环隧道 VPN",
    "Open a VPN app that tunnels to this iPhone — LocalDevVPN, ClashMi, or another. Any of them works.":
        "打开一个能向本机建立隧道的 VPN 应用 —— LocalDevVPN、ClashMi 或其他应用，任选一个即可。",
    "If GitHub is blocked where you are, pick one that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "如果你所在地区无法访问 GitHub，请选一个同时能代理流量的应用：iOS 同一时间只允许一个 VPN，因此仅本地的隧道会让你无法下载 SideStore。",
    "Tap Connect so the toggle turns on.": "轻点 Connect，让开关打开。",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "保持 Wi-Fi 开启，然后回到这里 —— 接下来会自动继续。",
    "Get LocalDevVPN": "获取 LocalDevVPN",
    "Import an .ipa first": "请先导入一个 .ipa",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "轻点上方的“导入 .ipa”并选择文件 —— 文件可以放在“文件”App 能访问的任何位置，包括 iCloud 云盘或 U 盘。",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "也可以把它复制到 文件 › 我的 iPhone › SideInstaller，SideInstaller 同样能找到。",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "在 GitHub 被封锁的地区，这就是可行的办法：在任何设备上取得 IPA，带过来，然后在这里安装。",

    "Pair this iPhone in Settings": "在 设置 中配对此 iPhone",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "打开 设置 应用，然后进入 隐私与安全性 › 开发者模式。",
    "Tap “Pair with SideInstaller”.": "轻点“与 SideInstaller 配对”。",
    "Enter your iPhone’s passcode if it asks for it.":
        "如果系统要求，请输入你的 iPhone 密码。",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "回到 SideInstaller，查看它显示给你的验证码，然后把相同的验证码输入到 设置 中的提示框内。",

    "Too many signing certificates": "签名证书过多",
    "Apple allows only 3 signing certificates per Apple ID, and this one already has 3 — usually left over from setting up AltStore / SideStore on other devices.":
        "Apple 规定每个 Apple ID 最多只能有 3 个签名证书，而此 Apple ID 已经有 3 个了 —— 通常是之前在其他设备上设置 AltStore / SideStore 时遗留下来的。",
    "Open the Certificates tab at the bottom of the screen, make sure your Apple ID is filled in, and tap “Load certificates”.":
        "打开屏幕底部的“证书”标签页，确认已填写你的 Apple ID，然后轻点“加载证书”。",
    "Tap “Revoke” on an old or expired certificate to free up a slot. Revoking stops apps already signed with that certificate from launching on other devices, so pick one you no longer use.":
        "在一个旧的或已过期的证书上轻点“吊销”，以腾出名额。吊销后，已用该证书签名的应用将无法在其他设备上启动，所以请选择一个你不再使用的证书。",
    "Come back to the Install tab and tap Install again.":
        "回到“安装”标签页，再次轻点“安装”。",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "或者，在上面用另一个（或备用的）Apple ID 登录，然后再次轻点“安装”。",

    "Couldn't register this device": "无法注册此设备",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "你的 Apple ID 已达到注册设备数量的上限。免费账户每年只能注册少量设备，并且在年度重置之前无法移除旧设备。",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "最简单的解决办法：在上面的输入框中填入另一个（或备用的）Apple ID，然后再次轻点“安装”。",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller 无法自动将此 iPhone 添加到你 Apple ID 的开发者团队。再次轻点“安装”通常就能成功 —— Apple 的开发者服务有时会短暂不可用。",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "如果一直失败，请手动添加该设备。它的 UDID 是：",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "把它粘贴到 Apple Developer 门户中的“Register a Device”表单里（这需要付费的 Apple Developer 账户），然后再次轻点“安装”。",
    "Open device list": "打开设备列表",

    "Last step: trust %@": "最后一步：信任 %@",
    "Open Settings › General › VPN & Device Management.":
        "打开 设置 › 通用 › VPN 与设备管理。",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "在“开发者 App”下轻点你的 Apple ID，然后轻点“信任”。",
    "Open %@ from your Home Screen — you're done.":
        "从主屏幕打开 %@ —— 就大功告成了。",

    "Import the certificate into LiveContainer": "将证书导入 LiveContainer",
    "Open LiveContainer from your Home Screen.": "从主屏幕打开 LiveContainer。",
    "Tap the Settings tab.": "轻点 Settings 标签页。",
    "Tap “Import Certificate From SideStore”.":
        "轻点“Import Certificate From SideStore”。",
]
