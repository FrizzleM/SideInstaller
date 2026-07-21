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
    "Two-Factor Code": "Mã xác minh hai yếu tố",
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
    "iOS %@ required": "Yêu cầu iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "iPhone này đang chạy iOS %@, SideInstaller không thể cài đặt trên phiên bản đó. Hãy cập nhật lên iOS %@ trở lên trong Cài đặt › Cài đặt chung › Cập nhật phần mềm.",
    "Wi-Fi required": "Yêu cầu Wi-Fi",
    "Connect to a Wi-Fi network. LocalDevVPN's tunnel and the install run over it.":
        "Hãy kết nối vào một mạng Wi-Fi. Đường hầm của LocalDevVPN và quá trình cài đặt đều chạy qua đó.",
    "LocalDevVPN required": "Yêu cầu LocalDevVPN",
    "Open LocalDevVPN and tap Connect. The install runs over its tunnel.":
        "Hãy mở LocalDevVPN và chạm Connect. Quá trình cài đặt chạy qua đường hầm của ứng dụng đó.",
    "Pairing code": "Mã ghép nối",
    "Type this into the prompt in Settings.":
        "Hãy nhập mã này vào hộp thoại trong Cài đặt.",
    "Install stopped": "Đã dừng cài đặt",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ đã được cài đặt. Hãy hoàn tất bước tin cậy ở trên để mở ứng dụng.",
    "Action needed": "Cần thao tác",

    // MARK: - Install steps

    "Connect the VPN": "Kết nối VPN",
    "Pair with this iPhone": "Ghép nối với iPhone này",
    "Open the device link": "Mở liên kết tới thiết bị",
    "Sign in to Apple ID": "Đăng nhập Apple ID",
    "Download %@": "Tải %@",
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
    "Connect to Wi-Fi to scan and install. LocalDevVPN's tunnel runs over it.":
        "Hãy kết nối Wi-Fi để quét và cài đặt. Đường hầm của LocalDevVPN chạy qua đó.",
    "Turn on LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Hãy bật LocalDevVPN để quét và cài đặt. Việc ghi tệp chạy qua đường hầm của nó.",
    "%d supported app installed": "Đã cài %d ứng dụng được hỗ trợ",
    "%d supported apps installed": "Đã cài %d ứng dụng được hỗ trợ",
    "No supported apps found": "Không tìm thấy ứng dụng được hỗ trợ",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Hãy cài trước một ứng dụng như SideStore, StikDebug hoặc Feather, rồi quét lại.",
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
        "đang phát quảng bá — hãy mở Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển",
    "enter PIN %@ in Settings": "nhập mã PIN %@ trong Cài đặt",
    "paired: %@ (%dB)": "đã ghép nối: %@ (%d B)",
    "failed: empty pairing file": "lỗi: tệp ghép nối rỗng",
    "failed: %@": "lỗi: %@",
    "Pairing is already in progress.": "Đang có một phiên ghép nối chạy rồi.",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "Quyền Mạng cục bộ đang tắt. Hãy bật quyền này trong Cài đặt › SideInstaller › Mạng cục bộ rồi thử lại.",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "Quá trình ghép nối tạo ra một tệp rỗng. Hãy chắc chắn bạn đã chấp nhận yêu cầu ghép nối rồi thử lại.",

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
        "Hãy nhập email và mật khẩu Apple ID của bạn trước.",
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
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "Chưa có tệp IPA nào được tải. Những tệp bạn cài từ tab Cài ứng dụng sẽ được lưu ở đây.",
    "Downloaded %@": "Đã tải lúc %@",
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
        "Hãy nhập email và mật khẩu Apple ID của bạn.",
    "Two-factor verification was cancelled.": "Đã hủy xác minh hai yếu tố.",
    "Apple ID sign-in failed: %@": "Đăng nhập Apple ID thất bại: %@",
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
        "Vẫn chưa có tệp ghép nối — hãy chạm “Tạo tệp ghép nối” trước.",
    "%@ isn't installed yet — install must run first.":
        "%@ chưa được cài đặt — phải cài đặt trước.",
    "Wi-Fi is off. Connect to a Wi-Fi network, then try again.":
        "Wi-Fi đang tắt. Hãy kết nối vào một mạng Wi-Fi rồi thử lại.",
    "LocalDevVPN isn't connected. Turn it on, then try again.":
        "LocalDevVPN chưa kết nối. Hãy bật lên rồi thử lại.",
    "Apple allows only 3 signing certificates per Apple ID and this one already has 3, so a new one can't be made. Open the Certificates tab, tap “Load certificates”, and revoke an old or expired one to free a slot — then tap Install again. See the steps above.":
        "Apple chỉ cho phép 3 chứng chỉ ký trên mỗi Apple ID và Apple ID này đã có đủ 3, nên không thể tạo thêm. Hãy mở tab Chứng chỉ, chạm “Tải danh sách chứng chỉ” và thu hồi một chứng chỉ cũ hoặc đã hết hạn để giải phóng chỗ — rồi chạm Cài đặt lần nữa. Xem các bước ở trên.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Không thể đăng ký iPhone này%@ vào nhóm phát triển của Apple ID, nên Apple sẽ không cấp hồ sơ cấp phép. %@ — xem các bước ở trên.",

    // MARK: - Guide cards

    "Connect to Wi-Fi": "Kết nối Wi-Fi",
    "Open Settings › Wi-Fi and join a network.":
        "Mở Cài đặt › Wi-Fi và tham gia một mạng.",
    "LocalDevVPN's tunnel — and the whole install — run over Wi-Fi.":
        "Đường hầm của LocalDevVPN — và cả quá trình cài đặt — đều chạy qua Wi-Fi.",
    "Then come back here — this continues automatically.":
        "Sau đó quay lại đây: quá trình sẽ tự tiếp tục.",

    "Turn on LocalDevVPN": "Bật LocalDevVPN",
    "Open the LocalDevVPN app (install it first if you haven't).":
        "Mở ứng dụng LocalDevVPN (nếu chưa có, hãy cài trước).",
    "Tap Connect so the toggle turns on.": "Chạm Connect để công tắc bật lên.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Giữ Wi-Fi bật rồi quay lại đây: quá trình sẽ tự tiếp tục.",
    "Get LocalDevVPN": "Tải LocalDevVPN",

    "Pair this iPhone in Settings": "Ghép nối iPhone này trong Cài đặt",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Mở ứng dụng Cài đặt, rồi vào Quyền riêng tư & Bảo mật › Chế độ nhà phát triển.",
    "Tap “Pair with SideInstaller”.": "Chạm “Ghép nối với SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.":
        "Nhập mật mã iPhone của bạn nếu được hỏi.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Quay lại SideInstaller, xem mã mà ứng dụng hiển thị, rồi nhập đúng mã đó vào hộp thoại trong Cài đặt.",

    "Too many signing certificates": "Quá nhiều chứng chỉ ký",
    "Apple allows only 3 signing certificates per Apple ID, and this one already has 3 — usually left over from setting up AltStore / SideStore on other devices.":
        "Apple chỉ cho phép 3 chứng chỉ ký trên mỗi Apple ID và Apple ID này đã có đủ 3 — thường là còn sót lại từ việc thiết lập AltStore / SideStore trên các thiết bị khác.",
    "Open the Certificates tab at the bottom of the screen, make sure your Apple ID is filled in, and tap “Load certificates”.":
        "Mở tab Chứng chỉ ở cuối màn hình, kiểm tra đã điền Apple ID của bạn, rồi chạm “Tải danh sách chứng chỉ”.",
    "Tap “Revoke” on an old or expired certificate to free up a slot. Revoking stops apps already signed with that certificate from launching on other devices, so pick one you no longer use.":
        "Chạm “Thu hồi” trên một chứng chỉ cũ hoặc đã hết hạn để giải phóng chỗ. Khi thu hồi, các ứng dụng đã ký bằng chứng chỉ đó sẽ không mở được trên các thiết bị khác, nên hãy chọn chứng chỉ bạn không còn dùng.",
    "Come back to the Install tab and tap Install again.":
        "Quay lại tab Cài ứng dụng và chạm Cài đặt lần nữa.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Hoặc đăng nhập bằng một Apple ID khác (hoặc tài khoản dự phòng) ở trên, rồi chạm Cài đặt lần nữa.",

    "Couldn't register this device": "Không thể đăng ký thiết bị này",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Apple ID của bạn đã đạt giới hạn số thiết bị đăng ký. Tài khoản miễn phí chỉ đăng ký được một số ít thiết bị mỗi năm và không thể gỡ thiết bị cũ cho đến khi năm đăng ký được đặt lại.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "Cách đơn giản nhất: điền một Apple ID khác (hoặc tài khoản dự phòng) vào các ô ở trên, rồi chạm Cài đặt lần nữa.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller không thể tự động thêm iPhone này vào nhóm phát triển của Apple ID. Chạm Cài đặt lần nữa thường sẽ được — dịch vụ nhà phát triển của Apple đôi khi tạm thời không hoạt động.",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "Nếu vẫn lỗi, hãy thêm thiết bị thủ công. UDID của thiết bị là:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Dán mã đó vào biểu mẫu “Register a Device” trên cổng Apple Developer (việc này cần tài khoản Apple Developer trả phí), rồi chạm Cài đặt lần nữa.",
    "Open device list": "Mở danh sách thiết bị",

    "Last step: trust %@": "Bước cuối: tin cậy %@",
    "Open Settings › General › VPN & Device Management.":
        "Mở Cài đặt › Cài đặt chung › VPN & Quản lý thiết bị.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "Chạm vào Apple ID của bạn trong mục “Ứng dụng nhà phát triển”, rồi chạm Tin cậy.",
    "Open %@ from your Home Screen — you're done.":
        "Mở %@ từ Màn hình chính — vậy là xong.",

    "Import the certificate into LiveContainer": "Nhập chứng chỉ vào LiveContainer",
    "Open LiveContainer from your Home Screen.": "Mở LiveContainer từ Màn hình chính.",
    "Tap the Settings tab.": "Chạm tab Settings.",
    "Tap “Import Certificate From SideStore”.":
        "Chạm “Import Certificate From SideStore”.",
]
