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
        "Apple bu Apple kimliği için imzalama sertifikası vermiyor: zaten bir tane olduğunu bildiriyor (hata 7460). Araçlar › Sertifikalar altında SideStore'un sertifikasını kullan veya onu iptal et, sonra yeniden yenile.",
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
        "%@ Apple kimliğinle yeniden imzalanıp bu cihazdaki kopyanın üzerine yüklenecek. Verileri korunur ve yedi günü yeniden başlar.",
    "%d apps will be signed again with your Apple ID and installed over the copies on this device. They keep their data, and their seven days start over.":
        "%d uygulama Apple kimliğinle yeniden imzalanıp bu cihazdaki kopyaların üzerine yüklenecek. Verileri korunur ve yedi günleri yeniden başlar.",
    "%d app can be signed again from an IPA already on this iPhone.":
        "%d uygulama, bu iPhone'da zaten bulunan bir IPA'dan yeniden imzalanabilir.",
    "%d apps can be signed again from IPAs already on this iPhone.":
        "%d uygulama, bu iPhone'da zaten bulunan IPA'lardan yeniden imzalanabilir.",
    "Reload": "Yeniden yükle",
    "Waiting": "Bekleing",
    "In progress": "Devam ediyor",
    "Failed": "Başarısız",
    "%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.":
        "Buradaki %d uygulamanın SideInstaller'da IPA'sı yok, bu yüzden bu sayfadan yenilenemez. Onu yükleyen uygulamada yenile veya önce .ipa dosyasını içe aktar.",
    "%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.":
        "Buradaki %d uygulamanın SideInstaller'da IPA'sı yok, bu yüzden bu sayfadan yenilenemez. Onları yükleyen uygulamada yenile veya önce .ipa dosyalarını içe aktar.",
    "%d app": "%d app",
    "%d apps": "%d apps",
    "%d app needs refreshing": "%d uygulamneeds yenileing",
    "%d apps need refreshing": "%d uygulamas need yenileing",
    "No sideloaded apps": "No sideloaded uygulamas",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Bu cihazda hiçbir şey sağlama profiliyle yüklenmemiş. App Store uygulamalarının süresi dolmaz, bu yüzden burada listelenmezler.",
    "No matching profile": "Eşleşen profil yok",
    "Expires today": "Bugün doluyor",
    "Expires tomorrow": "Expires tomveyarow",
    "Expires in %d days — %@": "%d gün içinde doluyor — %@",
    "Expired %@": "Süresi doldu %@",
    "Unused profiles": "Kullanılmayan profiller",
    "Issued to App IDs no installed app is running on.": "Yüklü hiçbir uygulamanın çalışmadığı App ID'lere verilmiş.",
    "Older profiles": "Eski profiller",
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
        "Joker App ID — altındaki herhangi bir paket kimliğini kapsar ve uygulamaya özel yetenekler taşıyamaz.",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "Cihazda bu App ID için sağlama profili yok. Uygulama zaten açılmayı bırakmış olabilir — düzeltmek için yeniden yükle.",
    // MARK: - Side by Side tool

    // The tool's name is left in English everywhere, as SideStore's is.

    "Side by Side": "Yan yana",
    "Pair with their iPhone": "Pair ile ir iPhone",
    "Sign in to their Apple ID": "Onların Apple kimliği ile oturum aç",
    "Download SideInstaller": "SideInstaller'ı indir",
    "Install on their iPhone": "Yükle on ir iPhone",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” bir IPv4 adresi değil. 192.168.1.42 gibi görünmeli.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ bu iPhone'un zaten sahip olduğu bir adres. Yan yana başkasının iPhone'una yükler — onunkini kullan. Buna yüklemek için Yükle sekmesini kullan.",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "iPhone şu paired was bu one. Pair şuradir iPhone's Ayarlar instead. To yükle on bu iPhone, use Yükle tab.",
    "Enter the Apple ID to sign with, and its password.": "İmzalamak için Apple kimliğini ve parolasını gir.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Wi-Fi kapalı. Bunun çalışması için her iki iPhone'un da aynı Wi-Fi ağında olması gerekir.",
    "The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute.":
        "release indir değildi IPA. GitHub may be returning hatpage — yeniden dene in minute.",
    "Couldn't download the latest SideInstaller release: %@": "En son SideInstaller sürümü indirilemedi: %@",
    "No SideInstaller IPA downloaded.": "SideInstaller IPA indirilmedi.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise.":
        "Apple bu Apple kimliği için imzalama sertifikası vermiyor: zaten bir tane olduğunu bildiriyor (hata 7460). Önce birinin iptal edilmesi gerekir — bu Ayarlar › Hesap'ta kayıtlı Apple kimliğiyse Sertifikalar aracıyla; değilse developer.apple.com'da o hesapla oturum açarak.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple onların iPhone'unu bu Apple kimliğinin geliştirici ekibine kaydetmedi, bu yüzden sağlama profili vermiyor. %@",
    "No pair record for their iPhone.": "No pair recveyad için ir iPhone.",
    "The link to their iPhone dropped — start again.": "bağlantı to ir iPhone dropped — start yeniden.",
    "Set up someone else's iPhone": "Başkasının iPhone'unu kur",
    "Same Wi-Fi network": "Same Wi-Fi ağ",
    "Their iPhone needs iOS %@ — SideInstaller pairs itself once it's installed, and nothing older can.":
        "Onların iPhone'u iOS %@ gerektirir — SideInstaller yüklendikten sonra kendini eşler; daha eskisi eşlenemez.",
    "Their iPhone": "ir iPhone",
    "IP address (optional)": "IP adresi (isteğe bağlı)",
    "Optional: leave it empty, and it fills in when their iPhone pairs.":
        "Optional: leave it empty, ve it fills in when ir iPhone pairs.",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "On ir iPhone: Ayarlar › Wi-Fi › ⓘ next to ağ, sonr“IP Ekleress”.",
    "This iPhone is %@, so theirs will look similar.": "Bu iPhone is %@, so irs will look similar.",
    "Apple ID to sign with": "İmzalamak için Apple kimliği",
    "Tip: Use the iPhone/iPad owner's Apple account credentials": "İpucu: iPhone/iPad sahibinin Apple hesap bilgilerini kullan",
    "Use my saved Apple ID instead": "Bunun yerine kayıtlı Apple kimliğimi kullan",
    "Steps": "Adımlar",
    "Waiting for them to tap Trust…": "Bekleing için m to tap Trust…",
    "Waiting for them to pair in Settings…": "Bekleing için m to pair in Ayarlar…",
    "Waiting for them to enter the code…": "Bekleing için m to enter code…",
    "Pair their iPhone in Settings": "Pair ir iPhone in Ayarlar",
    "Their iPhone won't ask by itself — pairing starts from its Settings.":
        "ir iPhone yapmayacak ask by itself — eşleme starts şuradits Ayarlar.",
    "On their iPhone, open Settings › Privacy & Security › Developer Mode.":
        "On ir iPhone, aç Ayarlar › Privacy & Security › Developer Mode.",
    "Tap “Pair with %@”.": "“%@ ile eşle”ye dokun.",
    "Enter their iPhone’s passcode if it asks for it.": "Enter ir iPhone’s passcode if it asks için it.",
    "Type the code that appears here into the prompt on their iPhone.":
        "Type code şu uygulamaears buradinto prompt on ir iPhone.",
    "Type this into the prompt on their iPhone.": "Type bu into prompt on ir iPhone.",
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "y tuygulamaed “YapmTrust” on ir iPhone. Start yeniden, ve have m tap Trust.",
    "SideInstaller is already waiting for an iPhone to pair with it — from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "SideInstaller zaten bir iPhone'un eşlenmesini bekliyor — Yükle sekmesinden, Eşleme sayfasından veya buradaki önceki bir denemeden. O eşlemeyi bitir veya SideInstaller'ı kapatıp aç, sonra yeniden dene.",
    "Pairing with their iPhone didn't finish: %@": "Eşleme ile ir iPhone yapmadı bitir: %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "ir iPhone at %@ refused bağlantı. It only accepts one while Developer Mode is on, ve iOS asks to confirm Developer Mode yeniden after every restart: on ir iPhone, turn it on under Ayarlar › Privacy & Security › Developer Mode, sonryeniden dene.",
    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Onların iPhone'una %@ adresinden ulaşılamadı. Adresi kontrol et (onların iPhone'unda Ayarlar › Wi-Fi › ⓘ), her iki iPhone'un aynı Wi-Fi ağında olduğunu ve bu iPhone'un Ayarları'nda SideInstaller için Yerel Ağ'ın açık olduğunu doğrula. Misafir ve genel ağlar cihazların birbirine ulaşmasını sıkça engeller.",
    "The link to their iPhone didn't come up: %@": "bağlantı to ir iPhone yapmadı come up: %@",
    "%d%% downloaded": "%d%% indired",
    "%d%% uploaded": "%%%d yüklendi",
    "Start the install": "Start yükle",
    "Install again": "Yükle yeniden",
    "Clear their details": "Onların ayrıntılarını temizle",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "Bu iPhone hâlâ onunki ile eşli. Temizlemek bunu unutturur.",
    "Last step: they trust %@": "Last step: y trust %@",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "On ir iPhone: Ayarlar › General › VPN & Cihaz Management.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "“Geliştirici Uygulaması” altındaki Apple kimliğine dokun, sonra Güven'e dokun.",
    "Open it from their Home Screen — they're set up.": "Aç it şuradir Home Screen — y're set up.",
    // MARK: - Settings

    "Settings": "Ayarlar",
    "Done": "Tamam",
    "Language": "Dil",
    "App language": "Uygulama dili",
    "Sounds": "Sesler",
    "Sound effects": "Ses efektleri",
    "Auto": "Otomatik",
    // The Tunnel section: starting LocalDevVPN from here.

    "Tunnel": "Tunnel",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.":
        "%@:%d adresindeki bir şey bağlantıyı reddetti; tünel trafik taşıyor — cihaz yalnızca eşleme bağlantı noktasında dinlemiyor. Bu bağlantı noktası yalnızca Geliştirici Modu açıkken açılır ve iOS her yeniden başlatmadan sonra yeniden ister: Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu'ndan aç, sonra yeniden dene. Zaten açıksa “Eşleme dosyası” altında bu iPhone'u yeniden eşle.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port: Developer Mode is off. Turn it on under Settings › Privacy & Security › Developer Mode (the iPhone restarts), then try again.":
        "Something at %@:%d refused bağlantı, so tunnel is carrying traffic, but bu iPhone değil listening on its eşleme pveyat: Developer Mode is off. Turn it on under Ayarlar › Privacy & Security › Developer Mode ( iPhone restarts), sonryeniden dene.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port, although Developer Mode is on. Pair this iPhone again under “Pairing file”, then try again. If it still fails, restart the iPhone.":
        "Something at %@:%d refused bağlantı, so tunnel is carrying traffic, but bu iPhone değil listening on its eşleme pveyat, although Developer Mode is on. Pair bu iPhone yeniden under “Eşleme dosyası”, sonryeniden dene. If it still fails, restart iPhone.",
    "Start LocalDevVPN when needed": "Gerektiğinde LocalDevVPN'i başlat",
    "Start LocalDevVPN now": "LocalDevVPN'i şimdi başlat",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "LocalDevVPN yüklü değil. App Store'dan al; bu senin için başlatabilir.",
    "Downloaded IPAs": "İndirilen IPA'lar",
    "%@ used": "%@ kullanıldı",
    "imported": "içe aktared",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "İndirilmiş IPA yok. Yükle sekmesinden yüklediklerin burada önbelleğe alınır.",
    "Downloaded %@": "İndired %@",
    "Added %@": "Ekleed %@",
    "Delete this download?": "Sil bu indir?",
    "Delete": "Sil",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "“%@” (%@) kaldırılacak. Yükle sekmesinden istediğin zaman yeniden indirebilirsin.",
    "Couldn't delete %@: %@": "Yapılamadı sil %@: %@",
    "Server": "Sunucu",
    "Custom…": "Özel…",
    "Server URL": "Sunucu URL",
    "Anisette Server": "Anisette sunucusu",
    "Starts with %@": "Starts ile %@",
    "Auto starts with the server that signed in last, then tries the others, the ones most likely to work first.":
        "Otomatik, en son oturum açılan sunucuyla başlar, sonra diğerlerini dener; önce çalışması en olası olanları dener.",
    "Only this server is tried. If it fails, so does sign-in: choose Auto to have SideInstaller try the others.":
        "Yalnızca bu sunucu denenir. Başarısız olursa oturum açma da başarısız olur: diğerlerini denemesi için Otomatik'i seç.",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "Yalnızca Ayarlar › Anisette sunucusu'nda seçilen sunucu denendi. Biri başarısız olunca SideInstaller'ın diğerlerini denemesi için orada Otomatik'i seç.",
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
        "İkisi de bu iPhone'a zaten çalışan bir bağlantı ister: LocalDevVPN artı bir eşleme dosyası (örneğin iOS 17.4–26'da içe aktarılmış biri). iOS 27'de bağlantının kendisi Geliştirici Modu ister; bu yüzden orada eksik bir seçeneği geri getiremezler.",
    "Turn on Developer Mode?": "Geliştirici Modu açılsın mı?",
    "Turn On and Restart": "Turn On ve Restart",
    "This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode.":
        "Bu iPhone hemen yeniden başlar. Kilit açtıktan sonra görünen uyarıda Aç'a dokun. iOS bunu yalnızca iPhone'da parola yokken izin verir.",
    "Developer Mode is already on.": "Geliştirici Modu zaten açık.",
    "Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.":
        "Geliştirici Modu artık Ayarlar › Gizlilik ve Güvenlik'te, altlara doğru görünür. Oradan aç; bitirmek için iOS yeniden başlar.",
    "Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.":
        "Developer Mode is set to turn on, ve bu iPhone restarts now. Once you unlock it, tap Turn On.",
    "An install is already running. Wait for it to finish, then try again.":
        "Bir yükleme zaten sürüyor. Bitmesini bekle, sonra yeniden dene.",
    "iOS turns Developer Mode on from here only while this iPhone has no passcode. Tap “Show Developer Mode in Settings” and turn it on there instead.":
        "iOS, Geliştirici Modu'nu buradan yalnızca bu iPhone'da parola yokken açar. Bunun yerine “Ayarlar'da Geliştirici Modu'nu göster”e dokunup oradan aç.",
    "This iPhone didn't take the Developer Mode request: %@": "Bu iPhone yapmadı take Developer Mode request: %@",
    // MARK: - Release channels & downloads

    "Stable": "Kararlı",
    "Nightly": "Gecelik",
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
        "%@ olarak inen şey bir IPA değil — bu ağda bir sayfa döndü veya aktarım yarıda kaldı.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "şu bağlantı answered HTTP %d — it değil direct indir, veyit needs sign-in.",
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
    "%@ isn't installed yet — install must run first.": "%@ henüz yüklü değil — önce yükleme çalışmalı.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ geçerli bir IPA değil — indiği kaynak muhtemelen hata sayfası döndü veya kopya yarıda kaldı. Değiştir ve Yükle'ye yeniden dokun.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ bir IPA değil. .ipa dosyasının kendisini seç — doğru görünüyorsa indirme hata sayfası kaydetmiş veya yarıda kalmış olabilir.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Henüz IPA içe aktarılmadı. “.ipa içe aktar”a dokun ve bir tane seç.",
    "Couldn't import %@: %@": "Yapılamadı içe aktar %@: %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "Bu, SideInstaller'ın indirebileceği bir bağlantı değil. .ipa'nın indirildiği tam https:// adresini yapıştır.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "Şu bağlantı yapmadı return IPA. It has to indir dosyitself — page şu only bağlantıs to .ipa, veyone şu asks you to sign in önce, arrives buradas web page.",
    "Couldn't download that link: %@": "Yapılamadı indir şu bağlantı: %@",
    "there's nothing to download for a custom IPA — import one first":
        "var nothing to indir için custom IP— içe aktar one önce",
    "your app": "senin uygulama",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple bu Apple kimliği için imzalama sertifikası vermiyor: zaten bir tane olduğunu veya isteğin hâlâ beklemede olduğunu bildiriyor (hata 7460). SideInstaller oradaki sertifikayı yeniden kullanamadı, bu yüzden değiştirmek yerine durdu. Yukarıdaki adımlara bak.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Bu iPhone%@ Apple kimliğinin geliştirici ekibine kaydedilemedi; Apple sağlama profili vermiyor. %@ — yukarıdaki adımlara bak.",
    "Connect to Wi-Fi": "Wi-Fi'ye bağlan",
    "Open Settings › Wi-Fi and join a network.": "Aç Ayarlar › Wi-Fi ve join ağ.",
    "Then come back here — this continues automatically.": "Sonra buraya dön — bu otomatik devam eder.",
    "Tap Connect so the toggle turns on.": "Tap Connect so toggle turns on.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Wi-Fi'yi açık tut, sonra buraya dön — bu otomatik devam eder.",
    "Get LocalDevVPN": "LocalDevVPN al",
    "Import an .ipa first": "İçe aktar .ipönce",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Yukarıda “.ipa içe aktar”a dokun ve dosyayı seç — Dosyalar uygulamasının erişebildiği her yerde olabilir; iCloud Drive veya USB sürücü dahil.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "Veya o düğmenin altında doğrudan indirme bağlantısı yapıştır; SideInstaller .ipa'yı kendisi alır.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "Veya Dosyalar uygulamasını aç, .ipa'ya basılı tut, Paylaş'a dokun ve SideInstaller'ı seç — seçici olmadan dosyayı iletir.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "Veya Dosyalar › iPhone'umda › SideInstaller'a kopyala; SideInstaller orada da bulur.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "Bu is way in wburadGitHub is blocked: fetch IPon any cihaz, bring it over, ve yükle it burada.",
    "Bring the .ipa yourself": "Bring .ipseninself",
    "%@ can't be downloaded while its GitHub repository is offline. The other apps still install as usual.":
        "%@ yapılamaz be indired while its GitHub repositveyay is offline. or uygulamas still yükle as usual.",
    "To install it anyway, get its .ipa from somewhere you trust, name it %@, and copy it into Files › On My iPhone › SideInstaller.":
        "Yine de yüklemek için .ipa'sını güvendiğin bir yerden al, adını %@ koy ve Dosyalar › iPhone'umda › SideInstaller'a kopyala.",
    "Then tap Install again — SideInstaller uses your file instead of downloading one.":
        "Sonra Yükle'ye yeniden dokun — SideInstaller indirmek yerine senin dosyanı kullanır.",
    "If you reach GitHub through a VPN or proxy app, turn off LocalDevVPN and turn that one on: iOS runs only one VPN at a time.":
        "If you reach GitHub through VPN veyproxy uygulama, turn off LocalDevVPN ve turn şu one on: iOS runs only one VPN at time.",
    "Tap “Get the .ipa” below and save the file, or download it on another device and bring it over.":
        "Aşağıda “.ipa'yı al”a dokunup dosyayı kaydet veya başka cihazda indirip buraya getir.",
    "Back in SideInstaller, pick Custom .ipa under Install, tap “Import .ipa” and choose the file. SideInstaller recognizes %@ and sets it up just like its own download.":
        "SideInstaller'a dön, Yükle altında Özel .ipa'yı seç, “.ipa içe aktar”a dokun ve dosyayı seç. SideInstaller %@ olarak tanır ve kendi indirmesi gibi kurar.",
    "Turn LocalDevVPN back on, then tap Install.": "LocalDevVPN'i yeniden aç, sonra Yükle'ye dokun.",
    "Get the .ipa": "Get .ipa",
    "Pair this iPhone in Settings": "Pair bu iPhone in Ayarlar",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Aç Ayarlar uygulama, sonrgo to Privacy & Security › Developer Mode.",
    "Tap “Pair with SideInstaller”.": "“SideInstaller ile eşle”ye dokun.",
    "Enter your iPhone’s passcode if it asks for it.": "Enter senin iPhone’s passcode if it asks için it.",
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

    "Installing %@": "Yükleing %@",
    "Paused": "Duraklatıldı",
    "Open SideInstaller to finish the install.": "Yüklemeyi bitirmek için SideInstaller'ı aç.",
    "Check the App IDs it needs, then tap Install.": "İhtiyacı olan App ID'leri kontrol et, sonra Yükle'ye dokun.",
    "Tap Trust": "Güven'e dokun",
    "Unlock this iPhone and tap Trust when it asks.": "Unlock bu iPhone ve tap Trust when it asks.",
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
    "Then tap Install again.": "Sonrtap Yükle yeniden.",
    "Open iForgot": "Aç iİçingot",
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
    "Every app SideInstaller signs needs an App ID, which its extensions share. A free Apple ID can register 10 a week, and each one counts for 7 days.":
        "SideInstaller'ın imzaladığı her uygulama bir App ID ister; uzantıları da onu paylaşır. Ücretsiz Apple kimliği haftada 10 tane kaydedebilir ve her biri 7 gün sayılır.",
    "They can't be deleted sooner. Wait until some expire, then tap Install again.":
        "Daha erken silinemezler. Bazılarının süresi dolana kadar bekle, sonra Yükle'ye yeniden dokun.",
    "Or sign in with a different (or spare) Apple ID in Settings › Account, then tap Install again.":
        "Veya Ayarlar › Hesap'ta farklı (veya yedek) bir Apple kimliğiyle oturum aç, sonra Yükle'ye yeniden dokun.",
    "Three sideloaded apps already": "Three sideloaded uygulamas already",
    "iOS allows three apps signed with a free Apple ID on an iPhone at a time, and it refused a fourth.":
        "iOS bir iPhone'da ücretsiz Apple kimliğiyle imzalanmış en fazla üç uygulamaya izin verir ve dördüncüyü reddetti.",
    "Expired apps count too. Delete one you no longer need from the Home Screen.":
        "Expired uygulamas count too. Sil one you no longer need şurad Home Screen.",
    // Guide: import a pairing file

    "Import a pairing file": "İçe aktar eşleme dosyası",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@ is önce version iPhone cpair ile itself on. On bu one eşleme dosyası has to be made on computer.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "Mac, Windows PC veya Linux bilgisayarda bu iPhone'u bağla, bilgisayara güven ve jitterbugpair (veya “pymobiledevice3 lockdown pair”) çalıştır.",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "Send dosyit writes — .mobilecihazeşleme vey.plist — to bu iPhone, by AirDrop, iCloud Drive veycable.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "Buraya dön, “Eşleme dosyasını içe aktar”a dokun ve dosyayı seç. Ondan sonrası iOS %@ üzerindeki gibi çalışır.",
    "Get jitterbugpair": "jitterbugpair al",
    "From iOS 26.4 on it has to be a remote pairing file: this iPhone hangs up on lockdown ones, like jitterbugpair's, when they come through LocalDevVPN.":
        "ŞuradiOS 26.4 on it has to be remote eşleme dosyası: bu iPhone hangs up on lockdown ones, like jitterbugpair's, when y come through LocalDevVPN.",
    "Get idevice_pair": "idevice_pair al",
    "Make a remote pairing file": "Make remote eşleme dosyası",
    "The pairing file you imported is a lockdown one. Since iOS 26.4, this iPhone hangs up on those when they come through LocalDevVPN, so it can't connect, and a new one of the same kind won't either.":
        "İçe aktardığın eşleme dosyası bir lockdown dosyası. iOS 26.4'ten beri bu iPhone, LocalDevVPN üzerinden gelen bu tür dosyalarda bağlantıyı keser; bağlanamaz ve aynı türden yenisi de işe yaramaz.",
    "Come back here, tap “Replace” on the Pairing file card, and pick it.":
        "Buraya dön, Eşleme dosyası kartında “Değiştir”e dokun ve dosyayı seç.",
    "On a Mac, Windows PC or Linux box, open idevice_pair, plug this iPhone in, and tap Trust if it asks. Pick it, choose “Remote pairing”, click “Create”, and keep this iPhone unlocked until it's done.":
        "Mac, Windows PC veya Linux bilgisayarda idevice_pair'i aç, bu iPhone'u bağla ve isterse Güven'e dokun. Seç, “Remote pairing”i seç, “Create”e tıkla ve bitene kadar bu iPhone'un kilidini açık tut.",
    "Click “Save to file…” and send the file to this iPhone, by AirDrop, iCloud Drive or a cable. A pairing file exported from iLoader works too.":
        "“Save to file…”e tıkla ve dosyayı AirDrop, iCloud Drive veya kabloyla bu iPhone'a gönder. iLoader'dan dışa aktarılmış eşleme dosyası da çalışır.",
    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "Bir sertifika zaten var",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple bu Apple kimliği için ikinci bir imzalama sertifikası vermez. Zaten olanı iptal etmek yüklemenin sürmesini sağlar — ama geri alınamaz.",
    "Loading certificates": "Loading sertifikas",
    "Revoke and retry": "İptal et ve retry",
    "Which certificate should be revoked?": "Which sertifikshould be iptal etd?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple bu Apple kimliğinde bir sertifika olduğunu bildiriyor ama listede hiçbiri gelmedi. Hâlâ beklemede olan bir istek olabilir — birkaç dakika bekle ve Yükle'ye yeniden dokun.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "Seçtiğin sertifikayla imzalanmış her uygulama, her cihazda açılmayı bırakır — AltStore, SideStore veya bilgisayarla yüklenenler dahil. Bu geri alınamaz. Yükleme hemen ardından yeniden dener.",
    " (expired)": "(expired)",
    "Couldn't register this device": "Yapılamadı register bu cihaz",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Apple kimliğin kayıtlı cihaz sınırına ulaştı. Ücretsiz hesaplar yılda yalnızca birkaç cihaz kaydedebilir ve yıl sıfırlanana kadar eskileri kaldıramaz.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "En kolay çözüm: yukarıdaki alanlara farklı (veya yedek) bir Apple kimliği yaz, sonra Yükle'ye yeniden dokun.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller bu iPhone'u Apple kimliğinin geliştirici ekibine otomatik ekleyemedi. Yükle'ye yeniden dokunmak sıkça işe yarar — Apple'ın geliştirici hizmeti bazen kısa süre kullanılamaz.",
    "If it keeps failing, add the device by hand. Its UDID is:": "If it keeps failing, ekle cihaz by hve. Its UDID is:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Bunu Apple Developer portalındaki “Register a Device” formuna yapıştır (ücretli Apple Developer hesabı gerekir), sonra Yükle'ye yeniden dokun.",
    "Open device list": "Aç cihaz list",
    "Last step: trust %@": "Son adım: %@ için güven",
    "Open Settings › General › VPN & Device Management.": "Aç Ayarlar › General › VPN & Cihaz Management.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "“Geliştirici Uygulaması” altındaki Apple kimliğine dokun, sonra Güven'e dokun.",
    "Open %@ from your Home Screen — you're done.": "Aç %@ şuradsenin Home Screen — sen done.",
    "Import the certificate into LiveContainer": "İçe aktar sertifikinto LiveContainer",
    "Open LiveContainer from your Home Screen.": "Aç LiveContainer şuradsenin Home Screen.",
    "Tap the Settings tab.": "Tap Ayarlar tab.",
    "Tap “Import Certificate From SideStore”.": "“SideStore'dan Sertifika İçe Aktar”a dokun.",
    "Wrong device IP": "Wrong cihaz IP",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "Ayarlar › Gelişmiş › Cihaz IP'deki adres bu iPhone'un zaten sahip olduğu bir adres; diğer uçta bağlanacak bir şey yok.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "Varsayılan 10.7.0.1 değerine geri al. LocalDevVPN'de bu, Ayarlar › Cihaz IP altındaki değerdir — ana ekrandaki adres değil; o tünelin kendi ucudur.",
    "If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one.":
        "LocalDevVPN adreslerini değiştirdiysen, Cihaz IP'sini buraya kopyala — /32 gösteriyorsa onu da ekle.",
    "Device IP is %@, one of this iPhone's own addresses, and iOS won't let an app connect to those. In Settings › Advanced, set Device IP to the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default, not the “Connected to” address on its main screen.":
        "Cihaz IP %@ — bu iPhone'un kendi adreslerinden biri ve iOS bir uygulamanın bunlara bağlanmasına izin vermez. Ayarlar › Gelişmiş'te Cihaz IP'yi LocalDevVPN'in Ayarlar › Cihaz IP altındaki adresine ayarla: varsayılan 10.7.0.1; ana ekrandaki “Bağlı” adresi değil.",
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "iOS, bu iPhone'da %@ adresine bağlantıyı bir şey gönderilmeden reddetti. Bunu bu iPhone'un kendi adresleri için yapar; örneğin LocalDevVPN ana ekranındaki “Bağlı” adresi. Ayarlar › Gelişmiş'teki Cihaz IP, LocalDevVPN'in Ayarlar › Cihaz IP altındaki adres olmalı: varsayılan 10.7.0.1. Zaten öyleyse LocalDevVPN'i kapatıp aç, sonra yeniden dene.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "Bu iPhone hung up on bağlantı as soon as it açed. ŞuradiOS 26.4 on it does şu to lockdown eşleme dosyasıs, like bu one, when y come through LocalDevVPN. Pair bu iPhone ile itself instead: tap “Regenerate” under Tools › Eşleme, veytap Yükle, which pairs it önce.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "Bu iPhone bağlantı açılır açılmaz kesti. iOS 26.4'ten beri LocalDevVPN üzerinden gelen lockdown eşleme dosyalarında (bunun gibi) bunu yapar; aynı türden yenisi yardımcı olmaz. Uzaktan eşleme dosyası hâlâ çalışır: bilgisayarda idevice_pair'i aç, “Remote pairing” seç, “Create” sonra “Save to file…”e tıkla ve dosyayı “Eşleme dosyası” altında içe aktar.",
    "This iPhone hung up on the connection: from iOS 26.4 on, it does that to lockdown pairing files like this one when they come through LocalDevVPN. See the steps above.":
        "Bu iPhone hung up on bağlantı: şuradiOS 26.4 on, it does şu to lockdown eşleme dosyasıs like bu one when y come through LocalDevVPN. See steps above.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Bu iPhone'u eşlemek için gerekir: SideInstaller, Ayarlar'ın bulması için kendini yerel ağda duyurur.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Bir Wi-Fi ağına bağlan. Bu iPhone'u eşlemek için gerekir — SideInstaller yerel ağda bulunabilir olmalı.",
    // MARK: - About

    "About": "Hakkında",
    "Version %@ (%@)": "Sürüm %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller, bilgisayar olmadan SideStore ve LiveContainer'ı doğrudan iPhone'una yükler.",
    "Links": "Bağlantılar",
    "Source code": "Kaynak kodu",
    "Support the project": "Projeyi destekle",
    "Crypto": "Kripto",
    "Donation wallets for Bitcoin, Ethereum and Solana.": "Bitcoin, Ethereum ve Solana bağış cüzdanları.",
    "Crypto donations": "Kripto bağışları",
    "Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you.":
        "Bağışlar tamamen isteğe bağlıdır. Bir şey satın almaz, özellik açmaz veya karşılığında bir şey vermez; SideInstaller yardımcı olduysa teşekkür etmenin bir yoludur.",
    "Coin": "Coin",
    "Network: %@": "Ağ: %@",
    "QR code for the %@ address": "%@ adresi için QR kodu",
    "Copied": "Kopyalandı",
    "Send each coin only on the network shown. Crypto sent on another network can't be recovered.":
        "Send each coin only on ağ shown. Crypto sent on anor ağ yapılamaz be recovered.",
    "Special thanks": "Özel teşekkürler",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "idevice için — SideInstaller'ın iPhone'unla konuştuğu kütüphane. O olmadan bunların hiçbiri olmazdı.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Destek için ve sayesinde düzeltilen hataları bulduğu için.",
    "For the Japanese translation.": "Japonca çeviri için.",
    "For the Korean translation.": "Korece çeviri için.",
    "Built with": "Bunlarla yapıldı",
    "The open source work this app is built on:": "Bu uygulamanın üzerine kurulduğu açık kaynak çalışmalar:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "Eşleme, tünel ve yüklemenin kendisi. jkcoxson, MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Apple kimliği oturum açma, sertifikalar ve cihazda imzalama. nab138, MIT.",
    "The sideloading app this installs for you.": "Senin için yüklediği yan yükleme uygulaması.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Yan yüklenen uygulamaları her biri için uygulama yuvası harcamadan çalıştırır.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "Geliştirici disk görüntüsü konum taklidi bağlama noktaları. doronz88 tarafından yansıtıldı.",
    "Where to get it": "Nereden alınır",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "Yalnızca resmi yükleme sayfası ve depodaki derlemeler bana aittir. Herkes kaynağı çatallayıp kimlik bilgisi çalan bir şey ekleyip aynı ad ve simgeyle yayınlayabilir — bu yüzden Apple kimliğini başka yerden gelen bir kopyaya emanet etme.",
    "Install page": "Yükleme sayfası",
    "Terms": "Koşullar",
    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.": "%@ needs iOS %d veylater. Bu iPhone runs iOS %@.",
    "Open Madeira from your Home Screen.": "Aç Madeirşuradsenin Home Screen.",
    "In its setup, under “Set up JIT”, pick “In-app with pairing file”: SideInstaller already put the file there, so tap “Continue”.":
        "Kurulumunda “Set up JIT” altında “In-app with pairing file” seç: SideInstaller dosyayı zaten oraya koydu, “Continue”e dokun.",
    "In its setup, under “Set up JIT”, pick how this iPhone gets JIT.":
        "In its setup, under “Set up JIT”, pick how bu iPhone gets JIT.",
    "Madeira renews its own signing from now on, when it's open and LocalDevVPN is connected. SideInstaller gave it a sign-in for that: a token for Apple's developer service, not your password. Madeira can forget it under Settings › Signing.":
        "Madeira bundan sonra kendi imzasını yeniler; açıkken ve LocalDevVPN bağlıyken. SideInstaller bunun için bir oturum verdi: Apple'ın geliştirici hizmeti için jeton, parolan değil. Madeira Ayarlar › İmzalama altında bunu unutabilir.",
    "Its signing lasts 7 days. Before they run out, refresh it here under Tools › Sideloaded apps.":
        "Its imzalamlasts 7 days. Beiçine y run out, yenile it buradunder Tools › Sideloaded uygulamas.",
    "This pairing file has no RPPairing record, the only kind %@ reads.":
        "Bu eşleme dosyasında RPPairing kaydı yok; %@'nin okuduğu tek tür o.",
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
    "The next one frees up on %@.": "next one frees up on %@.",
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
    "It replaces %@, the custom .ipa you have now.": "It replaces %@, custom .ipyou have now.",
    "Use SideStore's pairing file?": "SideStore'un eşleme dosyası kullanılsın mı?",
    "Import this pairing file?": "Bu eşleme dosyası içe aktarılsın mı?",
    "Import": "İçe aktar",
    "SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.":
        "SideStore elindeki eşleme dosyasını geri gönderdi. SideInstaller bu iPhone'a onunla bağlanacak.",
    "A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.":
        "Bir bağlantı SideInstaller'a eşleme dosyası gönderdi. Yalnızca sen istediysen içe aktar: SideInstaller bu iPhone'a onunla bağlanacak.",
    "It replaces %@.": "%@ yerine geçer.",
    "It replaces the pairing file in use now.": "It replaces eşleme dosyası in use now.",
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
    "Auto, starts with %@": "Otomatik, %@ ile başlar",
    "Error": "Error",
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
]
