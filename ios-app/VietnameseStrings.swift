import Foundation

/// Vietnamese translations (same rules as `spanishStrings`). The Install tab is
/// "Cài ứng dụng" because "Cài đặt" means Settings. Nouns don't inflect for
/// number, so singular and plural app-count strings are the same.

let vietnameseStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "Hủy",
    "Copy": "Sao chép",
    "Copy logs": "Sao chép nhật ký",
    "Email": "Email",
    "Password": "Mật khẩu",
    "Install": "Cài ứng dụng",
    "Installing": "Đang cài đặt",
    "Cancelling": "Đang hủy",
    "Installed": "Đã cài đặt",
    "Something went wrong": "Đã xảy ra lỗi",
    "an app by Frizzle": "một ứng dụng của Frizzle",
    "device": "thiết bị",

    // MARK: - Welcome

    "I have accepted the": "Tôi đã chấp nhận",
    "Start": "Bắt đầu",

    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "Bạn sẽ cần một tệp ghép nối",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "iPhone này chạy iOS %@. Chỉ iOS %@ mới tự ghép nối được, nên bạn phải tạo tệp ghép nối trên máy tính — bằng jitterbugpair hoặc pymobiledevice3 — rồi nhập vào ứng dụng. SideInstaller sẽ hướng dẫn bạn từng bước.",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "Đăng nhập bằng Apple ID của bạn",
    "Don't worry, these are stored locally":
        "Đừng lo, những thông tin này chỉ được lưu trên máy",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "Được lưu trong keychain của iPhone này và chỉ gửi cho Apple khi đăng nhập.",
    "Continue": "Tiếp tục",
    "Set this up later": "Thiết lập sau",
    "Add Apple ID": "Thêm Apple ID",
    "Edit Apple ID": "Sửa Apple ID",
    "Save": "Lưu",
    "Enter the password again to save this Apple ID.": "Nhập lại mật khẩu để lưu Apple ID này.",
    "Account": "Tài khoản",
    "In use": "Đang dùng",
    "Edit": "Sửa",
    "Remove": "Xóa",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "Chưa lưu Apple ID nào. Thêm một tài khoản và SideInstaller sẽ dùng nó cho mọi lần đăng nhập.",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "Được lưu trong keychain của iPhone này và chỉ gửi cho Apple khi đăng nhập. Vuốt một hàng để sửa mật khẩu hoặc xóa.",
    "Remove this Apple ID?": "Xóa Apple ID này?",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "“%@” và mật khẩu đã lưu sẽ bị xóa khỏi iPhone này. Tài khoản Apple của bạn không thay đổi.",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "Keychain của iPhone này từ chối lưu mật khẩu (lỗi %d), nên mật khẩu chỉ được giữ đến khi thoát SideInstaller.",
    "No Apple ID saved. Add one in Settings › Account.":
        "Chưa lưu Apple ID nào. Hãy thêm một tài khoản trong Cài đặt › Tài khoản.",

    "Add your Apple ID": "Thêm Apple ID của bạn",
    "Open Settings with the gear at the top right.":
        "Mở Cài đặt bằng biểu tượng bánh răng ở góc trên bên phải.",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "Trong mục Tài khoản, chạm “Thêm Apple ID” rồi nhập email và mật khẩu của bạn.",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "Công cụ",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "Ghép nối",
    "Certificates": "Chứng chỉ",
    "Two-Factor Code": "Mã xác minh",
    "6-digit code": "Mã gồm 6 chữ số",
    "Submit": "Gửi",
    "Enter the code Apple just sent to your trusted device.":
        "Nhập mã mà Apple vừa gửi đến thiết bị tin cậy của bạn.",
    "Enter the code Apple texted to %@.":
        "Nhập mã Apple đã nhắn tin đến %@.",
    "Enter the code Apple texted to your phone.":
        "Nhập mã Apple đã nhắn tin đến điện thoại của bạn.",
    "Apple is calling %@. Enter the code you hear.":
        "Apple đang gọi đến %@. Hãy nhập mã bạn nghe được.",
    "Apple is calling your phone. Enter the code you hear.":
        "Apple đang gọi đến điện thoại của bạn. Hãy nhập mã bạn nghe được.",
    "Choose how Apple should send your verification code.":
        "Chọn cách Apple gửi mã xác minh cho bạn.",
    "Choose How to Get a Code":
        "Chọn cách nhận mã",
    "Verify":
        "Xác minh",
    "Didn't get it?":
        "Không nhận được?",
    "Send a new code to my devices":
        "Gửi mã mới đến thiết bị của tôi",
    "Text me a new code":
        "Nhắn tin cho tôi mã mới",
    "Call me again":
        "Gọi lại cho tôi",
    "Send a code to my Apple devices":
        "Gửi mã đến thiết bị Apple của tôi",
    "Text %@":
        "Nhắn tin đến %@",
    "Call %@":
        "Gọi %@",
    "Checking the code…":
        "Đang kiểm tra mã…",
    "Requesting a new code…":
        "Đang yêu cầu mã mới…",
    "Sending a code to your devices…":
        "Đang gửi mã đến thiết bị của bạn…",
    "Texting a code to %@…":
        "Đang nhắn mã đến %@…",
    "Calling %@…":
        "Đang gọi %@…",

    // MARK: - Install tab

    "Tunnel connected": "Đã kết nối đường hầm",
    "Tunnel off": "Đường hầm đã tắt",
    "Update available": "Đã có bản cập nhật",
    "SideInstaller %@ is available — you're on %@.":
        "Đã có SideInstaller %@ — bạn đang dùng bản %@.",
    "Get the latest version": "Tải phiên bản mới nhất",
    "From the website": "Từ trang web",
    "Sign it with your Apple ID": "Ký bằng Apple ID của bạn",
    "Install it in LiveContainer": "Cài vào LiveContainer",
    "LiveContainer isn't installed on this iPhone.": "LiveContainer chưa được cài trên iPhone này.",
    "Release": "Kênh",
    "Reinstall": "Cài đặt lại",
    "Install %@": "Cài đặt %@",
    "Custom .ipa": "IPA tùy chọn",
    "Import .ipa": "Nhập .ipa",
    "Importing…": "Đang nhập…",
    "Replace": "Thay",
    "or": "hoặc",
    "Paste a download link": "Dán liên kết tải xuống",
    "Downloading… %d%%": "Đang tải… %d%%",
    "iOS %@ required": "Yêu cầu iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "iPhone này đang chạy iOS %@, SideInstaller không thể cài đặt trên phiên bản đó. Cập nhật lên iOS %@ trở lên trong Cài đặt › Cài đặt chung › Cập nhật phần mềm.",
    "Wi-Fi required": "Yêu cầu Wi-Fi",
    "Pairing code": "Mã ghép nối",
    "Type this into the prompt in Settings.":
        "Nhập mã này vào hộp thoại trong Cài đặt.",
    "Install stopped": "Đã dừng cài đặt",
    "Close": "Đóng",
    "Yes": "Có",
    "No": "Không",
    "Closing this popup will end the process. Are you sure?":
        "Đóng cửa sổ này sẽ dừng quá trình. Bạn có chắc không?",
    "Cancel the install?": "Hủy cài đặt?",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ đã được cài đặt. Hoàn tất bước tin cậy ở trên để mở ứng dụng.",
    "%@ is installed. Finish the trust step below to open it.":
        "%@ đã được cài đặt. Hoàn tất bước tin cậy ở dưới để mở ứng dụng.",
    "Success: last steps": "Thành công: các bước cuối",
    "Action needed": "Cần thao tác",
    "Step %@ of %@": "Bước %@ trên %@",
    "Show all steps": "Hiện tất cả các bước",
    "Show fewer steps": "Ẩn bớt các bước",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "Cần LocalDevVPN",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "Cài LocalDevVPN và kết nối. Quá trình cài đặt chạy qua đường hầm của nó.",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Kết nối LocalDevVPN để quét và cài đặt. Việc ghi tệp chạy qua đường hầm của nó.",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "Kết nối LocalDevVPN. Việc giả lập chạy qua đường hầm của nó, như mọi thứ khác ở đây.",
    "LocalDevVPN isn't connected. Connect it, then try again.":
        "LocalDevVPN chưa được kết nối. Hãy kết nối rồi thử lại.",
    "Connect LocalDevVPN": "Kết nối LocalDevVPN",
    "Install LocalDevVPN from the App Store and open it.":
        "Cài LocalDevVPN từ App Store rồi mở ứng dụng.",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Nếu GitHub bị chặn ở nơi bạn ở, hãy dùng một VPN cũng có thể định tuyến lưu lượng của bạn: iOS chỉ chạy một VPN tại một thời điểm, nên đường hầm chỉ nội bộ sẽ không còn đường nào để tải SideStore.",

    // MARK: - Install steps

    "Connect the VPN": "Kết nối VPN",
    "Get pairing file": "Lấy tệp ghép nối",
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
    "%d supported app installed": "Đã cài %d ứng dụng được hỗ trợ",
    "%d supported apps installed": "Đã cài %d ứng dụng được hỗ trợ",
    "No supported apps found": "Không tìm thấy ứng dụng được hỗ trợ",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Cài trước một ứng dụng như SideStore, StikDebug hoặc Feather, rồi quét lại.",
    "Install pairing": "Cài tệp ghép nối",
    "Pairing file ready. You can export it or install it into an app below.":
        "Tệp ghép nối đã sẵn sàng. Bạn có thể xuất tệp hoặc cài vào một ứng dụng bên dưới.",
    "Pairing file installed into %@.": "Đã cài tệp ghép nối vào %@.",
    "Install pairing into all apps": "Cài tệp ghép nối vào tất cả ứng dụng",
    "Installing into all apps": "Đang cài vào tất cả ứng dụng",
    "Pairing file installed into all %d apps.": "Đã cài tệp ghép nối vào cả %d ứng dụng.",
    "Couldn't write into %@.": "Không thể ghi vào %@.",
    "The %@ record isn't a plist dictionary.": "Bản ghi %@ không phải là từ điển plist.",

    // Importing a pairing file (required below iOS 27, under Advanced from 27)

    "Import pairing file": "Nhập tệp ghép nối",
    "How do I make one?": "Tạo nó như thế nào?",
    "(Optional)": "(Không bắt buộc)",
    "imported pairing file": "đã nhập tệp ghép nối",
    "No pairing file yet — tap “Import pairing file” first.":
        "Chưa có tệp ghép nối — hãy chạm “Nhập tệp ghép nối” trước.",
    "Pairing file missing — import it first.": "Thiếu tệp ghép nối — hãy nhập trước.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ không phải tệp ghép nối. Hãy chọn tệp máy tính đã tạo — một .mobiledevicepairing hoặc .plist chứa bản ghi ghép nối của iPhone này.",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "iOS %@ không thể tự tạo tệp ghép nối — việc đó cần iOS %@. Hãy nhập một tệp tạo trên máy tính trong mục “Tệp ghép nối” rồi thử lại.",

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
    "%d certificate(s)": "%d chứng chỉ",
    "No certificates": "Không có chứng chỉ",
    "This Apple ID has no development certificates to revoke.":
        "Apple ID này không có chứng chỉ phát triển nào để thu hồi.",
    "Expired": "Đã hết hạn",
    "Expires %@": "Hết hạn ngày %@",
    "Unnamed certificate": "Chứng chỉ không có tên",
    "This certificate has no serial number, so it can't be revoked.":
        "Chứng chỉ này không có số sê-ri nên không thể thu hồi.",

    // Export: the certificate SideInstaller signs with, as a .p12
    "This certificate has no serial number, so it can't be exported.":
        "Chứng chỉ này không có số sê-ri nên không thể xuất.",
    "Only the certificate SideInstaller signs with can be exported: the private key of any other stays on the device that asked Apple for it.":
        "Chỉ có thể xuất chứng chỉ mà SideInstaller dùng để ký: khóa riêng của mọi chứng chỉ khác nằm trên thiết bị đã yêu cầu nó từ Apple.",
    "Couldn't export the certificate: %@": "Không thể xuất chứng chỉ: %@",
    "Export certificate": "Xuất chứng chỉ",
    "Export": "Xuất",
    "Exporting": "Đang xuất",
    "Saves this certificate and its private key as a .p12 file, for another signing app or a computer to sign with. Choose a password for it: you'll need it to import the file. Keep the file to yourself.":
        "Lưu chứng chỉ này và khóa riêng của nó thành tệp .p12, để một ứng dụng ký khác hoặc máy tính ký bằng nó. Hãy chọn mật khẩu: bạn sẽ cần nó để nhập tệp. Đừng đưa tệp cho ai.",
    "SideInstaller can export only the certificate it signs with, and none of these is it: a certificate's private key stays on the device that asked Apple for it.":
        "SideInstaller chỉ có thể xuất chứng chỉ mà nó dùng để ký, và không chứng chỉ nào ở đây là nó: khóa riêng của một chứng chỉ nằm trên thiết bị đã yêu cầu nó từ Apple.",
    "SideInstaller signs with this one": "SideInstaller ký bằng chứng chỉ này",

    // MARK: - SideStore's certificate (sidestore://certificate)

    "Use SideStore's certificate": "Dùng chứng chỉ của SideStore",
    "Checking the certificate": "Đang kiểm tra chứng chỉ",
    "SideStore opens and sends back its certificate. SideInstaller then signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "SideStore sẽ mở ra và gửi lại chứng chỉ của nó. Sau đó SideInstaller cũng ký bằng chứng chỉ này, nên với Apple ID miễn phí, không ứng dụng nào phải thu hồi chứng chỉ của ứng dụng kia.",
    "Apple won't issue a second signing certificate for this Apple ID. If SideStore made the one it has, SideInstaller can sign with that one too, and nothing is revoked. Revoking it lets the install continue as well — but it can't be undone.":
        "Apple sẽ không cấp chứng chỉ ký thứ hai cho Apple ID này. Nếu chứng chỉ sẵn có do SideStore tạo, SideInstaller cũng có thể ký bằng nó mà không thu hồi gì cả. Thu hồi nó cũng giúp quá trình cài đặt tiếp tục — nhưng không thể hoàn tác.",
    "If SideStore made it, tap “Use SideStore's certificate” above: SideInstaller signs with that one too, and nothing is revoked.":
        "Nếu chứng chỉ đó do SideStore tạo, hãy chạm “Dùng chứng chỉ của SideStore” ở trên: SideInstaller cũng ký bằng chứng chỉ đó, và không có gì bị thu hồi.",
    "SideInstaller signs with “%@” from now on. Nothing was revoked, so the apps already signed with it keep working.":
        "Từ giờ SideInstaller ký bằng “%@”. Không có gì bị thu hồi, nên các ứng dụng đã được ký bằng chứng chỉ này vẫn hoạt động.",
    "SideInstaller already signs with “%@”.": "SideInstaller đã ký bằng “%@” rồi.",
    "That certificate isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID (SideStore may be signed in with a different one). Nothing was changed.":
        "Chứng chỉ đó không thuộc Apple ID này: nó đã bị thu hồi, hoặc thuộc một Apple ID khác (có thể SideStore đang đăng nhập bằng Apple ID khác). Không có gì bị thay đổi.",
    "Couldn't use that certificate: %@": "Không thể dùng chứng chỉ đó: %@",
    "SideStore isn't installed on this iPhone, so there's no certificate to get from it.":
        "SideStore chưa được cài trên iPhone này, nên không có chứng chỉ nào để lấy.",
    "Sign with this certificate?": "Ký bằng chứng chỉ này?",
    "A link sent SideInstaller a signing certificate. Only use it if you asked for one: SideInstaller will sign apps with it from now on, in place of its own. It's used only if it's one of your Apple ID's certificates.":
        "Một liên kết đã gửi cho SideInstaller một chứng chỉ ký. Chỉ dùng nếu chính bạn đã yêu cầu: từ giờ SideInstaller sẽ ký ứng dụng bằng chứng chỉ này thay cho chứng chỉ của nó. Chứng chỉ chỉ được dùng nếu là một trong các chứng chỉ của Apple ID của bạn.",
    "Use it": "Dùng",
    "That link was meant to carry a signing certificate, but what it holds can't be read.":
        "Liên kết đó lẽ ra chứa một chứng chỉ ký, nhưng không đọc được nội dung.",

    // MARK: - Location tab

    "Location spoofing": "Giả lập vị trí",
    "Not simulating": "Không mô phỏng",
    "Simulated": "Đã mô phỏng",
    "Pick a place": "Chọn một nơi",
    "Search for a place": "Tìm một địa điểm",
    "Nothing found for “%@”.": "Không tìm thấy kết quả cho “%@”.",
    "Set location": "Đặt vị trí",
    "Setting": "Đang đặt",
    "Reset to real location": "Trở lại vị trí thật",
    "Location set to %@.": "Đã đặt vị trí thành %@.",
    "Location reset. The device is using its own again.":
        "Đã đặt lại vị trí. Thiết bị dùng lại vị trí của chính nó.",
    "That isn't a valid coordinate.": "Tọa độ đó không hợp lệ.",
    "Location session closed — set it up again.": "Phiên vị trí đã đóng — hãy thiết lập lại.",
    "Downloading %@ failed (HTTP %d).": "Tải %@ thất bại (HTTP %d).",
    "Couldn't build the download URL for %@.": "Không thể tạo URL tải cho %@.",

    // Location › saved places and GPX routes.
    "Saved places": "Địa điểm đã lưu",
    "Save this place": "Lưu địa điểm này",
    "Name": "Tên",
    "Show on map": "Xem trên bản đồ",
    "Tap Save under the map to keep the spot under the pin. Tapping a saved place sets it straight away.":
        "Chạm Lưu bên dưới bản đồ để giữ lại điểm dưới ghim. Chạm vào một địa điểm đã lưu để đặt ngay.",
    "Play a GPX route": "Phát lộ trình GPX",
    "Import a .gpx file and the device moves along it at the speed you pick, then stays at its last point.":
        "Nhập tệp .gpx và thiết bị sẽ di chuyển theo nó với tốc độ bạn chọn, rồi dừng ở điểm cuối.",
    "Import GPX file": "Nhập tệp GPX",
    "Couldn't read %@ as a GPX file.": "Không thể đọc %@ dưới dạng tệp GPX.",
    "%@ has no track, route or waypoints in it.": "%@ không có track, route hay waypoint nào.",
    "As recorded": "Như đã ghi",
    "Walk": "Đi bộ",
    "Cycle": "Đạp xe",
    "Drive": "Lái xe",
    "Speed": "Tốc độ",
    "Play route": "Phát lộ trình",
    "Playing route · %d%%": "Đang phát lộ trình · %d%%",
    "Stop here": "Dừng tại đây",
    "%@ of %@": "%@ / %@",
    "Route finished. The device stays at its last point.":
        "Đã hết lộ trình. Thiết bị ở lại điểm cuối.",
    "Route stopped. The device stays where it got to.":
        "Đã dừng lộ trình. Thiết bị ở lại vị trí đã đến.",
    "Route playback stopped: %@": "Đã dừng phát lộ trình: %@",
    // Location › planned routes (OpenStreetMap).
    "Add stop": "Thêm điểm dừng",
    "Add as stop": "Thêm làm điểm dừng",
    "Plan a route": "Lập lộ trình",
    "Travel by": "Phương tiện",
    "Goes along each street at its speed limit, from OpenStreetMap. A street without one mapped gets the usual limit for its kind of road.":
        "Đi trên mỗi con đường đúng giới hạn tốc độ của nó, theo OpenStreetMap. Đường chưa có giới hạn trên bản đồ sẽ dùng giới hạn thường gặp của loại đường đó.",
    "Rides streets and paths a bike can take, at a cycling pace.":
        "Đi trên các đường phố và lối đi mà xe đạp đi được, với tốc độ đạp xe.",
    "Walks streets and paths at a walking pace.":
        "Đi trên các đường phố và lối đi, với tốc độ đi bộ.",
    "Start where the device is": "Bắt đầu từ vị trí của thiết bị",
    "Move the map so the pin is on a place, then tap Add stop. Add as many as you like: the route goes to each in order.":
        "Di chuyển bản đồ để ghim nằm trên một địa điểm, rồi chạm Thêm điểm dừng. Thêm bao nhiêu cũng được: lộ trình sẽ đi qua từng điểm theo thứ tự.",
    "The device's location": "Vị trí của thiết bị",
    "Stop %d": "Điểm dừng %d",
    "Clear stops": "Xóa các điểm dừng",
    "Move up": "Chuyển lên",
    "Move down": "Chuyển xuống",
    "Find route": "Tìm lộ trình",
    "Finding route": "Đang tìm lộ trình",
    "Add one more stop to plan a route.": "Thêm một điểm dừng nữa để lập lộ trình.",
    "Routes from OpenStreetMap, © OpenStreetMap contributors":
        "Lộ trình từ OpenStreetMap, © những người đóng góp OpenStreetMap",
    "Speed limits are mapped for all of it.":
        "Toàn bộ lộ trình đều có giới hạn tốc độ trên bản đồ.",
    "Speed limits are mapped for %d%% of it; the rest is estimated.":
        "%d%% lộ trình có giới hạn tốc độ trên bản đồ; phần còn lại là ước tính.",
    "Average %@": "Trung bình %@",
    "Speed limit %@": "Giới hạn tốc độ %@",
    "No speed limit · going %@": "Không giới hạn tốc độ · đang đi %@",
    "No limit mapped · going %@": "Chưa có giới hạn trên bản đồ · đang đi %@",
    "Going %@": "Đang đi %@",
    "No street name": "Đường không tên",
    "Estimated speed limit %@": "Giới hạn tốc độ ước tính %@",
    "No speed limit": "Không giới hạn tốc độ",
    "No route found between these stops. Move them onto roads or paths, or travel another way.":
        "Không tìm thấy lộ trình giữa các điểm dừng này. Hãy dời chúng lên đường hoặc lối đi, hoặc chọn phương tiện khác.",
    "A stop is too far from any road or path. Move it closer and try again.":
        "Một điểm dừng ở quá xa mọi con đường hoặc lối đi. Hãy dời nó lại gần hơn rồi thử lại.",
    "Too many stops for the route server. Take some out and try again.":
        "Quá nhiều điểm dừng cho máy chủ lộ trình. Hãy bớt vài điểm rồi thử lại.",
    "That route is too long for the route server. Make it shorter, or split it up.":
        "Lộ trình này quá dài cho máy chủ lộ trình. Hãy rút ngắn hoặc chia nhỏ nó.",
    "The route server is busy. Try again in a minute.":
        "Máy chủ lộ trình đang bận. Hãy thử lại sau một phút.",
    "The route server couldn't plan this route (%@).":
        "Máy chủ lộ trình không lập được lộ trình này (%@).",

    // MARK: - Entitlements tab

    "Entitlements": "Quyền",
    "Load apps": "Tải danh sách ứng dụng",
    "%d App ID": "%d App ID",
    "%d App IDs": "%d App ID",
    "No App IDs": "Không có App ID",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "Apple ID này chưa đăng ký ứng dụng nào. Hãy cài một ứng dụng bằng SideInstaller rồi quay lại.",
    "Memory and performance": "Bộ nhớ và hiệu năng",
    "Other free capabilities": "Các khả năng miễn phí khác",
    "Recommended": "Khuyến nghị",
    "Select all": "Chọn tất cả",
    "None": "Không chọn",
    "Enable %d selected": "Bật %d mục đã chọn",
    "Asking Apple": "Đang hỏi Apple",
    "%d of %d enabled": "Đã bật %d trong %d",
    "Install the app again for these to take effect.":
        "Cài lại ứng dụng để các quyền có hiệu lực.",

    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "Ứng dụng sideload",
    "Reading the device": "Đang đọc thiết bị",

    // Refresh all: signing the installed apps again.
    "iOS %@ isn't supported — SideInstaller needs iOS %@ or later.":
        "iOS %@ không được hỗ trợ — SideInstaller cần iOS %@ trở lên.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Under Tools › Certificates, use SideStore's certificate or revoke that one, then refresh again.":
        "Apple không cấp chứng chỉ ký cho Apple ID này: nó báo rằng đã có một chứng chỉ (lỗi 7460). Trong Công cụ › Chứng chỉ, hãy dùng chứng chỉ của SideStore hoặc thu hồi chứng chỉ đó, rồi gia hạn lại.",
    "An install is already running. Wait for it to finish, then refresh.":
        "Đang có một lượt cài đặt chạy. Hãy đợi xong rồi gia hạn.",
    "Getting ready": "Đang chuẩn bị",
    "Stopping after this app": "Sẽ dừng sau ứng dụng này",
    "Refreshing %@": "Đang gia hạn %@",
    "Signed by team %@, not the one you're signed in as — refreshing it here would install a second copy.":
        "Được ký bởi nhóm %@, không phải nhóm bạn đang đăng nhập — gia hạn ở đây sẽ cài thêm một bản thứ hai.",
    "Refreshed. Its seven days start again now.":
        "Đã gia hạn. Bảy ngày bắt đầu lại từ bây giờ.",
    "Nothing was refreshed.": "Không có ứng dụng nào được gia hạn.",
    "Refreshed %d of %d apps.": "Đã gia hạn %d trong %d ứng dụng.",
    "Refresh all apps?": "Gia hạn tất cả ứng dụng?",
    "Refresh all": "Gia hạn tất cả",
    "%@ will be signed again with your Apple ID and installed over the copy on this device. It keeps its data, and its seven days start over.":
        "%@ sẽ được ký lại bằng Apple ID của bạn và cài đè lên bản đang có trên thiết bị này. Ứng dụng giữ nguyên dữ liệu, và bảy ngày bắt đầu lại.",
    "%d apps will be signed again with your Apple ID and installed over the copies on this device. They keep their data, and their seven days start over.":
        "%d ứng dụng sẽ được ký lại bằng Apple ID của bạn và cài đè lên các bản đang có trên thiết bị này. Chúng giữ nguyên dữ liệu, và bảy ngày bắt đầu lại.",
    "%d app can be signed again from an IPA already on this iPhone.":
        "%d ứng dụng có thể được ký lại từ một tệp IPA đã có trên iPhone này.",
    "%d apps can be signed again from IPAs already on this iPhone.":
        "%d ứng dụng có thể được ký lại từ các tệp IPA đã có trên iPhone này.",
    "Reload": "Tải lại",
    "Waiting": "Đang chờ",
    "In progress": "Đang chạy",
    "Failed": "Thất bại",
    "%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.":
        "%d ứng dụng ở đây không có tệp IPA trong SideInstaller nên không thể gia hạn từ trang này. Hãy gia hạn trong ứng dụng đã cài nó, hoặc nhập tệp .ipa của nó trước.",
    "%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.":
        "%d ứng dụng ở đây không có tệp IPA trong SideInstaller nên không thể gia hạn từ trang này. Hãy gia hạn trong ứng dụng đã cài chúng, hoặc nhập các tệp .ipa của chúng trước.",
    "%d app": "%d ứng dụng",
    "%d apps": "%d ứng dụng",
    "%d app needs refreshing": "%d ứng dụng cần gia hạn",
    "%d apps need refreshing": "%d ứng dụng cần gia hạn",
    "No sideloaded apps": "Không có ứng dụng sideload nào",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Không có gì trên thiết bị này được cài bằng hồ sơ cấp phép. Ứng dụng từ App Store không hết hạn nên không xuất hiện ở đây.",
    "No matching profile": "Không có hồ sơ nào khớp",
    "Expires today": "Hết hạn hôm nay",
    "Expires tomorrow": "Hết hạn ngày mai",
    "Expires in %d days — %@": "Hết hạn sau %d ngày — %@",
    "Expired %@": "Đã hết hạn ngày %@",
    "Unused profiles": "Hồ sơ không dùng đến",
    "Issued to App IDs no installed app is running on.":
        "Được cấp cho các App ID mà không ứng dụng nào đã cài đang chạy trên đó.",
    "Older profiles": "Hồ sơ cũ hơn",
    "Bundle identifier": "Định danh bundle",
    "App ID": "App ID",
    "Version": "Phiên bản",
    "Profile name": "Tên hồ sơ",
    "Team": "Nhóm",
    "Team ID": "ID nhóm",
    "Issued": "Ngày cấp",
    "Profile UUID": "UUID hồ sơ",
    "Capabilities": "Khả năng",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "App ID ký tự đại diện — nó bao trùm mọi bundle id bên dưới nên không mang được khả năng riêng của từng ứng dụng.",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "Thiết bị không có hồ sơ cấp phép cho App ID này. Ứng dụng có thể đã không mở được nữa — hãy cài lại để khắc phục.",

    // MARK: - Side by Side tool

    // The tool's name is left in English everywhere, as SideStore's is.
    "Side by Side": "Side by Side",
    "Pair with their iPhone": "Ghép nối với iPhone của họ",
    "Sign in to their Apple ID": "Đăng nhập Apple ID của họ",
    "Download SideInstaller": "Tải SideInstaller",
    "Install on their iPhone": "Cài lên iPhone của họ",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” không phải là địa chỉ IPv4. Nó phải có dạng 192.168.1.42.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ là địa chỉ mà chính chiếc iPhone này đang dùng. Side by Side cài lên iPhone của người khác — hãy dùng địa chỉ của họ. Để cài lên máy này, hãy dùng tab Cài ứng dụng.",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "iPhone vừa ghép nối là chính máy này. Hãy ghép nối từ Cài đặt trên iPhone của họ. Để cài lên iPhone này, hãy dùng tab Cài ứng dụng.",
    "Enter the Apple ID to sign with, and its password.":
        "Nhập Apple ID dùng để ký và mật khẩu của nó.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Wi-Fi đang tắt. Cả hai iPhone phải cùng một mạng Wi-Fi thì mới hoạt động.",
    "The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute.":
        "Bản tải về không phải là tệp IPA. Có thể GitHub đang trả về trang lỗi — hãy thử lại sau một phút.",
    "Couldn't download the latest SideInstaller release: %@":
        "Không tải được bản phát hành SideInstaller mới nhất: %@",
    "No SideInstaller IPA downloaded.": "Chưa tải IPA của SideInstaller.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise.":
        "Apple không cấp chứng chỉ ký cho Apple ID này: nó báo rằng đã có một chứng chỉ (lỗi 7460). Phải thu hồi bớt một chứng chỉ trước — bằng công cụ Chứng chỉ nếu đây là Apple ID đã lưu trong Cài đặt › Tài khoản, còn không thì vào developer.apple.com và đăng nhập bằng tài khoản đó.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple không đăng ký được iPhone của họ với nhóm nhà phát triển của Apple ID này, nên sẽ không cấp hồ sơ provisioning. %@",
    "No pair record for their iPhone.": "Không có bản ghi ghép nối cho iPhone của họ.",
    "The link to their iPhone dropped — start again.":
        "Kết nối tới iPhone của họ đã rớt — hãy bắt đầu lại.",
    "Set up someone else's iPhone": "Thiết lập iPhone cho người khác",
    "Same Wi-Fi network": "Cùng một mạng Wi-Fi",
    "Their iPhone needs iOS %@ — SideInstaller pairs itself once it's installed, and nothing older can.":
        "iPhone của họ cần iOS %@: sau khi cài, SideInstaller tự ghép nối, còn các phiên bản cũ hơn thì không thể.",
    "Their iPhone": "iPhone của họ",
    "IP address (optional)": "Địa chỉ IP (không bắt buộc)",
    "Optional: leave it empty, and it fills in when their iPhone pairs.":
        "Không bắt buộc: để trống, địa chỉ sẽ tự điền khi iPhone của họ ghép nối.",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "Trên iPhone của họ: Cài đặt › Wi-Fi › ⓘ cạnh tên mạng, rồi xem “Địa chỉ IP”.",
    "This iPhone is %@, so theirs will look similar.":
        "iPhone này là %@, nên địa chỉ của họ sẽ tương tự.",
    "Apple ID to sign with": "Apple ID dùng để ký",
    "Tip: Use the iPhone/iPad owner's Apple account credentials":
        "Mẹo: Hãy dùng thông tin đăng nhập tài khoản Apple của chủ nhân iPhone/iPad",
    "Use my saved Apple ID instead": "Dùng Apple ID đã lưu của tôi",
    "Steps": "Các bước",
    "Waiting for them to tap Trust…": "Đang đợi họ chạm Tin cậy…",
    "Waiting for them to pair in Settings…":
        "Đang đợi họ ghép nối trong Cài đặt…",
    "Waiting for them to enter the code…":
        "Đang đợi họ nhập mã…",
    "Pair their iPhone in Settings":
        "Ghép nối iPhone của họ trong Cài đặt",
    "Their iPhone won't ask by itself — pairing starts from its Settings.":
        "iPhone của họ sẽ không tự hỏi — việc ghép nối bắt đầu từ Cài đặt của máy.",
    "On their iPhone, open Settings › Privacy & Security › Developer Mode.":
        "Trên iPhone của họ, mở Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển.",
    "Tap “Pair with %@”.":
        "Chạm vào “Ghép nối với %@”.",
    "Enter their iPhone’s passcode if it asks for it.":
        "Nhập mật mã iPhone của họ nếu được hỏi.",
    "Type the code that appears here into the prompt on their iPhone.":
        "Nhập mã hiển thị tại đây vào hộp thoại trên iPhone của họ.",
    "Type this into the prompt on their iPhone.":
        "Nhập mã này vào hộp thoại trên iPhone của họ.",
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "Họ đã chạm “Không tin cậy” trên iPhone của họ. Hãy bắt đầu lại và nhờ họ chạm Tin cậy.",
    "SideInstaller is already waiting for an iPhone to pair with it — from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "SideInstaller đang đợi một iPhone ghép nối với nó — từ thẻ Cài ứng dụng, trang Ghép nối, hoặc một lần thử trước ở đây. Hãy hoàn tất lần ghép nối đó, hoặc đóng rồi mở lại SideInstaller, sau đó thử lại.",
    "Pairing with their iPhone didn't finish: %@":
        "Ghép nối với iPhone của họ chưa hoàn tất: %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "iPhone của họ ở %@ đã từ chối kết nối. Máy chỉ chấp nhận khi bật Chế độ nhà phát triển, và iOS yêu cầu xác nhận lại sau mỗi lần khởi động lại: trên iPhone của họ, hãy bật trong Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển rồi thử lại.",
    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Không kết nối được tới iPhone của họ ở %@. Hãy kiểm tra địa chỉ (Cài đặt › Wi-Fi › ⓘ trên iPhone của họ), hai iPhone có cùng một mạng Wi-Fi không, và Mạng cục bộ đã được bật cho SideInstaller trong Cài đặt của iPhone này chưa. Mạng khách và mạng công cộng thường ngăn các thiết bị kết nối với nhau.",
    "The link to their iPhone didn't come up: %@":
        "Không mở được kết nối tới iPhone của họ: %@",
    "%d%% downloaded": "Đã tải %d%%",
    "%d%% uploaded": "Đã tải lên %d%%",
    "Start the install": "Bắt đầu cài đặt",
    "Install again": "Cài lại",
    "Clear their details": "Xóa thông tin của họ",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "iPhone này vẫn đang ghép nối với iPhone của họ. Xóa sẽ bỏ ghép nối đó.",
    "Last step: they trust %@": "Bước cuối: họ tin cậy %@",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "Trên iPhone của họ: Cài đặt › Cài đặt chung › VPN & Quản lý thiết bị.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "Chạm vào Apple ID trong mục “Ứng dụng nhà phát triển”, rồi chạm vào Tin cậy.",
    "Open it from their Home Screen — they're set up.":
        "Mở ứng dụng từ màn hình chính của họ — vậy là xong.",

    // MARK: - Settings

    "Settings": "Cài đặt",
    "Done": "Xong",
    "Language": "Ngôn ngữ",
    "App language": "Ngôn ngữ ứng dụng",
    "Sounds": "Âm thanh",
    "Sound effects": "Hiệu ứng âm thanh",
    "Auto": "Tự động",
    // The Tunnel section: starting LocalDevVPN from here.
    "Tunnel": "Đường hầm",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.":
        "Có thứ gì đó ở %@:%d đã từ chối kết nối, nghĩa là đường hầm vẫn thông — chỉ là thiết bị không lắng nghe trên cổng ghép nối của nó. Cổng đó chỉ mở khi bật Chế độ nhà phát triển, và iOS hỏi lại sau mỗi lần khởi động lại: hãy bật trong Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển rồi thử lại. Nếu đã bật, hãy ghép nối lại iPhone này trong “Tệp ghép nối”.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port: Developer Mode is off. Turn it on under Settings › Privacy & Security › Developer Mode (the iPhone restarts), then try again.":
        "Có thứ gì đó ở %@:%d đã từ chối kết nối, nghĩa là đường hầm vẫn thông, nhưng iPhone này không lắng nghe trên cổng ghép nối: Chế độ nhà phát triển đang tắt. Hãy bật trong Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển (iPhone sẽ khởi động lại) rồi thử lại.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port, although Developer Mode is on. Pair this iPhone again under “Pairing file”, then try again. If it still fails, restart the iPhone.":
        "Có thứ gì đó ở %@:%d đã từ chối kết nối, nghĩa là đường hầm vẫn thông, nhưng iPhone này không lắng nghe trên cổng ghép nối dù Chế độ nhà phát triển đang bật. Hãy ghép nối lại iPhone này trong “Tệp ghép nối” rồi thử lại. Nếu vẫn lỗi, hãy khởi động lại iPhone.",
    "Start LocalDevVPN when needed": "Khởi động LocalDevVPN khi cần",
    "Start LocalDevVPN now": "Khởi động LocalDevVPN ngay",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "Chưa cài LocalDevVPN. Hãy tải từ App Store, rồi SideInstaller có thể khởi động giúp bạn.",

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
    "Starts with %@": "Bắt đầu với %@",
    "Auto starts with the server that signed in last, then tries the others, the ones most likely to work first.":
        "Chế độ Tự động bắt đầu với máy chủ đã đăng nhập thành công gần nhất, sau đó thử các máy chủ khác, ưu tiên những máy chủ có khả năng hoạt động cao nhất.",
    "Only this server is tried. If it fails, so does sign-in: choose Auto to have SideInstaller try the others.":
        "Chỉ máy chủ này được thử. Nếu nó lỗi, đăng nhập cũng thất bại: chọn Tự động để SideInstaller thử các máy chủ khác.",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "Chỉ máy chủ đã chọn trong Cài đặt › Máy chủ Anisette được thử. Chọn Tự động ở đó để SideInstaller thử các máy chủ khác khi một máy chủ lỗi.",
    "Device IP": "IP thiết bị",
    "Advanced": "Nâng cao",
    "Clear": "Xóa hết",
    "Activity Log (%d)": "Nhật ký hoạt động (%d)",

    // Settings › Developer Mode: AMFI requests over the device link.
    "Developer Mode": "Chế độ nhà phát triển",
    "Show Developer Mode in Settings": "Hiện Chế độ nhà phát triển trong Cài đặt",
    "Turn on Developer Mode": "Bật Chế độ nhà phát triển",
    "Asking this iPhone…": "Đang hỏi iPhone này…",
    "Both need a link to this iPhone that already works: LocalDevVPN plus a pairing file, such as one imported on iOS 17.4 to 26. On iOS 27 the link itself needs Developer Mode, so they can't bring back a missing option there.":
        "Cả hai đều cần một kết nối tới iPhone này đã hoạt động sẵn: LocalDevVPN cùng một tệp ghép nối, chẳng hạn tệp được nhập trên iOS 17.4 đến 26. Trên iOS 27, chính kết nối đó cần Chế độ nhà phát triển, nên chúng không thể khôi phục tùy chọn đã biến mất.",
    "Turn on Developer Mode?": "Bật Chế độ nhà phát triển?",
    "Turn On and Restart": "Bật và khởi động lại",
    "This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode.":
        "iPhone này sẽ khởi động lại ngay. Sau khi mở khóa, hãy chạm Bật trong cảnh báo hiện ra. iOS chỉ cho phép việc này khi iPhone không có mật mã.",
    "Developer Mode is already on.": "Chế độ nhà phát triển đã bật sẵn.",
    "Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.":
        "Chế độ nhà phát triển giờ đã hiện trong Cài đặt › Quyền riêng tư & Bảo mật, gần cuối danh sách. Hãy bật nó ở đó, iOS sẽ khởi động lại để hoàn tất.",
    "Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.":
        "Chế độ nhà phát triển sẽ được bật và iPhone này khởi động lại ngay bây giờ. Sau khi mở khóa, hãy chạm Bật.",
    "An install is already running. Wait for it to finish, then try again.":
        "Đang có một lượt cài đặt chạy. Hãy đợi xong rồi thử lại.",
    "iOS turns Developer Mode on from here only while this iPhone has no passcode. Tap “Show Developer Mode in Settings” and turn it on there instead.":
        "iOS chỉ bật Chế độ nhà phát triển từ đây khi iPhone này không có mật mã. Hãy chạm “Hiện Chế độ nhà phát triển trong Cài đặt” rồi bật nó ở đó.",
    "This iPhone didn't take the Developer Mode request: %@":
        "iPhone này không nhận yêu cầu về Chế độ nhà phát triển: %@",

    // MARK: - Release channels & downloads

    "Stable": "Ổn định",
    "Nightly": "Nightly",

    // Version picker (Advanced)

    "%@ version": "Phiên bản %@",
    "Latest": "Mới nhất",
    "Latest (%@)": "Mới nhất (%@)",
    "Couldn't load the other versions: %@": "Không thể tải các phiên bản khác: %@",
    "Try again": "Thử lại",

    "couldn't find the IPA in the %@ %@ release":
        "không tìm thấy tệp IPA trong bản phát hành %@ của %@",
    "%@ has no %@ release right now": "%@ hiện không có bản phát hành %@ nào",
    "bad asset URL": "URL tệp tải không hợp lệ",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub đang giới hạn số yêu cầu từ mạng này — GitHub không bị chặn, và giới hạn sẽ tự hết. Hãy thử lại %@.",
    "GitHub answered HTTP %d%@": "GitHub đã trả về HTTP %d%@",
    "GitHub isn't serving %@ right now — the repository has been taken down, moved or made private, so there's nothing to download. Nothing is wrong with this iPhone or its network.":
        "GitHub hiện không cung cấp %@ — kho mã đã bị gỡ, chuyển đi hoặc chuyển thành riêng tư nên không có gì để tải. iPhone này và mạng của nó không có vấn đề gì.",
    "couldn't reach GitHub: %@": "không kết nối được tới GitHub: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "phản hồi của GitHub không phải là thông tin bản phát hành (%@) — có thể thứ gì đó trên mạng này đã thay thế nó.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "tệp tải về dưới tên %@ không phải là IPA — có thể thứ gì đó trên mạng này đã trả về một trang web, hoặc quá trình tải bị gián đoạn.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "liên kết đó trả về HTTP %d — không phải liên kết tải trực tiếp, hoặc cần đăng nhập.",
    "GitHub has no build of %@'s %@ branch to download right now.":
        "Hiện GitHub không có bản dựng nào của nhánh %2$@ thuộc %1$@ để tải xuống.",
    "couldn't download %@ through nightly.link, which passes on GitHub's builds: %@":
        "không thể tải %@ qua nightly.link, dịch vụ chuyển tiếp các bản dựng của GitHub: %@",
    "the %@ build that arrived isn't the file GitHub recorded, so it isn't installed. Try again later.":
        "bản dựng %@ nhận được không phải là tệp GitHub đã ghi nhận, nên sẽ không được cài đặt. Hãy thử lại sau.",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "Đã hủy xác minh hai yếu tố.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID hoặc mật khẩu không đúng. Hãy kiểm tra lại email và mật khẩu Apple Account của bạn rồi thử lại.",
    "Apple ID sign-in failed on %@. Error: %@":
        "Đăng nhập Apple ID thất bại trên %@. Lỗi: %@",
    "Apple ID sign-in failed on %@. Error via %@: %@":
        "Đăng nhập Apple ID thất bại trên %@. Lỗi qua %@: %@",
    "Apple's sign-in server refused the request (HTTP 503). It isn't your password or the anisette server, so trying more servers won't help. Try again later, or update SideInstaller.":
        "Máy chủ đăng nhập của Apple đã từ chối yêu cầu (HTTP 503). Lỗi không phải do mật khẩu hay máy chủ anisette, nên thử thêm máy chủ khác cũng không giúp được. Hãy thử lại sau hoặc cập nhật SideInstaller.",
    "“%@” makes its anisette data with Apple's Android library, and Apple now refuses to finish signing in through those servers (error -80046), after your password and code. In Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "“%@” tạo dữ liệu anisette bằng thư viện Android của Apple, và giờ Apple từ chối hoàn tất đăng nhập qua các máy chủ đó (lỗi -80046), sau khi bạn nhập mật khẩu và mã. Trong Cài đặt › Máy chủ Anisette, hãy chọn Tự động hoặc một máy chủ Mac như “SideStore (New)”.",
    "Apple refused to finish signing in (error -80046), even through a Mac anisette server, the kind it still accepted. Try again later, or check for a SideInstaller update.":
        "Apple đã từ chối hoàn tất đăng nhập (lỗi -80046), kể cả qua máy chủ anisette Mac, loại mà Apple vẫn chấp nhận. Hãy thử lại sau hoặc kiểm tra bản cập nhật SideInstaller.",
    "Apple refused to finish signing in through “%@” (error -80046). It now only accepts sign-ins through anisette servers on its macOS library: in Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "Apple đã từ chối hoàn tất đăng nhập qua “%@” (lỗi -80046). Giờ Apple chỉ chấp nhận đăng nhập qua các máy chủ anisette dùng thư viện macOS của Apple: trong Cài đặt › Máy chủ Anisette, hãy chọn Tự động hoặc một máy chủ Mac như “SideStore (New)”.",
    "Apple won't send a code by text or call to this sign-in, so it was sent to your Apple devices.":
        "Apple không gửi mã qua tin nhắn hoặc cuộc gọi cho lần đăng nhập này, nên mã đã được gửi đến thiết bị Apple của bạn.",
    "Apple didn't confirm sending a code to your Apple devices. If one arrived, enter it; if not, try another way.":
        "Apple chưa xác nhận đã gửi mã đến thiết bị Apple của bạn. Nếu đã nhận được mã, hãy nhập; nếu chưa, hãy thử cách khác.",
    "SideInstaller can't reach Apple's sign-in server (gsa.apple.com), though this iPhone has an internet connection. Something is blocking it: a firewall, a DNS filter or ad blocker, Screen Time content restrictions, or another VPN app. Turn it off or try another network, then try again.":
        "SideInstaller không kết nối được tới máy chủ đăng nhập của Apple (gsa.apple.com), dù iPhone này vẫn có kết nối internet. Có thứ gì đó đang chặn nó: tường lửa, bộ lọc DNS hoặc trình chặn quảng cáo, giới hạn nội dung trong Thời gian sử dụng, hoặc một ứng dụng VPN khác. Hãy tắt nó hoặc thử mạng khác, rồi thử lại.",
    "SideInstaller can't reach Apple: Cellular Data is turned off for it. Turn SideInstaller on in Settings › Cellular, or join a Wi-Fi network with internet access, then try again.":
        "SideInstaller không kết nối được tới Apple: Dữ liệu di động đang bị tắt cho ứng dụng này. Hãy bật SideInstaller trong Cài đặt › Di động, hoặc kết nối Wi-Fi có internet, rồi thử lại.",
    "SideInstaller can't reach Apple: iOS isn't letting it use Wi-Fi. In Settings › Apps › SideInstaller › Wireless Data, choose WLAN & Cellular Data, then try again.":
        "SideInstaller không kết nối được tới Apple: iOS không cho phép nó dùng Wi-Fi. Vào Cài đặt › Ứng dụng › SideInstaller › Dữ liệu không dây, chọn WLAN & Dữ liệu di động, rồi thử lại.",
    "SideInstaller can't reach Apple: a VPN set to carry all traffic is disconnected, so iOS is holding traffic back. Reconnect it, or turn off its kill switch or Connect On Demand, then try again.":
        "SideInstaller không kết nối được tới Apple: một VPN được đặt để chuyển toàn bộ lưu lượng đang bị ngắt kết nối, nên iOS đang giữ lại lưu lượng. Hãy kết nối lại, hoặc tắt kill switch hay Kết nối theo yêu cầu của nó, rồi thử lại.",
    "SideInstaller can't reach Apple: this iPhone has no internet connection. Connect to Wi-Fi or turn on cellular data, then try again.":
        "SideInstaller không kết nối được tới Apple: iPhone này không có kết nối internet. Hãy kết nối Wi-Fi hoặc bật dữ liệu di động, rồi thử lại.",
    "Apple is temporarily limiting sign-ins for this Apple ID or network (HTTP 429). Trying other servers won't help, and every attempt can extend the wait, so leave it a while before signing in again.":
        "Apple đang tạm thời giới hạn việc đăng nhập cho Apple ID hoặc mạng này (HTTP 429). Thử máy chủ khác cũng không giúp được, và mỗi lần thử có thể kéo dài thời gian chờ, nên hãy đợi một lúc rồi mới đăng nhập lại.",
    "If you're sure the password is right, Apple may be limiting sign-in attempts: wait a while before trying again.":
        "Nếu bạn chắc chắn mật khẩu đúng, có thể Apple đang giới hạn số lần đăng nhập: hãy đợi một lúc rồi thử lại.",
    "Apple has locked this Apple Account for security reasons (error -20209), so every sign-in fails until it's unlocked. Reset its password at iforgot.apple.com, then sign in again with the new password.":
        "Apple đã khóa Apple Account này vì lý do bảo mật (lỗi -20209), nên mọi lần đăng nhập đều thất bại cho đến khi tài khoản được mở khóa. Hãy đặt lại mật khẩu tại iforgot.apple.com, rồi đăng nhập lại bằng mật khẩu mới.",
    "the anisette server": "máy chủ anisette",
    "all %d anisette servers": "tất cả %d máy chủ anisette",
    "%d anisette servers (%d skipped)": "%d máy chủ anisette (bỏ qua %d)",
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
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ không phải là một IPA hợp lệ — có thể lượt tải về đã trả về một trang lỗi, hoặc việc sao chép bị dừng giữa chừng. Hãy thay tệp rồi chạm Cài đặt lại.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ không phải là IPA. Hãy chọn đúng tệp .ipa — nếu trông vẫn đúng thì có thể lượt tải đã lưu một trang lỗi, hoặc dừng giữa chừng.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Chưa nhập IPA nào. Hãy chạm “Nhập .ipa” và chọn một tệp.",
    "Couldn't import %@: %@": "Không thể nhập %@: %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "SideInstaller không tải được liên kết đó. Hãy dán đầy đủ địa chỉ https:// mà tệp .ipa được tải về.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "Liên kết đó không trả về IPA. Nó phải tải thẳng tệp về — một trang chỉ dẫn tới tệp .ipa, hoặc bắt đăng nhập trước, sẽ về đây dưới dạng trang web.",
    "Couldn't download that link: %@": "Không tải được liên kết đó: %@",
    "there's nothing to download for a custom IPA — import one first":
        "không có gì để tải cho IPA tùy chọn — hãy nhập một tệp trước",
    "your app": "ứng dụng của bạn",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple sẽ không cấp chứng chỉ ký cho Apple ID này: Apple báo rằng đã có một chứng chỉ, hoặc một yêu cầu vẫn đang chờ xử lý (lỗi 7460). SideInstaller không dùng lại được chứng chỉ sẵn có nên đã dừng lại thay vì thay thế nó. Xem các bước ở trên.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Không thể đăng ký iPhone này%@ vào nhóm phát triển của Apple ID, nên Apple sẽ không cấp hồ sơ cấp phép. %@ — xem các bước ở trên.",
    "Connect to Wi-Fi": "Kết nối Wi-Fi",
    "Open Settings › Wi-Fi and join a network.": "Mở Cài đặt › Wi-Fi và tham gia một mạng.",
    "Then come back here — this continues automatically.":
        "Sau đó quay lại đây: quá trình sẽ tự tiếp tục.",
    "Tap Connect so the toggle turns on.": "Chạm vào Connect để công tắc bật lên.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Giữ Wi-Fi bật rồi quay lại đây: quá trình sẽ tự tiếp tục.",
    "Get LocalDevVPN": "Tải LocalDevVPN",
    "Import an .ipa first": "Hãy nhập một .ipa trước",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Chạm “Nhập .ipa” ở trên và chọn tệp — tệp có thể nằm ở bất kỳ đâu mà app Tệp truy cập được, kể cả iCloud Drive hay ổ USB.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "Hoặc dán liên kết tải trực tiếp ngay dưới nút đó, SideInstaller sẽ tự tải tệp .ipa về.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "Hoặc mở ứng dụng Tệp, chạm giữ tệp .ipa, chọn Chia sẻ rồi chọn SideInstaller — tệp sẽ được chuyển sang mà không cần trình chọn tệp.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "Hoặc chép tệp vào Tệp › Trên iPhone của tôi › SideInstaller — SideInstaller cũng tìm thấy ở đó.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "Đây là lối đi ở những nơi GitHub bị chặn: tải IPA trên bất kỳ thiết bị nào, mang sang đây rồi cài đặt.",
    "Bring the .ipa yourself": "Tự mang tệp .ipa đến",
    "%@ can't be downloaded while its GitHub repository is offline. The other apps still install as usual.":
        "Không thể tải %@ khi kho mã của nó trên GitHub đang ngoại tuyến. Các ứng dụng khác vẫn cài được như bình thường.",
    "To install it anyway, get its .ipa from somewhere you trust, name it %@, and copy it into Files › On My iPhone › SideInstaller.":
        "Để vẫn cài được, hãy lấy tệp .ipa của nó từ một nguồn bạn tin cậy, đặt tên là %@ rồi chép vào Tệp › Trên iPhone của tôi › SideInstaller.",
    "Then tap Install again — SideInstaller uses your file instead of downloading one.":
        "Sau đó chạm vào Cài ứng dụng lần nữa — SideInstaller sẽ dùng tệp của bạn thay vì tải về.",
    "Pair this iPhone in Settings": "Ghép nối iPhone này trong Cài đặt",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Mở ứng dụng Cài đặt, rồi vào Quyền riêng tư & Bảo mật › Chế độ nhà phát triển.",
    "Tap “Pair with SideInstaller”.": "Chạm vào “Ghép nối với SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.": "Nhập mật mã iPhone của bạn nếu được hỏi.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Quay lại SideInstaller, xem mã mà ứng dụng hiển thị, rồi nhập đúng mã đó vào hộp thoại trong Cài đặt.",
    "Type the code that appears at the top of the screen into the prompt in Settings. If none appears, come back to SideInstaller to read it.":
        "Nhập mã hiện ở đầu màn hình vào hộp thoại trong Cài đặt. Nếu không thấy mã, hãy quay lại SideInstaller để xem.",
    "Allow notifications when SideInstaller asks: that's how the pairing code reaches you in Settings.":
        "Hãy cho phép thông báo khi SideInstaller hỏi: mã ghép nối sẽ đến với bạn trong Cài đặt bằng cách đó.",

    // The pairing Live Activity
    "Privacy & Security › Developer Mode › Pair with SideInstaller":
        "Quyền riêng tư & Bảo mật › Chế độ nhà phát triển › Ghép nối với SideInstaller",
    "Paired": "Đã ghép nối",
    "Tap to return to SideInstaller.": "Chạm để quay lại SideInstaller.",

    // The install's progress outside the app
    "Installing %@": "Đang cài đặt %@",
    "Paused": "Đã tạm dừng",
    "Open SideInstaller to finish the install.":
        "Mở SideInstaller để hoàn tất cài đặt.",
    "Check the App IDs it needs, then tap Install.":
        "Kiểm tra các App ID cần dùng, rồi chạm vào Cài ứng dụng.",
    "Tap Trust": "Chạm vào Tin cậy",
    "Unlock this iPhone and tap Trust when it asks.":
        "Mở khóa iPhone này và chạm vào Tin cậy khi được hỏi.",

    "A signing certificate already exists": "Đã có một chứng chỉ ký",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Apple trả về lỗi 7460: Apple ID này đã có chứng chỉ phát triển iOS, hoặc một yêu cầu vẫn đang chờ xử lý.",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideInstaller không dùng lại được chứng chỉ đó. Điều này xảy ra khi chứng chỉ được cấp ở nơi khác — AltStore, SideStore, Sideloadly hoặc Xcode trên một thiết bị khác — nên khoá riêng tư cần thiết không có trên iPhone này.",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "Dùng “Thu hồi và thử lại” ở trên, hoặc mở Chứng chỉ trong thẻ Công cụ, chạm “Tải danh sách chứng chỉ” rồi thu hồi ở đó.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "Thu hồi là vĩnh viễn: mọi ứng dụng đã ký bằng chứng chỉ đó sẽ không mở được nữa, trên mọi thiết bị.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Hoặc đăng nhập bằng một Apple ID khác (hoặc tài khoản dự phòng) ở trên, rồi chạm vào Cài đặt lần nữa.",

    // MARK: - Guide cards

    // Guide: reset a locked Apple Account

    "Reset your Apple Account password": "Đặt lại mật khẩu Apple Account",
    "Apple has locked this Apple Account for security reasons, often after too many sign-in attempts. Every sign-in fails until it's unlocked, so tapping Install again won't help yet.":
        "Apple đã khóa Apple Account này vì lý do bảo mật, thường là sau quá nhiều lần thử đăng nhập. Mọi lần đăng nhập đều thất bại cho đến khi tài khoản được mở khóa, nên lúc này chạm vào Cài ứng dụng lần nữa chưa có tác dụng.",
    "Open iForgot, enter this Apple Account's email, and follow Apple's steps to unlock it and reset its password.":
        "Mở iForgot, nhập email của Apple Account này và làm theo các bước của Apple để mở khóa và đặt lại mật khẩu.",
    "Back in SideInstaller, open Settings › Account, swipe left on this Apple ID, tap Edit, and enter the new password.":
        "Quay lại SideInstaller, mở Cài đặt › Tài khoản, vuốt sang trái trên Apple ID này, chạm vào Sửa rồi nhập mật khẩu mới.",
    "Then tap Install again.": "Sau đó chạm vào Cài ứng dụng lần nữa.",
    "Open iForgot": "Mở iForgot",
    "Apple won't let this Apple Account use developer services because of its owner's age (error 1102). Sign in with an adult's Apple Account instead.":
        "Apple không cho Apple Account này dùng dịch vụ dành cho nhà phát triển vì tuổi của chủ tài khoản (lỗi 1102). Hãy đăng nhập bằng Apple Account của một người lớn.",
    "This Apple ID has no App IDs left (error 9120). A free Apple ID can register 10 a week, and each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Apple ID này đã hết App ID (lỗi 9120). Apple ID miễn phí chỉ đăng ký được 10 App ID mỗi tuần, và mỗi App ID được tính trong 7 ngày, nên hãy đợi một số hết hạn hoặc đăng nhập bằng Apple ID khác.",
    "This iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. Delete one of them, then try again.":
        "iPhone này đã có ba ứng dụng ký bằng Apple ID miễn phí, mức tối đa iOS cho phép, kể cả ứng dụng đã hết hạn. Hãy xóa một ứng dụng rồi thử lại.",
    "This Apple Account can't sign apps":
        "Apple Account này không thể ký ứng dụng",
    "Apple only lets adults use the developer services SideInstaller signs apps with, and it reports that this Apple Account belongs to someone younger (error 1102).":
        "Apple chỉ cho người lớn dùng dịch vụ dành cho nhà phát triển mà SideInstaller dùng để ký ứng dụng, và Apple cho biết Apple Account này thuộc về người chưa đủ tuổi (lỗi 1102).",
    "Sign in with an adult's Apple Account instead: open Settings › Account and add it there.":
        "Hãy đăng nhập bằng Apple Account của một người lớn: mở Cài đặt › Tài khoản và thêm tài khoản đó vào.",
    "Apple won't let this Apple Account use developer services until its email address is verified (error 2160). Verify it at account.apple.com, then try again.":
        "Apple không cho Apple Account này dùng dịch vụ dành cho nhà phát triển cho đến khi địa chỉ email của tài khoản được xác minh (lỗi 2160). Hãy xác minh tại account.apple.com rồi thử lại.",
    "Verify your Apple Account's email":
        "Xác minh email của Apple Account",
    "Apple won't let this Apple Account sign apps until its email address is verified (error 2160). Signing in again or through another anisette server won't change that.":
        "Apple không cho Apple Account này ký ứng dụng cho đến khi địa chỉ email của tài khoản được xác minh (lỗi 2160). Đăng nhập lại hay dùng máy chủ anisette khác cũng không thay đổi được điều đó.",
    "Sign in at account.apple.com with this Apple Account and verify its email address when Apple asks. Apple sends the code or link to that address, so check its spam folder too.":
        "Đăng nhập account.apple.com bằng Apple Account này và xác minh địa chỉ email khi Apple yêu cầu. Apple gửi mã hoặc liên kết đến địa chỉ đó, nên hãy kiểm tra cả thư mục thư rác.",
    "Open Apple Account":
        "Mở Apple Account",
    "No App IDs left this week": "Đã hết App ID trong tuần này",
    "Every app SideInstaller signs needs an App ID, which its extensions share. A free Apple ID can register 10 a week, and each one counts for 7 days.":
        "Mỗi ứng dụng mà SideInstaller ký đều cần một App ID, và các tiện ích mở rộng của nó dùng chung App ID đó. Apple ID miễn phí chỉ đăng ký được 10 App ID mỗi tuần, và mỗi App ID được tính trong 7 ngày.",
    "They can't be deleted sooner. Wait until some expire, then tap Install again.":
        "Không thể xóa chúng sớm hơn. Hãy đợi một số hết hạn, rồi chạm vào Cài ứng dụng lần nữa.",
    "Or sign in with a different (or spare) Apple ID in Settings › Account, then tap Install again.":
        "Hoặc đăng nhập bằng một Apple ID khác (hoặc tài khoản dự phòng) trong Cài đặt › Tài khoản, rồi chạm vào Cài ứng dụng lần nữa.",
    "Three sideloaded apps already": "Đã có ba ứng dụng sideload",
    "iOS allows three apps signed with a free Apple ID on an iPhone at a time, and it refused a fourth.":
        "iOS chỉ cho phép ba ứng dụng ký bằng Apple ID miễn phí trên một iPhone cùng lúc, và đã từ chối ứng dụng thứ tư.",
    "Expired apps count too. Delete one you no longer need from the Home Screen.":
        "Ứng dụng đã hết hạn cũng được tính. Hãy xóa một ứng dụng bạn không cần nữa khỏi Màn hình chính.",

    // Guide: import a pairing file

    "Import a pairing file": "Nhập một tệp ghép nối",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@ là phiên bản đầu tiên mà iPhone có thể tự ghép nối. Trên máy này, tệp ghép nối phải được tạo trên máy tính.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "Trên Mac, PC Windows hoặc Linux, cắm iPhone này vào, tin cậy máy tính rồi chạy jitterbugpair (hoặc “pymobiledevice3 lockdown pair”).",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "Gửi tệp thu được — một .mobiledevicepairing hoặc .plist — sang iPhone này bằng AirDrop, iCloud Drive hoặc cáp.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "Quay lại đây, chạm “Nhập tệp ghép nối” và chọn tệp. Sau đó mọi thứ hoạt động giống như trên iOS %@.",
    "Get jitterbugpair": "Tải jitterbugpair",
    "From iOS 26.4 on it has to be a remote pairing file: this iPhone hangs up on lockdown ones, like jitterbugpair's, when they come through LocalDevVPN.":
        "Từ iOS 26.4, đó phải là tệp “Remote pairing”: iPhone này ngắt kết nối với các tệp lockdown, như tệp của jitterbugpair, khi chúng đi qua LocalDevVPN.",
    "Get idevice_pair": "Tải idevice_pair",
    "Make a remote pairing file": "Tạo một tệp “Remote pairing”",
    "The pairing file you imported is a lockdown one. Since iOS 26.4, this iPhone hangs up on those when they come through LocalDevVPN, so it can't connect, and a new one of the same kind won't either.":
        "Tệp ghép nối bạn đã nhập là loại lockdown. Từ iOS 26.4, iPhone này ngắt kết nối với các tệp đó khi chúng đi qua LocalDevVPN, nên tệp này không kết nối được, và một tệp mới cùng loại cũng vậy.",
    "Come back here, tap “Replace” on the Pairing file card, and pick it.":
        "Quay lại đây, chạm “Thay” trên thẻ “Tệp ghép nối” và chọn tệp đó.",
    "On a Mac, Windows PC or Linux box, open idevice_pair, plug this iPhone in, and tap Trust if it asks. Pick it, choose “Remote pairing”, click “Create”, and keep this iPhone unlocked until it's done.":
        "Trên Mac, PC Windows hoặc Linux, mở idevice_pair, cắm iPhone này vào và chạm Tin cậy nếu được hỏi. Chọn iPhone này, chọn “Remote pairing”, bấm “Create” và giữ iPhone này ở trạng thái mở khóa cho đến khi xong.",
    "Click “Save to file…” and send the file to this iPhone, by AirDrop, iCloud Drive or a cable. A pairing file exported from iLoader works too.":
        "Bấm “Save to file…” rồi gửi tệp sang iPhone này bằng AirDrop, iCloud Drive hoặc cáp. Tệp ghép nối xuất từ iLoader cũng dùng được.",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "Đã có một chứng chỉ",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple sẽ không cấp chứng chỉ ký thứ hai cho Apple ID này. Thu hồi chứng chỉ sẵn có sẽ giúp quá trình cài đặt tiếp tục — nhưng không thể hoàn tác.",
    "Loading certificates": "Đang tải chứng chỉ",
    "Revoke and retry": "Thu hồi và thử lại",
    "Which certificate should be revoked?": "Bạn muốn thu hồi chứng chỉ nào?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple báo rằng Apple ID này có chứng chỉ, nhưng danh sách trả về lại trống. Có thể đó là một yêu cầu vẫn đang chờ xử lý — hãy đợi vài phút rồi chạm Cài đặt lại.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "Mọi ứng dụng đã ký bằng chứng chỉ bạn chọn sẽ không mở được nữa, trên mọi thiết bị — kể cả ứng dụng cài bằng AltStore, SideStore hoặc từ máy tính. Không thể hoàn tác. Quá trình cài đặt sẽ thử lại ngay sau đó.",
    " (expired)": " (đã hết hạn)",

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
    "If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one.":
        "Nếu bạn đã đổi địa chỉ của LocalDevVPN, hãy sao chép Device IP của nó vào đây — kể cả phần /32, nếu có hiển thị.",
    "Device IP is %@, one of this iPhone's own addresses, and iOS won't let an app connect to those. In Settings › Advanced, set Device IP to the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default, not the “Connected to” address on its main screen.":
        "IP thiết bị đang là %@, một trong các địa chỉ của chính iPhone này, và iOS không cho ứng dụng kết nối tới các địa chỉ đó. Trong Cài đặt › Nâng cao, hãy đặt IP thiết bị thành địa chỉ ở Cài đặt › Device IP của LocalDevVPN (mặc định là 10.7.0.1), không phải địa chỉ sau “Connected to” trên màn hình chính của nó.",
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "iOS đã từ chối kết nối tới %@ ngay trên iPhone này, trước khi bất cứ thứ gì được gửi đi. iOS làm vậy với các địa chỉ của chính iPhone này, như địa chỉ sau “Connected to” trên màn hình chính của LocalDevVPN. IP thiết bị, trong Cài đặt › Nâng cao, phải là địa chỉ ở Cài đặt › Device IP của LocalDevVPN (mặc định là 10.7.0.1). Nếu đã đúng như vậy, hãy tắt rồi bật lại LocalDevVPN, sau đó thử lại.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "iPhone này đã ngắt kết nối ngay khi nó vừa mở. Từ iOS 26.4, nó làm vậy với các tệp ghép nối lockdown, như tệp này, khi chúng đi qua LocalDevVPN. Thay vào đó, hãy ghép nối iPhone này với chính nó: chạm “Tạo lại” trong Công cụ › Ghép nối, hoặc chạm Cài ứng dụng, thao tác này sẽ ghép nối trước.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "iPhone này đã ngắt kết nối ngay khi nó vừa mở. Từ iOS 26.4, nó làm vậy với các tệp ghép nối lockdown, như tệp này, khi chúng đi qua LocalDevVPN, nên tạo một tệp mới cùng loại cũng không giúp được gì. Tệp ghép nối “Remote pairing” vẫn dùng được: trên máy tính, mở idevice_pair, chọn “Remote pairing”, bấm “Create”, rồi “Save to file…”, và nhập tệp đó trong “Tệp ghép nối”.",
    "This iPhone hung up on the connection: from iOS 26.4 on, it does that to lockdown pairing files like this one when they come through LocalDevVPN. See the steps above.":
        "iPhone này đã ngắt kết nối: từ iOS 26.4, nó làm vậy với các tệp ghép nối lockdown như tệp này khi chúng đi qua LocalDevVPN. Xem các bước ở trên.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Việc ghép nối iPhone này cần đến nó: SideInstaller quảng bá chính mình trên mạng nội bộ để Cài đặt tìm thấy.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Hãy kết nối vào một mạng Wi-Fi. Việc ghép nối iPhone này cần đến nó — SideInstaller phải tìm thấy được trên mạng nội bộ.",

    // MARK: - About

    "About": "Giới thiệu",
    "Version %@ (%@)": "Phiên bản %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller cài SideStore và LiveContainer thẳng vào iPhone của bạn, không cần đến máy tính.",

    "Links": "Liên kết",
    "Source code": "Mã nguồn",
    "Support the project": "Ủng hộ dự án",
    "Crypto": "Tiền mã hóa",
    "Donation wallets for Bitcoin, Ethereum and Solana.":
        "Ví nhận ủng hộ cho Bitcoin, Ethereum và Solana.",
    "Crypto donations": "Ủng hộ bằng tiền mã hóa",
    "Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you.":
        "Việc ủng hộ hoàn toàn là tự nguyện. Khoản ủng hộ không dùng để mua gì, không mở khóa tính năng nào và bạn không nhận lại gì cả; đó chỉ là một cách để cảm ơn nếu SideInstaller đã giúp ích cho bạn.",
    "Coin": "Đồng tiền",
    "Network: %@": "Mạng: %@",
    "QR code for the %@ address": "Mã QR của địa chỉ %@",
    "Copied": "Đã sao chép",
    "Send each coin only on the network shown. Crypto sent on another network can't be recovered.":
        "Chỉ gửi mỗi đồng tiền qua đúng mạng được ghi. Tiền mã hóa gửi qua mạng khác sẽ không thể khôi phục.",

    "Special thanks": "Lời cảm ơn đặc biệt",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "Vì idevice, thư viện mà SideInstaller dùng để giao tiếp với iPhone của bạn. Không có nó thì mọi thứ này đều không tồn tại.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Vì đã hỗ trợ và phát hiện những lỗi sau đó được sửa.",
    "For the Japanese translation.": "Vì bản dịch tiếng Nhật.",
    "For the Korean translation.": "Vì bản dịch tiếng Hàn.",

    "Built with": "Được xây dựng với",
    "The open source work this app is built on:":
        "Những dự án mã nguồn mở mà ứng dụng này dựa trên:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "Ghép nối, đường hầm và chính việc cài đặt. Của jkcoxson, giấy phép MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Đăng nhập Apple ID, chứng chỉ và ký ngay trên máy. Của nab138, giấy phép MIT.",
    "The sideloading app this installs for you.":
        "Ứng dụng sideload mà ứng dụng này cài giúp bạn.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Chạy các ứng dụng sideload mà không tốn một suất ứng dụng cho mỗi cái.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "Ảnh đĩa nhà phát triển mà chức năng giả lập vị trí gắn kết. Được doronz88 lưu bản sao.",

    "Where to get it": "Nơi tải ứng dụng",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "Chỉ những bản dựng trên trang cài đặt và kho mã chính thức mới là của tôi. Bất kỳ ai cũng có thể fork mã nguồn, thêm mã đánh cắp thông tin đăng nhập rồi phát hành với cùng tên và biểu tượng — vì vậy đừng giao Apple ID của bạn cho một bản sao lấy từ nơi khác.",
    "Install page": "Trang cài đặt",
    "Terms": "Điều khoản",

    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.":
        "%@ cần iOS %d trở lên. iPhone này đang chạy iOS %@.",
    "Open Madeira from your Home Screen.": "Mở Madeira từ Màn hình chính.",
    "In its setup, under “Set up JIT”, pick “In-app with pairing file”: SideInstaller already put the file there, so tap “Continue”.":
        "Trong phần thiết lập của nó, ở mục “Set up JIT”, chọn “In-app with pairing file”: SideInstaller đã đặt sẵn tệp ở đó, nên hãy chạm vào “Continue”.",
    "In its setup, under “Set up JIT”, pick how this iPhone gets JIT.":
        "Trong phần thiết lập của nó, ở mục “Set up JIT”, chọn cách iPhone này có JIT.",
    "Madeira renews its own signing from now on, when it's open and LocalDevVPN is connected. SideInstaller gave it a sign-in for that: a token for Apple's developer service, not your password. Madeira can forget it under Settings › Signing.":
        "Từ giờ Madeira tự gia hạn chữ ký của mình, khi nó đang mở và LocalDevVPN đang kết nối. SideInstaller đã cấp cho nó một phiên đăng nhập để làm việc đó: một token cho dịch vụ nhà phát triển của Apple, không phải mật khẩu của bạn. Madeira có thể xoá nó trong Settings › Signing.",
    "Its signing lasts 7 days. Before they run out, refresh it here under Tools › Sideloaded apps.":
        "Chữ ký của nó có hiệu lực 7 ngày. Trước khi hết hạn, hãy gia hạn tại đây trong Công cụ › Ứng dụng sideload.",
    "This pairing file has no RPPairing record, the only kind %@ reads.":
        "Tệp ghép nối này không có bản ghi RPPairing, loại duy nhất mà %@ đọc được.",
    "Runs Windows PC games on your iPhone. By Will Faust, GPL-3.0.":
        "Chạy game PC Windows trên iPhone của bạn. Của Will Faust, giấy phép GPL-3.0.",

    // MARK: - App ID cost

    "App IDs for this app": "App ID cho ứng dụng này",
    "Cost": "Cần dùng",
    "Left now": "Còn lại",
    "Left after": "Còn sau đó",
    "New App IDs": "App ID mới",
    "This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Apple ID này không còn đủ App ID: ứng dụng này cần %d, nhưng chỉ còn %d. Mỗi App ID được tính trong 7 ngày, nên hãy chờ vài App ID hết hạn hoặc đăng nhập bằng Apple ID khác.",
    "The next one frees up on %@.": "App ID tiếp theo được giải phóng vào %@.",
    "Your Apple ID already has every App ID this app needs, so installing it uses none.":
        "Apple ID của bạn đã có mọi App ID mà ứng dụng này cần, nên cài nó không tốn App ID nào.",
    "Signing registers one App ID for the app, and its extensions share it. It counts for 7 days.":
        "Khi ký, chỉ một App ID được đăng ký cho ứng dụng, và các tiện ích mở rộng của nó dùng chung App ID này. App ID đó được tính trong 7 ngày.",
    "This Apple ID can register %d a week.":
        "Apple ID này đăng ký được %d App ID mỗi tuần.",

    // MARK: - Links (sideinstaller://install, sideinstaller://pairingFile)

    "Install from a link?": "Cài đặt từ liên kết?",
    "Download and install": "Tải xuống và cài đặt",
    "SideInstaller will download this .ipa, then sign it with your Apple ID and install it. Only go ahead if you trust where the link came from.":
        "SideInstaller sẽ tải .ipa này xuống, ký bằng Apple ID của bạn rồi cài đặt. Chỉ tiếp tục nếu bạn tin nguồn của liên kết.",
    "It replaces %@, the custom .ipa you have now.": "Nó sẽ thay %@, IPA tùy chọn bạn đang có.",
    "Use SideStore's pairing file?": "Dùng tệp ghép nối của SideStore?",
    "Import this pairing file?": "Nhập tệp ghép nối này?",
    "Import": "Nhập",
    "SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.":
        "SideStore đã gửi lại tệp ghép nối nó đang có. SideInstaller sẽ dùng tệp này để kết nối với iPhone này.",
    "A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.":
        "Một liên kết đã gửi cho SideInstaller một tệp ghép nối. Chỉ nhập nếu chính bạn đã yêu cầu: SideInstaller sẽ dùng tệp này để kết nối với iPhone này.",
    "It replaces %@.": "Nó sẽ thay %@.",
    "It replaces the pairing file in use now.": "Nó sẽ thay tệp ghép nối đang dùng.",
    "Get it from SideStore": "Lấy từ SideStore",
    "SideStore opens and sends back the pairing file it has.":
        "SideStore sẽ mở ra và gửi lại tệp ghép nối nó đang có.",
    "SideStore isn't installed on this iPhone, so there's no pairing file to get from it.":
        "SideStore chưa được cài trên iPhone này, nên không có tệp ghép nối nào để lấy.",
    "That install link has no .ipa in it. It needs ?url= followed by the https:// address the .ipa downloads from.":
        "Liên kết cài đặt đó không chứa .ipa nào. Nó cần ?url= theo sau là địa chỉ https:// để tải .ipa.",
    "That link was meant to carry a pairing file, but what it holds can't be read.":
        "Liên kết đó lẽ ra chứa một tệp ghép nối, nhưng không đọc được nội dung.",
    "That link carries a file, but it isn't a pairing file.":
        "Liên kết đó có chứa một tệp, nhưng không phải tệp ghép nối.",

    // MARK: - Report a problem

    "Report a problem": "Báo cáo sự cố",
    "Report this problem": "Báo cáo sự cố này",
    "Opens a GitHub issue with this app's details, its log and crash logs.":
        "Mở một issue trên GitHub kèm thông tin ứng dụng, nhật ký và nhật ký sự cố.",
    "What happened?": "Đã xảy ra chuyện gì?",
    "What were you doing, and what went wrong?": "Bạn đang làm gì, và điều gì đã bị lỗi?",
    "Say what you tapped, what you expected and what happened instead. English is best, but any language is fine.":
        "Hãy kể bạn đã nhấn gì, bạn mong đợi điều gì và điều gì đã xảy ra. Tiếng Anh là tốt nhất, nhưng ngôn ngữ nào cũng được.",
    "Included": "Đính kèm",
    "Device": "Thiết bị",
    "App": "Ứng dụng",
    "Stopped at": "Dừng ở",
    "not connected": "chưa kết nối",
    "none": "không có",
    "made on this iPhone": "tạo trên iPhone này",
    "Runs inside LiveContainer": "Chạy bên trong LiveContainer",
    "on": "bật",
    "off": "tắt",
    "unknown": "không rõ",
    "yes": "có",
    "no": "không",
    "latest": "mới nhất",
    "custom server": "máy chủ tùy chỉnh",
    "Auto, starts with %@": "Tự động, bắt đầu với %@",
    "Error": "Lỗi",
    "Activity log": "Nhật ký hoạt động",
    "%d lines": "%d dòng",
    "Your Apple ID, device name, serial numbers and keys are taken out of the log first.":
        "Apple ID, tên thiết bị, số sê-ri và khóa được xóa khỏi nhật ký trước.",
    "Crash logs": "Nhật ký sự cố",
    "Looking for crash logs …": "Đang tìm nhật ký sự cố …",
    "Look for crash logs on this iPhone": "Tìm nhật ký sự cố trên iPhone này",
    "Look again": "Tìm lại",
    "No crash logs from SideStore, LiveContainer or Madeira in the last %d days.":
        "Không có nhật ký sự cố nào của SideStore, LiveContainer hoặc Madeira trong %d ngày qua.",
    "iOS hands SideInstaller its own crashes the next time it opens. Crash logs from SideStore, LiveContainer and Madeira are read from this iPhone through LocalDevVPN.":
        "iOS chuyển các sự cố của chính SideInstaller cho ứng dụng vào lần mở tiếp theo. Nhật ký sự cố của SideStore, LiveContainer và Madeira được đọc từ iPhone này qua LocalDevVPN.",
    "Open a GitHub issue": "Mở issue trên GitHub",
    "Share the report": "Chia sẻ báo cáo",
    "Preview the report": "Xem trước báo cáo",
    "Report": "Báo cáo",
    "The issue opens filled in. When the log is too long for that, SideInstaller copies it for you to paste at the end of the issue. The whole report is also saved in %@.":
        "Issue mở ra với nội dung đã điền sẵn. Khi nhật ký quá dài để điền, SideInstaller sẽ sao chép nó để bạn dán vào cuối issue. Toàn bộ báo cáo cũng được lưu trong %@.",
    "Files › On My iPhone": "Tệp › Trên iPhone của tôi",
    "Copy the full log": "Sao chép toàn bộ nhật ký",
    "Paste the log into the issue": "Dán nhật ký vào issue",
    "Open GitHub": "Mở GitHub",
    "The full log is too long to fill in, so SideInstaller copied it. On GitHub, tap the end of the text, choose Paste, then submit the issue.":
        "Nhật ký đầy đủ quá dài để điền sẵn, nên SideInstaller đã sao chép nó. Trên GitHub, chạm vào cuối văn bản, chọn Dán, rồi gửi issue.",
    "Describe the problem above first.": "Hãy mô tả sự cố ở trên trước.",
    "Couldn't save the report: %@": "Không thể lưu báo cáo: %@",

    // MARK: - Official download check

    "Did you download SideInstaller from sideinstaller.net?":
        "Bạn đã tải SideInstaller từ sideinstaller.net phải không?",
    "SideInstaller is open source, so anyone can publish a modified copy that steals the Apple ID typed into it. Only sideinstaller.net is official.":
        "SideInstaller là mã nguồn mở, nên bất kỳ ai cũng có thể phát hành một bản đã chỉnh sửa để đánh cắp Apple ID được nhập vào. Chỉ sideinstaller.net là chính thức.",
    "Yes, from sideinstaller.net":
        "Có, từ sideinstaller.net",
    "No, or I'm not sure":
        "Không, hoặc tôi không chắc",
    "Don't sign in with this copy":
        "Đừng đăng nhập bằng bản này",
    "Copies from anywhere other than sideinstaller.net are unofficial and may have been changed to steal your Apple ID. Delete this one and install SideInstaller from sideinstaller.net, then sign in there.":
        "Các bản tải từ nơi khác ngoài sideinstaller.net không chính thức và có thể đã bị chỉnh sửa để đánh cắp Apple ID của bạn. Hãy xoá bản này, cài SideInstaller từ sideinstaller.net rồi đăng nhập ở đó.",
    "Open sideinstaller.net":
        "Mở sideinstaller.net",
    "Back":
        "Quay lại",
    "I understand the risks":
        "Tôi hiểu các rủi ro",
    "Use an unofficial copy?":
        "Dùng bản không chính thức?",
    "If this copy was changed, it can send your Apple ID and password to someone else. Continue only if you trust where it came from.":
        "Nếu bản này đã bị chỉnh sửa, nó có thể gửi Apple ID và mật khẩu của bạn cho người khác. Chỉ tiếp tục nếu bạn tin tưởng nguồn tải.",
]
