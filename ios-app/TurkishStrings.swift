import Foundation

/// Turkish translations, keyed by the English string passed to `L(_:)`. Missing
/// keys fall back to English. Keep `%@`/`%d` placeholders, and leave product and
/// third-party UI names in English.

let turkishStrings: [String: String] = [

    // MARK: - Shared

    "Expiry date": "Bitiş tarihi",
    "Signed date": "İmza tarihi",
    "Bundle ID": "Bundle ID",
    "Not enough free space on this iPhone to download this IPA — it needs %@, but only %@ is free. Free some space and try again.":
        "Bu iPhone'da bu IPA'yı indirmek için yeterli boş alan yok: %@ gerekiyor ama yalnızca %@ boş. Yer açıp yeniden deneyin.",
    "Free space: %@": "Boş alan: %@",
    "Apple ID":
        "Apple ID",
    "Cancel": "İptal",
    "Copy": "Kopyala",
    "Copy logs": "Günlükleri kopyala",
    "Email": "E-posta",
    "No unsigned IPA in the library.":
        "Kitaplıkta imzalanmamış IPA yok.",
    "Once the install starts, tap the Install button at the bottom to see progress.":
        "Yükleme başladıktan sonra ilerlemeyi görmek için alttaki Yükle düğmesine dokunun.",
    "Password": "Parola",
    "Install": "Yükle",
    // U-UI (0.9.102): new tab bar / source + file list redesign.
    "Apps": "Uygulamalar",
    "Pick an IPA to install with your Apple ID.":
        "Apple ID ile yüklemek için bir IPA seçin.",
    "Signing method":
        "İmzalama yöntemi",
    "Sources": "Kaynaklar",
    "AppStore": "AppStore",
    "企业证书":
        "Kurumsal sertifika",
    "用 Apple ID 安装":
        "Apple ID ile yükle",
    "软件源": "Yazılım kaynakları",
    "文件列表": "Dosya listesi",
    "筛选": "Filtrele",
    "正在刷新数据中…": "Veriler yenileniyor…",
    "最后更新：%@": "Son güncelleme: %@",
    "应用文件夹库": "Uygulama klasörü arşivi",
    "应用 - %@": "Uygulama - %@",
    "No downloaded IPAs. Ones you install from a source or a file are cached here.": "İndirilmiş IPA yok. Kaynak veya dosyadan yüklenenler burada önbelleğe alınır.",
    "%d 个 IPA · %@": "%d IPA · %@",
    "清空全部": "Tümünü sil",
    "清空全部 %d 个下载？": "%d indirme tamamen silinsin mi?",
    "还没有文件。点上面「导入文件」放 IPA 进来，或在源页面下载后这里会出现。": "Henüz dosya yok. IPA eklemek için yukarıdaki «Dosya içe aktar»a dokunun veya kaynak sayfasından indirin.",
    "文件库里还没有没签过的 IPA。去文件页导入一个，或者去设置里的企业证书页点「从文件导入」。": "Arşivde henüz imzalanmamış IPA yok. Dosya sayfasından içe aktarın veya Ayarlar'daki kurumsal sertifika sayfasında «Dosyadan içe aktar»a dokunun.",
    "先去设置里的企业证书页，把证书、描述文件和密码备齐。": "Önce Ayarlar'daki kurumsal sertifika sayfasında sertifika, profil ve parolayı hazırlayın.",
    "还没有已签名的 IPA。用设置里企业证书页的「仅签名」签好就会存到这里，随时能装、能分享。": "Henüz imzalanmış IPA yok. Ayarlar'daki kurumsal sertifika sayfasında «Yalnızca imzala» ile imzalayın; burada saklanır, istediğiniz zaman yükleyip paylaşabilirsiniz.",
    "Installing": "Yükleniyor",
    "Installed": "Yüklendi",
    "Install history": "Yükleme geçmişi",
    "No installs yet.": "Henüz yükleme yok.",
    "Something went wrong": "Bir şeyler ters gitti",
    "an app by Frizzle": "Frizzle tarafından bir uygulama",
    "device": "cihaz",

    // MARK: - Welcome

    "I have accepted the": "Kabul ettim:",
    "Start": "Başla",
    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "Bir eşleme dosyasına ihtiyacın olacak",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "Bu iPhone iOS %@ çalıştırıyor. Yalnızca iOS %@ kendi kendine eşlenebilir, bu yüzden bilgisayarda — jitterbugpair veya pymobiledevice3 ile — bir eşleme dosyası oluşturup uygulamaya içe aktarman gerekir. SideInstaller adım adım gösterir.",

    // iOS 27 runs on this iPhone: recommended at setup

    "Update to iOS %@": "iOS %@ sürümüne güncelle",
    "This iPhone can run iOS %@, where SideInstaller works without a computer: the iPhone pairs with itself, so there's no pairing file to make. Update in Settings › General › Software Update.":
        "Bu iPhone iOS %@ çalıştırabilir; bu sürümde SideInstaller bilgisayarsız çalışır: iPhone kendi kendine eşlenir, böylece eşleme dosyası oluşturman gerekmez. Ayarlar › Genel › Yazılım Güncelleme'den güncelle.",
    "OK": "Tamam",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "Apple kimliğinle oturum aç",
    "Don't worry, these are stored locally": "Merak etme, bunlar yalnızca bu cihazda saklanır",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "Bu iPhone'un anahtar zincirinde saklanır ve yalnızca oturum açılırken Apple'a gönderilir.",
    "Continue": "Devam et",
    "Set this up later": "Bunu daha sonra ayarla",
    "Add Apple ID": "Apple kimliği ekle",
    "Edit Apple ID": "Apple kimliğini düzenle",
    "Save": "Kaydet",
    "Enter the password again to save this Apple ID.": "Bu Apple kimliğini kaydetmek için parolayı yeniden gir.",
    "Account": "Hesap",
    "In use": "Kullanımda",
    "Edit": "Düzenle",
    "Remove": "Kaldır",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "Henüz kayıtlı Apple kimliği yok. Bir tane ekle; SideInstaller her oturum açışında onu kullanır.",
    "Remove this Apple ID?": "Bu Apple kimliği kaldırılsın mı?",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "“%@” ve kayıtlı parolası bu iPhone'dan silinecek. Apple hesabında bir şey değişmez.",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "Bu iPhone'un anahtar zinciri parolayı saklamayı reddetti (hata %d), bu yüzden yalnızca SideInstaller kapanana kadar tutulur.",
    "No Apple ID saved. Add one in Settings › Account.":
        "Kayıtlı Apple kimliği yok. Ayarlar › Hesap bölümünden bir tane ekle.",
    "Add your Apple ID": "Apple kimliğini ekle",
    "Open Settings with the gear at the top right.": "Sağ üstteki dişli ile Ayarlar'ı aç.",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "Hesap altında “Apple kimliği ekle”ye dokun ve e-posta ile parolanı gir.",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "Araçlar",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "Eşleme",
    "Certificates": "Sertifikalar",
    "Two-Factor Code": "İki adımlı doğrulama kodu",
    "6-digit code": "6 haneli kod",
    "Enter the code Apple just sent to your trusted device.": "Apple'ın az önce güvenilir cihazına gönderdiği kodu gir.",
    "Enter the code Apple texted to %@.": "Apple'ın %@ numarasına gönderdiği kodu gir.",
    "Enter the code Apple texted to your phone.": "Apple'ın telefonuna mesajla gönderdiği kodu gir.",
    "Apple is calling %@. Enter the code you hear.": "Apple %@ numarasını arıyor. Duyduğun kodu gir.",
    "Apple is calling your phone. Enter the code you hear.": "Apple telefonunu arıyor. Duyduğun kodu gir.",
    "Choose how Apple should send your verification code.": "Apple'ın doğrulama kodunu nasıl göndereceğini seç.",
    "Choose How to Get a Code": "Kodu nasıl alacağını seç",
    "Verify": "Doğrula",
    "Didn't get it?": "Gelmedi mi?",
    "Send a new code to my devices": "Cihazlarıma yeni kod gönder",
    "Text me a new code": "Bana yeni kod kısa mesajla gönder",
    "Call me again": "Beni yeniden ara",
    "Send a code to my Apple devices": "Apple cihazlarıma kod gönder",
    "Text %@": "%@ numarasına mesaj gönder",
    "Call %@": "%@ numarasını ara",
    "Checking the code…": "Kod kontrol ediliyor…",
    "Requesting a new code…": "Yeni kod isteniyor…",
    "Sending a code to your devices…": "Cihazlarına kod gönderiliyor…",
    "Texting a code to %@…": "%@ numarasına kod mesajı gönderiliyor…",
    "Calling %@…": "%@ aranıyor…",

    // MARK: - Install tab

    "Tunnel connected": "Tünel bağlı",
    "Tunnel off": "Tünel kapalı",
    "Update available": "Güncelleme mevcut",
    "SideInstaller %@ is available — you're on %@.": "SideInstaller %@ mevcut — sen %@ sürümündesin.",
    "Get the latest version": "En son sürümü al",
    "Release": "Sürüm",
    "Reinstall": "Yeniden yükle",
    "Install %@": "%@ yükle",
    "Custom .ipa": "Özel .ipa",
    "Import .ipa": ".ipa içe aktar",
    "Importing…": "İçe aktarılıyor…",
    "Replace": "Değiştir",
    "or": "veya",
    "Paste a download link": "Bir indirme bağlantısı yapıştır",
    "SideInstaller recognizes this as %@ and sets it up just like its own download.":
        "SideInstaller bunu %@ olarak tanır ve kendi indirmesi gibi kurar.",
    "Downloading… %d%%": "İndiriliyor… %%%d",
    "Downloading": "İndiriliyor",
    "Queued": "Sırada",
    "iOS %@ required": "iOS %@ gerekli",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Bu iPhone iOS %@ çalıştırıyor; SideInstaller buna yükleme yapamaz. Ayarlar › Genel › Yazılım Güncelleme'den iOS %@ veya sonrasına güncelle.",
    "Wi-Fi required": "Wi-Fi gerekli",
    "Pairing code": "Eşleme kodu",
    "Type this into the prompt in Settings.": "Bunu Ayarlar'daki istem alanına yaz.",
    "Install stopped": "Yükleme durdu",
    "Close": "Kapat",
    "Yes": "Evet",
    "No": "Hayır",
    "Closing this popup will end the process. Are you sure?": "Bu pencereyi kapatmak işlemi sonlandırır. Emin misin?",
    "Cancel the install?": "Yükleme iptal edilsin mi?",
    "%@ is installed. Finish the trust step above to open it.": "%@ yüklendi. Açmak için yukarıdaki güven adımını tamamla.",
    "%@ is installed. Finish the trust step below to open it.": "%@ yüklendi. Açmak için aşağıdaki güven adımını tamamla.",
    "Success: last steps": "Başarılı: son adımlar",
    "Action needed": "İşlem gerekli",
    "Step %@ of %@": "Adım %@ / %@",
    "Show all steps": "Tüm adımları göster",
    "Show fewer steps": "Daha az adım göster",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "LocalDevVPN gerekli",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "LocalDevVPN'i yükle ve bağla. Yükleme onun tüneli üzerinden çalışır.",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Taramak ve yüklemek için LocalDevVPN'e bağlan. Yazma işlemi onun tüneli üzerinden yapılır.",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "LocalDevVPN'e bağlan. Konum taklidi de buradaki her şey gibi onun tüneli üzerinden çalışır.",
    "LocalDevVPN isn't connected. Connect it, then try again.": "LocalDevVPN bağlı değil. Bağlan, sonra yeniden dene.",
    "No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.": "Döngü VPN’i bağlı değil ve tünelin otomatik başlatılması kapalı. Ayarlar’dan “Gerektiğinde LocalDevVPN’i başlat” seçeneğini açıp Yükle’ye yeniden dokunun.",
    "Connect LocalDevVPN": "LocalDevVPN'e bağlan",
    "Install LocalDevVPN from the App Store and open it.": "LocalDevVPN'i App Store'dan yükle ve aç.",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Bulunduğun yerde GitHub engelleniyorsa, trafiği de vekilleyebilen bir VPN kullan: iOS aynı anda tek VPN çalıştırır; yalnızca yerel bir tünel SideStore indirmeye yetmez.",

    // MARK: - Install steps

    "Connect the VPN": "VPN'e bağlan",
    "Get pairing file": "Eşleme dosyasını al",
    "Open the device link": "Cihaz bağlantısını aç",
    "Sign in to Apple ID": "Apple kimliği ile oturum aç",
    "Download %@": "%@ indir",
    "Use your imported IPA": "İçe aktardığın IPA'yı kullan",
    "Use a custom .ipa instead": "Bunun yerine özel bir .ipa kullan",
    "Pick an .ipa to install.": "Yüklenecek .ipa dosyasını seç.",
    "Signed with the Apple ID and installed as it is, without a pairing file.": "Apple kimliğiyle imzalanır ve eşleme dosyası olmadan olduğu gibi yüklenir.",
    "Open %@.": "%@ uygulamasını aç.",
    "Sign the app": "Uygulamayı imzala",
    "Finish setup": "Kurulumu bitir",

    // MARK: - Pairing tab

    "Pairing file ready": "Eşleme dosyası hazır",
    "No pairing file": "Eşleme dosyası yok",
    "Pairing file": "Eşleme dosyası",
    "Pairing file is being generated. Wait for it to finish, then try again.": "Eşleştirme dosyası oluşturuluyor. Tamamlanmasını bekleyip yeniden deneyin.",
    "Pairing…": "Eşleniyor…",
    "Regenerate": "Yeniden oluştur",
    "Generate pairing file": "Eşleme dosyası oluştur",
    "Export pairing file": "Eşleme dosyasını dışa aktar",
    "Pair in Settings": "Ayarlar'da eşle",
    "Install into an app": "Bir uygulamaya yükle",
    "Scanning": "Taranıyor",
    "Rescan apps": "Uygulamaları yeniden tara",
    "Scan installed apps": "Yüklü uygulamaları tara",
    "%d supported app installed": "%d desteklenen uygulama yüklü",
    "%d supported apps installed": "%d desteklenen uygulama yüklü",
    "No supported apps found": "Desteklenen uygulama bulunamadı",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Önce SideStore, StikDebug veya Feather gibi bir uygulama yükle, sonra yeniden tara.",
    "Install pairing": "Eşlemeyi yükle",
    "Pairing file ready. You can export it or install it into an app below.":
        "Eşleme dosyası hazır. Aşağıdan dışa aktarabilir veya bir uygulamaya yükleyebilirsin.",
    "Pairing file installed into %@.": "Eşleme dosyası %@ içine yüklendi.",
    "Install pairing into all apps": "Eşlemeyi tüm uygulamalara yükle",
    "Installing into all apps": "Tüm uygulamalara yükleniyor",
    "Pairing file installed into all %d apps.": "Eşleme dosyası tüm %d uygulamaya yüklendi.",
    "Couldn't write into %@.": "%@ içine yazılamadı.",
    "The %@ record isn't a plist dictionary.": "%@ kaydı bir plist sözlüğü değil.",
    // Importing a pairing file (required below iOS 27, under Advanced from 27)

    "Import pairing file": "Eşleme dosyasını içe aktar",
    "How do I make one?": "Nasıl oluştururum?",
    "(Optional)": "(İsteğe bağlı)",
    "imported pairing file": "içe aktarılmış eşleme dosyası",
    "No pairing file yet — tap “Import pairing file” first.":
        "Henüz eşleme dosyası yok — önce “Eşleme dosyasını içe aktar”a dokun.",
    "Pairing file missing — import it first.": "Eşleme dosyası eksik — önce içe aktar.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ bir eşleme dosyası değil. Bilgisayarının oluşturduğu dosyayı seç — bu iPhone'un eşleme kaydını tutan .mobiledevicepairing veya .plist.",
    "%@ isn't installed on this iPhone, so there's nowhere to import the certificate.":
        "%@ bu iPhone'da yüklü değil, bu yüzden sertifika içe aktarılamıyor.",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "iOS %@ kendi eşleme dosyasını oluşturamaz — bunun için iOS %@ gerekir. “Eşleme dosyası” altında bilgisayarda yapılmış birini içe aktar, sonra yeniden dene.",

    // MARK: - Pairing service status

    "not paired": "eşlenmedi",
    "connected": "bağlı",
    "requesting Local Network…": "Yerel Ağ izni isteniyor…",
    "Local Network denied": "Yerel Ağ reddedildi",
    "waiting for device…": "cihaz bekleniyor…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "duyuruluyor — Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu'nu aç",
    "enter PIN %@ in Settings": "Ayarlar'da PIN %@ gir",
    "paired: %@ (%dB)": "eşlendi: %@ (%dB)",
    "failed: empty pairing file": "başarısız: boş eşleme dosyası",
    "failed: %@": "başarısız: %@",
    "Pairing is already in progress.": "Eşleme zaten sürüyor.",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "Yerel Ağ izni kapalı. Ayarlar › SideInstaller › Yerel Ağ'dan aç, sonra yeniden dene.",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "Eşleme boş bir dosya üretti. Eşleme isteğini onayladığından emin ol, sonra yeniden dene.",

    // MARK: - Certificates tab

    "Revoke this certificate?": "Bu sertifika iptal edilsin mi?",
    "Revoke": "İptal et",
    "Revoking": "İptal ediliyor",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "“%@” iptal edilecek. Bununla imzalanmış uygulamalar her cihazda açılmayı bırakır. Bu geri alınamaz.",
    "Apps signed with this certificate:\n%@": "Bu sertifikayla imzalanmış uygulamalar:\n%@",
    "Refreshing": "Yenileniyor",
    "Signing in": "Oturum açılıyor",
    "Refresh": "Yenile",
    "Load certificates": "Sertifikaları yükle",
    "%d certificate(s)": "%d sertifika",
    "No certificates": "Sertifika yok",
    "This Apple ID has no development certificates to revoke.":
        "Bu Apple kimliğinin iptal edilecek geliştirici sertifikası yok.",
    "Expired": "Süresi dolmuş",
    "Expires %@": "Bitiş %@",
    "Unnamed certificate": "Adsız sertifika",
    "This certificate has no serial number, so it can't be revoked.":
        "Bu sertifikanın seri numarası yok, bu yüzden iptal edilemez.",
    // Export: the certificate SideInstaller signs with, as a .p12

    "Import to %@": "%@'e aktar",
    "Exporting": "Dışa aktarılıyor",

    // MARK: - SideStore's certificate (sidestore://certificate)

    "Use SideStore's certificate": "SideStore'un sertifikasını kullan",
    "Checking the certificate": "Sertifika kontrol ediliyor",
    "SideStore opens and sends back its certificate. SideInstaller then signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "SideStore açılır ve sertifikasını geri gönderir. SideInstaller da onunla imzalar; böylece ücretsiz bir Apple kimliğinde iki uygulama birbirinin sertifikasını iptal etmek zorunda kalmaz.",
    "Apple won't issue a second signing certificate for this Apple ID. If SideStore made the one it has, SideInstaller can sign with that one too, and nothing is revoked. Revoking it lets the install continue as well — but it can't be undone.":
        "Apple bu Apple kimliği için ikinci bir imzalama sertifikası vermez. SideStore elindeki sertifikayı oluşturduysa SideInstaller de onunla imzalayabilir ve hiçbir şey iptal edilmez. İptal etmek yüklemenin sürmesini de sağlar — ama geri alınamaz.",
    "If SideStore made it, tap “Use SideStore's certificate” above: SideInstaller signs with that one too, and nothing is revoked.":
        "SideStore oluşturduysa yukarıda “SideStore'un sertifikasını kullan”a dokun: SideInstaller de onunla imzalar ve hiçbir şey iptal edilmez.",
    "SideInstaller signs with “%@” from now on. Nothing was revoked, so the apps already signed with it keep working.":
        "SideInstaller bundan sonra “%@” ile imzalıyor. Hiçbir şey iptal edilmedi, bu yüzden zaten bununla imzalanmış uygulamalar çalışmaya devam eder.",
    "SideInstaller already signs with “%@”.": "SideInstaller zaten “%@” ile imzalıyor.",
    "That certificate isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID (SideStore may be signed in with a different one). Nothing was changed.":
        "Bu sertifika bu Apple kimliğine ait değil: iptal edilmiş veya başka bir Apple kimliğine ait (SideStore farklı bir hesapla oturum açmış olabilir). Hiçbir şey değişmedi.",
    "Couldn't use that certificate: %@": "Bu sertifika kullanılamadı: %@",
    "SideStore isn't installed on this iPhone, so there's no certificate to get from it.":
        "Bu iPhone'da SideStore yüklü değil, bu yüzden ondan alınacak sertifika yok.",
    "Inside LiveContainer, SideStore can't send its certificate back to SideInstaller, and LiveContainer doesn't hold one yet. In LiveContainer's Settings, tap “Import Certificate From SideStore” (sign in to SideStore first if it has no certificate), then try again here.":
        "LiveContainer içinde SideStore sertifikasını SideInstaller'a geri gönderemez ve LiveContainer henüz bir tane tutmuyor. LiveContainer'ın Ayarlar sekmesinde “Sertifikayı SideStore'dan içe aktar”a dokun (sertifikası yoksa önce SideStore'da oturum aç), sonra burada yeniden dene.",
    "The certificate LiveContainer holds for SideStore isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID. Nothing was changed. If SideStore has made a new one since, tap “Refresh Certificate from SideStore” in LiveContainer's Settings, then try again here.":
        "LiveContainer'ın SideStore için tuttuğu sertifika bu Apple kimliğine ait değil: iptal edilmiş veya başka bir Apple kimliğine ait. Hiçbir şey değiştirilmedi. SideStore o zamandan beri yeni bir tane oluşturduysa LiveContainer'ın Ayarlar sekmesinde “Sertifikayı SideStore'dan yenile”ye dokun, sonra burada yeniden dene.",
    "SideInstaller takes SideStore's certificate from LiveContainer and signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "SideInstaller, SideStore'un sertifikasını LiveContainer'dan alır ve onunla da imzalar; böylece ücretsiz bir Apple kimliğinde iki uygulama birbirininkini iptal etmek zorunda kalmaz.",
    "Sign with this certificate?": "Bu sertifika ile imzalansın mı?",
    "A link sent SideInstaller a signing certificate. Only use it if you asked for one: SideInstaller will sign apps with it from now on, in place of its own. It's used only if it's one of your Apple ID's certificates.":
        "Bir bağlantı SideInstaller'a bir imzalama sertifikası gönderdi. Yalnızca sen istediysen kullan: SideInstaller bundan sonra kendi sertifikası yerine bununla uygulamaları imzalayacak. Yalnızca Apple kimliğinin sertifikalarından biri ise kullanılır.",
    "Use it": "Kullan",
    "That link was meant to carry a signing certificate, but what it holds can't be read.":
        "Bu bağlantı bir imzalama sertifikası taşıyacaktı, ancak içeriği okunamıyor.",

    // MARK: - Location tab

    "Location spoofing": "Konum taklidi",
    "Not simulating": "Simüle edilmiyor",
    "Simulated": "Simüle edildi",
    "Pick a place": "Bir yer seç",
    "Search for a place": "Yer ara",
    "Nothing found for “%@”.": "“%@” için bir şey bulunamadı.",
    "Set location": "Konumu ayarla",
    "Setting": "Ayarlanıyor",
    "Reset to real location": "Gerçek konuma sıfırla",
    "Location set to %@.": "Konum %@ olarak ayarlandı.",
    "Location reset. The device is using its own again.": "Konum sıfırlandı. Cihaz yine kendi konumunu kullanıyor.",
    "That isn't a valid coordinate.": "Bu geçerli bir koordinat değil.",
    "Location session closed — set it up again.": "Konum oturumu kapandı — yeniden ayarla.",
    "Downloading %@ failed (HTTP %d).": "%@ indirme başarısız (HTTP %d).",
    "The download of %@ came back empty. Try again.": "%@ indirmesi boş geldi. Yeniden deneyin.",
    "Couldn't build the download URL for %@.": "%@ için indirme adresi oluşturulamadı.",
    "Couldn't build the certificate link.": "Sertifika bağlantısı oluşturulamadı.",
    // Location › saved places and GPX routes.

    "Saved places": "Kayıtlı yerler",
    "Save this place": "Bu yeri kaydet",
    "Name": "Ad",
    "Show on map": "Haritada göster",
    "Tap Save under the map to keep the spot under the pin. Tapping a saved place sets it straight away.":
        "İğnenin altındaki yeri saklamak için haritanın altındaki Kaydet'e dokun. Kayıtlı bir yere dokunmak hemen uygular.",
    "Play a GPX route": "GPX rotası oynat",
    "Import a .gpx file and the device moves along it at the speed you pick, then stays at its last point.":
        ".gpx dosyası içe aktar; cihaz seçtiğin hızda rota boyunca hareket eder, sonra son noktada kalır.",
    "Import GPX file": "GPX dosyasını içe aktar",
    "Couldn't read %@ as a GPX file.": "%@ bir GPX dosyası olarak okunamadı.",
    "%@ has no track, route or waypoints in it.": "%@ içinde iz, rota veya yol noktası yok.",
    "As recorded": "Kayıtlı hızda",
    "Walk": "Yürüme",
    "Cycle": "Bisiklet",
    "Drive": "Araba",
    "Speed": "Hız",
    "Play route": "Rotayı oynat",
    "Playing route · %d%%": "Rota oynatılıyor · %%%d",
    "Stop here": "Burada dur",
    "%@ of %@": "%@ / %@",
    "Route finished. The device stays at its last point.": "Rota bitti. Cihaz son noktada kalır.",
    "Route stopped. The device stays where it got to.": "Rota durduruldu. Cihaz ulaştığı yerde kalır.",
    "Route playback stopped: %@": "Rota oynatma durdu: %@",
    // Location › planned routes (OpenStreetMap).

    "Add stop": "Durak ekle",
    "Add as stop": "Durak olarak ekle",
    "Plan a route": "Rota planla",
    "Travel by": "Ulaşım",
    "Goes along each street at its speed limit, from OpenStreetMap. A street without one mapped gets the usual limit for its kind of road.":
        "OpenStreetMap'ten her caddede hız sınırında ilerler. Haritalanmamış bir cadde, yol türünün olağan sınırını alır.",
    "Rides streets and paths a bike can take, at a cycling pace.":
        "Bisikletin gidebileceği cadde ve yollarda bisiklet temposunda ilerler.",
    "Walks streets and paths at a walking pace.": "Cadde ve yollarda yürüme temposunda ilerler.",
    "Start where the device is": "Cihazın olduğu yerden başla",
    "Move the map so the pin is on a place, then tap Add stop. Add as many as you like: the route goes to each in order.":
        "İğne bir yerin üstüne gelsin diye haritayı kaydır, sonra Durak ekle'ye dokun. İstediğin kadar ekle: rota sırayla her birine gider.",
    "The device's location": "Cihazın konumu",
    "Stop %d": "Durak %d",
    "Clear stops": "Durakları temizle",
    "Move up": "Yukarı taşı",
    "Move down": "Aşağı taşı",
    "Find route": "Rota bul",
    "Finding route": "Rota bulunuyor",
    "Add one more stop to plan a route.": "Rota planlamak için bir durak daha ekle.",
    "Routes from OpenStreetMap, © OpenStreetMap contributors":
        "Rotalar OpenStreetMap'ten, © OpenStreetMap katkıda bulunanlar",
    "Speed limits are mapped for all of it.": "Hız sınırlarının tümü haritalanmış.",
    "Speed limits are mapped for %d%% of it; the rest is estimated.":
        "Hız sınırlarının %%%d kadarı haritalanmış; geri kalanı tahmini.",
    "Average %@": "Ortalama %@",
    "Speed limit %@": "Hız sınırı %@",
    "No speed limit · going %@": "Hız sınırı yok · %@ ile gidiliyor",
    "No limit mapped · going %@": "Haritalanmış sınır yok · %@ ile gidiliyor",
    "Going %@": "%@ ile gidiliyor",
    "No street name": "Sokak adı yok",
    "Estimated speed limit %@": "Tahmini hız sınırı %@",
    "No speed limit": "Hız sınırı yok",
    "No route found between these stops. Move them onto roads or paths, or travel another way.":
        "Bu duraklar arasında rota bulunamadı. Onları yol veya patikaya taşı veya başka bir ulaşım seç.",
    "A stop is too far from any road or path. Move it closer and try again.":
        "Bir durak herhangi bir yol veya patikadan çok uzak. Daha yakına taşı ve yeniden dene.",
    "Too many stops for the route server. Take some out and try again.":
        "Rota sunucusu için çok fazla durak. Bazılarını çıkar ve yeniden dene.",
    "That route is too long for the route server. Make it shorter, or split it up.":
        "Bu rota rota sunucusu için çok uzun. Kısalt veya böl.",
    "The route server is busy. Try again in a minute.": "Rota sunucusu meşgul. Bir dakika sonra yeniden dene.",

    // MARK: - Entitlements tab

    "Entitlements": "Yetkiler",
    "Load apps": "Uygulamaları yükle",
    "%d App ID": "%d App ID",
    "%d App IDs": "%d App ID",
    "No App IDs": "App ID yok",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "Bu Apple kimliği henüz hiç uygulama kaydetmemiş. Önce SideInstaller ile bir şey yükle, sonra dön.",
    "Memory and performance": "Bellek ve performans",
    "Other free capabilities": "Diğer ücretsiz yetenekler",
    "Beta": "Beta",
    "Recommended": "Önerilen",
    "Select all": "Tümünü seç",
    "None": "Hiçbiri",
    "Enable %d selected": "Seçilenleri etkinleştir (%d)",
    "Asking Apple": "Apple'a soruluyor",
    "%d of %d enabled": "%d / %d etkin",
    "Install the app again for these to take effect.": "Bunların geçerli olması için uygulamayı yeniden yükle.",

    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "Yan yüklenen uygulamalar",
    "Reading the device": "Cihaz okunuyor",
    // Refresh all: signing the installed apps again.

    "iOS %@ isn't supported — SideInstaller needs iOS %@ or later.":
        "iOS %@ desteklenmiyor — SideInstaller iOS %@ veya sonrasını ister.",
    "An install is already running. Wait for it to finish, then refresh.":
        "Bir yükleme zaten sürüyor. Bitmesini bekle, sonra yenile.",
    "A refresh is already running. Wait for it to finish, then try again.":
        "Bir yenileme zaten çalışıyor. Bitmesini bekleyip yeniden deneyin.",
    "A signing is already running. Wait for it to finish, then try again.":
        "İmzalama zaten devam ediyor. Bitmesini bekleyip tekrar deneyin.",
    "Still reading the device. Try again in a moment.":
        "Cihaz hâlâ okunuyor. Birazdan yeniden deneyin.",
    "Load failed. Showing the last loaded list.":
        "Liste yüklenemedi. Son yüklenen liste gösteriliyor.",
    "Skipped: this app stopped being refreshable after the run started. Its IPA may have been deleted.":
        "Atlandı: bu uygulama çalıştırma başladıktan sonra yenilenemez hale geldi. IPA'si silinmiş olabilir.",
    "Skipped: this app has no team on its signing profile, so it can't be refreshed.":
        "Atlandı: bu uygulamanın imza profilinde ekip yok, bu yüzden yenilenemez.",
    "Revoked, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.":
        "İptal edildi, ancak sertifika listesi yenilenemedi. Yeniden yükleyene kadar güncel olmayabilir.",

    "Imported, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.":
        "İçe aktarıldı, ancak sertifika listesi yenilenemedi. Yeniden yükleyene kadar güncel olmayabilir.",
    "%@ is on their iPhone":
        "%@ onların iPhone'unda",
    "%@ is on their iPhone, but its pairing file couldn't be added (%@). Run Side by Side again, or import a pairing file in %@.":
        "%@ onların iPhone'unda ama eşleştirme dosyası eklenemedi (%@). Side by Side'ı yeniden çalıştır ya da %@ içinde bir eşleştirme dosyası içe aktar.",
    "Apple may send a code to their devices, so keep their iPhone close.":
        "Apple onların cihazlarına bir kod gönderebilir, o yüzden onların iPhone'unu yakınında tut.",
    "Change details":
        "Ayrıntıları değiştir",
    "Connect their iPhone to the same Wi-Fi network as this one.":
        "Onların iPhone'unu bu iPhone ile aynı Wi-Fi ağına bağla.",
    "Couldn't download %@: %@":
        "%@ indirilemedi: %@",
    "Couldn't find %@ in Downloads. Download it again first.": "İndirilenler'de %@ bulunamadı. Önce yeniden indirin.",
    "The IPA for %@ in Downloads is a different clone. Its bundle ID doesn't match this history entry. Download this clone's IPA first.": "İndirilenler'deki %@ IPA'sı farklı bir klon. Paket kimliği bu kayıtla eşleşmiyor. Önce bu klonun IPA'sını indirin.",
    "Do this on their iPhone, then start.":
        "Bunu onların iPhone'unda yap, sonra başlat.",
    "Finish on their iPhone":
        "Onların iPhone'unda bitir",
    "Get LocalDevVPN from the App Store and connect it: SideStore works through it.":
        "LocalDevVPN'i App Store'dan alıp bağlan: SideStore onun üzerinden çalışır.",
    "Get started":
        "Başla",
    "Get their iPhone ready":
        "Onların iPhone'unu hazırla",
    "Handing over the pairing file…":
        "Eşleştirme dosyası aktarılıyor…",
    "Install another app":
        "Başka bir uygulama yükle",
    "Installing %@ on their iPhone":
        "%@ onların iPhone'una yükleniyor",
    "Looking for their iPhone…":
        "Onların iPhone'u aranıyor…",
    "My Apple ID":
        "Apple kimliğim",
    "Needs LocalDevVPN on their iPhone":
        "Onların iPhone'unda LocalDevVPN gerekiyor",
    "Only if you'll keep their apps signed yourself: they won't have this Apple ID's password.":
        "Yalnızca onların uygulamalarını kendin imzalı tutacaksan seç: bu Apple kimliğinin parolası onlarda olmayacak.",
    "Open LiveContainer, go to its Settings tab, and tap “Import Certificate From SideStore”.":
        "LiveContainer'ı aç, Settings sekmesine git ve “Import Certificate From SideStore” öğesine dokun.",
    "Open SideStore and sign in with the same Apple ID. Its pairing file is already in place.":
        "SideStore'u aç ve aynı Apple kimliğiyle oturum aç. Eşleştirme dosyası zaten yerinde.",
    "Pick one. You can come back for another one later.":
        "Birini seç. Başka biri için daha sonra dönebilirsin.",
    "Recommended: they keep their apps signed with it.":
        "Önerilir: uygulamalarını bununla imzalı tutarlar.",
    "The app is signed with it, and needs it again every 7 days to keep opening. Use the iPhone owner's.":
        "Uygulama bununla imzalanıyor ve açılmaya devam etmesi için her 7 günde bir yine buna ihtiyaç duyuyor. iPhone sahibinin kimliğini kullan.",
    "Their Apple ID":
        "Onların Apple kimliği",
    "Their iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. They need to delete one, then you can try again.":
        "Onların iPhone'unda ücretsiz bir Apple kimliğiyle imzalanmış üç uygulama zaten var; süresi dolanlar da dahil iOS'un izin verdiği en fazla bu kadar. Birini silmeleri gerekiyor, sonra yeniden deneyebilirsin.",
    "This iPhone no longer keeps a pairing with theirs.":
        "Bu iPhone artık onların iPhone'uyla eşleştirmeyi tutmuyor.",
    "Turn on Developer Mode under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.":
        "Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu altından Geliştirici Modu'nu aç ve yeniden başlatmanın ardından onayla.",
    "Unlock their iPhone and keep it next to this one.":
        "Onların iPhone'unun kilidini aç ve bunu yanında tut.",
    "Used for this install only, and never saved.":
        "Yalnızca bu yükleme için kullanılır, asla kaydedilmez.",
    "Waiting for their iPhone…":
        "Onların iPhone'u bekleniyor…",
    "What should go on their iPhone?":
        "Onların iPhone'una ne yüklensin?",
    "Which Apple ID signs it?":
        "Hangi Apple kimliği imzalıyor?",
    "Skipped: refresh stopped.":
        "Atlandı: yenileme durduruldu.",
    "The pairing wasn't handed over in the newer format. SideStore may ask for the pairing file.":
        "Eşleştirme yeni biçimde aktarılamadı. SideStore ilk açılışta eşleştirme dosyasını isteyebilir.",
    "The signing certificate wasn't handed over. SideStore may ask to resign itself on first sign-in.":
        "İmzalama sertifikası aktarılamadı. SideStore ilk oturum açışta yeniden imzalamayı isteyebilir.",
    "Cellular Install (OTA)":
        "Mobil veriyle yükleme (OTA)",
    "Pairing Install":
        "Eşleştirme ile yükleme",
    "Upload these two files to R2, then install: %@ and %@. Upload via the WebDAV bridge https://r2-webdav.wozofa.workers.dev or the R2 console; .plist as text/xml, .ipa as application/octet-stream. After uploading, tap “Uploaded, Start Install”.":
        "Bu iki dosyayı R2’ye yükleyip sonra kurun: %@ ve %@. WebDAV köprüsü https://r2-webdav.wozofa.workers.dev veya R2 konsoluyla yükleyin; .plist text/xml, .ipa application/octet-stream olarak. Yükledikten sonra “Yüklendi, yüklemeyi başlat” düğmesine dokunun.",
    "Uploaded, Start Install":
        "Yüklendi, yüklemeyi başlat",
    "After installing, the first launch will say “Untrusted Enterprise Developer”: go to Settings → General → VPN & Device Management to trust the certificate, tap “Allow and Restart”, then open the app again.":
        "Kurulumdan sonra ilk açılışta “Güvenilmeyen Kurumsal Geliştirici” uyarısı çıkar: Ayarlar → Genel → VPN ve Aygıt Yönetimi’ne gidip sertifikaya güvenin, “İzin Ver ve Yeniden Başlat”a dokunun, ardından uygulamayı yeniden açın.",
    "Cellular install couldn't open the system installer: check the R2 links, or use pairing install instead.":
        "Mobil veriyle yükleme sistem yükleyicisini açamadı: R2 bağlantılarını kontrol edin veya eşleştirme ile yüklemeyi kullanın.",
    "SideStore's anisette settings weren't set. If its sign-in fails with -80046, turn off On-device Anisette and Auto Rotation and pick “SideStore (New)”.":
        "SideStore'un anisette ayarları uygulanamadı. Girişi -80046 hatasıyla başarısız olursa cihaz içi Anisette'i ve otomatik döndürmeyi kapatıp “SideStore (New)” öğesini seçin.",
    "Last refresh (its notification couldn't be delivered): %@":
        "Son yenileme (bildirim iletilemedi): %@",
    "Getting ready": "Hazırlanıyor",
    "Stopping after this app": "Bu uygulamadan sonra duruluyor",
    "Refreshing %@": "%@ yenileniyor",
    "Refreshed. Its seven days start again now.": "Yenilendi. Yedi günü şimdi yeniden başlar.",
    "Nothing was refreshed.": "Hiçbir şey yenilenmedi.",
    "Refreshed %d of %d apps.": "%d / %d uygulama yenilendi.",
    "Refresh all apps?": "Tüm uygulamalar yenilensin mi?",
    "Refresh all": "Tümünü yenile",
    "Renew this app": "Bu uygulamayı yenile",
    "%d app can be signed again from an IPA already on this iPhone.":
        "%d uygulama, bu iPhone'da zaten bulunan bir IPA'dan yeniden imzalanabilir.",
    "%d apps can be signed again from IPAs already on this iPhone.":
        "%d uygulama, bu iPhone'da zaten bulunan IPA'lardan yeniden imzalanabilir.",
    "Reload": "Yeniden yükle",
    "Waiting": "Bekliyor",
    "In progress": "Devam ediyor",
    "Failed": "Başarısız",
    "%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.":
        "Buradaki %d uygulamanın SideInstaller'da IPA'sı yok, bu yüzden bu sayfadan yenilenemez. Onu yükleyen uygulamada yenile veya önce .ipa dosyasını içe aktar.",
    "%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.":
        "Buradaki %d uygulamanın SideInstaller'da IPA'sı yok, bu yüzden bu sayfadan yenilenemez. Onları yükleyen uygulamada yenile veya önce .ipa dosyalarını içe aktar.",
    "%d app": "%d uygulama",
    "%d apps": "%d uygulama",
    "%d app needs refreshing": "%d uygulamanın yenilenmesi gerekiyor",
    "%d apps need refreshing": "%d uygulamanın yenilenmesi gerekiyor",
    "No sideloaded apps": "Yan yüklenen uygulama yok",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Bu cihazda hiçbir şey sağlama profiliyle yüklenmemiş. App Store uygulamalarının süresi dolmaz, bu yüzden burada listelenmezler.",
    "No apps were read. Tap Reload to read this iPhone again; pair it and turn on Developer Mode first if nothing shows.":
        "Hiç uygulama okunamadı. Bu iPhone'u yeniden okumak için Yeniden yükle'ye dokunun; hâlâ bir şey görünmüyorsa önce iPhone'u eşleştirin ve Geliştirici Modu'nu açın.",
    "No matching apps.": "Eşleşen uygulama yok.",
    "No matching profile": "Eşleşen profil yok",
    "Expires today": "Bugün doluyor",
    "Expires tomorrow": "Yarın doluyor",
    "Expires in %d days — %@": "%d gün içinde doluyor — %@",
    "Expired %@": "Süresi doldu %@",
    "Unused profiles": "Kullanılmayan profiller",
    "Issued to App IDs no installed app is running on.": "Yüklü hiçbir uygulamanın çalışmadığı App ID'lere verilmiş.",
    "Older profiles": "Eski profiller",
    "App ID": "App ID",
    "Version": "Sürüm",
    "Profile name": "Profil adı",
    "Team": "Ekip",
    "Team ID": "Ekip kimliği",
    "Issued": "Verildi",
    "Profile UUID": "Profil UUID'si",
    "Capabilities": "Yetenekler",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "Joker App ID — altındaki herhangi bir paket kimliğini kapsar ve uygulamaya özel yetenekler taşıyamaz.",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "Cihazda bu App ID için sağlama profili yok. Uygulama zaten açılmayı bırakmış olabilir — düzeltmek için yeniden yükle.",

    // MARK: - Side by Side tool

    // The tool's name is left in English everywhere, as SideStore's is.

    "Side by Side": "Side by Side",
    "Pair with their iPhone": "Diğer iPhone ile eşle",
    "Install on their iPhone": "Diğer iPhone'a yükle",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "Eşlenen iPhone bu iPhone'du. Bunun yerine diğer iPhone'un Ayarlar'ından eşle. Bu iPhone'a yüklemek için Yükle sekmesini kullan.",
    "Enter the Apple ID to sign with, and its password.": "İmzalamak için Apple kimliğini ve parolasını gir.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Wi-Fi kapalı. Bunun çalışması için her iki iPhone'un da aynı Wi-Fi ağında olması gerekir.",
    "The release download wasn't an IPA. GitHub may be returning an error page, so try again in a minute.":
        "İndirilen sürüm bir IPA değildi. GitHub bir hata sayfası döndürüyor olabilir, bir dakika sonra yeniden dene.",
    "Couldn't download the latest SideInstaller release: %@": "En son SideInstaller sürümü indirilemedi: %@",
    "No SideInstaller IPA downloaded.": "SideInstaller IPA indirilmedi.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first. Use the Certificates tool if this is the Apple ID saved in Settings › Account, or developer.apple.com signed in as it otherwise.":
        "Apple bu Apple kimliği için imzalama sertifikası vermiyor: zaten bir tane olduğunu bildiriyor (hata 7460). Önce birinin iptal edilmesi gerekir. Bu Ayarlar › Hesap'ta kayıtlı Apple kimliğiyse Sertifikalar aracıyla; değilse developer.apple.com'da o hesapla oturum açarak.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple diğer iPhone'u bu Apple kimliğinin geliştirici ekibine kaydetmedi, bu yüzden sağlama profili vermiyor. %@",
    "No pair record for their iPhone.": "Diğer iPhone için eşleme kaydı yok.",
    "The link to their iPhone dropped. Start again.": "Diğer iPhone ile bağlantı koptu. Yeniden başla.",
    "Set up someone else's iPhone": "Başkasının iPhone'unu kur",
    "Same Wi-Fi network": "Aynı Wi-Fi ağı",
    "Apple ID to sign with": "İmzalamak için Apple kimliği",
    "Waiting for them to pair in Settings…": "Diğer iPhone'un Ayarlar'da eşlenmesi bekleniyor…",
    "Waiting for them to enter the code…": "Diğer iPhone'da kodun girilmesi bekleniyor…",
    "Pair their iPhone in Settings": "Diğer iPhone'u Ayarlar'da eşle",
    "Their iPhone won't ask by itself. Pairing starts from its Settings.":
        "Diğer iPhone kendiliğinden sormaz. Eşleme onun Ayarlar'ından başlar.",
    "On their iPhone, open Settings › Privacy & Security › Developer Mode.":
        "Diğer iPhone'da Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu'nu aç.",
    "Tap “Pair with %@”.": "“%@ ile eşle”ye dokun.",
    "Enter their iPhone’s passcode if it asks for it.": "Sorarsa diğer iPhone'un parolasını gir.",
    "Type the code that appears here into the prompt on their iPhone.":
        "Burada görünen kodu diğer iPhone'daki istem alanına yaz.",
    "Type this into the prompt on their iPhone.": "Bunu diğer iPhone'daki istem alanına yaz.",
    "SideInstaller is already waiting for an iPhone to pair with it, from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "SideInstaller zaten bir iPhone'un eşlenmesini bekliyor: Yükle sekmesinden, Eşleme sayfasından veya buradaki önceki bir denemeden. O eşlemeyi bitir veya SideInstaller'ı kapatıp aç, sonra yeniden dene.",
    "Pairing with their iPhone didn't finish: %@": "Diğer iPhone ile eşleme tamamlanmadı: %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "%@ adresindeki diğer iPhone bağlantıyı reddetti. Yalnızca Geliştirici Modu açıkken bağlantı kabul eder ve iOS her yeniden başlatmadan sonra Geliştirici Modu'nu yeniden onaylatır: diğer iPhone'da Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu'ndan aç, sonra yeniden dene.",
    "Couldn't reach their iPhone at %@. Check that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Diğer iPhone'a %@ adresinden ulaşılamadı. İki iPhone'un aynı Wi-Fi ağında olduğunu ve bu iPhone'un Ayarlar'ında SideInstaller için Yerel Ağ'ın açık olduğunu kontrol et. Misafir ve genel ağlar cihazların birbirine ulaşmasını sıkça engeller.",
    "%d%% downloaded": "%%%d indirildi",
    "%@ downloaded": "%@ indirildi",
    "%d%% uploaded": "%%%d yüklendi",
    "Start the install": "Yüklemeyi başlat",
    "Clear their details": "Diğer iPhone'un bilgilerini temizle",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "Bu iPhone hâlâ diğer iPhone ile eşli. Temizlersen bu eşleme unutulur.",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "Diğer iPhone'da: Ayarlar › Genel › VPN ve Aygıt Yönetimi.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "“Geliştirici Uygulaması” altındaki Apple kimliğine dokun, sonra Güven'e dokun.",

    // MARK: - Settings

    "Settings": "Ayarlar",
    "Done": "Tamam",
    "Language": "Dil",
    "App language": "Uygulama dili",
    "Sounds": "Sesler",
    "Sound effects": "Ses efektleri",
    "Auto": "Otomatik",
    // The Tunnel section: starting LocalDevVPN from here.

    "Tunnel": "Tünel",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.":
        "%@:%d adresindeki bir şey bağlantıyı reddetti; tünel trafik taşıyor — cihaz yalnızca eşleme bağlantı noktasında dinlemiyor. Bu bağlantı noktası yalnızca Geliştirici Modu açıkken açılır ve iOS her yeniden başlatmadan sonra yeniden ister: Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu'ndan aç, sonra yeniden dene. Zaten açıksa “Eşleme dosyası” altında bu iPhone'u yeniden eşle.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port: Developer Mode is off. Turn it on under Settings › Privacy & Security › Developer Mode (the iPhone restarts), then try again.":
        "%@:%d adresindeki bir şey bağlantıyı reddetti; yani tünel trafik taşıyor, ama bu iPhone eşleme bağlantı noktasını dinlemiyor: Geliştirici Modu kapalı. Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu'ndan aç (iPhone yeniden başlar), sonra yeniden dene.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port, although Developer Mode is on. Pair this iPhone again under “Pairing file”, then try again. If it still fails, restart the iPhone.":
        "%@:%d adresindeki bir şey bağlantıyı reddetti; yani tünel trafik taşıyor, ama Geliştirici Modu açık olduğu hâlde bu iPhone eşleme bağlantı noktasını dinlemiyor. “Eşleme dosyası” altında bu iPhone'u yeniden eşle, sonra yeniden dene. Yine olmazsa iPhone'u yeniden başlat.",
    "Something at %@:%d took the connection but didn't answer as this iPhone's pairing port, and no other port answered as one either. Check that LocalDevVPN is the VPN that's on and that Developer Mode is on (Settings › Privacy & Security › Developer Mode), then try again. If it still fails, restart the iPhone.":
        "%@:%d adresindeki bir şey bağlantıyı kabul etti ama bu iPhone'un eşleme bağlantı noktası gibi yanıt vermedi, başka hiçbir bağlantı noktası da öyle yanıt vermedi. Açık olan VPN'in LocalDevVPN olduğunu ve Geliştirici Modu'nun açık olduğunu (Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu) denetle, sonra yeniden dene. Yine olmazsa iPhone'u yeniden başlat.",
    "Start LocalDevVPN when needed": "Gerektiğinde LocalDevVPN'i başlat",
    "Start LocalDevVPN now": "LocalDevVPN'i şimdi başlat",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "LocalDevVPN yüklü değil. App Store'dan al; bu senin için başlatabilir.",
    "When on, operations that need the tunnel try the built-in tunnel first and start LocalDevVPN when needed. When off, LocalDevVPN is never started automatically; the built-in tunnel still starts on demand, and the manual pill switch is unaffected.":
        "Açıkken, tünel gerektiren işlemler önce yerleşik tüneli dener ve gerektiğinde LocalDevVPN'i başlatır. Kapalıyken LocalDevVPN hiçbir zaman otomatik başlatılmaz; yerleşik tünel yine de gerektiğinde başlar ve manuel pill anahtarı etkilenmez.",
    "imported": "içe aktarıldı",
    "Downloaded %@": "İndirildi: %@",
    "Added %@": "Eklendi: %@",
    "Delete": "Sil",
    "Couldn't delete %@: %@": "%@ silinemedi: %@",
    "Server": "Sunucu",
    "Custom…": "Özel…",
    "Server URL": "Sunucu URL",
    "Anisette Server": "Anisette sunucusu",
    "Starts with %@": "%@ ile başlar",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "Yalnızca Ayarlar › Anisette sunucusu'nda seçilen sunucu denendi. Biri başarısız olunca SideInstaller'ın diğerlerini denemesi için orada Otomatik'i seç.",
    "Device IP": "Cihaz IP",
    "Advanced": "Gelişmiş",
    "Clear": "Temizle",
    "Clear install history?": "Kurulum geçmişi temizlensin mi?",
    "Activity Log (%d)": "Etkinlik günlüğü (%d)",
    "没有匹配的日志。": "Eşleşen günlük yok.",
    "Verbose logging": "Ayrıntılı günlük",
    "Adds the messages exchanged with iOS to the log, for tracking down a connection problem. Leave it off otherwise, as they quickly fill the log.":
        "Bir bağlantı sorununu bulmak için iOS ile alınıp verilen mesajları günlüğe ekler. Günlüğü hızla doldurdukları için diğer zamanlarda kapalı bırak.",
    // Settings › Developer Mode: AMFI requests over the device link.

    "Developer Mode": "Geliştirici Modu",
    "Developer disk image": "Geliştirici disk görüntüsü",
    "Downloaded": "İndirildi",
    "Not downloaded": "İndirilmedi",
    "Re-download": "Yeniden indir",
    "Show Developer Mode in Settings": "Ayarlar'da Geliştirici Modu'nu göster",
    "Turn on Developer Mode": "Geliştirici Modu'nu aç",
    "Asking this iPhone…": "Bu iPhone'a soruluyor…",
    "Turn on Developer Mode?": "Geliştirici Modu açılsın mı?",
    "Turn On and Restart": "Aç ve yeniden başlat",
    "This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode.":
        "Bu iPhone hemen yeniden başlar. Kilit açtıktan sonra görünen uyarıda Aç'a dokun. iOS bunu yalnızca iPhone'da parola yokken izin verir.",
    "Developer Mode is already on.": "Geliştirici Modu zaten açık.",
    "Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.":
        "Geliştirici Modu artık Ayarlar › Gizlilik ve Güvenlik'te, altlara doğru görünür. Oradan aç; bitirmek için iOS yeniden başlar.",
    "Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.":
        "Geliştirici Modu açılmaya ayarlandı ve bu iPhone şimdi yeniden başlıyor. Kilidi açınca Aç'a dokun.",
    "An install is already running. Wait for it to finish, then try again.":
        "Bir yükleme zaten sürüyor. Bitmesini bekle, sonra yeniden dene.",
    "An import is already running. Wait for it to finish, then try again.": "Zaten devam eden bir içe aktarma var. Bitmesini bekleyip yeniden deneyin.",
    "%@ will be signed again with the Apple ID that signed it and installed over the copy on this device. It keeps its data, and its seven days start over.": "%@, kendisini imzalayan Apple Kimliği ile yeniden imzalanıp bu cihazdaki kopyanın üzerine yüklenecek. Verileri korunur ve yedi günü sıfırdan başlar.",
    "%d apps will be signed again, each with the Apple ID that signed it, and installed over the copies on this device. They keep their data, and their seven days start over.": "%d uygulama, her biri kendisini imzalayan Apple Kimliği ile yeniden imzalanıp bu cihazdaki kopyaların üzerine yüklenecek. Verileri korunur ve yedi günü sıfırdan başlar.",
    "%d app here is signed under a team that matches no saved Apple ID, so it is left out. Switch to the Apple ID that signed it and sign in once, then reload, and it will join the list. Enterprise-signed apps stay excluded.": "Buradaki %d uygulama, kayıtlı hiçbir Apple Kimliğiyle eşleşmeyen bir ekiple imzalandığı için listeye alınmadı. Onu imzalayan Apple Kimliğine geçip bir kez giriş yapın, ardından yeniden yükleyin; listeye eklenecektir. Kurumsal imzalı uygulamalar hariç tutulmaya devam eder.",
    "%d apps here are signed under teams that match no saved Apple ID, so they are left out. Switch to the Apple ID that signed them and sign in once, then reload, and they will join the list. Enterprise-signed apps stay excluded.": "Buradaki %d uygulama, kayıtlı hiçbir Apple Kimliğiyle eşleşmeyen ekiplerle imzalandığı için listeye alınmadı. Onları imzalayan Apple Kimliğine geçip bir kez giriş yapın, ardından yeniden yükleyin; listeye ekleneceklerdir. Kurumsal imzalı uygulamalar hariç tutulmaya devam eder.",
    "These apps were signed under %d Apple IDs, so each group is signed with its own Apple ID.": "Bu uygulamalar %d Apple Kimliği ile imzalandı, bu yüzden her grup kendi Apple Kimliği ile imzalanır.",
    "Couldn't sign in as %@ (%@). Switch to that account and refresh again.": "%@ (%@) olarak giriş yapılamadı. O hesaba geçip yeniden deneyin.",
    "Skipped: no saved Apple ID matches this app's team (%@). Switch to that account and refresh again.": "Atlandı: bu uygulamanın ekibiyle (%@) eşleşen kayıtlı Apple Kimliği yok. O hesaba geçip yeniden deneyin.",
    "Skipped: signed in as %@, but this app's team is %@. Switch to that account and refresh again.": "Atlandı: %@ olarak giriş yapıldı, ancak bu uygulamanın ekibi %@. O hesaba geçip yeniden deneyin.",
    "Refreshing %@ as %@": "%@, %@ olarak yenileniyor",
    "Invalid device IP": "Cihaz IP'si geçersiz",
    "The address was invalid, reset to 10.7.0.1.": "Adres geçersizdi, 10.7.0.1 olarak sıfırlandı.",
    "Bundle Identifier": "Paket Tanımlayıcı",
    "rpath": "rpath",
    "iOS turns Developer Mode on from here only while this iPhone has no passcode. Tap “Show Developer Mode in Settings” and turn it on there instead.":
        "iOS, Geliştirici Modu'nu buradan yalnızca bu iPhone'da parola yokken açar. Bunun yerine “Ayarlar'da Geliştirici Modu'nu göster”e dokunup oradan aç.",
    "This iPhone didn't take the Developer Mode request: %@": "Bu iPhone Geliştirici Modu isteğini kabul etmedi: %@",

    // MARK: - Release channels & downloads

    "Stable": "Kararlı",
    "Nightly": "Gecelik",
    // Version picker (Advanced)

    "%@ version": "%@ sürümü",
    "Latest": "En son",
    "Latest (%@)": "En son (%@)",
    "Couldn't load the other versions: %@": "Diğer sürümler yüklenemedi: %@",
    "Try again": "Yeniden dene",
    "Retry failed items": "Başarısız öğeleri yeniden dene",
    "couldn't find the IPA in the %@ %@ release": "%@ %@ sürümünde IPA bulunamadı",
    "%@ has no %@ release right now": "%@ için şu anda %@ sürüm yok",
    "bad asset URL": "geçersiz varlık adresi",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub bu ağa hız sınırı uyguluyor — engellenmiş değil ve sınır kendiliğinden kalkar. %@ yeniden dene.",
    "GitHub isn't serving %@ right now — the repository has been taken down, moved or made private, so there's nothing to download. Nothing is wrong with this iPhone or its network.":
        "GitHub şu anda %@ deposunu sunmuyor — depo kaldırılmış, taşınmış veya gizli yapılmış, bu yüzden indirilecek bir şey yok. Bu iPhone'da veya ağında bir sorun yok.",
    "couldn't reach GitHub: %@": "GitHub'a ulaşılamadı: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "GitHub'ın yanıtı sürüm bilgisi değildi (%@) — bu ağdaki bir şey onu değiştirmiş olabilir.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "%@ olarak inen şey bir IPA değil — bu ağda bir sayfa döndü veya aktarım yarıda kaldı.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "bu bağlantı HTTP %d yanıtı verdi — doğrudan indirme değil ya da oturum açmayı gerektiriyor.",
    "GitHub has no build of %@'s %@ branch to download right now.":
        "GitHub'da şu an %@ dalının %@ derlemesi indirilecek durumda değil.",
    "couldn't download %@ through nightly.link, which passes on GitHub's builds: %@":
        "GitHub derlemelerini ileten nightly.link üzerinden %@ indirilemedi: %@",
    "the %@ build that arrived isn't the file GitHub recorded, so it isn't installed. Try again later.":
        "Gelen %@ derlemesi GitHub'ın kaydettiği dosya değil, bu yüzden yüklenmedi. Daha sonra yeniden dene.",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "İki adımlı doğrulama iptal edildi.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Yanlış Apple kimliği veya parola. Apple Hesabı e-posta ve parolanı kontrol et, sonra yeniden dene.",
    "Apple ID sign-in failed on %@. Error: %@": "%@ üzerinde Apple kimliği oturum açma başarısız. Hata: %@",
    "Apple ID sign-in failed on %@. Error via %@: %@":
        "%@ üzerinde Apple kimliği oturum açma başarısız. %@ üzerinden hata: %@",
    "Apple's sign-in server refused the request (HTTP 503). It isn't your password or the anisette server, so trying more servers won't help. Try again later, or update SideInstaller.":
        "Apple'ın oturum açma sunucusu isteği reddetti (HTTP 503). Parolan veya anisette sunucusu değil; daha fazla sunucu denemek yardımcı olmaz. Daha sonra yeniden dene veya SideInstaller'ı güncelle.",
    "“%@” makes its anisette data with Apple's Android library, and Apple now refuses to finish signing in through those servers (error -80046), after your password and code. In Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "“%@” anisette verisini Apple'ın Android kütüphanesiyle üretir ve Apple artık bu sunucular üzerinden oturum açmayı tamamlamayı reddediyor (hata -80046), parola ve kodundan sonra. Ayarlar › Anisette sunucusu'nda Otomatik veya “SideStore (New)” gibi bir Mac sunucusu seç.",
    "Apple refused to finish signing in (error -80046), even through a Mac anisette server, the kind it still accepted. Try again later, or check for a SideInstaller update.":
        "Apple oturum açmayı tamamlamayı reddetti (hata -80046), hâlâ kabul ettiği türden bir Mac anisette sunucusu üzerinden bile. Daha sonra yeniden dene veya SideInstaller güncellemesi kontrol et.",
    "Apple refused to finish signing in through “%@” (error -80046). It now only accepts sign-ins through anisette servers on its macOS library: in Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "Apple, “%@” üzerinden oturum açmayı tamamlamayı reddetti (hata -80046). Artık yalnızca macOS kütüphanesindeki anisette sunucuları üzerinden oturum açmayı kabul ediyor: Ayarlar › Anisette sunucusu'nda Otomatik veya “SideStore (New)” gibi bir Mac sunucusu seç.",
    "Apple won't send a code by text or call to this sign-in, so it was sent to your Apple devices.":
        "Apple bu oturum açma için kodu mesaj veya aramayla göndermiyor; bu yüzden Apple cihazlarına gönderildi.",
    "Apple didn't confirm sending a code to your Apple devices. If one arrived, enter it; if not, try another way.":
        "Apple, Apple cihazlarına kod gönderdiğini doğrulamadı. Biri geldiyse gir; gelmediyse başka bir yol dene.",
    "SideInstaller can't reach Apple's sign-in server (gsa.apple.com), though this iPhone has an internet connection. Something is blocking it: a firewall, a DNS filter or ad blocker, Screen Time content restrictions, or another VPN app. Turn it off or try another network, then try again.":
        "Bu iPhone internete bağlı olsa da SideInstaller Apple'ın oturum açma sunucusuna (gsa.apple.com) ulaşamıyor. Bir şey engelliyor: güvenlik duvarı, DNS filtresi veya reklam engelleyici, Ekran Süresi içerik kısıtlamaları veya başka bir VPN uygulaması. Kapat veya başka ağ dene, sonra yeniden dene.",
    "SideInstaller can't reach Apple: Cellular Data is turned off for it. Turn SideInstaller on in Settings › Cellular, or join a Wi-Fi network with internet access, then try again.":
        "SideInstaller Apple'a ulaşamıyor: Hücresel Veri kapalı. Ayarlar › Hücresel'de SideInstaller'ı aç veya interneti olan bir Wi-Fi ağına bağlan, sonra yeniden dene.",
    "SideInstaller can't reach Apple: iOS isn't letting it use Wi-Fi. In Settings › Apps › SideInstaller › Wireless Data, choose WLAN & Cellular Data, then try again.":
        "SideInstaller Apple'a ulaşamıyor: iOS Wi-Fi kullanmasına izin vermiyor. Ayarlar › Uygulamalar › SideInstaller › Kablosuz Veri'de WLAN ve Hücresel Veri'yi seç, sonra yeniden dene.",
    "SideInstaller can't reach Apple: a VPN set to carry all traffic is disconnected, so iOS is holding traffic back. Reconnect it, or turn off its kill switch or Connect On Demand, then try again.":
        "SideInstaller Apple'a ulaşamıyor: tüm trafiği taşıyan bir VPN bağlantısı kesik; iOS trafiği tutuyor. Yeniden bağlan veya kill switch / İstek Üzerine Bağlan'ı kapat, sonra yeniden dene.",
    "SideInstaller can't reach Apple: this iPhone has no internet connection. Connect to Wi-Fi or turn on cellular data, then try again.":
        "SideInstaller Apple'a ulaşamıyor: bu iPhone'un internet bağlantısı yok. Wi-Fi'ye bağlan veya hücresel veriyi aç, sonra yeniden dene.",
    "Apple is temporarily limiting sign-ins for this Apple ID or network (HTTP 429). Trying other servers won't help, and every attempt can extend the wait, so leave it a while before signing in again.":
        "Apple bu Apple kimliği veya ağ için oturum açmaları geçici olarak sınırlıyor (HTTP 429). Diğer sunucuları denemek yardımcı olmaz ve her deneme beklemeyi uzatabilir; yeniden oturum açmadan önce bir süre bekle.",
    "If you're sure the password is right, Apple may be limiting sign-in attempts: wait a while before trying again.":
        "Parolanın doğru olduğundan eminsen Apple oturum açma denemelerini sınırlıyor olabilir: yeniden denemeden önce bir süre bekle.",
    "Apple has locked this Apple Account for security reasons (error -20209), so every sign-in fails until it's unlocked. Reset its password at iforgot.apple.com, then sign in again with the new password.":
        "Apple güvenlik nedeniyle bu Apple Hesabını kilitledi (hata -20209); kilit açılana kadar her oturum açma başarısız olur. Parolasını iforgot.apple.com'da sıfırla, sonra yeni parolayla yeniden oturum aç.",
    "the anisette server": "anisette sunucusu",
    "all %d anisette servers": "tüm %d anisette sunucusu",
    "%d anisette servers (%d skipped)": "%d anisette sunucusu (%d atlandı)",
    "Not signed in.": "Oturum açılmadı.",
    "No SideStore IPA downloaded.": "SideStore IPA indirilmedi.",
    "Signing failed: %@": "İmzalama başarısız: %@",
    "No signed bundle to install.": "Yüklenecek imzalı paket yok.",
    "Device link dropped — reconnect.": "Cihaz bağlantısı koptu — yeniden bağlan.",
    "Pairing didn't finish — no pairing file yet.": "Eşleme bitmedi — henüz eşleme dosyası yok.",
    "Pairing file missing — pairing must run first.": "Eşleme dosyası eksik — önce eşleme yapılmalı.",
    "Pairing file missing — generate it first.": "Eşleme dosyası eksik — önce oluştur.",
    "No pairing file yet — tap “Generate pairing file” first.":
        "Henüz eşleme dosyası yok — önce “Eşleme dosyası oluştur”a dokun.",
    "%@ isn't installed yet — install must run first.": "%@ henüz yüklü değil — önce yükleme çalışmalı.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ geçerli bir IPA değil — indiği kaynak muhtemelen hata sayfası döndü veya kopya yarıda kaldı. Değiştir ve Yükle'ye yeniden dokun.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ bir IPA değil. .ipa dosyasının kendisini seç — doğru görünüyorsa indirme hata sayfası kaydetmiş veya yarıda kalmış olabilir.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Henüz IPA içe aktarılmadı. “.ipa içe aktar”a dokun ve bir tane seç.",
    "No IPA on this iPhone":
        "Bu iPhone'da karşılık gelen bir IPA yok",
    "Couldn't import %@: %@": "%@ içe aktarılamadı: %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "Bu, SideInstaller'ın indirebileceği bir bağlantı değil. .ipa'nın indirildiği tam https:// adresini yapıştır.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "Bu bağlantı bir IPA döndürmedi. Dosyanın kendisini indirmesi gerekir — yalnızca .ipa'ya bağlantı veren ya da önce oturum açmanı isteyen bir sayfa buraya web sayfası olarak gelir.",
    "Couldn't download that link: %@": "Bu bağlantı indirilemedi: %@",
    "there's nothing to download for a custom IPA — import one first":
        "özel IPA için indirilecek bir şey yok — önce bir tane içe aktar",
    "your app": "uygulaman",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple bu Apple kimliği için imzalama sertifikası vermiyor: zaten bir tane olduğunu veya isteğin hâlâ beklemede olduğunu bildiriyor (hata 7460). SideInstaller oradaki sertifikayı yeniden kullanamadı, bu yüzden değiştirmek yerine durdu. Yukarıdaki adımlara bak.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Bu iPhone%@ Apple kimliğinin geliştirici ekibine kaydedilemedi; Apple sağlama profili vermiyor. %@ — yukarıdaki adımlara bak.",
    "Connect to Wi-Fi": "Wi-Fi'ye bağlan",
    "Open Settings › Wi-Fi and join a network.": "Ayarlar › Wi-Fi'yi aç ve bir ağa katıl.",
    "Then come back here — this continues automatically.": "Sonra buraya dön — bu otomatik devam eder.",
    "Tap Connect so the toggle turns on.": "Anahtarın açılması için Connect'e dokun.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Wi-Fi'yi açık tut, sonra buraya dön — bu otomatik devam eder.",
    "Get LocalDevVPN": "LocalDevVPN al",
    "Import an .ipa first": "Önce bir .ipa içe aktar",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Yukarıda “.ipa içe aktar”a dokun ve dosyayı seç — Dosyalar uygulamasının erişebildiği her yerde olabilir; iCloud Drive veya USB sürücü dahil.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "Veya o düğmenin altında doğrudan indirme bağlantısı yapıştır; SideInstaller .ipa'yı kendisi alır.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "Veya Dosyalar uygulamasını aç, .ipa'ya basılı tut, Paylaş'a dokun ve SideInstaller'ı seç — seçici olmadan dosyayı iletir.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "Veya Dosyalar › iPhone'umda › SideInstaller'a kopyala; SideInstaller orada da bulur.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "GitHub'ın engellendiği yerlerde yol bu: IPA'yı herhangi bir cihazda indir, buraya getir ve buradan yükle.",
    "Bring the .ipa yourself": ".ipa'yı kendin getir",
    "%@ can't be downloaded while its GitHub repository is offline. The other apps still install as usual.":
        "%@, GitHub deposu çevrimdışıyken indirilemez. Diğer uygulamalar her zamanki gibi yüklenir.",
    "To install it anyway, get its .ipa from somewhere you trust, name it %@, and copy it into Files › On My iPhone › SideInstaller.":
        "Yine de yüklemek için .ipa'sını güvendiğin bir yerden al, adını %@ koy ve Dosyalar › iPhone'umda › SideInstaller'a kopyala.",
    "Then tap Install again — SideInstaller uses your file instead of downloading one.":
        "Sonra Yükle'ye yeniden dokun — SideInstaller indirmek yerine senin dosyanı kullanır.",
    "If you reach GitHub through a VPN or proxy app, turn off LocalDevVPN and turn that one on: iOS runs only one VPN at a time.":
        "GitHub'a bir VPN veya proxy uygulamasıyla ulaşıyorsan LocalDevVPN'i kapat ve onu aç: iOS aynı anda yalnızca bir VPN çalıştırır.",
    "Tap “Get the .ipa” below and save the file, or download it on another device and bring it over.":
        "Aşağıda “.ipa'yı al”a dokunup dosyayı kaydet veya başka cihazda indirip buraya getir.",
    "Back in SideInstaller, pick Custom .ipa under Install, tap “Import .ipa” and choose the file. SideInstaller recognizes %@ and sets it up just like its own download.":
        "SideInstaller'a dön, Yükle altında Özel .ipa'yı seç, “.ipa içe aktar”a dokun ve dosyayı seç. SideInstaller %@ olarak tanır ve kendi indirmesi gibi kurar.",
    "Turn LocalDevVPN back on, then tap Install.": "LocalDevVPN'i yeniden aç, sonra Yükle'ye dokun.",
    "Get the .ipa": ".ipa'yı al",
    "Pair this iPhone in Settings": "Bu iPhone'u Ayarlar'da eşle",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Ayarlar uygulamasını aç, sonra Gizlilik ve Güvenlik › Geliştirici Modu'na git.",
    "Tap “Pair with SideInstaller”.": "“SideInstaller ile eşle”ye dokun.",
    "Enter your iPhone’s passcode if it asks for it.": "Sorarsa iPhone'unun parolasını gir.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "SideInstaller'a dön, gösterdiği kodu oku, sonra aynı kodu Ayarlar'daki istem alanına yaz.",
    "Type the code that appears at the top of the screen into the prompt in Settings. If none appears, come back to SideInstaller to read it.":
        "Ekranın üstünde görünen kodu Ayarlar'daki istem alanına yaz. Hiçbiri görünmezse okumak için SideInstaller'a dön.",
    "Allow notifications when SideInstaller asks: that's how the pairing code reaches you in Settings.":
        "SideInstaller istediğinde bildirimlere izin ver: eşleme kodunun Ayarlar'da sana ulaşması böyle olur.",
    // The pairing Live Activity

    "Privacy & Security › Developer Mode › Pair with SideInstaller":
        "Gizlilik ve Güvenlik › Geliştirici Modu › SideInstaller ile eşle",
    "Paired": "Eşlendi",
    "Tap to return to SideInstaller.": "SideInstaller'a dönmek için dokun.",
    // The install's progress outside the app

    "Installing %@": "%@ yükleniyor",
    "Paused": "Duraklatıldı",
    "Ignore this version": "Bu sürümü yoksay",
    "已忽略的更新": "Yoksayılan güncellemeler",
    "没有已忽略的更新。": "Yoksayılan güncelleme yok.",
    "所有已忽略的版本都将重新提示更新。": "Yoksayılan tüm sürümler güncellemeleri yeniden önerecek.",
    "Pause": "Duraklat",
    "Pause all": "Tümünü duraklat",
    "Resume": "Devam et",
    "Resume all": "Tümünü sürdür",
    "Open": "Aç",
    "Open SideInstaller to finish the install.": "Yüklemeyi bitirmek için SideInstaller'ı aç.",
    "Check the App IDs it needs, then tap Install.": "İhtiyacı olan App ID'leri kontrol et, sonra Yükle'ye dokun.",
    "Tap Trust": "Güven'e dokun",
    "Unlock this iPhone and tap Trust when it asks.": "Bu iPhone'un kilidini aç ve sorduğunda Güven'e dokun.",
    "A signing certificate already exists": "Bir imzalama sertifikası zaten var",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Apple hata 7460 döndürdü: bu Apple kimliğinde zaten bir iOS geliştirici sertifikası var veya isteği hâlâ beklemede.",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideInstaller onu yeniden kullanamadı. Sertifika başka yerde verildiğinde olur — AltStore, SideStore, Sideloadly veya başka cihazdaki Xcode — bu yüzden gereken özel anahtar bu iPhone'da değil.",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "Yukarıda “İptal et ve yeniden dene”yi kullan veya Araçlar sekmesinde Sertifikalar'ı aç, “Sertifikaları yükle”ye dokun ve oradan iptal et.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "İptal kalıcıdır: o sertifikayla imzalanmış her uygulama, her cihazda açılmayı bırakır.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Alternatif olarak yukarıda farklı (veya yedek) bir Apple kimliğiyle oturum aç, sonra Yükle'ye yeniden dokun.",

    // MARK: - Guide cards

    // Guide: reset a locked Apple Account

    "Reset your Apple Account password": "Apple Hesabı parolanı sıfırla",
    "Apple has locked this Apple Account for security reasons, often after too many sign-in attempts. Every sign-in fails until it's unlocked, so tapping Install again won't help yet.":
        "Apple güvenlik nedeniyle bu Apple Hesabını kilitledi; genellikle çok fazla oturum açma denemesinden sonra. Kilit açılana kadar her oturum açma başarısız olur; şimdilik Yükle'ye yeniden dokunmak yardımcı olmaz.",
    "Open iForgot, enter this Apple Account's email, and follow Apple's steps to unlock it and reset its password.":
        "iForgot'u aç, bu Apple Hesabının e-postasını gir ve kilidi açıp parolayı sıfırlamak için Apple'ın adımlarını izle.",
    "Back in SideInstaller, open Settings › Account, swipe left on this Apple ID, tap Edit, and enter the new password.":
        "SideInstaller'a dön, Ayarlar › Hesap'ı aç, bu Apple kimliğinde sola kaydır, Düzenle'ye dokun ve yeni parolayı gir.",
    "Then tap Install again.": "Sonra Yükle'ye yeniden dokun.",
    "Open iForgot": "iForgot'u aç",
    "Apple won't let this Apple Account use developer services because of its owner's age (error 1102). Sign in with an adult's Apple Account instead.":
        "Apple, hesap sahibinin yaşı nedeniyle bu Apple Hesabının geliştirici hizmetlerini kullanmasına izin vermiyor (hata 1102). Bunun yerine bir yetişkinin Apple Hesabıyla oturum aç.",
    "This Apple ID has no App IDs left (error 9120). A free Apple ID can register 10 a week, and each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Bu Apple kimliğinde App ID kalmadı (hata 9120). Ücretsiz bir Apple kimliği haftada 10 tane kaydedebilir ve her biri 7 gün sayılır; bazılarının süresinin dolmasını bekle veya başka Apple kimliğiyle oturum aç.",
    "This iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. Delete one of them, then try again.":
        "Bu iPhone'da ücretsiz Apple kimliğiyle imzalanmış üç uygulama var — iOS'un izin verdiği en fazla, süresi dolmuşlar dahil. Birini sil, sonra yeniden dene.",
    "This Apple Account can't sign apps": "Bu Apple Hesabı uygulama imzalayamaz",
    "Apple only lets adults use the developer services SideInstaller signs apps with, and it reports that this Apple Account belongs to someone younger (error 1102).":
        "Apple, SideInstaller'ın uygulamaları imzaladığı geliştirici hizmetlerini yalnızca yetişkinlere açar ve bu Apple Hesabının daha genç birine ait olduğunu bildiriyor (hata 1102).",
    "Sign in with an adult's Apple Account instead: open Settings › Account and add it there.":
        "Bunun yerine bir yetişkinin Apple Hesabıyla oturum aç: Ayarlar › Hesap'ı aç ve oraya ekle.",
    "Apple won't let this Apple Account use developer services until its email address is verified (error 2160). Verify it at account.apple.com, then try again.":
        "Apple, e-posta adresi doğrulanana kadar bu Apple Hesabının geliştirici hizmetlerini kullanmasına izin vermiyor (hata 2160). account.apple.com'da doğrula, sonra yeniden dene.",
    "Verify your Apple Account's email": "Apple Hesabının e-postasını doğrula",
    "Apple won't let this Apple Account sign apps until its email address is verified (error 2160). Signing in again or through another anisette server won't change that.":
        "Apple, e-posta adresi doğrulanana kadar bu Apple Hesabının uygulama imzalamasına izin vermiyor (hata 2160). Yeniden oturum açmak veya başka anisette sunucusu kullanmak bunu değiştirmez.",
    "Sign in at account.apple.com with this Apple Account and verify its email address when Apple asks. Apple sends the code or link to that address, so check its spam folder too.":
        "account.apple.com'da bu Apple Hesabıyla oturum aç ve Apple istediğinde e-posta adresini doğrula. Apple kodu veya bağlantıyı o adrese gönderir; spam klasörünü de kontrol et.",
    "Open Apple Account": "Apple Hesabını aç",
    "No App IDs left this week": "Bu hafta App ID kalmadı",
    "They can't be deleted sooner. Wait until some expire, then tap Install again.":
        "Daha erken silinemezler. Bazılarının süresi dolana kadar bekle, sonra Yükle'ye yeniden dokun.",
    "Or sign in with a different (or spare) Apple ID in Settings › Account, then tap Install again.":
        "Veya Ayarlar › Hesap'ta farklı (veya yedek) bir Apple kimliğiyle oturum aç, sonra Yükle'ye yeniden dokun.",
    "Three sideloaded apps already": "Zaten üç yan yüklenmiş uygulama var",
    "iOS allows three apps signed with a free Apple ID on an iPhone at a time, and it refused a fourth.":
        "iOS bir iPhone'da ücretsiz Apple kimliğiyle imzalanmış en fazla üç uygulamaya izin verir ve dördüncüyü reddetti.",
    "Expired apps count too. Delete one you no longer need from the Home Screen.":
        "Süresi dolmuş uygulamalar da sayılır. Artık ihtiyacın olmayan birini Ana Ekran'dan sil.",
    // Guide: import a pairing file

    "Import a pairing file": "Bir eşleme dosyası içe aktar",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@, bir iPhone'un kendi kendine eşlenebildiği ilk sürüm. Bu iPhone'da eşleme dosyasının bir bilgisayarda oluşturulması gerekir.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "Mac, Windows PC veya Linux bilgisayarda bu iPhone'u bağla, bilgisayara güven ve jitterbugpair (veya “pymobiledevice3 lockdown pair”) çalıştır.",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "Oluşturduğu dosyayı — bir .mobiledevicepairing veya .plist — AirDrop, iCloud Drive ya da kabloyla bu iPhone'a gönder.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "Buraya dön, “Eşleme dosyasını içe aktar”a dokun ve dosyayı seç. Ondan sonrası iOS %@ üzerindeki gibi çalışır.",
    "Get jitterbugpair": "jitterbugpair al",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "Bir sertifika zaten var",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple bu Apple kimliği için ikinci bir imzalama sertifikası vermez. Zaten olanı iptal etmek yüklemenin sürmesini sağlar — ama geri alınamaz.",
    "Loading certificates": "Sertifikalar yükleniyor",
    "Revoke and retry": "İptal et ve yeniden dene",
    "Which certificate should be revoked?": "Hangi sertifika iptal edilsin?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple bu Apple kimliğinde bir sertifika olduğunu bildiriyor ama listede hiçbiri gelmedi. Hâlâ beklemede olan bir istek olabilir — birkaç dakika bekle ve Yükle'ye yeniden dokun.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "Seçtiğin sertifikayla imzalanmış her uygulama, her cihazda açılmayı bırakır — AltStore, SideStore veya bilgisayarla yüklenenler dahil. Bu geri alınamaz. Yükleme hemen ardından yeniden dener.",
    " (expired)": " (süresi dolmuş)",
    "Couldn't register this device": "Bu cihaz kaydedilemedi",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Apple kimliğin kayıtlı cihaz sınırına ulaştı. Ücretsiz hesaplar yılda yalnızca birkaç cihaz kaydedebilir ve yıl sıfırlanana kadar eskileri kaldıramaz.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "En kolay çözüm: yukarıdaki alanlara farklı (veya yedek) bir Apple kimliği yaz, sonra Yükle'ye yeniden dokun.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller bu iPhone'u Apple kimliğinin geliştirici ekibine otomatik ekleyemedi. Yükle'ye yeniden dokunmak sıkça işe yarar — Apple'ın geliştirici hizmeti bazen kısa süre kullanılamaz.",
    "If it keeps failing, add the device by hand. Its UDID is:": "Hata sürerse cihazı elle ekle. UDID'si:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Bunu Apple Developer portalındaki “Register a Device” formuna yapıştır (ücretli Apple Developer hesabı gerekir), sonra Yükle'ye yeniden dokun.",
    "Open device list": "Cihaz listesini aç",
    "Last step: trust %@": "Son adım: %@ için güven",
    "Open Settings › General › VPN & Device Management.": "Ayarlar › Genel › VPN ve Aygıt Yönetimi'ni aç.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "“Geliştirici Uygulaması” altındaki Apple kimliğine dokun, sonra Güven'e dokun.",
    "Open %@ from your Home Screen — you're done.": "%@ artık Ana Ekran'da — oradan aç, hepsi bu.",
    "Import the certificate into LiveContainer": "Sertifikayı LiveContainer'a içe aktar",
    "Open LiveContainer from your Home Screen.": "LiveContainer'ı Ana Ekran'dan aç.",
    "Tap the Settings tab.": "Ayarlar sekmesine dokun.",
    "Tap “Import Certificate From SideStore”.": "“Sertifikayı SideStore'dan içe aktar”a dokun.",
    "Wrong device IP": "Yanlış cihaz IP'si",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "Ayarlar › Gelişmiş › Cihaz IP'deki adres bu iPhone'un zaten sahip olduğu bir adres; diğer uçta bağlanacak bir şey yok.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "Varsayılan 10.7.0.1 değerine geri al. LocalDevVPN'de bu, Ayarlar › Cihaz IP altındaki değerdir — ana ekrandaki adres değil; o tünelin kendi ucudur.",
    "If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one.":
        "LocalDevVPN adreslerini değiştirdiysen, Cihaz IP'sini buraya kopyala — /32 gösteriyorsa onu da ekle.",
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "iOS, bu iPhone'da %@ adresine bağlantıyı bir şey gönderilmeden reddetti. Bunu bu iPhone'un kendi adresleri için yapar; örneğin LocalDevVPN ana ekranındaki “Bağlı” adresi. Ayarlar › Gelişmiş'teki Cihaz IP, LocalDevVPN'in Ayarlar › Cihaz IP altındaki adres olmalı: varsayılan 10.7.0.1. Zaten öyleyse LocalDevVPN'i kapatıp aç, sonra yeniden dene.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "Bu iPhone bağlantıyı açılır açılmaz kesti. iOS 26.4'ten itibaren, bunun gibi lockdown eşleme dosyaları LocalDevVPN üzerinden geldiğinde bunu yapar. Bunun yerine bu iPhone'u kendisiyle eşle: Araçlar › Eşleme altında “Yeniden oluştur”a dokun ya da önce eşlemeyi yapan Yükle'ye dokun.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "Bu iPhone bağlantı açılır açılmaz kesti. iOS 26.4'ten beri LocalDevVPN üzerinden gelen lockdown eşleme dosyalarında (bunun gibi) bunu yapar; aynı türden yenisi yardımcı olmaz. Uzaktan eşleme dosyası hâlâ çalışır: bilgisayarda idevice_pair'i aç, “Remote pairing” seç, “Create” sonra “Save to file…”e tıkla ve dosyayı “Eşleme dosyası” altında içe aktar.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Bu iPhone'u eşlemek için gerekir: SideInstaller, Ayarlar'ın bulması için kendini yerel ağda duyurur.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Bir Wi-Fi ağına bağlan. Bu iPhone'u eşlemek için gerekir — SideInstaller yerel ağda bulunabilir olmalı.",

    // MARK: - About

    "About": "Hakkında",
    "Version %@ (%@)": "Sürüm %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller, bilgisayar olmadan SideStore ve LiveContainer'ı doğrudan iPhone'una yükler.",
    "Checking for updates…": "Güncellemeler denetleniyor…",
    "Checking for updates… Tap again to cancel.": "Güncellemeler denetleniyor… İptal etmek için tekrar dokunun.",
    "You're up to date.": "Güncel durumdasınız.",
    "Couldn't check for updates. Check your connection and try again.":
        "Güncellemeler denetlenemedi. Bağlantınızı kontrol edip yeniden deneyin.",
    "Links": "Bağlantılar",
    "Source code": "Kaynak kodu",
    "Support the project": "Projeyi destekle",
    "Crypto": "Kripto",
    "Donation wallets for Bitcoin, Ethereum and Solana.": "Bitcoin, Ethereum ve Solana bağış cüzdanları.",
    "Crypto donations": "Kripto bağışları",
    "Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you.":
        "Bağışlar tamamen isteğe bağlıdır. Bir şey satın almaz, özellik açmaz veya karşılığında bir şey vermez; SideInstaller yardımcı olduysa teşekkür etmenin bir yoludur.",
    "Coin": "Kripto para",
    "Network: %@": "Ağ: %@",
    "QR code for the %@ address": "%@ adresi için QR kodu",
    "Copied": "Kopyalandı",
    "Send each coin only on the network shown. Crypto sent on another network can't be recovered.":
        "Her kripto parayı yalnızca gösterilen ağda gönder. Başka bir ağda gönderilen kripto para geri alınamaz.",
    "Special thanks": "Özel teşekkürler",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "idevice için — SideInstaller'ın iPhone'unla konuştuğu kütüphane. O olmadan bunların hiçbiri olmazdı.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Destek için ve sayesinde düzeltilen hataları bulduğu için.",
    "For the Japanese translation.": "Japonca çeviri için.",
    "For the Korean translation.": "Korece çeviri için.",
    "For the Turkish translation.": "Türkçe çeviri için.",
    "Built with": "Bunlarla yapıldı",
    "The open source work this app is built on:": "Bu uygulamanın üzerine kurulduğu açık kaynak çalışmalar:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "Eşleme, tünel ve yüklemenin kendisi. jkcoxson, MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Apple kimliği oturum açma, sertifikalar ve cihazda imzalama. nab138, MIT.",
    "The code signer isideload uses for each app. By Dadoum, LGPL-2.1.":
        "isideload’un her uygulama için kullandığı kod imzalayıcı. Dadoum, LGPL-2.1.",
    "The sideloading app this installs for you.": "Senin için yüklediği yan yükleme uygulaması.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Yan yüklenen uygulamaları her biri için uygulama yuvası harcamadan çalıştırır.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "Geliştirici disk görüntüsü konum taklidi bağlama noktaları. doronz88 tarafından yansıtıldı.",
    "Terms": "Koşullar",

    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.": "%@ için iOS %d veya sonrası gerekir. Bu iPhone iOS %@ çalıştırıyor.",
    "%@ needs iOS %@ or later. This iPhone runs iOS %@.": "%@ için iOS %@ veya sonrası gerekir. Bu iPhone iOS %@ çalıştırıyor.",
    "Minimum iOS": "Asgari iOS",
    "SHA-256": "SHA-256",
    "Show all": "Tümünü göster",
    "Open Madeira from your Home Screen.": "Madeira'yı Ana Ekran'dan aç.",
    "In its setup, under “Set up JIT”, pick “In-app with pairing file”: SideInstaller already put the file there, so tap “Continue”.":
        "Kurulumunda “Set up JIT” altında “In-app with pairing file” seç: SideInstaller dosyayı zaten oraya koydu, “Continue”e dokun.",
    "In its setup, under “Set up JIT”, pick how this iPhone gets JIT.":
        "Kurulumunda “Set up JIT” altında bu iPhone'un JIT'i nasıl alacağını seç.",
    "Madeira renews its own signing from now on, when it's open and LocalDevVPN is connected. SideInstaller gave it a sign-in for that: a token for Apple's developer service, not your password. Madeira can forget it under Settings › Signing.":
        "Madeira bundan sonra kendi imzasını yeniler; açıkken ve LocalDevVPN bağlıyken. SideInstaller bunun için bir oturum verdi: Apple'ın geliştirici hizmeti için jeton, parolan değil. Madeira Ayarlar › İmzalama altında bunu unutabilir.",
    "Its signing lasts 7 days. Before they run out, refresh it here under Tools › Sideloaded apps.":
        "İmzası 7 gün geçerli. Süre dolmadan burada, Araçlar › Yan yüklenen uygulamalar altında yenile.",
    "This pairing file has no RPPairing record, the only kind %@ reads.":
        "Bu eşleme dosyasında RPPairing kaydı yok; %@ yalnızca bu türü okur.",
    "Runs Windows PC games on your iPhone. By Will Faust, GPL-3.0.":
        "Windows PC oyunlarını iPhone'unda çalıştırır. Will Faust, GPL-3.0.",

    // MARK: - App ID cost

    "App IDs for this app": "Bu uygulama için App ID'ler",
    "Cost": "Maliyet",
    "Left now": "Şu an kalan",
    "Left after": "Sonra kalan",
    "New App IDs": "Yeni App ID'ler",
    "This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Bu Apple kimliğinde yeterli App ID kalmadı: bu uygulama %d ister, %d kaldı. Her biri 7 gün sayılır; bazılarının süresinin dolmasını bekle veya başka Apple kimliğiyle oturum aç.",
    "The next one frees up on %@.": "Bir sonraki %@ tarihinde boşalır.",
    "Your Apple ID already has every App ID this app needs, so installing it uses none.":
        "Apple kimliğin bu uygulamanın istediği tüm App ID'lere zaten sahip; yüklemek hiçbirini kullanmaz.",
    "Signing registers one App ID for the app, and its extensions share it. It counts for 7 days.":
        "İmzalama uygulama için bir App ID kaydeder; uzantıları da onu paylaşır. 7 gün sayılır.",
    "This Apple ID can register %d a week.": "Bu Apple kimliği haftada %d tane kaydedebilir.",

    // MARK: - Links (sideinstaller://install, sideinstaller://pairingFile)

    "Install from a link?": "Bağlantıdan yüklensin mi?",
    "Download and install": "İndir ve yükle",
    "SideInstaller will download this .ipa, then sign it with your Apple ID and install it. Only go ahead if you trust where the link came from.":
        "SideInstaller bu .ipa'yı indirir, Apple kimliğinle imzalar ve yükler. Yalnızca bağlantının geldiği yere güveniyorsan devam et.",
    "It replaces %@, the custom .ipa you have now.": "Şu anki özel .ipa'nın (%@) yerine geçer.",
    "Use SideStore's pairing file?": "SideStore'un eşleme dosyası kullanılsın mı?",
    "Import this pairing file?": "Bu eşleme dosyası içe aktarılsın mı?",
    "Import": "İçe aktar",
    "SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.":
        "SideStore elindeki eşleme dosyasını geri gönderdi. SideInstaller bu iPhone'a onunla bağlanacak.",
    "A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.":
        "Bir bağlantı SideInstaller'a eşleme dosyası gönderdi. Yalnızca sen istediysen içe aktar: SideInstaller bu iPhone'a onunla bağlanacak.",
    "It replaces %@.": "%@ yerine geçer.",
    "It replaces the pairing file in use now.": "Şu an kullanılan eşleme dosyasının yerine geçer.",
    "Get it from SideStore": "SideStore'dan al",
    "SideStore opens and sends back the pairing file it has.": "SideStore açılır ve elindeki eşleme dosyasını geri gönderir.",
    "SideStore isn't installed on this iPhone, so there's no pairing file to get from it.":
        "Bu iPhone'da SideStore yüklü değil, bu yüzden ondan alınacak eşleme dosyası yok.",
    "SideInstaller takes the pairing file LiveContainer's built-in SideStore has.":
        "SideInstaller, LiveContainer'ın yerleşik SideStore'undaki eşleme dosyasını alır.",
    "This is the pairing file LiveContainer's built-in SideStore has. SideInstaller will connect to this iPhone with it.":
        "Bu, LiveContainer'ın yerleşik SideStore'undaki eşleme dosyası. SideInstaller bu iPhone'a onunla bağlanacak.",
    "In LiveContainer's Multitask Mode, SideInstaller can't open the built-in SideStore's files. Open SideInstaller in LiveContainer without Multitask Mode, then try again, or tap “Import pairing file” and pick the file your computer made.":
        "LiveContainer'ın Çoklu Görev Modu'nda SideInstaller yerleşik SideStore dosyalarını açamaz. SideInstaller'ı LiveContainer'da Çoklu Görev Modu olmadan açıp yeniden dene, veya “Eşleme dosyasını içe aktar”a dokunup bilgisayarının oluşturduğu dosyayı seç.",
    "Inside LiveContainer, SideStore can't send its pairing file back to SideInstaller, and LiveContainer's built-in SideStore has none that SideInstaller can use. Tap “Import pairing file” and pick the file your computer made, or import one into SideStore first, then try again here.":
        "LiveContainer içinde SideStore eşleme dosyasını SideInstaller'a geri gönderemez ve LiveContainer'ın yerleşik SideStore'unda SideInstaller'ın kullanabileceği bir dosya yok. “Eşleme dosyasını içe aktar”a dokunup bilgisayarının oluşturduğu dosyayı seç, veya önce SideStore'a bir tane içe aktarıp burada yeniden dene.",
    "That install link has no .ipa in it. It needs ?url= followed by the https:// address the .ipa downloads from.":
        "Bu yükleme bağlantısında .ipa yok. ?url= ve ardından .ipa'nın indirildiği https:// adresi gerekir.",
    "That link was meant to carry a pairing file, but what it holds can't be read.":
        "Bu bağlantı bir eşleme dosyası taşıyacaktı, ancak içeriği okunamıyor.",
    "That link carries a file, but it isn't a pairing file.": "Bu bağlantı bir dosya taşıyor, ancak eşleme dosyası değil.",

    // MARK: - Report a problem

    "Report a problem": "Sorun bildir",
    "Report this problem": "Bu sorunu bildir",
    "Opens a GitHub issue with this app's details, its log and crash logs.":
        "Bu uygulamanın ayrıntıları, günlüğü ve çökme günlükleriyle bir GitHub sorunu açar.",
    "What happened?": "Ne oldu?",
    "What were you doing, and what went wrong?": "Ne yapıyordun ve ne ters gitti?",
    "Say what you tapped, what you expected and what happened instead. English is best, but any language is fine.":
        "Neye dokunduğunu, ne beklediğini ve bunun yerine ne olduğunu yaz. En iyisi İngilizce, ama her dil olur.",
    "Included": "Dahil",
    "Device": "Cihaz",
    "App": "Uygulama",
    "Stopped at": "Durduğu yer",
    "not connected": "bağlı değil",
    "none": "yok",
    "made on this iPhone": "bu iPhone'da oluşturuldu",
    "Runs inside LiveContainer": "LiveContainer içinde çalışır",
    "on": "açık",
    "off": "kapalı",
    "unknown": "bilinmiyor",
    "yes": "evet",
    "no": "hayır",
    "latest": "en son",
    "custom server": "özel sunucu",
    "Auto, starts with %@": "Otomatik, %@ ile başlar",
    "Error": "Hata",
    "Activity log": "Etkinlik günlüğü",
    "%d lines": "%d satır",
    "Your Apple ID, device name, serial numbers and keys are taken out of the log first.":
        "Apple kimliğin, cihaz adı, seri numaraları ve anahtarlar önce günlükten çıkarılır.",
    "Crash logs": "Çökme günlükleri",
    "Looking for crash logs …": "Çökme günlükleri aranıyor …",
    "Look for crash logs on this iPhone": "Bu iPhone'da çökme günlüklerini ara",
    "Look again": "Yeniden ara",
    "No crash logs from SideStore, LiveContainer or Madeira in the last %d days.":
        "Son %d günde SideStore, LiveContainer veya Madeira'dan çökme günlüğü yok.",
    "iOS hands SideInstaller its own crashes the next time it opens. Crash logs from SideStore, LiveContainer and Madeira are read from this iPhone through LocalDevVPN.":
        "iOS, SideInstaller'ın kendi çökmelerini bir sonraki açılışta iletir. SideStore, LiveContainer ve Madeira çökme günlükleri LocalDevVPN üzerinden bu iPhone'dan okunur.",
    "Open a GitHub issue": "GitHub sorunu aç",
    "Share the report": "Raporu paylaş",
    "Preview the report": "Raporu önizle",
    "Report": "Rapor",
    "The issue opens filled in. When the log is too long for that, SideInstaller copies it for you to paste at the end of the issue. The whole report is also saved in %@.":
        "Sorun doldurulmuş olarak açılır. Günlük bunun için çok uzunsa SideInstaller, sorunun sonuna yapıştırman için kopyalar. Tüm rapor ayrıca %@ konumuna kaydedilir.",
    "Files › On My iPhone": "Dosyalar › iPhone'umda",
    "Copy the full log": "Tam günlüğü kopyala",
    "Paste the log into the issue": "Günlüğü soruna yapıştır",
    "Open GitHub": "GitHub'ı aç",
    "The full log is too long to fill in, so SideInstaller copied it. On GitHub, tap the end of the text, choose Paste, then submit the issue.":
        "Tam günlük doldurulamayacak kadar uzun, bu yüzden SideInstaller kopyaladı. GitHub'da metnin sonuna dokun, Yapıştır'ı seç, sonra sorunu gönder.",
    "Describe the problem above first.": "Önce yukarıda sorunu açıkla.",
    "Couldn't save the report: %@": "Rapor kaydedilemedi: %@",

    // MARK: - Official download check

    "Did you download SideInstaller from sideinstaller.net?": "SideInstaller'ı sideinstaller.net'ten mi indirdin?",
    "SideInstaller is open source, so anyone can publish a modified copy that steals the Apple ID typed into it. Only sideinstaller.net is official.":
        "SideInstaller açık kaynaklıdır, bu yüzden herkes içine yazılan Apple kimliğini çalan değiştirilmiş bir kopya yayınlayabilir. Yalnızca sideinstaller.net resmidir.",
    "Yes, from sideinstaller.net": "Evet, sideinstaller.net'ten",
    "No, or I'm not sure": "Hayır veya emin değilim",
    "Don't sign in with this copy": "Bu kopya ile oturum açma",
    "Copies from anywhere other than sideinstaller.net are unofficial and may have been changed to steal your Apple ID. Delete this one and install SideInstaller from sideinstaller.net, then sign in there.":
        "sideinstaller.net dışındaki her yerden gelen kopyalar resmi değildir ve Apple kimliğini çalmak için değiştirilmiş olabilir. Bunu sil, SideInstaller'ı sideinstaller.net'ten yükle ve orada oturum aç.",
    "Open sideinstaller.net": "sideinstaller.net'i aç",
    "Back": "Geri",
    "I understand the risks": "Riskleri anlıyorum",
    "Use an unofficial copy?": "Resmi olmayan bir kopya kullanılsın mı?",
    "If this copy was changed, it can send your Apple ID and password to someone else. Continue only if you trust where it came from.":
        "Bu kopya değiştirildiyse Apple kimliğini ve parolanı başkasına gönderebilir. Yalnızca geldiği yere güveniyorsan devam et.",

    // MARK: - Side by Side: their address, and the pairing file SideInstaller gets

    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Diğer iPhone'a %@ adresinden ulaşılamadı. Adresi (diğer iPhone'da Ayarlar › Wi-Fi › ⓘ), iki iPhone'un aynı Wi-Fi ağında olduğunu ve bu iPhone'un Ayarlar'ında SideInstaller için Yerel Ağ'ın açık olduğunu kontrol et. Misafir ve genel ağlar cihazların birbirine ulaşmasını sıkça engeller.",
    "Their iPhone": "Diğer iPhone",
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "Diğer iPhone'da “Güvenme”ye dokunuldu. Yeniden başla ve bu kez Güven'e dokunulmasını iste.",
    "Pairs from its Settings": "Kendi Ayarlar'ından eşlenir",
    "Waiting for them to tap Trust…": "Diğer iPhone'da Güven'e dokunulması bekleniyor…",
    "Tap Trust on their iPhone": "Diğer iPhone'da Güven'e dokun",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "Diğer iPhone'da: Ayarlar › Wi-Fi › ağın yanındaki ⓘ, sonra “IP Adresi”.",
    "Unlock their iPhone, then tap Trust in the prompt that comes up.":
        "Diğer iPhone'un kilidini aç, sonra çıkan istemde Güven'e dokun.",
    "This iPhone is %@, so theirs will look similar.":
        "Bu iPhone'un adresi %@; diğerininki de buna benzer olur.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” bir IPv4 adresi değil. 192.168.1.42 gibi görünmeli.",
    "Do you have the device's IP?": "Cihazın IP adresini biliyor musun?",
    "Optional": "İsteğe bağlı",
    "SideInstaller asks their iPhone to pair directly. Needed below iOS 27.":
        "SideInstaller diğer iPhone'dan doğrudan eşlenmesini ister. iOS 27'nin altında gerekir.",
    "Their iPhone pairs from its own Settings, which needs iOS 27.":
        "Diğer iPhone kendi Ayarlar'ından eşlenir, bunun için iOS 27 gerekir.",
    "IP address": "IP adresi",
    "Their iPhone runs iOS %@. From iOS 26.4 on, SideInstaller can't use the pairing their iPhone gives over Wi-Fi, so it needs a pairing file made on a computer.":
        "Diğer iPhone iOS %@ kullanıyor. iOS 26.4'ten itibaren SideInstaller, diğer iPhone'un Wi-Fi üzerinden verdiği eşlemeyi kullanamaz, bu yüzden bilgisayarda yapılmış bir eşleme dosyası gerekir.",
    "Get LocalDevVPN from the App Store and connect it: SideInstaller works through it.":
        "App Store'dan LocalDevVPN'i indir ve bağla: SideInstaller onun üzerinden çalışır.",
    "Open SideInstaller. Its pairing file is already in place.":
        "SideInstaller'ı aç. Eşleme dosyası zaten yerinde.",
    "Open SideInstaller and import a pairing file made on a computer.":
        "SideInstaller'ı aç ve bilgisayarda yapılmış bir eşleme dosyasını içe aktar.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone, so use theirs. To install on this one, use the Install tab.":
        "%@ bu iPhone'un zaten sahip olduğu bir adres. Side by Side başkasının iPhone'una yükler, o yüzden onunkini kullan. Buna yüklemek için Yükle sekmesini kullan.",
    "Their iPhone runs iOS %@. From iOS 26.4 on, %@ can't use the pairing their iPhone gives over Wi-Fi. iOS 27 pairs from its own Settings instead, which works: update their iPhone, then try again and answer No when asked for its IP.":
        "Diğer iPhone iOS %@ kullanıyor. iOS 26.4'ten itibaren %@, diğer iPhone'un Wi-Fi üzerinden verdiği eşlemeyi kullanamaz. iOS 27 bunun yerine kendi Ayarlar'ından eşlenir ve bu çalışır: diğer iPhone'u güncelle, sonra yeniden dene ve IP'si sorulduğunda Hayır'ı seç.",

    // MARK: - AltStore

    "couldn't reach %@: %@":
        "%@ adresine ulaşılamadı: %@",
    "%@ answered HTTP %d":
        "%@ HTTP %d yanıtı verdi",
    "%@'s list of apps couldn't be read (%@). Something on this network may have replaced it.":
        "%@ uygulama listesi okunamadı (%@). Bu ağdaki bir şey onu değiştirmiş olabilir.",
    "the %@ that arrived isn't the file %@ lists, so it isn't installed. Try again later.":
        "Gelen %@, %@ listesindeki dosya değil, bu yüzden yüklenmedi. Daha sonra yeniden dene.",
    "%@ lists no version of %@ that runs on iOS %@.":
        "%@ listesinde %@ için iOS %@ ile uyumlu bir sürüm yok.",
    "Open AltStore from your Home Screen and sign in with your Apple ID.":
        "AltStore'u Ana Ekran'dan aç ve Apple ID'nle giriş yap.",
    "To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings. Its pairing file is already in place, so the setup skips pairing.":
        "Bilgisayarsız uygulama yüklemek ve yenilemek için AltStore'un Ayarlar'ında “Set up Remote AltServer”a dokun. Eşleme dosyası zaten yerinde, bu yüzden kurulum eşleme adımını atlar.",
    "To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings and follow its steps.":
        "Bilgisayarsız uygulama yüklemek ve yenilemek için AltStore'un Ayarlar'ında “Set up Remote AltServer”a dokun ve adımları izle.",
    "Open AltStore and sign in with the same Apple ID.":
        "AltStore'u aç ve aynı Apple ID ile giriş yap.",

    // MARK: - LAN transfer (browser page)

    "File not found": "Dosya bulunamadı",
    "Invalid path": "Geçersiz yol",
    "Couldn't parse the upload": "Yükleme işlenemedi",
    "No such page": "Böyle bir sayfa yok",
    "Download": "İndir",
    "Download complete": "İndirme tamamlandı",
    "%@ downloaded. You can install it from the Downloads page.": "%@ indirildi. İndirilenler sayfasından yükleyebilirsiniz.",
    "Delete this file?": "Bu dosya silinsin mi?",
    "This directory is empty": "(Bu dizin boş)",
    "SideInstaller LAN Transfer": "SideInstaller LAN Aktarımı",
    "SideInstaller File Transfer": "SideInstaller Dosya Aktarımı",
    "Upload": "Yükle",
    "File": "Dosya",
    "Size": "Boyut",
    "Add": "Ekle",
    "Add Source": "Kaynak ekle",
    "Anyone on your LAN can access it without a password. Turn it off when done.": "LAN’ınızdaki herkes şifresiz erişebilir. İşiniz bitince kapatın.",
    "Appearance": "Görünüm",
    "Apple ID sign-in failed on %@. Last error: %@": "%@ üzerinde Apple ID ile giriş yapılamadı. Son hata: %@",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Revoke it under Tools › Certificates, then refresh again.": "Apple bu Apple ID için bir imzalama sertifikası vermeyecek: zaten bir tane olduğunu bildiriyor (hata 7460). Araçlar › Sertifikalar altında iptal edip yeniden yenileyin.",
    "Auto Refresh": "Otomatik yenileme",
    "Built-in tunnel interface": "Yerleşik tünel arayüzü",
    "Built-in tunnel: interface 10.7.1.1/32 and peer 10.7.0.1/32 by default. Address changes take effect the next time the tunnel connects.": "Yerleşik tünel: varsayılan olarak arayüz 10.7.1.1/32 ve eş 10.7.0.1/32. Adres değişiklikleri tünelin bir sonraki bağlantısında geçerli olur.",
    "Certificate password:": "Sertifika şifresi:",
    "Couldn't reach the device at %@:%d at all. The loopback VPN is most likely off, or Device IP isn't the address it carries: in LocalDevVPN that's the one under Settings › Device IP (10.7.0.1 by default), not the “Connected to” address on its main screen. First check that the phone and the computer are on the same Wi-Fi (the local tunnel needs a local network).": "%@:%d adresindeki cihaza hiç ulaşılamadı. Geri döngü VPN’i büyük olasılıkla kapalı ya da Cihaz IP’si cihazın kullandığı adres değil: LocalDevVPN’de bu, ana ekrandaki \"Bağlı olunan\" adresi değil, Ayarlar › Cihaz IP altındaki adrestir (varsayılan 10.7.0.1). Önce telefonun ve bilgisayarın aynı Wi-Fi’de olduğunu denetleyin (yerel tünel yerel ağ gerektirir).",
    "Dark": "Koyu",
    "Every app and app extension SideInstaller signs needs an App ID. A free Apple ID can register 10 a week, and each one counts for 7 days.": "SideInstaller’ın imzaladığı her uygulama ve uygulama uzantısının bir App ID’si olmalıdır. Ücretsiz bir Apple ID haftada 10 tane kaydedebilir ve her biri 7 gün geçerlidir.",
    "Export certificate (p12)": "Sertifikayı dışa aktar (p12)",
    "Follow System": "Sistemi izle",
    "Import failed": "İçe aktarma başarısız",
    "Light": "Açık",
    "Loading…": "Yükleniyor…",
    "Location is not set to “Always”, so only silent audio is keeping the app alive — renewal from the lock screen may be suspended. Set Location to “Always” in Settings.": "Konum \"Her zaman\" olarak ayarlanmamış, bu yüzden uygulamayı yalnızca sessiz ses ayakta tutuyor; kilit ekranından yenileme askıya alınabilir. Ayarlar’da Konum’u \"Her zaman\" yapın.",
    "No IPA imported.": "İçe aktarılmış IPA yok.",
    "No sources yet. Tap + to add one.": "Henüz kaynak yok. Eklemek için + simgesine dokunun.",
    "Refresh apps automatically in background": "Uygulamaları arka planda otomatik yenile",
    "SideInstaller stays alive in the background (silent audio + location) and checks every 30 minutes. Apps whose signing expires within 3 days are re-signed automatically. Location access must be set to “Always” and the tunnel must stay connected (the built-in tunnel is enough). The system also wakes the app in the background from time to time to run a check — don't swipe it away from the app switcher.": "SideInstaller arka planda çalışmaya devam eder (sessiz ses + konum) ve her 30 dakikada bir denetler. İmzası 3 gün içinde dolacak uygulamalar otomatik olarak yeniden imzalanır. Konum erişimi \"Her zaman\" olarak ayarlanmalı ve tünel bağlı kalmalıdır (yerleşik tünel yeterlidir). Sistem ayrıca ara sıra uygulamayı arka planda uyandırıp denetim çalıştırır; uygulama değiştiriciden kapatmayın.",
    "Skipped: not signed by the team you're signed in as, so a certificate-signed app is never re-signed here.": "Atlandı: giriş yaptığınız ekip tarafından imzalanmamış, bu nedenle sertifikayla imzalanmış bir uygulama burada asla yeniden imzalanmaz.",
    "Source URL": "Kaynak URL’si",
    "That isn't a usable source link.": "Bu kullanılabilir bir kaynak bağlantısı değil.",
    "The built-in tunnel couldn't start. See the log for the reason, then try again.": "Yerleşik tünel başlatılamadı. Nedeni için günlüğe bakın, sonra yeniden deneyin.",
    "Transfer files to Documents over LAN": "LAN üzerinden Documents’a dosya aktar",
    "Tunnel peer (device IP)": "Tünel eş (cihaz IP)",
    "Tunnel standby": "Tünel beklemede",
    "WebDAV failed to start": "WebDAV başlatılamadı",
    "WebDAV file service": "WebDAV dosya hizmeti",
    "Wi-Fi not connected": "Wi-Fi bağlı değil",
    "导出描述文件": "Sağlama profilini dışa aktar",
    "导出后可在 LiveContainer 里导入同一张证书，不用再找原文件；密码不一起导出，导入时再填一次。": "Dışa aktardıktan sonra orijinal dosyayı aramadan aynı sertifikayı LiveContainer’a aktarabilirsiniz; şifre birlikte dışa aktarılmaz, içe aktarırken yeniden girersiniz.",
    "名字不能以. 开头": "Ad '.' ile başlayamaz",
    // SIDE-35 (0.9.124): new keys.
    "Modified edition": "Değiştirilmiş sürüm",
    "Archive": "Arşiv",
    "%@ (extracted)": "%@ (çıkarıldı)",
    "Source is too large": "Kaynak çok büyük",
    "Folders can't be deleted": "Klasörler silinemez",
    // SIDE-36 (0.9.125): new keys.
    "Couldn't read this source": "Bu kaynak okunamadı",
    "Listing certificates failed: %@": "Sertifikalar listelenemedi: %@",
    "Revoke failed: %@": "İptal başarısız oldu: %@",
    "Couldn't parse p12 export result.": "p12 dışa aktarma sonucu ayrıştırılamadı.",
    "Export failed: %@": "Dışa aktarma başarısız oldu: %@",
    "Listing App IDs failed: %@": "App ID'leri listelenemedi: %@",
    "Enabling entitlements failed: %@": "Yetkiler etkinleştirilemedi: %@",
    "Waiting for this install to finish…": "Bu yüklemenin bitmesi bekleniyor…",
    "This file is being installed. Wait until it finishes.": "Bu dosya yükleniyor. Bitene kadar bekleyin.",
    "The device answered on the RSD port at %@, then the tunnel port it opened was unreachable on that same address — dropped or refused, across %@. The device is there; what's in front of it is forwarding some ports and not others. The tunnel opens on a fresh high port every attempt, so a rule-based proxy that forwards the RSD port alone can never cover it. Use a loopback VPN that blanket-forwards every port on the RSD subnet. Re-pairing won't help — the pairing is fine.": "Cihaz %@ adresindeki RSD bağlantı noktasına yanıt verdi, ancak açtığı tünel bağlantı noktasına aynı adreste ulaşılamadı — atıldı veya reddedildi, %@ üzerinde denendi. Cihaz orada; önündeki şey bazı bağlantı noktalarını iletiyor, bazılarını iletmiyor. Tünel her denemede yeni bir yüksek bağlantı noktasında açıldığı için yalnızca RSD bağlantı noktasını ileten kural tabanlı bir proxy bunu asla kapsayamaz. RSD alt ağındaki tüm bağlantı noktalarını ileten bir geri döngü VPN kullanın. Yeniden eşleştirmek işe yaramaz — eşleştirme sorunsuz.",
    "The tunnel port never answered and never refused on any address (%@) — the connection is being swallowed rather than rejected. That's usually a VPN or firewall dropping traffic on the RSD subnet. Check the VPN is still up, then try again.": "Tünel bağlantı noktası hiçbir adreste (%@) yanıt vermedi de reddetmedi de — bağlantı reddedilmek yerine yutuluyor. Bu genellikle RSD alt ağında trafiği atan bir VPN veya güvenlik duvarıdır. VPN'in hâlâ açık olduğunu kontrol edip yeniden deneyin.",
    "Something accepted the tunnel connection but failed the encrypted handshake on top of it. Either another process holds that port, or this pairing file's key no longer matches the device. Pair again, and if that doesn't take, restart the loopback VPN.": "Bir şey tünel bağlantısını kabul etti ancak üzerindeki şifreli el sıkışma başarısız oldu. Ya başka bir işlem o bağlantı noktasını tutuyor ya da bu eşleştirme dosyasının anahtarı artık cihazla eşleşmiyor. Yeniden eşleştirin, olmazsa geri döngü VPN'i yeniden başlatın.",
    "The device rejected this pairing file: it's for a different device, or the pairing was revoked (a reset, a restore, or Developer Mode being turned off). Pair with this iPhone again to get a fresh file.": "Cihaz bu eşleştirme dosyasını reddetti: başka bir cihaza ait ya da eşleştirme iptal edilmiş (sıfırlama, geri yükleme veya Geliştirici Modu kapatılmış). Yeni bir dosya almak için bu iPhone'u yeniden eşleştirin.",
    "The tunnel didn't come up, and the failure didn't match any known cause. The raw error is in the log.": "Tünel kurulamadı ve hata bilinen hiçbir nedene uymuyor. Ham hata günlükte.",
    "Diagnostics: remote pairing advertisement: %@; Developer Mode: %@.": "Tanı: uzaktan eşleştirme duyurusu: %@; Geliştirici Modu: %@.",
    "No anisette servers are configured.": "Hiçbir anisette sunucusu yapılandırılmadı.",
    "Sign-in failed.": "Oturum açma başarısız oldu.",
    "This folder can't be renamed or moved.": "Bu klasör yeniden adlandırılamaz veya taşınamaz.",
    "This file is being signed. Wait until it finishes.": "Bu dosya imzalanıyor. Bitene kadar bekleyin.",
    "This file is being renewed. Wait until it finishes.": "Bu dosya yenileniyor. Bitene kadar bekleyin.",
    "This only clears the list. Installed apps are not affected.": "Bu yalnızca listeyi temizler. Kurulu uygulamalar etkilenmez.",
    "empty account config": "Hesap yapılandırması boş",
    "%d files, first %@: %@": "%d dosya, ilki %@ : %@",
    "%@ isn't listed": "%@ listede yok",
    "the data couldn't be read": "Veriler okunamadı",
    "Couldn't reach this iPhone. Check the connection and try again.": "Bu iPhone'a ulaşılamıyor. Bağlantıyı kontrol edip yeniden deneyin.",
    "the connection to this iPhone failed": "bu iPhone'a bağlantı kurulamadı.",

    // MARK: - SIDE-43+44 (0.9.132)
    "This Apple ID has no development team. Sign in at developer.apple.com once to create one, then try again.": "Bu Apple Kimliğinin geliştirme ekibi yok. Bir ekip oluşturmak için developer.apple.com adresine bir kez giriş yapın, sonra yeniden deneyin.",
    "That certificate belongs to another Apple ID, or it was revoked.": "Bu sertifika başka bir Apple Kimliğine ait veya iptal edilmiş.",
    "That App ID is no longer on this team.": "Bu App ID artık bu ekipte değil.",
    "That file isn't a certificate archive (.p12). Check the file and try again.": "Bu dosya bir sertifika arşivi (.p12) değil. Dosyayı denetleyip yeniden deneyin.",
    "There's no signing certificate on this Apple ID yet. Install an app first — that's what creates it.": "Bu Apple Kimliğinde henüz bir imzalama sertifikası yok. Önce bir uygulama yükleyin — sertifika yükleme sırasında oluşturulur.",
    "Check the network connection and try again.": "Ağ bağlantısını denetleyip yeniden deneyin.",
    "Apple didn't accept the sign-in. Check the Apple ID and password, then try again.": "Apple oturum açmayı kabul etmedi. Apple Kimliğini ve parolayı denetleyip yeniden deneyin.",
    "Sign-ins are being limited right now. Wait a few minutes and try again.": "Oturum açmalar şu anda sınırlandırılıyor. Birkaç dakika bekleyip yeniden deneyin.",
    "Apple's service didn't answer. Try again in a bit.": "Apple hizmeti yanıt vermedi. Biraz sonra yeniden deneyin.",
    "This iPhone is out of storage space. Free some space and try again.": "Bu iPhone'da depolama alanı kalmadı. Yer açıp yeniden deneyin.",
    "A file this step needed is missing. Check the file library and try again.": "Bu adım için gereken bir dosya bulunamadı. Dosya kitaplığını denetleyip yeniden deneyin.",
    "Something went wrong. Check the activity log and try again.": "Bir şeyler ters gitti. Etkinlik günlüğünü denetleyip yeniden deneyin.",
    "Couldn't read the certificate list.": "Sertifika listesi okunamadı.",
    "Couldn't read what the import did.": "İçe aktarma sonucu okunamadı.",
    "Couldn't read the App ID list.": "App ID listesi okunamadı.",
    "Couldn't read Apple's reply.": "Apple yanıtı okunamadı.",
    "瘦身改包解压失败。": "Paketi hafifletmek için açma başarısız oldu.",
    "瘦身改包压包失败。": "Paketi hafifletmek için sıkıştırma başarısız oldu.",
    "Pairing file for another iPhone": "Başka bir iPhone'un eşleştirme dosyası",
    "This pairing file belongs to another iPhone (UDID %@). The iPhone connected now is %@.": "Bu eşleştirme dosyası başka bir iPhone'a aittir (UDID %@). Şu anda bağlı olan iPhone %@.",
    "The route server couldn't plan this route.": "Rota sunucusu bu rotayı planlayamadı.",
    "Their iPhone connected but stopped responding before asking for a code. Try pairing again.": "Karşı tarafın iPhone'u bağlandı ama kod istemeden yanıt vermeyi kesti. Yeniden eşleştirmeyi deneyin.",
    "The pairing code wasn't entered in time. Pair again and enter the code when it appears.": "Eşleştirme kodu zamanında girilmedi. Yeniden eşleştirin ve kod göründüğünde girin.",
    "Their iPhone rejected this pairing file: it's for a different device, or the pairing was revoked (a reset, a restore, or Developer Mode being turned off). Pair with their iPhone again to get a fresh file.":
        "Diğer iPhone bu eşleştirme dosyasını reddetti: dosya başka bir cihaza ait ya da eşleştirme iptal edilmiş (sıfırlama, geri yükleme veya Geliştirici Modu'nun kapatılması). Yeni bir dosya almak için diğer iPhone ile yeniden eşleştir.",
    "Their iPhone answered, but the tunnel port it opened couldn't be reached — something between the two iPhones is forwarding some ports and not others. Check both iPhones are on the same Wi-Fi network (not a guest network), and that Local Network is on for SideInstaller in this iPhone's Settings. Re-pairing won't help — the pairing is fine.":
        "Diğer iPhone yanıt verdi, ama açtığı tünel portuna ulaşılamadı. İki iPhone arasında bir şey bazı portları geçirip bazılarını geçirmiyor. İki iPhone'un aynı Wi-Fi ağında (misafir ağı değil) olduğunu ve bu iPhone'un Ayarlar'ında SideInstaller için Yerel Ağ'ın açık olduğunu kontrol et. Yeniden eşleştirmek işe yaramaz, eşleştirme sağlam.",
    "Their iPhone never answered the tunnel port and never refused it — the connection is being swallowed rather than rejected. That's usually the Wi-Fi network or a firewall dropping traffic on the way. Check both iPhones are on the same Wi-Fi network, then try again.":
        "Diğer iPhone tünel portuna ne yanıt verdi ne de reddetti. Bağlantı reddedilmiyor, yolda yutuluyor. Genellikle Wi-Fi ağı ya da bir güvenlik duvarı trafiği yolda düşürüyor. İki iPhone'un aynı Wi-Fi ağında olduğunu kontrol edip yeniden dene.",
    "Something accepted the tunnel connection but the encrypted handshake on top of it failed. Either another process holds that port, or this pairing file's key no longer matches their iPhone. Pair again.":
        "Bir şey tünel bağlantısını kabul etti ama üstündeki şifreli el sıkışma başarısız oldu. Ya başka bir işlem o portu tutuyor ya da bu eşleştirme dosyasının anahtarı artık diğer iPhone ile uyuşmuyor. Yeniden eşleştir.",
    "GitHub answered HTTP %d":
        "GitHub HTTP %d yanıtı verdi",
    "The code was incorrect. Try again.":
        "Kod yanlıştı. Tekrar deneyin.",
    "A code was already sent and is still valid. Enter it.":
        "Bir kod zaten gönderildi ve hâlâ geçerli. Girin.",
    "That way isn't available. Choose another way.":
        "Bu yöntem kullanılamıyor. Başka bir yöntem seçin.",
    "That didn't work. Try another way.":
        "Olmadı. Başka bir yöntem deneyin.",
    // MARK: - Developer team

    "Free · %@": "Ücretsiz · %@",
    "Paid · %@": "Ücretli · %@",
    "This Apple Account is on %d developer teams. Pick the one that signs.":
        "Bu Apple Hesabı %d geliştirici ekibinde. İmzalayacak ekibi seç.",
    "Which Team?": "Hangi ekip?",
    "Signed this copy of SideInstaller": "Bu SideInstaller kopyasını imzaladı",
    "A free team's apps last 7 days; a paid team's last a year.":
        "Ücretsiz bir ekibin uygulamaları 7 gün, ücretli bir ekibinkiler bir yıl geçerlidir.",
    "An app installed with another team isn't replaced: signing it with this one installs a second copy.":
        "Başka bir ekiple yüklenen uygulama değiştirilmez: onu bu ekiple imzalamak ikinci bir kopya yükler.",
    "SideInstaller remembers the pick for this Apple ID. To pick again, open Settings › Account, swipe the Apple ID left and tap Team.":
        "SideInstaller bu Apple kimliği için seçimi hatırlar. Yeniden seçmek için Ayarlar › Hesap'ı aç, Apple kimliğinde sola kaydır ve Ekip'e dokun.",
    "No developer team was picked, so the sign-in stopped.":
        "Hiçbir geliştirici ekibi seçilmedi, bu yüzden oturum açma durduruldu.",
    "Your Apple Account is on more than one developer team. Open SideInstaller and pick the one that signs.":
        "Apple Hesabın birden fazla geliştirici ekibinde. SideInstaller'ı aç ve imzalayacak ekibi seç.",
    "Pick the team again?": "Ekip yeniden seçilsin mi?",
    "Pick Again": "Yeniden seç",
    "The next sign-in with “%@” asks which developer team signs.":
        "“%@” ile bir sonraki oturum açmada hangi geliştirici ekibinin imzalayacağı sorulur.",
    // Shortcuts actions (ShortcutsSupport.swift and the *Shortcuts.swift files).
    "%@ can't be refreshed: SideInstaller has no IPA to sign it again from. Refresh it in whatever installed it, or import its .ipa into SideInstaller first.":
        "%@ yenilenemiyor: SideInstaller'da onu yeniden imzalayacak IPA yok. Onu yükleyen uygulamada yenile ya da önce .ipa dosyasını SideInstaller'a aktar.",
    "%@ is installed.":
        "%@ yüklendi.",
    "Apple is asking you to finish signing in. Continue in SideInstaller to answer it.":
        "Apple oturum açmayı bitirmeni istiyor. Yanıtlamak için SideInstaller'da devam et.",
    "LocalDevVPN is connected.":
        "LocalDevVPN bağlı.",
    "LocalDevVPN isn't connected. Connect it before this action runs: Shortcuts' Set VPN action can, or turn on “Start LocalDevVPN when needed” in SideInstaller's Settings.":
        "LocalDevVPN bağlı değil. Bu eylem çalışmadan önce bağla: Kestirmeler'deki VPN eylemi bunu yapabilir. Ya da SideInstaller'ın Ayarlar'ında “Gerektiğinde LocalDevVPN'i başlat”ı aç.",
    "LocalDevVPN isn't connected. Continue in SideInstaller to connect it.":
        "LocalDevVPN bağlı değil. Bağlamak için SideInstaller'da devam et.",
    "No route is playing.":
        "Oynatılan bir rota yok.",
    "Open SideInstaller and accept its terms first.":
        "Önce SideInstaller'ı aç ve koşullarını kabul et.",
    "Pick where the route starts, or set a location first.":
        "Rotanın nereden başlayacağını seç ya da önce bir konum ayarla.",
    "Route started: %@, about %@.":
        "Rota başladı: %@, yaklaşık %@.",
    "That place has no coordinates. Pick it on the map, or type its address.":
        "Bu yerin koordinatları yok. Haritada seç ya da adresini yaz.",
    "The install didn't start. Open SideInstaller to see why.":
        "Yükleme başlamadı. Nedenini görmek için SideInstaller'ı aç.",

    // MARK: - Sources

    "Suggested":
        "Önerilen",

    "Paste the link of a SideStore or AltStore source, or of a .json source file. Its apps, their updates and release notes show here.":
        "Bir SideStore veya AltStore kaynağının ya da bir .json kaynak dosyasının bağlantısını yapıştırın. Uygulamaları, güncellemeleri ve sürüm notları burada görünür.",
    "Add a source":
        "Kaynak ekle",
    "Updates":
        "Güncellemeler",
    "Update":
        "Güncelle",
    "Your sources":
        "Kaynaklarınız",
    "Check for updates":
        "Güncellemeleri denetle",
    "Copy link":
        "Bağlantıyı kopyala",
    "Source options":
        "Kaynak seçenekleri",
    "What's new":
        "Yenilikler",
    "Version history":
        "Sürüm geçmişi",
    "This version has no release notes.":
        "Bu sürümün sürüm notu yok.",
    "%d update":
        "%d güncelleme",
    "%d updates":
        "%d güncelleme",
    "%d updates · Total size: %@": "%d güncelleme · Toplam boyut: %@",
    "%d 个可更新": "%d güncelleme mevcut",
    "全部更新进行中，等它跑完再批量安装。":
        "Tüm uygulamalar güncelleniyor. Toplu kuruluma başlamadan önce bitmesini bekleyin.",
    "全部更新进行中，等它跑完再重装。":
        "Tüm uygulamalar güncelleniyor. Yeniden kurmadan önce bitmesini bekleyin.",
    "全部更新进行中，等它跑完再重试。":
        "Tüm uygulamalar güncelleniyor. Yeniden denemeden önce bitmesini bekleyin.",
    "An update-all batch is running. Wait for it to finish, then try again.":
        "Tüm uygulamalar güncelleniyor. Bitmesini bekleyin, sonra yeniden deneyin.",
    "全部更新进行中，等它跑完再更新。":
        "Tüm uygulamalar güncelleniyor. Güncellemeden önce bitmesini bekleyin.",
    "上次刷新失败：%@": "Son yenileme başarısız oldu: %@",
    "已停止更新：成功 %d 个，剩余 %d 个未更新。": "Güncelleme durduruldu: %d başarılı, %d kalan güncellenmedi.",
    "%d source":
        "%d kaynak",
    "%d sources":
        "%d kaynak",
    "Update to %@":
        "%@ sürümüne güncelle",
    "Install %@ %@?":
        "%@ %@ yüklensin mi?",
    "Version %@ · from %@":
        "Sürüm %@ · kaynak: %@",
    "%@ installed · %@ available":
        "%@ yüklü · %@ mevcut",
    "%@ installed · up to date":
        "%@ yüklü · güncel",
    "That source is already added.":
        "Bu kaynak zaten eklendi.",
    "The source answered with HTTP %d.":
        "Kaynak HTTP %d ile yanıt verdi.",
    "Couldn't reach the source: %@":
        "Kaynağa ulaşılamadı: %@",
    "That isn't a source link. Paste the whole https:// address of the source.":
        "Bu bir kaynak bağlantısı değil. Kaynağın https:// adresinin tamamını yapıştırın.",
    "That link didn't return a source. It has to be the source's JSON file itself.":
        "Bu bağlantı bir kaynak döndürmedi. Kaynağın JSON dosyasının kendisi olmalı.",
    "Downloads the IPA from the source, then signs it with your Apple ID and installs it, as a custom .ipa would be.":
        "IPA'yı kaynaktan indirir, ardından Apple Kimliğinizle imzalayıp yükler; özel bir .ipa gibi.",
    "This version is older than the newest one. It's installed over the copy on this iPhone, which may not open data a newer version saved.":
        "Bu sürüm en yenisinden daha eski. Bu iPhone'daki kopyanın üzerine yüklenir ve daha yeni bir sürümün kaydettiği verileri açamayabilir.",
    "This version is older than the one on this iPhone (%@). Installed over it, it may not open data the newer version saved.":
        "Bu sürüm, bu iPhone'daki sürümden (%@) daha eski. Üzerine yüklendiğinde, daha yeni sürümün kaydettiği verileri açamayabilir.",

    // MARK: - JIT

    "%@ has the JIT memory it asked for, so SideInstaller let go of it. JIT stays on until it quits.":
        "%@ istediği JIT belleğini aldı, bu yüzden SideInstaller ondan ayrıldı. JIT, uygulama kapanana kadar açık kalır.",
    "%@ of JIT memory prepared": "%@ JIT belleği hazırlandı",
    "%d app can use JIT": "%d uygulama JIT kullanabilir",
    "%d apps can use JIT": "%d uygulama JIT kullanabilir",
    "Attach and detach": "Bağlan ve ayrıl",
    "Attaching the debugger": "Hata ayıklayıcı bağlanıyor",
    "Auto: %@": "Otomatik: %@",
    "Connecting to this iPhone's debugger": "Bu iPhone'un hata ayıklayıcısına bağlanılıyor",
    "Couldn't open %@ under the debugger: %@": "%@ hata ayıklayıcıyla açılamadı: %@",
    "Couldn't reach the debugger on this iPhone: %@":
        "Bu iPhone'un hata ayıklayıcısına ulaşılamadı: %@",
    "Enable JIT": "JIT'i etkinleştir",
    "Continue JIT for %@": "%@ için JIT'e devam et",
    "JIT is on for %@ until it quits.": "%@ için JIT, uygulama kapanana kadar açık.",
    "JIT is on. SideInstaller stays attached while %@ runs: keep SideInstaller in the background, since closing it ends JIT.":
        "JIT açık. %@ çalışırken SideInstaller bağlı kalır: SideInstaller'ı arka planda bırak, çünkü kapatmak JIT'i sonlandırır.",
    "JIT needs Developer Mode. Turn it on under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.":
        "JIT için Geliştirici Modu gerekir. Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu'ndan aç ve yeniden başlatmadan sonra onayla.",
    "JIT on for %@": "%@ için JIT açık",
    "Legacy": "Eski",
    "No app on this iPhone is signed for development, which a debugger needs. Install the app with SideStore or SideInstaller, which sign apps that way, then load the apps again.":
        "Bu iPhone'da geliştirme için imzalanmış bir uygulama yok, oysa hata ayıklayıcı buna ihtiyaç duyar. Uygulamayı bu şekilde imzalayan SideStore veya SideInstaller ile yükle, ardından uygulamaları yeniden yükle.",
    "No apps can use JIT": "JIT kullanabilen uygulama yok",
    "Opening %@": "%@ açılıyor",
    "Quit %@": "%@ uygulamasından çık",
    "The debugger couldn't attach to %@ (%@). Install it again with SideStore or SideInstaller, which sign apps so a debugger can attach.":
        "Hata ayıklayıcı %@ uygulamasına bağlanamadı (%@). Uygulamaları hata ayıklayıcının bağlanabileceği şekilde imzalayan SideStore veya SideInstaller ile onu yeniden yükle.",
    "The debugger lost %@ (%@). Open it with JIT again.":
        "Hata ayıklayıcı %@ ile bağlantıyı kaybetti (%@). Onu yeniden JIT ile aç.",
    "Universal": "Evrensel",

    // MARK: - Batch install, history empty state & clear-downloads failures (0.9.151)

    "安装所选": "Seçilenleri yükle",
    "正在安装第 %d/%d 个：%@": "%d/%d yükleniyor: %@",
    "批量安装完成：%d 个已安装。": "Toplu yükleme tamamlandı: %d yüklendi.",
    "批量安装完成：成功 %d 个，失败 %d 个。失败：%@": "Toplu yükleme tamamlandı: %d başarılı, %d başarısız. Başarısız: %@",
    "等 %d 个": "ve %d tane daha",
    "其中 %d 个不是 IPA，已跳过。": "%d tanesi IPA değildi, atlandı.",
    "已有安装在进行，先等当前安装完成再批量安装。": "Zaten bir yükleme sürüyor. Toplu yüklemeden önce bitmesini bekleyin.",
    "正在签名，等它跑完再批量安装。": "İmzalama sürüyor. Toplu yüklemeden önce bitmesini bekleyin.",
    "Installed apps will be listed here.": "Yüklenen uygulamalar burada listelenir.",
    "以下 %d 个删除失败：%@": "Şu %d dosya silinemedi: %@",

    // MARK: - F1 source toggle, F2 source export/import & F3 download rename (0.9.152)

    "Enabled": "Etkin",
    "Names can't be empty, contain /, or start with .": "Adlar boş olamaz, / içeremez ve . ile başlayamaz",
    "Export sources": "Kaynakları dışa aktar",
    "Import sources": "Kaynakları içe aktar",
    "The clipboard has no source list to import.": "Panoda içe aktarılacak kaynak listesi yok.",
    "Imported %d, already added %d, failed %d.": "%d içe aktarıldı, %d zaten ekli, %d başarısız.",

    // MARK: - F3 update-all, F4 batch move & F5 log export (0.9.154)

    "全部更新": "Tümünü güncelle",
    "正在更新第 %d/%d 个：%@": "%d/%d güncelleniyor: %@",
    "正在读取已装 App…": "Yüklü uygulamalar okunuyor…",
    "全部更新完成：%d 个已更新。": "Tüm güncellemeler tamamlandı: %d güncellendi.",
    "全部更新完成：成功 %d 个，失败 %d 个。失败：%@": "Tüm güncellemeler tamamlandı: %d başarılı, %d başarısız. Başarısız: %@",
    "移动": "Taşı",
    "已移动 %d 个。": "%d taşındı.",
    "已移动 %d 个，失败 %d 个。失败：%@": "%d taşındı, %d başarısız. Başarısız: %@",
    "导出日志": "Günlüğü dışa aktar",

    // MARK: - F-C download speed/ETA & F-G Wi-Fi only downloads (0.9.156)

    "%@/s": "%@/s",
    "%@ left": "%@ kaldı",
    "Download over cellular?": "Hücresel veriyle indirilsin mi?",
    "Size: %@": "Boyut: %@",
    "Size unknown": "Boyut bilinmiyor",
    "You're on cellular data. This download will use your mobile data.": "Hücresel veri kullanıyorsunuz. Bu indirme, mobil verinizi kullanacak.",
    "Wi-Fi only downloads": "Yalnızca Wi-Fi ile indirme",
    "When on, a download over cellular data asks first, so a large IPA doesn't use your mobile data.": "Açıkken, hücresel veriyle indirme önce sorar; böylece büyük bir IPA mobil verinizi kullanmaz.",
    "Downloads": "İndirilenler",

    // MARK: - F-3 enterprise certificate expiry notice (0.9.157)

    "Enterprise certificate expiring": "Kurumsal sertifikanın süresi dolmak üzere",
    "The enterprise certificate expires on %@. Re-import it in time.": "Kurumsal sertifikanın süresi %@ tarihinde doluyor. Zamanında yeniden içe aktarın.",
    "The enterprise provisioning profile expires on %@. Re-import it in time.": "Kurumsal sağlama profilinin süresi %@ tarihinde doluyor. Zamanında yeniden içe aktarın.",

    // MARK: - 0.9.159: delete after install, downgrade check, dev-cert notice

    "Delete the IPA after installing": "Kurulumdan sonra IPA'yı sil",
    "Deletes the source IPA after a successful install. Files used for renewal are kept.": "Başarılı kurulumdan sonra kaynak IPA'yı siler. Yenileme için kullanılan dosyalar saklanır.",
    "Install an older version?": "Daha eski bir sürüm yüklensin mi?",
    "Installed: %@ · This IPA: %@": "Yüklü: %@ · Bu IPA: %@",
    "Couldn't read their iPhone's iOS version. Reconnect and try again — installing without it could put an app their iPhone can't run on it.": "Karşı tarafın iPhone'unun iOS sürümü okunamadı. Yeniden bağlanıp tekrar deneyin — sürümü bilmeden yüklemek, iPhone'larının çalıştıramayacağı bir uygulamayı yükleyebilir.",
    "Development certificate expiring": "Geliştirici sertifikasının süresi dolmak üzere",
    "The development certificate \"%@\" expires on %@. Renew it in time, or installs will fail.": "“%@” geliştirici sertifikası %@ tarihinde sona eriyor. Zamanında yenileyin, yoksa kurulumlar başarısız olur.",
    "This IPA asks for %@, which a free Apple ID certificate can't provide. Those features will silently stop working after install.": "Bu IPA %@ istiyor, ancak ücretsiz Apple ID sertifikası bunları sağlayamaz. Bu özellikler yüklemeden sonra sessizce çalışmayı durdurur.",
    "Before you install": "Yüklemeden önce",
    "Reinstall all": "Tümünü yeniden yükle",
    "Reinstall all finished: %d succeeded, %d failed, %d skipped.": "Toplu yeniden yükleme bitti: %d başarılı, %d başarısız, %d atlandı.",
    "Failed: %@": "Başarısız: %@",
    "Still getting ready. Try again in a moment.": "Hâlâ hazırlanıyor. Birazdan yeniden deneyin.",

    // MARK: - 0.9.161: uninstall, clean up old versions, last-checked, partial pairing write

    "Uninstall": "Kaldır",
    "Uninstall %@?": "%@ kaldırılsın mı?",
    "This removes %@ from this iPhone, including its data.": "Bu, %@ uygulamasını verileriyle birlikte bu iPhone'dan kaldırır.",
    "SideInstaller can't uninstall itself.": "SideInstaller kendisini kaldıramaz.",
    "Clean up old versions": "Eski sürümleri temizle",
    "Clean up %d old versions?": "%d eski sürüm temizlensin mi?",
    "Only the newest version of each app is kept. Deleted files can't be recovered.": "Her uygulamanın yalnızca en yeni sürümü tutulur. Silinen dosyalar kurtarılamaz.",
    "Cleaned up %d old versions.": "%d eski sürüm temizlendi.",
    "No old versions to clean up.": "Temizlenecek eski sürüm yok.",
    "%d files skipped (in use or needed for renewal).": "%d dosya atlandı (kullanımda veya yenileme için gerekli).",
    "%d files couldn't be deleted: %@": "%d dosya silinemedi: %@",
    "Checked just now": "Şimdi denetlendi",
    "Checked %d minutes ago": "%d dakika önce denetlendi",
    "Checked %d hours ago": "%d saat önce denetlendi",
    "Checked %d days ago": "%d gün önce denetlendi",
    "Pairing file installed into %@, but couldn't be written into %@.": "Eşleştirme dosyası %@ içine yüklendi, ancak %@ içine yazılamadı.",

    // 0.9.164
    "Loop route": "Rotayı döngüde oynat",
    "Newer than installed %@": "Yüklü %@ sürümünden daha yeni",
    "Older than installed %@": "Yüklü %@ sürümünden daha eski",
    "Same as installed %@": "Yüklü %@ ile aynı",
    "Show in Downloads": "İndirilenlerde göster",
    "Still installing — check the Install page for progress.": "Hâlâ yükleniyor — ilerlemeyi Yükleme sayfasından kontrol edin.",
    "Installing — tap to cancel": "Yükleniyor — iptal için dokunun",

    // 0.9.166
    "All": "Tümü",
    "Succeeded": "Başarılı",
    "Restore real location when done": "Bitince gerçek konumu geri yükle",
    "Import a .gpx file and the device moves along it at the speed you pick. When it ends, the device stays at its last point, unless restoring the real location when done is on.": ".gpx dosyası içe aktar; cihaz seçtiğin hızda rota boyunca hareket eder. Bitince son noktada kalır, ancak bitince gerçek konumu geri yükleme açıksa gerçek konumuna döner.",
    "移动“%@”？": "\"%@\" taşınsın mı?",
    "This is the IPA on the Install tab. Moving it empties that slot — install it from its new folder instead.": "Bu, Yükle sekmesindeki IPA'dır. Taşımak o yuvayı boşaltır — bunun yerine yeni klasöründen yükleyin.",
    "Move": "Taşı",
    "其中 %d 个因拒绝降级而跳过。": "%d tanesi düşürmeyi reddettiği için atlandı.",

    // 0.9.167
    "Folder": "Klasör",
    "Export history": "Geçmişi dışa aktar",
    "No files match the current filter.": "Geçerli filtreyle eşleşen dosya yok.",

]
