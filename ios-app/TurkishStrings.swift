import Foundation

/// Turkish translations, keyed by the English string passed to `L(_:)`. Missing
/// keys fall back to English. Keep `%@`/`%d` placeholders, and leave product and
/// third-party UI names in English.

let turkishStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "İptal",
    "Copy": "Kopyala",
    "Copy logs": "Günlükleri kopyala",
    "Email": "E-posta",
    "Password": "Parola",
    "Install": "Yükle",
    "Installing": "Yükleniyor",
    "Cancelling": "İptal ediliyor",
    "Installed": "Yüklendi",
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
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "Bu iPhone'un anahtar zincirinde saklanır ve yalnızca oturum açılırken Apple'a gönderilir. Parolasını düzenlemek veya silmek için bir satırı kaydır.",
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
    "Submit": "Gönder",
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
    "From the website": "Web sitesinden",
    "Sign it with your Apple ID": "Apple kimliğinle imzala",
    "Install it in LiveContainer": "LiveContainer'a yükle",
    "LiveContainer isn't installed on this iPhone.": "Bu iPhone'da LiveContainer yüklü değil.",
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
    "iOS %@ required": "iOS %@ gerekli",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Bu iPhone iOS %@ çalıştırıyor; SideInstaller buna yükleme yapamaz. Ayarlar › Genel › Yazılım Güncelleme'den iOS %@ veya sonrasına güncelle.",
    "Wi-Fi required": "Wi-Fi gerekli",
    "Pairing code": "Eşleme kodu",
    "Type this into the prompt in Settings.": "Bunu Ayarlar'daki istem alanına yaz.",
    "Install stopped": "Yükleme durdu",
    "Close": "Kapat",
    "Yes": "Evet",
    "No": "No",
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
    "Sign the app": "Uygulamayı imzala",
    "Finish setup": "Kurulumu bitir",
    // MARK: - Pairing tab

    "Pairing file ready": "Eşleme dosyası hazır",
    "No pairing file": "Eşleme dosyası yok",
    "Pairing file": "Eşleme dosyası",
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

    "This certificate has no serial number, so it can't be exported.":
        "Bu sertifikanın seri numarası yok, bu yüzden dışa aktarılamaz.",
    "Only the certificate SideInstaller signs with can be exported: the private key of any other stays on the device that asked Apple for it.":
        "Yalnızca SideInstaller'ın imzaladığı sertifika dışa aktarılabilir: diğerlerinin özel anahtarı, Apple'dan onu isteyen cihazda kalır.",
    "Couldn't export the certificate: %@": "Sertifika dışa aktarılamadı: %@",
    "Export certificate": "Sertifikayı dışa aktar",
    "Password (optional)": "Parola (isteğe bağlı)",
    "Export": "Dışa aktar",
    "Exporting": "Dışa aktarılıyor",
    "Saves this certificate and its private key as a .p12 file, for another signing app or a computer to sign with. Choose a password, which you'll need to import the file, or leave it empty: signing apps import it without one, but a Mac won't. Keep the file to yourself.":
        "Bu sertifikayı ve özel anahtarını .p12 dosyası olarak kaydeder; başka bir imzalama uygulaması veya bilgisayar bununla imzalayabilir. Dosyayı içe aktarmak için gerekecek bir parola seç veya boş bırak: imzalama uygulamaları parolasız içe aktarır, Mac ise aktarmaz. Dosyayı kendine sakla.",
    "SideInstaller can export only the certificate it signs with, and none of these is it: a certificate's private key stays on the device that asked Apple for it.":
        "SideInstaller yalnızca imzaladığı sertifikayı dışa aktarabilir ve bunların hiçbiri o değil: bir sertifikanın özel anahtarı, Apple'dan onu isteyen cihazda kalır.",
    "SideInstaller signs with this one": "SideInstaller bununla imzalıyor",
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
        "LiveContainer içinde SideStore sertifikasını SideInstaller'a geri gönderemez ve LiveContainer henüz bir tane tutmuyor. LiveContainer Ayarları'nda “SideStore'dan Sertifika İçe Aktar”a dokun (sertifikası yoksa önce SideStore'da oturum aç), sonra burada yeniden dene.",
    "The certificate LiveContainer holds for SideStore isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID. Nothing was changed. If SideStore has made a new one since, tap “Refresh Certificate from SideStore” in LiveContainer's Settings, then try again here.":
        "LiveContainer'ın SideStore için tuttuğu sertifika bu Apple kimliğine ait değil: iptal edilmiş veya başka bir kimliğe ait. Hiçbir şey değişmedi. SideStore o zamandan beri yeni bir tane oluşturduysa LiveContainer Ayarları'nda “SideStore'dan Sertifikayı Yenile”ye dokun, sonra burada yeniden dene.",
    "SideInstaller takes SideStore's certificate from LiveContainer and signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "SideInstaller, SideStore'un sertifikasını LiveContainer'dan alır ve onunla da imzalar; böylece ücretsiz bir Apple kimliğinde iki uygulama birbirininkini iptal etmek zorunda kalmaz.",
    "Sign with this certificate?": "Bu sertifika ile imzalansın mı?",
    "A link sent SideInstaller a signing certificate. Only use it if you asked for one: SideInstaller will sign apps with it from now on, in place of its own. It's used only if it's one of your Apple ID's certificates.":
        "Bir bağlantı SideInstaller'a bir imzalama sertifikası gönderdi. Yalnızca sen istediysen kullan: SideInstaller bundan sonra kendi sertifikası yerine bununla uygulamaları imzalayacak. Yalnızca Apple kimliğinin sertifikalarından biri ise kullanılır.",
    "Use it": "Kullan",
    "That link was meant to carry a signing certificate, but what it holds can't be read.":
        "Bu bağlantı bir imzalama sertifikası taşıyacaktı, ancak içeriği okunamıyor.",
    // MARK: - Export certificate (sideinstaller://exportCertificate)

    "Export signing certificate?": "İmzalama sertifikası dışa aktarılsın mı?",
    "Another app (for example LiveContainer) asked SideInstaller to export the certificate it currently signs with. Only continue if you started that request. SideInstaller will send the certificate back; if it has none, it will say so.":
        "Başka bir uygulama (örneğin LiveContainer) SideInstaller'dan şu anda imzaladığı sertifikayı dışa aktarmasını istedi. Yalnızca bu isteği sen başlattıysan devam et. SideInstaller sertifikayı geri gönderecek; yoksa bunu bildirecek.",
    "Export and send": "Dışa aktar ve gönder",
    "That export link is missing a usable callback_template with $(BASE64_CERT).":
        "Bu dışa aktarma bağlantısında $(BASE64_CERT) içeren kullanılabilir bir callback_template yok.",
    "SideInstaller has no signing certificate. Sign in and install an app (or import a certificate) first, then try again.":
        "SideInstaller'ın imzalama sertifikası yok. Önce oturum açıp bir uygulama yükle (veya bir sertifika içe aktar), sonra yeniden dene.",
    "Certificate sent to the other app.": "Sertifika diğer uygulamaya gönderildi.",
    "Couldn't open the other app to deliver the certificate. Is it still installed?":
        "Sertifikayı iletmek için diğer uygulama açılamadı. Hâlâ yüklü mü?",
    "Couldn't build the callback URL to send the certificate.":
        "Sertifikayı göndermek için geri çağırma bağlantısı oluşturulamadı.",
    "No Apple ID saved, so SideInstaller has no signing certificate to export. Add one in Settings › Account, or install an app first so a certificate is created.":
        "Kayıtlı Apple kimliği yok, bu yüzden SideInstaller'ın dışa aktaracak imzalama sertifikası yok. Ayarlar › Hesap bölümünden bir tane ekle veya önce bir uygulama yükleyerek sertifika oluştur.",
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
    "Couldn't build the download URL for %@.": "%@ için indirme adresi oluşturulamadı.",
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
        "Hız sınırlarının %%%d'i haritalanmış; geri kalanı tahmin.",
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
    "The route server couldn't plan this route (%@).": "Rota sunucusu bu rotayı planlayamadı (%@).",
    // MARK: - Entitlements tab

    "Entitlements": "Entitlements",
    "Load apps": "Uygulamaları yükle",
    "%d App ID": "%d App ID",
    "%d App IDs": "%d App IDs",
    "No App IDs": "App ID yok",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "Bu Apple kimliği henüz hiç uygulama kaydetmemiş. Önce SideInstaller ile bir şey yükle, sonra dön.",
    "Memory and performance": "Bellek ve performans",
    "Other free capabilities": "Diğer ücretsiz yetenekler",
    "Recommended": "Önerilen",
    "Select all": "Tümünü seç",
    "None": "Hiçbiri",
    "Enable %d selected": "Seçilen %d'yi etkinleştir",
    "Asking Apple": "Apple'a soruluyor",
    "%d of %d enabled": "%d / %d etkin",
    "Install the app again for these to take effect.": "Bunların geçerli olması için uygulamayı yeniden yükle.",
    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "Yan yüklenen uygulamalar",
    "Reading the device": "Cihaz okunuyor",
    // Refresh all: signing the installed apps again.

    "iOS %@ isn't supported — SideInstaller needs iOS %@ or later.":
        "iOS %@ desteklenmiyor — SideInstaller iOS %@ veya sonrasını ister.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Under Tools › Certificates, use SideStore's certificate or revoke that one, then refresh again.":
        "Uygulamale yapmayacak issue imzalamsertifikiçin bu Uygulamale kimliği: it repveyats şu one already exists (hat7460). Under Tools › Sertifikas, use SideStveyae's sertifikveyiptal et şu one, sonryenile yeniden.",
    "An install is already running. Wait for it to finish, then refresh.":
        "Bir yükleme zaten sürüyor. Bitmesini bekle, sonra yenile.",
    "Getting ready": "Hazırlanıyor",
    "Stopping after this app": "Bu uygulamadan sonra duruluyor",
    "Refreshing %@": "%@ yenileniyor",
    "Signed by team %@, not the one you're signed in as — refreshing it here would install a second copy.":
        "%@ ekibi tarafından imzalanmış, oturum açtığın ekip değil — burada yenilemek ikinci bir kopya yükler.",
    "Refreshed. Its seven days start again now.": "Yenilendi. Yedi günü şimdi yeniden başlar.",
    "Nothing was refreshed.": "Hiçbir şey yenilenmedi.",
    "Refreshed %d of %d apps.": "%d / %d uygulama yenilendi.",
    "Refresh all apps?": "Tüm uygulamalar yenilensin mi?",
    "Refresh all": "Yenile all",
    "%@ will be signed again with your Apple ID and installed over the copy on this device. It keeps its data, and its seven days start over.":
        "%@ will be imzalveı yeniden ile senin Uygulamale kimliği ve yükleed over copy on bu cihaz. It keeps its data, ve its seven days start over.",
    "%d apps will be signed again with your Apple ID and installed over the copies on this device. They keep their data, and their seven days start over.":
        "%d uygulamas will be imzalveı yeniden ile senin Uygulamale kimliği ve yükleed over copies on bu cihaz. y keep ir data, ve ir seven days start over.",
    "%d app can be signed again from an IPA already on this iPhone.":
        "%d uygulamcbe imzalveı yeniden şuradIPalready on bu iPhone.",
    "%d apps can be signed again from IPAs already on this iPhone.":
        "%d uygulamas cbe imzalveı yeniden şuradIPAs already on bu iPhone.",
    "Reload": "Yeniden yükle",
    "Waiting": "Bekleing",
    "In progress": "Devam ediyor",
    "Failed": "Başarısız",
    "%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.":
        "%d uygulamburadhas no IPin SideYükleer, so it yapılamaz be yenileed şuradbu page. Yenile it in whatever yükleed it, veyiçe aktar its .ipönce.",
    "%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.":
        "%d uygulamas buradhave no IPin SideYükleer, so y yapılamaz be yenileed şuradbu page. Yenile m in whatever yükleed m, veyiçe aktar ir .ipönce.",
    "%d app": "%d app",
    "%d apps": "%d apps",
    "%d app needs refreshing": "%d uygulamneeds yenileing",
    "%d apps need refreshing": "%d uygulamas need yenileing",
    "No sideloaded apps": "No sideloaded uygulamas",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Nothing on bu cihaz was yükleed ile provisioning prodosya. UygulamStveyae uygulamas yapmexpire, so y aren't listed burada.",
    "No matching profile": "No matching prodosya",
    "Expires today": "Bugün doluyor",
    "Expires tomorrow": "Expires tomveyarow",
    "Expires in %d days — %@": "%d gün içinde doluyor — %@",
    "Expired %@": "Süresi doldu %@",
    "Unused profiles": "Unused prodosyas",
    "Issued to App IDs no installed app is running on.": "Issued to UygulamIDs no yükleed uygulamis running on.",
    "Older profiles": "Older prodosyas",
    "Bundle identifier": "Paket tanımlayıcı",
    "App ID": "App ID",
    "Version": "Sürüm",
    "Profile name": "Prodosyname",
    "Team": "Team",
    "Team ID": "Takım kimliği",
    "Issued": "Verildi",
    "Profile UUID": "ProdosyUUID",
    "Capabilities": "Yetenekler",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "Wildcard UygulamID — it covers any bundle id under it, ve yapılamaz carry uygulama-specific capabilities.",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "cihaz has no provisioning prodosyiçin bu UygulamID. uygulammay already have durakped launching — yükle it yeniden to fix şu.",
    // MARK: - Side by Side tool

    // The tool's name is left in English everywhere, as SideStore's is.

    "Side by Side": "Yan yana",
    "Pair with their iPhone": "Pair ile ir iPhone",
    "Sign in to their Apple ID": "Sign in to ir Uygulamale kimliği",
    "Download SideInstaller": "İndir SideYükleer",
    "Install on their iPhone": "Yükle on ir iPhone",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” değil IPv4 ekleress. It should look like 192.168.1.42.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ is ekleress bu iPhone already holds. Side by Side yükles onto someone else's iPhone — use irs. To yükle on bu one, use Yükle tab.",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "iPhone şu paired was bu one. Pair şuradir iPhone's Ayarlar instead. To yükle on bu iPhone, use Yükle tab.",
    "Enter the Apple ID to sign with, and its password.": "Enter Uygulamale kimliği to sign ile, ve its parola.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Wi-Fi is off. Both iPhones have to be on same Wi-Fi ağ için bu to wveyak.",
    "The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute.":
        "release indir değildi IPA. GitHub may be returning hatpage — yeniden dene in minute.",
    "Couldn't download the latest SideInstaller release: %@": "Yapılamadı indir latest SideYükleer release: %@",
    "No SideInstaller IPA downloaded.": "No SideYükleer IPindired.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise.":
        "Uygulamale yapmayacak issue imzalamsertifikiçin bu Uygulamale kimliği: it repveyats şu one already exists (hat7460). One has to be iptal etd önce — ile Sertifikas tool if bu is Uygulamale kimliği kaydetd in Ayarlar › Account, ve at developer.uygulamale.com imzalveı in as it orwise.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Uygulamale wouldn't register ir iPhone ile bu Uygulamale kimliği's developer team, so it yapmayacak issue provisioning prodosya. %@",
    "No pair record for their iPhone.": "No pair recveyad için ir iPhone.",
    "The link to their iPhone dropped — start again.": "bağlantı to ir iPhone dropped — start yeniden.",
    "Set up someone else's iPhone": "Başkasının iPhone'unu kur",
    "Same Wi-Fi network": "Same Wi-Fi ağ",
    "Their iPhone needs iOS %@ — SideInstaller pairs itself once it's installed, and nothing older can.":
        "ir iPhone needs iOS %@ — SideYükleer pairs itself once bu yükleed, ve nothing older can.",
    "Their iPhone": "ir iPhone",
    "IP address (optional)": "IP ekleress (optional)",
    "Optional: leave it empty, and it fills in when their iPhone pairs.":
        "Optional: leave it empty, ve it fills in when ir iPhone pairs.",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "On ir iPhone: Ayarlar › Wi-Fi › ⓘ next to ağ, sonr“IP Ekleress”.",
    "This iPhone is %@, so theirs will look similar.": "Bu iPhone is %@, so irs will look similar.",
    "Apple ID to sign with": "Uygulamale kimliği to sign ile",
    "Tip: Use the iPhone/iPad owner's Apple account credentials": "Tip: Use iPhone/iPad owner's Uygulamale account credentials",
    "Use my saved Apple ID instead": "Use my kaydetd Uygulamale kimliği instead",
    "Steps": "Adımlar",
    "Waiting for them to tap Trust…": "Bekleing için m to tap Trust…",
    "Waiting for them to pair in Settings…": "Bekleing için m to pair in Ayarlar…",
    "Waiting for them to enter the code…": "Bekleing için m to enter code…",
    "Pair their iPhone in Settings": "Pair ir iPhone in Ayarlar",
    "Their iPhone won't ask by itself — pairing starts from its Settings.":
        "ir iPhone yapmayacak ask by itself — eşleme starts şuradits Ayarlar.",
    "On their iPhone, open Settings › Privacy & Security › Developer Mode.":
        "On ir iPhone, aç Ayarlar › Privacy & Security › Developer Mode.",
    "Tap “Pair with %@”.": "Tap “Pair ile %@”.",
    "Enter their iPhone’s passcode if it asks for it.": "Enter ir iPhone’s passcode if it asks için it.",
    "Type the code that appears here into the prompt on their iPhone.":
        "Type code şu uygulamaears buradinto prompt on ir iPhone.",
    "Type this into the prompt on their iPhone.": "Type bu into prompt on ir iPhone.",
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "y tuygulamaed “YapmTrust” on ir iPhone. Start yeniden, ve have m tap Trust.",
    "SideInstaller is already waiting for an iPhone to pair with it — from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "SideYükleer is already bekleing için iPhone to pair ile it — şurad Yükle tab, Eşleme page, veyearlier attempt burada. Bitir şu eşleme, veykapat ve reaç SideYükleer, sonryeniden dene.",
    "Pairing with their iPhone didn't finish: %@": "Eşleme ile ir iPhone yapmadı bitir: %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "ir iPhone at %@ refused bağlantı. It only accepts one while Developer Mode is on, ve iOS asks to confirm Developer Mode yeniden after every restart: on ir iPhone, turn it on under Ayarlar › Privacy & Security › Developer Mode, sonryeniden dene.",
    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Yapılamadı reach ir iPhone at %@. Check ekleress (Ayarlar › Wi-Fi › ⓘ on ir iPhone), şu both iPhones are on same Wi-Fi ağ, ve şu Local Ağ is on için SideYükleer in bu iPhone's Ayarlar. Guest ve public ağs often keep cihazs şuradreaching each or.",
    "The link to their iPhone didn't come up: %@": "bağlantı to ir iPhone yapmadı come up: %@",
    "%d%% downloaded": "%d%% indired",
    "%d%% uploaded": "%%%d yüklendi",
    "Start the install": "Start yükle",
    "Install again": "Yükle yeniden",
    "Clear their details": "Clear ir details",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "Bu iPhone is still paired ile irs. Clearing içingets it.",
    "Last step: they trust %@": "Last step: y trust %@",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "On ir iPhone: Ayarlar › General › VPN & Cihaz Management.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "Tap Uygulamale kimliği under “Developer Uygulama”, sonrtap Trust.",
    "Open it from their Home Screen — they're set up.": "Aç it şuradir Home Screen — y're set up.",
    // MARK: - Settings

    "Settings": "Ayarlar",
    "Done": "Tamam",
    "Language": "Dil",
    "App language": "Uygulamlanguage",
    "Sounds": "Sesler",
    "Sound effects": "Ses efektleri",
    "Auto": "Otomatik",
    // The Tunnel section: starting LocalDevVPN from here.

    "Tunnel": "Tunnel",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.":
        "Something at %@:%d refused bağlantı, so tunnel is carrying traffic — cihaz just değil listening on its eşleme pveyat. Şu pveyat only açs while Developer Mode is on, ve iOS asks için it yeniden after every restart: turn it on under Ayarlar › Privacy & Security › Developer Mode, sonryeniden dene. If bu already on, pair bu iPhone yeniden under “Eşleme dosyası”.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port: Developer Mode is off. Turn it on under Settings › Privacy & Security › Developer Mode (the iPhone restarts), then try again.":
        "Something at %@:%d refused bağlantı, so tunnel is carrying traffic, but bu iPhone değil listening on its eşleme pveyat: Developer Mode is off. Turn it on under Ayarlar › Privacy & Security › Developer Mode ( iPhone restarts), sonryeniden dene.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port, although Developer Mode is on. Pair this iPhone again under “Pairing file”, then try again. If it still fails, restart the iPhone.":
        "Something at %@:%d refused bağlantı, so tunnel is carrying traffic, but bu iPhone değil listening on its eşleme pveyat, although Developer Mode is on. Pair bu iPhone yeniden under “Eşleme dosyası”, sonryeniden dene. If it still fails, restart iPhone.",
    "Start LocalDevVPN when needed": "Gerektiğinde LocalDevVPN'i başlat",
    "Start LocalDevVPN now": "LocalDevVPN'i şimdi başlat",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "LocalDevVPN değil yükleed. Get it şurad UygulamStveyae, ve bu cstart it için you.",
    "Downloaded IPAs": "İndired IPAs",
    "%@ used": "%@ kullanıldı",
    "imported": "içe aktared",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "No indired IPAs. Ones you yükle şurad Yükle tab are cached burada.",
    "Downloaded %@": "İndired %@",
    "Added %@": "Ekleed %@",
    "Delete this download?": "Sil bu indir?",
    "Delete": "Sil",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "“%@” (%@) will be kaldırd. You cindir it yeniden any time şurad Yükle tab.",
    "Couldn't delete %@: %@": "Yapılamadı sil %@: %@",
    "Server": "Sunucu",
    "Custom…": "Özel…",
    "Server URL": "Sunucu URL",
    "Anisette Server": "Anisette Sunucu",
    "Starts with %@": "Starts ile %@",
    "Auto starts with the server that signed in last, then tries the others, the ones most likely to work first.":
        "Auto starts ile sunucu şu imzalveı in last, sonrtries ors, ones most likely to wveyak önce.",
    "Only this server is tried. If it fails, so does sign-in: choose Auto to have SideInstaller try the others.":
        "Only bu sunucu is tried. If it fails, so does sign-in: seç Auto to have SideYükleer try ors.",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "Only sunucu picked in Ayarlar › Anisette Sunucu was tried. Seç Auto tburadto let SideYükleer try ors when one fails.",
    "Device IP": "Cihaz IP",
    "Advanced": "Gelişmiş",
    "Clear": "Temizle",
    "Activity Log (%d)": "Etkinlik günlüğü (%d)",
    // Settings › Developer Mode: AMFI requests over the device link.

    "Developer Mode": "Geliştirici Modu",
    "Show Developer Mode in Settings": "Ayarlar'da Geliştirici Modu'nu göster",
    "Turn on Developer Mode": "Geliştirici Modu'nu aç",
    "Asking this iPhone…": "Asking bu iPhone…",
    "Both need a link to this iPhone that already works: LocalDevVPN plus a pairing file, such as one imported on iOS 17.4 to 26. On iOS 27 the link itself needs Developer Mode, so they can't bring back a missing option there.":
        "Both need bağlantı to bu iPhone şu already wveyaks: LocalDevVPN plus eşleme dosyası, such as one içe aktared on iOS 17.4 to 26. On iOS 27 bağlantı itself needs Developer Mode, so y yapılamaz bring back missing option tburada.",
    "Turn on Developer Mode?": "Geliştirici Modu açılsın mı?",
    "Turn On and Restart": "Turn On ve Restart",
    "This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode.":
        "Bu iPhone restarts right away. Once you unlock it, tap Turn On in alert şu uygulamaears. iOS allows bu only while iPhone has no passcode.",
    "Developer Mode is already on.": "Geliştirici Modu zaten açık.",
    "Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.":
        "Developer Mode now shows under Ayarlar › Privacy & Security, near bottom. Turn it on tburada, ve iOS restarts to bitir.",
    "Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.":
        "Developer Mode is set to turn on, ve bu iPhone restarts now. Once you unlock it, tap Turn On.",
    "An install is already running. Wait for it to finish, then try again.":
        "Bir yükleme zaten sürüyor. Bitmesini bekle, sonra yeniden dene.",
    "iOS turns Developer Mode on from here only while this iPhone has no passcode. Tap “Show Developer Mode in Settings” and turn it on there instead.":
        "iOS turns Developer Mode on şuradburadonly while bu iPhone has no passcode. Tap “Show Developer Mode in Ayarlar” ve turn it on tburadinstead.",
    "This iPhone didn't take the Developer Mode request: %@": "Bu iPhone yapmadı take Developer Mode request: %@",
    // MARK: - Release channels & downloads

    "Stable": "Stable",
    "Nightly": "Nightly",
    // Version picker (Advanced)

    "%@ version": "%@ sürümü",
    "Latest": "En son",
    "Latest (%@)": "En son (%@)",
    "Couldn't load the other versions: %@": "Diğer sürümler yüklenemedi: %@",
    "Try again": "Yeniden dene",
    "couldn't find the IPA in the %@ %@ release": "yapılamadı find IPin %@ %@ release",
    "%@ has no %@ release right now": "%@ şu anda %@ sürümüne sahip değil",
    "bad asset URL": "geçersiz varlık adresi",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub is rate-limiting bu ağ — it değil blocked, ve limit clears itself. Yeniden dene %@.",
    "GitHub answered HTTP %d%@": "GitHub HTTP %d%@ yanıtladı",
    "GitHub isn't serving %@ right now — the repository has been taken down, moved or made private, so there's nothing to download. Nothing is wrong with this iPhone or its network.":
        "GitHub değil serving %@ right now — repositveyay has been taken down, moved veymade private, so var nothing to indir. Nothing is wrong ile bu iPhone veyits ağ.",
    "couldn't reach GitHub: %@": "yapılamadı reach GitHub: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "GitHub's answer değildi release iniçinmation (%@) — something on bu ağ may have replaced it.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "what indired as %@ değil IP— something on bu ağ returned page instead, vey transfer durakped partway.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "şu bağlantı answered HTTP %d — it değil direct indir, veyit needs sign-in.",
    "GitHub has no build of %@'s %@ branch to download right now.": "GitHub has no build of %@'s %@ branch to indir right now.",
    "couldn't download %@ through nightly.link, which passes on GitHub's builds: %@":
        "yapılamadı indir %@ through nightly.bağlantı, which passes on GitHub's builds: %@",
    "the %@ build that arrived isn't the file GitHub recorded, so it isn't installed. Try again later.":
        "%@ build şu arrived değil dosyGitHub recveyaded, so it değil yükleed. Yeniden dene later.",
    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "İki adımlı doğrulama iptal edildi.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Yanlış Apple kimliği veya parola. Apple Hesabı e-posta ve parolanı kontrol et, sonra yeniden dene.",
    "Apple ID sign-in failed on %@. Error: %@": "Uygulamale kimliği sign-in başarısız on %@. Hata: %@",
    "Apple ID sign-in failed on %@. Error via %@: %@": "Uygulamale kimliği sign-in başarısız on %@. Hatvi%@: %@",
    "Apple's sign-in server refused the request (HTTP 503). It isn't your password or the anisette server, so trying more servers won't help. Try again later, or update SideInstaller.":
        "Uygulamale's sign-in sunucu refused request (HTTP 503). It değil senin parolvey anisette sunucu, so trying mveyae sunucus yapmayacak help. Yeniden dene later, veyupdate SideYükleer.",
    "“%@” makes its anisette data with Apple's Android library, and Apple now refuses to finish signing in through those servers (error -80046), after your password and code. In Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "“%@” makes its anisette datile Uygulamale's Veroid library, ve Uygulamale now refuses to bitir imzalamin through those sunucus (hat-80046), after senin parolve code. In Ayarlar › Anisette Sunucu, seç Auto veyMac sunucu such as “SideStveyae (New)”.",
    "Apple refused to finish signing in (error -80046), even through a Mac anisette server, the kind it still accepted. Try again later, or check for a SideInstaller update.":
        "Uygulamale refused to bitir imzalamin (hat-80046), even through Mac anisette sunucu, kind it still accepted. Yeniden dene later, veycheck için SideYükleer update.",
    "Apple refused to finish signing in through “%@” (error -80046). It now only accepts sign-ins through anisette servers on its macOS library: in Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "Uygulamale refused to bitir imzalamin through “%@” (hat-80046). It now only accepts sign-ins through anisette sunucus on its macOS library: in Ayarlar › Anisette Sunucu, seç Auto veyMac sunucu such as “SideStveyae (New)”.",
    "Apple won't send a code by text or call to this sign-in, so it was sent to your Apple devices.":
        "Uygulamale yapmayacak send code by text veycall to bu sign-in, so it was sent to senin Uygulamale cihazs.",
    "Apple didn't confirm sending a code to your Apple devices. If one arrived, enter it; if not, try another way.":
        "Uygulamale yapmadı confirm sending code to senin Uygulamale cihazs. If one arrived, enter it; if not, try anor way.",
    "SideInstaller can't reach Apple's sign-in server (gsa.apple.com), though this iPhone has an internet connection. Something is blocking it: a firewall, a DNS filter or ad blocker, Screen Time content restrictions, or another VPN app. Turn it off or try another network, then try again.":
        "SideYükleer yapılamaz reach Uygulamale's sign-in sunucu (gsa.uygulamale.com), though bu iPhone has internet bağlantı. Something is blocking it: firewall, DNS filter veyad blocker, Screen Time content restrictions, veyanor VPN uygulama. Turn it off veytry anor ağ, sonryeniden dene.",
    "SideInstaller can't reach Apple: Cellular Data is turned off for it. Turn SideInstaller on in Settings › Cellular, or join a Wi-Fi network with internet access, then try again.":
        "SideYükleer yapılamaz reach Uygulamale: Cellular Datis turned off için it. Turn SideYükleer on in Ayarlar › Cellular, veyjoin Wi-Fi ağ ile internet access, sonryeniden dene.",
    "SideInstaller can't reach Apple: iOS isn't letting it use Wi-Fi. In Settings › Apps › SideInstaller › Wireless Data, choose WLAN & Cellular Data, then try again.":
        "SideYükleer yapılamaz reach Uygulamale: iOS değil letting it use Wi-Fi. In Ayarlar › Uygulamas › SideYükleer › Wireless Data, seç WLAN & Cellular Data, sonryeniden dene.",
    "SideInstaller can't reach Apple: a VPN set to carry all traffic is disconnected, so iOS is holding traffic back. Reconnect it, or turn off its kill switch or Connect On Demand, then try again.":
        "SideYükleer yapılamaz reach Uygulamale: VPN set to carry all traffic is disbağlı, so iOS is holding traffic back. Reconnect it, veyturn off its kill switch veyConnect On Demve, sonryeniden dene.",
    "SideInstaller can't reach Apple: this iPhone has no internet connection. Connect to Wi-Fi or turn on cellular data, then try again.":
        "SideYükleer yapılamaz reach Uygulamale: bu iPhone has no internet bağlantı. Connect to Wi-Fi veyturn on cellular data, sonryeniden dene.",
    "Apple is temporarily limiting sign-ins for this Apple ID or network (HTTP 429). Trying other servers won't help, and every attempt can extend the wait, so leave it a while before signing in again.":
        "Uygulamale is tempveyaarily limiting sign-ins için bu Uygulamale kimliği veyağ (HTTP 429). Trying or sunucus yapmayacak help, ve every attempt cextend bekle, so leave it while beiçine imzalamin yeniden.",
    "If you're sure the password is right, Apple may be limiting sign-in attempts: wait a while before trying again.":
        "If sen sure parolis right, Uygulamale may be limiting sign-in attempts: bekle while beiçine trying yeniden.",
    "Apple has locked this Apple Account for security reasons (error -20209), so every sign-in fails until it's unlocked. Reset its password at iforgot.apple.com, then sign in again with the new password.":
        "Uygulamale has locked bu Uygulamale Account için security reasons (hat-20209), so every sign-in fails until bu unlocked. Reset its parolat iiçingot.uygulamale.com, sonrsign in yeniden ile new parola.",
    "the anisette server": "anisette sunucu",
    "all %d anisette servers": "all %d anisette sunucus",
    "%d anisette servers (%d skipped)": "%d anisette sunucus (%d skipped)",
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
    "%@ isn't installed yet — install must run first.": "%@ değil yükleed yet — yükle must run önce.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ değil valid IP— indir it came şuradprobably returned hatpage, vey copy durakped partway. Replace it ve tap Yükle yeniden.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ değil IPA. Pick .ipdosyitself — if it looks right, indir may have kaydetd hatpage instead, veydurakped partway.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.": "No IPiçe aktared yet. Tap “İçe aktar .ipa” ve pick one.",
    "Couldn't import %@: %@": "Yapılamadı içe aktar %@: %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "Şu değil bağlantı SideYükleer cindir. Paste whole https:// ekleress .ipindirs şuradan.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "Şu bağlantı yapmadı return IPA. It has to indir dosyitself — page şu only bağlantıs to .ipa, veyone şu asks you to sign in önce, arrives buradas web page.",
    "Couldn't download that link: %@": "Yapılamadı indir şu bağlantı: %@",
    "there's nothing to download for a custom IPA — import one first":
        "var nothing to indir için custom IP— içe aktar one önce",
    "your app": "senin uygulama",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Uygulamale yapmayacak issue imzalamsertifikiçin bu Uygulamale kimliği: it repveyats şu one already exists, veyşu request için one is still pending (hat7460). SideYükleer yapılamadı reuse sertifikbu already tburada, so it durakped instead of replacing it. See steps above.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Yapılamadı register bu iPhone%@ ile senin Uygulamale kimliği's developer team, so Uygulamale yapmayacak issue provisioning prodosya. %@ — see steps above.",
    "Connect to Wi-Fi": "Wi-Fi'ye bağlan",
    "Open Settings › Wi-Fi and join a network.": "Aç Ayarlar › Wi-Fi ve join ağ.",
    "Then come back here — this continues automatically.": "Sonrcome back burad— bu devam ets automatically.",
    "Tap Connect so the toggle turns on.": "Tap Connect so toggle turns on.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Keep Wi-Fi on, sonrcome back burad— bu devam ets automatically.",
    "Get LocalDevVPN": "LocalDevVPN al",
    "Import an .ipa first": "İçe aktar .ipönce",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Tap “İçe aktar .ipa” above ve pick dosy— it clive anywburad Dosyas uygulamcreach, including iCloud Drive veyUSB drive.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "Veypaste direct indir bağlantı under şu button, ve SideYükleer fetches .ipitself.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "Veyaç Dosyas uygulama, press ve hold .ipa, tap Share, ve pick SideYükleer — şu hves dosyover ileout picker.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "Veycopy it into Dosyas › On My iPhone › SideYükleer, wburadSideYükleer also finds it.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "Bu is way in wburadGitHub is blocked: fetch IPon any cihaz, bring it over, ve yükle it burada.",
    "Bring the .ipa yourself": "Bring .ipseninself",
    "%@ can't be downloaded while its GitHub repository is offline. The other apps still install as usual.":
        "%@ yapılamaz be indired while its GitHub repositveyay is offline. or uygulamas still yükle as usual.",
    "To install it anyway, get its .ipa from somewhere you trust, name it %@, and copy it into Files › On My iPhone › SideInstaller.":
        "To yükle it anyway, get its .ipşuradsomewburadyou trust, name it %@, ve copy it into Dosyas › On My iPhone › SideYükleer.",
    "Then tap Install again — SideInstaller uses your file instead of downloading one.":
        "Sonrtap Yükle yeniden — SideYükleer uses senin dosyinstead of indiring one.",
    "If you reach GitHub through a VPN or proxy app, turn off LocalDevVPN and turn that one on: iOS runs only one VPN at a time.":
        "If you reach GitHub through VPN veyproxy uygulama, turn off LocalDevVPN ve turn şu one on: iOS runs only one VPN at time.",
    "Tap “Get the .ipa” below and save the file, or download it on another device and bring it over.":
        "Tap “Get .ipa” below ve kaydet dosya, veyindir it on anor cihaz ve bring it over.",
    "Back in SideInstaller, pick Custom .ipa under Install, tap “Import .ipa” and choose the file. SideInstaller recognizes %@ and sets it up just like its own download.":
        "Back in SideYükleer, pick Custom .ipunder Yükle, tap “İçe aktar .ipa” ve seç dosya. SideYükleer recognizes %@ ve sets it up just like its own indir.",
    "Turn LocalDevVPN back on, then tap Install.": "Turn LocalDevVPN back on, sonrtap Yükle.",
    "Get the .ipa": "Get .ipa",
    "Pair this iPhone in Settings": "Pair bu iPhone in Ayarlar",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Aç Ayarlar uygulama, sonrgo to Privacy & Security › Developer Mode.",
    "Tap “Pair with SideInstaller”.": "Tap “Pair ile SideYükleer”.",
    "Enter your iPhone’s passcode if it asks for it.": "Enter senin iPhone’s passcode if it asks için it.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Come back to SideYükleer, read code it shows you, sonrtype şu same code into prompt in Ayarlar.",
    "Type the code that appears at the top of the screen into the prompt in Settings. If none appears, come back to SideInstaller to read it.":
        "Type code şu uygulamaears at top of screen into prompt in Ayarlar. If none uygulamaears, come back to SideYükleer to read it.",
    "Allow notifications when SideInstaller asks: that's how the pairing code reaches you in Settings.":
        "Allow notifications when SideYükleer asks: bu how eşleme code reaches you in Ayarlar.",
    // The pairing Live Activity

    "Privacy & Security › Developer Mode › Pair with SideInstaller":
        "Privacy & Security › Developer Mode › Pair ile SideYükleer",
    "Paired": "Eşlendi",
    "Tap to return to SideInstaller.": "Tap to return to SideYükleer.",
    // The install's progress outside the app

    "Installing %@": "Yükleing %@",
    "Paused": "Duraklatıldı",
    "Open SideInstaller to finish the install.": "Aç SideYükleer to bitir yükle.",
    "Check the App IDs it needs, then tap Install.": "Check UygulamIDs it needs, sonrtap Yükle.",
    "Tap Trust": "Güven'e dokun",
    "Unlock this iPhone and tap Trust when it asks.": "Unlock bu iPhone ve tap Trust when it asks.",
    "A signing certificate already exists": "imzalamsertifikalready exists",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Uygulamale returned hat7460: bu Uygulamale kimliği already has iOS development sertifika, veyrequest için one is still pending.",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideYükleer yapılamadı reuse it. Şu huygulamaens when sertifikwas issued somewburadelse — AltStveyae, SideStveyae, Sideloadly veyXcode on anor cihaz — so private key it needs değil on bu iPhone.",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "Use “İptal et ve retry” above, veyaç Sertifikas in Tools tab, tap “Load sertifikas”, ve iptal et it tburada.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "Revoking is permanent: every uygulamalready imzalveı ile şu sertifikduraks launching, on every cihaz.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Alternatively, sign in ile different (veyspare) Uygulamale kimliği above, sonrtap Yükle yeniden.",
    // MARK: - Guide cards

    // Guide: reset a locked Apple Account

    "Reset your Apple Account password": "Reset senin Uygulamale Account parola",
    "Apple has locked this Apple Account for security reasons, often after too many sign-in attempts. Every sign-in fails until it's unlocked, so tapping Install again won't help yet.":
        "Uygulamale has locked bu Uygulamale Account için security reasons, often after too many sign-in attempts. Every sign-in fails until bu unlocked, so tuygulamaing Yükle yeniden yapmayacak help yet.",
    "Open iForgot, enter this Apple Account's email, and follow Apple's steps to unlock it and reset its password.":
        "Aç iİçingot, enter bu Uygulamale Account's email, ve follow Uygulamale's steps to unlock it ve reset its parola.",
    "Back in SideInstaller, open Settings › Account, swipe left on this Apple ID, tap Edit, and enter the new password.":
        "Back in SideYükleer, aç Ayarlar › Account, swipe left on bu Uygulamale kimliği, tap Edit, ve enter new parola.",
    "Then tap Install again.": "Sonrtap Yükle yeniden.",
    "Open iForgot": "Aç iİçingot",
    "Apple won't let this Apple Account use developer services because of its owner's age (error 1102). Sign in with an adult's Apple Account instead.":
        "Uygulamale yapmayacak let bu Uygulamale Account use developer services because of its owner's age (hat1102). Sign in ile adult's Uygulamale Account instead.",
    "This Apple ID has no App IDs left (error 9120). A free Apple ID can register 10 a week, and each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Bu Uygulamale kimliği has no UygulamIDs left (hat9120). free Uygulamale kimliği cregister 10 week, ve each one counts için 7 days, so bekle için some to expire veysign in ile anor Uygulamale kimliği.",
    "This iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. Delete one of them, then try again.":
        "Bu iPhone already has three uygulamas imzalveı ile free Uygulamale kimliği, most iOS allows, counting expired ones. Sil one of m, sonryeniden dene.",
    "This Apple Account can't sign apps": "Bu Uygulamale Account yapılamaz sign uygulamas",
    "Apple only lets adults use the developer services SideInstaller signs apps with, and it reports that this Apple Account belongs to someone younger (error 1102).":
        "Uygulamale only lets adults use developer services SideYükleer signs uygulamas ile, ve it repveyats şu bu Uygulamale Account belongs to someone younger (hat1102).",
    "Sign in with an adult's Apple Account instead: open Settings › Account and add it there.":
        "Sign in ile adult's Uygulamale Account instead: aç Ayarlar › Account ve ekle it tburada.",
    "Apple won't let this Apple Account use developer services until its email address is verified (error 2160). Verify it at account.apple.com, then try again.":
        "Uygulamale yapmayacak let bu Uygulamale Account use developer services until its email ekleress is verified (hat2160). Verify it at account.uygulamale.com, sonryeniden dene.",
    "Verify your Apple Account's email": "Verify senin Uygulamale Account's email",
    "Apple won't let this Apple Account sign apps until its email address is verified (error 2160). Signing in again or through another anisette server won't change that.":
        "Uygulamale yapmayacak let bu Uygulamale Account sign uygulamas until its email ekleress is verified (hat2160). İmzalamin yeniden veythrough anor anisette sunucu yapmayacak change şu.",
    "Sign in at account.apple.com with this Apple Account and verify its email address when Apple asks. Apple sends the code or link to that address, so check its spam folder too.":
        "Sign in at account.uygulamale.com ile bu Uygulamale Account ve verify its email ekleress when Uygulamale asks. Uygulamale sends code veybağlantı to şu ekleress, so check its spam folder too.",
    "Open Apple Account": "Aç Uygulamale Account",
    "No App IDs left this week": "No UygulamIDs left bu week",
    "Every app SideInstaller signs needs an App ID, which its extensions share. A free Apple ID can register 10 a week, and each one counts for 7 days.":
        "Every uygulamSideYükleer signs needs UygulamID, which its extensions share. free Uygulamale kimliği cregister 10 week, ve each one counts için 7 days.",
    "They can't be deleted sooner. Wait until some expire, then tap Install again.":
        "y yapılamaz be sild sooner. Bekle until some expire, sonrtap Yükle yeniden.",
    "Or sign in with a different (or spare) Apple ID in Settings › Account, then tap Install again.":
        "Veysign in ile different (veyspare) Uygulamale kimliği in Ayarlar › Account, sonrtap Yükle yeniden.",
    "Three sideloaded apps already": "Three sideloaded uygulamas already",
    "iOS allows three apps signed with a free Apple ID on an iPhone at a time, and it refused a fourth.":
        "iOS allows three uygulamas imzalveı ile free Uygulamale kimliği on iPhone at time, ve it refused fourth.",
    "Expired apps count too. Delete one you no longer need from the Home Screen.":
        "Expired uygulamas count too. Sil one you no longer need şurad Home Screen.",
    // Guide: import a pairing file

    "Import a pairing file": "İçe aktar eşleme dosyası",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@ is önce version iPhone cpair ile itself on. On bu one eşleme dosyası has to be made on computer.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "On Mac, Windows PC veyLinux box, plug bu iPhone in, trust computer, ve run jitterbugpair (vey“pymobilecihaz3 lockdown pair”).",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "Send dosyit writes — .mobilecihazeşleme vey.plist — to bu iPhone, by AirDrop, iCloud Drive veycable.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "Come back burada, tap “İçe aktar eşleme dosyası”, ve pick it. Everything after şu wveyaks as it does on iOS %@.",
    "Get jitterbugpair": "jitterbugpair al",
    "From iOS 26.4 on it has to be a remote pairing file: this iPhone hangs up on lockdown ones, like jitterbugpair's, when they come through LocalDevVPN.":
        "ŞuradiOS 26.4 on it has to be remote eşleme dosyası: bu iPhone hangs up on lockdown ones, like jitterbugpair's, when y come through LocalDevVPN.",
    "Get idevice_pair": "Get icihaz_pair",
    "Make a remote pairing file": "Make remote eşleme dosyası",
    "The pairing file you imported is a lockdown one. Since iOS 26.4, this iPhone hangs up on those when they come through LocalDevVPN, so it can't connect, and a new one of the same kind won't either.":
        "eşleme dosyası you içe aktared is lockdown one. Since iOS 26.4, bu iPhone hangs up on those when y come through LocalDevVPN, so it yapılamaz connect, ve new one of same kind yapmayacak eir.",
    "Come back here, tap “Replace” on the Pairing file card, and pick it.":
        "Come back burada, tap “Replace” on Eşleme dosyası card, ve pick it.",
    "On a Mac, Windows PC or Linux box, open idevice_pair, plug this iPhone in, and tap Trust if it asks. Pick it, choose “Remote pairing”, click “Create”, and keep this iPhone unlocked until it's done.":
        "On Mac, Windows PC veyLinux box, aç icihaz_pair, plug bu iPhone in, ve tap Trust if it asks. Pick it, seç “Remote eşleme”, click “Create”, ve keep bu iPhone unlocked until bu done.",
    "Click “Save to file…” and send the file to this iPhone, by AirDrop, iCloud Drive or a cable. A pairing file exported from iLoader works too.":
        "Click “Kaydet to dosya…” ve send dosyto bu iPhone, by AirDrop, iCloud Drive veycable. eşleme dosyası dışaktared şuradiLoader wveyaks too.",
    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "sertifikalready exists",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Uygulamale yapmayacak issue second imzalamsertifikiçin bu Uygulamale kimliği. Revoking one it already has lets yükle devam et — but it yapılamaz be undone.",
    "Loading certificates": "Loading sertifikas",
    "Revoke and retry": "İptal et ve retry",
    "Which certificate should be revoked?": "Which sertifikshould be iptal etd?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Uygulamale repveyats sertifikon bu Uygulamale kimliği, but none came back in list. It may be request bu still pending — bekle few minutes ve tap Yükle yeniden.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "Every uygulamalready imzalveı ile sertifikyou pick will durak launching, on every cihaz — including uygulamas yükleed by AltStveyae, SideStveyae, veycomputer. Bu yapılamaz be undone. yükle retries straight afterwards.",
    " (expired)": "(expired)",
    "Couldn't register this device": "Yapılamadı register bu cihaz",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Senin Uygulamale kimliği has hit its limit of registered cihazs. Free accounts conly register hveful of cihazs per year ve yapılamaz kaldır old ones until year resets.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "Easiest fix: put different (veyspare) Uygulamale kimliği in fields above, sonrtap Yükle yeniden.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideYükleer yapılamadı ekle bu iPhone to senin Uygulamale kimliği's developer team automatically. Tuygulamaing Yükle yeniden often wveyaks — Uygulamale's developer service is sometimes briefly unavailable.",
    "If it keeps failing, add the device by hand. Its UDID is:": "If it keeps failing, ekle cihaz by hve. Its UDID is:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Paste şu into “Register Cihaz” içinm in Uygulamale Developer pveyatal (bu requires paid Uygulamale Developer account), sonrtap Yükle yeniden.",
    "Open device list": "Aç cihaz list",
    "Last step: trust %@": "Son adım: %@ için güven",
    "Open Settings › General › VPN & Device Management.": "Aç Ayarlar › General › VPN & Cihaz Management.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "Tap senin Uygulamale kimliği under “Developer Uygulama”, sonrtap Trust.",
    "Open %@ from your Home Screen — you're done.": "Aç %@ şuradsenin Home Screen — sen done.",
    "Import the certificate into LiveContainer": "İçe aktar sertifikinto LiveContainer",
    "Open LiveContainer from your Home Screen.": "Aç LiveContainer şuradsenin Home Screen.",
    "Tap the Settings tab.": "Tap Ayarlar tab.",
    "Tap “Import Certificate From SideStore”.": "Tap “İçe aktar SertifikŞuradSideStveyae”.",
    "Wrong device IP": "Wrong cihaz IP",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "ekleress in Ayarlar › Advanced › Cihaz IP is one bu iPhone already holds, so var nothing at or end to connect to.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "Set it back to 10.7.0.1, default. In LocalDevVPN bu value under Ayarlar › Cihaz IP — not ekleress on its main screen, which is tunnel's own end.",
    "If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one.":
        "If you changed LocalDevVPN's ekleresses, copy its Cihaz IP burad— including /32, if it shows one.",
    "Device IP is %@, one of this iPhone's own addresses, and iOS won't let an app connect to those. In Settings › Advanced, set Device IP to the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default, not the “Connected to” address on its main screen.":
        "Cihaz IP is %@, one of bu iPhone's own ekleresses, ve iOS yapmayacak let uygulamconnect to those. In Ayarlar › Advanced, set Cihaz IP to ekleress under LocalDevVPN's Ayarlar › Cihaz IP: 10.7.0.1 by default, not “Bağlı to” ekleress on its main screen.",
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "iOS refused bağlantı to %@ on bu iPhone, beiçine anything was sent. It does şu için bu iPhone's own ekleresses, like “Bağlı to” ekleress on LocalDevVPN's main screen. Cihaz IP, in Ayarlar › Advanced, has to be ekleress under LocalDevVPN's Ayarlar › Cihaz IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off ve on yeniden, sonryeniden dene.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "Bu iPhone hung up on bağlantı as soon as it açed. ŞuradiOS 26.4 on it does şu to lockdown eşleme dosyasıs, like bu one, when y come through LocalDevVPN. Pair bu iPhone ile itself instead: tap “Regenerate” under Tools › Eşleme, veytap Yükle, which pairs it önce.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "Bu iPhone hung up on bağlantı as soon as it açed. Since iOS 26.4 it does şu to lockdown eşleme dosyasıs, like bu one, when y come through LocalDevVPN, so new one of same kind yapmayacak help. remote eşleme dosyası still wveyaks: on computer, aç icihaz_pair, seç “Remote eşleme”, click “Create”, sonr“Kaydet to dosya…”, ve içe aktar dosyunder “Eşleme dosyası”.",
    "This iPhone hung up on the connection: from iOS 26.4 on, it does that to lockdown pairing files like this one when they come through LocalDevVPN. See the steps above.":
        "Bu iPhone hung up on bağlantı: şuradiOS 26.4 on, it does şu to lockdown eşleme dosyasıs like bu one when y come through LocalDevVPN. See steps above.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Bu iPhone'u eşlemek için gerekir: SideInstaller, Ayarlar'ın bulması için kendini yerel ağda duyurur.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Bir Wi-Fi ağına bağlan. Bu iPhone'u eşlemek için gerekir — SideInstaller yerel ağda bulunabilir olmalı.",
    // MARK: - About

    "About": "Hakkında",
    "Version %@ (%@)": "Version %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller, bilgisayar olmadan SideStore ve LiveContainer'ı doğrudan iPhone'una yükler.",
    "Links": "Links",
    "Source code": "Kaynak kodu",
    "Support the project": "Projeyi destekle",
    "Crypto": "Crypto",
    "Donation wallets for Bitcoin, Ethereum and Solana.": "Donation wallets için Bitcoin, Etburadaum ve Solana.",
    "Crypto donations": "Kripto bağışları",
    "Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you.":
        "Donations are entirely optional. y yapmbuy anything, unlock any feature veyget you anything in return; y're just way to say thanks if SideYükleer has helped you.",
    "Coin": "Coin",
    "Network: %@": "Ağ: %@",
    "QR code for the %@ address": "QR code için %@ ekleress",
    "Copied": "Kopyalandı",
    "Send each coin only on the network shown. Crypto sent on another network can't be recovered.":
        "Send each coin only on ağ shown. Crypto sent on anor ağ yapılamaz be recovered.",
    "Special thanks": "Özel teşekkürler",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "İçin icihaz, library SideYükleer talks to senin iPhone through. None of bu exists ileout it.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "İçin suppveyat, ve için spotting bugs şu got fixed because of it.",
    "For the Japanese translation.": "İçin Japanese translation.",
    "For the Korean translation.": "İçin Kveyaetranslation.",
    "Built with": "Bunlarla yapıldı",
    "The open source work this app is built on:": "aç source wveyak bu uygulamis built on:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "Eşleme, tunnel ve yükle itself. By jkcoxson, MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Uygulamale kimliği sign in, sertifikas ve imzalamon cihaz. By nab138, MIT.",
    "The sideloading app this installs for you.": "sideloading uygulambu yükles için you.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Runs sideloaded uygulamas ileout spending uygulamslot on each one.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "developer disk image konum spoofing mounts. Mirrveyaed by dveyaonz88.",
    "Where to get it": "Nereden alınır",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "Only builds on official yükle page ve repositveyay are mine. Anyone ciçink source, ekle credential stealer ve ship it under same name ve icon — so yapmtrust senin Uygulamale kimliği to copy şuradanywburadelse.",
    "Install page": "Yükleme sayfası",
    "Terms": "Koşullar",
    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.": "%@ needs iOS %d veylater. Bu iPhone runs iOS %@.",
    "Open Madeira from your Home Screen.": "Aç Madeirşuradsenin Home Screen.",
    "In its setup, under “Set up JIT”, pick “In-app with pairing file”: SideInstaller already put the file there, so tap “Continue”.":
        "In its setup, under “Set up JIT”, pick “In-uygulamile eşleme dosyası”: SideYükleer already put dosytburada, so tap “Devam et”.",
    "In its setup, under “Set up JIT”, pick how this iPhone gets JIT.":
        "In its setup, under “Set up JIT”, pick how bu iPhone gets JIT.",
    "Madeira renews its own signing from now on, when it's open and LocalDevVPN is connected. SideInstaller gave it a sign-in for that: a token for Apple's developer service, not your password. Madeira can forget it under Settings › Signing.":
        "Madeirrenews its own imzalamşuradnow on, when bu aç ve LocalDevVPN is bağlı. SideYükleer gave it sign-in için şu: token için Uygulamale's developer service, not senin parola. Madeirciçinget it under Ayarlar › İmzalama.",
    "Its signing lasts 7 days. Before they run out, refresh it here under Tools › Sideloaded apps.":
        "Its imzalamlasts 7 days. Beiçine y run out, yenile it buradunder Tools › Sideloaded uygulamas.",
    "This pairing file has no RPPairing record, the only kind %@ reads.":
        "Bu eşleme dosyası has no RPEşleme recveyad, only kind %@ reads.",
    "Runs Windows PC games on your iPhone. By Will Faust, GPL-3.0.":
        "Runs Windows PC games on senin iPhone. By Will Faust, GPL-3.0.",
    // MARK: - App ID cost

    "App IDs for this app": "Bu uygulama için App ID'ler",
    "Cost": "Maliyet",
    "Left now": "Şu an kalan",
    "Left after": "Sonra kalan",
    "New App IDs": "Yeni App ID'ler",
    "This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Bu Uygulamale kimliği yapmıyveyhave enough UygulamIDs left: bu uygulamneeds %d, ve %d are left. Each one counts için 7 days, so bekle için some to expire veysign in ile anor Uygulamale kimliği.",
    "The next one frees up on %@.": "next one frees up on %@.",
    "Your Apple ID already has every App ID this app needs, so installing it uses none.":
        "Senin Uygulamale kimliği already has every UygulamID bu uygulamneeds, so yükleing it uses none.",
    "Signing registers one App ID for the app, and its extensions share it. It counts for 7 days.":
        "İmzalamregisters one UygulamID için uygulama, ve its extensions share it. It counts için 7 days.",
    "This Apple ID can register %d a week.": "Bu Uygulamale kimliği cregister %d week.",
    // MARK: - Links (sideinstaller://install, sideinstaller://pairingFile)

    "Install from a link?": "Bağlantıdan yüklensin mi?",
    "Download and install": "İndir ve yükle",
    "SideInstaller will download this .ipa, then sign it with your Apple ID and install it. Only go ahead if you trust where the link came from.":
        "SideYükleer will indir bu .ipa, sonrsign it ile senin Uygulamale kimliği ve yükle it. Only go ahead if you trust wburad bağlantı came şuradan.",
    "It replaces %@, the custom .ipa you have now.": "It replaces %@, custom .ipyou have now.",
    "Use SideStore's pairing file?": "SideStore'un eşleme dosyası kullanılsın mı?",
    "Import this pairing file?": "Bu eşleme dosyası içe aktarılsın mı?",
    "Import": "İçe aktar",
    "SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.":
        "SideStveyae sent back eşleme dosyası it has. SideYükleer will connect to bu iPhone ile it.",
    "A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.":
        "bağlantı sent SideYükleer eşleme dosyası. Only içe aktar it if you asked için one: SideYükleer will connect to bu iPhone ile it.",
    "It replaces %@.": "%@ yerine geçer.",
    "It replaces the pairing file in use now.": "It replaces eşleme dosyası in use now.",
    "Get it from SideStore": "SideStore'dan al",
    "SideStore opens and sends back the pairing file it has.": "SideStveyae açs ve sends back eşleme dosyası it has.",
    "SideStore isn't installed on this iPhone, so there's no pairing file to get from it.":
        "SideStveyae değil yükleed on bu iPhone, so var no eşleme dosyası to get şuradit.",
    "SideInstaller takes the pairing file LiveContainer's built-in SideStore has.":
        "SideYükleer takes eşleme dosyası LiveContainer's built-in SideStveyae has.",
    "This is the pairing file LiveContainer's built-in SideStore has. SideInstaller will connect to this iPhone with it.":
        "Bu is eşleme dosyası LiveContainer's built-in SideStveyae has. SideYükleer will connect to bu iPhone ile it.",
    "In LiveContainer's Multitask Mode, SideInstaller can't open the built-in SideStore's files. Open SideInstaller in LiveContainer without Multitask Mode, then try again, or tap “Import pairing file” and pick the file your computer made.":
        "In LiveContainer's Multitask Mode, SideYükleer yapılamaz aç built-in SideStveyae's dosyas. Aç SideYükleer in LiveContainer ileout Multitask Mode, sonryeniden dene, veytap “İçe aktar eşleme dosyası” ve pick dosysenin computer made.",
    "Inside LiveContainer, SideStore can't send its pairing file back to SideInstaller, and LiveContainer's built-in SideStore has none that SideInstaller can use. Tap “Import pairing file” and pick the file your computer made, or import one into SideStore first, then try again here.":
        "Inside LiveContainer, SideStveyae yapılamaz send its eşleme dosyası back to SideYükleer, ve LiveContainer's built-in SideStveyae has none şu SideYükleer cuse. Tap “İçe aktar eşleme dosyası” ve pick dosysenin computer made, veyiçe aktar one into SideStveyae önce, sonryeniden dene burada.",
    "That install link has no .ipa in it. It needs ?url= followed by the https:// address the .ipa downloads from.":
        "Bu yükleme bağlantısında .ipa yok. ?url= ve ardından .ipa'nın indirildiği https:// adresi gerekir.",
    "That link was meant to carry a pairing file, but what it holds can't be read.":
        "Bu bağlantı bir eşleme dosyası taşıyacaktı, ancak içeriği okunamıyor.",
    "That link carries a file, but it isn't a pairing file.": "Bu bağlantı bir dosya taşıyor, ancak eşleme dosyası değil.",
    // MARK: - Report a problem

    "Report a problem": "Sorun bildir",
    "Report this problem": "Bu sorunu bildir",
    "Opens a GitHub issue with this app's details, its log and crash logs.":
        "Açs GitHub issue ile bu uygulama's details, its log ve crash logs.",
    "What happened?": "Ne oldu?",
    "What were you doing, and what went wrong?": "What were you doing, ve what went wrong?",
    "Say what you tapped, what you expected and what happened instead. English is best, but any language is fine.":
        "Say what you tuygulamaed, what you expected ve what huygulamaened instead. English is best, but any language is fine.",
    "Included": "Dahil",
    "Device": "Cihaz",
    "App": "App",
    "Stopped at": "Durduğu yer",
    "not connected": "bağlı değil",
    "none": "yok",
    "made on this iPhone": "bu iPhone'da oluşturuldu",
    "Runs inside LiveContainer": "LiveContainer içinde çalışır",
    "on": "açık",
    "off": "kapalı",
    "unknown": "bilinmiyor",
    "yes": "evet",
    "no": "no",
    "latest": "en son",
    "custom server": "özel sunucu",
    "Auto, starts with %@": "Auto, starts ile %@",
    "Error": "Error",
    "Activity log": "Etkinlik günlüğü",
    "%d lines": "%d satır",
    "Your Apple ID, device name, serial numbers and keys are taken out of the log first.":
        "Senin Uygulamale kimliği, cihaz name, serial numbers ve keys are taken out of log önce.",
    "Crash logs": "Çökme günlükleri",
    "Looking for crash logs …": "Çökme günlükleri aranıyor …",
    "Look for crash logs on this iPhone": "Bu iPhone'da çökme günlüklerini ara",
    "Look again": "Yeniden ara",
    "No crash logs from SideStore, LiveContainer or Madeira in the last %d days.":
        "No crash logs şuradSideStveyae, LiveContainer veyMadeirin last %d days.",
    "iOS hands SideInstaller its own crashes the next time it opens. Crash logs from SideStore, LiveContainer and Madeira are read from this iPhone through LocalDevVPN.":
        "iOS hves SideYükleer its own crashes next time it açs. Crash logs şuradSideStveyae, LiveContainer ve Madeirare read şuradbu iPhone through LocalDevVPN.",
    "Open a GitHub issue": "GitHub sorunu aç",
    "Share the report": "Raporu paylaş",
    "Preview the report": "Raporu önizle",
    "Report": "Rapor",
    "The issue opens filled in. When the log is too long for that, SideInstaller copies it for you to paste at the end of the issue. The whole report is also saved in %@.":
        "issue açs filled in. When log is too long için şu, SideYükleer copies it için you to paste at end of issue. whole repveyat is also kaydetd in %@.",
    "Files › On My iPhone": "Dosyalar › iPhone'umda",
    "Copy the full log": "Tam günlüğü kopyala",
    "Paste the log into the issue": "Günlüğü soruna yapıştır",
    "Open GitHub": "GitHub'ı aç",
    "The full log is too long to fill in, so SideInstaller copied it. On GitHub, tap the end of the text, choose Paste, then submit the issue.":
        "full log is too long to fill in, so SideYükleer copied it. On GitHub, tap end of text, seç Paste, sonrsubmit issue.",
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
]
