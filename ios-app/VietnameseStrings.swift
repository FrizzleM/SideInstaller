import Foundation

/// Vietnamese copy, on the same contract as `spanishStrings`. The Install tab is
/// "Cài ứng dụng", since "Cài đặt" also means Settings, and nouns don't inflect
/// for number, so the app-count strings share one wording.

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
    "%@ is installed. Finish the trust step above to open it.":
        "%@ đã được cài đặt. Hoàn tất bước tin cậy ở trên để mở ứng dụng.",
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

    // Importing a pairing file (iOS 26 and below)

    "Import pairing file": "Nhập tệp ghép nối",
    "How do I make one?": "Tạo nó như thế nào?",
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
    "Enter the other iPhone's IP address. It's in Settings › Wi-Fi, next to the network it's on.":
        "Nhập địa chỉ IP của chiếc iPhone kia. Nó nằm trong Cài đặt › Wi-Fi, ngay cạnh mạng mà máy đang kết nối.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” không phải là địa chỉ IPv4. Nó phải có dạng 192.168.1.42.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ là địa chỉ mà chính chiếc iPhone này đang dùng. Side by Side cài lên iPhone của người khác — hãy dùng địa chỉ của họ. Để cài lên máy này, hãy dùng tab Cài ứng dụng.",
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
    "How it works": "Cách hoạt động",
    "This installs SideInstaller onto another iPhone on the same Wi-Fi network — no computer and no cable. Their iPhone will ask them to trust this one; they have to be holding it, unlocked, when you tap Install.":
        "Cài SideInstaller lên một chiếc iPhone khác trong cùng mạng Wi-Fi — không cần máy tính, không cần cáp. iPhone của họ sẽ hỏi có tin cậy máy này không; họ phải cầm máy, đã mở khóa, khi bạn chạm Cài ứng dụng.",
    "Their iPhone": "iPhone của họ",
    "IP address (e.g. 192.168.1.42)": "Địa chỉ IP (ví dụ 192.168.1.42)",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "Trên iPhone của họ: Cài đặt › Wi-Fi › ⓘ cạnh tên mạng, rồi xem “Địa chỉ IP”.",
    "This iPhone is %@, so theirs will look similar.":
        "iPhone này là %@, nên địa chỉ của họ sẽ tương tự.",
    "Apple ID to sign with": "Apple ID dùng để ký",
    "Usually theirs, so the app is signed to their account and their free developer slots. Held only until this page is closed — never saved to this iPhone, and the password is never sent anywhere but Apple.":
        "Thường là của họ, để ứng dụng được ký bằng tài khoản và các suất nhà phát triển miễn phí của họ. Chỉ giữ đến khi bạn đóng trang này — không bao giờ lưu vào iPhone này, và mật khẩu chỉ được gửi tới Apple.",
    "Use my saved Apple ID instead": "Dùng Apple ID đã lưu của tôi",
    "Steps": "Các bước",
    "Waiting for them to tap Trust…": "Đang đợi họ chạm Tin cậy…",
    "%d%% downloaded": "Đã tải %d%%",
    "%d%% uploaded": "Đã tải lên %d%%",
    "Start the install": "Bắt đầu cài đặt",
    "Install again": "Cài lại",
    "Clear their details": "Xóa thông tin của họ",
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
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub đang giới hạn số yêu cầu từ mạng này — GitHub không bị chặn, và giới hạn sẽ tự hết. Hãy thử lại %@.",
    "GitHub answered HTTP %d%@": "GitHub đã trả về HTTP %d%@",
    "couldn't reach GitHub: %@": "không kết nối được tới GitHub: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "phản hồi của GitHub không phải là thông tin bản phát hành (%@) — có thể thứ gì đó trên mạng này đã thay thế nó.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "tệp tải về dưới tên %@ không phải là IPA — có thể thứ gì đó trên mạng này đã trả về một trang web, hoặc quá trình tải bị gián đoạn.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "liên kết đó trả về HTTP %d — không phải liên kết tải trực tiếp, hoặc cần đăng nhập.",

    // MARK: - Engine failures

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
    "Pair this iPhone in Settings": "Ghép nối iPhone này trong Cài đặt",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Mở ứng dụng Cài đặt, rồi vào Quyền riêng tư & Bảo mật › Chế độ nhà phát triển.",
    "Tap “Pair with SideInstaller”.": "Chạm vào “Ghép nối với SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.": "Nhập mật mã iPhone của bạn nếu được hỏi.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Quay lại SideInstaller, xem mã mà ứng dụng hiển thị, rồi nhập đúng mã đó vào hộp thoại trong Cài đặt.",
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
    "If you changed LocalDevVPN's addresses, put its Device IP here, and make sure its Tunnel IP and subnet mask cover it.":
        "Nếu bạn đã đổi địa chỉ của LocalDevVPN, hãy nhập Device IP của nó vào đây và đảm bảo Tunnel IP cùng mặt nạ mạng con của nó bao phủ địa chỉ đó.",
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

    "Special thanks": "Lời cảm ơn đặc biệt",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "Vì idevice, thư viện mà SideInstaller dùng để giao tiếp với iPhone của bạn. Không có nó thì mọi thứ này đều không tồn tại.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Vì đã hỗ trợ và phát hiện những lỗi sau đó được sửa.",
    "For the Japanese translation.": "Vì bản dịch tiếng Nhật.",

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
]
