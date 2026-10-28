import Foundation

/// Korean translations (same rules as `spanishStrings`). Uses Apple's ko wording
/// for Settings paths and "tap" (탭하세요), 폐기 for "revoke", and formal 합쇼체
/// (~습니다/~합니까) for statements and questions, ~하세요 for instructions.
/// Product and third-party UI names stay in English.

let koreanStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "취소",
    "Copy": "복사",
    "Copy logs": "로그 복사",
    "Email": "이메일",
    "Password": "암호",
    "Install": "설치",
    "Installing": "설치 중",
    "Cancelling": "취소 중",
    "Installed": "설치됨",
    "Something went wrong": "문제가 발생했습니다",
    "an app by Frizzle": "by Frizzle",
    "device": "기기",

    // MARK: - Welcome

    "I have accepted the": "다음에 동의합니다:",
    "Start": "시작",

    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "페어링 파일이 필요합니다",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "이 iPhone의 iOS 버전은 %@입니다. 자기 자신과 페어링할 수 있는 것은 iOS %@ 이상뿐이라서, 컴퓨터에서 jitterbugpair나 pymobiledevice3로 페어링 파일을 만들어 앱으로 가져와야 합니다. 방법은 SideInstaller가 안내해 드립니다.",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "Apple ID로 로그인",
    "Don't worry, these are stored locally":
        "걱정 마세요, 이 정보는 기기 안에만 저장됩니다",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "이 iPhone의 키체인에 저장되며, 로그인할 때 Apple에만 전송됩니다.",
    "Continue": "계속",
    "Set this up later": "나중에 설정",
    "Add Apple ID": "Apple ID 추가",
    "Edit Apple ID": "Apple ID 편집",
    "Save": "저장",
    "Enter the password again to save this Apple ID.": "이 Apple ID를 저장하려면 암호를 다시 입력하세요.",
    "Account": "계정",
    "In use": "사용 중",
    "Edit": "편집",
    "Remove": "삭제",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "저장된 Apple ID가 없습니다. 하나 추가하면 SideInstaller가 로그인할 때마다 사용합니다.",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "이 iPhone의 키체인에 저장되며, 로그인할 때 Apple에만 전송됩니다. 행을 살짝 밀면 암호를 수정하거나 삭제할 수 있습니다.",
    "Remove this Apple ID?": "이 Apple ID를 삭제하시겠습니까?",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "“%@” 및 저장된 암호가 이 iPhone에서 삭제됩니다. Apple 계정에는 아무 영향이 없습니다.",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "이 iPhone의 키체인이 암호 저장을 거부했습니다(오류 %d). SideInstaller를 종료하기 전까지만 보관됩니다.",
    "No Apple ID saved. Add one in Settings › Account.": "저장된 Apple ID가 없습니다. 설정 › 계정에서 추가하세요.",

    "Add your Apple ID": "Apple ID 추가하기",
    "Open Settings with the gear at the top right.": "오른쪽 위의 톱니바퀴를 탭해 설정을 여세요.",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "계정 아래에서 “Apple ID 추가”를 탭하고 이메일과 암호를 입력하세요.",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "도구",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "페어링",
    "Certificates": "인증서",
    "Two-Factor Code": "2단계 인증 코드",
    "6-digit code": "6자리 코드",
    "Submit": "제출",
    "Enter the code Apple just sent to your trusted device.":
        "Apple이 방금 신뢰할 수 있는 기기로 보낸 코드를 입력하세요.",
    "Enter the code Apple texted to %@.":
        "Apple이 %@(으)로 보낸 문자 메시지의 코드를 입력하세요.",
    "Enter the code Apple texted to your phone.":
        "Apple이 휴대폰으로 보낸 문자 메시지의 코드를 입력하세요.",
    "Apple is calling %@. Enter the code you hear.":
        "Apple이 %@(으)로 전화를 걸고 있습니다. 들리는 코드를 입력하세요.",
    "Apple is calling your phone. Enter the code you hear.":
        "Apple이 휴대폰으로 전화를 걸고 있습니다. 들리는 코드를 입력하세요.",
    "Choose how Apple should send your verification code.":
        "Apple이 인증 코드를 보낼 방법을 선택하세요.",
    "Choose How to Get a Code":
        "코드 받는 방법 선택",
    "Verify":
        "확인",
    "Didn't get it?":
        "코드를 받지 못하셨습니까?",
    "Send a new code to my devices":
        "내 기기로 새 코드 보내기",
    "Text me a new code":
        "새 코드를 문자로 받기",
    "Call me again":
        "다시 전화 받기",
    "Send a code to my Apple devices":
        "내 Apple 기기로 코드 보내기",
    "Text %@":
        "%@(으)로 문자 받기",
    "Call %@":
        "%@(으)로 전화 받기",
    "Checking the code…":
        "코드를 확인하는 중…",
    "Requesting a new code…":
        "새 코드를 요청하는 중…",
    "Sending a code to your devices…":
        "기기로 코드를 보내는 중…",
    "Texting a code to %@…":
        "%@(으)로 문자 코드를 보내는 중…",
    "Calling %@…":
        "%@(으)로 전화를 거는 중…",

    // MARK: - Install tab

    "Tunnel connected": "터널 연결됨",
    "Tunnel off": "터널 꺼짐",
    "Update available": "업데이트 가능",
    "SideInstaller %@ is available — you're on %@.":
        "SideInstaller %@ 버전을 사용할 수 있습니다. 현재 버전은 %@입니다.",
    "Get the latest version": "최신 버전 받기",
    "From the website": "웹사이트에서 받기",
    "Sign it with your Apple ID": "내 Apple ID로 서명",
    "Install it in LiveContainer": "LiveContainer에 설치",
    "LiveContainer isn't installed on this iPhone.": "이 iPhone에 LiveContainer가 설치되어 있지 않습니다.",
    "Release": "릴리즈 채널",
    "Reinstall": "다시 설치",
    "Install %@": "%@ 설치",
    "Custom .ipa": "사용자 지정 .ipa",
    "Import .ipa": ".ipa 가져오기",
    "Importing…": "가져오는 중…",
    "Replace": "교체",
    "or": "또는",
    "Paste a download link": "다운로드 링크 붙여넣기",
    "Downloading… %d%%": "다운로드 중… %d%%",
    "iOS %@ required": "iOS %@ 필요",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "이 iPhone의 iOS 버전은 %@이므로 SideInstaller로 설치할 수 없습니다. 설정 › 일반 › 소프트웨어 업데이트에서 iOS %@ 이상으로 업데이트하세요.",
    "Wi-Fi required": "Wi-Fi 필요",
    "Pairing code": "페어링 코드",
    "Type this into the prompt in Settings.":
        "설정의 입력창에 이 코드를 입력하세요.",
    "Install stopped": "설치 중단됨",
    "Close": "닫기",
    "Yes": "예",
    "No": "아니요",
    "Closing this popup will end the process. Are you sure?":
        "이 팝업을 닫으면 작업이 종료됩니다. 계속하시겠습니까?",
    "Cancel the install?": "설치를 취소하시겠습니까?",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ 앱이 설치되었습니다. 위 안내에 따라 개발자 앱을 신뢰하면 열 수 있습니다.",
    "%@ is installed. Finish the trust step below to open it.":
        "%@ 앱이 설치되었습니다. 아래 안내에 따라 개발자 앱을 신뢰하면 열 수 있습니다.",
    "Success: last steps": "설치 완료: 마지막 단계",
    "Action needed": "직접 진행 필요",
    "Step %@ of %@": "%@/%@단계",
    "Show all steps": "전체 과정 펼치기",
    "Show fewer steps": "과정 접기",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "LocalDevVPN 필요",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "LocalDevVPN을 설치하고 연결하세요. 설치는 이 터널을 통해 진행됩니다.",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "앱을 검색하고 페어링 파일을 넣으려면 LocalDevVPN을 연결하세요. 파일을 넣는 작업도 이 터널을 통해 진행됩니다.",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "LocalDevVPN을 연결하세요. 위치 변경도 여기 있는 다른 기능처럼 이 터널을 통해 작동합니다.",
    "LocalDevVPN isn't connected. Connect it, then try again.": "LocalDevVPN이 연결되어 있지 않습니다. 연결한 뒤 다시 시도하세요.",
    "Connect LocalDevVPN": "LocalDevVPN 연결",
    "Install LocalDevVPN from the App Store and open it.": "App Store에서 LocalDevVPN을 설치하고 실행하세요.",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "사용 중인 지역에서 GitHub이 차단되어 있다면 트래픽도 대신 전달할 수 있는 VPN을 사용하세요. iOS는 한 번에 VPN을 하나만 실행하므로, 로컬 전용 터널이 켜져 있으면 SideStore를 내려받을 경로가 없습니다.",

    // MARK: - Install steps

    "Connect the VPN": "VPN 연결",
    "Get pairing file": "페어링 파일 준비",
    "Open the device link": "기기와 연결",
    "Sign in to Apple ID": "Apple ID로 로그인",
    "Download %@": "%@ 다운로드",
    "Use your imported IPA": "가져온 IPA 사용",
    "Sign the app": "앱 서명",
    "Finish setup": "설정 마무리",

    // MARK: - Pairing tab

    "Pairing file ready": "페어링 파일 준비됨",
    "No pairing file": "페어링 파일 없음",
    "Pairing file": "페어링 파일",
    "Pairing…": "페어링 중…",
    "Regenerate": "다시 생성",
    "Generate pairing file": "페어링 파일 생성",
    "Export pairing file": "페어링 파일 내보내기",
    "Pair in Settings": "설정에서 페어링",
    "Install into an app": "앱에 페어링 파일 넣기",
    "Scanning": "검색 중",
    "Rescan apps": "앱 다시 검색",
    "Scan installed apps": "설치된 앱 검색",
    "%d supported app installed": "지원되는 앱 %d개 설치됨",
    "%d supported apps installed": "지원되는 앱 %d개 설치됨",
    "No supported apps found": "지원되는 앱을 찾을 수 없습니다",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "SideStore, StikDebug, Feather 같은 앱을 먼저 설치한 뒤 다시 검색해 주세요.",
    "Install pairing": "페어링 파일 넣기",
    "Pairing file ready. You can export it or install it into an app below.":
        "페어링 파일이 준비되었습니다. 내보내거나 아래의 앱에 넣을 수 있습니다.",
    "Pairing file installed into %@.": "%@에 페어링 파일을 넣었습니다.",
    "Install pairing into all apps": "모든 앱에 페어링 파일 넣기",
    "Installing into all apps": "모든 앱에 넣는 중…",
    "Pairing file installed into all %d apps.": "앱 %d개 모두에 페어링 파일을 넣었습니다.",
    "Couldn't write into %@.": "%@에 파일을 쓰지 못했습니다.",
    "The %@ record isn't a plist dictionary.": "%@ 레코드가 plist 딕셔너리가 아닙니다.",

    // Importing a pairing file (required below iOS 27, under Advanced from 27)

    "Import pairing file": "페어링 파일 가져오기",
    "How do I make one?": "페어링 파일 만드는 방법",
    "(Optional)": "(선택 사항)",
    "imported pairing file": "가져온 페어링 파일",
    "No pairing file yet — tap “Import pairing file” first.": "아직 페어링 파일이 없습니다. 먼저 “페어링 파일 가져오기”를 탭하세요.",
    "Pairing file missing — import it first.": "페어링 파일이 없습니다. 먼저 가져오세요.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ 파일은 페어링 파일이 아닙니다. 컴퓨터에서 만든 파일, 즉 이 iPhone의 페어 레코드가 들어 있는 .mobiledevicepairing 또는 .plist 파일을 선택하세요.",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "iOS %@에서는 자체 페어링 파일을 만들 수 없습니다. iOS %@ 이상이 필요합니다. “페어링 파일”에서 컴퓨터로 만든 파일을 가져온 뒤 다시 시도하세요.",

    // MARK: - Pairing service status

    "not paired": "페어링 안 됨",
    "connected": "연결됨",
    "requesting Local Network…": "로컬 네트워크 권한 요청 중…",
    "Local Network denied": "로컬 네트워크 권한 거부됨",
    "waiting for device…": "기기를 기다리는 중…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "로컬 네트워크에 알리는 중 — 설정 › 개인정보 보호 및 보안 › 개발자 모드를 여세요",
    "enter PIN %@ in Settings": "설정에서 PIN %@ 입력",
    "paired: %@ (%dB)": "페어링됨: %@ (%dB)",
    "failed: empty pairing file": "실패: 페어링 파일이 비어 있음",
    "failed: %@": "실패: %@",
    "Pairing is already in progress.": "이미 페어링이 진행 중입니다.",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "로컬 네트워크 권한이 꺼져 있습니다. 설정 › SideInstaller › 로컬 네트워크에서 켠 뒤 다시 시도하세요.",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "페어링 결과 파일이 비어 있습니다. 페어링 요청을 승인했는지 확인한 뒤 다시 시도하세요.",

    // MARK: - Certificates tab

    "Revoke this certificate?": "이 인증서를 폐기하시겠습니까?",
    "Revoke": "폐기",
    "Revoking": "폐기 중",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "“%@” 인증서가 폐기됩니다. 이 인증서로 서명된 앱은 모든 기기에서 실행되지 않게 됩니다. 이 작업은 되돌릴 수 없습니다.",
    "Refreshing": "새로 고치는 중",
    "Signing in": "로그인 중",
    "Refresh": "새로 고침",
    "Load certificates": "인증서 불러오기",
    "%d certificate(s)": "인증서 %d개",
    "No certificates": "인증서 없음",
    "This Apple ID has no development certificates to revoke.":
        "이 Apple ID에는 폐기할 개발용 인증서가 없습니다.",
    "Expired": "만료됨",
    "Expires %@": "%@에 만료",
    "Unnamed certificate": "이름 없는 인증서",
    "This certificate has no serial number, so it can't be revoked.":
        "이 인증서에는 일련번호가 없어서 폐기할 수 없습니다.",

    // Export: the certificate SideInstaller signs with, as a .p12
    "This certificate has no serial number, so it can't be exported.":
        "이 인증서에는 일련번호가 없어서 내보낼 수 없습니다.",
    "Only the certificate SideInstaller signs with can be exported: the private key of any other stays on the device that asked Apple for it.":
        "SideInstaller가 서명에 사용하는 인증서만 내보낼 수 있습니다. 다른 인증서의 개인 키는 Apple에 인증서를 요청한 기기에만 남아 있습니다.",
    "Couldn't export the certificate: %@": "인증서를 내보내지 못했습니다: %@",
    "Export certificate": "인증서 내보내기",
    "Export": "내보내기",
    "Exporting": "내보내는 중",
    "Saves this certificate and its private key as a .p12 file, for another signing app or a computer to sign with. Choose a password for it: you'll need it to import the file. Keep the file to yourself.":
        "이 인증서와 개인 키를 .p12 파일로 저장합니다. 다른 서명 앱이나 컴퓨터에서 서명할 때 사용할 수 있습니다. 파일에 사용할 암호를 정하세요. 파일을 가져올 때 필요합니다. 파일은 본인만 보관하세요.",
    "SideInstaller can export only the certificate it signs with, and none of these is it: a certificate's private key stays on the device that asked Apple for it.":
        "SideInstaller는 서명에 사용하는 인증서만 내보낼 수 있는데, 이 목록에는 해당하는 인증서가 없습니다. 인증서의 개인 키는 Apple에 인증서를 요청한 기기에만 남아 있기 때문입니다.",
    "SideInstaller signs with this one": "SideInstaller가 이 인증서로 서명합니다",

    // MARK: - SideStore's certificate (sidestore://certificate)

    "Use SideStore's certificate": "SideStore의 인증서 사용",
    "Checking the certificate": "인증서 확인 중",
    "SideStore opens and sends back its certificate. SideInstaller then signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "SideStore가 열리고 자신의 인증서를 돌려보냅니다. 그러면 SideInstaller도 같은 인증서로 서명하므로, 무료 Apple ID에서도 두 앱이 서로의 인증서를 폐기할 필요가 없습니다.",
    "Apple won't issue a second signing certificate for this Apple ID. If SideStore made the one it has, SideInstaller can sign with that one too, and nothing is revoked. Revoking it lets the install continue as well — but it can't be undone.":
        "Apple은 이 Apple ID에 서명 인증서를 2개 발급하지 않습니다. 이미 있는 인증서를 SideStore가 만들었다면 SideInstaller도 그 인증서로 서명할 수 있으며, 아무것도 폐기되지 않습니다. 그 인증서를 폐기해도 설치를 계속할 수 있지만, 이 작업은 되돌릴 수 없습니다.",
    "If SideStore made it, tap “Use SideStore's certificate” above: SideInstaller signs with that one too, and nothing is revoked.":
        "SideStore가 만든 인증서라면 위의 “SideStore의 인증서 사용”을 탭하세요. SideInstaller도 그 인증서로 서명하며, 아무것도 폐기되지 않습니다.",
    "SideInstaller signs with “%@” from now on. Nothing was revoked, so the apps already signed with it keep working.":
        "이제부터 SideInstaller는 “%@” 인증서로 서명합니다. 폐기된 것은 없으므로 이 인증서로 이미 서명한 앱은 계속 작동합니다.",
    "SideInstaller already signs with “%@”.": "SideInstaller는 이미 “%@” 인증서로 서명하고 있습니다.",
    "That certificate isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID (SideStore may be signed in with a different one). Nothing was changed.":
        "이 Apple ID의 인증서가 아닙니다. 이미 폐기되었거나 다른 Apple ID의 인증서입니다(SideStore에 다른 Apple ID로 로그인되어 있을 수 있습니다). 변경된 것은 없습니다.",
    "Couldn't use that certificate: %@": "해당 인증서를 사용하지 못했습니다: %@",
    "SideStore isn't installed on this iPhone, so there's no certificate to get from it.":
        "이 iPhone에 SideStore가 설치되어 있지 않아서 가져올 인증서가 없습니다.",
    "Sign with this certificate?": "이 인증서로 서명하시겠습니까?",
    "A link sent SideInstaller a signing certificate. Only use it if you asked for one: SideInstaller will sign apps with it from now on, in place of its own. It's used only if it's one of your Apple ID's certificates.":
        "링크를 통해 SideInstaller에 서명 인증서가 전달되었습니다. 직접 요청한 경우에만 사용하세요. 사용하면 SideInstaller가 자체 인증서 대신 이 인증서로 앱에 서명합니다. 내 Apple ID의 인증서 중 하나인 경우에만 사용됩니다.",
    "Use it": "사용",
    "That link was meant to carry a signing certificate, but what it holds can't be read.":
        "이 링크는 서명 인증서를 전달하려는 것이었지만, 담긴 내용을 읽을 수 없습니다.",

    // MARK: - Location tab

    "Location spoofing": "위치 변경",
    "Not simulating": "시뮬레이션 안 함",
    "Simulated": "시뮬레이션 중",
    "Pick a place": "장소 선택",
    "Search for a place": "장소 검색",
    "Nothing found for “%@”.": "“%@”에 대한 검색 결과가 없습니다.",
    "Set location": "위치 설정",
    "Setting": "설정 중",
    "Reset to real location": "실제 위치로 되돌리기",
    "Location set to %@.": "위치를 %@(으)로 설정했습니다.",
    "Location reset. The device is using its own again.": "위치를 초기화했습니다. 기기가 다시 실제 위치를 사용합니다.",
    "That isn't a valid coordinate.": "올바른 좌표가 아닙니다.",
    "Location session closed — set it up again.": "위치 세션이 종료되었습니다. 다시 설정하세요.",
    "Downloading %@ failed (HTTP %d).": "%@ 다운로드에 실패했습니다(HTTP %d).",
    "Couldn't build the download URL for %@.": "%@의 다운로드 URL을 만들지 못했습니다.",

    // Location › saved places and GPX routes.
    "Saved places": "저장된 장소",
    "Save this place": "이 장소 저장",
    "Name": "이름",
    "Show on map": "지도에 표시",
    "Tap Save under the map to keep the spot under the pin. Tapping a saved place sets it straight away.":
        "지도 아래의 저장을 탭하면 핀이 가리키는 위치를 저장합니다. 저장된 장소를 탭하면 바로 그 위치로 설정됩니다.",
    "Play a GPX route": "GPX 경로 재생",
    "Import a .gpx file and the device moves along it at the speed you pick, then stays at its last point.":
        ".gpx 파일을 가져오면 기기가 선택한 속도로 그 경로를 따라 이동하고, 마지막 지점에 머뭅니다.",
    "Import GPX file": "GPX 파일 가져오기",
    "Couldn't read %@ as a GPX file.": "%@ 파일을 GPX 파일로 읽지 못했습니다.",
    "%@ has no track, route or waypoints in it.": "%@ 파일에 트랙, 경로, 웨이포인트가 없습니다.",
    "As recorded": "기록된 대로",
    "Walk": "도보",
    "Cycle": "자전거",
    "Drive": "자동차",
    "Speed": "속도",
    "Play route": "경로 재생",
    "Playing route · %d%%": "경로 재생 중 · %d%%",
    "Stop here": "여기서 중지",
    "%@ of %@": "%@ / %@",
    "Route finished. The device stays at its last point.": "경로가 끝났습니다. 기기는 마지막 지점에 머뭅니다.",
    "Route stopped. The device stays where it got to.": "경로를 중지했습니다. 기기는 도달한 지점에 머뭅니다.",
    "Route playback stopped: %@": "경로 재생이 중지되었습니다: %@",
    // Location › planned routes (OpenStreetMap).
    "Add stop": "경유지 추가",
    "Add as stop": "경유지로 추가",
    "Plan a route": "경로 계획",
    "Travel by": "이동 수단",
    "Goes along each street at its speed limit, from OpenStreetMap. A street without one mapped gets the usual limit for its kind of road.":
        "OpenStreetMap의 제한 속도에 따라 각 도로를 이동합니다. 제한 속도가 등록되지 않은 도로는 해당 도로 종류의 일반적인 제한 속도를 적용합니다.",
    "Rides streets and paths a bike can take, at a cycling pace.": "자전거로 갈 수 있는 도로와 길을 자전거 속도로 이동합니다.",
    "Walks streets and paths at a walking pace.": "도로와 길을 걷는 속도로 이동합니다.",
    "Start where the device is": "기기가 있는 위치에서 시작",
    "Move the map so the pin is on a place, then tap Add stop. Add as many as you like: the route goes to each in order.":
        "핀이 원하는 장소에 오도록 지도를 움직인 뒤 “경유지 추가”를 탭하세요. 원하는 만큼 추가할 수 있으며, 경로는 추가한 순서대로 각 경유지를 지납니다.",
    "The device's location": "기기의 위치",
    "Stop %d": "경유지 %d",
    "Clear stops": "경유지 지우기",
    "Move up": "위로 이동",
    "Move down": "아래로 이동",
    "Find route": "경로 찾기",
    "Finding route": "경로를 찾는 중",
    "Add one more stop to plan a route.": "경로를 계획하려면 경유지를 하나 더 추가하세요.",
    "Routes from OpenStreetMap, © OpenStreetMap contributors":
        "경로 출처: OpenStreetMap, © OpenStreetMap 기여자",
    "Speed limits are mapped for all of it.": "전 구간의 제한 속도가 등록되어 있습니다.",
    "Speed limits are mapped for %d%% of it; the rest is estimated.":
        "구간의 %d%%에 제한 속도가 등록되어 있으며, 나머지는 추정한 값입니다.",
    "Average %@": "평균 %@",
    "Speed limit %@": "제한 속도 %@",
    "No speed limit · going %@": "제한 속도 없음 · 이동 속도 %@",
    "No limit mapped · going %@": "제한 속도 미등록 · 이동 속도 %@",
    "Going %@": "이동 속도 %@",
    "No street name": "도로명 없음",
    "Estimated speed limit %@": "추정 제한 속도 %@",
    "No speed limit": "제한 속도 없음",
    "No route found between these stops. Move them onto roads or paths, or travel another way.":
        "이 경유지들 사이의 경로를 찾지 못했습니다. 경유지를 도로나 길 위로 옮기거나 다른 이동 수단을 선택하세요.",
    "A stop is too far from any road or path. Move it closer and try again.":
        "경유지가 도로나 길에서 너무 멀리 떨어져 있습니다. 더 가까이 옮긴 뒤 다시 시도하세요.",
    "Too many stops for the route server. Take some out and try again.":
        "경로 서버에서 처리하기에 경유지가 너무 많습니다. 일부를 삭제한 뒤 다시 시도하세요.",
    "That route is too long for the route server. Make it shorter, or split it up.":
        "경로 서버에서 처리하기에 경로가 너무 깁니다. 경로를 줄이거나 나누어 주세요.",
    "The route server is busy. Try again in a minute.": "경로 서버가 바쁩니다. 잠시 후 다시 시도하세요.",
    "The route server couldn't plan this route (%@).": "경로 서버가 이 경로를 계획하지 못했습니다(%@).",

    // MARK: - Entitlements tab

    "Entitlements": "Entitlements",
    "Load apps": "앱 불러오기",
    "%d App ID": "App ID %d개",
    "%d App IDs": "App ID %d개",
    "No App IDs": "App ID 없음",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "이 Apple ID로 등록된 앱이 아직 없습니다. 먼저 SideInstaller로 앱을 설치한 뒤 다시 확인하세요.",
    "Memory and performance": "메모리 및 성능",
    "Other free capabilities": "기타 무료 기능",
    "Beta": "베타",
    "Recommended": "추천",
    "Select all": "모두 선택",
    "None": "선택 해제",
    "Enable %d selected": "선택한 %d개 활성화",
    "Asking Apple": "Apple에 요청하는 중",
    "%d of %d enabled": "%d/%d 활성화됨",
    "Install the app again for these to take effect.": "적용하려면 앱을 다시 설치하세요.",

    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "사이드로드한 앱",
    "Reading the device": "기기를 읽는 중",

    // Refresh all: signing the installed apps again.
    "iOS %@ isn't supported — SideInstaller needs iOS %@ or later.":
        "iOS %@ 버전은 지원되지 않습니다. SideInstaller는 iOS %@ 이상이 필요합니다.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Under Tools › Certificates, use SideStore's certificate or revoke that one, then refresh again.":
        "Apple이 이 Apple ID에 서명 인증서를 발급하지 않습니다. 이미 인증서가 있다고 응답했습니다(오류 7460). 도구 › 인증서에서 SideStore의 인증서를 사용하거나 기존 인증서를 폐기한 뒤 다시 갱신하세요.",
    "An install is already running. Wait for it to finish, then refresh.":
        "이미 설치가 진행 중입니다. 끝날 때까지 기다린 뒤 다시 갱신하세요.",
    "Getting ready": "준비 중",
    "Stopping after this app": "이 앱까지 진행하고 중단하는 중",
    "Refreshing %@": "%@ 갱신 중",
    "Signed by team %@, not the one you're signed in as — refreshing it here would install a second copy.":
        "지금 로그인한 팀이 아닌 %@ 팀이 서명한 앱입니다. 여기서 갱신하면 사본이 하나 더 설치됩니다.",
    "Refreshed. Its seven days start again now.": "갱신했습니다. 7일이 지금부터 다시 시작됩니다.",
    "Nothing was refreshed.": "갱신된 앱이 없습니다.",
    "Refreshed %d of %d apps.": "앱 %d개를 갱신했습니다(전체 %d개).",
    "Refresh all apps?": "모든 앱을 갱신하시겠습니까?",
    "Refresh all": "모두 갱신",
    "%@ will be signed again with your Apple ID and installed over the copy on this device. It keeps its data, and its seven days start over.":
        "%@ 앱을 Apple ID로 다시 서명해 이 기기에 있는 앱 위에 설치합니다. 데이터는 그대로 유지되고, 7일이 다시 시작됩니다.",
    "%d apps will be signed again with your Apple ID and installed over the copies on this device. They keep their data, and their seven days start over.":
        "앱 %d개를 Apple ID로 다시 서명해 이 기기에 있는 앱 위에 설치합니다. 데이터는 그대로 유지되고, 7일이 다시 시작됩니다.",
    "%d app can be signed again from an IPA already on this iPhone.":
        "앱 %d개를 이 iPhone에 이미 있는 IPA로 다시 서명할 수 있습니다.",
    "%d apps can be signed again from IPAs already on this iPhone.":
        "앱 %d개를 이 iPhone에 이미 있는 IPA로 다시 서명할 수 있습니다.",
    "Reload": "다시 불러오기",
    "Waiting": "대기 중",
    "In progress": "진행 중",
    "Failed": "실패",
    "%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.":
        "이 목록의 앱 %d개는 SideInstaller에 IPA가 없어 이 화면에서 갱신할 수 없습니다. 해당 앱을 설치한 도구에서 갱신하거나, 먼저 .ipa를 가져오세요.",
    "%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.":
        "이 목록의 앱 %d개는 SideInstaller에 IPA가 없어 이 화면에서 갱신할 수 없습니다. 해당 앱을 설치한 도구에서 갱신하거나, 먼저 .ipa를 가져오세요.",
    "%d app": "앱 %d개",
    "%d apps": "앱 %d개",
    "%d app needs refreshing": "앱 %d개 갱신 필요",
    "%d apps need refreshing": "앱 %d개 갱신 필요",
    "No sideloaded apps": "사이드로드한 앱 없음",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "이 기기에서 프로비저닝 프로파일로 설치된 앱이 없습니다. App Store 앱은 만료되지 않으므로 여기에 표시되지 않습니다.",
    "No matching profile": "일치하는 프로파일 없음",
    "Expires today": "오늘 만료",
    "Expires tomorrow": "내일 만료",
    "Expires in %d days — %@": "%d일 후 만료 — %@",
    "Expired %@": "%@에 만료됨",
    "Unused profiles": "사용하지 않는 프로파일",
    "Issued to App IDs no installed app is running on.":
        "설치된 어떤 앱도 사용하지 않는 App ID에 발급된 프로파일입니다.",
    "Older profiles": "이전 프로파일",
    "Bundle identifier": "번들 ID",
    "App ID": "App ID",
    "Version": "버전",
    "Profile name": "프로파일 이름",
    "Team": "팀",
    "Team ID": "팀 ID",
    "Issued": "발급일",
    "Profile UUID": "프로파일 UUID",
    "Capabilities": "기능",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "와일드카드 App ID — 그 아래의 모든 번들 ID에 적용되며, 앱별 기능(Capabilities)은 포함할 수 없습니다.",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "이 App ID에 대한 프로비저닝 프로파일이 기기에 없습니다. 앱이 이미 실행되지 않을 수 있습니다. 다시 설치하면 해결됩니다.",

    // MARK: - Settings

    "Settings": "설정",
    "Done": "완료",
    "Language": "언어",
    "App language": "앱 언어",
    "Sounds": "사운드",
    "Sound effects": "효과음",
    "Auto": "자동",
    // The Tunnel section: starting LocalDevVPN from here.
    "Tunnel": "터널",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.":
        "%@:%d에서 연결을 거부했습니다. 터널은 트래픽을 전달하고 있지만, 기기가 페어링 포트를 열고 있지 않다는 뜻입니다. 이 포트는 개발자 모드가 켜져 있을 때만 열리고, iOS는 재시동할 때마다 다시 켜라고 요청합니다. 설정 › 개인정보 보호 및 보안 › 개발자 모드를 켠 뒤 다시 시도하세요. 이미 켜져 있다면 “페어링 파일”에서 이 iPhone을 다시 페어링하세요.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port: Developer Mode is off. Turn it on under Settings › Privacy & Security › Developer Mode (the iPhone restarts), then try again.":
        "%@:%d에서 연결을 거부했습니다. 터널은 트래픽을 전달하고 있지만, 개발자 모드가 꺼져 있어 이 iPhone이 페어링 포트를 열고 있지 않습니다. 설정 › 개인정보 보호 및 보안 › 개발자 모드를 켠 뒤(iPhone이 재시동됩니다) 다시 시도하세요.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port, although Developer Mode is on. Pair this iPhone again under “Pairing file”, then try again. If it still fails, restart the iPhone.":
        "%@:%d에서 연결을 거부했습니다. 터널은 트래픽을 전달하고 있지만, 개발자 모드가 켜져 있는데도 이 iPhone이 페어링 포트를 열고 있지 않습니다. “페어링 파일”에서 이 iPhone을 다시 페어링한 뒤 다시 시도하세요. 그래도 실패하면 iPhone을 재시동하세요.",
    "Start LocalDevVPN when needed": "필요할 때 LocalDevVPN 시작",
    "Start LocalDevVPN now": "지금 LocalDevVPN 시작",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "LocalDevVPN이 설치되어 있지 않습니다. App Store에서 받으면 여기서 실행할 수 있습니다.",

    "Downloaded IPAs": "다운로드한 IPA",
    "%@ used": "%@ 사용 중",
    "imported": "가져옴",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "다운로드한 IPA가 없습니다. 설치 탭에서 설치한 IPA가 여기에 보관됩니다.",
    "Downloaded %@": "%@ 다운로드됨",
    "Added %@": "%@ 추가됨",
    "Delete this download?": "이 다운로드를 삭제하시겠습니까?",
    "Delete": "삭제",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "“%@”(%@) 파일이 삭제됩니다. 설치 탭에서 언제든 다시 다운로드할 수 있습니다.",
    "Couldn't delete %@: %@": "%@ 파일을 삭제하지 못했습니다: %@",
    "Server": "서버",
    "Custom…": "직접 입력…",
    "Server URL": "서버 URL",
    "Anisette Server": "Anisette 서버",
    "Starts with %@": "%@부터 시작",
    "Auto starts with the server that signed in last, then tries the others, the ones most likely to work first.":
        "자동은 마지막으로 로그인에 성공한 서버부터 시작해서, 작동할 가능성이 높은 순서대로 나머지 서버를 시도합니다.",
    "Only this server is tried. If it fails, so does sign-in: choose Auto to have SideInstaller try the others.":
        "이 서버만 시도합니다. 실패하면 로그인도 실패하므로, 자동을 선택해 SideInstaller가 다른 서버를 시도하게 하세요.",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "설정 › Anisette 서버에서 선택한 서버만 시도했습니다. 그곳에서 자동을 선택하면 실패했을 때 SideInstaller가 다른 서버를 시도합니다.",
    "Device IP": "기기 IP",
    "Advanced": "고급",
    "Clear": "지우기",
    "Activity Log (%d)": "활동 로그 (%d)",

    // Settings › Developer Mode: AMFI requests over the device link.
    "Developer Mode": "개발자 모드",
    "Show Developer Mode in Settings": "설정에서 개발자 모드 표시",
    "Turn on Developer Mode": "개발자 모드 켜기",
    "Asking this iPhone…": "이 iPhone에 요청하는 중…",
    "Both need a link to this iPhone that already works: LocalDevVPN plus a pairing file, such as one imported on iOS 17.4 to 26. On iOS 27 the link itself needs Developer Mode, so they can't bring back a missing option there.":
        "두 방법 모두 이미 작동하는 이 iPhone과의 연결이 필요합니다. LocalDevVPN과, iOS 17.4~26에서 가져온 것과 같은 페어링 파일이 있어야 합니다. iOS 27에서는 연결 자체에 개발자 모드가 필요하므로, 사라진 옵션을 이 방법으로 되살릴 수 없습니다.",
    "Turn on Developer Mode?": "개발자 모드를 켜시겠습니까?",
    "Turn On and Restart": "켜고 재시동",
    "This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode.":
        "이 iPhone이 바로 재시동됩니다. 잠금을 해제하면 표시되는 알림에서 “켜기”를 탭하세요. iOS는 iPhone에 암호가 설정되어 있지 않을 때만 이 방법을 허용합니다.",
    "Developer Mode is already on.": "개발자 모드가 이미 켜져 있습니다.",
    "Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.":
        "이제 설정 › 개인정보 보호 및 보안의 아래쪽에 개발자 모드가 표시됩니다. 그곳에서 켜면 iOS가 재시동되어 완료됩니다.",
    "Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.":
        "개발자 모드가 켜지도록 설정되었으며, 이 iPhone이 지금 재시동됩니다. 잠금을 해제한 뒤 “켜기”를 탭하세요.",
    "An install is already running. Wait for it to finish, then try again.":
        "이미 설치가 진행 중입니다. 끝날 때까지 기다린 뒤 다시 시도하세요.",
    "iOS turns Developer Mode on from here only while this iPhone has no passcode. Tap “Show Developer Mode in Settings” and turn it on there instead.":
        "iOS는 iPhone에 암호가 없을 때만 여기에서 개발자 모드를 켤 수 있습니다. 대신 “설정에서 개발자 모드 표시”를 탭하고 설정에서 켜세요.",
    "This iPhone didn't take the Developer Mode request: %@":
        "이 iPhone이 개발자 모드 요청을 받아들이지 않았습니다: %@",

    // MARK: - Release channels & downloads

    "Stable": "Stable",
    "Nightly": "Nightly",

    // Version picker (Advanced)

    "%@ version": "%@ 버전",
    "Latest": "최신",
    "Latest (%@)": "최신 (%@)",
    "Couldn't load the other versions: %@": "다른 버전을 불러오지 못했습니다: %@",
    "Try again": "다시 시도",

    "couldn't find the IPA in the %@ %@ release":
        "%@ %@ 릴리즈에서 IPA를 찾을 수 없습니다",
    "%@ has no %@ release right now": "%@에는 지금 %@ 릴리즈가 없습니다",
    "bad asset URL": "잘못된 에셋 URL",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "이 네트워크에서 GitHub이 요청 횟수를 제한하고 있습니다. 차단된 것은 아니며 제한은 저절로 풀립니다. %@에 다시 시도하세요.",
    "GitHub answered HTTP %d%@": "GitHub이 HTTP %d로 응답했습니다%@",
    "GitHub isn't serving %@ right now — the repository has been taken down, moved or made private, so there's nothing to download. Nothing is wrong with this iPhone or its network.":
        "지금 GitHub이 %@을(를) 제공하지 않습니다. 저장소가 삭제되었거나 이전되었거나 비공개로 바뀌어서 내려받을 파일이 없습니다. 이 iPhone이나 네트워크에는 문제가 없습니다.",
    "couldn't reach GitHub: %@": "GitHub에 연결할 수 없습니다: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "GitHub의 응답이 릴리즈 정보가 아닙니다(%@). 이 네트워크의 무언가가 응답을 바꿨을 수 있습니다.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "%@(으)로 다운로드된 파일은 IPA가 아닙니다. 이 네트워크가 대신 웹 페이지를 돌려줬거나 전송이 중간에 끊겼을 수 있습니다.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "그 링크가 HTTP %d로 응답했습니다. 직접 다운로드 링크가 아니거나 로그인이 필요합니다.",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "2단계 인증이 취소되었습니다.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID 또는 암호가 올바르지 않습니다. Apple 계정의 이메일과 암호를 확인한 뒤 다시 시도하세요.",
    "Apple ID sign-in failed on %@. Error: %@":
        "%@에서 Apple ID 로그인에 실패했습니다. 오류: %@",
    "Apple ID sign-in failed on %@. Error via %@: %@":
        "%@에서 Apple ID 로그인에 실패했습니다. %@ 경유 오류: %@",
    "Apple's sign-in server refused the request (HTTP 503). It isn't your password or the anisette server, so trying more servers won't help. Try again later, or update SideInstaller.":
        "Apple 로그인 서버가 요청을 거부했습니다(HTTP 503). 암호나 Anisette 서버 문제가 아니므로 다른 서버를 시도해도 소용없습니다. 나중에 다시 시도하거나 SideInstaller를 업데이트하세요.",
    "“%@” makes its anisette data with Apple's Android library, and Apple now refuses to finish signing in through those servers (error -80046), after your password and code. In Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "“%@”은(는) Apple의 Android 라이브러리로 anisette 데이터를 만들며, 이제 Apple은 암호와 코드를 입력한 뒤 이러한 서버를 통한 로그인 완료를 거부합니다(오류 -80046). 설정 › Anisette 서버에서 자동 또는 “SideStore (New)” 같은 Mac 서버를 선택하세요.",
    "Apple refused to finish signing in (error -80046), even through a Mac anisette server, the kind it still accepted. Try again later, or check for a SideInstaller update.":
        "Apple이 로그인 완료를 거부했습니다(오류 -80046). 지금까지 허용하던 Mac anisette 서버를 통해서도 마찬가지였습니다. 나중에 다시 시도하거나 SideInstaller 업데이트가 있는지 확인하세요.",
    "Apple refused to finish signing in through “%@” (error -80046). It now only accepts sign-ins through anisette servers on its macOS library: in Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "Apple이 “%@”을(를) 통한 로그인 완료를 거부했습니다(오류 -80046). 이제 Apple은 macOS 라이브러리를 사용하는 anisette 서버를 통한 로그인만 허용합니다. 설정 › Anisette 서버에서 자동 또는 “SideStore (New)” 같은 Mac 서버를 선택하세요.",
    "Apple won't send a code by text or call to this sign-in, so it was sent to your Apple devices.":
        "Apple이 이 로그인에는 문자나 전화로 코드를 보내지 않으므로, 코드를 Apple 기기로 보냈습니다.",
    "Apple didn't confirm sending a code to your Apple devices. If one arrived, enter it; if not, try another way.":
        "Apple이 Apple 기기로 코드를 보냈는지 확인해 주지 않았습니다. 코드를 받았다면 입력하고, 받지 못했다면 다른 방법을 시도하세요.",
    "SideInstaller can't reach Apple's sign-in server (gsa.apple.com), though this iPhone has an internet connection. Something is blocking it: a firewall, a DNS filter or ad blocker, Screen Time content restrictions, or another VPN app. Turn it off or try another network, then try again.":
        "이 iPhone이 인터넷에 연결되어 있는데도 SideInstaller가 Apple 로그인 서버(gsa.apple.com)에 연결할 수 없습니다. 방화벽, DNS 필터나 광고 차단기, 스크린 타임 콘텐츠 제한, 다른 VPN 앱 등이 접속을 막고 있습니다. 해당 기능을 끄거나 다른 네트워크를 사용한 뒤 다시 시도하세요.",
    "SideInstaller can't reach Apple: Cellular Data is turned off for it. Turn SideInstaller on in Settings › Cellular, or join a Wi-Fi network with internet access, then try again.":
        "SideInstaller가 Apple에 연결할 수 없습니다. SideInstaller의 셀룰러 데이터가 꺼져 있습니다. 설정 › 셀룰러에서 SideInstaller를 켜거나, 인터넷이 되는 Wi-Fi에 연결한 뒤 다시 시도하세요.",
    "SideInstaller can't reach Apple: iOS isn't letting it use Wi-Fi. In Settings › Apps › SideInstaller › Wireless Data, choose WLAN & Cellular Data, then try again.":
        "SideInstaller가 Apple에 연결할 수 없습니다. iOS가 Wi-Fi 사용을 허용하지 않고 있습니다. 설정 › 앱 › SideInstaller › 무선 데이터에서 “WLAN 및 셀룰러 데이터”를 선택한 뒤 다시 시도하세요.",
    "SideInstaller can't reach Apple: a VPN set to carry all traffic is disconnected, so iOS is holding traffic back. Reconnect it, or turn off its kill switch or Connect On Demand, then try again.":
        "SideInstaller가 Apple에 연결할 수 없습니다. 모든 트래픽을 전달하도록 설정된 VPN의 연결이 끊겨서 iOS가 트래픽을 막고 있습니다. VPN을 다시 연결하거나 킬 스위치 또는 주문형 연결을 끈 뒤 다시 시도하세요.",
    "SideInstaller can't reach Apple: this iPhone has no internet connection. Connect to Wi-Fi or turn on cellular data, then try again.":
        "SideInstaller가 Apple에 연결할 수 없습니다. 이 iPhone이 인터넷에 연결되어 있지 않습니다. Wi-Fi에 연결하거나 셀룰러 데이터를 켠 뒤 다시 시도하세요.",
    "Apple is temporarily limiting sign-ins for this Apple ID or network (HTTP 429). Trying other servers won't help, and every attempt can extend the wait, so leave it a while before signing in again.":
        "이 Apple ID 또는 네트워크의 로그인을 Apple이 일시적으로 제한하고 있습니다(HTTP 429). 다른 서버를 시도해도 소용없고, 시도할 때마다 대기 시간이 늘어날 수 있으니 한동안 기다렸다가 다시 로그인하세요.",
    "If you're sure the password is right, Apple may be limiting sign-in attempts: wait a while before trying again.":
        "암호가 확실히 맞다면, Apple이 로그인 시도를 제한하고 있을 수 있습니다. 잠시 기다린 뒤 다시 시도하세요.",
    "Apple has locked this Apple Account for security reasons (error -20209), so every sign-in fails until it's unlocked. Reset its password at iforgot.apple.com, then sign in again with the new password.":
        "보안상의 이유로 Apple이 이 Apple 계정을 잠갔습니다(오류 -20209). 잠금이 풀릴 때까지 모든 로그인이 실패합니다. iforgot.apple.com에서 암호를 재설정한 뒤 새 암호로 다시 로그인하세요.",
    "the anisette server": "Anisette 서버",
    "all %d anisette servers": "Anisette 서버 %d개 전부",
    "%d anisette servers (%d skipped)": "Anisette 서버 %d개(%d개 건너뜀)",
    "Not signed in.": "로그인되어 있지 않습니다.",
    "No SideStore IPA downloaded.": "다운로드한 SideStore IPA가 없습니다.",
    "Signing failed: %@": "서명 실패: %@",
    "No signed bundle to install.": "설치할 서명된 번들이 없습니다.",
    "Device link dropped — reconnect.":
        "기기와의 연결이 끊어졌습니다. 다시 연결하세요.",
    "Pairing didn't finish — no pairing file yet.":
        "페어링이 끝나지 않았습니다. 아직 페어링 파일이 없습니다.",
    "Pairing file missing — pairing must run first.":
        "페어링 파일이 없습니다. 먼저 페어링을 진행해야 합니다.",
    "Pairing file missing — generate it first.":
        "페어링 파일이 없습니다. 먼저 생성하세요.",
    "No pairing file yet — tap “Generate pairing file” first.":
        "아직 페어링 파일이 없습니다. 먼저 “페어링 파일 생성”을 탭하세요.",
    "%@ isn't installed yet — install must run first.":
        "%@ 앱이 아직 설치되지 않았습니다. 먼저 설치를 진행해야 합니다.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ 파일은 올바른 IPA가 아닙니다. 받아온 다운로드가 오류 페이지를 돌려줬거나 복사가 중간에 멈췄을 수 있습니다. 파일을 교체한 뒤 설치를 다시 탭하세요.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ 파일은 IPA가 아닙니다. .ipa 파일 자체를 선택하세요. 올바른 파일 같다면 다운로드가 오류 페이지를 저장했거나 중간에 멈췄을 수 있습니다.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "가져온 IPA가 아직 없습니다. “.ipa 가져오기”를 탭하고 파일을 선택하세요.",
    "Couldn't import %@: %@": "%@ 파일을 가져오지 못했습니다: %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "SideInstaller가 다운로드할 수 있는 링크가 아닙니다. .ipa를 내려받는 https:// 주소 전체를 붙여넣으세요.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "그 링크가 IPA를 돌려주지 않았습니다. 파일 자체를 내려받는 링크여야 합니다. .ipa로 연결만 해 주는 페이지나 먼저 로그인을 요구하는 페이지는 웹 페이지로 전달됩니다.",
    "Couldn't download that link: %@": "그 링크를 다운로드하지 못했습니다: %@",
    "there's nothing to download for a custom IPA — import one first":
        "사용자 지정 IPA는 내려받을 항목이 없습니다. 먼저 IPA를 가져오세요.",
    "your app": "내 앱",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "이 Apple ID로는 서명 인증서를 발급받을 수 없습니다. Apple이 이미 인증서가 있거나 발급 요청이 아직 처리 중이라고 응답했습니다(오류 7460). SideInstaller는 기존 인증서를 재사용하지 못했고, 교체하는 대신 작업을 중단했습니다. 위의 안내를 참고하세요.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "이 기기%@를 Apple ID의 개발자 팀에 등록하지 못해서 Apple이 프로비저닝 프로파일을 발급하지 않습니다. %@ — 위의 단계를 참고하세요.",
    "Connect to Wi-Fi": "Wi-Fi에 연결",
    "Open Settings › Wi-Fi and join a network.": "설정 › Wi-Fi를 열어 네트워크에 연결하세요.",
    "Then come back here — this continues automatically.": "그런 다음 여기로 돌아오세요. 자동으로 이어집니다.",
    "Tap Connect so the toggle turns on.": "“Connect”를 탭해서 스위치를 켜세요.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Wi-Fi를 켜 둔 채 여기로 돌아오세요. 자동으로 이어집니다.",
    "Get LocalDevVPN": "LocalDevVPN 받기",
    "Import an .ipa first": "먼저 .ipa 가져오기",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "위의 “.ipa 가져오기”를 탭하고 파일을 선택하세요. 파일 앱에서 접근할 수 있는 곳이면 iCloud Drive나 USB 드라이브에 있어도 됩니다.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "또는 그 버튼 아래에 다운로드 링크를 붙여넣으면 SideInstaller가 .ipa를 직접 받아옵니다.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "또는 파일 앱에서 .ipa를 길게 누르고 공유를 탭한 뒤 SideInstaller를 선택하세요. 선택 창 없이 파일이 바로 전달됩니다.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "또는 파일 › 나의 iPhone › SideInstaller에 복사해 두세요. SideInstaller가 그곳의 파일도 찾습니다.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "GitHub이 차단된 곳에서는 이 방법을 쓰세요. 다른 기기에서 IPA를 받아 옮겨 와서 여기서 설치하면 됩니다.",
    "Bring the .ipa yourself": ".ipa를 직접 준비하세요",
    "%@ can't be downloaded while its GitHub repository is offline. The other apps still install as usual.":
        "GitHub 저장소가 오프라인이라 %@ 앱은 다운로드할 수 없습니다. 다른 앱은 평소처럼 설치할 수 있습니다.",
    "To install it anyway, get its .ipa from somewhere you trust, name it %@, and copy it into Files › On My iPhone › SideInstaller.":
        "그래도 설치하려면 신뢰할 수 있는 곳에서 .ipa를 구해 이름을 %@(으)로 바꾸고, 파일 › 나의 iPhone › SideInstaller에 복사하세요.",
    "Then tap Install again — SideInstaller uses your file instead of downloading one.":
        "그런 다음 설치를 다시 탭하세요. SideInstaller가 다운로드하는 대신 그 파일을 사용합니다.",
    "Pair this iPhone in Settings": "설정에서 이 iPhone 페어링",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "설정 앱을 열고 개인정보 보호 및 보안 › 개발자 모드로 이동하세요.",
    "Tap “Pair with SideInstaller”.": "“SideInstaller와 페어링”을 탭하세요.",
    "Enter your iPhone’s passcode if it asks for it.": "iPhone 암호를 요청하면 입력하세요.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "SideInstaller로 돌아와 표시되는 코드를 확인한 뒤, 설정의 입력창에 같은 코드를 입력하세요.",
    "Type the code that appears at the top of the screen into the prompt in Settings. If none appears, come back to SideInstaller to read it.":
        "화면 맨 위에 나타나는 코드를 설정의 입력창에 입력하세요. 코드가 보이지 않으면 SideInstaller로 돌아와 확인하세요.",
    "Allow notifications when SideInstaller asks: that's how the pairing code reaches you in Settings.":
        "SideInstaller가 알림 허용을 요청하면 허용하세요. 그래야 설정에서 페어링 코드를 받을 수 있습니다.",

    // The pairing Live Activity
    "Privacy & Security › Developer Mode › Pair with SideInstaller":
        "개인정보 보호 및 보안 › 개발자 모드 › SideInstaller와 페어링",
    "Paired": "페어링됨",
    "Tap to return to SideInstaller.": "탭하면 SideInstaller로 돌아갑니다.",

    // The install's progress outside the app
    "Installing %@": "%@ 설치 중",
    "Paused": "일시 중지됨",
    "Open SideInstaller to finish the install.":
        "SideInstaller를 열어 설치를 마치세요.",
    "Check the App IDs it needs, then tap Install.":
        "필요한 App ID를 확인한 뒤 설치를 탭하세요.",
    "Tap Trust": "신뢰 탭",
    "Unlock this iPhone and tap Trust when it asks.":
        "이 iPhone의 잠금을 해제하고, 요청이 표시되면 신뢰를 탭하세요.",

    "A signing certificate already exists": "서명 인증서가 이미 있습니다",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Apple이 오류 7460으로 응답했습니다. 이 Apple ID에 iOS 개발용 인증서가 이미 있거나, 발급 요청이 아직 처리 중입니다.",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideInstaller가 그 인증서를 재사용하지 못했습니다. AltStore, SideStore, Sideloadly, 또는 다른 기기의 Xcode처럼 다른 곳에서 발급된 인증서라서, 필요한 개인 키가 이 iPhone에 없을 때 생기는 문제입니다.",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "위의 “폐기 후 재시도”를 사용하거나, 도구 탭의 인증서를 열어 “인증서 불러오기”를 탭한 뒤 거기서 폐기하세요.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "폐기는 되돌릴 수 없습니다. 그 인증서로 서명된 모든 앱이 모든 기기에서 실행되지 않게 됩니다.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "또는 위에서 다른(또는 여분의) Apple ID로 로그인한 뒤 설치를 다시 탭하세요.",

    // MARK: - Guide cards

    // Guide: reset a locked Apple Account

    "Reset your Apple Account password": "Apple 계정 암호 재설정",
    "Apple has locked this Apple Account for security reasons, often after too many sign-in attempts. Every sign-in fails until it's unlocked, so tapping Install again won't help yet.":
        "보안상의 이유로 Apple이 이 Apple 계정을 잠갔습니다. 로그인 시도가 너무 많았을 때 흔히 생깁니다. 잠금이 풀릴 때까지 모든 로그인이 실패하므로, 지금은 설치를 다시 탭해도 소용없습니다.",
    "Open iForgot, enter this Apple Account's email, and follow Apple's steps to unlock it and reset its password.":
        "iForgot을 열어 이 Apple 계정의 이메일을 입력하고, Apple의 안내에 따라 잠금을 풀고 암호를 재설정하세요.",
    "Back in SideInstaller, open Settings › Account, swipe left on this Apple ID, tap Edit, and enter the new password.":
        "SideInstaller로 돌아와 설정 › 계정에서 이 Apple ID를 왼쪽으로 밀고, 편집을 탭한 뒤 새 암호를 입력하세요.",
    "Then tap Install again.": "그런 다음 설치를 다시 탭하세요.",
    "Open iForgot": "iForgot 열기",
    "Apple won't let this Apple Account use developer services because of its owner's age (error 1102). Sign in with an adult's Apple Account instead.":
        "계정 소유자의 나이 때문에 Apple이 이 Apple 계정의 개발자 서비스 사용을 허용하지 않습니다(오류 1102). 성인의 Apple 계정으로 로그인하세요.",
    "This Apple ID has no App IDs left (error 9120). A free Apple ID can register 10 a week, and each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "이 Apple ID에는 남은 App ID가 없습니다(오류 9120). 무료 Apple ID는 일주일에 10개를 등록할 수 있고, 각각 7일 동안 집계됩니다. 일부가 만료될 때까지 기다리거나 다른 Apple ID로 로그인하세요.",
    "This iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. Delete one of them, then try again.":
        "이 iPhone에는 무료 Apple ID로 서명한 앱이 이미 세 개 있습니다. 만료된 앱을 포함해 iOS가 허용하는 최대 개수입니다. 하나를 삭제한 뒤 다시 시도하세요.",
    "This Apple Account can't sign apps": "이 Apple 계정으로는 앱에 서명할 수 없습니다",
    "Apple only lets adults use the developer services SideInstaller signs apps with, and it reports that this Apple Account belongs to someone younger (error 1102).":
        "SideInstaller가 앱 서명에 쓰는 개발자 서비스는 Apple이 성인에게만 허용합니다. 이 Apple 계정은 미성년자의 계정으로 확인되었습니다(오류 1102).",
    "Sign in with an adult's Apple Account instead: open Settings › Account and add it there.":
        "성인의 Apple 계정으로 로그인하세요. 설정 › 계정을 열어 거기에 추가하면 됩니다.",
    "Apple won't let this Apple Account use developer services until its email address is verified (error 2160). Verify it at account.apple.com, then try again.":
        "이메일 주소를 인증하기 전까지 Apple이 이 Apple 계정의 개발자 서비스 사용을 허용하지 않습니다(오류 2160). account.apple.com에서 인증한 뒤 다시 시도하세요.",
    "Verify your Apple Account's email":
        "Apple 계정 이메일 인증",
    "Apple won't let this Apple Account sign apps until its email address is verified (error 2160). Signing in again or through another anisette server won't change that.":
        "이메일 주소를 인증하기 전까지 Apple이 이 Apple 계정으로 앱을 서명하도록 허용하지 않습니다(오류 2160). 다시 로그인하거나 다른 Anisette 서버를 써도 달라지지 않습니다.",
    "Sign in at account.apple.com with this Apple Account and verify its email address when Apple asks. Apple sends the code or link to that address, so check its spam folder too.":
        "이 Apple 계정으로 account.apple.com에 로그인해 Apple이 요청하면 이메일 주소를 인증하세요. 코드나 링크는 그 주소로 전송되니 스팸 메일함도 확인하세요.",
    "Open Apple Account":
        "Apple 계정 열기",
    "No App IDs left this week": "이번 주에는 남은 App ID가 없습니다",
    "Every app SideInstaller signs needs an App ID, which its extensions share. A free Apple ID can register 10 a week, and each one counts for 7 days.":
        "SideInstaller가 서명하는 모든 앱에는 App ID가 필요하며, 앱의 확장 기능은 이 App ID를 함께 사용합니다. 무료 Apple ID는 일주일에 10개를 등록할 수 있고, 등록한 App ID는 각각 7일 동안 개수에 포함됩니다.",
    "They can't be deleted sooner. Wait until some expire, then tap Install again.":
        "그보다 일찍 삭제할 수는 없습니다. 일부가 만료될 때까지 기다린 뒤 설치를 다시 탭하세요.",
    "Or sign in with a different (or spare) Apple ID in Settings › Account, then tap Install again.":
        "또는 설정 › 계정에서 다른(또는 여분의) Apple ID로 로그인한 뒤 설치를 다시 탭하세요.",
    "Three sideloaded apps already": "이미 사이드로드한 앱이 3개입니다",
    "iOS allows three apps signed with a free Apple ID on an iPhone at a time, and it refused a fourth.":
        "iOS는 무료 Apple ID로 서명한 앱을 iPhone 한 대에 3개까지만 허용하며, 네 번째 앱은 거부했습니다.",
    "Expired apps count too. Delete one you no longer need from the Home Screen.":
        "만료된 앱도 개수에 포함됩니다. 홈 화면에서 필요 없는 앱 하나를 삭제하세요.",

    // Guide: import a pairing file

    "Import a pairing file": "페어링 파일 가져오기",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@은(는) iPhone이 스스로와 페어링할 수 있는 첫 번째 버전입니다. 이 버전에서는 페어링 파일을 컴퓨터에서 만들어야 합니다.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "Mac, Windows PC 또는 Linux에서 이 iPhone을 연결하고 컴퓨터를 신뢰한 뒤 jitterbugpair(또는 “pymobiledevice3 lockdown pair”)를 실행하세요.",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "생성된 파일(.mobiledevicepairing 또는 .plist)을 AirDrop, iCloud Drive 또는 케이블로 이 iPhone에 보내세요.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "여기로 돌아와 “페어링 파일 가져오기”를 탭하고 그 파일을 선택하세요. 이후는 iOS %@에서와 똑같이 작동합니다.",
    "Get jitterbugpair": "jitterbugpair 받기",
    "From iOS 26.4 on it has to be a remote pairing file: this iPhone hangs up on lockdown ones, like jitterbugpair's, when they come through LocalDevVPN.":
        "iOS 26.4부터는 원격 페어링 파일이어야 합니다. 이 iPhone은 jitterbugpair가 만든 것 같은 lockdown 방식 파일이 LocalDevVPN을 통해 들어오면 연결을 끊습니다.",
    "Get idevice_pair": "idevice_pair 받기",
    "Make a remote pairing file": "원격 페어링 파일 만들기",
    "The pairing file you imported is a lockdown one. Since iOS 26.4, this iPhone hangs up on those when they come through LocalDevVPN, so it can't connect, and a new one of the same kind won't either.":
        "가져온 페어링 파일은 lockdown 방식입니다. iOS 26.4부터 이 iPhone은 이런 파일이 LocalDevVPN을 통해 들어오면 연결을 끊으므로 연결할 수 없으며, 같은 방식으로 새로 만들어도 마찬가지입니다.",
    "Come back here, tap “Replace” on the Pairing file card, and pick it.":
        "여기로 돌아와 페어링 파일 카드에서 “교체”를 탭하고 해당 파일을 선택하세요.",
    "On a Mac, Windows PC or Linux box, open idevice_pair, plug this iPhone in, and tap Trust if it asks. Pick it, choose “Remote pairing”, click “Create”, and keep this iPhone unlocked until it's done.":
        "Mac, Windows PC 또는 Linux 컴퓨터에서 idevice_pair를 열고 이 iPhone을 연결한 뒤, 요청이 표시되면 신뢰를 탭하세요. 목록에서 이 iPhone을 선택하고 “Remote pairing”을 고른 다음 “Create”를 클릭하세요. 완료될 때까지 iPhone의 잠금을 해제한 상태로 두세요.",
    "Click “Save to file…” and send the file to this iPhone, by AirDrop, iCloud Drive or a cable. A pairing file exported from iLoader works too.":
        "“Save to file…”을 클릭하고, 파일을 AirDrop, iCloud Drive 또는 케이블로 이 iPhone에 보내세요. iLoader에서 내보낸 페어링 파일도 사용할 수 있습니다.",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "인증서가 이미 있습니다",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple은 이 Apple ID에 서명 인증서를 2개 발급하지 않습니다. 이미 있는 인증서를 폐기하면 설치를 계속할 수 있지만, 이 작업은 되돌릴 수 없습니다.",
    "Loading certificates": "인증서 불러오는 중",
    "Revoke and retry": "폐기 후 재시도",
    "Which certificate should be revoked?": "어떤 인증서를 폐기하시겠습니까?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple은 이 Apple ID에 인증서가 있다고 응답했지만 목록에는 나오지 않았습니다. 아직 처리 중인 요청일 수 있으니 몇 분 기다린 뒤 설치를 다시 탭하세요.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "선택한 인증서로 서명된 모든 앱이 모든 기기에서 실행되지 않게 됩니다. AltStore, SideStore 또는 컴퓨터로 설치한 앱도 포함됩니다. 되돌릴 수 없습니다. 설치는 곧바로 다시 시도됩니다.",
    " (expired)": " (만료됨)",

    "Couldn't register this device": "이 기기를 등록하지 못했습니다",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Apple ID가 등록 가능한 기기 수 한도에 도달했습니다. 무료 계정은 1년에 몇 대만 등록할 수 있고, 연도가 바뀌기 전에는 이전 기기를 제거할 수 없습니다.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "가장 쉬운 해결 방법: 위의 입력란에 다른(또는 여분의) Apple ID를 입력한 뒤 설치를 다시 탭하세요.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller가 이 iPhone을 Apple ID의 개발자 팀에 자동으로 추가하지 못했습니다. 설치를 다시 탭하면 해결되는 경우가 많습니다. Apple의 개발자 서비스가 잠시 응답하지 않을 때가 있습니다.",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "계속 실패하면 기기를 직접 추가하세요. 이 기기의 UDID는 다음과 같습니다:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Apple Developer 포털의 “Register a Device” 양식에 이 UDID를 붙여넣은 뒤(유료 Apple Developer 계정이 필요합니다) 설치를 다시 탭하세요.",
    "Open device list": "기기 목록 열기",

    "Last step: trust %@": "마지막 단계: %@ 신뢰하기",
    "Open Settings › General › VPN & Device Management.":
        "설정 › 일반 › VPN 및 기기 관리를 여세요.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "“개발자 앱” 아래의 Apple ID를 탭한 뒤 신뢰를 탭하세요.",
    "Open %@ from your Home Screen — you're done.":
        "홈 화면에서 %@ 앱을 여세요. 모두 끝났습니다.",

    "Import the certificate into LiveContainer": "LiveContainer로 인증서 가져오기",
    "Open LiveContainer from your Home Screen.": "홈 화면에서 LiveContainer를 여세요.",
    "Tap the Settings tab.": "설정 탭으로 이동하세요.",
    "Tap “Import Certificate From SideStore”.":
        "“Import Certificate From SideStore”를 탭하세요.",
    "Wrong device IP": "기기 IP가 올바르지 않습니다",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "설정 › 고급 › 기기 IP의 주소는 이 iPhone이 이미 가지고 있는 주소라서, 반대편에 연결할 대상이 없습니다.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "기본값인 10.7.0.1로 되돌리세요. LocalDevVPN에서는 설정 › 기기 IP에 있는 값입니다. 메인 화면에 표시된 주소는 터널의 이 기기 쪽 끝이므로 해당하지 않습니다.",
    "If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one.":
        "LocalDevVPN의 주소를 변경했다면 그 기기 IP를 여기에 복사하세요. /32가 표시된다면 그것도 포함하세요.",
    "Device IP is %@, one of this iPhone's own addresses, and iOS won't let an app connect to those. In Settings › Advanced, set Device IP to the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default, not the “Connected to” address on its main screen.":
        "기기 IP가 %@인데, 이는 이 iPhone 자체의 주소 중 하나이며 iOS는 앱이 이런 주소에 연결하는 것을 허용하지 않습니다. 설정 › 고급에서 기기 IP를 LocalDevVPN의 설정 › 기기 IP에 있는 주소(기본값 10.7.0.1)로 설정하세요. LocalDevVPN 메인 화면의 “Connected to” 주소가 아닙니다.",
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "iOS가 이 iPhone에서 %@ 주소로 향하는 연결을 아무 데이터도 보내기 전에 거부했습니다. LocalDevVPN 메인 화면의 “Connected to” 주소처럼 이 iPhone 자체의 주소에는 이렇게 동작합니다. 설정 › 고급의 기기 IP는 LocalDevVPN의 설정 › 기기 IP에 있는 주소(기본값 10.7.0.1)여야 합니다. 이미 그렇게 설정되어 있다면 LocalDevVPN을 껐다 켠 뒤 다시 시도하세요.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "이 iPhone이 연결이 열리자마자 끊었습니다. iOS 26.4부터는 이 파일 같은 lockdown 방식 페어링 파일이 LocalDevVPN을 통해 들어오면 이렇게 동작합니다. 대신 이 iPhone을 자기 자신과 페어링하세요. 도구 › 페어링에서 “다시 생성”을 탭하거나, 먼저 페어링을 진행하는 설치를 탭하세요.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "이 iPhone이 연결이 열리자마자 끊었습니다. iOS 26.4부터는 이 파일 같은 lockdown 방식 페어링 파일이 LocalDevVPN을 통해 들어오면 이렇게 동작하므로, 같은 방식으로 새로 만들어도 소용없습니다. 원격 페어링 파일은 계속 사용할 수 있습니다. 컴퓨터에서 idevice_pair를 열고 “Remote pairing”을 선택한 뒤 “Create”를 클릭하고 “Save to file…”을 클릭하세요. 그런 다음 “페어링 파일”에서 그 파일을 가져오세요.",
    "This iPhone hung up on the connection: from iOS 26.4 on, it does that to lockdown pairing files like this one when they come through LocalDevVPN. See the steps above.":
        "이 iPhone이 연결을 끊었습니다. iOS 26.4부터는 이 파일 같은 lockdown 방식 페어링 파일이 LocalDevVPN을 통해 들어오면 이렇게 동작합니다. 위의 단계를 참고하세요.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "이 iPhone을 페어링하려면 필요합니다. 설정이 찾을 수 있도록 SideInstaller가 로컬 네트워크에 자신을 알립니다.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Wi-Fi 네트워크에 연결하세요. 이 iPhone을 페어링하려면 필요합니다. SideInstaller가 로컬 네트워크에서 발견될 수 있어야 합니다.",

    // MARK: - Side by Side tool

    // The tool's name is left in English everywhere, as SideStore's is.
    "Side by Side": "Side by Side",
    "Set up someone else's iPhone": "다른 사람의 iPhone에 SideInstaller 설치해 주기",
    "Steps": "단계",
    "Same Wi-Fi network": "같은 Wi-Fi 네트워크",
    "Their iPhone needs iOS %@ — SideInstaller pairs itself once it's installed, and nothing older can.":
        "상대방 iPhone은 iOS %@ 이상이 필요합니다. SideInstaller는 설치된 뒤 스스로 페어링하는데, 그보다 낮은 버전은 그렇게 할 수 없습니다.",
    "Their iPhone": "상대방 iPhone",
    "This iPhone is %@, so theirs will look similar.": "이 iPhone의 주소는 %@입니다. 상대방 주소도 이와 비슷한 형태입니다.",
    "IP address (optional)": "IP 주소(선택)",
    "Optional: leave it empty, and it fills in when their iPhone pairs.":
        "선택 사항입니다. 비워 두면 상대방 iPhone이 페어링될 때 자동으로 채워집니다.",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "상대방 iPhone에서: 설정 › Wi-Fi › 네트워크 옆 ⓘ를 탭한 뒤 “IP 주소”를 확인하세요.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” 값은 IPv4 주소가 아닙니다. 192.168.1.42 같은 형태여야 합니다.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ 주소는 이 iPhone이 이미 가지고 있는 주소입니다. Side by Side는 다른 사람의 iPhone에 설치하는 기능이니 상대방 주소를 입력하세요. 이 iPhone에 설치하려면 설치 탭을 사용하세요.",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "페어링된 기기는 이 iPhone이었습니다. 대신 상대방 iPhone의 설정에서 페어링하세요. 이 iPhone에 설치하려면 설치 탭을 사용하세요.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Wi-Fi가 꺼져 있습니다. 이 기능을 쓰려면 두 iPhone이 같은 Wi-Fi 네트워크에 있어야 합니다.",
    "Pair with their iPhone": "상대방 iPhone과 페어링",
    "No pair record for their iPhone.": "상대방 iPhone의 페어 레코드가 없습니다.",
    "The link to their iPhone dropped — start again.": "상대방 iPhone과의 연결이 끊어졌습니다. 처음부터 다시 시작하세요.",
    "Sign in to their Apple ID": "상대방 Apple ID로 로그인",
    "Apple ID to sign with": "서명에 사용할 Apple ID",
    "Enter the Apple ID to sign with, and its password.": "서명에 사용할 Apple ID와 암호를 입력하세요.",
    "Tip: Use the iPhone/iPad owner's Apple account credentials":
        "팁: iPhone/iPad 소유자의 Apple 계정 정보를 사용하세요",
    "Use my saved Apple ID instead": "저장된 내 Apple ID 사용",
    "Clear their details": "상대방 정보 지우기",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "이 iPhone은 아직 상대방 iPhone과 페어링되어 있습니다. 지우면 해당 정보가 삭제됩니다.",
    "Download SideInstaller": "SideInstaller 다운로드",
    "Couldn't download the latest SideInstaller release: %@": "최신 SideInstaller 릴리즈를 다운로드하지 못했습니다: %@",
    "The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute.":
        "다운로드한 릴리즈가 IPA가 아닙니다. GitHub이 오류 페이지를 돌려줬을 수 있으니 잠시 후 다시 시도하세요.",
    "No SideInstaller IPA downloaded.": "다운로드한 SideInstaller IPA가 없습니다.",
    "Start the install": "설치 시작",
    "Install on their iPhone": "상대방 iPhone에 설치",
    "Install again": "다시 설치",
    "%d%% downloaded": "%d%% 다운로드됨",
    "%d%% uploaded": "%d%% 업로드됨",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple이 상대방 iPhone을 이 Apple ID의 개발자 팀에 등록해 주지 않아서 프로비저닝 프로파일을 발급하지 않습니다. %@",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise.":
        "이 Apple ID로는 서명 인증서를 발급받을 수 없습니다. Apple이 이미 인증서가 있다고 응답했습니다(오류 7460). 먼저 인증서 하나를 폐기해야 합니다. 설정 › 계정에 저장된 Apple ID라면 인증서 도구에서, 그렇지 않다면 해당 Apple ID로 developer.apple.com에 로그인해 폐기하세요.",
    "Last step: they trust %@": "마지막 단계: 상대방이 %@ 신뢰하기",
    "Waiting for them to tap Trust…": "상대방이 신뢰를 탭하기를 기다리는 중…",
    "Waiting for them to pair in Settings…":
        "상대방이 설정에서 페어링하기를 기다리는 중…",
    "Waiting for them to enter the code…":
        "상대방이 코드를 입력하기를 기다리는 중…",
    "Pair their iPhone in Settings":
        "설정에서 상대방 iPhone 페어링",
    "Their iPhone won't ask by itself — pairing starts from its Settings.":
        "상대방 iPhone은 스스로 요청하지 않습니다. 페어링은 그 iPhone의 설정에서 시작됩니다.",
    "On their iPhone, open Settings › Privacy & Security › Developer Mode.":
        "상대방 iPhone에서 설정 › 개인정보 보호 및 보안 › 개발자 모드를 여세요.",
    "Tap “Pair with %@”.":
        "“%@ 페어링”을 탭하세요.",
    "Enter their iPhone’s passcode if it asks for it.":
        "암호를 요청하면 상대방이 직접 입력하게 하세요.",
    "Type the code that appears here into the prompt on their iPhone.":
        "여기에 나타나는 코드를 상대방 iPhone의 입력창에 입력하세요.",
    "Type this into the prompt on their iPhone.":
        "이 코드를 상대방 iPhone의 입력창에 입력하세요.",
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "상대방이 iPhone에서 “신뢰 안 함”을 탭했습니다. 처음부터 다시 시작하고, 신뢰를 탭하도록 해 주세요.",
    "SideInstaller is already waiting for an iPhone to pair with it — from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "SideInstaller가 이미 페어링할 iPhone을 기다리고 있습니다. 설치 탭, 페어링 화면 또는 이전 시도에서 시작된 것입니다. 그 페어링을 마치거나 SideInstaller를 닫았다가 다시 연 뒤 시도하세요.",
    "Pairing with their iPhone didn't finish: %@":
        "상대방 iPhone과의 페어링이 끝나지 않았습니다: %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "%@에 있는 상대방 iPhone이 연결을 거부했습니다. 개발자 모드가 켜져 있을 때만 연결을 받으며, iOS는 재시동할 때마다 개발자 모드를 다시 확인하라고 요청합니다. 상대방 iPhone에서 설정 › 개인정보 보호 및 보안 › 개발자 모드를 켠 뒤 다시 시도하세요.",
    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "%@에 있는 상대방 iPhone에 연결할 수 없습니다. 주소(상대방 iPhone의 설정 › Wi-Fi › ⓘ)가 맞는지, 두 iPhone이 같은 Wi-Fi 네트워크에 있는지, 이 iPhone의 설정에서 SideInstaller의 로컬 네트워크가 켜져 있는지 확인하세요. 게스트 네트워크나 공용 네트워크는 기기끼리 연결되지 않는 경우가 많습니다.",
    "The link to their iPhone didn't come up: %@":
        "상대방 iPhone과의 연결이 만들어지지 않았습니다: %@",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "상대방 iPhone에서: 설정 › 일반 › VPN 및 기기 관리.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "“개발자 앱” 아래의 Apple ID를 탭한 뒤 신뢰를 탭하세요.",
    "Open it from their Home Screen — they're set up.": "상대방의 홈 화면에서 앱을 열면 설정이 모두 끝납니다.",

    // MARK: - About

    "About": "정보",
    "Version %@ (%@)": "버전 %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller는 PC 없이 SideStore와 LiveContainer를 iPhone에 바로 설치해 줍니다.",

    "Links": "링크",
    "Source code": "소스 코드",
    "Support the project": "프로젝트 후원",
    "Crypto": "암호화폐",
    "Donation wallets for Bitcoin, Ethereum and Solana.":
        "Bitcoin, Ethereum, Solana 기부 지갑입니다.",
    "Crypto donations": "암호화폐 기부",
    "Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you.":
        "기부는 전적으로 자발적입니다. 기부한다고 기능이 추가로 열리거나 보상이 주어지지는 않으며, SideInstaller가 도움이 되었다면 고마움을 전하는 방법일 뿐입니다.",
    "Coin": "코인",
    "Network: %@": "네트워크: %@",
    "QR code for the %@ address": "%@ 주소의 QR 코드",
    "Copied": "복사됨",
    "Send each coin only on the network shown. Crypto sent on another network can't be recovered.":
        "각 코인은 표시된 네트워크로만 보내세요. 다른 네트워크로 보낸 암호화폐는 복구할 수 없습니다.",

    "Special thanks": "특별한 감사",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "SideInstaller가 iPhone과 통신하는 데 쓰는 라이브러리 idevice에 감사드립니다. 이게 없었다면 이 앱도 없었을 것입니다.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "응원해 주시고, 버그를 찾아내 고칠 수 있게 도와주셔서 감사합니다.",
    "For the Japanese translation.": "일본어 번역에 감사드립니다.",
    "For the Korean translation.": "한국어 번역에 감사드립니다.",

    "Built with": "사용된 오픈 소스",
    "The open source work this app is built on:": "이 앱의 기반이 된 오픈 소스 작업물입니다:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "페어링, 터널, 설치 자체를 담당합니다. jkcoxson 개발, MIT 라이선스.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Apple ID 로그인, 인증서, 기기에서의 서명을 담당합니다. nab138 개발, MIT 라이선스.",
    "The sideloading app this installs for you.":
        "SideInstaller가 대신 설치해 주는 사이드로딩 앱입니다.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "앱마다 앱 슬롯을 쓰지 않고 사이드로드한 앱을 실행합니다.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "위치 변경 도구가 마운트하는 개발자 디스크 이미지입니다. doronz88이 미러링했습니다.",

    "Where to get it": "받을 수 있는 곳",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "공식 설치 페이지와 저장소의 빌드만 제가 만든 것입니다. 누구나 소스를 포크해 자격 증명 탈취 코드를 넣고 같은 이름과 아이콘으로 배포할 수 있으니, 다른 곳의 사본에는 Apple ID를 맡기지 마세요.",
    "Install page": "설치 페이지",
    "Terms": "약관",

    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.": "%@ 앱은 iOS %d 이상이 필요합니다. 이 iPhone의 iOS 버전은 %@입니다.",
    "Open Madeira from your Home Screen.": "홈 화면에서 Madeira를 여세요.",
    "In its setup, under “Set up JIT”, pick “In-app with pairing file”: SideInstaller already put the file there, so tap “Continue”.":
        "설정 화면의 “Set up JIT”에서 “In-app with pairing file”을 선택하세요. SideInstaller가 이미 파일을 넣어 두었으니 “Continue”를 탭하면 됩니다.",
    "In its setup, under “Set up JIT”, pick how this iPhone gets JIT.":
        "설정 화면의 “Set up JIT”에서 이 iPhone이 JIT를 얻는 방법을 선택하세요.",
    "Madeira renews its own signing from now on, when it's open and LocalDevVPN is connected. SideInstaller gave it a sign-in for that: a token for Apple's developer service, not your password. Madeira can forget it under Settings › Signing.":
        "이제부터 Madeira는 앱이 열려 있고 LocalDevVPN이 연결되어 있을 때 스스로 서명을 갱신합니다. 이를 위해 SideInstaller가 로그인 정보를 전달했습니다. 암호가 아니라 Apple 개발자 서비스용 토큰입니다. Madeira의 설정 › Signing에서 삭제할 수 있습니다.",
    "Its signing lasts 7 days. Before they run out, refresh it here under Tools › Sideloaded apps.":
        "서명은 7일 동안 유지됩니다. 만료되기 전에 도구 › 사이드로드한 앱에서 갱신하세요.",
    "This pairing file has no RPPairing record, the only kind %@ reads.":
        "이 페어링 파일에는 %@이(가) 읽는 유일한 형식인 RPPairing 레코드가 없습니다.",
    "Runs Windows PC games on your iPhone. By Will Faust, GPL-3.0.":
        "Windows PC 게임을 iPhone에서 실행합니다. Will Faust 개발, GPL-3.0 라이선스.",

    // MARK: - App ID cost

    "App IDs for this app": "이 앱의 App ID",
    "Cost": "소모",
    "Left now": "현재 남음",
    "Left after": "설치 후 남음",
    "New App IDs": "새 App ID",
    "This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "이 Apple ID에 남은 App ID가 부족합니다. 이 앱에는 %d개가 필요한데 %d개가 남아 있습니다. 각 App ID는 7일 동안 개수에 포함되므로, 일부가 만료될 때까지 기다리거나 다른 Apple ID로 로그인하세요.",
    "The next one frees up on %@.": "다음 App ID는 %@에 사용 가능해집니다.",
    "Your Apple ID already has every App ID this app needs, so installing it uses none.":
        "이 Apple ID에는 이 앱에 필요한 App ID가 모두 이미 있으므로, 설치해도 추가로 소모되지 않습니다.",
    "Signing registers one App ID for the app, and its extensions share it. It counts for 7 days.":
        "서명하면 앱에 App ID가 하나 등록되며 앱의 확장 기능이 이를 함께 사용합니다. 이 App ID는 7일 동안 개수에 포함됩니다.",
    "This Apple ID can register %d a week.": "이 Apple ID는 일주일에 %d개를 등록할 수 있습니다.",

    // MARK: - Links (sideinstaller://install, sideinstaller://pairingFile)

    "Install from a link?": "링크에서 설치하시겠습니까?",
    "Download and install": "다운로드 및 설치",
    "SideInstaller will download this .ipa, then sign it with your Apple ID and install it. Only go ahead if you trust where the link came from.":
        "SideInstaller가 이 .ipa를 다운로드한 뒤 Apple ID로 서명하여 설치합니다. 링크의 출처를 신뢰하는 경우에만 진행하세요.",
    "It replaces %@, the custom .ipa you have now.": "현재 사용 중인 사용자 지정 .ipa인 %@ 파일을 대체합니다.",
    "Use SideStore's pairing file?": "SideStore의 페어링 파일을 사용하시겠습니까?",
    "Import this pairing file?": "이 페어링 파일을 가져오시겠습니까?",
    "Import": "가져오기",
    "SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.":
        "SideStore가 보유한 페어링 파일을 돌려보냈습니다. SideInstaller가 이 파일로 이 iPhone에 연결합니다.",
    "A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.":
        "링크를 통해 SideInstaller에 페어링 파일이 전달되었습니다. 직접 요청한 경우에만 가져오세요. SideInstaller가 이 파일로 이 iPhone에 연결합니다.",
    "It replaces %@.": "%@ 파일을 대체합니다.",
    "It replaces the pairing file in use now.": "현재 사용 중인 페어링 파일을 대체합니다.",
    "Get it from SideStore": "SideStore에서 가져오기",
    "SideStore opens and sends back the pairing file it has.": "SideStore가 열리고 보유한 페어링 파일을 돌려보냅니다.",
    "SideStore isn't installed on this iPhone, so there's no pairing file to get from it.":
        "이 iPhone에 SideStore가 설치되어 있지 않아서 가져올 페어링 파일이 없습니다.",
    "That install link has no .ipa in it. It needs ?url= followed by the https:// address the .ipa downloads from.":
        "이 설치 링크에는 .ipa가 없습니다. ?url= 뒤에 .ipa를 내려받을 https:// 주소가 있어야 합니다.",
    "That link was meant to carry a pairing file, but what it holds can't be read.":
        "이 링크는 페어링 파일을 전달하려는 것이었지만, 담긴 내용을 읽을 수 없습니다.",
    "That link carries a file, but it isn't a pairing file.": "이 링크에는 파일이 있지만 페어링 파일이 아닙니다.",

    // MARK: - Report a problem

    "Report a problem": "문제 신고",
    "Report this problem": "이 문제 신고",
    "Opens a GitHub issue with this app's details, its log and crash logs.":
        "이 앱의 정보, 로그, 충돌 로그가 담긴 GitHub 이슈를 엽니다.",
    "What happened?": "어떤 일이 있었습니까?",
    "What were you doing, and what went wrong?": "무엇을 하고 있었고, 어떤 문제가 생겼습니까?",
    "Say what you tapped, what you expected and what happened instead. English is best, but any language is fine.":
        "무엇을 탭했는지, 무엇을 기대했는지, 실제로 어떤 일이 일어났는지 적어 주세요. 영어가 가장 좋지만 어떤 언어든 괜찮습니다.",
    "Included": "포함된 정보",
    "Device": "기기",
    "App": "앱",
    "Stopped at": "중단된 단계",
    "not connected": "연결되지 않음",
    "none": "없음",
    "made on this iPhone": "이 iPhone에서 생성",
    "Runs inside LiveContainer": "LiveContainer 안에서 실행",
    "on": "켬",
    "off": "끔",
    "unknown": "알 수 없음",
    "yes": "예",
    "no": "아니요",
    "latest": "최신",
    "custom server": "사용자 지정 서버",
    "Auto, starts with %@": "자동, %@부터 시작",
    "Error": "오류",
    "Activity log": "활동 로그",
    "%d lines": "%d줄",
    "Your Apple ID, device name, serial numbers and keys are taken out of the log first.":
        "Apple ID, 기기 이름, 일련번호, 키는 로그에서 먼저 제거됩니다.",
    "Crash logs": "충돌 로그",
    "Looking for crash logs …": "충돌 로그를 찾는 중 …",
    "Look for crash logs on this iPhone": "이 iPhone에서 충돌 로그 찾기",
    "Look again": "다시 찾기",
    "No crash logs from SideStore, LiveContainer or Madeira in the last %d days.":
        "최근 %d일 동안 SideStore, LiveContainer, Madeira의 충돌 로그가 없습니다.",
    "iOS hands SideInstaller its own crashes the next time it opens. Crash logs from SideStore, LiveContainer and Madeira are read from this iPhone through LocalDevVPN.":
        "SideInstaller 자체의 충돌 정보는 iOS가 다음에 앱을 열 때 전달해 줍니다. SideStore, LiveContainer, Madeira의 충돌 로그는 LocalDevVPN을 통해 이 iPhone에서 읽어 옵니다.",
    "Open a GitHub issue": "GitHub 이슈 열기",
    "Share the report": "보고서 공유",
    "Preview the report": "보고서 미리 보기",
    "Report": "보고서",
    "The issue opens filled in. When the log is too long for that, SideInstaller copies it for you to paste at the end of the issue. The whole report is also saved in %@.":
        "이슈는 내용이 채워진 채로 열립니다. 로그가 너무 길어 채울 수 없으면 SideInstaller가 로그를 복사해 두니 이슈 끝에 붙여 넣으세요. 전체 보고서는 %@에도 저장됩니다.",
    "Files › On My iPhone": "파일 › 나의 iPhone",
    "Copy the full log": "전체 로그 복사",
    "Paste the log into the issue": "로그를 이슈에 붙여 넣으세요",
    "Open GitHub": "GitHub 열기",
    "The full log is too long to fill in, so SideInstaller copied it. On GitHub, tap the end of the text, choose Paste, then submit the issue.":
        "전체 로그가 너무 길어 자동으로 채울 수 없어서 SideInstaller가 복사해 두었습니다. GitHub에서 텍스트 끝을 탭하고 붙여넣기를 선택한 뒤 이슈를 제출하세요.",
    "Describe the problem above first.": "먼저 위에 문제를 설명해 주세요.",
    "Couldn't save the report: %@": "보고서를 저장하지 못했습니다: %@",

    // MARK: - Official download check

    "Did you download SideInstaller from sideinstaller.net?":
        "sideinstaller.net에서 SideInstaller를 받으셨습니까?",
    "SideInstaller is open source, so anyone can publish a modified copy that steals the Apple ID typed into it. Only sideinstaller.net is official.":
        "SideInstaller는 오픈 소스이므로 누구나 입력한 Apple ID를 훔치도록 수정한 복사본을 배포할 수 있습니다. 공식 사이트는 sideinstaller.net뿐입니다.",
    "Yes, from sideinstaller.net":
        "예, sideinstaller.net에서 받았습니다",
    "No, or I'm not sure":
        "아니요, 또는 잘 모르겠습니다",
    "Don't sign in with this copy":
        "이 복사본으로 로그인하지 마세요",
    "Copies from anywhere other than sideinstaller.net are unofficial and may have been changed to steal your Apple ID. Delete this one and install SideInstaller from sideinstaller.net, then sign in there.":
        "sideinstaller.net이 아닌 곳에서 받은 복사본은 비공식이며 Apple ID를 훔치도록 변경되었을 수 있습니다. 이 앱을 삭제하고 sideinstaller.net에서 SideInstaller를 설치한 뒤 그곳에서 로그인하세요.",
    "Open sideinstaller.net":
        "sideinstaller.net 열기",
    "Back":
        "뒤로",
    "I understand the risks":
        "위험을 이해했습니다",
    "Use an unofficial copy?":
        "비공식 복사본을 사용하시겠습니까?",
    "If this copy was changed, it can send your Apple ID and password to someone else. Continue only if you trust where it came from.":
        "이 복사본이 변경되었다면 Apple ID와 암호를 다른 사람에게 보낼 수 있습니다. 출처를 신뢰하는 경우에만 계속하세요.",
]
