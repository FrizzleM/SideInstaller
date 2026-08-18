import Foundation

/// Simplified Chinese copy, on the same contract as `spanishStrings`. Settings
/// paths and "tap" follow Apple's own zh-Hans wording, prose uses full-width
/// punctuation, "revoke" is the PKI term 吊销, and the second person is 你.

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

    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "你需要一个配对文件",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "本机运行 iOS %@。只有 iOS %@ 能与自身配对，因此你需要在电脑上用 jitterbugpair 或 pymobiledevice3 生成配对文件，再导入到 App 中。SideInstaller 会逐步引导你。",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "使用你的 Apple ID 登录",
    "Don't worry, these are stored locally":
        "别担心，这些信息只保存在本机",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "保存在本机的钥匙串中，仅在登录时发送给 Apple。",
    "Continue": "继续",
    "Set this up later": "稍后设置",
    "Add Apple ID": "添加 Apple ID",
    "Edit Apple ID": "编辑 Apple ID",
    "Save": "存储",
    "Enter the password again to save this Apple ID.": "请再次输入密码以保存此 Apple ID。",
    "Account": "账户",
    "In use": "使用中",
    "Edit": "编辑",
    "Remove": "移除",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "尚未保存 Apple ID。添加一个后，SideInstaller 每次登录都会使用它。",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "保存在本机的钥匙串中，仅在登录时发送给 Apple。左滑某一行可修改其密码或将其移除。",
    "Remove this Apple ID?": "移除此 Apple ID？",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "“%@”及其保存的密码将从本机删除。你的 Apple 账户不会有任何变化。",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "本机钥匙串拒绝保存该密码（错误 %d），因此密码只会保留到 SideInstaller 退出为止。",
    "No Apple ID saved. Add one in Settings › Account.": "尚未保存 Apple ID。请在“设置 › 账户”中添加一个。",

    "Add your Apple ID": "添加你的 Apple ID",
    "Open Settings with the gear at the top right.": "点按右上角的齿轮打开设置。",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "在“账户”一节中点按“添加 Apple ID”，然后输入你的电子邮件和密码。",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "工具",

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
    "Importing…": "正在导入…",
    "Replace": "更换",
    "or": "或",
    "Paste a download link": "粘贴下载链接",
    "Downloading… %d%%": "正在下载… %d%%",
    "iOS %@ required": "需要 iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "此 iPhone 运行的是 iOS %@，SideInstaller 无法在该版本上安装。请在 设置 › 通用 › 软件更新 中更新到 iOS %@ 或更高版本。",
    "Wi-Fi required": "需要 Wi-Fi",
    "Pairing code": "配对码",
    "Type this into the prompt in Settings.":
        "将它输入到 设置 中的提示框内。",
    "Install stopped": "安装已停止",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ 已安装。完成上面的信任步骤即可打开。",
    "Action needed": "需要操作",
    "Step %@ of %@": "第 %@ 步，共 %@ 步",
    "Show all steps": "显示所有步骤",
    "Show fewer steps": "收起步骤",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "需要 LocalDevVPN",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "安装 LocalDevVPN 并连接。安装过程走它的隧道。",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "连接 LocalDevVPN 以扫描和安装。写入走它的隧道。",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "连接 LocalDevVPN。和这里的其他功能一样，模拟也走它的隧道。",
    "LocalDevVPN isn't connected. Connect it, then try again.": "LocalDevVPN 未连接。请先连接，然后重试。",
    "Connect LocalDevVPN": "连接 LocalDevVPN",
    "Install LocalDevVPN from the App Store and open it.": "从 App Store 安装 LocalDevVPN 并打开它。",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "如果你所在的地区无法访问 GitHub，请使用同时能代理流量的 VPN：iOS 一次只能运行一个 VPN，仅限本地的隧道会让 SideStore 无法下载。",

    // MARK: - Install steps

    "Connect the VPN": "连接 VPN",
    "Get pairing file": "获取配对文件",
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
    "%d supported app installed": "已安装 %d 个受支持的应用",
    "%d supported apps installed": "已安装 %d 个受支持的应用",
    "No supported apps found": "未找到受支持的应用",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "请先安装 SideStore、StikDebug 或 Feather 之类的应用，然后重新扫描。",
    "Install pairing": "安装配对文件",
    "Pairing file ready. You can export it or install it into an app below.":
        "配对文件已就绪。你可以导出，或安装到下面的某个应用中。",
    "Pairing file installed into %@.": "配对文件已安装到 %@。",

    // Importing a pairing file (iOS 26 and below)

    "Import pairing file": "导入配对文件",
    "How do I make one?": "怎么生成？",
    "imported pairing file": "已导入配对文件",
    "No pairing file yet — tap “Import pairing file” first.": "还没有配对文件 — 请先点按“导入配对文件”。",
    "Pairing file missing — import it first.": "缺少配对文件 — 请先导入。",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ 不是配对文件。请选择电脑生成的文件 — 包含本机配对记录的 .mobiledevicepairing 或 .plist。",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "iOS %@ 无法自行生成配对文件，那需要 iOS %@。请在“配对文件”中导入一个在电脑上生成的文件，然后重试。",

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
    "%d certificate(s)": "%d 个证书",
    "No certificates": "没有证书",
    "This Apple ID has no development certificates to revoke.":
        "此 Apple ID 没有可吊销的开发证书。",
    "Expired": "已过期",
    "Expires %@": "%@ 到期",
    "Unnamed certificate": "未命名的证书",
    "This certificate has no serial number, so it can't be revoked.":
        "此证书没有序列号，因此无法吊销。",

    // MARK: - Location tab

    "Location spoofing": "位置模拟",
    "Not simulating": "未模拟",
    "Simulated": "模拟位置",
    "Pick a place": "选择地点",
    "Search for a place": "搜索地点",
    "Nothing found for “%@”.": "找不到“%@”的结果。",
    "Set location": "设置位置",
    "Setting": "正在设置",
    "Reset to real location": "恢复真实位置",
    "Location set to %@.": "位置已设为 %@。",
    "Location reset. The device is using its own again.": "位置已恢复。设备重新使用自己的位置。",
    "That isn't a valid coordinate.": "该坐标无效。",
    "Location session closed — set it up again.": "位置会话已关闭 — 请重新设置。",
    "Downloading %@ failed (HTTP %d).": "下载 %@ 失败（HTTP %d）。",
    "Couldn't build the download URL for %@.": "无法为 %@ 构建下载链接。",

    // MARK: - Entitlements tab

    "Entitlements": "权限",
    "Load apps": "加载应用",
    "%d App ID": "%d 个 App ID",
    "%d App IDs": "%d 个 App ID",
    "No App IDs": "没有 App ID",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "此 Apple ID 还没有注册任何应用。请先用 SideInstaller 安装一个，然后再回来。",
    "Memory and performance": "内存与性能",
    "Other free capabilities": "其他免费能力",
    "Beta": "测试版",
    "Recommended": "推荐",
    "Select all": "全选",
    "None": "全不选",
    "Enable %d selected": "启用所选的 %d 项",
    "Asking Apple": "正在询问 Apple",
    "%d of %d enabled": "已启用 %d/%d",
    "Install the app again for these to take effect.": "重新安装应用后这些权限才会生效。",

    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "侧载应用",
    "Reading the device": "正在读取设备",
    "%d app": "%d 个应用",
    "%d apps": "%d 个应用",
    "%d app needs refreshing": "%d 个应用需要续签",
    "%d apps need refreshing": "%d 个应用需要续签",
    "No sideloaded apps": "没有侧载应用",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "这台设备上没有任何应用是用描述文件安装的。App Store 的应用不会过期，因此不会列在这里。",
    "No matching profile": "没有匹配的描述文件",
    "Expires today": "今天过期",
    "Expires tomorrow": "明天过期",
    "Expires in %d days — %@": "%d 天后过期 — %@",
    "Expired %@": "已于 %@ 过期",
    "Unused profiles": "未使用的描述文件",
    "Issued to App IDs no installed app is running on.":
        "签发给了没有任何已安装应用在使用的 App ID。",
    "Older profiles": "较旧的描述文件",
    "Bundle identifier": "Bundle 标识符",
    "App ID": "App ID",
    "Version": "版本",
    "Profile name": "描述文件名称",
    "Team": "团队",
    "Team ID": "团队 ID",
    "Issued": "签发时间",
    "Profile UUID": "描述文件 UUID",
    "Capabilities": "功能",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "通配符 App ID：它涵盖其下的任意 bundle id，因此无法携带针对单个应用的功能。",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "设备上没有这个 App ID 的描述文件。该应用可能已经无法启动——重新安装一次即可解决。",

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
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub 正在限制此网络的请求频率 —— 它没有被屏蔽，限制会自动解除。请在%@重试。",
    "GitHub answered HTTP %d%@": "GitHub 返回了 HTTP %d%@",
    "couldn't reach GitHub: %@": "无法连接到 GitHub：%@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "GitHub 的响应不是发行版信息（%@）—— 此网络上的某个环节可能替换了它。",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "以 %@ 为名下载到的文件不是 IPA —— 此网络上的某个环节可能返回了一个网页，或者传输中断了。",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "该链接返回 HTTP %d — 它不是直接下载链接，或者需要登录。",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "双重认证验证已取消。",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID 或密码不正确。请检查你的 Apple 账户电子邮件和密码，然后重试。",
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
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ 不是有效的 IPA —— 多半是下载时返回了一个错误页面，或者复制中途中断。请替换它，然后再次轻点“安装”。",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ 不是 IPA。请选择 .ipa 文件本身；如果看起来没错，可能是下载时保存的是错误页面，或者中途中断了。",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "还没有导入任何 IPA。请轻点“导入 .ipa”并选择一个文件。",
    "Couldn't import %@: %@": "无法导入 %@：%@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "SideInstaller 无法下载该链接。请粘贴 .ipa 的完整 https:// 下载地址。",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "该链接返回的不是 IPA。它必须直接下载文件——只是指向 .ipa 的网页，或先要求登录的网页，到这里都只是一个网页。",
    "Couldn't download that link: %@": "无法下载该链接：%@",
    "there's nothing to download for a custom IPA — import one first":
        "自定义 IPA 没有可下载的内容 —— 请先导入一个文件",
    "your app": "你的应用",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple 不会为此 Apple ID 签发签名证书：它报告已经存在一个证书，或者仍有一个申请在处理中（错误 7460）。SideInstaller 无法复用已有的证书，因此停止了操作，而不是替换它。请参见上面的步骤。",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "无法将此 iPhone%@ 注册到你 Apple ID 的开发者团队，因此 Apple 不会签发描述文件。%@ —— 请参见上面的步骤。",
    "Connect to Wi-Fi": "连接 Wi-Fi",
    "Open Settings › Wi-Fi and join a network.": "打开 设置 › Wi-Fi 并加入一个网络。",
    "Then come back here — this continues automatically.": "然后回到这里 —— 接下来会自动继续。",
    "Tap Connect so the toggle turns on.": "轻点 Connect，让开关打开。",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "保持 Wi-Fi 开启，然后回到这里 —— 接下来会自动继续。",
    "Get LocalDevVPN": "获取 LocalDevVPN",
    "Import an .ipa first": "请先导入一个 .ipa",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "轻点上方的“导入 .ipa”并选择文件 —— 文件可以放在“文件”App 能访问的任何位置，包括 iCloud 云盘或 U 盘。",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "或者在该按钮下方粘贴直接下载链接，SideInstaller 会自己把 .ipa 取回来。",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "或者打开“文件”App，长按该 .ipa，点按“共享”并选择 SideInstaller——这样文件不经过选择器就能交过来。",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "也可以把它复制到 文件 › 我的 iPhone › SideInstaller，SideInstaller 同样能找到。",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "在 GitHub 被封锁的地区，这就是可行的办法：在任何设备上取得 IPA，带过来，然后在这里安装。",
    "Pair this iPhone in Settings": "在 设置 中配对此 iPhone",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "打开 设置 应用，然后进入 隐私与安全性 › 开发者模式。",
    "Tap “Pair with SideInstaller”.": "轻点“与 SideInstaller 配对”。",
    "Enter your iPhone’s passcode if it asks for it.": "如果系统要求，请输入你的 iPhone 密码。",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "回到 SideInstaller，查看它显示给你的验证码，然后把相同的验证码输入到 设置 中的提示框内。",
    "A signing certificate already exists": "已存在签名证书",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Apple 返回错误 7460：此 Apple ID 已有一个 iOS 开发证书，或者有一个申请仍在处理中。",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideInstaller 无法复用它。当证书是在别处签发时就会这样——另一台设备上的 AltStore、SideStore、Sideloadly 或 Xcode——所需的私钥并不在这台 iPhone 上。",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "使用上方的“吊销并重试”，或在“工具”标签页中打开“证书”，点按“加载证书”，在那里吊销它。",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "吊销不可撤回：所有已用该证书签名的 App 都将无法启动，在所有设备上都是如此。",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "或者，在上面用另一个（或备用的）Apple ID 登录，然后再次轻点“安装”。",

    // MARK: - Guide cards

    // Guide: import a pairing file

    "Import a pairing file": "导入配对文件",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@ 是 iPhone 能与自身配对的第一个版本。在本机上，配对文件必须在电脑上生成。",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "在 Mac、Windows 电脑或 Linux 上插上本机，选择信任该电脑，然后运行 jitterbugpair（或“pymobiledevice3 lockdown pair”）。",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "通过隔空投送、iCloud 云盘或数据线，把生成的文件（.mobiledevicepairing 或 .plist）传到本机。",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "回到这里，点按“导入配对文件”并选中它。之后的步骤与 iOS %@ 上完全一致。",
    "Get jitterbugpair": "获取 jitterbugpair",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "已存在证书",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple 不会为此 Apple ID 签发第二个签名证书。吊销已有的那个可以让安装继续——但此操作无法撤回。",
    "Loading certificates": "正在加载证书",
    "Revoke and retry": "吊销并重试",
    "Which certificate should be revoked?": "要吊销哪个证书？",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple 报告此 Apple ID 上有证书，但列表返回为空。可能是仍在处理中的申请——请等几分钟后再次点按“安装”。",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "所有已用你选择的证书签名的 App 都将无法启动，在所有设备上都是如此——包括通过 AltStore、SideStore 或电脑安装的 App。此操作无法撤回。安装会紧接着重试。",
    " (expired)": "（已过期）",

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
    "Wrong device IP": "设备 IP 有误",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "“设置 › 高级 › 设备 IP”中填的地址是本机已有的地址，另一端没有可连接的对象。",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "改回默认值 10.7.0.1。在 LocalDevVPN 中，它是“设置 › Device IP”里的值，而不是主界面上显示的地址——那是隧道自己的一端。",
    "If you changed LocalDevVPN's addresses, put its Device IP here, and make sure its Tunnel IP and subnet mask cover it.":
        "若你改过 LocalDevVPN 的地址，请在此填入它的 Device IP，并确认它的 Tunnel IP 与子网掩码覆盖该地址。",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "配对这台 iPhone 需要它：SideInstaller 会在本地网络上广播自己，供“设置”发现。",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "请连接到 Wi-Fi 网络。配对这台 iPhone 需要它——SideInstaller 必须能在本地网络上被找到。",

    // MARK: - About

    "About": "关于",
    "Version %@ (%@)": "版本 %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller 直接把 SideStore 和 LiveContainer 装到你的 iPhone 上，全程不需要电脑。",

    "Links": "链接",
    "Source code": "源代码",
    "Support the project": "支持这个项目",

    "Special thanks": "特别感谢",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "感谢 idevice——SideInstaller 正是通过这个库与你的 iPhone 通信的。没有它，这一切都不会存在。",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "感谢一路以来的支持，以及发现了那些因此得到修复的问题。",

    "Built with": "基于以下项目",
    "The open source work this app is built on:": "这个应用所依赖的开源成果：",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "配对、隧道以及安装本身，由 jkcoxson 开发，MIT 许可证。",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Apple ID 登录、证书与本机签名，由 nab138 开发，MIT 许可证。",
    "The sideloading app this installs for you.":
        "本应用为你安装的侧载应用。",
    "Runs sideloaded apps without spending an app slot on each one.":
        "运行侧载应用，而不必为每个应用占用一个名额。",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "位置模拟所挂载的开发者磁盘映像，由 doronz88 镜像存放。",

    "Where to get it": "从哪里获取",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "只有官方安装页面和代码仓库上的构建版本才是我发布的。任何人都可以 fork 源代码，加入窃取凭据的代码，再用同样的名称和图标发布——所以不要把你的 Apple ID 交给来自其他地方的副本。",
    "Install page": "安装页面",
    "Terms": "条款",
]
