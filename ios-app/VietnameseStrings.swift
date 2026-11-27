import Foundation

/// Vietnamese translations (same rules as `spanishStrings`). The Install tab is
/// "Cài ứng dụng" because "Cài đặt" means Settings. Nouns don't inflect for
/// number, so singular and plural app-count strings are the same.

let vietnameseStrings: [String: String] = [

    // MARK: - Shared

    "Expiry date": "Ngày hết hạn",
    "Signed date": "Ngày ký",
    "Bundle ID": "Bundle ID",
    "Not enough free space on this iPhone to download this IPA — it needs %@, but only %@ is free. Free some space and try again.":
        "iPhone này không còn đủ dung lượng trống để tải IPA này — cần %@, nhưng chỉ còn %@. Hãy giải phóng dung lượng rồi thử lại.",
    "Free space: %@": "Dung lượng trống: %@",
    "Apple ID":
        "Apple ID",
    "Cancel": "Hủy",
    "Copy": "Sao chép",
    "Copy logs": "Sao chép nhật ký",
    "Email": "Email",
    "No unsigned IPA in the library.":
        "Không có IPA chưa ký nào trong thư viện.",
    "Once the install starts, tap the Install button at the bottom to see progress.":
        "Sau khi quá trình cài đặt bắt đầu, chạm vào nút Cài ứng dụng ở phía dưới để xem tiến độ.",
    "Password": "Mật khẩu",
    "Install": "Cài ứng dụng",
    // U-UI (0.9.102): new tab bar / source + file list redesign.
    "Apps": "Ứng dụng",
    "Pick an IPA to install with your Apple ID.":
        "Chọn một IPA để cài đặt bằng ID Apple của bạn.",
    "Signing method":
        "Phương thức ký",
    "Sources": "Nguồn",
    "AppStore": "AppStore",
    "企业证书":
        "Chứng chỉ doanh nghiệp",
    "用 Apple ID 安装":
        "Cài đặt bằng ID Apple",
    "软件源": "Nguồn phần mềm",
    "文件列表": "Danh sách tệp",
    "筛选": "Lọc",
    "正在刷新数据中…": "Đang làm mới dữ liệu…",
    "最后更新：%@": "Cập nhật lần cuối: %@",
    "应用文件夹库": "Thư viện thư mục ứng dụng",
    "应用 - %@": "Ứng dụng - %@",
    "No downloaded IPAs. Ones you install from a source or a file are cached here.": "Chưa có IPA nào được tải xuống. Các IPA cài từ nguồn hoặc tệp sẽ được lưu đệm tại đây.",
    "%d 个 IPA · %@": "%d IPA · %@",
    "清空全部": "Xóa tất cả",
    "清空全部 %d 个下载？": "Xóa tất cả %d lượt tải xuống?",
    "还没有文件。点上面「导入文件」放 IPA 进来，或在源页面下载后这里会出现。": "Chưa có tệp nào. Nhấn «Nhập tệp» ở trên để thêm IPA, hoặc tải xuống từ trang nguồn.",
    "文件库里还没有没签过的 IPA。去文件页导入一个，或者去设置里的企业证书页点「从文件导入」。": "Thư viện chưa có IPA nào chưa ký. Hãy nhập một IPA từ trang Tệp, hoặc nhấn «Nhập từ tệp» trên trang chứng chỉ doanh nghiệp trong Cài đặt.",
    "先去设置里的企业证书页，把证书、描述文件和密码备齐。": "Trước tiên, hãy chuẩn bị chứng chỉ, hồ sơ và mật khẩu trên trang chứng chỉ doanh nghiệp trong Cài đặt.",
    "还没有已签名的 IPA。用设置里企业证书页的「仅签名」签好就会存到这里，随时能装、能分享。": "Chưa có IPA nào đã ký. Hãy ký một IPA bằng «Chỉ ký» trên trang chứng chỉ doanh nghiệp trong Cài đặt: nó sẽ được lưu tại đây, sẵn sàng cài đặt và chia sẻ.",
    "Installing": "Đang cài đặt",
    "Installed": "Đã cài đặt",
    "Install history": "Lịch sử cài đặt",
    "No installs yet.": "Chưa có lượt cài đặt nào.",
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

    // iOS 27 runs on this iPhone: recommended at setup

    "Update to iOS %@": "Cập nhật lên iOS %@",
    "This iPhone can run iOS %@, where SideInstaller works without a computer: the iPhone pairs with itself, so there's no pairing file to make. Update in Settings › General › Software Update.":
        "iPhone này có thể chạy iOS %@. Trên phiên bản đó, SideInstaller hoạt động mà không cần máy tính: iPhone tự ghép nối, nên không phải tạo tệp ghép nối. Cập nhật trong Cài đặt › Cài đặt chung › Cập nhật phần mềm.",
    "OK": "OK",

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
    "SideInstaller %@ is still being published — try again later.": "SideInstaller %@ vẫn đang được phát hành — hãy thử lại sau.",
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
    "or": "hoặc",
    "Paste a download link": "Dán liên kết tải xuống",
    "SideInstaller recognizes this as %@ and sets it up just like its own download.":
        "SideInstaller nhận ra đây là %@ và thiết lập nó y như bản tự tải về.",
    "Downloading… %d%%": "Đang tải… %d%%",
    "Downloading": "Đang tải xuống",
    "Queued": "Đang chờ",
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
    "No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.": "Chưa kết nối VPN vòng lặp và tự động khởi động tunnel đang tắt. Hãy bật “Khởi động LocalDevVPN khi cần” trong Cài đặt rồi chạm Cài đặt lại.",
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
    "Use a custom .ipa instead": "Dùng tệp .ipa tùy chỉnh",
    "Pick an .ipa to install.": "Hãy chọn tệp .ipa cần cài.",
    "Signed with the Apple ID and installed as it is, without a pairing file.": "Được ký bằng Apple ID và cài nguyên trạng, không kèm tệp ghép nối.",
    "Open %@.": "Mở %@.",
    "Sign the app": "Ký ứng dụng",
    "Finish setup": "Hoàn tất thiết lập",

    // MARK: - Pairing tab

    "Pairing file ready": "Tệp ghép nối đã sẵn sàng",
    "No pairing file": "Chưa có tệp ghép nối",
    "Pairing file": "Tệp ghép nối",
    "Pairing file is being generated. Wait for it to finish, then try again.": "Đang tạo tệp ghép nối. Hãy đợi hoàn tất rồi thử lại.",
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
    "%@ isn't installed on this iPhone, so there's nowhere to import the certificate.":
        "%@ chưa được cài trên iPhone này nên không thể nhập chứng chỉ.",
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
    "Apps signed with this certificate:\n%@": "Ứng dụng đã ký bằng chứng chỉ này:\n%@",
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
    "Import to %@": "Nhập vào %@",
    "Exporting": "Đang xuất",

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
    "Inside LiveContainer, SideStore can't send its certificate back to SideInstaller, and LiveContainer doesn't hold one yet. In LiveContainer's Settings, tap “Import Certificate From SideStore” (sign in to SideStore first if it has no certificate), then try again here.":
        "Trong LiveContainer, SideStore không thể gửi lại chứng chỉ cho SideInstaller, và LiveContainer cũng chưa có chứng chỉ nào. Trong Settings của LiveContainer, chạm vào “Import Certificate From SideStore” (hãy đăng nhập SideStore trước nếu nó chưa có chứng chỉ), rồi thử lại tại đây.",
    "The certificate LiveContainer holds for SideStore isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID. Nothing was changed. If SideStore has made a new one since, tap “Refresh Certificate from SideStore” in LiveContainer's Settings, then try again here.":
        "Chứng chỉ mà LiveContainer giữ cho SideStore không thuộc Apple ID này: nó đã bị thu hồi, hoặc thuộc một Apple ID khác. Không có gì bị thay đổi. Nếu từ đó SideStore đã tạo chứng chỉ mới, hãy chạm vào “Refresh Certificate from SideStore” trong Settings của LiveContainer, rồi thử lại tại đây.",
    "SideInstaller takes SideStore's certificate from LiveContainer and signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "SideInstaller lấy chứng chỉ của SideStore từ LiveContainer và cũng ký bằng chứng chỉ này, nên với Apple ID miễn phí, không ứng dụng nào phải thu hồi chứng chỉ của ứng dụng kia.",
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
    "The download of %@ came back empty. Try again.": "Tải xuống %@ về trống. Hãy thử lại.",
    "Couldn't build the download URL for %@.": "Không thể tạo URL tải cho %@.",
    "Couldn't build the certificate link.": "Không thể tạo liên kết chứng chỉ.",

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
    "An install is already running. Wait for it to finish, then refresh.":
        "Đang có một lượt cài đặt chạy. Hãy đợi xong rồi gia hạn.",
    "A refresh is already running. Wait for it to finish, then try again.":
        "Đã có một lần gia hạn đang chạy. Hãy đợi nó hoàn tất rồi thử lại.",
    "A signing is already running. Wait for it to finish, then try again.":
        "Đang ký rồi. Hãy đợi ký xong rồi thử lại.",
    "Still reading the device. Try again in a moment.":
        "Vẫn đang đọc thiết bị. Hãy thử lại sau giây lát.",
    "Load failed. Showing the last loaded list.":
        "Tải danh sách thất bại. Đang hiển thị danh sách đã tải lần trước.",
    "Skipped: this app stopped being refreshable after the run started. Its IPA may have been deleted.":
        "Đã bỏ qua: ứng dụng này không còn làm mới được sau khi bắt đầu. IPA có thể đã bị xóa.",
    "Skipped: this app has no team on its signing profile, so it can't be refreshed.":
        "Đã bỏ qua: hồ sơ ký của ứng dụng này không có nhóm nên không thể làm mới.",
    "Revoked, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.":
        "Đã thu hồi, nhưng không thể làm mới danh sách chứng chỉ. Danh sách có thể lỗi thời cho đến khi tải lại.",

    "Imported, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.":
        "Đã nhập, nhưng không thể làm mới danh sách chứng chỉ. Danh sách có thể lỗi thời cho đến khi tải lại.",
    "Skipped: refresh stopped.":
        "Đã bỏ qua: đã dừng gia hạn.",
    "The pairing wasn't handed over in the newer format. SideStore may ask for the pairing file.":
        "Không thể chuyển tệp ghép nối ở định dạng mới. SideStore có thể yêu cầu tệp ghép nối khi mở lần đầu.",
    "The signing certificate wasn't handed over. SideStore may ask to resign itself on first sign-in.":
        "Không thể chuyển chứng chỉ ký. SideStore có thể yêu cầu ký lại khi đăng nhập lần đầu.",
    "Cellular Install (OTA)":
        "Cài đặt qua dữ liệu (OTA)",
    "Pairing Install":
        "Cài đặt qua ghép nối",
    "Upload these two files to R2, then install: %@ and %@. Upload via the WebDAV bridge https://r2-webdav.wozofa.workers.dev or the R2 console; .plist as text/xml, .ipa as application/octet-stream. After uploading, tap “Uploaded, Start Install”.":
        "Tải hai tệp này lên R2 rồi cài đặt: %@ và %@. Tải lên qua cầu WebDAV https://r2-webdav.wozofa.workers.dev hoặc bảng điều khiển R2; .plist dạng text/xml, .ipa dạng application/octet-stream. Sau khi tải lên, chạm vào “Đã tải lên, bắt đầu cài đặt”.",
    "Uploaded, Start Install":
        "Đã tải lên, bắt đầu cài đặt",
    "After installing, the first launch will say “Untrusted Enterprise Developer”: go to Settings → General → VPN & Device Management to trust the certificate, tap “Allow and Restart”, then open the app again.":
        "Sau khi cài đặt, lần mở đầu tiên sẽ báo “Nhà phát triển doanh nghiệp không đáng tin cậy”: vào Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị để tin cậy chứng chỉ, chạm “Cho phép và khởi động lại”, rồi mở lại ứng dụng.",
    "Cellular install couldn't open the system installer: check the R2 links, or use pairing install instead.":
        "Cài đặt qua dữ liệu không mở được trình cài đặt hệ thống: hãy kiểm tra các liên kết R2 hoặc dùng cài đặt qua ghép nối.",
    "SideStore's anisette settings weren't set. If its sign-in fails with -80046, turn off On-device Anisette and Auto Rotation and pick “SideStore (New)”.":
        "Không thể đặt cài đặt anisette của SideStore. Nếu đăng nhập lỗi -80046, hãy tắt Anisette trên thiết bị và tính năng tự động xoay, và chọn “SideStore (New)”。",
    "Last refresh (its notification couldn't be delivered): %@":
        "Lần làm mới trước (không gửi được thông báo): %@",
    "Getting ready": "Đang chuẩn bị",
    "Stopping after this app": "Sẽ dừng sau ứng dụng này",
    "Refreshing %@": "Đang gia hạn %@",
    "Refreshed. Its seven days start again now.":
        "Đã gia hạn. Bảy ngày bắt đầu lại từ bây giờ.",
    "Nothing was refreshed.": "Không có ứng dụng nào được gia hạn.",
    "Refreshed %d of %d apps.": "Đã gia hạn %d trong %d ứng dụng.",
    "Refresh all apps?": "Gia hạn tất cả ứng dụng?",
    "Refresh all": "Gia hạn tất cả",
    "Renew this app": "Gia hạn ứng dụng này",
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
    "No apps were read. Tap Reload to read this iPhone again; pair it and turn on Developer Mode first if nothing shows.":
        "Không đọc được ứng dụng nào. Chạm vào Tải lại để đọc lại iPhone này; nếu vẫn không có gì, hãy ghép nối iPhone và bật Chế độ nhà phát triển trước.",
    "No matching apps.": "Không có ứng dụng nào phù hợp.",
    "No matching profile": "Không có hồ sơ nào khớp",
    "Expires today": "Hết hạn hôm nay",
    "Expires tomorrow": "Hết hạn ngày mai",
    "Expires in %d days — %@": "Hết hạn sau %d ngày — %@",
    "Expired %@": "Đã hết hạn ngày %@",
    "Unused profiles": "Hồ sơ không dùng đến",
    "Issued to App IDs no installed app is running on.":
        "Được cấp cho các App ID mà không ứng dụng nào đã cài đang chạy trên đó.",
    "Older profiles": "Hồ sơ cũ hơn",
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
    "Install on their iPhone": "Cài lên iPhone của họ",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "iPhone vừa ghép nối là chính máy này. Hãy ghép nối từ Cài đặt trên iPhone của họ. Để cài lên iPhone này, hãy dùng tab Cài ứng dụng.",
    "Enter the Apple ID to sign with, and its password.":
        "Nhập Apple ID dùng để ký và mật khẩu của nó.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Wi-Fi đang tắt. Cả hai iPhone phải cùng một mạng Wi-Fi thì mới hoạt động.",
    "The release download wasn't an IPA. GitHub may be returning an error page, so try again in a minute.":
        "Bản tải về không phải là tệp IPA. Có thể GitHub đang trả về trang lỗi, hãy thử lại sau một phút.",
    "Couldn't download the latest SideInstaller release: %@":
        "Không tải được bản phát hành SideInstaller mới nhất: %@",
    "No SideInstaller IPA downloaded.": "Chưa tải IPA của SideInstaller.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first. Use the Certificates tool if this is the Apple ID saved in Settings › Account, or developer.apple.com signed in as it otherwise.":
        "Apple không cấp chứng chỉ ký cho Apple ID này: nó báo rằng đã có một chứng chỉ (lỗi 7460). Phải thu hồi bớt một chứng chỉ trước: bằng công cụ Chứng chỉ nếu đây là Apple ID đã lưu trong Cài đặt › Tài khoản, còn không thì vào developer.apple.com và đăng nhập bằng tài khoản đó.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple không đăng ký được iPhone của họ với nhóm nhà phát triển của Apple ID này, nên sẽ không cấp hồ sơ provisioning. %@",
    "No pair record for their iPhone.": "Không có bản ghi ghép nối cho iPhone của họ.",
    "The link to their iPhone dropped. Start again.":
        "Kết nối tới iPhone của họ đã rớt. Hãy bắt đầu lại.",
    "Set up someone else's iPhone": "Thiết lập iPhone cho người khác",
    "Same Wi-Fi network": "Cùng một mạng Wi-Fi",
    "Apple ID to sign with": "Apple ID dùng để ký",
    "Waiting for them to pair in Settings…":
        "Đang đợi họ ghép nối trong Cài đặt…",
    "Waiting for them to enter the code…":
        "Đang đợi họ nhập mã…",
    "Pair their iPhone in Settings":
        "Ghép nối iPhone của họ trong Cài đặt",
    "Their iPhone won't ask by itself. Pairing starts from its Settings.":
        "iPhone của họ sẽ không tự hỏi. Việc ghép nối bắt đầu từ Cài đặt của máy.",
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
    "SideInstaller is already waiting for an iPhone to pair with it, from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "SideInstaller đang đợi một iPhone ghép nối với nó, từ thẻ Cài ứng dụng, trang Ghép nối, hoặc một lần thử trước ở đây. Hãy hoàn tất lần ghép nối đó, hoặc đóng rồi mở lại SideInstaller, sau đó thử lại.",
    "Pairing with their iPhone didn't finish: %@":
        "Ghép nối với iPhone của họ chưa hoàn tất: %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "iPhone của họ ở %@ đã từ chối kết nối. Máy chỉ chấp nhận khi bật Chế độ nhà phát triển, và iOS yêu cầu xác nhận lại sau mỗi lần khởi động lại: trên iPhone của họ, hãy bật trong Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển rồi thử lại.",
    "Couldn't reach their iPhone at %@. Check that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Không kết nối được tới iPhone của họ ở %@. Hãy kiểm tra xem hai iPhone có cùng một mạng Wi-Fi không, và Mạng cục bộ đã được bật cho SideInstaller trong Cài đặt của iPhone này chưa. Mạng khách và mạng công cộng thường ngăn các thiết bị kết nối với nhau.",
    "%d%% downloaded": "Đã tải %d%%",
    "%@ downloaded": "Đã tải %@",
    "%d%% uploaded": "Đã tải lên %d%%",
    "Start the install": "Bắt đầu cài đặt",
    "Clear their details": "Xóa thông tin của họ",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "iPhone này vẫn đang ghép nối với iPhone của họ. Xóa sẽ bỏ ghép nối đó.",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "Trên iPhone của họ: Cài đặt › Cài đặt chung › VPN & Quản lý thiết bị.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "Chạm vào Apple ID trong mục “Ứng dụng nhà phát triển”, rồi chạm vào Tin cậy.",

    // MARK: - Side by Side, step by step

    "Needs LocalDevVPN on their iPhone": "Cần LocalDevVPN trên iPhone của họ",
    "Couldn't download %@: %@": "Không tải được %@: %@",
    "Couldn't find %@ in Downloads. Download it again first.": "Không tìm thấy %@ trong Tải xuống. Hãy tải lại trước.",
    "The IPA for %@ in Downloads is a different clone. Its bundle ID doesn't match this history entry. Download this clone's IPA first.": "IPA của %@ trong Tải về là một bản sao khác. ID gói của nó không khớp với mục lịch sử này. Hãy tải IPA của bản sao này trước.",
    "Their iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. They need to delete one, then you can try again.":
        "iPhone của họ đã có ba ứng dụng được ký bằng Apple ID miễn phí, mức tối đa iOS cho phép, tính cả ứng dụng đã hết hạn. Họ cần xóa một ứng dụng, rồi bạn có thể thử lại.",
    "%@ is on their iPhone, but its pairing file couldn't be added (%@). Run Side by Side again, or import a pairing file in %@.":
        "%@ đã có trên iPhone của họ, nhưng không thêm được tệp ghép nối (%@). Hãy chạy lại Side by Side, hoặc nhập tệp ghép nối trong %@.",
    "Get started": "Bắt đầu thôi",
    "What should go on their iPhone?": "Cài gì lên iPhone của họ?",
    "Pick one. You can come back for another one later.":
        "Chọn một. Bạn có thể quay lại cài thêm sau.",
    "Which Apple ID signs it?": "Apple ID nào sẽ ký?",
    "The app is signed with it, and needs it again every 7 days to keep opening. Use the iPhone owner's.":
        "Ứng dụng được ký bằng Apple ID này, và cứ 7 ngày lại cần nó để tiếp tục mở được. Hãy dùng Apple ID của chủ iPhone.",
    "Their Apple ID": "Apple ID của họ",
    "Recommended: they keep their apps signed with it.":
        "Khuyến nghị: họ dùng nó để giữ ứng dụng luôn được ký.",
    "My Apple ID": "Apple ID của tôi",
    "Only if you'll keep their apps signed yourself: they won't have this Apple ID's password.":
        "Chỉ chọn nếu chính bạn sẽ giữ ứng dụng của họ luôn được ký: họ sẽ không có mật khẩu của Apple ID này.",
    "Used for this install only, and never saved.":
        "Chỉ dùng cho lần cài này, và không bao giờ được lưu.",
    "Apple may send a code to their devices, so keep their iPhone close.":
        "Apple có thể gửi mã đến thiết bị của họ, vì vậy hãy để iPhone của họ ở gần.",
    "Get their iPhone ready": "Chuẩn bị iPhone của họ",
    "Do this on their iPhone, then start.": "Làm những việc này trên iPhone của họ, rồi bắt đầu.",
    "Connect their iPhone to the same Wi-Fi network as this one.":
        "Kết nối iPhone của họ với cùng mạng Wi-Fi như iPhone này.",
    "Turn on Developer Mode under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.":
        "Bật Chế độ nhà phát triển trong Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển, và xác nhận sau khi khởi động lại.",
    "Unlock their iPhone and keep it next to this one.":
        "Mở khóa iPhone của họ và để nó cạnh iPhone này.",
    "Installing %@ on their iPhone": "Đang cài %@ lên iPhone của họ",
    "Waiting for their iPhone…": "Đang chờ iPhone của họ…",
    "Looking for their iPhone…": "Đang tìm iPhone của họ…",
    "Handing over the pairing file…": "Đang chuyển tệp ghép nối…",
    "Change details": "Đổi thông tin",
    "%@ is on their iPhone": "%@ đã có trên iPhone của họ",
    "Finish on their iPhone": "Hoàn tất trên iPhone của họ",
    "This iPhone no longer keeps a pairing with theirs.":
        "iPhone này không còn giữ phần ghép nối với iPhone của họ.",
    "Install another app": "Cài ứng dụng khác",
    "Get LocalDevVPN from the App Store and connect it: SideStore works through it.":
        "Tải LocalDevVPN từ App Store và kết nối: SideStore hoạt động thông qua nó.",
    "Open SideStore and sign in with the same Apple ID. Its pairing file is already in place.":
        "Mở SideStore và đăng nhập bằng cùng Apple ID đó. Tệp ghép nối đã có sẵn trong đó.",
    "Open LiveContainer, go to its Settings tab, and tap “Import Certificate From SideStore”.":
        "Mở LiveContainer, vào tab Settings, rồi chạm “Import Certificate From SideStore”.",

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
    "Something at %@:%d took the connection but didn't answer as this iPhone's pairing port, and no other port answered as one either. Check that LocalDevVPN is the VPN that's on and that Developer Mode is on (Settings › Privacy & Security › Developer Mode), then try again. If it still fails, restart the iPhone.":
        "Có thứ gì đó ở %@:%d đã nhận kết nối nhưng không trả lời như cổng ghép nối của iPhone này, và cũng không có cổng nào khác trả lời như vậy. Hãy kiểm tra rằng VPN đang bật là LocalDevVPN và Chế độ nhà phát triển đang bật (Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển) rồi thử lại. Nếu vẫn lỗi, hãy khởi động lại iPhone.",
    "Start LocalDevVPN when needed": "Khởi động LocalDevVPN khi cần",
    "Start LocalDevVPN now": "Khởi động LocalDevVPN ngay",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "Chưa cài LocalDevVPN. Hãy tải từ App Store, rồi SideInstaller có thể khởi động giúp bạn.",
    "When on, operations that need the tunnel try the built-in tunnel first and start LocalDevVPN when needed. When off, LocalDevVPN is never started automatically; the built-in tunnel still starts on demand, and the manual pill switch is unaffected.":
        "Khi bật, các thao tác cần đường hầm sẽ thử đường hầm tích hợp trước rồi khởi động LocalDevVPN khi cần. Khi tắt, LocalDevVPN không bao giờ tự khởi động; đường hầm tích hợp vẫn khởi động khi cần, và công tắc pill thủ công không bị ảnh hưởng.",

    "imported": "đã nhập",
    "Downloaded %@": "Đã tải vào %@",
    "Added %@": "Đã thêm %@",
    "Delete": "Xóa",
    "Couldn't delete %@: %@": "Không thể xóa %@: %@",
    "Server": "Máy chủ",
    "Custom…": "Tùy chỉnh…",
    "Server URL": "URL máy chủ",
    "Anisette Server": "Máy chủ Anisette",
    "Starts with %@": "Bắt đầu với %@",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "Chỉ máy chủ đã chọn trong Cài đặt › Máy chủ Anisette được thử. Chọn Tự động ở đó để SideInstaller thử các máy chủ khác khi một máy chủ lỗi.",
    "Device IP": "IP thiết bị",
    "Advanced": "Nâng cao",
    "Clear": "Xóa hết",
    "Clear install history?": "Xóa lịch sử cài đặt?",
    "Activity Log (%d)": "Nhật ký hoạt động (%d)",
    "没有匹配的日志。": "Không có nhật ký phù hợp.",
    "Verbose logging": "Nhật ký chi tiết",
    "Adds the messages exchanged with iOS to the log, for tracking down a connection problem. Leave it off otherwise, as they quickly fill the log.":
        "Thêm các thông điệp trao đổi với iOS vào nhật ký, để tìm ra sự cố kết nối. Những lúc khác hãy để tắt, vì chúng nhanh chóng làm đầy nhật ký.",

    // Settings › Developer Mode: AMFI requests over the device link.
    "Developer Mode": "Chế độ nhà phát triển",
    "Developer disk image": "Ảnh đĩa nhà phát triển",
    "Downloaded": "Đã tải xuống",
    "Not downloaded": "Chưa tải xuống",
    "Re-download": "Tải lại",
    "Show Developer Mode in Settings": "Hiện Chế độ nhà phát triển trong Cài đặt",
    "Turn on Developer Mode": "Bật Chế độ nhà phát triển",
    "Asking this iPhone…": "Đang hỏi iPhone này…",
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
    "An import is already running. Wait for it to finish, then try again.": "Đã có một quá trình nhập đang chạy. Hãy đợi nó hoàn tất rồi thử lại.",
    "%@ will be signed again with the Apple ID that signed it and installed over the copy on this device. It keeps its data, and its seven days start over.": "%@ sẽ được ký lại bằng ID Apple đã ký nó và cài đè lên bản sao trên thiết bị này. Dữ liệu được giữ nguyên và bảy ngày sẽ được tính lại từ đầu.",
    "%d apps will be signed again, each with the Apple ID that signed it, and installed over the copies on this device. They keep their data, and their seven days start over.": "%d ứng dụng sẽ được ký lại, mỗi ứng dụng bằng ID Apple đã ký nó, và cài đè lên các bản sao trên thiết bị này. Dữ liệu được giữ nguyên và bảy ngày sẽ được tính lại từ đầu.",
    "%d app here is signed under a team that matches no saved Apple ID, so it is left out. Switch to the Apple ID that signed it and sign in once, then reload, and it will join the list. Enterprise-signed apps stay excluded.": "%d ứng dụng ở đây được ký bởi một nhóm không khớp với ID Apple đã lưu nào nên bị loại khỏi danh sách. Hãy chuyển sang ID Apple đã ký nó, đăng nhập một lần rồi tải lại, ứng dụng sẽ được thêm vào danh sách. Ứng dụng ký doanh nghiệp vẫn bị loại.",
    "%d apps here are signed under teams that match no saved Apple ID, so they are left out. Switch to the Apple ID that signed them and sign in once, then reload, and they will join the list. Enterprise-signed apps stay excluded.": "%d ứng dụng ở đây được ký bởi các nhóm không khớp với ID Apple đã lưu nào nên bị loại khỏi danh sách. Hãy chuyển sang ID Apple đã ký chúng, đăng nhập một lần rồi tải lại, các ứng dụng sẽ được thêm vào danh sách. Ứng dụng ký doanh nghiệp vẫn bị loại.",
    "These apps were signed under %d Apple IDs, so each group is signed with its own Apple ID.": "Các ứng dụng này được ký bằng %d ID Apple nên mỗi nhóm được ký bằng ID Apple của riêng mình.",
    "Couldn't sign in as %@ (%@). Switch to that account and refresh again.": "Không thể đăng nhập với tên %@ (%@). Hãy chuyển sang tài khoản đó rồi làm mới lại.",
    "Skipped: no saved Apple ID matches this app's team (%@). Switch to that account and refresh again.": "Đã bỏ qua: không có ID Apple đã lưu nào khớp với nhóm của ứng dụng này (%@). Hãy chuyển sang tài khoản đó rồi làm mới lại.",
    "Skipped: signed in as %@, but this app's team is %@. Switch to that account and refresh again.": "Đã bỏ qua: đã đăng nhập với tên %@ nhưng nhóm của ứng dụng này là %@. Hãy chuyển sang tài khoản đó rồi làm mới lại.",
    "Refreshing %@ as %@": "Đang gia hạn %@ với tên %@",
    "Invalid device IP": "IP thiết bị không hợp lệ",
    "The address was invalid, reset to 10.7.0.1.": "Địa chỉ không hợp lệ, đã đặt lại thành 10.7.0.1.",
    "Bundle Identifier": "Mã định danh gói",
    "rpath": "rpath",
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
    "Retry failed items": "Thử lại các mục thất bại",

    "couldn't find the IPA in the %@ %@ release":
        "không tìm thấy tệp IPA trong bản phát hành %@ của %@",
    "%@ has no %@ release right now": "%@ hiện không có bản phát hành %@ nào",
    "bad asset URL": "URL tệp tải không hợp lệ",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub đang giới hạn số yêu cầu từ mạng này — GitHub không bị chặn, và giới hạn sẽ tự hết. Hãy thử lại %@.",
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
    "No IPA on this iPhone":
        "Không có IPA tương ứng trên iPhone này",
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
    "If you reach GitHub through a VPN or proxy app, turn off LocalDevVPN and turn that one on: iOS runs only one VPN at a time.":
        "Nếu bạn vào GitHub qua một ứng dụng VPN hoặc proxy, hãy tắt LocalDevVPN rồi bật ứng dụng đó: iOS chỉ chạy một VPN tại một thời điểm.",
    "Tap “Get the .ipa” below and save the file, or download it on another device and bring it over.":
        "Chạm vào “Lấy tệp .ipa” bên dưới và lưu tệp, hoặc tải tệp trên thiết bị khác rồi chuyển sang đây.",
    "Back in SideInstaller, pick Custom .ipa under Install, tap “Import .ipa” and choose the file. SideInstaller recognizes %@ and sets it up just like its own download.":
        "Quay lại SideInstaller, chọn IPA tùy chọn trong mục Cài ứng dụng, chạm vào “Nhập .ipa” rồi chọn tệp. SideInstaller nhận ra %@ và thiết lập nó y như bản tự tải về.",
    "Turn LocalDevVPN back on, then tap Install.":
        "Bật lại LocalDevVPN, rồi chạm vào Cài ứng dụng.",
    "Get the .ipa": "Lấy tệp .ipa",
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
    "Ignore this version": "Bỏ qua phiên bản này",
    "已忽略的更新": "Bản cập nhật đã bỏ qua",
    "没有已忽略的更新。": "Không có bản cập nhật nào bị bỏ qua.",
    "所有已忽略的版本都将重新提示更新。": "Tất cả phiên bản đã bỏ qua sẽ lại nhắc cập nhật.",
    "Pause": "Tạm dừng",
    "Pause all": "Tạm dừng tất cả",
    "Resume": "Tiếp tục",
    "Resume all": "Tiếp tục tất cả",
    "Open": "Mở",
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
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "iOS đã từ chối kết nối tới %@ ngay trên iPhone này, trước khi bất cứ thứ gì được gửi đi. iOS làm vậy với các địa chỉ của chính iPhone này, như địa chỉ sau “Connected to” trên màn hình chính của LocalDevVPN. IP thiết bị, trong Cài đặt › Nâng cao, phải là địa chỉ ở Cài đặt › Device IP của LocalDevVPN (mặc định là 10.7.0.1). Nếu đã đúng như vậy, hãy tắt rồi bật lại LocalDevVPN, sau đó thử lại.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "iPhone này đã ngắt kết nối ngay khi nó vừa mở. Từ iOS 26.4, nó làm vậy với các tệp ghép nối lockdown, như tệp này, khi chúng đi qua LocalDevVPN. Thay vào đó, hãy ghép nối iPhone này với chính nó: chạm “Tạo lại” trong Công cụ › Ghép nối, hoặc chạm Cài ứng dụng, thao tác này sẽ ghép nối trước.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "iPhone này đã ngắt kết nối ngay khi nó vừa mở. Từ iOS 26.4, nó làm vậy với các tệp ghép nối lockdown, như tệp này, khi chúng đi qua LocalDevVPN, nên tạo một tệp mới cùng loại cũng không giúp được gì. Tệp ghép nối “Remote pairing” vẫn dùng được: trên máy tính, mở idevice_pair, chọn “Remote pairing”, bấm “Create”, rồi “Save to file…”, và nhập tệp đó trong “Tệp ghép nối”.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Việc ghép nối iPhone này cần đến nó: SideInstaller quảng bá chính mình trên mạng nội bộ để Cài đặt tìm thấy.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Hãy kết nối vào một mạng Wi-Fi. Việc ghép nối iPhone này cần đến nó — SideInstaller phải tìm thấy được trên mạng nội bộ.",

    // MARK: - About

    "About": "Giới thiệu",
    "Version %@ (%@)": "Phiên bản %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller cài SideStore và LiveContainer thẳng vào iPhone của bạn, không cần đến máy tính.",
    "Checking for updates…": "Đang kiểm tra cập nhật…",
    "Checking for updates… Tap again to cancel.": "Đang kiểm tra cập nhật… Chạm lại để hủy.",
    "You're up to date.": "Bạn đang dùng phiên bản mới nhất.",
    "Couldn't check for updates. Check your connection and try again.":
        "Không thể kiểm tra cập nhật. Hãy kiểm tra kết nối và thử lại.",

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
    "For the Turkish translation.": "Vì bản dịch tiếng Thổ Nhĩ Kỳ.",

    "Built with": "Được xây dựng với",
    "The open source work this app is built on:":
        "Những dự án mã nguồn mở mà ứng dụng này dựa trên:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "Ghép nối, đường hầm và chính việc cài đặt. Của jkcoxson, giấy phép MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Đăng nhập Apple ID, chứng chỉ và ký ngay trên máy. Của nab138, giấy phép MIT.",
    "The code signer isideload uses for each app. By Dadoum, LGPL-2.1.":
        "Công cụ ký mã mà isideload dùng cho từng ứng dụng. Của Dadoum, giấy phép LGPL-2.1.",
    "The sideloading app this installs for you.":
        "Ứng dụng sideload mà ứng dụng này cài giúp bạn.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Chạy các ứng dụng sideload mà không tốn một suất ứng dụng cho mỗi cái.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "Ảnh đĩa nhà phát triển mà chức năng giả lập vị trí gắn kết. Được doronz88 lưu bản sao.",

    "Terms": "Điều khoản",

    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.":
        "%@ cần iOS %d trở lên. iPhone này đang chạy iOS %@.",
    "%@ needs iOS %@ or later. This iPhone runs iOS %@.": "%@ cần iOS %@ trở lên. iPhone này đang chạy iOS %@.",
    "Minimum iOS": "iOS tối thiểu",
    "SHA-256": "SHA-256",
    "Show all": "Hiển thị tất cả",
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
    "SideInstaller takes the pairing file LiveContainer's built-in SideStore has.":
        "SideInstaller sẽ lấy tệp ghép nối mà SideStore tích hợp trong LiveContainer đang có.",
    "This is the pairing file LiveContainer's built-in SideStore has. SideInstaller will connect to this iPhone with it.":
        "Đây là tệp ghép nối mà SideStore tích hợp trong LiveContainer đang có. SideInstaller sẽ dùng tệp này để kết nối với iPhone này.",
    "In LiveContainer's Multitask Mode, SideInstaller can't open the built-in SideStore's files. Open SideInstaller in LiveContainer without Multitask Mode, then try again, or tap “Import pairing file” and pick the file your computer made.":
        "Trong Chế độ Đa nhiệm của LiveContainer, SideInstaller không mở được các tệp của SideStore tích hợp. Hãy mở SideInstaller trong LiveContainer mà không dùng Chế độ Đa nhiệm rồi thử lại, hoặc chạm “Nhập tệp ghép nối” và chọn tệp máy tính đã tạo.",
    "Inside LiveContainer, SideStore can't send its pairing file back to SideInstaller, and LiveContainer's built-in SideStore has none that SideInstaller can use. Tap “Import pairing file” and pick the file your computer made, or import one into SideStore first, then try again here.":
        "Trong LiveContainer, SideStore không gửi lại được tệp ghép nối cho SideInstaller, và SideStore tích hợp trong LiveContainer cũng không có tệp nào SideInstaller dùng được. Hãy chạm “Nhập tệp ghép nối” và chọn tệp máy tính đã tạo, hoặc nhập một tệp vào SideStore trước, rồi quay lại đây thử lại.",
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
    "Share": "Chia sẻ",
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

    // MARK: - Side by Side: their address, and the pairing file SideInstaller gets

    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Không kết nối được tới iPhone của họ ở %@. Hãy kiểm tra địa chỉ (Cài đặt › Wi-Fi › ⓘ trên iPhone của họ), hai iPhone có cùng một mạng Wi-Fi không, và Mạng cục bộ đã được bật cho SideInstaller trong Cài đặt của iPhone này chưa. Mạng khách và mạng công cộng thường ngăn các thiết bị kết nối với nhau.",
    "Their iPhone": "iPhone của họ",
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "Họ đã chạm “Không tin cậy” trên iPhone của họ. Hãy bắt đầu lại và nhờ họ chạm Tin cậy.",
    "Pairs from its Settings": "Ghép nối từ Cài đặt",
    "Waiting for them to tap Trust…": "Đang đợi họ chạm Tin cậy…",
    "Tap Trust on their iPhone": "Chạm Tin cậy trên iPhone của họ",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "Trên iPhone của họ: Cài đặt › Wi-Fi › ⓘ cạnh tên mạng, rồi xem “Địa chỉ IP”.",
    "Unlock their iPhone, then tap Trust in the prompt that comes up.":
        "Mở khóa iPhone của họ, rồi chạm Tin cậy trong lời nhắc hiện ra.",
    "This iPhone is %@, so theirs will look similar.": "iPhone này là %@, nên địa chỉ của họ sẽ tương tự.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” không phải là địa chỉ IPv4. Nó phải có dạng 192.168.1.42.",
    "Do you have the device's IP?": "Bạn có địa chỉ IP của thiết bị không?",
    "Optional": "Không bắt buộc",
    "SideInstaller asks their iPhone to pair directly. Needed below iOS 27.":
        "SideInstaller yêu cầu iPhone của họ ghép nối trực tiếp. Cần thiết với iOS dưới 27.",
    "Their iPhone pairs from its own Settings, which needs iOS 27.":
        "iPhone của họ tự ghép nối từ Cài đặt của máy, việc này cần iOS 27.",
    "IP address": "Địa chỉ IP",
    "Their iPhone runs iOS %@. From iOS 26.4 on, SideInstaller can't use the pairing their iPhone gives over Wi-Fi, so it needs a pairing file made on a computer.":
        "iPhone của họ đang chạy iOS %@. Từ iOS 26.4 trở đi, SideInstaller không dùng được kiểu ghép nối mà iPhone của họ cấp qua Wi-Fi, nên cần tệp ghép nối tạo trên máy tính.",
    "Get LocalDevVPN from the App Store and connect it: SideInstaller works through it.":
        "Tải LocalDevVPN từ App Store và kết nối: SideInstaller hoạt động thông qua nó.",
    "Open SideInstaller. Its pairing file is already in place.":
        "Mở SideInstaller. Tệp ghép nối đã có sẵn trong đó.",
    "Open SideInstaller and import a pairing file made on a computer.":
        "Mở SideInstaller và nhập tệp ghép nối tạo trên máy tính.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone, so use theirs. To install on this one, use the Install tab.":
        "%@ là địa chỉ mà chính chiếc iPhone này đang dùng. Side by Side cài lên iPhone của người khác, nên hãy dùng địa chỉ của họ. Để cài lên máy này, hãy dùng tab Cài ứng dụng.",
    "Their iPhone runs iOS %@. From iOS 26.4 on, %@ can't use the pairing their iPhone gives over Wi-Fi. iOS 27 pairs from its own Settings instead, which works: update their iPhone, then try again and answer No when asked for its IP.":
        "iPhone của họ đang chạy iOS %@. Từ iOS 26.4 trở đi, %@ không dùng được kiểu ghép nối mà iPhone của họ cấp qua Wi-Fi. iOS 27 thì ghép nối từ Cài đặt của chính nó, cách này hoạt động: hãy cập nhật iPhone của họ, rồi thử lại và chọn Không khi được hỏi địa chỉ IP.",

    // MARK: - AltStore

    "couldn't reach %@: %@":
        "không kết nối được tới %@: %@",
    "%@ answered HTTP %d":
        "%@ phản hồi HTTP %d",
    "%@'s list of apps couldn't be read (%@). Something on this network may have replaced it.":
        "không đọc được danh sách ứng dụng của %@ (%@). Có thể thứ gì đó trên mạng này đã thay thế nó.",
    "the %@ that arrived isn't the file %@ lists, so it isn't installed. Try again later.":
        "%@ nhận được không phải là tệp mà %@ liệt kê, nên sẽ không được cài đặt. Hãy thử lại sau.",
    "%@ lists no version of %@ that runs on iOS %@.":
        "%@ không có phiên bản %@ nào chạy được trên iOS %@.",
    "Open AltStore from your Home Screen and sign in with your Apple ID.":
        "Mở AltStore từ Màn hình chính và đăng nhập bằng Apple ID của bạn.",
    "To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings. Its pairing file is already in place, so the setup skips pairing.":
        "Để cài đặt và gia hạn ứng dụng mà không cần máy tính, chạm vào “Set up Remote AltServer” trong phần Cài đặt của AltStore. Tệp ghép nối đã có sẵn, nên quá trình thiết lập sẽ bỏ qua bước ghép nối.",
    "To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings and follow its steps.":
        "Để cài đặt và gia hạn ứng dụng mà không cần máy tính, chạm vào “Set up Remote AltServer” trong phần Cài đặt của AltStore và làm theo các bước.",
    "Open AltStore and sign in with the same Apple ID.":
        "Mở AltStore và đăng nhập bằng cùng Apple ID đó.",

    // MARK: - LAN transfer (browser page)

    "File not found": "Không tìm thấy tệp",
    "Invalid path": "Đường dẫn không hợp lệ",
    "Couldn't parse the upload": "Không thể xử lý tệp tải lên",
    "No such page": "Không có trang này",
    "Download": "Tải xuống",
    "Download complete": "Đã tải xuống xong",
    "%@ downloaded. You can install it from the Downloads page.": "Đã tải xuống %@. Bạn có thể cài đặt từ trang Tải xuống.",
    "Delete this file?": "Xóa tệp này?",
    "This directory is empty": "(Thư mục này trống)",
    "SideInstaller LAN Transfer": "Truyền tệp LAN SideInstaller",
    "SideInstaller File Transfer": "Truyền tệp SideInstaller",
    "Upload": "Tải lên",
    "File": "Tệp",
    "Size": "Kích thước",
    "Add": "Thêm",
    "Add Source": "Thêm nguồn",
    "Anyone on your LAN can access it without a password. Turn it off when done.": "Bất kỳ ai trong mạng LAN đều có thể truy cập mà không cần mật khẩu. Hãy tắt khi dùng xong.",
    "Appearance": "Giao diện",
    "Apple ID sign-in failed on %@. Last error: %@": "Đăng nhập Apple ID trên %@ không thành công. Lỗi cuối cùng: %@",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Revoke it under Tools › Certificates, then refresh again.": "Apple sẽ không cấp chứng chỉ ký cho Apple ID này: hệ thống báo đã tồn tại một chứng chỉ (lỗi 7460). Hãy thu hồi nó trong Công cụ › Chứng chỉ, rồi làm mới lại.",
    "Auto Refresh": "Tự động làm mới",
    "Built-in tunnel interface": "Giao diện tunnel tích hợp",
    "Built-in tunnel: interface 10.7.1.1/32 and peer 10.7.0.1/32 by default. Address changes take effect the next time the tunnel connects.": "Tunnel tích hợp: mặc định giao diện 10.7.1.1/32 và peer 10.7.0.1/32. Thay đổi địa chỉ có hiệu lực vào lần kết nối tunnel tiếp theo.",
    "Certificate password:": "Mật khẩu chứng chỉ:",
    "Couldn't reach the device at %@:%d at all. The loopback VPN is most likely off, or Device IP isn't the address it carries: in LocalDevVPN that's the one under Settings › Device IP (10.7.0.1 by default), not the “Connected to” address on its main screen. First check that the phone and the computer are on the same Wi-Fi (the local tunnel needs a local network).": "Không thể kết nối tới thiết bị tại %@:%d. Rất có thể VPN loopback đang tắt, hoặc IP thiết bị không phải địa chỉ mà nó đang dùng: trong LocalDevVPN, đó là địa chỉ trong Cài đặt › IP thiết bị (mặc định 10.7.0.1), không phải địa chỉ \"Đã kết nối tới\" trên màn hình chính. Trước tiên hãy kiểm tra điện thoại và máy tính có cùng Wi-Fi không (tunnel nội bộ cần mạng nội bộ).",
    "Dark": "Tối",
    "Every app and app extension SideInstaller signs needs an App ID. A free Apple ID can register 10 a week, and each one counts for 7 days.": "Mọi ứng dụng và tiện ích mở rộng mà SideInstaller ký đều cần một App ID. Apple ID miễn phí có thể đăng ký 10 ID mỗi tuần, mỗi ID có hiệu lực 7 ngày.",
    "Export certificate (p12)": "Xuất chứng chỉ (p12)",
    "Follow System": "Theo hệ thống",
    "Import failed": "Nhập không thành công",
    "Light": "Sáng",
    "Loading…": "Đang tải…",
    "Location is not set to “Always”, so only silent audio is keeping the app alive — renewal from the lock screen may be suspended. Set Location to “Always” in Settings.": "Vị trí chưa được đặt thành \"Luôn luôn\", vì vậy chỉ âm thanh im lặng mới giữ ứng dụng chạy — việc gia hạn từ màn hình khóa có thể bị tạm dừng. Hãy đặt Vị trí thành \"Luôn luôn\" trong Cài đặt.",
    "No IPA imported.": "Chưa nhập IPA nào.",
    "No sources yet. Tap + to add one.": "Chưa có nguồn nào. Chạm + để thêm.",
    "Refresh apps automatically in background": "Tự động làm mới ứng dụng trong nền",
    "SideInstaller stays alive in the background (silent audio + location) and checks every 30 minutes. Apps whose signing expires within 3 days are re-signed automatically. Location access must be set to “Always” and the tunnel must stay connected (the built-in tunnel is enough). The system also wakes the app in the background from time to time to run a check — don't swipe it away from the app switcher.": "SideInstaller tiếp tục chạy trong nền (âm thanh im lặng + vị trí) và kiểm tra mỗi 30 phút. Các ứng dụng sắp hết hạn ký trong 3 ngày sẽ được ký lại tự động. Quyền truy cập vị trí phải đặt thành \"Luôn luôn\" và tunnel phải luôn được kết nối (tunnel tích hợp là đủ). Hệ thống cũng thỉnh thoảng đánh thức ứng dụng trong nền để chạy kiểm tra — đừng vuốt đóng nó trong trình chuyển đổi ứng dụng.",
    "Skipped: not signed by the team you're signed in as, so a certificate-signed app is never re-signed here.": "Đã bỏ qua: không được ký bởi nhóm bạn đã đăng nhập, vì vậy ứng dụng đã ký bằng chứng chỉ sẽ không bao giờ được ký lại ở đây.",
    "Source URL": "URL nguồn",
    "That isn't a usable source link.": "Đó không phải là liên kết nguồn dùng được.",
    "The built-in tunnel couldn't start. See the log for the reason, then try again.": "Không thể khởi động tunnel tích hợp. Xem nhật ký để biết lý do, rồi thử lại.",
    "Transfer files to Documents over LAN": "Chuyển tệp tới Documents qua LAN",
    "Tunnel peer (device IP)": "Peer của tunnel (IP thiết bị)",
    "Tunnel standby": "Tunnel đang chờ",
    "WebDAV failed to start": "Không khởi động được WebDAV",
    "WebDAV file service": "Dịch vụ tệp WebDAV",
    "Wi-Fi not connected": "Wi-Fi chưa kết nối",
    "导出描述文件": "Xuất hồ sơ cấp phép",
    "导出后可在 LiveContainer 里导入同一张证书，不用再找原文件；密码不一起导出，导入时再填一次。": "Sau khi xuất, bạn có thể nhập cùng một chứng chỉ vào LiveContainer mà không cần tìm lại tệp gốc; mật khẩu không được xuất kèm, bạn sẽ nhập lại khi nhập.",
    "Beta": "Beta",
    "名字不能以. 开头": "Tên không được bắt đầu bằng dấu chấm",
    // SIDE-35 (0.9.124): new keys.
    "Modified edition": "Bản chỉnh sửa",
    "Archive": "Tệp lưu trữ",
    "%@ (extracted)": "%@ (đã giải nén)",
    "Source is too large": "Nguồn quá lớn",
    "Folders can't be deleted": "Không thể xóa thư mục",
    // SIDE-36 (0.9.125): new keys.
    "Couldn't read this source": "Không đọc được nguồn này",
    "Listing certificates failed: %@": "Liệt kê chứng chỉ thất bại: %@",
    "Revoke failed: %@": "Thu hồi thất bại: %@",
    "Couldn't parse p12 export result.": "Không phân tích được kết quả xuất p12.",
    "Export failed: %@": "Xuất thất bại: %@",
    "Listing App IDs failed: %@": "Liệt kê App ID thất bại: %@",
    "Enabling entitlements failed: %@": "Bật quyền thất bại: %@",
    "Waiting for this install to finish…": "Đang chờ lần cài đặt này hoàn tất…",
    "This file is being installed. Wait until it finishes.": "Tệp này đang được cài đặt. Hãy chờ cho đến khi xong.",
    "The device answered on the RSD port at %@, then the tunnel port it opened was unreachable on that same address — dropped or refused, across %@. The device is there; what's in front of it is forwarding some ports and not others. The tunnel opens on a fresh high port every attempt, so a rule-based proxy that forwards the RSD port alone can never cover it. Use a loopback VPN that blanket-forwards every port on the RSD subnet. Re-pairing won't help — the pairing is fine.": "Thiết bị đã trả lời trên cổng RSD tại %@, nhưng cổng đường hầm mà nó mở lại không thể truy cập tại cùng địa chỉ đó — bị hủy hoặc bị từ chối, trên %@. Thiết bị vẫn ở đó; thứ ở phía trước chỉ chuyển tiếp một số cổng chứ không phải tất cả. Đường hầm mở trên một cổng cao mới mỗi lần thử, vì vậy proxy dựa trên quy tắc chỉ chuyển tiếp cổng RSD sẽ không bao giờ bao quát được hết. Hãy dùng VPN loopback chuyển tiếp mọi cổng trên mạng con RSD. Ghép nối lại cũng không giúp được — bản thân việc ghép nối vẫn ổn.",
    "The tunnel port never answered and never refused on any address (%@) — the connection is being swallowed rather than rejected. That's usually a VPN or firewall dropping traffic on the RSD subnet. Check the VPN is still up, then try again.": "Cổng đường hầm không bao giờ trả lời cũng không từ chối trên bất kỳ địa chỉ nào (%@) — kết nối đang bị nuốt mất thay vì bị từ chối. Thường là do VPN hoặc tường lửa đang hủy lưu lượng trên mạng con RSD. Kiểm tra xem VPN còn bật không, rồi thử lại.",
    "Something accepted the tunnel connection but failed the encrypted handshake on top of it. Either another process holds that port, or this pairing file's key no longer matches the device. Pair again, and if that doesn't take, restart the loopback VPN.": "Có thứ gì đó đã chấp nhận kết nối đường hầm nhưng không hoàn thành được quá trình bắt tay mã hóa. Hoặc một tiến trình khác đang giữ cổng đó, hoặc khóa của tệp ghép nối này không còn khớp với thiết bị. Hãy ghép nối lại, và nếu vẫn không được, hãy khởi động lại VPN loopback.",
    "The device rejected this pairing file: it's for a different device, or the pairing was revoked (a reset, a restore, or Developer Mode being turned off). Pair with this iPhone again to get a fresh file.": "Thiết bị đã từ chối tệp ghép nối này: nó thuộc về một thiết bị khác, hoặc việc ghép nối đã bị thu hồi (đặt lại, khôi phục, hoặc Chế độ nhà phát triển đã tắt). Hãy ghép nối lại iPhone này để lấy một tệp mới.",
    "The tunnel didn't come up, and the failure didn't match any known cause. The raw error is in the log.": "Đường hầm không mở được và lỗi không khớp với bất kỳ nguyên nhân nào đã biết. Lỗi gốc nằm trong nhật ký.",
    "Diagnostics: remote pairing advertisement: %@; Developer Mode: %@.": "Chẩn đoán: quảng bá ghép nối từ xa: %@; Chế độ nhà phát triển: %@.",
    "No anisette servers are configured.": "Chưa cấu hình máy chủ anisette nào.",
    "Sign-in failed.": "Đăng nhập thất bại.",
    "This folder can't be renamed or moved.": "Không thể đổi tên hoặc di chuyển thư mục này.",
    "This file is being signed. Wait until it finishes.": "Tệp này đang được ký. Hãy chờ cho đến khi xong.",
    "This file is being renewed. Wait until it finishes.": "Tệp này đang được gia hạn. Hãy chờ cho đến khi xong.",
    "This only clears the list. Installed apps are not affected.": "Chỉ xóa danh sách. Các ứng dụng đã cài đặt không bị ảnh hưởng.",
    "empty account config": "Cấu hình tài khoản trống",
    "%d files, first %@: %@": "%d tệp, tệp đầu tiên %@ : %@",
    "%@ isn't listed": "%@ không có trong danh sách",
    "the data couldn't be read": "Không thể đọc dữ liệu",
    "Couldn't reach this iPhone. Check the connection and try again.": "Không thể kết nối tới iPhone này. Kiểm tra kết nối rồi thử lại.",
    "the connection to this iPhone failed": "kết nối tới iPhone này đã thất bại.",

    // MARK: - SIDE-43+44 (0.9.132)
    "This Apple ID has no development team. Sign in at developer.apple.com once to create one, then try again.": "ID Apple này không có nhóm phát triển. Đăng nhập developer.apple.com một lần để tạo nhóm, rồi thử lại.",
    "That certificate belongs to another Apple ID, or it was revoked.": "Chứng chỉ đó thuộc về một ID Apple khác, hoặc đã bị thu hồi.",
    "That App ID is no longer on this team.": "ID ứng dụng đó không còn trong nhóm này.",
    "That file isn't a certificate archive (.p12). Check the file and try again.": "Tệp đó không phải là tệp lưu trữ chứng chỉ (.p12). Kiểm tra lại tệp rồi thử lại.",
    "There's no signing certificate on this Apple ID yet. Install an app first — that's what creates it.": "ID Apple này chưa có chứng chỉ ký. Hãy cài đặt một ứng dụng trước — quá trình cài đặt sẽ tạo chứng chỉ.",
    "Check the network connection and try again.": "Kiểm tra kết nối mạng rồi thử lại.",
    "Apple didn't accept the sign-in. Check the Apple ID and password, then try again.": "Apple không chấp nhận lần đăng nhập này. Kiểm tra ID Apple và mật khẩu rồi thử lại.",
    "Sign-ins are being limited right now. Wait a few minutes and try again.": "Đăng nhập đang bị giới hạn. Đợi vài phút rồi thử lại.",
    "Apple's service didn't answer. Try again in a bit.": "Dịch vụ của Apple không phản hồi. Thử lại sau một lát.",
    "This iPhone is out of storage space. Free some space and try again.": "iPhone này đã hết dung lượng lưu trữ. Giải phóng dung lượng rồi thử lại.",
    "A file this step needed is missing. Check the file library and try again.": "Thiếu một tệp cần cho bước này. Kiểm tra thư viện tệp rồi thử lại.",
    "Something went wrong. Check the activity log and try again.": "Đã xảy ra lỗi. Kiểm tra nhật ký hoạt động rồi thử lại.",
    "Couldn't read the certificate list.": "Không đọc được danh sách chứng chỉ.",
    "Couldn't read what the import did.": "Không đọc được kết quả nhập.",
    "Couldn't read the App ID list.": "Không đọc được danh sách ID ứng dụng.",
    "Couldn't read Apple's reply.": "Không đọc được phản hồi của Apple.",
    "瘦身改包解压失败。": "Giải nén để thu gọn gói không thành công.",
    "瘦身改包压包失败。": "Nén để thu gọn gói không thành công.",
    "Pairing file for another iPhone": "Tệp ghép nối của một iPhone khác",
    "This pairing file belongs to another iPhone (UDID %@). The iPhone connected now is %@.": "Tệp ghép nối này thuộc về một iPhone khác (UDID %@). iPhone đang kết nối là %@.",
    "The route server couldn't plan this route.": "Máy chủ tuyến đường không thể lập tuyến đường này.",
    "Their iPhone connected but stopped responding before asking for a code. Try pairing again.": "iPhone của họ đã kết nối nhưng ngừng phản hồi trước khi yêu cầu mã. Hãy ghép nối lại.",
    "The pairing code wasn't entered in time. Pair again and enter the code when it appears.": "Mã ghép nối chưa được nhập kịp thời. Hãy ghép nối lại và nhập mã ngay khi mã xuất hiện.",
    "Their iPhone rejected this pairing file: it's for a different device, or the pairing was revoked (a reset, a restore, or Developer Mode being turned off). Pair with their iPhone again to get a fresh file.":
        "iPhone của họ đã từ chối tệp ghép nối này: tệp thuộc về một thiết bị khác, hoặc việc ghép nối đã bị thu hồi (đặt lại, khôi phục, hoặc Chế độ nhà phát triển bị tắt). Hãy ghép nối lại với iPhone của họ để lấy một tệp mới.",
    "Their iPhone answered, but the tunnel port it opened couldn't be reached — something between the two iPhones is forwarding some ports and not others. Check both iPhones are on the same Wi-Fi network (not a guest network), and that Local Network is on for SideInstaller in this iPhone's Settings. Re-pairing won't help — the pairing is fine.":
        "iPhone của họ đã phản hồi, nhưng không tới được cổng đường hầm mà nó đã mở — có thứ gì đó giữa hai iPhone chỉ cho một số cổng đi qua. Hãy kiểm tra xem hai iPhone có cùng một mạng Wi-Fi (không phải mạng khách) không, và Mạng cục bộ đã được bật cho SideInstaller trong Cài đặt của iPhone này chưa. Ghép nối lại cũng không giúp được gì — việc ghép nối vẫn ổn.",
    "Their iPhone never answered the tunnel port and never refused it — the connection is being swallowed rather than rejected. That's usually the Wi-Fi network or a firewall dropping traffic on the way. Check both iPhones are on the same Wi-Fi network, then try again.":
        "iPhone của họ không bao giờ trả lời cổng đường hầm mà cũng không từ chối — kết nối đang bị nuốt mất chứ không phải bị từ chối. Thường là do mạng Wi-Fi hoặc tường lửa làm rớt lưu lượng trên đường đi. Hãy kiểm tra xem hai iPhone có cùng một mạng Wi-Fi không rồi thử lại.",
    "Something accepted the tunnel connection but the encrypted handshake on top of it failed. Either another process holds that port, or this pairing file's key no longer matches their iPhone. Pair again.":
        "Đã có thứ gì đó chấp nhận kết nối đường hầm, nhưng quá trình bắt tay mã hóa phía trên đã thất bại. Hoặc một tiến trình khác đang giữ cổng đó, hoặc khóa của tệp ghép nối này không còn khớp với iPhone của họ nữa. Hãy ghép nối lại.",
    "GitHub answered HTTP %d":
        "GitHub đã trả về HTTP %d",
    "The code was incorrect. Try again.":
        "Mã không đúng. Thử lại.",
    "A code was already sent and is still valid. Enter it.":
        "Một mã đã được gửi và vẫn còn hiệu lực. Nhập mã đó.",
    "That way isn't available. Choose another way.":
        "Cách đó không khả dụng. Chọn cách khác.",
    "That didn't work. Try another way.":
        "Không được. Thử cách khác.",
    // MARK: - Developer team

    "Free · %@": "Miễn phí · %@",
    "Paid · %@": "Trả phí · %@",
    "This Apple Account is on %d developer teams. Pick the one that signs.":
        "Apple Account này thuộc %d nhóm nhà phát triển. Hãy chọn nhóm dùng để ký.",
    "Which Team?": "Nhóm nào?",
    "Signed this copy of SideInstaller": "Đã ký bản SideInstaller này",
    "A free team's apps last 7 days; a paid team's last a year.":
        "Ứng dụng do nhóm miễn phí ký dùng được 7 ngày; do nhóm trả phí ký dùng được một năm.",
    "An app installed with another team isn't replaced: signing it with this one installs a second copy.":
        "Ứng dụng đã cài bằng nhóm khác sẽ không bị thay thế: ký bằng nhóm này sẽ cài thêm một bản thứ hai.",
    "SideInstaller remembers the pick for this Apple ID. To pick again, open Settings › Account, swipe the Apple ID left and tap Team.":
        "SideInstaller sẽ nhớ lựa chọn này cho Apple ID. Để chọn lại, mở Cài đặt › Tài khoản, vuốt sang trái trên Apple ID đó rồi chạm vào Nhóm.",
    "No developer team was picked, so the sign-in stopped.":
        "Chưa chọn nhóm nhà phát triển nào nên đã dừng đăng nhập.",
    "Your Apple Account is on more than one developer team. Open SideInstaller and pick the one that signs.":
        "Apple Account của bạn thuộc nhiều nhóm nhà phát triển. Hãy mở SideInstaller và chọn nhóm dùng để ký.",
    "Pick the team again?": "Chọn lại nhóm?",
    "Pick Again": "Chọn lại",
    "The next sign-in with “%@” asks which developer team signs.":
        "Lần đăng nhập tiếp theo bằng “%@” sẽ hỏi ký bằng nhóm nhà phát triển nào.",
    // Shortcuts actions (ShortcutsSupport.swift and the *Shortcuts.swift files).
    "%@ can't be refreshed: SideInstaller has no IPA to sign it again from. Refresh it in whatever installed it, or import its .ipa into SideInstaller first.":
        "Không thể gia hạn %@: SideInstaller không có tệp IPA để ký lại. Hãy gia hạn trong ứng dụng đã cài nó, hoặc nhập tệp .ipa của nó vào SideInstaller trước.",
    "%@ is installed.":
        "%@ đã được cài đặt.",
    "Apple is asking you to finish signing in. Continue in SideInstaller to answer it.":
        "Apple đang yêu cầu bạn hoàn tất đăng nhập. Hãy tiếp tục trong SideInstaller để trả lời.",
    "LocalDevVPN is connected.":
        "LocalDevVPN đã được kết nối.",
    "LocalDevVPN isn't connected. Connect it before this action runs: Shortcuts' Set VPN action can, or turn on “Start LocalDevVPN when needed” in SideInstaller's Settings.":
        "LocalDevVPN chưa được kết nối. Hãy kết nối trước khi tác vụ này chạy: tác vụ VPN trong Phím tắt làm được việc đó. Hoặc bật “Khởi động LocalDevVPN khi cần” trong Cài đặt của SideInstaller.",
    "LocalDevVPN isn't connected. Continue in SideInstaller to connect it.":
        "LocalDevVPN chưa được kết nối. Hãy tiếp tục trong SideInstaller để kết nối.",
    "No route is playing.":
        "Không có lộ trình nào đang phát.",
    "Open SideInstaller and accept its terms first.":
        "Hãy mở SideInstaller và chấp nhận điều khoản của ứng dụng trước.",
    "Pick where the route starts, or set a location first.":
        "Hãy chọn nơi lộ trình bắt đầu, hoặc đặt một vị trí trước.",
    "Route started: %@, about %@.":
        "Đã bắt đầu lộ trình: %@, khoảng %@.",
    "That place has no coordinates. Pick it on the map, or type its address.":
        "Địa điểm đó không có tọa độ. Hãy chọn trên bản đồ hoặc nhập địa chỉ.",
    "The install didn't start. Open SideInstaller to see why.":
        "Việc cài đặt chưa bắt đầu. Hãy mở SideInstaller để xem lý do.",

    // MARK: - Sources

    "Suggested":
        "Gợi ý",

    "Paste the link of a SideStore or AltStore source, or of a .json source file. Its apps, their updates and release notes show here.":
        "Dán liên kết của một nguồn SideStore hoặc AltStore, hoặc của một tệp nguồn .json. Ứng dụng, bản cập nhật và ghi chú phát hành của nguồn sẽ hiện ở đây.",
    "Add a source":
        "Thêm nguồn",
    "Updates":
        "Cập nhật",
    "Update":
        "Cập nhật",
    "Your sources":
        "Nguồn của bạn",
    "Check for updates":
        "Kiểm tra cập nhật",
    "Copy link":
        "Sao chép liên kết",
    "Source options":
        "Tùy chọn nguồn",
    "What's new":
        "Có gì mới",
    "Version history":
        "Lịch sử phiên bản",
    "This version has no release notes.":
        "Phiên bản này không có ghi chú phát hành.",
    "%d update":
        "%d bản cập nhật",
    "%d updates":
        "%d bản cập nhật",
    "%d updates · Total size: %@": "%d bản cập nhật · Tổng dung lượng: %@",
    "%d 个可更新": "Có %d bản cập nhật",
    "全部更新进行中，等它跑完再批量安装。":
        "Đang cập nhật tất cả ứng dụng. Hãy đợi xong rồi mới cài đặt hàng loạt.",
    "全部更新进行中，等它跑完再重装。":
        "Đang cập nhật tất cả ứng dụng. Hãy đợi xong rồi mới cài đặt lại.",
    "全部更新进行中，等它跑完再重试。": "Đang cập nhật tất cả ứng dụng. Hãy đợi xong rồi mới thử lại.",
    "全部更新进行中，等它跑完再续签。": "Đang cập nhật tất cả ứng dụng. Vui lòng đợi xong rồi mới gia hạn.",
    "An update-all batch is running. Wait for it to finish, then try again.":
        "Đang cập nhật tất cả ứng dụng. Hãy đợi xong rồi thử lại.",
    "全部更新进行中，等它跑完再更新。":
        "Đang cập nhật tất cả ứng dụng. Hãy đợi xong rồi mới cập nhật.",
    "上次刷新失败：%@": "Lần làm mới trước thất bại: %@",
    "已停止更新：成功 %d 个，剩余 %d 个未更新。": "Đã dừng cập nhật: thành công %d, còn %d chưa cập nhật.",
    "%d source":
        "%d nguồn",
    "%d sources":
        "%d nguồn",
    "Update to %@":
        "Cập nhật lên %@",
    "Update now": "Cập nhật ngay",
    "Install %@ %@?":
        "Cài %@ %@?",
    "Version %@ · from %@":
        "Phiên bản %@ · từ %@",
    "%@ installed · %@ available":
        "Đã cài %@ · có %@",
    "%@ installed · up to date":
        "Đã cài %@ · mới nhất",
    "That source is already added.":
        "Nguồn đó đã được thêm.",
    "The source answered with HTTP %d.":
        "Nguồn trả về HTTP %d.",
    "Couldn't reach the source: %@":
        "Không thể kết nối tới nguồn: %@",
    "That isn't a source link. Paste the whole https:// address of the source.":
        "Đó không phải liên kết nguồn. Hãy dán toàn bộ địa chỉ https:// của nguồn.",
    "That link didn't return a source. It has to be the source's JSON file itself.":
        "Liên kết đó không trả về nguồn. Nó phải là chính tệp JSON của nguồn.",
    "Downloads the IPA from the source, then signs it with your Apple ID and installs it, as a custom .ipa would be.":
        "Tải IPA từ nguồn, rồi ký bằng Apple ID của bạn và cài đặt, giống như một .ipa tùy chỉnh.",
    "This version is older than the newest one. It's installed over the copy on this iPhone, which may not open data a newer version saved.":
        "Phiên bản này cũ hơn bản mới nhất. Nó được cài đè lên bản trên iPhone này và có thể không mở được dữ liệu mà phiên bản mới hơn đã lưu.",
    "This version is older than the one on this iPhone (%@). Installed over it, it may not open data the newer version saved.":
        "Phiên bản này cũ hơn bản trên iPhone này (%@). Khi cài đè lên, nó có thể không mở được dữ liệu mà phiên bản mới hơn đã lưu.",

    // MARK: - JIT

    "%@ has the JIT memory it asked for, so SideInstaller let go of it. JIT stays on until it quits.":
        "%@ đã có bộ nhớ JIT mà nó yêu cầu, nên SideInstaller đã tách khỏi nó. JIT vẫn bật cho đến khi ứng dụng thoát.",
    "%@ of JIT memory prepared": "Đã chuẩn bị %@ bộ nhớ JIT",
    "%d app can use JIT": "%d ứng dụng có thể dùng JIT",
    "%d apps can use JIT": "%d ứng dụng có thể dùng JIT",
    "Attach and detach": "Gắn rồi tách",
    "Attaching the debugger": "Đang gắn trình gỡ lỗi",
    "Auto: %@": "Tự động: %@",
    "Connecting to this iPhone's debugger": "Đang kết nối tới trình gỡ lỗi của iPhone này",
    "Couldn't open %@ under the debugger: %@": "Không thể mở %@ dưới trình gỡ lỗi: %@",
    "Couldn't reach the debugger on this iPhone: %@":
        "Không thể kết nối tới trình gỡ lỗi trên iPhone này: %@",
    "Enable JIT": "Bật JIT",
    "Continue JIT for %@": "Tiếp tục JIT cho %@",
    "JIT is on for %@ until it quits.": "JIT đã bật cho %@ cho đến khi ứng dụng thoát.",
    "JIT is on. SideInstaller stays attached while %@ runs: keep SideInstaller in the background, since closing it ends JIT.":
        "JIT đã bật. SideInstaller vẫn gắn vào trong khi %@ chạy: hãy để SideInstaller chạy nền, vì đóng nó sẽ kết thúc JIT.",
    "JIT needs Developer Mode. Turn it on under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.":
        "JIT cần Chế độ nhà phát triển. Hãy bật trong Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển, và xác nhận sau khi khởi động lại.",
    "JIT on for %@": "JIT đang bật cho %@",
    "Legacy": "Cũ",
    "No app on this iPhone is signed for development, which a debugger needs. Install the app with SideStore or SideInstaller, which sign apps that way, then load the apps again.":
        "Không có ứng dụng nào trên iPhone này được ký để phát triển, điều mà trình gỡ lỗi cần. Hãy cài ứng dụng bằng SideStore hoặc SideInstaller, vốn ký ứng dụng theo cách đó, rồi tải lại danh sách ứng dụng.",
    "No apps can use JIT": "Không có ứng dụng nào dùng được JIT",
    "Opening %@": "Đang mở %@",
    "Quit %@": "Thoát %@",
    "The debugger couldn't attach to %@ (%@). Install it again with SideStore or SideInstaller, which sign apps so a debugger can attach.":
        "Trình gỡ lỗi không gắn được vào %@ (%@). Hãy cài lại nó bằng SideStore hoặc SideInstaller, vốn ký ứng dụng để trình gỡ lỗi gắn vào được.",
    "The debugger lost %@ (%@). Open it with JIT again.":
        "Trình gỡ lỗi đã mất kết nối với %@ (%@). Hãy mở lại nó bằng JIT.",
    "Universal": "Phổ quát",

    // MARK: - Batch install, history empty state & clear-downloads failures (0.9.151)

    "安装所选": "Cài đặt mục đã chọn",
    "正在安装第 %d/%d 个：%@": "Đang cài đặt %d/%d: %@",
    "批量安装完成：%d 个已安装。": "Cài đặt hàng loạt xong: đã cài %d.",
    "批量安装完成：成功 %d 个，失败 %d 个。失败：%@": "Cài đặt hàng loạt xong: thành công %d, thất bại %d. Thất bại: %@",
    "等 %d 个": "và %d mục nữa",
    "其中 %d 个不是 IPA，已跳过。": "%d mục không phải IPA nên đã bỏ qua.",
    "已有安装在进行，先等当前安装完成再批量安装。": "Đã có một lượt cài đặt đang chạy. Hãy đợi xong rồi mới cài đặt hàng loạt.",
    "已有安装在进行，先等当前安装完成再试。": "Đã có một lượt cài đặt đang chạy. Hãy đợi xong rồi thử lại.",
    "正在签名，等它跑完再批量安装。": "Đang ký. Hãy đợi xong rồi mới cài đặt hàng loạt.",
    "Installed apps will be listed here.": "Các app đã cài sẽ được liệt kê ở đây.",
    "以下 %d 个删除失败：%@": "Không xóa được %d tệp: %@",

    // MARK: - F1 source toggle, F2 source export/import & F3 download rename (0.9.152)

    "Enabled": "Bật",
    "Names can't be empty, contain /, or start with .": "Tên không được để trống, chứa / hoặc bắt đầu bằng .",
    "Export sources": "Xuất danh sách nguồn",
    "Import sources": "Nhập danh sách nguồn",
    "The clipboard has no source list to import.": "Bảng tạm không có danh sách nguồn để nhập.",
    "Imported %d, already added %d, failed %d.": "Đã nhập %d, đã thêm %d, lỗi %d.",

    // MARK: - F3 update-all, F4 batch move & F5 log export (0.9.154)

    "全部更新": "Cập nhật tất cả",
    "正在更新第 %d/%d 个：%@": "Đang cập nhật %d/%d: %@",
    "正在读取已装 App…": "Đang đọc các app đã cài…",
    "全部更新完成：%d 个已更新。": "Cập nhật xong: đã cập nhật %d.",
    "全部更新完成：成功 %d 个，失败 %d 个。失败：%@": "Cập nhật xong: thành công %d, thất bại %d. Thất bại: %@",
    "移动": "Di chuyển",
    "已移动 %d 个。": "Đã di chuyển %d.",
    "已移动 %d 个，失败 %d 个。失败：%@": "Đã di chuyển %d, thất bại %d. Thất bại: %@",
    "导出日志": "Xuất nhật ký",

    // MARK: - F-C download speed/ETA & F-G Wi-Fi only downloads (0.9.156)

    "%@/s": "%@/s",
    "%@ left": "còn %@",
    "Download over cellular?": "Tải xuống bằng dữ liệu di động?",
    "Size: %@": "Dung lượng: %@",
    "Size unknown": "Không rõ dung lượng",
    "You're on cellular data. This download will use your mobile data.": "Bạn đang dùng dữ liệu di động. Bản tải xuống này sẽ dùng dữ liệu di động của bạn.",
    "Wi-Fi only downloads": "Chỉ tải xuống qua Wi-Fi",
    "When on, a download over cellular data asks first, so a large IPA doesn't use your mobile data.": "Khi bật, bản tải xuống bằng dữ liệu di động sẽ hỏi trước, để một file IPA lớn không dùng dữ liệu di động của bạn.",
    "Downloads": "Tải xuống",

    // MARK: - F-3 enterprise certificate expiry notice (0.9.157)

    "Enterprise certificate expiring": "Chứng chỉ doanh nghiệp sắp hết hạn",
    "The enterprise certificate expires on %@. Re-import it in time.": "Chứng chỉ doanh nghiệp hết hạn vào %@. Hãy nhập lại kịp thời.",
    "The enterprise provisioning profile expires on %@. Re-import it in time.": "Hồ sơ cấp phép doanh nghiệp hết hạn vào %@. Hãy nhập lại kịp thời.",

    // MARK: - 0.9.159: delete after install, downgrade check, dev-cert notice

    "Delete the IPA after installing": "Xóa IPA sau khi cài đặt",
    "Deletes the source IPA after a successful install. Files used for renewal are kept.": "Xóa IPA gốc sau khi cài đặt thành công. Các tệp dùng để gia hạn được giữ lại.",
    "Install an older version?": "Cài đặt phiên bản cũ hơn?",
    "Installed: %@ · This IPA: %@": "Đã cài: %@ · IPA này: %@",
    "Couldn't read their iPhone's iOS version. Reconnect and try again — installing without it could put an app their iPhone can't run on it.": "Không đọc được phiên bản iOS của iPhone bên kia. Hãy kết nối lại rồi thử lại — cài đặt mà không biết phiên bản có thể cài ứng dụng mà iPhone của họ không chạy được.",
    "Development certificate expiring": "Chứng chỉ phát triển sắp hết hạn",
    "The development certificate \"%@\" expires on %@. Renew it in time, or installs will fail.": "Chứng chỉ phát triển \"%@\" hết hạn vào %@. Hãy gia hạn kịp thời, nếu không quá trình cài đặt sẽ thất bại.",
    "This IPA asks for %@, which a free Apple ID certificate can't provide. Those features will silently stop working after install.": "IPA này yêu cầu %@, mà chứng chỉ Apple ID miễn phí không thể cung cấp. Các tính năng đó sẽ âm thầm ngừng hoạt động sau khi cài đặt.",
    "Before you install": "Trước khi cài đặt",
    "Reinstall all": "Cài đặt lại tất cả",
    "Reinstall all finished: %d succeeded, %d failed, %d skipped.": "Cài đặt lại tất cả xong: thành công %d, thất bại %d, đã bỏ qua %d.",
    "Failed: %@": "Thất bại: %@",
    "Still getting ready. Try again in a moment.": "Vẫn đang chuẩn bị. Hãy thử lại sau giây lát.",

    // MARK: - 0.9.161: uninstall, clean up old versions, last-checked, partial pairing write

    "Uninstall": "Gỡ cài đặt",
    "Uninstall %@?": "Gỡ cài đặt %@?",
    "This removes %@ from this iPhone, including its data.": "Thao tác này sẽ xóa %@ khỏi iPhone này, bao gồm cả dữ liệu của nó.",
    "SideInstaller can't uninstall itself.": "SideInstaller không thể tự gỡ cài đặt chính nó.",
    "Clean up old versions": "Dọn các phiên bản cũ",
    "Clean up %d old versions?": "Dọn %d phiên bản cũ?",
    "Only the newest version of each app is kept. Deleted files can't be recovered.": "Chỉ giữ lại phiên bản mới nhất của mỗi ứng dụng. Không thể khôi phục các tệp đã xóa.",
    "Cleaned up %d old versions.": "Đã dọn %d phiên bản cũ.",
    "No old versions to clean up.": "Không có phiên bản cũ để dọn.",
    "%d files skipped (in use or needed for renewal).": "Đã bỏ qua %d tệp (đang dùng hoặc cần cho việc gia hạn).",
    "%d files couldn't be deleted: %@": "Không thể xóa %d tệp: %@",
    "上次巡检：%@": "Lần kiểm tra gần nhất: %@",
    "Checked just now": "Vừa kiểm tra",
    "Checked %d minutes ago": "Đã kiểm tra %d phút trước",
    "Checked %d hours ago": "Đã kiểm tra %d giờ trước",
    "Checked %d days ago": "Đã kiểm tra %d ngày trước",
    "Pairing file installed into %@, but couldn't be written into %@.": "Đã cài tệp ghép nối vào %@, nhưng không thể ghi vào %@.",

    // 0.9.164
    "Loop route": "Lặp lại tuyến đường",
    "Newer than installed %@": "Mới hơn bản đã cài %@",
    "Older than installed %@": "Cũ hơn bản đã cài %@",
    "Same as installed %@": "Giống bản đã cài %@",
    "Show in Downloads": "Hiển thị trong Tải xuống",
    "Timed out waiting for the install slot — the download was discarded. Try again.": "Hết thời gian chờ vị trí cài đặt — tệp đã tải xuống đã bị xóa. Hãy thử lại.",
    "Still installing — check the Install page for progress.": "Vẫn đang cài đặt — kiểm tra tiến trình trên trang Cài đặt.",
    "Installing — tap to cancel": "Đang cài đặt — chạm để hủy",

    // 0.9.166
    "All": "Tất cả",
    "Succeeded": "Thành công",
    "Restore real location when done": "Khôi phục vị trí thực khi xong",
    "Import a .gpx file and the device moves along it at the speed you pick. When it ends, the device stays at its last point, unless restoring the real location when done is on.": "Nhập tệp .gpx và thiết bị sẽ di chuyển theo nó với tốc độ bạn chọn. Khi xong, thiết bị dừng ở điểm cuối, trừ khi khôi phục vị trí thực khi xong đang bật.",
    "移动“%@”？": "Di chuyển \"%@\"?",
    "This is the IPA on the Install tab. Moving it empties that slot — install it from its new folder instead.": "Đây là IPA trên tab Cài đặt. Di chuyển nó sẽ làm trống ô đó — hãy cài đặt từ thư mục mới của nó.",
    "Move": "Di chuyển",
    "其中 %d 个因拒绝降级而跳过。": "Trong đó %d mục đã bỏ qua do từ chối hạ cấp.",

    // 0.9.167
    "Folder": "Thư mục",
    "Export history": "Xuất lịch sử",
    "No files match the current filter.": "Không có tệp nào khớp với bộ lọc hiện tại.",

    // 0.9.174
    "Retry all": "Thử lại tất cả",
    "Skip": "Bỏ qua",
    "Clear all": "Xóa tất cả",
    "Clear all failed downloads?": "Xóa tất cả lượt tải xuống thất bại?",
    "全部更新进行中，等它跑完再安装。": "Đang cập nhật tất cả ứng dụng. Vui lòng đợi xong rồi mới cài đặt.",
    "其中 %d 个已跳过。": "Trong đó đã bỏ qua %d mục.",

    // 0.9.178
    "从未巡检": "Chưa từng chạy",
    "上次自动续签：%@": "Lần tự động gia hạn gần nhất: %@",

    // 0.9.179
    "Choose how to sign": "Chọn cách ký",
    "Enterprise signing keeps the Bundle ID unchanged.": "Ký bằng chứng chỉ doanh nghiệp giữ nguyên Bundle ID.",
    "Apple ID signing changes the Bundle ID to “original ID.team ID”, so it installs as a second icon.": "Ký bằng ID Apple sẽ đổi Bundle ID thành “ID gốc.ID nhóm” nên ứng dụng được cài dưới dạng biểu tượng thứ hai.",
    "Update to %@ · %@": "Cập nhật lên %@ · %@",

    // 0.9.182
    "从未自动续签": "Chưa từng tự động gia hạn",
    "粘贴": "Dán",
    "Recent links": "Liên kết gần đây",

]
