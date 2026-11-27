import Foundation

/// French translations (same rules as `spanishStrings`). Uses formal "vous" and
/// iOS's French UI terms.

let frenchStrings: [String: String] = [

    // MARK: - Shared

    "Expiry date": "Date d'expiration",
    "Signed date": "Date de signature",
    "Bundle ID": "Bundle ID",
    "Not enough free space on this iPhone to download this IPA — it needs %@, but only %@ is free. Free some space and try again.":
        "Pas assez d'espace libre sur cet iPhone pour télécharger cet IPA : il faut %@, mais il ne reste que %@. Libérez de l'espace puis réessayez.",
    "Free space: %@": "Espace libre : %@",
    "Apple ID":
        "Apple ID",
    "Cancel": "Annuler",
    "Copy": "Copier",
    "Copy logs": "Copier les journaux",
    "Email": "E-mail",
    "No unsigned IPA in the library.":
        "Aucun IPA non signé dans la bibliothèque.",
    "Once the install starts, tap the Install button at the bottom to see progress.":
        "Une fois l'installation lancée, touchez le bouton Installer en bas pour voir la progression.",
    "Password": "Mot de passe",
    "Install": "Installer",
    // U-UI (0.9.102): new tab bar / source + file list redesign.
    "Apps": "Apps",
    "Pick an IPA to install with your Apple ID.":
        "Choisissez un IPA à installer avec votre identifiant Apple.",
    "Signing method":
        "Méthode de signature",
    "Sources": "Sources",
    "AppStore": "AppStore",
    "企业证书":
        "Certificat d'entreprise",
    "用 Apple ID 安装":
        "Installer avec votre identifiant Apple",
    "软件源": "Sources logicielles",
    "文件列表": "Liste des fichiers",
    "筛选": "Filtrer",
    "正在刷新数据中…": "Actualisation des données…",
    "最后更新：%@": "Dernière mise à jour : %@",
    "应用文件夹库": "Bibliothèque d'apps",
    "应用 - %@": "App - %@",
    "No downloaded IPAs. Ones you install from a source or a file are cached here.": "Aucun IPA téléchargé. Ceux installés depuis une source ou un fichier sont mis en cache ici.",
    "%d 个 IPA · %@": "%d IPA · %@",
    "清空全部": "Tout effacer",
    "清空全部 %d 个下载？": "Effacer les %d téléchargements ?",
    "还没有文件。点上面「导入文件」放 IPA 进来，或在源页面下载后这里会出现。": "Aucun fichier. Touchez « Importer » ci-dessus pour ajouter un IPA, ou téléchargez-en un depuis la page des sources.",
    "文件库里还没有没签过的 IPA。去文件页导入一个，或者去设置里的企业证书页点「从文件导入」。": "Aucun IPA non signé dans la bibliothèque. Importez-en un depuis la page Fichiers, ou touchez « Importer un fichier » sur la page des certificats d'entreprise dans Réglages.",
    "先去设置里的企业证书页，把证书、描述文件和密码备齐。": "Préparez d'abord le certificat, le profil et le mot de passe dans le groupe de certificats de la page des certificats d'entreprise dans Réglages.",
    "还没有已签名的 IPA。用设置里企业证书页的「仅签名」签好就会存到这里，随时能装、能分享。": "Aucun IPA signé pour l'instant. Signez-en un avec « Signer seulement » sur la page des certificats d'entreprise dans Réglages : il sera stocké ici, prêt à installer et à partager.",
    "Installing": "Installation en cours",
    "Installed": "Installé",
    "Install history": "Historique des installations",
    "No installs yet.": "Aucune installation pour l’instant.",
    "Something went wrong": "Une erreur s'est produite",
    "an app by Frizzle": "une app de Frizzle",
    "device": "appareil",

    // MARK: - Welcome

    "I have accepted the": "J'accepte les",
    "Start": "Commencer",

    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "Il vous faudra un fichier de jumelage",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "Cet iPhone est sous iOS %@. Seul iOS %@ peut se jumeler tout seul : vous devrez créer un fichier de jumelage sur un ordinateur — avec jitterbugpair ou pymobiledevice3 — puis l'importer dans l'app. SideInstaller vous guide pas à pas.",

    // iOS 27 runs on this iPhone: recommended at setup

    "Update to iOS %@": "Passez à iOS %@",
    "This iPhone can run iOS %@, where SideInstaller works without a computer: the iPhone pairs with itself, so there's no pairing file to make. Update in Settings › General › Software Update.":
        "Cet iPhone peut passer à iOS %@, où SideInstaller fonctionne sans ordinateur : l'iPhone se jumelle tout seul, donc aucun fichier de jumelage à créer. Mettez à jour dans Réglages › Général › Mise à jour logicielle.",
    "OK": "OK",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "Connectez-vous avec votre Apple ID",
    "Don't worry, these are stored locally":
        "Pas d'inquiétude, tout reste stocké sur cet iPhone",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "Enregistré dans le trousseau de cet iPhone, et envoyé uniquement à Apple lors de la connexion.",
    "Continue": "Continuer",
    "Set this up later": "Configurer plus tard",
    "Add Apple ID": "Ajouter un Apple ID",
    "Edit Apple ID": "Modifier l'Apple ID",
    "Save": "Enregistrer",
    "Enter the password again to save this Apple ID.":
        "Saisissez à nouveau le mot de passe pour enregistrer cet Apple ID.",
    "Account": "Compte",
    "In use": "Utilisé",
    "Edit": "Modifier",
    "Remove": "Supprimer",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "Aucun Apple ID enregistré. Ajoutez-en un et SideInstaller l'utilisera à chaque connexion.",
    "Remove this Apple ID?": "Supprimer cet Apple ID ?",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "« %@ » et son mot de passe enregistré seront supprimés de cet iPhone. Votre compte Apple reste inchangé.",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "Le trousseau de cet iPhone a refusé d'enregistrer le mot de passe (erreur %d) : il n'est conservé que tant que SideInstaller est ouvert.",
    "No Apple ID saved. Add one in Settings › Account.":
        "Aucun Apple ID enregistré. Ajoutez-en un dans Réglages › Compte.",

    "Add your Apple ID": "Ajoutez votre Apple ID",
    "Open Settings with the gear at the top right.":
        "Ouvrez les Réglages avec la roue dentée en haut à droite.",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "Dans la section Compte, touchez « Ajouter un Apple ID » et saisissez votre e-mail et votre mot de passe.",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "Outils",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "Jumelage",
    "Certificates": "Certificats",
    "Two-Factor Code": "Code de validation",
    "6-digit code": "Code à 6 chiffres",
    "Enter the code Apple just sent to your trusted device.":
        "Saisissez le code qu'Apple vient d'envoyer à votre appareil de confiance.",
    "Enter the code Apple texted to %@.":
        "Saisissez le code qu'Apple a envoyé par SMS au %@.",
    "Enter the code Apple texted to your phone.":
        "Saisissez le code qu'Apple a envoyé par SMS à votre téléphone.",
    "Apple is calling %@. Enter the code you hear.":
        "Apple appelle le %@. Saisissez le code que vous entendez.",
    "Apple is calling your phone. Enter the code you hear.":
        "Apple appelle votre téléphone. Saisissez le code que vous entendez.",
    "Choose how Apple should send your verification code.":
        "Choisissez comment Apple doit vous envoyer le code de vérification.",
    "Choose How to Get a Code":
        "Choisir comment recevoir le code",
    "Verify":
        "Vérifier",
    "Didn't get it?":
        "Vous ne l'avez pas reçu ?",
    "Send a new code to my devices":
        "Envoyer un nouveau code sur mes appareils",
    "Text me a new code":
        "M'envoyer un nouveau code par SMS",
    "Call me again":
        "M'appeler à nouveau",
    "Send a code to my Apple devices":
        "Envoyer un code sur mes appareils Apple",
    "Text %@":
        "SMS au %@",
    "Call %@":
        "Appeler le %@",
    "Checking the code…":
        "Vérification du code…",
    "Requesting a new code…":
        "Demande d'un nouveau code…",
    "Sending a code to your devices…":
        "Envoi d'un code sur vos appareils…",
    "Texting a code to %@…":
        "Envoi du code par SMS au %@…",
    "Calling %@…":
        "Appel du %@…",

    // MARK: - Install tab

    "Tunnel connected": "Tunnel connecté",
    "Tunnel off": "Tunnel désactivé",
    "Update available": "Mise à jour disponible",
    "SideInstaller %@ is still being published — try again later.": "SideInstaller %@ est toujours en cours de publication — réessayez plus tard.",
    "SideInstaller %@ is available — you're on %@.":
        "SideInstaller %@ est disponible — vous utilisez la %@.",
    "Get the latest version": "Obtenir la dernière version",
    "Release": "Canal",
    "Reinstall": "Réinstaller",
    "Install %@": "Installer %@",
    "Custom .ipa": "IPA personnalisé",
    "Import .ipa": "Importer un .ipa",
    "Importing…": "Importation…",
    "Replace": "Remplacer",
    "or": "ou",
    "Paste a download link": "Collez un lien de téléchargement",
    "SideInstaller recognizes this as %@ and sets it up just like its own download.":
        "SideInstaller reconnaît ici %@ et le configure comme s'il l'avait téléchargé lui-même.",
    "Downloading… %d%%": "Téléchargement… %d%%",
    "Downloading": "Téléchargement en cours",
    "Queued": "En file d’attente",
    "iOS %@ required": "iOS %@ requis",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Cet iPhone est sous iOS %@, sur lequel SideInstaller ne peut rien installer. Mettez à jour vers iOS %@ ou une version ultérieure dans Réglages › Général › Mise à jour logicielle.",
    "Wi-Fi required": "Wi-Fi requis",
    "Pairing code": "Code de jumelage",
    "Type this into the prompt in Settings.":
        "Saisissez ce code dans la demande affichée dans Réglages.",
    "Install stopped": "Installation interrompue",
    "Close": "Fermer",
    "Yes": "Oui",
    "No": "Non",
    "Closing this popup will end the process. Are you sure?":
        "Fermer cette fenêtre arrêtera le processus. Voulez-vous continuer ?",
    "Cancel the install?": "Annuler l'installation ?",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ est installé. Terminez l'étape de confiance ci-dessus pour l'ouvrir.",
    "%@ is installed. Finish the trust step below to open it.":
        "%@ est installé. Terminez l'étape de confiance ci-dessous pour l'ouvrir.",
    "Success: last steps": "Terminé : dernières étapes",
    "Action needed": "Action requise",
    "Step %@ of %@": "Étape %@ sur %@",
    "Show all steps": "Afficher toutes les étapes",
    "Show fewer steps": "Afficher moins d'étapes",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "LocalDevVPN requis",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "Installe LocalDevVPN et connecte-le. L'installation passe par son tunnel.",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Connecte LocalDevVPN pour chercher et installer. L'écriture passe par son tunnel.",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "Connecte LocalDevVPN. La simulation passe par son tunnel, comme tout le reste ici.",
    "LocalDevVPN isn't connected. Connect it, then try again.":
        "LocalDevVPN n'est pas connecté. Connecte-le, puis réessaie.",
    "No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.": "Aucun VPN de bouclage n’est connecté et le démarrage automatique du tunnel est désactivé. Activez « Démarrer LocalDevVPN si nécessaire » dans Réglages, puis touchez à nouveau Installer.",
    "Connect LocalDevVPN": "Connecte LocalDevVPN",
    "Install LocalDevVPN from the App Store and open it.":
        "Installe LocalDevVPN depuis l'App Store et ouvre-le.",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Si GitHub est bloqué là où tu es, utilise un VPN qui peut aussi acheminer ton trafic : iOS n'exécute qu'un VPN à la fois, donc un tunnel purement local ne laisse rien pour télécharger SideStore.",

    // MARK: - Install steps

    "Connect the VPN": "Connecter le VPN",
    "Get pairing file": "Obtenir le fichier de jumelage",
    "Open the device link": "Ouvrir la liaison avec l'appareil",
    "Sign in to Apple ID": "Se connecter à l'Apple ID",
    "Download %@": "Télécharger %@",
    "Use your imported IPA": "Utiliser votre IPA importé",
    "Use a custom .ipa instead": "Utiliser plutôt un .ipa personnalisé",
    "Pick an .ipa to install.": "Choisissez le .ipa à installer.",
    "Signed with the Apple ID and installed as it is, without a pairing file.": "Signé avec l'Apple ID et installé tel quel, sans fichier de jumelage.",
    "Open %@.": "Ouvrez %@.",
    "Sign the app": "Signer l'app",
    "Finish setup": "Terminer la configuration",

    // MARK: - Pairing tab

    "Pairing file ready": "Fichier de jumelage prêt",
    "No pairing file": "Aucun fichier de jumelage",
    "Pairing file": "Fichier de jumelage",
    "Pairing file is being generated. Wait for it to finish, then try again.": "Le fichier de jumelage est en cours de génération. Attendez qu’il soit terminé, puis réessayez.",
    "Pairing…": "Jumelage…",
    "Regenerate": "Régénérer",
    "Generate pairing file": "Générer le fichier de jumelage",
    "Export pairing file": "Exporter le fichier de jumelage",
    "Pair in Settings": "Jumeler dans Réglages",
    "Install into an app": "Installer dans une app",
    "Scanning": "Recherche",
    "Rescan apps": "Rechercher à nouveau",
    "Scan installed apps": "Rechercher les apps installées",
    "%d supported app installed": "%d app compatible installée",
    "%d supported apps installed": "%d apps compatibles installées",
    "No supported apps found": "Aucune app compatible trouvée",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Installez d'abord une app comme SideStore, StikDebug ou Feather, puis relancez la recherche.",
    "Install pairing": "Installer le jumelage",
    "Pairing file ready. You can export it or install it into an app below.":
        "Fichier de jumelage prêt. Vous pouvez l'exporter ou l'installer dans une app ci-dessous.",
    "Pairing file installed into %@.": "Fichier de jumelage installé dans %@.",
    "Install pairing into all apps": "Installer le jumelage dans toutes les apps",
    "Installing into all apps": "Installation dans toutes les apps",
    "Pairing file installed into all %d apps.": "Fichier de jumelage installé dans les %d apps.",
    "Couldn't write into %@.": "Impossible d'écrire dans %@.",
    "The %@ record isn't a plist dictionary.": "L'enregistrement %@ n'est pas un dictionnaire plist.",

    // Importing a pairing file (required below iOS 27, under Advanced from 27)

    "Import pairing file": "Importer le fichier de jumelage",
    "How do I make one?": "Comment en créer un ?",
    "(Optional)": "(Facultatif)",
    "imported pairing file": "fichier de jumelage importé",
    "No pairing file yet — tap “Import pairing file” first.":
        "Aucun fichier de jumelage — touchez d'abord « Importer le fichier de jumelage ».",
    "Pairing file missing — import it first.": "Fichier de jumelage manquant : importez-le d'abord.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ n'est pas un fichier de jumelage. Choisissez le fichier créé par votre ordinateur — un .mobiledevicepairing ou .plist contenant l'enregistrement de jumelage de cet iPhone.",
    "%@ isn't installed on this iPhone, so there's nowhere to import the certificate.":
        "%@ n'est pas installé sur cet iPhone : le certificat ne peut pas y être importé.",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "iOS %@ ne peut pas créer son propre fichier de jumelage : cela demande iOS %@. Importez-en un créé sur un ordinateur dans « Fichier de jumelage », puis réessayez.",

    // MARK: - Pairing service status

    "not paired": "non jumelé",
    "connected": "connecté",
    "requesting Local Network…": "demande d'accès au réseau local…",
    "Local Network denied": "accès au réseau local refusé",
    "waiting for device…": "en attente de l'appareil…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "diffusion en cours — ouvrez Réglages › Confidentialité et sécurité › Mode développeur",
    "enter PIN %@ in Settings": "saisissez le code %@ dans Réglages",
    "paired: %@ (%dB)": "jumelé : %@ (%d o)",
    "failed: empty pairing file": "échec : fichier de jumelage vide",
    "failed: %@": "échec : %@",
    "Pairing is already in progress.": "Un jumelage est déjà en cours.",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "L'autorisation Réseau local est désactivée. Activez-la dans Réglages › SideInstaller › Réseau local, puis réessayez.",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "Le jumelage a produit un fichier vide. Vérifiez que vous avez accepté la demande de jumelage, puis réessayez.",

    // MARK: - Certificates tab

    "Revoke this certificate?": "Révoquer ce certificat ?",
    "Revoke": "Révoquer",
    "Revoking": "Révocation en cours",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "« %@ » sera révoqué. Les apps déjà signées avec ce certificat ne s'ouvriront plus sur aucun appareil. Cette action est irréversible.",
    "Apps signed with this certificate:\n%@": "Apps signées avec ce certificat :\n%@",
    "Refreshing": "Actualisation",
    "Signing in": "Connexion en cours",
    "Refresh": "Actualiser",
    "Load certificates": "Charger les certificats",
    "%d certificate(s)": "%d certificat(s)",
    "No certificates": "Aucun certificat",
    "This Apple ID has no development certificates to revoke.":
        "Cet Apple ID n'a aucun certificat de développement à révoquer.",
    "Expired": "Expiré",
    "Expires %@": "Expire le %@",
    "Unnamed certificate": "Certificat sans nom",
    "This certificate has no serial number, so it can't be revoked.":
        "Ce certificat n'a pas de numéro de série, il ne peut donc pas être révoqué.",

    // Export: the certificate SideInstaller signs with, as a .p12
    "Import to %@": "Importer dans %@",
    "Exporting": "Exportation",

    // MARK: - SideStore's certificate (sidestore://certificate)

    "Use SideStore's certificate": "Utiliser le certificat de SideStore",
    "Checking the certificate": "Vérification du certificat",
    "SideStore opens and sends back its certificate. SideInstaller then signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "SideStore s'ouvre et renvoie son certificat. SideInstaller signe ensuite aussi avec lui : avec un Apple ID gratuit, aucune des deux apps n'a plus à révoquer celui de l'autre.",
    "Apple won't issue a second signing certificate for this Apple ID. If SideStore made the one it has, SideInstaller can sign with that one too, and nothing is revoked. Revoking it lets the install continue as well — but it can't be undone.":
        "Apple n'émettra pas un second certificat de signature pour cet Apple ID. Si c'est SideStore qui a créé celui qui existe, SideInstaller peut signer avec lui aussi, sans rien révoquer. Le révoquer permet aussi de poursuivre l'installation, mais c'est irréversible.",
    "If SideStore made it, tap “Use SideStore's certificate” above: SideInstaller signs with that one too, and nothing is revoked.":
        "Si c'est SideStore qui l'a créé, touchez « Utiliser le certificat de SideStore » ci-dessus : SideInstaller signe aussi avec lui, et rien n'est révoqué.",
    "SideInstaller signs with “%@” from now on. Nothing was revoked, so the apps already signed with it keep working.":
        "SideInstaller signe désormais avec « %@ ». Rien n'a été révoqué : les apps déjà signées avec lui continuent de fonctionner.",
    "SideInstaller already signs with “%@”.": "SideInstaller signe déjà avec « %@ ».",
    "That certificate isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID (SideStore may be signed in with a different one). Nothing was changed.":
        "Ce certificat n'appartient pas à cet Apple ID : il a été révoqué, ou il appartient à un autre Apple ID (SideStore est peut-être connecté avec un autre). Rien n'a été modifié.",
    "Couldn't use that certificate: %@": "Impossible d'utiliser ce certificat : %@",
    "SideStore isn't installed on this iPhone, so there's no certificate to get from it.":
        "SideStore n'est pas installé sur cet iPhone, il n'y a donc aucun certificat à récupérer.",
    "Inside LiveContainer, SideStore can't send its certificate back to SideInstaller, and LiveContainer doesn't hold one yet. In LiveContainer's Settings, tap “Import Certificate From SideStore” (sign in to SideStore first if it has no certificate), then try again here.":
        "Dans LiveContainer, SideStore ne peut pas renvoyer son certificat à SideInstaller, et LiveContainer n'en a pas encore. Dans les Settings de LiveContainer, touchez « Import Certificate From SideStore » (connectez-vous d'abord à SideStore s'il n'a pas de certificat), puis réessayez ici.",
    "The certificate LiveContainer holds for SideStore isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID. Nothing was changed. If SideStore has made a new one since, tap “Refresh Certificate from SideStore” in LiveContainer's Settings, then try again here.":
        "Le certificat que LiveContainer garde pour SideStore n'appartient pas à cet Apple ID : il a été révoqué, ou il appartient à un autre Apple ID. Rien n'a été modifié. Si SideStore en a créé un nouveau depuis, touchez « Refresh Certificate from SideStore » dans les Settings de LiveContainer, puis réessayez ici.",
    "SideInstaller takes SideStore's certificate from LiveContainer and signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "SideInstaller récupère le certificat de SideStore dans LiveContainer et signe aussi avec lui : avec un Apple ID gratuit, aucune des deux apps n'a plus à révoquer celui de l'autre.",
    "Sign with this certificate?": "Signer avec ce certificat ?",
    "A link sent SideInstaller a signing certificate. Only use it if you asked for one: SideInstaller will sign apps with it from now on, in place of its own. It's used only if it's one of your Apple ID's certificates.":
        "Un lien a envoyé un certificat de signature à SideInstaller. Ne l'utilisez que si vous l'avez demandé : SideInstaller signera désormais les apps avec lui, à la place du sien. Il n'est utilisé que s'il fait partie des certificats de votre Apple ID.",
    "Use it": "L'utiliser",
    "That link was meant to carry a signing certificate, but what it holds can't be read.":
        "Ce lien devait contenir un certificat de signature, mais son contenu est illisible.",

    // MARK: - Location tab

    "Location spoofing": "Simulation de position",
    "Not simulating": "Aucune simulation",
    "Simulated": "Simulée",
    "Pick a place": "Choisis un lieu",
    "Search for a place": "Rechercher un lieu",
    "Nothing found for “%@”.": "Aucun résultat pour « %@ ».",
    "Set location": "Définir la position",
    "Setting": "Application",
    "Reset to real location": "Revenir à la position réelle",
    "Location set to %@.": "Position définie sur %@.",
    "Location reset. The device is using its own again.":
        "Position réinitialisée. L'appareil utilise de nouveau la sienne.",
    "That isn't a valid coordinate.": "Cette coordonnée n'est pas valide.",
    "Location session closed — set it up again.":
        "La session de position est fermée — relance la préparation.",
    "Downloading %@ failed (HTTP %d).": "Le téléchargement de %@ a échoué (HTTP %d).",
    "The download of %@ came back empty. Try again.": "Le téléchargement de %@ est arrivé vide. Réessayez.",
    "Couldn't build the download URL for %@.":
        "Impossible de construire l'URL de téléchargement pour %@.",
    "Couldn't build the certificate link.": "Impossible de construire le lien du certificat.",

    // Location › saved places and GPX routes.
    "Saved places": "Lieux enregistrés",
    "Save this place": "Enregistrer ce lieu",
    "Name": "Nom",
    "Show on map": "Voir sur la carte",
    "Tap Save under the map to keep the spot under the pin. Tapping a saved place sets it straight away.":
        "Touche Enregistrer sous la carte pour garder le point sous l'épingle. Toucher un lieu enregistré le définit aussitôt.",
    "Play a GPX route": "Lire un itinéraire GPX",
    "Import a .gpx file and the device moves along it at the speed you pick, then stays at its last point.":
        "Importe un fichier .gpx : l'appareil le parcourt à la vitesse choisie, puis reste sur le dernier point.",
    "Import GPX file": "Importer un fichier GPX",
    "Couldn't read %@ as a GPX file.": "Impossible de lire %@ comme fichier GPX.",
    "%@ has no track, route or waypoints in it.":
        "%@ ne contient ni trace, ni itinéraire, ni waypoint.",
    "As recorded": "Comme enregistré",
    "Walk": "À pied",
    "Cycle": "À vélo",
    "Drive": "En voiture",
    "Speed": "Vitesse",
    "Play route": "Lire l'itinéraire",
    "Playing route · %d%%": "Itinéraire en cours · %d %%",
    "Stop here": "Arrêter ici",
    "%@ of %@": "%@ sur %@",
    "Route finished. The device stays at its last point.":
        "Itinéraire terminé. L'appareil reste sur le dernier point.",
    "Route stopped. The device stays where it got to.":
        "Itinéraire arrêté. L'appareil reste là où il en était.",
    "Route playback stopped: %@": "Lecture de l'itinéraire interrompue : %@",
    // Location › planned routes (OpenStreetMap).
    "Add stop": "Ajouter une étape",
    "Add as stop": "Ajouter comme étape",
    "Plan a route": "Planifier un itinéraire",
    "Travel by": "Mode de déplacement",
    "Goes along each street at its speed limit, from OpenStreetMap. A street without one mapped gets the usual limit for its kind of road.":
        "Parcourt chaque rue à sa limitation de vitesse, d'après OpenStreetMap. Une rue sans limitation cartographiée prend celle habituelle pour son type de route.",
    "Rides streets and paths a bike can take, at a cycling pace.":
        "Emprunte les rues et chemins praticables à vélo, à une allure de cycliste.",
    "Walks streets and paths at a walking pace.":
        "Emprunte les rues et chemins à une allure de marche.",
    "Start where the device is": "Partir de la position de l'appareil",
    "Move the map so the pin is on a place, then tap Add stop. Add as many as you like: the route goes to each in order.":
        "Déplace la carte pour placer l'épingle sur un lieu, puis touche Ajouter une étape. Ajoutes-en autant que tu veux : l'itinéraire passe par chacune dans l'ordre.",
    "The device's location": "Position de l'appareil",
    "Stop %d": "Étape %d",
    "Clear stops": "Effacer les étapes",
    "Move up": "Monter",
    "Move down": "Descendre",
    "Find route": "Trouver l'itinéraire",
    "Finding route": "Recherche de l'itinéraire",
    "Add one more stop to plan a route.": "Ajoute une étape de plus pour planifier un itinéraire.",
    "Routes from OpenStreetMap, © OpenStreetMap contributors":
        "Itinéraires d'OpenStreetMap, © contributeurs d'OpenStreetMap",
    "Speed limits are mapped for all of it.":
        "Les limitations de vitesse sont cartographiées sur tout le trajet.",
    "Speed limits are mapped for %d%% of it; the rest is estimated.":
        "Les limitations de vitesse sont cartographiées sur %d %% du trajet ; le reste est estimé.",
    "Average %@": "Moyenne : %@",
    "Speed limit %@": "Limitation de vitesse %@",
    "No speed limit · going %@": "Pas de limitation · à %@",
    "No limit mapped · going %@": "Aucune limitation cartographiée · à %@",
    "Going %@": "À %@",
    "No street name": "Rue sans nom",
    "Estimated speed limit %@": "Limitation de vitesse estimée %@",
    "No speed limit": "Pas de limitation de vitesse",
    "No route found between these stops. Move them onto roads or paths, or travel another way.":
        "Aucun itinéraire trouvé entre ces étapes. Place-les sur des routes ou des chemins, ou change de mode de déplacement.",
    "A stop is too far from any road or path. Move it closer and try again.":
        "Une étape est trop loin de toute route ou de tout chemin. Rapproche-la et réessaie.",
    "Too many stops for the route server. Take some out and try again.":
        "Trop d'étapes pour le serveur d'itinéraires. Retires-en quelques-unes et réessaie.",
    "That route is too long for the route server. Make it shorter, or split it up.":
        "Cet itinéraire est trop long pour le serveur d'itinéraires. Raccourcis-le ou découpe-le.",
    "The route server is busy. Try again in a minute.":
        "Le serveur d'itinéraires est occupé. Réessaie dans une minute.",

    // MARK: - Entitlements tab

    "Entitlements": "Droits",
    "Load apps": "Charger les apps",
    "%d App ID": "%d App ID",
    "%d App IDs": "%d App ID",
    "No App IDs": "Aucun App ID",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "Cet Apple ID n'a encore enregistré aucune app. Installes-en une avec SideInstaller, puis reviens ici.",
    "Memory and performance": "Mémoire et performances",
    "Other free capabilities": "Autres fonctionnalités gratuites",
    "Beta": "Bêta",
    "Recommended": "Recommandés",
    "Select all": "Tout sélectionner",
    "None": "Aucun",
    "Enable %d selected": "Activer %d sélectionnés",
    "Asking Apple": "Demande à Apple",
    "%d of %d enabled": "%d sur %d activés",
    "Install the app again for these to take effect.":
        "Réinstalle l'app pour qu'ils prennent effet.",

    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "Apps sideloadées",
    "Reading the device": "Lecture de l'appareil",

    // Refresh all: signing the installed apps again.
    "iOS %@ isn't supported — SideInstaller needs iOS %@ or later.":
        "iOS %@ n'est pas pris en charge : SideInstaller nécessite iOS %@ ou une version ultérieure.",
    "An install is already running. Wait for it to finish, then refresh.":
        "Une installation est déjà en cours. Attendez qu'elle se termine, puis renouvelez.",
    "A refresh is already running. Wait for it to finish, then try again.":
        "Un renouvellement est déjà en cours. Attendez qu'il se termine, puis réessayez.",
    "A signing is already running. Wait for it to finish, then try again.":
        "Une signature est déjà en cours. Attendez qu'elle se termine, puis réessayez.",
    "Still reading the device. Try again in a moment.":
        "Lecture de l'appareil toujours en cours. Réessayez dans un instant.",
    "Load failed. Showing the last loaded list.":
        "Échec du chargement. Affichage de la dernière liste chargée.",
    "Skipped: this app stopped being refreshable after the run started. Its IPA may have been deleted.":
        "Ignoré : cette app n'était plus actualisable au début de l'opération. Son IPA a peut-être été supprimé.",
    "Skipped: this app has no team on its signing profile, so it can't be refreshed.":
        "Ignoré : le profil de signature de cette app n'a pas d'équipe, elle ne peut pas être actualisée.",
    "Revoked, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.":
        "Révoqué, mais la liste des certificats n'a pas pu être actualisée. Elle peut être obsolète jusqu'au prochain rechargement.",

    "Imported, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.":
        "Importé, mais la liste des certificats n'a pas pu être actualisée. Elle peut être obsolète jusqu'au prochain rechargement.",
    "Skipped: refresh stopped.":
        "Ignoré : actualisation arrêtée.",
    "The pairing wasn't handed over in the newer format. SideStore may ask for the pairing file.":
        "Le jumelage n'a pas été transmis dans le nouveau format. SideStore pourrait demander le fichier de jumelage.",
    "The signing certificate wasn't handed over. SideStore may ask to resign itself on first sign-in.":
        "Le certificat de signature n'a pas été transmis. SideStore pourrait demander une nouvelle signature à la première connexion.",
    "Cellular Install (OTA)":
        "Installation cellulaire (OTA)",
    "Pairing Install":
        "Installation par jumelage",
    "Upload these two files to R2, then install: %@ and %@. Upload via the WebDAV bridge https://r2-webdav.wozofa.workers.dev or the R2 console; .plist as text/xml, .ipa as application/octet-stream. After uploading, tap “Uploaded, Start Install”.":
        "Envoyez ces deux fichiers sur R2, puis installez : %@ et %@. Envoyez-les via le pont WebDAV https://r2-webdav.wozofa.workers.dev ou la console R2 ; .plist en text/xml, .ipa en application/octet-stream. Après l’envoi, touchez « Déjà envoyé, installer ».",
    "Uploaded, Start Install":
        "Déjà envoyé, installer",
    "After installing, the first launch will say “Untrusted Enterprise Developer”: go to Settings → General → VPN & Device Management to trust the certificate, tap “Allow and Restart”, then open the app again.":
        "Après l’installation, le premier lancement affichera « Développeur d’entreprise non approuvé » : allez dans Réglages → Général → VPN et gestion des appareils pour approuver le certificat, touchez « Autoriser et redémarrer », puis rouvrez l’app.",
    "Cellular install couldn't open the system installer: check the R2 links, or use pairing install instead.":
        "L’installation cellulaire n’a pas pu ouvrir l’installateur système : vérifiez les liens R2 ou utilisez l’installation par jumelage.",
    "SideStore's anisette settings weren't set. If its sign-in fails with -80046, turn off On-device Anisette and Auto Rotation and pick “SideStore (New)”.":
        "Les réglages anisette de SideStore n'ont pas pu être définis. Si sa connexion échoue avec -80046, désactivez Anisette sur l'appareil et la rotation automatique, et choisissez « SideStore (New) ».",
    "Last refresh (its notification couldn't be delivered): %@":
        "Dernière actualisation (notification non distribuée) : %@",
    "Getting ready": "Préparation",
    "Stopping after this app": "Arrêt après cette app",
    "Refreshing %@": "Renouvellement de %@",
    "Refreshed. Its seven days start again now.":
        "Renouvelée. Ses sept jours repartent maintenant.",
    "Nothing was refreshed.": "Rien n'a été renouvelé.",
    "Refreshed %d of %d apps.": "%d app sur %d renouvelées.",
    "Refresh all apps?": "Renouveler toutes les apps ?",
    "Refresh all": "Tout renouveler",
    "Renew this app": "Renouveler cette app",
    "%d app can be signed again from an IPA already on this iPhone.":
        "%d app peut être signée à nouveau depuis un IPA déjà présent sur cet iPhone.",
    "%d apps can be signed again from IPAs already on this iPhone.":
        "%d apps peuvent être signées à nouveau depuis des IPA déjà présents sur cet iPhone.",
    "Reload": "Recharger",
    "Waiting": "En attente",
    "In progress": "En cours",
    "Failed": "Échec",
    "%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.":
        "%d app ici n'a pas d'IPA dans SideInstaller : elle ne peut pas être renouvelée depuis cette page. Renouvelez-la dans l'app qui l'a installée, ou importez d'abord son .ipa.",
    "%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.":
        "%d apps ici n'ont pas d'IPA dans SideInstaller : elles ne peuvent pas être renouvelées depuis cette page. Renouvelez-les dans l'app qui les a installées, ou importez d'abord leurs .ipa.",
    "%d app": "%d app",
    "%d apps": "%d apps",
    "%d app needs refreshing": "%d app à renouveler",
    "%d apps need refreshing": "%d apps à renouveler",
    "No sideloaded apps": "Aucune app sideloadée",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Rien sur cet appareil n'a été installé avec un profil de provisionnement. Les apps de l'App Store n'expirent pas, elles ne figurent donc pas ici.",
    "No apps were read. Tap Reload to read this iPhone again; pair it and turn on Developer Mode first if nothing shows.":
        "Aucune app lue. Touchez Recharger pour relire cet iPhone ; s'il ne s'affiche toujours rien, associez-le d'abord et activez le mode développeur.",
    "No matching apps.": "Aucune app correspondante.",
    "No matching profile": "Aucun profil correspondant",
    "Expires today": "Expire aujourd'hui",
    "Expires tomorrow": "Expire demain",
    "Expires in %d days — %@": "Expire dans %d jours — %@",
    "Expired %@": "Expiré le %@",
    "Unused profiles": "Profils inutilisés",
    "Issued to App IDs no installed app is running on.":
        "Émis pour des App ID sur lesquels aucune app installée ne tourne.",
    "Older profiles": "Profils plus anciens",
    "App ID": "App ID",
    "Version": "Version",
    "Profile name": "Nom du profil",
    "Team": "Équipe",
    "Team ID": "ID de l'équipe",
    "Issued": "Émis",
    "Profile UUID": "UUID du profil",
    "Capabilities": "Fonctionnalités",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "App ID générique : il couvre n'importe quel bundle id en dessous et ne peut pas porter de fonctionnalités propres à une app.",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "L'appareil n'a aucun profil de provisionnement pour cet App ID. L'app a peut-être déjà cessé de se lancer — réinstallez-la pour corriger cela.",

    // MARK: - Side by Side tool

    // The tool's name is left in English everywhere, as SideStore's is.
    "Side by Side": "Side by Side",
    "Pair with their iPhone": "Jumeler avec leur iPhone",
    "Install on their iPhone": "Installer sur leur iPhone",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "L'iPhone qui s'est jumelé est celui-ci. Jumelez depuis les Réglages de leur iPhone. Pour installer sur cet iPhone, utilisez l'onglet Installer.",
    "Enter the Apple ID to sign with, and its password.":
        "Saisissez l'Apple ID avec lequel signer, et son mot de passe.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Le Wi-Fi est désactivé. Les deux iPhone doivent être sur le même réseau Wi-Fi pour que cela fonctionne.",
    "The release download wasn't an IPA. GitHub may be returning an error page, so try again in a minute.":
        "Le téléchargement de la version n'était pas un IPA. GitHub renvoie peut-être une page d'erreur : réessayez dans une minute.",
    "Couldn't download the latest SideInstaller release: %@":
        "Impossible de télécharger la dernière version de SideInstaller : %@",
    "No SideInstaller IPA downloaded.": "Aucun IPA SideInstaller téléchargé.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first. Use the Certificates tool if this is the Apple ID saved in Settings › Account, or developer.apple.com signed in as it otherwise.":
        "Apple refuse de délivrer un certificat de signature pour cet Apple ID : elle indique qu'il en existe déjà un (erreur 7460). Il faut d'abord en révoquer un. Utilisez l'outil Certificats s'il s'agit de l'Apple ID enregistré dans Réglages › Compte, sinon developer.apple.com en vous y connectant avec.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple n'a pas enregistré leur iPhone auprès de l'équipe de développement de cet Apple ID, elle ne délivrera donc pas de profil de provisionnement. %@",
    "No pair record for their iPhone.":
        "Aucun enregistrement de jumelage pour leur iPhone.",
    "The link to their iPhone dropped. Start again.":
        "La liaison avec leur iPhone a été perdue. Recommencez.",
    "Set up someone else's iPhone": "Configurer l'iPhone de quelqu'un d'autre",
    "Same Wi-Fi network": "Même réseau Wi-Fi",
    "Apple ID to sign with": "Apple ID avec lequel signer",
    "Waiting for them to pair in Settings…":
        "En attente qu'ils jumellent l'iPhone dans Réglages…",
    "Waiting for them to enter the code…":
        "En attente qu'ils saisissent le code…",
    "Pair their iPhone in Settings":
        "Jumelez leur iPhone dans Réglages",
    "Their iPhone won't ask by itself. Pairing starts from its Settings.":
        "Leur iPhone ne le demandera pas de lui-même : le jumelage se lance depuis ses Réglages.",
    "On their iPhone, open Settings › Privacy & Security › Developer Mode.":
        "Sur leur iPhone, ouvrez Réglages › Confidentialité et sécurité › Mode développeur.",
    "Tap “Pair with %@”.":
        "Touchez « Jumeler avec %@ ».",
    "Enter their iPhone’s passcode if it asks for it.":
        "Saisissez le code de leur iPhone s'il le demande.",
    "Type the code that appears here into the prompt on their iPhone.":
        "Saisissez le code qui s'affiche ici dans la demande affichée sur leur iPhone.",
    "Type this into the prompt on their iPhone.":
        "Saisissez ce code dans la demande affichée sur leur iPhone.",
    "SideInstaller is already waiting for an iPhone to pair with it, from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "SideInstaller attend déjà qu'un iPhone se jumelle avec lui, depuis l'onglet Installer, la page Jumelage ou une tentative précédente ici. Terminez ce jumelage, ou fermez puis rouvrez SideInstaller, puis réessayez.",
    "Pairing with their iPhone didn't finish: %@":
        "Le jumelage avec leur iPhone n'a pas abouti : %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "Leur iPhone à l'adresse %@ a refusé la connexion. Il n'en accepte qu'avec le mode développeur activé, et iOS demande de le confirmer de nouveau après chaque redémarrage : sur leur iPhone, activez-le dans Réglages › Confidentialité et sécurité › Mode développeur, puis réessayez.",
    "Couldn't reach their iPhone at %@. Check that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Impossible de joindre leur iPhone à l'adresse %@. Vérifiez que les deux iPhone sont sur le même réseau Wi-Fi et que Réseau local est activé pour SideInstaller dans les Réglages de cet iPhone. Les réseaux invités et publics empêchent souvent les appareils de communiquer entre eux.",
    "%d%% downloaded": "%d%% téléchargés",
    "%@ downloaded": "%@ téléchargés",
    "%d%% uploaded": "%d%% envoyés",
    "Start the install": "Lancer l'installation",
    "Clear their details": "Effacer leurs informations",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "Cet iPhone est toujours jumelé avec le leur. Effacer supprime ce jumelage.",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "Sur leur iPhone : Réglages › Général › VPN et gestion des appareils.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "Touchez l'Apple ID sous « App de développeur », puis touchez Faire confiance.",

    // MARK: - Side by Side, step by step

    "Needs LocalDevVPN on their iPhone": "Nécessite LocalDevVPN sur leur iPhone",
    "Couldn't download %@: %@": "Impossible de télécharger %@ : %@",
    "Couldn't find %@ in Downloads. Download it again first.": "Impossible de trouver %@ dans Téléchargements. Téléchargez-le à nouveau d'abord.",
    "The IPA for %@ in Downloads is a different clone. Its bundle ID doesn't match this history entry. Download this clone's IPA first.": "L'IPA de %@ dans Téléchargements est un autre clone. Son identifiant de bundle ne correspond pas à cet historique. Téléchargez d'abord l'IPA de ce clone.",
    "Their iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. They need to delete one, then you can try again.":
        "Leur iPhone a déjà trois apps signées avec un Apple ID gratuit, le maximum autorisé par iOS, apps expirées comprises. Ils doivent en supprimer une, puis vous pourrez réessayer.",
    "%@ is on their iPhone, but its pairing file couldn't be added (%@). Run Side by Side again, or import a pairing file in %@.":
        "%@ est sur leur iPhone, mais son fichier de jumelage n'a pas pu être ajouté (%@). Relancez Side by Side, ou importez un fichier de jumelage dans %@.",
    "Get started": "C'est parti",
    "What should go on their iPhone?": "Que faut-il installer sur leur iPhone ?",
    "Pick one. You can come back for another one later.":
        "Choisissez-en une. Vous pourrez revenir pour une autre plus tard.",
    "Which Apple ID signs it?": "Quel Apple ID la signe ?",
    "The app is signed with it, and needs it again every 7 days to keep opening. Use the iPhone owner's.":
        "L'app est signée avec cet Apple ID, et en a de nouveau besoin tous les 7 jours pour continuer à s'ouvrir. Utilisez celui du propriétaire de l'iPhone.",
    "Their Apple ID": "Leur Apple ID",
    "Recommended: they keep their apps signed with it.":
        "Recommandé : ils gardent leurs apps signées avec.",
    "My Apple ID": "Mon Apple ID",
    "Only if you'll keep their apps signed yourself: they won't have this Apple ID's password.":
        "Seulement si vous gardez vous-même leurs apps signées : ils n'auront pas le mot de passe de cet Apple ID.",
    "Used for this install only, and never saved.":
        "Utilisé uniquement pour cette installation, et jamais enregistré.",
    "Apple may send a code to their devices, so keep their iPhone close.":
        "Apple peut envoyer un code à leurs appareils : gardez leur iPhone à portée de main.",
    "Get their iPhone ready": "Préparez leur iPhone",
    "Do this on their iPhone, then start.":
        "Faites ceci sur leur iPhone, puis lancez l'installation.",
    "Connect their iPhone to the same Wi-Fi network as this one.":
        "Connectez leur iPhone au même réseau Wi-Fi que celui-ci.",
    "Turn on Developer Mode under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.":
        "Activez le Mode développeur dans Réglages › Confidentialité et sécurité › Mode développeur, et confirmez-le après le redémarrage.",
    "Unlock their iPhone and keep it next to this one.":
        "Déverrouillez leur iPhone et gardez-le à côté de celui-ci.",
    "Installing %@ on their iPhone": "Installation de %@ sur leur iPhone",
    "Waiting for their iPhone…": "En attente de leur iPhone…",
    "Looking for their iPhone…": "Recherche de leur iPhone…",
    "Handing over the pairing file…": "Transmission du fichier de jumelage…",
    "Change details": "Modifier les détails",
    "%@ is on their iPhone": "%@ est sur leur iPhone",
    "Finish on their iPhone": "À terminer sur leur iPhone",
    "This iPhone no longer keeps a pairing with theirs.":
        "Cet iPhone ne garde plus de jumelage avec le leur.",
    "Install another app": "Installer une autre app",
    "Get LocalDevVPN from the App Store and connect it: SideStore works through it.":
        "Installez LocalDevVPN depuis l'App Store et connectez-le : SideStore passe par lui.",
    "Open SideStore and sign in with the same Apple ID. Its pairing file is already in place.":
        "Ouvrez SideStore et connectez-vous avec le même Apple ID. Son fichier de jumelage est déjà en place.",
    "Open LiveContainer, go to its Settings tab, and tap “Import Certificate From SideStore”.":
        "Ouvrez LiveContainer, allez dans son onglet Settings, et touchez « Import Certificate From SideStore ».",

    // MARK: - Settings

    "Settings": "Réglages",
    "Done": "Terminé",
    "Language": "Langue",
    "App language": "Langue de l'app",
    "Sounds": "Sons",
    "Sound effects": "Effets sonores",
    "Auto": "Automatique",
    // The Tunnel section: starting LocalDevVPN from here.
    "Tunnel": "Tunnel",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.":
        "Quelque chose sur %@:%d a refusé la connexion : le tunnel fonctionne donc, c'est l'appareil qui n'écoute pas sur son port de jumelage. Ce port ne s'ouvre qu'avec le mode développeur activé, et iOS le redemande après chaque redémarrage : activez-le dans Réglages › Confidentialité et sécurité › Mode développeur, puis réessayez. S'il est déjà activé, jumelez de nouveau cet iPhone depuis « Fichier de jumelage ».",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port: Developer Mode is off. Turn it on under Settings › Privacy & Security › Developer Mode (the iPhone restarts), then try again.":
        "Quelque chose sur %@:%d a refusé la connexion : le tunnel fonctionne donc, mais cet iPhone n'écoute pas sur son port de jumelage, car le mode développeur est désactivé. Activez-le dans Réglages › Confidentialité et sécurité › Mode développeur (l'iPhone redémarre), puis réessayez.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port, although Developer Mode is on. Pair this iPhone again under “Pairing file”, then try again. If it still fails, restart the iPhone.":
        "Quelque chose sur %@:%d a refusé la connexion : le tunnel fonctionne donc, mais cet iPhone n'écoute pas sur son port de jumelage, bien que le mode développeur soit activé. Jumelez de nouveau cet iPhone depuis « Fichier de jumelage », puis réessayez. Si ça échoue encore, redémarrez l'iPhone.",
    "Something at %@:%d took the connection but didn't answer as this iPhone's pairing port, and no other port answered as one either. Check that LocalDevVPN is the VPN that's on and that Developer Mode is on (Settings › Privacy & Security › Developer Mode), then try again. If it still fails, restart the iPhone.":
        "Quelque chose sur %@:%d a accepté la connexion mais n'a pas répondu comme le port de jumelage de cet iPhone, et aucun autre port n'a répondu comme tel non plus. Vérifiez que le VPN activé est bien LocalDevVPN et que le mode développeur est activé (Réglages › Confidentialité et sécurité › Mode développeur), puis réessayez. Si ça échoue encore, redémarrez l'iPhone.",
    "Start LocalDevVPN when needed": "Lancer LocalDevVPN au besoin",
    "Start LocalDevVPN now": "Lancer LocalDevVPN maintenant",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "LocalDevVPN n'est pas installé. Téléchargez-le sur l'App Store et SideInstaller pourra le lancer pour vous.",
    "When on, operations that need the tunnel try the built-in tunnel first and start LocalDevVPN when needed. When off, LocalDevVPN is never started automatically; the built-in tunnel still starts on demand, and the manual pill switch is unaffected.":
        "Activé, les opérations qui ont besoin du tunnel essaient d'abord le tunnel intégré, puis démarrent LocalDevVPN si nécessaire. Désactivé, LocalDevVPN n'est jamais démarré automatiquement ; le tunnel intégré démarre toujours à la demande, et l'interrupteur manuel (pill) n'est pas affecté.",

    "imported": "importé",
    "Downloaded %@": "Téléchargé le %@",
    "Added %@": "Ajouté %@",
    "Delete": "Supprimer",
    "Couldn't delete %@: %@": "Impossible de supprimer %@ : %@",
    "Server": "Serveur",
    "Custom…": "Personnalisé…",
    "Server URL": "URL du serveur",
    "Anisette Server": "Serveur Anisette",
    "Starts with %@": "Commence par %@",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "Seul le serveur choisi dans Réglages › Serveur Anisette a été essayé. Choisissez Automatique à cet endroit pour que SideInstaller essaie les autres quand l'un échoue.",
    "Device IP": "IP de l'appareil",
    "Advanced": "Avancé",
    "Clear": "Effacer",
    "Clear install history?": "Effacer l'historique d'installation ?",
    "Activity Log (%d)": "Journal d'activité (%d)",
    "没有匹配的日志。": "Aucun journal correspondant.",
    "Verbose logging": "Journal détaillé",
    "Adds the messages exchanged with iOS to the log, for tracking down a connection problem. Leave it off otherwise, as they quickly fill the log.":
        "Ajoute au journal les messages échangés avec iOS, pour identifier un problème de connexion. Le reste du temps, laissez-le désactivé, car ils remplissent vite le journal.",

    // Settings › Developer Mode: AMFI requests over the device link.
    "Developer Mode": "Mode développeur",
    "Developer disk image": "Image disque développeur",
    "Downloaded": "Téléchargée",
    "Not downloaded": "Non téléchargée",
    "Re-download": "Retélécharger",
    "Show Developer Mode in Settings": "Afficher le mode développeur dans Réglages",
    "Turn on Developer Mode": "Activer le mode développeur",
    "Asking this iPhone…": "Interrogation de cet iPhone…",
    "Turn on Developer Mode?": "Activer le mode développeur ?",
    "Turn On and Restart": "Activer et redémarrer",
    "This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode.":
        "Cet iPhone redémarre aussitôt. Une fois qu'il est déverrouillé, touchez Activer dans l'alerte qui s'affiche. iOS ne le permet que si l'iPhone n'a pas de code.",
    "Developer Mode is already on.": "Le mode développeur est déjà activé.",
    "Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.":
        "Le mode développeur apparaît maintenant dans Réglages › Confidentialité et sécurité, vers le bas. Activez-le à cet endroit, et iOS redémarre pour terminer.",
    "Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.":
        "Le mode développeur va s'activer, et cet iPhone redémarre maintenant. Une fois qu'il est déverrouillé, touchez Activer.",
    "An install is already running. Wait for it to finish, then try again.":
        "Une installation est déjà en cours. Attendez qu'elle se termine, puis réessayez.",
    "An import is already running. Wait for it to finish, then try again.": "Un import est déjà en cours. Attendez qu'il se termine, puis réessayez.",
    "%@ will be signed again with the Apple ID that signed it and installed over the copy on this device. It keeps its data, and its seven days start over.": "%@ sera de nouveau signé avec l'identifiant Apple qui l'a signé, puis installé par-dessus la copie présente sur cet appareil. Ses données sont conservées et ses sept jours repartent de zéro.",
    "%d apps will be signed again, each with the Apple ID that signed it, and installed over the copies on this device. They keep their data, and their seven days start over.": "%d apps seront de nouveau signées, chacune avec l'identifiant Apple qui l'a signée, puis installées par-dessus les copies présentes sur cet appareil. Leurs données sont conservées et leurs sept jours repartent de zéro.",
    "%d app here is signed under a team that matches no saved Apple ID, so it is left out. Switch to the Apple ID that signed it and sign in once, then reload, and it will join the list. Enterprise-signed apps stay excluded.": "%d app ici est signée par une équipe qui ne correspond à aucun identifiant Apple enregistré, elle est donc exclue. Basculez vers l'identifiant Apple qui l'a signée, connectez-vous une fois, puis rechargez, et elle rejoindra la liste. Les apps signées par une entreprise restent exclues.",
    "%d apps here are signed under teams that match no saved Apple ID, so they are left out. Switch to the Apple ID that signed them and sign in once, then reload, and they will join the list. Enterprise-signed apps stay excluded.": "%d apps ici sont signées par des équipes qui ne correspondent à aucun identifiant Apple enregistré, elles sont donc exclues. Basculez vers l'identifiant Apple qui les a signées, connectez-vous une fois, puis rechargez, et elles rejoindront la liste. Les apps signées par une entreprise restent exclues.",
    "These apps were signed under %d Apple IDs, so each group is signed with its own Apple ID.": "Ces apps ont été signées avec %d identifiants Apple, chaque groupe est donc signé avec son propre identifiant Apple.",
    "Couldn't sign in as %@ (%@). Switch to that account and refresh again.": "Impossible de se connecter en tant que %@ (%@). Basculez vers ce compte et réessayez.",
    "Skipped: no saved Apple ID matches this app's team (%@). Switch to that account and refresh again.": "Ignoré : aucun identifiant Apple enregistré ne correspond à l'équipe de cette app (%@). Basculez vers ce compte et réessayez.",
    "Skipped: signed in as %@, but this app's team is %@. Switch to that account and refresh again.": "Ignoré : connecté en tant que %@, mais l'équipe de cette app est %@. Basculez vers ce compte et réessayez.",
    "Refreshing %@ as %@": "Renouvellement de %@ en tant que %@",
    "Invalid device IP": "Adresse IP de l'appareil invalide",
    "The address was invalid, reset to 10.7.0.1.": "L'adresse était invalide, elle a été réinitialisée à 10.7.0.1.",
    "Bundle Identifier": "Identifiant de bundle",
    "rpath": "rpath",
    "iOS turns Developer Mode on from here only while this iPhone has no passcode. Tap “Show Developer Mode in Settings” and turn it on there instead.":
        "iOS n'active le mode développeur depuis ici que si cet iPhone n'a pas de code. Touchez « Afficher le mode développeur dans Réglages » et activez-le à cet endroit.",
    "This iPhone didn't take the Developer Mode request: %@":
        "Cet iPhone n'a pas accepté la demande de mode développeur : %@",

    // MARK: - Release channels & downloads

    "Stable": "Stable",
    "Nightly": "Nightly",

    // Version picker (Advanced)

    "%@ version": "Version de %@",
    "Latest": "Dernière",
    "Latest (%@)": "Dernière (%@)",
    "Couldn't load the other versions: %@": "Impossible de charger les autres versions : %@",
    "Try again": "Réessayer",
    // 0.9.185: P0-2 error popup, P0-4 quota row, P0-5 capabilities ok, P0-6 log errors.
    "查看日志": "Voir le journal",
    "免费名额：已装 %d/3": "Places gratuites : %d/3 installées",
    "App ID：已用 %d/%d": "ID d'app : %d/%d utilisés",
    "免费证书都支持": "Tout est pris en charge par le certificat gratuit",
    "错误 (%d)": "Erreurs (%d)",
    "Retry failed items": "Réessayer les éléments échoués",
    // 0.9.186: P1-1 preflight checklist + P1-2 account/team picker, P1-3 cert groups, P1-4 refresh next step, P1-5 background 2FA notice.
    "安装前检查": "Vérifications avant l'installation",
    "去设置": "Ouvrir Réglages",
    "去连 LocalDevVPN": "Connecter LocalDevVPN",
    "签名账号": "Compte de signature",
    "换团队": "Changer d'équipe",
    "首次登录时选择": "À choisir à la première connexion",
    "当前签名账号": "Compte de signature actuel",
    "点一下切换签名账号": "Touchez pour changer de compte de signature",
    "续签需要验证码": "Code de vérification requis pour le renouvellement",
    "自动续签需要输入 Apple ID 验证码。打开 SideInstaller 输入验证码，续签会继续。": "Le renouvellement automatique a besoin du code de vérification de l'identifiant Apple. Ouvrez SideInstaller, saisissez le code et le renouvellement continuera.",
    "重新登录": "Se reconnecter",
    "去证书页看": "Voir la page des certificats",

    "couldn't find the IPA in the %@ %@ release":
        "impossible de trouver l'IPA dans la version %@ de %@",
    "%@ has no %@ release right now": "%@ n'a aucune version %@ pour le moment",
    "bad asset URL": "URL de ressource incorrecte",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub limite les requêtes de ce réseau — il n'est pas bloqué, et la limite se réinitialise d'elle-même. Réessayez %@.",
    "GitHub isn't serving %@ right now — the repository has been taken down, moved or made private, so there's nothing to download. Nothing is wrong with this iPhone or its network.":
        "GitHub ne propose pas %@ pour le moment — le dépôt a été retiré, déplacé ou rendu privé, il n'y a donc rien à télécharger. Cet iPhone et son réseau n'y sont pour rien.",
    "couldn't reach GitHub: %@": "impossible de joindre GitHub : %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "la réponse de GitHub n'était pas les informations de version (%@) — quelque chose sur ce réseau les a peut-être remplacées.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "ce qui a été téléchargé sous le nom %@ n'est pas un IPA — quelque chose sur ce réseau a renvoyé une page, ou le transfert s'est interrompu.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "ce lien a répondu HTTP %d — ce n'est pas un téléchargement direct, ou il exige une connexion.",
    "GitHub has no build of %@'s %@ branch to download right now.":
        "GitHub n'a pour l'instant aucune version de la branche %2$@ de %1$@ à télécharger.",
    "couldn't download %@ through nightly.link, which passes on GitHub's builds: %@":
        "impossible de télécharger %@ via nightly.link, qui relaie les versions compilées par GitHub : %@",
    "the %@ build that arrived isn't the file GitHub recorded, so it isn't installed. Try again later.":
        "la version de %@ reçue n'est pas le fichier enregistré par GitHub, elle n'est donc pas installée. Réessayez plus tard.",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.":
        "La validation en deux étapes a été annulée.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Identifiant Apple ou mot de passe incorrect. Vérifiez l'e-mail et le mot de passe de votre compte Apple, puis réessayez.",
    "Apple ID sign-in failed on %@. Error: %@":
        "Échec de la connexion à l'Apple ID sur %@. Erreur : %@",
    "Apple ID sign-in failed on %@. Error via %@: %@":
        "Échec de la connexion à l'Apple ID sur %@. Erreur via %@ : %@",
    "Apple's sign-in server refused the request (HTTP 503). It isn't your password or the anisette server, so trying more servers won't help. Try again later, or update SideInstaller.":
        "Le serveur de connexion d'Apple a refusé la requête (HTTP 503). Ce n'est ni votre mot de passe ni le serveur anisette : essayer d'autres serveurs n'y changera rien. Réessayez plus tard ou mettez à jour SideInstaller.",
    "“%@” makes its anisette data with Apple's Android library, and Apple now refuses to finish signing in through those servers (error -80046), after your password and code. In Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "« %@ » produit ses données anisette avec la bibliothèque Android d'Apple, et Apple refuse désormais de terminer la connexion via ces serveurs (erreur -80046), après votre mot de passe et votre code. Dans Réglages › Serveur Anisette, choisissez Automatique ou un serveur Mac comme « SideStore (New) ».",
    "Apple refused to finish signing in (error -80046), even through a Mac anisette server, the kind it still accepted. Try again later, or check for a SideInstaller update.":
        "Apple a refusé de terminer la connexion (erreur -80046), même via un serveur anisette Mac, le type qu'il acceptait encore. Réessayez plus tard ou vérifiez s'il existe une mise à jour de SideInstaller.",
    "Apple refused to finish signing in through “%@” (error -80046). It now only accepts sign-ins through anisette servers on its macOS library: in Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "Apple a refusé de terminer la connexion via « %@ » (erreur -80046). Il n'accepte désormais que les connexions via des serveurs anisette utilisant sa bibliothèque macOS : dans Réglages › Serveur Anisette, choisissez Automatique ou un serveur Mac comme « SideStore (New) ».",
    "Apple won't send a code by text or call to this sign-in, so it was sent to your Apple devices.":
        "Apple n'envoie pas de code par SMS ou par appel pour cette connexion, il a donc été envoyé sur vos appareils Apple.",
    "Apple didn't confirm sending a code to your Apple devices. If one arrived, enter it; if not, try another way.":
        "Apple n'a pas confirmé l'envoi d'un code sur vos appareils Apple. Si vous en avez reçu un, saisissez-le ; sinon, essayez une autre méthode.",
    "SideInstaller can't reach Apple's sign-in server (gsa.apple.com), though this iPhone has an internet connection. Something is blocking it: a firewall, a DNS filter or ad blocker, Screen Time content restrictions, or another VPN app. Turn it off or try another network, then try again.":
        "SideInstaller ne parvient pas à joindre le serveur de connexion d'Apple (gsa.apple.com), alors que cet iPhone est connecté à Internet. Quelque chose le bloque : un pare-feu, un filtre DNS ou un bloqueur de publicités, les restrictions de contenu de Temps d'écran ou une autre app VPN. Désactivez-le ou essayez un autre réseau, puis réessayez.",
    "SideInstaller can't reach Apple: Cellular Data is turned off for it. Turn SideInstaller on in Settings › Cellular, or join a Wi-Fi network with internet access, then try again.":
        "SideInstaller ne parvient pas à joindre Apple : les données cellulaires sont désactivées pour l'app. Activez SideInstaller dans Réglages › Données cellulaires, ou connectez-vous à un réseau Wi-Fi avec accès à Internet, puis réessayez.",
    "SideInstaller can't reach Apple: iOS isn't letting it use Wi-Fi. In Settings › Apps › SideInstaller › Wireless Data, choose WLAN & Cellular Data, then try again.":
        "SideInstaller ne parvient pas à joindre Apple : iOS ne l'autorise pas à utiliser le Wi-Fi. Dans Réglages › Apps › SideInstaller › Données sans fil, choisissez « WLAN et données cellulaires », puis réessayez.",
    "SideInstaller can't reach Apple: a VPN set to carry all traffic is disconnected, so iOS is holding traffic back. Reconnect it, or turn off its kill switch or Connect On Demand, then try again.":
        "SideInstaller ne parvient pas à joindre Apple : un VPN configuré pour faire passer tout le trafic est déconnecté, et iOS retient donc le trafic. Reconnectez-le, ou désactivez son kill switch ou sa connexion à la demande, puis réessayez.",
    "SideInstaller can't reach Apple: this iPhone has no internet connection. Connect to Wi-Fi or turn on cellular data, then try again.":
        "SideInstaller ne parvient pas à joindre Apple : cet iPhone n'est pas connecté à Internet. Connectez-vous à un réseau Wi-Fi ou activez les données cellulaires, puis réessayez.",
    "Apple is temporarily limiting sign-ins for this Apple ID or network (HTTP 429). Trying other servers won't help, and every attempt can extend the wait, so leave it a while before signing in again.":
        "Apple limite temporairement les connexions pour cet identifiant Apple ou ce réseau (HTTP 429). Essayer d'autres serveurs n'y changera rien et chaque tentative peut prolonger l'attente : patientez un moment avant de vous reconnecter.",
    "If you're sure the password is right, Apple may be limiting sign-in attempts: wait a while before trying again.":
        "Si vous êtes sûr que le mot de passe est correct, Apple limite peut-être les tentatives de connexion : patientez un moment avant de réessayer.",
    "Apple has locked this Apple Account for security reasons (error -20209), so every sign-in fails until it's unlocked. Reset its password at iforgot.apple.com, then sign in again with the new password.":
        "Apple a verrouillé ce compte Apple pour des raisons de sécurité (erreur -20209) : toute connexion échoue tant qu'il n'est pas déverrouillé. Réinitialisez son mot de passe sur iforgot.apple.com, puis reconnectez-vous avec le nouveau mot de passe.",
    "the anisette server": "le serveur anisette",
    "all %d anisette servers": "les %d serveurs anisette",
    "%d anisette servers (%d skipped)": "%d serveurs anisette (%d ignorés)",
    "Not signed in.": "Non connecté.",
    "No SideStore IPA downloaded.": "Aucun IPA de SideStore téléchargé.",
    "Signing failed: %@": "Échec de la signature : %@",
    "No signed bundle to install.": "Aucun paquet signé à installer.",
    "Device link dropped — reconnect.":
        "Liaison avec l'appareil perdue — relancez la connexion.",
    "Pairing didn't finish — no pairing file yet.":
        "Le jumelage ne s'est pas terminé — il n'y a pas encore de fichier de jumelage.",
    "Pairing file missing — pairing must run first.":
        "Fichier de jumelage manquant — il faut d'abord effectuer le jumelage.",
    "Pairing file missing — generate it first.":
        "Fichier de jumelage manquant — générez-le d'abord.",
    "No pairing file yet — tap “Generate pairing file” first.":
        "Pas encore de fichier de jumelage — touchez d'abord « Générer le fichier de jumelage ».",
    "%@ isn't installed yet — install must run first.":
        "%@ n'est pas encore installé — il faut d'abord l'installer.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ n'est pas un IPA valide : le téléchargement a sans doute renvoyé une page d'erreur, ou la copie s'est arrêtée en cours de route. Remplacez-le et touchez Installer à nouveau.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ n'est pas un IPA. Choisissez le fichier .ipa lui-même ; s'il semble correct, le téléchargement a peut-être enregistré une page d'erreur, ou s'est arrêté en route.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Aucun IPA importé pour l'instant. Touchez « Importer un .ipa » et choisissez-en un.",
    "No IPA on this iPhone":
        "Aucun IPA correspondant sur cet iPhone",
    "Couldn't import %@: %@": "Impossible d'importer %@ : %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "SideInstaller ne peut pas télécharger ce lien. Collez l'adresse https:// complète depuis laquelle le .ipa se télécharge.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "Ce lien n'a pas renvoyé d'IPA. Il doit télécharger le fichier lui-même : une page qui se contente de pointer vers le .ipa, ou qui demande d'abord une connexion, arrive ici sous forme de page web.",
    "Couldn't download that link: %@": "Impossible de télécharger ce lien : %@",
    "there's nothing to download for a custom IPA — import one first":
        "il n'y a rien à télécharger pour un IPA personnalisé — importez-en un d'abord",
    "your app": "votre app",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple n'émettra pas de certificat de signature pour cet Apple ID : il indique qu'il en existe déjà un, ou qu'une demande est encore en attente (erreur 7460). SideInstaller n'a pas pu réutiliser le certificat déjà présent, il s'est donc arrêté au lieu de le remplacer. Voir les étapes ci-dessus.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Impossible d'enregistrer cet iPhone%@ auprès de l'équipe de développement de votre Apple ID, Apple ne délivrera donc pas de profil de provisionnement. %@ — voir les étapes ci-dessus.",
    "Connect to Wi-Fi": "Connectez-vous au Wi-Fi",
    "Open Settings › Wi-Fi and join a network.": "Ouvrez Réglages › Wi-Fi et rejoignez un réseau.",
    "Then come back here — this continues automatically.":
        "Revenez ensuite ici : la suite se fait toute seule.",
    "Tap Connect so the toggle turns on.": "Touchez Connect pour que l'interrupteur s'active.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Laissez le Wi-Fi activé, puis revenez ici : la suite se fait toute seule.",
    "Get LocalDevVPN": "Obtenir LocalDevVPN",
    "Import an .ipa first": "Importez d'abord un .ipa",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Touchez « Importer un .ipa » ci-dessus et choisissez le fichier : il peut se trouver partout où l'app Fichiers a accès, y compris iCloud Drive ou une clé USB.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "Ou collez un lien de téléchargement direct sous ce bouton : SideInstaller récupère le .ipa lui-même.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "Ou ouvrez l'app Fichiers, maintenez le .ipa, touchez Partager et choisissez SideInstaller : le fichier arrive sans passer par le sélecteur.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "Ou copiez-le dans Fichiers › Sur mon iPhone › SideInstaller, où SideInstaller le trouve aussi.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "C'est la solution là où GitHub est bloqué : récupérez l'IPA sur n'importe quel appareil, apportez-le ici et installez-le.",
    "Bring the .ipa yourself": "Apportez vous-même le .ipa",
    "%@ can't be downloaded while its GitHub repository is offline. The other apps still install as usual.":
        "%@ ne peut pas être téléchargé tant que son dépôt GitHub est hors ligne. Les autres apps s'installent comme d'habitude.",
    "To install it anyway, get its .ipa from somewhere you trust, name it %@, and copy it into Files › On My iPhone › SideInstaller.":
        "Pour l'installer quand même, récupérez son .ipa auprès d'une source de confiance, nommez-le %@ et copiez-le dans Fichiers › Sur mon iPhone › SideInstaller.",
    "Then tap Install again — SideInstaller uses your file instead of downloading one.":
        "Touchez ensuite à nouveau Installer — SideInstaller utilise votre fichier au lieu d'en télécharger un.",
    "If you reach GitHub through a VPN or proxy app, turn off LocalDevVPN and turn that one on: iOS runs only one VPN at a time.":
        "Si vous accédez à GitHub via une app VPN ou proxy, désactivez LocalDevVPN et activez celle-ci : iOS n'exécute qu'un seul VPN à la fois.",
    "Tap “Get the .ipa” below and save the file, or download it on another device and bring it over.":
        "Touchez « Obtenir le .ipa » ci-dessous et enregistrez le fichier, ou téléchargez-le sur un autre appareil et transférez-le ici.",
    "Back in SideInstaller, pick Custom .ipa under Install, tap “Import .ipa” and choose the file. SideInstaller recognizes %@ and sets it up just like its own download.":
        "De retour dans SideInstaller, choisissez IPA personnalisé sous Installer, touchez « Importer un .ipa » et sélectionnez le fichier. SideInstaller reconnaît %@ et le configure comme s'il l'avait téléchargé lui-même.",
    "Turn LocalDevVPN back on, then tap Install.":
        "Réactivez LocalDevVPN, puis touchez Installer.",
    "Get the .ipa": "Obtenir le .ipa",
    "Pair this iPhone in Settings": "Jumelez cet iPhone dans Réglages",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Ouvrez l'app Réglages, puis allez dans Confidentialité et sécurité › Mode développeur.",
    "Tap “Pair with SideInstaller”.": "Touchez « Jumeler avec SideInstaller ».",
    "Enter your iPhone’s passcode if it asks for it.":
        "Saisissez le code de votre iPhone s'il vous le demande.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Revenez dans SideInstaller, notez le code qu'il affiche, puis saisissez ce même code dans la demande affichée dans Réglages.",
    "Type the code that appears at the top of the screen into the prompt in Settings. If none appears, come back to SideInstaller to read it.":
        "Saisissez le code qui s'affiche en haut de l'écran dans la demande affichée dans Réglages. S'il n'apparaît pas, revenez dans SideInstaller pour le lire.",
    "Allow notifications when SideInstaller asks: that's how the pairing code reaches you in Settings.":
        "Autorisez les notifications quand SideInstaller le demande : c'est ainsi que le code de jumelage vous parvient dans Réglages.",

    // The pairing Live Activity
    "Privacy & Security › Developer Mode › Pair with SideInstaller":
        "Confidentialité et sécurité › Mode développeur › Jumeler avec SideInstaller",
    "Paired": "Jumelé",
    "Tap to return to SideInstaller.": "Touchez pour revenir dans SideInstaller.",

    // The install's progress outside the app
    "Installing %@": "Installation de %@",
    "Paused": "En pause",
    "Ignore this version": "Ignorer cette version",
    "已忽略的更新": "Mises à jour ignorées",
    "没有已忽略的更新。": "Aucune mise à jour ignorée.",
    "所有已忽略的版本都将重新提示更新。": "Toutes les versions ignorées proposeront à nouveau des mises à jour.",
    "Pause": "Pause",
    "Pause all": "Tout suspendre",
    "Resume": "Reprendre",
    "Resume all": "Tout reprendre",
    "Open": "Ouvrir",
    "Open SideInstaller to finish the install.":
        "Ouvrez SideInstaller pour terminer l'installation.",
    "Check the App IDs it needs, then tap Install.":
        "Vérifiez les App ID nécessaires, puis touchez Installer.",
    "Tap Trust": "Touchez Faire confiance",
    "Unlock this iPhone and tap Trust when it asks.":
        "Déverrouillez cet iPhone et touchez Faire confiance quand il le demande.",

    "A signing certificate already exists": "Un certificat de signature existe déjà",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Apple a renvoyé l'erreur 7460 : cet Apple ID possède déjà un certificat de développement iOS, ou une demande est encore en attente.",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideInstaller n'a pas pu le réutiliser. Cela arrive quand le certificat a été émis ailleurs — AltStore, SideStore, Sideloadly ou Xcode sur un autre appareil — la clé privée nécessaire n'est donc pas sur cet iPhone.",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "Utilise « Révoquer et réessayer » ci-dessus, ou ouvre Certificats dans l'onglet Outils, touche « Charger les certificats » et révoque-le là.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "La révocation est définitive : toutes les apps déjà signées avec ce certificat cessent de se lancer, sur tous les appareils.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Vous pouvez aussi vous connecter ci-dessus avec un autre Apple ID (ou un compte de secours), puis toucher à nouveau Installer.",

    // MARK: - Guide cards

    // Guide: reset a locked Apple Account

    "Reset your Apple Account password": "Réinitialisez le mot de passe de votre compte Apple",
    "Apple has locked this Apple Account for security reasons, often after too many sign-in attempts. Every sign-in fails until it's unlocked, so tapping Install again won't help yet.":
        "Apple a verrouillé ce compte Apple pour des raisons de sécurité, souvent après trop de tentatives de connexion. Toute connexion échoue tant qu'il n'est pas déverrouillé : toucher à nouveau Installer ne servira à rien pour l'instant.",
    "Open iForgot, enter this Apple Account's email, and follow Apple's steps to unlock it and reset its password.":
        "Ouvrez iForgot, saisissez l'e-mail de ce compte Apple et suivez les étapes d'Apple pour le déverrouiller et réinitialiser son mot de passe.",
    "Back in SideInstaller, open Settings › Account, swipe left on this Apple ID, tap Edit, and enter the new password.":
        "De retour dans SideInstaller, ouvrez Réglages › Compte, balayez cet Apple ID vers la gauche, touchez Modifier et saisissez le nouveau mot de passe.",
    "Then tap Install again.": "Touchez ensuite à nouveau Installer.",
    "Open iForgot": "Ouvrir iForgot",
    "Apple won't let this Apple Account use developer services because of its owner's age (error 1102). Sign in with an adult's Apple Account instead.":
        "Apple n'autorise pas ce compte Apple à utiliser les services pour développeurs en raison de l'âge de son titulaire (erreur 1102). Connectez-vous plutôt avec le compte Apple d'un adulte.",
    "This Apple ID has no App IDs left (error 9120). A free Apple ID can register 10 a week, and each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Cet Apple ID n'a plus d'App ID disponibles (erreur 9120). Un Apple ID gratuit peut en enregistrer 10 par semaine, et chacun compte pendant 7 jours : attendez que certains expirent ou connectez-vous avec un autre Apple ID.",
    "This iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. Delete one of them, then try again.":
        "Cet iPhone a déjà trois apps signées avec un Apple ID gratuit, le maximum autorisé par iOS, apps expirées comprises. Supprimez-en une, puis réessayez.",
    "This Apple Account can't sign apps":
        "Ce compte Apple ne peut pas signer d'apps",
    "Apple only lets adults use the developer services SideInstaller signs apps with, and it reports that this Apple Account belongs to someone younger (error 1102).":
        "Apple réserve aux adultes les services pour développeurs avec lesquels SideInstaller signe les apps, et indique que ce compte Apple appartient à une personne plus jeune (erreur 1102).",
    "Sign in with an adult's Apple Account instead: open Settings › Account and add it there.":
        "Connectez-vous plutôt avec le compte Apple d'un adulte : ouvrez Réglages › Compte et ajoutez-le.",
    "Apple won't let this Apple Account use developer services until its email address is verified (error 2160). Verify it at account.apple.com, then try again.":
        "Apple n'autorise pas ce compte Apple à utiliser les services pour développeurs tant que son adresse e-mail n'est pas vérifiée (erreur 2160). Vérifiez-la sur account.apple.com, puis réessayez.",
    "Verify your Apple Account's email":
        "Vérifiez l'e-mail de votre compte Apple",
    "Apple won't let this Apple Account sign apps until its email address is verified (error 2160). Signing in again or through another anisette server won't change that.":
        "Apple n'autorise pas ce compte Apple à signer des apps tant que son adresse e-mail n'est pas vérifiée (erreur 2160). Se reconnecter ou passer par un autre serveur anisette n'y changera rien.",
    "Sign in at account.apple.com with this Apple Account and verify its email address when Apple asks. Apple sends the code or link to that address, so check its spam folder too.":
        "Connectez-vous à account.apple.com avec ce compte Apple et vérifiez son adresse e-mail quand Apple le demande. Apple envoie le code ou le lien à cette adresse : pensez aussi à regarder dans les spams.",
    "Open Apple Account":
        "Ouvrir le compte Apple",
    "No App IDs left this week": "Plus d'App ID cette semaine",
    "They can't be deleted sooner. Wait until some expire, then tap Install again.":
        "Ils ne peuvent pas être supprimés plus tôt. Attendez que certains expirent, puis touchez à nouveau Installer.",
    "Or sign in with a different (or spare) Apple ID in Settings › Account, then tap Install again.":
        "Ou connectez-vous avec un autre Apple ID (ou un compte de secours) dans Réglages › Compte, puis touchez à nouveau Installer.",
    "Three sideloaded apps already": "Déjà trois apps sideloadées",
    "iOS allows three apps signed with a free Apple ID on an iPhone at a time, and it refused a fourth.":
        "iOS autorise trois apps signées avec un Apple ID gratuit à la fois sur un iPhone, et en a refusé une quatrième.",
    "Expired apps count too. Delete one you no longer need from the Home Screen.":
        "Les apps expirées comptent aussi. Supprimez de l'écran d'accueil une app dont vous n'avez plus besoin.",

    // Guide: import a pairing file

    "Import a pairing file": "Importer un fichier de jumelage",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@ est la première version où un iPhone peut se jumeler tout seul. Sur celui-ci, le fichier de jumelage doit être créé sur un ordinateur.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "Sur un Mac, un PC Windows ou Linux, branchez cet iPhone, faites confiance à l'ordinateur et lancez jitterbugpair (ou « pymobiledevice3 lockdown pair »).",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "Envoyez le fichier obtenu — un .mobiledevicepairing ou .plist — vers cet iPhone, par AirDrop, iCloud Drive ou un câble.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "Revenez ici, touchez « Importer le fichier de jumelage » et choisissez-le. Ensuite, tout fonctionne comme sur iOS %@.",
    "Get jitterbugpair": "Télécharger jitterbugpair",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "Un certificat existe déjà",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple n'émettra pas un second certificat de signature pour cet Apple ID. Révoquer celui qui existe déjà permet de poursuivre l'installation, mais c'est irréversible.",
    "Loading certificates": "Chargement des certificats",
    "Revoke and retry": "Révoquer et réessayer",
    "Which certificate should be revoked?": "Quel certificat faut-il révoquer ?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple signale un certificat sur cet Apple ID, mais la liste est revenue vide. C'est peut-être une demande encore en attente : attends quelques minutes puis touche Installer à nouveau.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "Toutes les apps déjà signées avec le certificat choisi cesseront de se lancer, sur tous les appareils — y compris celles installées par AltStore, SideStore ou depuis un ordinateur. C'est irréversible. L'installation reprend juste après.",
    " (expired)": " (expiré)",

    "Couldn't register this device": "Impossible d'enregistrer cet appareil",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Votre Apple ID a atteint sa limite d'appareils enregistrés. Les comptes gratuits ne peuvent enregistrer qu'un petit nombre d'appareils par an et ne peuvent pas retirer les anciens avant la réinitialisation annuelle.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "Solution la plus simple : saisissez un autre Apple ID (ou un compte de secours) dans les champs ci-dessus, puis touchez à nouveau Installer.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller n'a pas pu ajouter automatiquement cet iPhone à l'équipe de développement de votre Apple ID. Toucher à nouveau Installer suffit souvent : le service développeur d'Apple est parfois brièvement indisponible.",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "Si l'erreur persiste, ajoutez l'appareil à la main. Son UDID est :",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Collez-le dans le formulaire « Register a Device » du portail Apple Developer (cela nécessite un compte Apple Developer payant), puis touchez à nouveau Installer.",
    "Open device list": "Ouvrir la liste des appareils",

    "Last step: trust %@": "Dernière étape : faire confiance à %@",
    "Open Settings › General › VPN & Device Management.":
        "Ouvrez Réglages › Général › VPN et gestion des appareils.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "Touchez votre Apple ID sous « App de développeur », puis touchez Faire confiance.",
    "Open %@ from your Home Screen — you're done.":
        "Ouvrez %@ depuis votre écran d'accueil — c'est terminé.",

    "Import the certificate into LiveContainer": "Importez le certificat dans LiveContainer",
    "Open LiveContainer from your Home Screen.":
        "Ouvrez LiveContainer depuis votre écran d'accueil.",
    "Tap the Settings tab.": "Touchez l'onglet Settings.",
    "Tap “Import Certificate From SideStore”.":
        "Touchez « Import Certificate From SideStore ».",
    "Wrong device IP": "Mauvaise IP d’appareil",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "L’adresse indiquée dans Réglages › Avancé › IP de l’appareil est déjà celle de cet iPhone : il n’y a donc rien à l’autre bout auquel se connecter.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "Remettez-la à 10.7.0.1, la valeur par défaut. Dans LocalDevVPN, c’est la valeur sous Réglages › Device IP, et non l’adresse de l’écran principal, qui est l’extrémité du tunnel lui-même.",
    "If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one.":
        "Si vous avez modifié les adresses de LocalDevVPN, copiez ici son Device IP — y compris le /32, s'il en affiche un.",
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "iOS a refusé la connexion à %@ sur cet iPhone, avant que quoi que ce soit ne soit envoyé. Il le fait pour les adresses de cet iPhone lui-même, comme celle qui suit « Connecté à » sur l’écran principal de LocalDevVPN. L’IP de l’appareil, dans Réglages › Avancé, doit être l’adresse sous Réglages › Device IP dans LocalDevVPN (10.7.0.1 par défaut). Si c’est déjà le cas, désactivez puis réactivez LocalDevVPN, puis réessayez.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "Cet iPhone a coupé la connexion dès son ouverture. Depuis iOS 26.4, il le fait avec les fichiers de jumelage lockdown, comme celui-ci, quand ils passent par LocalDevVPN. Jumelez plutôt cet iPhone avec lui-même : touchez « Régénérer » dans Outils › Jumelage, ou touchez Installer, qui le jumelle d'abord.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "Cet iPhone a coupé la connexion dès son ouverture. Depuis iOS 26.4, il le fait avec les fichiers de jumelage lockdown, comme celui-ci, quand ils passent par LocalDevVPN : en refaire un du même type n'y changera rien. Un fichier de jumelage « Remote pairing » fonctionne toujours : sur un ordinateur, ouvrez idevice_pair, choisissez « Remote pairing », cliquez sur « Create » puis sur « Save to file… », et importez le fichier dans « Fichier de jumelage ».",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "L’appairage de cet iPhone en a besoin : SideInstaller s’annonce sur le réseau local pour que Réglages le trouve.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Connectez-vous à un réseau Wi-Fi. L’appairage de cet iPhone en a besoin : SideInstaller doit être détectable sur le réseau local.",

    // MARK: - About

    "About": "À propos",
    "Version %@ (%@)": "Version %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller installe SideStore et LiveContainer directement sur votre iPhone, sans PC.",
    "Checking for updates…": "Recherche de mises à jour…",
    "Checking for updates… Tap again to cancel.": "Recherche de mises à jour… Touchez à nouveau pour annuler.",
    "You're up to date.": "Vous êtes à jour.",
    "Couldn't check for updates. Check your connection and try again.":
        "Impossible de vérifier les mises à jour. Vérifiez votre connexion et réessayez.",

    "Links": "Liens",
    "Source code": "Code source",
    "Support the project": "Soutenir le projet",
    "Crypto": "Crypto",
    "Donation wallets for Bitcoin, Ethereum and Solana.":
        "Portefeuilles de dons pour Bitcoin, Ethereum et Solana.",
    "Crypto donations": "Dons en crypto",
    "Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you.":
        "Les dons sont entièrement facultatifs. Ils n'achètent rien, ne débloquent aucune fonction et ne donnent droit à rien en retour : c'est simplement une façon de dire merci si SideInstaller vous a aidé.",
    "Coin": "Monnaie",
    "Network: %@": "Réseau : %@",
    "QR code for the %@ address": "Code QR de l'adresse %@",
    "Copied": "Copié",
    "Send each coin only on the network shown. Crypto sent on another network can't be recovered.":
        "N'envoyez chaque monnaie que sur le réseau indiqué. Les cryptos envoyées sur un autre réseau sont irrécupérables.",

    "Special thanks": "Remerciements",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "Pour idevice, la bibliothèque avec laquelle SideInstaller communique avec votre iPhone. Rien de tout cela n’existerait sans elle.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Pour le soutien et pour avoir repéré les bugs qui ont ensuite été corrigés.",
    "For the Japanese translation.": "Pour la traduction japonaise.",
    "For the Korean translation.": "Pour la traduction coréenne.",
    "For the Turkish translation.": "Pour la traduction turque.",

    "Built with": "Construit avec",
    "The open source work this app is built on:":
        "Le travail open source sur lequel cette app repose :",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "L’appairage, le tunnel et l’installation elle-même. Par jkcoxson, MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "La connexion à l’Apple ID, les certificats et la signature sur l’appareil. Par nab138, MIT.",
    "The code signer isideload uses for each app. By Dadoum, LGPL-2.1.":
        "Le signataire de code qu’isideload utilise pour chaque app. Par Dadoum, LGPL-2.1.",
    "The sideloading app this installs for you.":
        "L’app de sideloading que celle-ci installe pour vous.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Exécute les apps sideloadées sans consommer un emplacement pour chacune.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "L’image disque développeur que monte la simulation de position. Miroir de doronz88.",

    "Terms": "Conditions",

    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.":
        "%@ nécessite iOS %d ou une version ultérieure. Cet iPhone utilise iOS %@.",
    "%@ needs iOS %@ or later. This iPhone runs iOS %@.": "%@ nécessite iOS %@ ou une version ultérieure. Cet iPhone utilise iOS %@.",
    "Minimum iOS": "iOS minimum",
    "SHA-256": "SHA-256",
    "Show all": "Tout afficher",
    "Open Madeira from your Home Screen.": "Ouvrez Madeira depuis votre écran d'accueil.",
    "In its setup, under “Set up JIT”, pick “In-app with pairing file”: SideInstaller already put the file there, so tap “Continue”.":
        "Dans sa configuration, sous « Set up JIT », choisissez « In-app with pairing file » : SideInstaller y a déjà placé le fichier, touchez donc « Continue ».",
    "In its setup, under “Set up JIT”, pick how this iPhone gets JIT.":
        "Dans sa configuration, sous « Set up JIT », choisissez comment cet iPhone obtient le JIT.",
    "Madeira renews its own signing from now on, when it's open and LocalDevVPN is connected. SideInstaller gave it a sign-in for that: a token for Apple's developer service, not your password. Madeira can forget it under Settings › Signing.":
        "Désormais, Madeira renouvelle lui-même sa signature, quand il est ouvert et que LocalDevVPN est connecté. SideInstaller lui a donné une connexion pour cela : un jeton pour le service développeur d'Apple, pas votre mot de passe. Madeira peut l'oublier dans Settings › Signing.",
    "Its signing lasts 7 days. Before they run out, refresh it here under Tools › Sideloaded apps.":
        "Sa signature dure 7 jours. Avant qu'ils ne soient écoulés, renouvelez-la ici dans Outils › Apps sideloadées.",
    "This pairing file has no RPPairing record, the only kind %@ reads.":
        "Ce fichier de jumelage ne contient pas d'enregistrement RPPairing, le seul type que %@ lit.",
    "Runs Windows PC games on your iPhone. By Will Faust, GPL-3.0.":
        "Fait tourner les jeux PC Windows sur votre iPhone. Par Will Faust, GPL-3.0.",

    // MARK: - App ID cost

    "App IDs for this app": "App IDs de cette app",
    "Cost": "Coût",
    "Left now": "Restants",
    "Left after": "Restants après",
    "New App IDs": "Nouveaux App IDs",
    "This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Il ne reste pas assez d'App IDs à cet Apple ID : cette app en demande %d et il en reste %d. Chacun compte pendant 7 jours, alors attendez que certains expirent ou connectez-vous avec un autre Apple ID.",
    "The next one frees up on %@.": "Le prochain se libère le %@.",
    "Your Apple ID already has every App ID this app needs, so installing it uses none.":
        "Votre Apple ID a déjà tous les App IDs dont cette app a besoin, donc l'installer n'en utilise aucun.",
    "Signing registers one App ID for the app, and its extensions share it. It counts for 7 days.":
        "La signature enregistre un seul App ID pour l'app, que ses extensions partagent. Il compte pendant 7 jours.",
    "This Apple ID can register %d a week.":
        "Cet Apple ID peut en enregistrer %d par semaine.",

    // MARK: - Links (sideinstaller://install, sideinstaller://pairingFile)

    "Install from a link?": "Installer depuis un lien ?",
    "Download and install": "Télécharger et installer",
    "SideInstaller will download this .ipa, then sign it with your Apple ID and install it. Only go ahead if you trust where the link came from.":
        "SideInstaller va télécharger ce .ipa, le signer avec votre Apple ID et l'installer. Ne continuez que si vous faites confiance à la provenance du lien.",
    "It replaces %@, the custom .ipa you have now.": "Il remplace %@, l'IPA personnalisé actuel.",
    "Use SideStore's pairing file?": "Utiliser le fichier de jumelage de SideStore ?",
    "Import this pairing file?": "Importer ce fichier de jumelage ?",
    "Import": "Importer",
    "SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.":
        "SideStore a renvoyé le fichier de jumelage qu'il possède. SideInstaller s'en servira pour se connecter à cet iPhone.",
    "A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.":
        "Un lien a envoyé un fichier de jumelage à SideInstaller. Ne l'importez que si vous l'avez demandé : SideInstaller s'en servira pour se connecter à cet iPhone.",
    "It replaces %@.": "Il remplace %@.",
    "It replaces the pairing file in use now.": "Il remplace le fichier de jumelage utilisé actuellement.",
    "Get it from SideStore": "Le récupérer depuis SideStore",
    "SideStore opens and sends back the pairing file it has.":
        "SideStore s'ouvre et renvoie le fichier de jumelage qu'il possède.",
    "SideStore isn't installed on this iPhone, so there's no pairing file to get from it.":
        "SideStore n'est pas installé sur cet iPhone, il n'y a donc aucun fichier de jumelage à récupérer.",
    "SideInstaller takes the pairing file LiveContainer's built-in SideStore has.":
        "SideInstaller prend le fichier de jumelage du SideStore intégré à LiveContainer.",
    "This is the pairing file LiveContainer's built-in SideStore has. SideInstaller will connect to this iPhone with it.":
        "Voici le fichier de jumelage du SideStore intégré à LiveContainer. SideInstaller s'en servira pour se connecter à cet iPhone.",
    "In LiveContainer's Multitask Mode, SideInstaller can't open the built-in SideStore's files. Open SideInstaller in LiveContainer without Multitask Mode, then try again, or tap “Import pairing file” and pick the file your computer made.":
        "En mode multitâche de LiveContainer, SideInstaller ne peut pas ouvrir les fichiers du SideStore intégré. Ouvrez SideInstaller dans LiveContainer sans le mode multitâche, puis réessayez, ou touchez « Importer le fichier de jumelage » et choisissez le fichier créé par votre ordinateur.",
    "Inside LiveContainer, SideStore can't send its pairing file back to SideInstaller, and LiveContainer's built-in SideStore has none that SideInstaller can use. Tap “Import pairing file” and pick the file your computer made, or import one into SideStore first, then try again here.":
        "Dans LiveContainer, SideStore ne peut pas renvoyer son fichier de jumelage à SideInstaller, et le SideStore intégré à LiveContainer n'en a aucun que SideInstaller puisse utiliser. Touchez « Importer le fichier de jumelage » et choisissez le fichier créé par votre ordinateur, ou importez-en d'abord un dans SideStore, puis réessayez ici.",
    "That install link has no .ipa in it. It needs ?url= followed by the https:// address the .ipa downloads from.":
        "Ce lien d'installation ne contient aucun .ipa. Il lui faut ?url= suivi de l'adresse https:// d'où se télécharge le .ipa.",
    "That link was meant to carry a pairing file, but what it holds can't be read.":
        "Ce lien devait contenir un fichier de jumelage, mais son contenu est illisible.",
    "That link carries a file, but it isn't a pairing file.":
        "Ce lien contient un fichier, mais ce n'est pas un fichier de jumelage.",

    // MARK: - Report a problem

    "Report a problem": "Signaler un problème",
    "Report this problem": "Signaler ce problème",
    "Opens a GitHub issue with this app's details, its log and crash logs.":
        "Ouvre un ticket GitHub avec les infos de l'app, son journal et les rapports de plantage.",
    "What happened?": "Que s'est-il passé ?",
    "What were you doing, and what went wrong?": "Que faisais-tu, et qu'est-ce qui n'a pas marché ?",
    "Say what you tapped, what you expected and what happened instead. English is best, but any language is fine.":
        "Dis ce que tu as touché, ce que tu attendais et ce qui s'est passé à la place. L'anglais est préférable, mais toute langue convient.",
    "Included": "Inclus",
    "Device": "Appareil",
    "App": "App",
    "Stopped at": "Arrêtée à",
    "not connected": "non connecté",
    "none": "aucun",
    "made on this iPhone": "créé sur cet iPhone",
    "Runs inside LiveContainer": "Exécuté dans LiveContainer",
    "on": "activé",
    "off": "désactivé",
    "unknown": "inconnu",
    "yes": "oui",
    "no": "non",
    "latest": "la plus récente",
    "custom server": "serveur personnalisé",
    "Auto, starts with %@": "Auto, commence par %@",
    "Error": "Erreur",
    "Activity log": "Journal d'activité",
    "%d lines": "%d lignes",
    "Your Apple ID, device name, serial numbers and keys are taken out of the log first.":
        "L'identifiant Apple, le nom de l'appareil, les numéros de série et les clés sont d'abord retirés du journal.",
    "Crash logs": "Rapports de plantage",
    "Looking for crash logs …": "Recherche des rapports de plantage …",
    "Look for crash logs on this iPhone": "Chercher les rapports de plantage sur cet iPhone",
    "Look again": "Chercher à nouveau",
    "No crash logs from SideStore, LiveContainer or Madeira in the last %d days.":
        "Aucun rapport de plantage de SideStore, LiveContainer ou Madeira ces %d derniers jours.",
    "iOS hands SideInstaller its own crashes the next time it opens. Crash logs from SideStore, LiveContainer and Madeira are read from this iPhone through LocalDevVPN.":
        "iOS transmet à SideInstaller ses propres plantages à sa prochaine ouverture. Les rapports de plantage de SideStore, LiveContainer et Madeira sont lus sur cet iPhone via LocalDevVPN.",
    "Open a GitHub issue": "Ouvrir un ticket GitHub",
    "Share": "Partager",
    "Share the report": "Partager le rapport",
    "Preview the report": "Aperçu du rapport",
    "Report": "Rapport",
    "The issue opens filled in. When the log is too long for that, SideInstaller copies it for you to paste at the end of the issue. The whole report is also saved in %@.":
        "Le ticket s'ouvre déjà rempli. Si le journal est trop long pour ça, SideInstaller le copie pour que tu le colles à la fin du ticket. Le rapport complet est aussi enregistré dans %@.",
    "Files › On My iPhone": "Fichiers › Sur mon iPhone",
    "Copy the full log": "Copier le journal complet",
    "Paste the log into the issue": "Colle le journal dans le ticket",
    "Open GitHub": "Ouvrir GitHub",
    "The full log is too long to fill in, so SideInstaller copied it. On GitHub, tap the end of the text, choose Paste, then submit the issue.":
        "Le journal complet est trop long pour être rempli automatiquement, alors SideInstaller l'a copié. Sur GitHub, touche la fin du texte, choisis Coller, puis envoie le ticket.",
    "Describe the problem above first.": "Décris d'abord le problème ci-dessus.",
    "Couldn't save the report: %@": "Impossible d'enregistrer le rapport : %@",

    // MARK: - Official download check

    "Did you download SideInstaller from sideinstaller.net?":
        "Avez-vous téléchargé SideInstaller depuis sideinstaller.net ?",
    "SideInstaller is open source, so anyone can publish a modified copy that steals the Apple ID typed into it. Only sideinstaller.net is official.":
        "SideInstaller est open source : n'importe qui peut publier une copie modifiée qui vole l'identifiant Apple saisi. Seul sideinstaller.net est officiel.",
    "Yes, from sideinstaller.net":
        "Oui, depuis sideinstaller.net",
    "No, or I'm not sure":
        "Non, ou je ne suis pas sûr",
    "Don't sign in with this copy":
        "Ne vous connectez pas avec cette copie",
    "Copies from anywhere other than sideinstaller.net are unofficial and may have been changed to steal your Apple ID. Delete this one and install SideInstaller from sideinstaller.net, then sign in there.":
        "Les copies provenant d'ailleurs que sideinstaller.net ne sont pas officielles et ont pu être modifiées pour voler votre identifiant Apple. Supprimez celle-ci, installez SideInstaller depuis sideinstaller.net, puis connectez-vous dans cette version.",
    "Open sideinstaller.net":
        "Ouvrir sideinstaller.net",
    "Back":
        "Retour",
    "I understand the risks":
        "Je comprends les risques",
    "Use an unofficial copy?":
        "Utiliser une copie non officielle ?",
    "If this copy was changed, it can send your Apple ID and password to someone else. Continue only if you trust where it came from.":
        "Si cette copie a été modifiée, elle peut envoyer votre identifiant Apple et votre mot de passe à quelqu'un d'autre. Ne continuez que si vous faites confiance à sa provenance.",

    // MARK: - Side by Side: their address, and the pairing file SideInstaller gets

    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Impossible de joindre leur iPhone à l'adresse %@. Vérifiez l'adresse (Réglages › Wi-Fi › ⓘ sur leur iPhone), que les deux iPhone sont sur le même réseau Wi-Fi et que Réseau local est activé pour SideInstaller dans les Réglages de cet iPhone. Les réseaux invités et publics empêchent souvent les appareils de communiquer entre eux.",
    "Their iPhone": "Leur iPhone",
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "Ils ont touché « Ne pas faire confiance » sur leur iPhone. Recommencez et demandez-leur de toucher Faire confiance.",
    "Pairs from its Settings": "Se jumelle depuis ses Réglages",
    "Waiting for them to tap Trust…": "En attente qu'ils touchent Faire confiance…",
    "Tap Trust on their iPhone": "Touchez Faire confiance sur leur iPhone",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "Sur leur iPhone : Réglages › Wi-Fi › ⓘ à côté du réseau, puis « Adresse IP ».",
    "Unlock their iPhone, then tap Trust in the prompt that comes up.":
        "Déverrouillez leur iPhone, puis touchez Faire confiance dans la demande qui s'affiche.",
    "This iPhone is %@, so theirs will look similar.": "Cet iPhone est %@, le leur y ressemblera.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "« %@ » n'est pas une adresse IPv4. Elle doit ressembler à 192.168.1.42.",
    "Do you have the device's IP?": "Avez-vous l'adresse IP de l'appareil ?",
    "Optional": "Facultatif",
    "SideInstaller asks their iPhone to pair directly. Needed below iOS 27.":
        "SideInstaller demande directement à leur iPhone de se jumeler. Nécessaire avant iOS 27.",
    "Their iPhone pairs from its own Settings, which needs iOS 27.":
        "Leur iPhone se jumelle depuis ses propres Réglages, ce qui nécessite iOS 27.",
    "IP address": "Adresse IP",
    "Their iPhone runs iOS %@. From iOS 26.4 on, SideInstaller can't use the pairing their iPhone gives over Wi-Fi, so it needs a pairing file made on a computer.":
        "Leur iPhone est sous iOS %@. À partir d'iOS 26.4, SideInstaller ne peut pas utiliser le jumelage que leur iPhone donne via le Wi-Fi ; il lui faut donc un fichier de jumelage créé sur un ordinateur.",
    "Get LocalDevVPN from the App Store and connect it: SideInstaller works through it.":
        "Installez LocalDevVPN depuis l'App Store et connectez-le : SideInstaller passe par lui.",
    "Open SideInstaller. Its pairing file is already in place.":
        "Ouvrez SideInstaller. Son fichier de jumelage est déjà en place.",
    "Open SideInstaller and import a pairing file made on a computer.":
        "Ouvrez SideInstaller et importez un fichier de jumelage créé sur un ordinateur.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone, so use theirs. To install on this one, use the Install tab.":
        "%@ est une adresse que cet iPhone possède déjà. Side by Side installe sur l'iPhone de quelqu'un d'autre : utilisez le sien. Pour installer sur celui-ci, utilisez l'onglet Installer.",
    "Their iPhone runs iOS %@. From iOS 26.4 on, %@ can't use the pairing their iPhone gives over Wi-Fi. iOS 27 pairs from its own Settings instead, which works: update their iPhone, then try again and answer No when asked for its IP.":
        "Leur iPhone est sous iOS %@. À partir d'iOS 26.4, %@ ne peut pas utiliser le jumelage que leur iPhone donne via le Wi-Fi. iOS 27 se jumelle plutôt depuis ses propres Réglages, ce qui fonctionne : mettez à jour leur iPhone, puis réessayez en répondant Non quand son IP est demandée.",

    // MARK: - AltStore

    "couldn't reach %@: %@":
        "impossible de joindre %@ : %@",
    "%@ answered HTTP %d":
        "%@ a répondu HTTP %d",
    "%@'s list of apps couldn't be read (%@). Something on this network may have replaced it.":
        "impossible de lire la liste d'apps de %@ (%@). Quelque chose sur ce réseau l'a peut-être remplacée.",
    "the %@ that arrived isn't the file %@ lists, so it isn't installed. Try again later.":
        "le %@ reçu n'est pas le fichier indiqué par %@, il n'est donc pas installé. Réessayez plus tard.",
    "%@ lists no version of %@ that runs on iOS %@.":
        "%@ ne propose aucune version de %@ compatible avec iOS %@.",
    "Open AltStore from your Home Screen and sign in with your Apple ID.":
        "Ouvrez AltStore depuis votre écran d'accueil et connectez-vous avec votre Apple ID.",
    "To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings. Its pairing file is already in place, so the setup skips pairing.":
        "Pour installer et renouveler des apps sans ordinateur, touchez « Set up Remote AltServer » dans les réglages d'AltStore. Son fichier de jumelage est déjà en place, la configuration saute donc le jumelage.",
    "To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings and follow its steps.":
        "Pour installer et renouveler des apps sans ordinateur, touchez « Set up Remote AltServer » dans les réglages d'AltStore et suivez les étapes.",
    "Open AltStore and sign in with the same Apple ID.":
        "Ouvrez AltStore et connectez-vous avec le même Apple ID.",

    // MARK: - LAN transfer (browser page)

    "File not found": "Fichier introuvable",
    "Invalid path": "Chemin invalide",
    "Couldn't parse the upload": "Impossible de traiter le fichier envoyé",
    "No such page": "Cette page n'existe pas",
    "Download": "Télécharger",
    "Download complete": "Téléchargement terminé",
    "%@ downloaded. You can install it from the Downloads page.": "%@ téléchargé. Vous pouvez l'installer depuis la page Téléchargements.",
    "Delete this file?": "Supprimer ce fichier ?",
    "This directory is empty": "(Ce répertoire est vide)",
    "SideInstaller LAN Transfer": "Transfert LAN SideInstaller",
    "SideInstaller File Transfer": "Transfert de fichiers SideInstaller",
    "Upload": "Téléverser",
    "File": "Fichier",
    "Size": "Taille",
    "Add": "Ajouter",
    "Add Source": "Ajouter une source",
    "Anyone on your LAN can access it without a password. Turn it off when done.": "Toute personne sur votre réseau local peut y accéder sans mot de passe. Éteignez-le quand vous avez terminé.",
    "Appearance": "Apparence",
    "Apple ID sign-in failed on %@. Last error: %@": "La connexion à l’identifiant Apple a échoué sur %@. Dernière erreur : %@",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Revoke it under Tools › Certificates, then refresh again.": "Apple ne délivrera pas de certificat de signature pour cet identifiant Apple : il signale qu’il en existe déjà un (erreur 7460). Révoquez-le sous Outils › Certificats, puis actualisez à nouveau.",
    "Auto Refresh": "Actualisation auto",
    "Built-in tunnel interface": "Interface du tunnel intégré",
    "Built-in tunnel: interface 10.7.1.1/32 and peer 10.7.0.1/32 by default. Address changes take effect the next time the tunnel connects.": "Tunnel intégré : interface 10.7.1.1/32 et pair 10.7.0.1/32 par défaut. Les changements d’adresse prennent effet à la prochaine connexion du tunnel.",
    "Certificate password:": "Mot de passe du certificat :",
    "Couldn't reach the device at %@:%d at all. The loopback VPN is most likely off, or Device IP isn't the address it carries: in LocalDevVPN that's the one under Settings › Device IP (10.7.0.1 by default), not the “Connected to” address on its main screen. First check that the phone and the computer are on the same Wi-Fi (the local tunnel needs a local network).": "Impossible de joindre l’appareil à %@:%d. Le VPN de bouclage est probablement désactivé, ou l’adresse IP de l’appareil n’est pas celle qu’il utilise : dans LocalDevVPN, c’est celle sous Réglages › Adresse IP de l’appareil (10.7.0.1 par défaut), et non l’adresse « Connecté à » sur son écran principal. Vérifiez d’abord que le téléphone et l’ordinateur sont sur le même Wi-Fi (le tunnel local nécessite un réseau local).",
    "Dark": "Sombre",
    "Every app and app extension SideInstaller signs needs an App ID. A free Apple ID can register 10 a week, and each one counts for 7 days.": "Chaque app et chaque extension que SideInstaller signe a besoin d’un identifiant d’app. Un identifiant Apple gratuit peut en enregistrer 10 par semaine, et chacun compte pendant 7 jours.",
    "Export certificate (p12)": "Exporter le certificat (p12)",
    "Follow System": "Suivre le système",
    "Import failed": "Échec de l’importation",
    "Light": "Clair",
    "Loading…": "Chargement…",
    "Location is not set to “Always”, so only silent audio is keeping the app alive — renewal from the lock screen may be suspended. Set Location to “Always” in Settings.": "La localisation n’est pas réglée sur « Toujours », donc seul l’audio silencieux maintient l’app en vie — le renouvellement depuis l’écran de verrouillage peut être suspendu. Réglez la localisation sur « Toujours » dans Réglages.",
    "No IPA imported.": "Aucun IPA importé.",
    "No sources yet. Tap + to add one.": "Aucune source pour l’instant. Touchez + pour en ajouter une.",
    "Refresh apps automatically in background": "Actualiser les apps automatiquement en arrière-plan",
    "SideInstaller stays alive in the background (silent audio + location) and checks every 30 minutes. Apps whose signing expires within 3 days are re-signed automatically. Location access must be set to “Always” and the tunnel must stay connected (the built-in tunnel is enough). The system also wakes the app in the background from time to time to run a check — don't swipe it away from the app switcher.": "SideInstaller reste actif en arrière-plan (audio silencieux + localisation) et vérifie toutes les 30 minutes. Les apps dont la signature expire dans les 3 jours sont re-signées automatiquement. L’accès à la localisation doit être réglé sur « Toujours » et le tunnel doit rester connecté (le tunnel intégré suffit). Le système réveille aussi l’app en arrière-plan de temps en temps pour lancer une vérification — ne la fermez pas depuis le sélecteur d’apps.",
    "Skipped: not signed by the team you're signed in as, so a certificate-signed app is never re-signed here.": "Ignoré : non signé par l’équipe avec laquelle vous êtes connecté, donc une app signée par certificat n’est jamais re-signée ici.",
    "Source URL": "URL de la source",
    "That isn't a usable source link.": "Ce n’est pas un lien de source utilisable.",
    "The built-in tunnel couldn't start. See the log for the reason, then try again.": "Le tunnel intégré n’a pas pu démarrer. Consultez le journal pour connaître la raison, puis réessayez.",
    "Transfer files to Documents over LAN": "Transférer des fichiers vers Documents via le réseau local",
    "Tunnel peer (device IP)": "Pair du tunnel (IP de l’appareil)",
    "Tunnel standby": "Tunnel en veille",
    "WebDAV failed to start": "Échec du démarrage de WebDAV",
    "WebDAV file service": "Service de fichiers WebDAV",
    "Wi-Fi not connected": "Wi-Fi non connecté",
    "导出描述文件": "Exporter le profil de provisionnement",
    "导出后可在 LiveContainer 里导入同一张证书，不用再找原文件；密码不一起导出，导入时再填一次。": "Après l’exportation, vous pouvez importer le même certificat dans LiveContainer sans retrouver le fichier d’origine ; le mot de passe n’est pas exporté, vous le saisirez à nouveau lors de l’importation.",
    "名字不能以. 开头": "Les noms ne peuvent pas commencer par un point",
    // SIDE-35 (0.9.124): new keys.
    "Modified edition": "Édition modifiée",
    "Archive": "Archive",
    "%@ (extracted)": "%@ (extrait)",
    "Source is too large": "La source est trop volumineuse",
    "Folders can't be deleted": "Les dossiers ne peuvent pas être supprimés",
    // SIDE-36 (0.9.125): new keys.
    "Couldn't read this source": "Impossible de lire cette source",
    "Listing certificates failed: %@": "Échec de la liste des certificats : %@",
    "Revoke failed: %@": "Échec de la révocation : %@",
    "Couldn't parse p12 export result.": "Impossible d'analyser le résultat de l'export p12.",
    "Export failed: %@": "Échec de l'export : %@",
    "Listing App IDs failed: %@": "Échec de la liste des identifiants d'app : %@",
    "Enabling entitlements failed: %@": "Échec de l'activation des droits : %@",
    "Waiting for this install to finish…": "En attente de la fin de cette installation…",
    "This file is being installed. Wait until it finishes.": "Ce fichier est en cours d'installation. Attendez qu'elle se termine.",
    "The device answered on the RSD port at %@, then the tunnel port it opened was unreachable on that same address — dropped or refused, across %@. The device is there; what's in front of it is forwarding some ports and not others. The tunnel opens on a fresh high port every attempt, so a rule-based proxy that forwards the RSD port alone can never cover it. Use a loopback VPN that blanket-forwards every port on the RSD subnet. Re-pairing won't help — the pairing is fine.": "L'appareil a répondu sur le port RSD à %@, mais le port de tunnel qu'il a ouvert était inaccessible à cette même adresse — abandonné ou refusé, sur %@. L'appareil est bien là ; ce qui se trouve devant ne fait suivre que certains ports et pas d'autres. Le tunnel s'ouvre sur un nouveau port élevé à chaque tentative, donc un proxy basé sur des règles qui ne fait suivre que le port RSD ne pourra jamais tout couvrir. Utilisez un VPN de bouclage qui fait suivre tous les ports du sous-réseau RSD. Refaire l'appairage ne servira à rien — l'appairage lui-même est correct.",
    "The tunnel port never answered and never refused on any address (%@) — the connection is being swallowed rather than rejected. That's usually a VPN or firewall dropping traffic on the RSD subnet. Check the VPN is still up, then try again.": "Le port du tunnel n'a jamais répondu ni refusé sur aucune adresse (%@) — la connexion est avalée plutôt que rejetée. C'est généralement un VPN ou un pare-feu qui abandonne le trafic sur le sous-réseau RSD. Vérifiez que le VPN est toujours actif, puis réessayez.",
    "Something accepted the tunnel connection but failed the encrypted handshake on top of it. Either another process holds that port, or this pairing file's key no longer matches the device. Pair again, and if that doesn't take, restart the loopback VPN.": "Quelque chose a accepté la connexion du tunnel mais a échoué lors de la poignée de main chiffrée. Soit un autre processus occupe ce port, soit la clé de ce fichier d'appairage ne correspond plus à l'appareil. Appairez à nouveau et, si ça ne marche pas, redémarrez le VPN de bouclage.",
    "The device rejected this pairing file: it's for a different device, or the pairing was revoked (a reset, a restore, or Developer Mode being turned off). Pair with this iPhone again to get a fresh file.": "L'appareil a rejeté ce fichier d'appairage : il est pour un autre appareil, ou l'appairage a été révoqué (une réinitialisation, une restauration, ou le mode développeur désactivé). Appairez à nouveau cet iPhone pour obtenir un nouveau fichier.",
    "The tunnel didn't come up, and the failure didn't match any known cause. The raw error is in the log.": "Le tunnel ne s'est pas établi et l'échec ne correspond à aucune cause connue. L'erreur brute est dans le journal.",
    "Diagnostics: remote pairing advertisement: %@; Developer Mode: %@.": "Diagnostic : annonce d'appairage distant : %@ ; mode développeur : %@.",
    "No anisette servers are configured.": "Aucun serveur anisette n'est configuré.",
    "Sign-in failed.": "La connexion a échoué.",
    "This folder can't be renamed or moved.": "Ce dossier ne peut pas être renommé ni déplacé.",
    "This file is being signed. Wait until it finishes.": "Ce fichier est en cours de signature. Attendez qu'elle se termine.",
    "This file is being renewed. Wait until it finishes.": "Ce fichier est en cours de renouvellement. Attendez qu'il se termine.",
    "This only clears the list. Installed apps are not affected.": "Cela efface seulement la liste. Les apps installées ne sont pas affectées.",
    "empty account config": "Configuration du compte vide",
    "%d files, first %@: %@": "%d fichiers, le premier %@ : %@",
    "%@ isn't listed": "%@ n'est pas répertorié",
    "the data couldn't be read": "Les données n'ont pas pu être lues",
    "Couldn't reach this iPhone. Check the connection and try again.": "Impossible de joindre cet iPhone. Vérifiez la connexion puis réessayez.",
    "the connection to this iPhone failed": "la connexion à cet iPhone a échoué.",

    // MARK: - SIDE-43+44 (0.9.132)
    "This Apple ID has no development team. Sign in at developer.apple.com once to create one, then try again.": "Cet identifiant Apple n'a aucune équipe de développement. Connectez-vous une fois sur developer.apple.com pour en créer une, puis réessayez.",
    "That certificate belongs to another Apple ID, or it was revoked.": "Ce certificat appartient à un autre identifiant Apple, ou il a été révoqué.",
    "That App ID is no longer on this team.": "Cet identifiant d'app ne fait plus partie de cette équipe.",
    "That file isn't a certificate archive (.p12). Check the file and try again.": "Ce fichier n'est pas une archive de certificat (.p12). Vérifiez le fichier et réessayez.",
    "There's no signing certificate on this Apple ID yet. Install an app first — that's what creates it.": "Il n'y a pas encore de certificat de signature pour cet identifiant Apple. Installez d'abord une app — c'est l'installation qui le crée.",
    "Check the network connection and try again.": "Vérifiez la connexion réseau et réessayez.",
    "Apple didn't accept the sign-in. Check the Apple ID and password, then try again.": "Apple n'a pas accepté la connexion. Vérifiez l'identifiant Apple et le mot de passe, puis réessayez.",
    "Sign-ins are being limited right now. Wait a few minutes and try again.": "Les connexions sont limitées pour le moment. Attendez quelques minutes et réessayez.",
    "Apple's service didn't answer. Try again in a bit.": "Le service Apple n'a pas répondu. Réessayez dans un instant.",
    "This iPhone is out of storage space. Free some space and try again.": "Cet iPhone n'a plus d'espace de stockage. Libérez de l'espace et réessayez.",
    "A file this step needed is missing. Check the file library and try again.": "Un fichier nécessaire à cette étape est introuvable. Vérifiez la bibliothèque de fichiers et réessayez.",
    "Something went wrong. Check the activity log and try again.": "Quelque chose s'est mal passé. Consultez le journal d'activité et réessayez.",
    "Couldn't read the certificate list.": "Impossible de lire la liste des certificats.",
    "Couldn't read what the import did.": "Impossible de lire le résultat de l'importation.",
    "Couldn't read the App ID list.": "Impossible de lire la liste des identifiants d'app.",
    "Couldn't read Apple's reply.": "Impossible de lire la réponse d'Apple.",
    "瘦身改包解压失败。": "Échec de la décompression pour l'allègement du paquet.",
    "瘦身改包压包失败。": "Échec de la compression pour l'allègement du paquet.",
    "Pairing file for another iPhone": "Fichier de jumelage d'un autre iPhone",
    "This pairing file belongs to another iPhone (UDID %@). The iPhone connected now is %@.": "Ce fichier de jumelage appartient à un autre iPhone (UDID %@). L'iPhone actuellement connecté est %@.",
    "The route server couldn't plan this route.": "Le serveur d'itinéraires n'a pas pu planifier cet itinéraire.",
    "Their iPhone connected but stopped responding before asking for a code. Try pairing again.": "Leur iPhone s'est connecté mais n'a pas répondu avant de demander un code. Essayez de jumeler à nouveau.",
    "The pairing code wasn't entered in time. Pair again and enter the code when it appears.": "Le code de jumelage n'a pas été saisi à temps. Jumelez à nouveau et saisissez le code dès qu'il apparaît.",
    "Their iPhone rejected this pairing file: it's for a different device, or the pairing was revoked (a reset, a restore, or Developer Mode being turned off). Pair with their iPhone again to get a fresh file.":
        "Leur iPhone a rejeté ce fichier de jumelage : il appartient à un autre appareil, ou le jumelage a été révoqué (une réinitialisation, une restauration, ou le mode développeur désactivé). Jumelez à nouveau leur iPhone pour obtenir un nouveau fichier.",
    "Their iPhone answered, but the tunnel port it opened couldn't be reached — something between the two iPhones is forwarding some ports and not others. Check both iPhones are on the same Wi-Fi network (not a guest network), and that Local Network is on for SideInstaller in this iPhone's Settings. Re-pairing won't help — the pairing is fine.":
        "Leur iPhone a répondu, mais le port du tunnel qu'il a ouvert est inaccessible — quelque chose entre les deux iPhone ne laisse passer que certains ports. Vérifiez que les deux iPhone sont sur le même réseau Wi-Fi (pas un réseau invité) et que Réseau local est activé pour SideInstaller dans les Réglages de cet iPhone. Jumeler à nouveau ne servira à rien — le jumelage est bon.",
    "Their iPhone never answered the tunnel port and never refused it — the connection is being swallowed rather than rejected. That's usually the Wi-Fi network or a firewall dropping traffic on the way. Check both iPhones are on the same Wi-Fi network, then try again.":
        "Leur iPhone n'a jamais répondu au port du tunnel, ni refusé la connexion — la connexion est avalée plutôt que rejetée. C'est généralement le réseau Wi-Fi ou un pare-feu qui bloque le trafic en route. Vérifiez que les deux iPhone sont sur le même réseau Wi-Fi, puis réessayez.",
    "Something accepted the tunnel connection but the encrypted handshake on top of it failed. Either another process holds that port, or this pairing file's key no longer matches their iPhone. Pair again.":
        "Quelque chose a accepté la connexion du tunnel, mais la poignée de main chiffrée par-dessus a échoué. Soit un autre processus occupe ce port, soit la clé de ce fichier de jumelage ne correspond plus à leur iPhone. Jumelez à nouveau.",
    "GitHub answered HTTP %d":
        "GitHub a répondu HTTP %d",
    "The code was incorrect. Try again.":
        "Le code était incorrect. Réessayez.",
    "A code was already sent and is still valid. Enter it.":
        "Un code a déjà été envoyé et il est toujours valable. Saisissez-le.",
    "That way isn't available. Choose another way.":
        "Ce moyen n'est pas disponible. Choisissez-en un autre.",
    "That didn't work. Try another way.":
        "Ça n'a pas marché. Essayez un autre moyen.",
    // MARK: - Developer team

    "Free · %@": "Gratuite · %@",
    "Paid · %@": "Payante · %@",
    "This Apple Account is on %d developer teams. Pick the one that signs.":
        "Ce compte Apple fait partie de %d équipes de développement. Choisissez celle qui signe.",
    "Which Team?": "Quelle équipe ?",
    "Signed this copy of SideInstaller": "A signé cette copie de SideInstaller",
    "A free team's apps last 7 days; a paid team's last a year.":
        "Les apps d'une équipe gratuite durent 7 jours ; celles d'une équipe payante, un an.",
    "An app installed with another team isn't replaced: signing it with this one installs a second copy.":
        "Une app installée avec une autre équipe n'est pas remplacée : la signer avec celle-ci en installe une deuxième copie.",
    "SideInstaller remembers the pick for this Apple ID. To pick again, open Settings › Account, swipe the Apple ID left and tap Team.":
        "SideInstaller retient ce choix pour cet Apple ID. Pour choisir à nouveau, ouvrez Réglages › Compte, balayez l'Apple ID vers la gauche et touchez Équipe.",
    "No developer team was picked, so the sign-in stopped.":
        "Aucune équipe de développement n'a été choisie, la connexion s'est donc arrêtée.",
    "Your Apple Account is on more than one developer team. Open SideInstaller and pick the one that signs.":
        "Votre compte Apple fait partie de plusieurs équipes de développement. Ouvrez SideInstaller et choisissez celle qui signe.",
    "Pick the team again?": "Choisir l'équipe à nouveau ?",
    "Pick Again": "Choisir à nouveau",
    "The next sign-in with “%@” asks which developer team signs.":
        "La prochaine connexion avec « %@ » demandera quelle équipe de développement signe.",
    // Shortcuts actions (ShortcutsSupport.swift and the *Shortcuts.swift files).
    "%@ can't be refreshed: SideInstaller has no IPA to sign it again from. Refresh it in whatever installed it, or import its .ipa into SideInstaller first.":
        "Impossible de renouveler %@ : SideInstaller n'a pas d'IPA pour la signer à nouveau. Renouvelez-la dans l'app qui l'a installée, ou importez d'abord son .ipa dans SideInstaller.",
    "%@ is installed.":
        "%@ est installé.",
    "Apple is asking you to finish signing in. Continue in SideInstaller to answer it.":
        "Apple vous demande de terminer la connexion. Continuez dans SideInstaller pour y répondre.",
    "LocalDevVPN is connected.":
        "LocalDevVPN est connecté.",
    "LocalDevVPN isn't connected. Connect it before this action runs: Shortcuts' Set VPN action can, or turn on “Start LocalDevVPN when needed” in SideInstaller's Settings.":
        "LocalDevVPN n'est pas connecté. Connectez-le avant que cette action ne s'exécute : l'action VPN de Raccourcis peut le faire. Sinon, activez « Lancer LocalDevVPN au besoin » dans les Réglages de SideInstaller.",
    "LocalDevVPN isn't connected. Continue in SideInstaller to connect it.":
        "LocalDevVPN n'est pas connecté. Continuez dans SideInstaller pour le connecter.",
    "No route is playing.":
        "Aucun itinéraire n'est en cours de lecture.",
    "Open SideInstaller and accept its terms first.":
        "Ouvrez d'abord SideInstaller et acceptez ses conditions.",
    "Pick where the route starts, or set a location first.":
        "Choisissez le point de départ de l'itinéraire, ou définissez d'abord une position.",
    "Route started: %@, about %@.":
        "Itinéraire lancé : %@, environ %@.",
    "That place has no coordinates. Pick it on the map, or type its address.":
        "Ce lieu n'a pas de coordonnées. Choisissez-le sur la carte, ou saisissez son adresse.",
    "The install didn't start. Open SideInstaller to see why.":
        "L'installation n'a pas démarré. Ouvrez SideInstaller pour en voir la raison.",

    // MARK: - Sources

    "Suggested":
        "Suggestions",

    "Paste the link of a SideStore or AltStore source, or of a .json source file. Its apps, their updates and release notes show here.":
        "Collez le lien d'une source SideStore ou AltStore, ou d'un fichier source .json. Ses apps, leurs mises à jour et leurs notes de version s'affichent ici.",
    "Add a source":
        "Ajouter une source",
    "Updates":
        "Mises à jour",
    "Update":
        "Mettre à jour",
    "Your sources":
        "Vos sources",
    "Check for updates":
        "Rechercher des mises à jour",
    "Copy link":
        "Copier le lien",
    "Source options":
        "Options de la source",
    "What's new":
        "Nouveautés",
    "Version history":
        "Historique des versions",
    "This version has no release notes.":
        "Cette version n'a pas de notes de version.",
    "%d update":
        "%d mise à jour",
    "%d updates":
        "%d mises à jour",
    "%d updates · Total size: %@": "%d mises à jour · Taille totale : %@",
    "%d 个可更新": "%d mises à jour disponibles",
    "全部更新进行中，等它跑完再批量安装。":
        "Une mise à jour de toutes les apps est en cours. Attendez qu'elle se termine avant d'installer en lot.",
    "全部更新进行中，等它跑完再重装。":
        "Une mise à jour de toutes les apps est en cours. Attendez qu'elle se termine avant de réinstaller.",
    "全部更新进行中，等它跑完再重试。":
        "Une mise à jour de toutes les apps est en cours. Attendez qu'elle se termine avant de réessayer.",
    "全部更新进行中，等它跑完再续签。": "Une mise à jour de toutes les apps est en cours. Attendez qu'elle se termine avant de renouveler.",
    "An update-all batch is running. Wait for it to finish, then try again.":
        "Une mise à jour de toutes les apps est en cours. Attendez qu'elle se termine, puis réessayez.",
    "全部更新进行中，等它跑完再更新。":
        "Une mise à jour de toutes les apps est en cours. Attendez qu'elle se termine avant de mettre à jour.",
    "上次刷新失败：%@": "Dernier rafraîchissement échoué : %@",
    "已停止更新：成功 %d 个，剩余 %d 个未更新。":
        "Mise à jour interrompue : %d réussies, %d restantes non mises à jour.",
    "%d source":
        "%d source",
    "%d sources":
        "%d sources",
    "Update to %@":
        "Mettre à jour vers %@",
    "Update now": "Mettre à jour maintenant",
    "Install %@ %@?":
        "Installer %@ %@ ?",
    "Version %@ · from %@":
        "Version %@ · de %@",
    "%@ installed · %@ available":
        "%@ installée · %@ disponible",
    "%@ installed · up to date":
        "%@ installée · à jour",
    "That source is already added.":
        "Cette source est déjà ajoutée.",
    "The source answered with HTTP %d.":
        "La source a répondu avec HTTP %d.",
    "Couldn't reach the source: %@":
        "Impossible de joindre la source : %@",
    "That isn't a source link. Paste the whole https:// address of the source.":
        "Ce n'est pas un lien de source. Collez l'adresse https:// complète de la source.",
    "That link didn't return a source. It has to be the source's JSON file itself.":
        "Ce lien n'a pas renvoyé de source. Il doit pointer vers le fichier JSON de la source lui-même.",
    "Downloads the IPA from the source, then signs it with your Apple ID and installs it, as a custom .ipa would be.":
        "Télécharge l'IPA depuis la source, puis la signe avec votre identifiant Apple et l'installe, comme un .ipa personnalisé.",
    "This version is older than the newest one. It's installed over the copy on this iPhone, which may not open data a newer version saved.":
        "Cette version est plus ancienne que la dernière. Elle est installée par-dessus la copie de cet iPhone, qui risque de ne pas ouvrir les données enregistrées par une version plus récente.",
    "This version is older than the one on this iPhone (%@). Installed over it, it may not open data the newer version saved.":
        "Cette version est plus ancienne que celle de cet iPhone (%@). Installée par-dessus, elle risque de ne pas ouvrir les données enregistrées par la version plus récente.",

    // MARK: - JIT

    "%@ has the JIT memory it asked for, so SideInstaller let go of it. JIT stays on until it quits.":
        "%@ a obtenu la mémoire JIT qu'elle demandait, SideInstaller s'est donc détaché. Le JIT reste actif jusqu'à ce que l'app se ferme.",
    "%@ of JIT memory prepared": "%@ de mémoire JIT préparée",
    "%d app can use JIT": "%d app peut utiliser le JIT",
    "%d apps can use JIT": "%d apps peuvent utiliser le JIT",
    "Attach and detach": "Attacher et détacher",
    "Attaching the debugger": "Attachement du débogueur",
    "Auto: %@": "Automatique : %@",
    "Connecting to this iPhone's debugger": "Connexion au débogueur de cet iPhone",
    "Couldn't open %@ under the debugger: %@": "Impossible d'ouvrir %@ sous le débogueur : %@",
    "Couldn't reach the debugger on this iPhone: %@":
        "Impossible de joindre le débogueur de cet iPhone : %@",
    "Enable JIT": "Activer le JIT",
    "Continue JIT for %@": "Reprendre JIT pour %@",
    "JIT is on for %@ until it quits.": "Le JIT est actif pour %@ jusqu'à sa fermeture.",
    "JIT is on. SideInstaller stays attached while %@ runs: keep SideInstaller in the background, since closing it ends JIT.":
        "Le JIT est actif. SideInstaller reste attaché pendant que %@ tourne : laissez SideInstaller en arrière-plan, car le fermer met fin au JIT.",
    "JIT needs Developer Mode. Turn it on under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.":
        "Le JIT nécessite le Mode développeur. Activez-le dans Réglages › Confidentialité et sécurité › Mode développeur, et confirmez-le après le redémarrage.",
    "JIT on for %@": "JIT actif pour %@",
    "Legacy": "Ancien",
    "No app on this iPhone is signed for development, which a debugger needs. Install the app with SideStore or SideInstaller, which sign apps that way, then load the apps again.":
        "Aucune app de cet iPhone n'est signée pour le développement, ce dont un débogueur a besoin. Installez l'app avec SideStore ou SideInstaller, qui signent les apps ainsi, puis rechargez les apps.",
    "No apps can use JIT": "Aucune app ne peut utiliser le JIT",
    "Opening %@": "Ouverture de %@",
    "Quit %@": "Quitter %@",
    "The debugger couldn't attach to %@ (%@). Install it again with SideStore or SideInstaller, which sign apps so a debugger can attach.":
        "Le débogueur n'a pas pu s'attacher à %@ (%@). Réinstallez-la avec SideStore ou SideInstaller, qui signent les apps pour qu'un débogueur puisse s'y attacher.",
    "The debugger lost %@ (%@). Open it with JIT again.":
        "Le débogueur a perdu %@ (%@). Rouvrez-la avec le JIT.",
    "Universal": "Universel",

    // MARK: - Batch install, history empty state & clear-downloads failures (0.9.151)

    "安装所选": "Installer la sélection",
    "正在安装第 %d/%d 个：%@": "Installation %d/%d : %@",
    "批量安装完成：%d 个已安装。": "Installation par lots terminée : %d installées.",
    "批量安装完成：成功 %d 个，失败 %d 个。失败：%@": "Installation par lots terminée : %d réussies, %d échouées. Échouées : %@",
    "等 %d 个": "et %d autres",
    "其中 %d 个不是 IPA，已跳过。": "%d n’étaient pas des IPA, ils ont été ignorés.",
    "已有安装在进行，先等当前安装完成再批量安装。": "Une installation est déjà en cours. Attendez qu’elle se termine avant l’installation par lots.",
    "已有安装在进行，先等当前安装完成再试。": "Une installation est déjà en cours. Attendez qu’elle se termine avant de réessayer.",
    "正在签名，等它跑完再批量安装。": "Signature en cours. Attendez qu’elle se termine avant l’installation par lots.",
    "Installed apps will be listed here.": "Les apps installées seront listées ici.",
    "以下 %d 个删除失败：%@": "Impossible de supprimer %d fichiers : %@",

    // MARK: - F1 source toggle, F2 source export/import & F3 download rename (0.9.152)

    "Enabled": "Activée",
    "Names can't be empty, contain /, or start with .": "Les noms ne peuvent pas être vides, contenir / ni commencer par .",
    "Export sources": "Exporter les sources",
    "Import sources": "Importer les sources",
    "The clipboard has no source list to import.": "Le presse-papiers ne contient aucune liste de sources à importer.",
    "Imported %d, already added %d, failed %d.": "%d importées, %d déjà ajoutées, %d en échec.",

    // MARK: - F3 update-all, F4 batch move & F5 log export (0.9.154)

    "全部更新": "Tout mettre à jour",
    "正在更新第 %d/%d 个：%@": "Mise à jour %d/%d : %@",
    "正在读取已装 App…": "Lecture des apps installées…",
    "全部更新完成：%d 个已更新。": "Mises à jour terminées : %d mises à jour.",
    "全部更新完成：成功 %d 个，失败 %d 个。失败：%@": "Mises à jour terminées : %d réussies, %d échouées. Échouées : %@",
    "移动": "Déplacer",
    "已移动 %d 个。": "%d déplacés.",
    "已移动 %d 个，失败 %d 个。失败：%@": "%d déplacés, %d échoués. Échoués : %@",
    "导出日志": "Exporter le journal",

    // MARK: - F-C download speed/ETA & F-G Wi-Fi only downloads (0.9.156)

    "%@/s": "%@/s",
    "%@ left": "encore %@",
    "Download over cellular?": "Télécharger avec les données mobiles ?",
    "Size: %@": "Taille : %@",
    "Size unknown": "Taille inconnue",
    "You're on cellular data. This download will use your mobile data.": "Vous êtes en données mobiles. Ce téléchargement utilisera vos données mobiles.",
    "Wi-Fi only downloads": "Téléchargements en Wi-Fi uniquement",
    "When on, a download over cellular data asks first, so a large IPA doesn't use your mobile data.": "Si activé, un téléchargement en données mobiles demande d'abord confirmation, pour qu'un gros IPA n'utilise pas vos données mobiles.",
    "Downloads": "Téléchargements",

    // MARK: - F-3 enterprise certificate expiry notice (0.9.157)

    "Enterprise certificate expiring": "Certificat d'entreprise bientôt expiré",
    "The enterprise certificate expires on %@. Re-import it in time.": "Le certificat d'entreprise expire le %@. Réimportez-le à temps.",
    "The enterprise provisioning profile expires on %@. Re-import it in time.": "Le profil de provisionnement d'entreprise expire le %@. Réimportez-le à temps.",

    // MARK: - 0.9.159: delete after install, downgrade check, dev-cert notice

    "Delete the IPA after installing": "Supprimer l’IPA après l’installation",
    "Deletes the source IPA after a successful install. Files used for renewal are kept.": "Supprime l’IPA source après une installation réussie. Les fichiers utilisés pour le renouvellement sont conservés.",
    "Install an older version?": "Installer une version plus ancienne ?",
    "Installed: %@ · This IPA: %@": "Installée : %@ · Cet IPA : %@",
    "Couldn't read their iPhone's iOS version. Reconnect and try again — installing without it could put an app their iPhone can't run on it.": "Impossible de lire la version d’iOS de leur iPhone. Reconnectez-vous et réessayez — installer sans la connaître pourrait installer une app que leur iPhone ne peut pas exécuter.",
    "Development certificate expiring": "Certificat de développement bientôt expiré",
    "The development certificate \"%@\" expires on %@. Renew it in time, or installs will fail.": "Le certificat de développement « %@ » expire le %@. Renouvelez-le à temps, sinon les installations échoueront.",
    "This IPA asks for %@, which a free Apple ID certificate can't provide. Those features will silently stop working after install.": "Cet IPA demande %@, ce qu'un certificat Apple ID gratuit ne peut pas fournir. Ces fonctionnalités cesseront silencieusement de fonctionner après l'installation.",
    "Before you install": "Avant l'installation",
    "Reinstall all": "Tout réinstaller",
    "Reinstall all finished: %d succeeded, %d failed, %d skipped.": "Réinstallation terminée : %d réussie(s), %d échouée(s), %d ignorée(s).",
    "Failed: %@": "Échec : %@",
    "Still getting ready. Try again in a moment.": "Préparation en cours. Réessayez dans un instant.",

    // MARK: - 0.9.161: uninstall, clean up old versions, last-checked, partial pairing write

    "Uninstall": "Désinstaller",
    "Uninstall %@?": "Désinstaller %@ ?",
    "This removes %@ from this iPhone, including its data.": "Cela supprime %@ de cet iPhone, y compris ses données.",
    "SideInstaller can't uninstall itself.": "SideInstaller ne peut pas se désinstaller.",
    "Clean up old versions": "Nettoyer les anciennes versions",
    "Clean up %d old versions?": "Nettoyer %d anciennes versions ?",
    "Only the newest version of each app is kept. Deleted files can't be recovered.": "Seule la version la plus récente de chaque app est conservée. Les fichiers supprimés ne peuvent pas être récupérés.",
    "Cleaned up %d old versions.": "%d anciennes versions nettoyées.",
    "No old versions to clean up.": "Aucune ancienne version à nettoyer.",
    "%d files skipped (in use or needed for renewal).": "%d fichiers ignorés (en cours d'utilisation ou nécessaires au renouvellement).",
    "%d files couldn't be deleted: %@": "Impossible de supprimer %d fichiers : %@",
    "上次巡检：%@": "Dernière vérification : %@",
    "Checked just now": "Vérifié à l'instant",
    "Checked %d minutes ago": "Vérifié il y a %d minutes",
    "Checked %d hours ago": "Vérifié il y a %d heures",
    "Checked %d days ago": "Vérifié il y a %d jours",
    "Pairing file installed into %@, but couldn't be written into %@.": "Fichier de jumelage installé dans %@, mais impossible de l'écrire dans %@.",

    // 0.9.164
    "Loop route": "Rejouer la route en boucle",
    "Newer than installed %@": "Plus récent que la version installée %@",
    "Older than installed %@": "Plus ancien que la version installée %@",
    "Same as installed %@": "Identique à la version installée %@",
    "Show in Downloads": "Afficher dans Téléchargements",
    "Timed out waiting for the install slot — the download was discarded. Try again.": "Délai d'attente de l'emplacement d'installation dépassé — le téléchargement a été supprimé. Réessayez.",
    "Still installing — check the Install page for progress.": "Installation toujours en cours — consultez la page d’installation pour suivre la progression.",
    "Installing — tap to cancel": "Installation en cours — toucher pour annuler",

    // 0.9.166
    "All": "Tout",
    "Succeeded": "Réussis",
    "Restore real location when done": "Restaurer la position réelle à la fin",
    "Import a .gpx file and the device moves along it at the speed you pick. When it ends, the device stays at its last point, unless restoring the real location when done is on.": "Importe un fichier .gpx : l'appareil le parcourt à la vitesse choisie. À la fin, il reste sur le dernier point, sauf si la restauration de la position réelle est activée.",
    "移动“%@”？": "Déplacer « %@ » ?",
    "This is the IPA on the Install tab. Moving it empties that slot — install it from its new folder instead.": "C'est l'IPA de l'onglet Installer. Le déplacer vide cet emplacement — installez-le plutôt depuis son nouveau dossier.",
    "Move": "Déplacer",
    "其中 %d 个因拒绝降级而跳过。": "Dont %d ont été ignorés pour refus de rétrograder.",

    // 0.9.167
    "Folder": "Dossier",
    "Export history": "Exporter l'historique",
    "No files match the current filter.": "Aucun fichier ne correspond au filtre actuel.",

    // 0.9.174
    "Retry all": "Tout réessayer",
    "Skip": "Ignorer",
    "Clear all": "Tout effacer",
    "Clear all failed downloads?": "Effacer tous les téléchargements échoués ?",
    "全部更新进行中，等它跑完再安装。": "Une mise à jour de toutes les apps est en cours. Attendez qu'elle se termine avant d'installer.",
    "其中 %d 个已跳过。": "Dont %d ignorées.",

    // 0.9.178
    "从未巡检": "Jamais vérifiée",
    "上次自动续签：%@": "Dernier renouvellement automatique : %@",

    // 0.9.179
    "Choose how to sign": "Choisir la méthode de signature",
    "Enterprise signing keeps the Bundle ID unchanged.": "La signature avec le certificat d'entreprise conserve le Bundle ID.",
    "Apple ID signing changes the Bundle ID to “original ID.team ID”, so it installs as a second icon.": "La signature avec l'identifiant Apple modifie le Bundle ID en « ID d'origine.ID d'équipe » et installe une deuxième icône.",
    "Update to %@ · %@": "Mettre à jour vers %@ · %@",

    // 0.9.182
    "从未自动续签": "Jamais renouvelé automatiquement",
    "粘贴": "Coller",
    "Recent links": "Liens récents",
    "Clear recent links": "Effacer les liens récents",
    "Copy Bundle ID": "Copier l’identifiant du bundle",

]
