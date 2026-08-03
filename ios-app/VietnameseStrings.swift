import Foundation

/// Vietnamese copy, keyed by the English source string every call site passes to
/// `L(_:)` — same contract as the other tables: same keys, same placeholders,
/// product and third-party UI names left in English.
///
/// Two notes specific to Vietnamese. "Cài đặt" is both *Settings* and *install*,
/// so the Install tab is "Cài ứng dụng" to keep it distinct from the Settings
/// sheet and from references to the iOS Settings app. And nouns don't inflect
/// for number, so the singular and plural app-count strings share one wording.
let vietnameseStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "Hủy",
    "Copy": "Sao chép",
    "Email": "Email",
    "Password": "Mật khẩu",
    "Install": "Cài ứng dụng",
    "Installing": "Đang cài đặt",
    "Installed": "Đã cài đặt",
    "Something went wrong": "Đã xảy ra lỗi",
    "an app by Frizzle": "một ứng dụng của Frizzle",
    "device": "thiết bị",

    // MARK: - Welcome

    "I have accepted the": "Tôi đã chấp nhận",
    "Start": "Bắt đầu",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "Ghép nối",
    "Certificates": "Chứng chỉ",
    "Two-Factor Code": "Mã xác minh",
    "6-digit code": "Mã gồm 6 chữ số",
    "Submit": "Gửi",
    "Enter the code Apple just sent to your trusted device.":
        "Nhập mã mà Apple vừa gửi đến thiết bị tin cậy của bạn.",

    // MARK: - Install tab

    "Tunnel connected": "Đã kết nối đường hầm",
    "Tunnel off": "Đường hầm đã tắt",
    "Update available": "Đã có bản cập nhật",
    "SideInstaller %@ is available — you're on %@.":
        "Đã có SideInstaller %@ — bạn đang dùng bản %@.",
    "Get the latest version": "Tải phiên bản mới nhất",
    "Release": "Kênh",
    "Reinstall": "Cài đặt lại",
    "Install %@": "Cài đặt %@",
    "Custom .ipa": "IPA tùy chọn",
    "Import .ipa": "Nhập .ipa",
    "Importing…": "Đang nhập…",
    "Replace": "Thay",
    "iOS %@ required": "Yêu cầu iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "iPhone này đang chạy iOS %@, SideInstaller không thể cài đặt trên phiên bản đó. Cập nhật lên iOS %@ trở lên trong Cài đặt › Cài đặt chung › Cập nhật phần mềm.",
    "Wi-Fi required": "Yêu cầu Wi-Fi",
    "Loopback VPN required": "Cần một VPN loopback",
    "Turn on a loopback VPN — LocalDevVPN, ClashMi, or any app that tunnels to this iPhone. The install runs over it.":
        "Bật một VPN loopback — LocalDevVPN, ClashMi hay bất kỳ ứng dụng nào tạo đường hầm tới iPhone này. Quá trình cài đặt chạy qua nó.",
    "Pairing code": "Mã ghép nối",
    "Type this into the prompt in Settings.":
        "Nhập mã này vào hộp thoại trong Cài đặt.",
    "Install stopped": "Đã dừng cài đặt",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ đã được cài đặt. Hoàn tất bước tin cậy ở trên để mở ứng dụng.",
    "Action needed": "Cần thao tác",

    // MARK: - Install steps

    "Connect the VPN": "Kết nối VPN",
    "Pair with this iPhone": "Ghép nối với iPhone này",
    "Open the device link": "Mở liên kết tới thiết bị",
    "Sign in to Apple ID": "Đăng nhập Apple ID",
    "Download %@": "Tải %@",
    "Use your imported IPA": "Dùng IPA đã nhập",
    "Sign the app": "Ký ứng dụng",
    "Finish setup": "Hoàn tất thiết lập",

    // MARK: - Pairing tab

    "Pairing file ready": "Tệp ghép nối đã sẵn sàng",
    "No pairing file": "Chưa có tệp ghép nối",
    "Pairing file": "Tệp ghép nối",
    "Pairing…": "Đang ghép nối…",
    "Regenerate": "Tạo lại",
    "Generate pairing file": "Tạo tệp ghép nối",
    "Export pairing file": "Xuất tệp ghép nối",
    "Pair in Settings": "Ghép nối trong Cài đặt",
    "Install into an app": "Cài vào một ứng dụng",
    "Scanning": "Đang quét",
    "Rescan apps": "Quét lại ứng dụng",
    "Scan installed apps": "Quét ứng dụng đã cài",
    "Turn on a loopback VPN to scan and install. The write runs over its tunnel.":
        "Bật một VPN loopback để quét và cài đặt. Việc ghi tệp chạy qua đường hầm này.",
    "%d supported app installed": "Đã cài %d ứng dụng được hỗ trợ",
    "%d supported apps installed": "Đã cài %d ứng dụng được hỗ trợ",
    "No supported apps found": "Không tìm thấy ứng dụng được hỗ trợ",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Cài trước một ứng dụng như SideStore, StikDebug hoặc Feather, rồi quét lại.",
    "Install pairing": "Cài tệp ghép nối",
    "Pairing file ready. You can export it or install it into an app below.":
        "Tệp ghép nối đã sẵn sàng. Bạn có thể xuất tệp hoặc cài vào một ứng dụng bên dưới.",
    "Pairing file installed into %@.": "Đã cài tệp ghép nối vào %@.",

    // MARK: - Pairing service status

    "not paired": "chưa ghép nối",
    "connected": "đã kết nối",
    "requesting Local Network…": "đang xin quyền Mạng cục bộ…",
    "Local Network denied": "quyền Mạng cục bộ bị từ chối",
    "waiting for device…": "đang chờ thiết bị…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "đang phát tín hiệu — mở Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển",
    "enter PIN %@ in Settings": "nhập mã PIN %@ trong Cài đặt",
    "paired: %@ (%dB)": "đã ghép nối: %@ (%d B)",
    "failed: empty pairing file": "lỗi: tệp ghép nối rỗng",
    "failed: %@": "lỗi: %@",
    "Pairing is already in progress.": "Quá trình ghép nối đang diễn ra.",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "Quyền Mạng cục bộ đang tắt. Bật quyền này trong Cài đặt › SideInstaller › Mạng cục bộ rồi thử lại.",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "Quá trình ghép nối tạo ra một tệp rỗng. Kiểm tra xem bạn đã chấp nhận yêu cầu ghép nối chưa, rồi thử lại.",

    // MARK: - Certificates tab

    "Revoke this certificate?": "Thu hồi chứng chỉ này?",
    "Revoke": "Thu hồi",
    "Revoking": "Đang thu hồi",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "“%@” sẽ bị thu hồi. Các ứng dụng đã ký bằng chứng chỉ này sẽ không mở được trên mọi thiết bị. Không thể hoàn tác.",
    "Refreshing": "Đang làm mới",
    "Signing in": "Đang đăng nhập",
    "Refresh": "Làm mới",
    "Load certificates": "Tải danh sách chứng chỉ",
    "%d of 3 certificates": "%d trên 3 chứng chỉ",
    "No certificates": "Không có chứng chỉ",
    "This Apple ID has no development certificates to revoke.":
        "Apple ID này không có chứng chỉ phát triển nào để thu hồi.",
    "Expired": "Đã hết hạn",
    "Expires %@": "Hết hạn ngày %@",
    "Unnamed certificate": "Chứng chỉ không có tên",
    "Enter your Apple ID email and password first.":
        "Nhập email và mật khẩu Apple ID của bạn trước.",
    "This certificate has no serial number, so it can't be revoked.":
        "Chứng chỉ này không có số sê-ri nên không thể thu hồi.",

    // MARK: - Settings

    "Settings": "Cài đặt",
    "Done": "Xong",
    "Language": "Ngôn ngữ",
    "App language": "Ngôn ngữ ứng dụng",
    "Auto": "Tự động",
    "Downloaded IPAs": "Tệp IPA đã tải",
    "%@ used": "Đã dùng %@",
    "imported": "đã nhập",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "Chưa có tệp IPA nào được tải. Những tệp bạn cài từ tab Cài ứng dụng sẽ được lưu ở đây.",
    "Downloaded %@": "Đã tải vào %@",
    "Added %@": "Đã thêm %@",
    "Delete this download?": "Xóa bản tải này?",
    "Delete": "Xóa",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "“%@” (%@) sẽ bị xóa. Bạn có thể tải lại bất cứ lúc nào từ tab Cài ứng dụng.",
    "Couldn't delete %@: %@": "Không thể xóa %@: %@",
    "Server": "Máy chủ",
    "Custom…": "Tùy chỉnh…",
    "Server URL": "URL máy chủ",
    "Anisette Server": "Máy chủ Anisette",
    "Device IP": "IP thiết bị",
    "Advanced": "Nâng cao",
    "Clear": "Xóa hết",
    "Activity Log (%d)": "Nhật ký hoạt động (%d)",

    // MARK: - Release channels & downloads

    "Stable": "Ổn định",
    "Nightly": "Nightly",
    "couldn't find the IPA in the %@ %@ release":
        "không tìm thấy tệp IPA trong bản phát hành %@ của %@",
    "%@ has no %@ release right now": "%@ hiện không có bản phát hành %@ nào",
    "bad asset URL": "URL tệp tải không hợp lệ",

    // MARK: - Engine failures

    "Enter your Apple ID email + password.":
        "Nhập email và mật khẩu Apple ID của bạn.",
    "Two-factor verification was cancelled.": "Đã hủy xác minh hai yếu tố.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID hoặc mật khẩu không đúng. Hãy kiểm tra lại email và mật khẩu Apple Account của bạn rồi thử lại.",
    "Apple ID sign-in failed on %@. Last error: %@":
        "Đăng nhập Apple ID thất bại trên %@. Lỗi cuối cùng: %@",
    "the anisette server": "máy chủ anisette",
    "all %d anisette servers": "tất cả %d máy chủ anisette",
    "Not signed in.": "Chưa đăng nhập.",
    "No SideStore IPA downloaded.": "Chưa tải tệp IPA của SideStore.",
    "Signing failed: %@": "Ký ứng dụng thất bại: %@",
    "No signed bundle to install.": "Không có gói đã ký nào để cài đặt.",
    "Device link dropped — reconnect.":
        "Mất liên kết với thiết bị — hãy kết nối lại.",
    "Pairing didn't finish — no pairing file yet.":
        "Ghép nối chưa hoàn tất — vẫn chưa có tệp ghép nối.",
    "Pairing file missing — pairing must run first.":
        "Thiếu tệp ghép nối — phải ghép nối trước.",
    "Pairing file missing — generate it first.":
        "Thiếu tệp ghép nối — hãy tạo tệp trước.",
    "No pairing file yet — tap “Generate pairing file” first.":
        "Vẫn chưa có tệp ghép nối — hãy chạm vào “Tạo tệp ghép nối” trước.",
    "%@ isn't installed yet — install must run first.":
        "%@ chưa được cài đặt — phải cài đặt trước.",
    "No loopback VPN is connected. Turn one on, then try again.":
        "Chưa có VPN loopback nào được kết nối. Hãy bật một cái rồi thử lại.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ không phải là một IPA hợp lệ — có thể lượt tải về đã trả về một trang lỗi, hoặc việc sao chép bị dừng giữa chừng. Hãy thay tệp rồi chạm Cài đặt lại.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ không phải là IPA. Hãy chọn đúng tệp .ipa — nếu trông vẫn đúng thì có thể lượt tải đã lưu một trang lỗi, hoặc dừng giữa chừng.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Chưa nhập IPA nào. Hãy chạm “Nhập .ipa” và chọn một tệp.",
    "Couldn't import %@: %@": "Không thể nhập %@: %@",
    "there's nothing to download for a custom IPA — import one first":
        "không có gì để tải cho IPA tùy chọn — hãy nhập một tệp trước",
    "your app": "ứng dụng của bạn",
    "Apple allows only 3 signing certificates per Apple ID and this one already has 3, so a new one can't be made. Open the Certificates tab, tap “Load certificates”, and revoke an old or expired one to free a slot — then tap Install again. See the steps above.":
        "Apple chỉ cho phép 3 chứng chỉ ký trên mỗi Apple ID và Apple ID này đã có đủ 3, nên không thể tạo thêm. Mở tab Chứng chỉ, chạm vào “Tải danh sách chứng chỉ” và thu hồi một chứng chỉ cũ hoặc đã hết hạn để giải phóng chỗ — rồi chạm vào Cài đặt lần nữa. Xem các bước ở trên.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Không thể đăng ký iPhone này%@ vào nhóm phát triển của Apple ID, nên Apple sẽ không cấp hồ sơ cấp phép. %@ — xem các bước ở trên.",

    // MARK: - Guide cards

    "Connect to Wi-Fi": "Kết nối Wi-Fi",
    "Open Settings › Wi-Fi and join a network.":
        "Mở Cài đặt › Wi-Fi và tham gia một mạng.",
    "Then come back here — this continues automatically.":
        "Sau đó quay lại đây: quá trình sẽ tự tiếp tục.",

    "Turn on a loopback VPN": "Bật một VPN loopback",
    "Open a VPN app that tunnels to this iPhone — LocalDevVPN, ClashMi, or another. Any of them works.":
        "Mở một ứng dụng VPN tạo đường hầm tới iPhone này — LocalDevVPN, ClashMi hay một ứng dụng khác. Cái nào cũng được.",
    "If GitHub is blocked where you are, pick one that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Nếu GitHub bị chặn ở nơi bạn ở, hãy chọn ứng dụng có thể làm proxy luôn: iOS chỉ cho phép một VPN tại một thời điểm, nên đường hầm chỉ cục bộ sẽ không còn đường nào để tải SideStore.",
    "Tap Connect so the toggle turns on.": "Chạm vào Connect để công tắc bật lên.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Giữ Wi-Fi bật rồi quay lại đây: quá trình sẽ tự tiếp tục.",
    "Get LocalDevVPN": "Tải LocalDevVPN",
    "Import an .ipa first": "Hãy nhập một .ipa trước",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Chạm “Nhập .ipa” ở trên và chọn tệp — tệp có thể nằm ở bất kỳ đâu mà app Tệp truy cập được, kể cả iCloud Drive hay ổ USB.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "Hoặc chép tệp vào Tệp › Trên iPhone của tôi › SideInstaller — SideInstaller cũng tìm thấy ở đó.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "Đây là lối đi ở những nơi GitHub bị chặn: tải IPA trên bất kỳ thiết bị nào, mang sang đây rồi cài đặt.",

    "Pair this iPhone in Settings": "Ghép nối iPhone này trong Cài đặt",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Mở ứng dụng Cài đặt, rồi vào Quyền riêng tư & Bảo mật › Chế độ nhà phát triển.",
    "Tap “Pair with SideInstaller”.": "Chạm vào “Ghép nối với SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.":
        "Nhập mật mã iPhone của bạn nếu được hỏi.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Quay lại SideInstaller, xem mã mà ứng dụng hiển thị, rồi nhập đúng mã đó vào hộp thoại trong Cài đặt.",

    "Too many signing certificates": "Quá nhiều chứng chỉ ký",
    "Apple allows only 3 signing certificates per Apple ID, and this one already has 3 — usually left over from setting up AltStore / SideStore on other devices.":
        "Apple chỉ cho phép 3 chứng chỉ ký trên mỗi Apple ID và Apple ID này đã có đủ 3 — thường là còn sót lại từ việc thiết lập AltStore / SideStore trên các thiết bị khác.",
    "Open the Certificates tab at the bottom of the screen, make sure your Apple ID is filled in, and tap “Load certificates”.":
        "Mở tab Chứng chỉ ở cuối màn hình, kiểm tra đã điền Apple ID của bạn, rồi chạm vào “Tải danh sách chứng chỉ”.",
    "Tap “Revoke” on an old or expired certificate to free up a slot. Revoking stops apps already signed with that certificate from launching on other devices, so pick one you no longer use.":
        "Chạm vào “Thu hồi” trên một chứng chỉ cũ hoặc đã hết hạn để giải phóng chỗ. Khi thu hồi, các ứng dụng đã ký bằng chứng chỉ đó sẽ không mở được trên các thiết bị khác, nên hãy chọn chứng chỉ bạn không còn dùng.",
    "Come back to the Install tab and tap Install again.":
        "Quay lại tab Cài ứng dụng và chạm vào Cài đặt lần nữa.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Hoặc đăng nhập bằng một Apple ID khác (hoặc tài khoản dự phòng) ở trên, rồi chạm vào Cài đặt lần nữa.",

    "Couldn't register this device": "Không thể đăng ký thiết bị này",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Apple ID của bạn đã đạt giới hạn số thiết bị đăng ký. Tài khoản miễn phí chỉ đăng ký được một số ít thiết bị mỗi năm và không thể gỡ thiết bị cũ cho đến khi năm đăng ký được đặt lại.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "Cách đơn giản nhất: điền một Apple ID khác (hoặc tài khoản dự phòng) vào các ô ở trên, rồi chạm vào Cài đặt lần nữa.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller không thể tự động thêm iPhone này vào nhóm phát triển của Apple ID. Chạm vào Cài đặt lần nữa thường sẽ được — dịch vụ nhà phát triển của Apple đôi khi tạm thời không hoạt động.",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "Nếu vẫn lỗi, hãy thêm thiết bị thủ công. UDID của thiết bị là:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Dán mã đó vào biểu mẫu “Register a Device” trên cổng Apple Developer (việc này cần tài khoản Apple Developer trả phí), rồi chạm vào Cài đặt lần nữa.",
    "Open device list": "Mở danh sách thiết bị",

    "Last step: trust %@": "Bước cuối: tin cậy %@",
    "Open Settings › General › VPN & Device Management.":
        "Mở Cài đặt › Cài đặt chung › VPN & Quản lý thiết bị.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "Chạm vào Apple ID của bạn trong mục “Ứng dụng nhà phát triển”, rồi chạm vào Tin cậy.",
    "Open %@ from your Home Screen — you're done.":
        "Mở %@ từ Màn hình chính — vậy là xong.",

    "Import the certificate into LiveContainer": "Nhập chứng chỉ vào LiveContainer",
    "Open LiveContainer from your Home Screen.": "Mở LiveContainer từ Màn hình chính.",
    "Tap the Settings tab.": "Chạm vào tab Settings.",
    "Tap “Import Certificate From SideStore”.":
        "Chạm vào “Import Certificate From SideStore”.",
    "Wrong device IP": "Sai IP thiết bị",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "Địa chỉ trong Cài đặt › Nâng cao › IP thiết bị là địa chỉ mà iPhone này đã có, nên không có gì ở đầu bên kia để kết nối.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "Đặt lại thành 10.7.0.1, giá trị mặc định. Trong LocalDevVPN đó là giá trị ở Cài đặt › Device IP — không phải địa chỉ trên màn hình chính, vốn là đầu của chính đường hầm.",
    "If you changed LocalDevVPN's addresses, put its Device IP here, and make sure its Tunnel IP and subnet mask cover it.":
        "Nếu bạn đã đổi địa chỉ của LocalDevVPN, hãy nhập Device IP của nó vào đây và đảm bảo Tunnel IP cùng mặt nạ mạng con của nó bao phủ địa chỉ đó.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Việc ghép nối iPhone này cần đến nó: SideInstaller quảng bá chính mình trên mạng nội bộ để Cài đặt tìm thấy.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Hãy kết nối vào một mạng Wi-Fi. Việc ghép nối iPhone này cần đến nó — SideInstaller phải tìm thấy được trên mạng nội bộ.",
]
