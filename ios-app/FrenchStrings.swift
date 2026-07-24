import Foundation

/// French copy, keyed by the English source string every call site passes to
/// `L(_:)` — same contract as the other tables: same keys, same placeholders,
/// product and third-party UI names left in English.
///
/// Two conventions here: the formal "vous", the way Apple's own French copy
/// addresses users; and iOS's French vocabulary for anything the user has to go
/// find on their phone — Réglages, jumelage, Faire confiance — so an instruction
/// names what's actually printed on screen.
let frenchStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "Annuler",
    "Copy": "Copier",
    "Email": "E-mail",
    "Password": "Mot de passe",
    "Install": "Installer",
    "Installing": "Installation en cours",
    "Installed": "Installé",
    "Something went wrong": "Une erreur s'est produite",
    "an app by Frizzle": "une app de Frizzle",
    "device": "appareil",

    // MARK: - Welcome

    "I have accepted the": "J'accepte les",
    "Start": "Commencer",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "Jumelage",
    "Certificates": "Certificats",
    "Two-Factor Code": "Code de validation",
    "6-digit code": "Code à 6 chiffres",
    "Submit": "Envoyer",
    "Enter the code Apple just sent to your trusted device.":
        "Saisissez le code qu'Apple vient d'envoyer à votre appareil de confiance.",

    // MARK: - Install tab

    "Tunnel connected": "Tunnel connecté",
    "Tunnel off": "Tunnel désactivé",
    "Update available": "Mise à jour disponible",
    "SideInstaller %@ is available — you're on %@.":
        "SideInstaller %@ est disponible — vous utilisez la %@.",
    "Get the latest version": "Obtenir la dernière version",
    "Release": "Canal",
    "Reinstall": "Réinstaller",
    "Install %@": "Installer %@",
    "iOS %@ required": "iOS %@ requis",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Cet iPhone est sous iOS %@, sur lequel SideInstaller ne peut rien installer. Mettez à jour vers iOS %@ ou une version ultérieure dans Réglages › Général › Mise à jour logicielle.",
    "Wi-Fi required": "Wi-Fi requis",
    "Connect to a Wi-Fi network. LocalDevVPN's tunnel and the install run over it.":
        "Connectez-vous à un réseau Wi-Fi. Le tunnel de LocalDevVPN et l'installation passent par ce réseau.",
    "LocalDevVPN required": "LocalDevVPN requis",
    "Open LocalDevVPN and tap Connect. The install runs over its tunnel.":
        "Ouvrez LocalDevVPN et touchez Connect. L'installation passe par son tunnel.",
    "Pairing code": "Code de jumelage",
    "Type this into the prompt in Settings.":
        "Saisissez ce code dans la demande affichée dans Réglages.",
    "Install stopped": "Installation interrompue",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ est installé. Terminez l'étape de confiance ci-dessus pour l'ouvrir.",
    "Action needed": "Action requise",

    // MARK: - Install steps

    "Connect the VPN": "Connecter le VPN",
    "Pair with this iPhone": "Jumeler avec cet iPhone",
    "Open the device link": "Ouvrir la liaison avec l'appareil",
    "Sign in to Apple ID": "Se connecter à l'Apple ID",
    "Download %@": "Télécharger %@",
    "Sign the app": "Signer l'app",
    "Finish setup": "Terminer la configuration",

    // MARK: - Pairing tab

    "Pairing file ready": "Fichier de jumelage prêt",
    "No pairing file": "Aucun fichier de jumelage",
    "Pairing file": "Fichier de jumelage",
    "Pairing…": "Jumelage…",
    "Regenerate": "Régénérer",
    "Generate pairing file": "Générer le fichier de jumelage",
    "Export pairing file": "Exporter le fichier de jumelage",
    "Pair in Settings": "Jumeler dans Réglages",
    "Install into an app": "Installer dans une app",
    "Scanning": "Recherche",
    "Rescan apps": "Rechercher à nouveau",
    "Scan installed apps": "Rechercher les apps installées",
    "Connect to Wi-Fi to scan and install. LocalDevVPN's tunnel runs over it.":
        "Connectez-vous au Wi-Fi pour rechercher et installer. Le tunnel de LocalDevVPN passe par ce réseau.",
    "Turn on LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Activez LocalDevVPN pour rechercher et installer. L'écriture passe par son tunnel.",
    "%d supported app installed": "%d app compatible installée",
    "%d supported apps installed": "%d apps compatibles installées",
    "No supported apps found": "Aucune app compatible trouvée",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Installez d'abord une app comme SideStore, StikDebug ou Feather, puis relancez la recherche.",
    "Install pairing": "Installer le jumelage",
    "Pairing file ready. You can export it or install it into an app below.":
        "Fichier de jumelage prêt. Vous pouvez l'exporter ou l'installer dans une app ci-dessous.",
    "Pairing file installed into %@.": "Fichier de jumelage installé dans %@.",

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
    "Refreshing": "Actualisation",
    "Signing in": "Connexion en cours",
    "Refresh": "Actualiser",
    "Load certificates": "Charger les certificats",
    "%d of 3 certificates": "Certificats : %d sur 3",
    "No certificates": "Aucun certificat",
    "This Apple ID has no development certificates to revoke.":
        "Cet Apple ID n'a aucun certificat de développement à révoquer.",
    "Expired": "Expiré",
    "Expires %@": "Expire le %@",
    "Unnamed certificate": "Certificat sans nom",
    "Enter your Apple ID email and password first.":
        "Saisissez d'abord l'e-mail et le mot de passe de votre Apple ID.",
    "This certificate has no serial number, so it can't be revoked.":
        "Ce certificat n'a pas de numéro de série, il ne peut donc pas être révoqué.",

    // MARK: - Settings

    "Settings": "Réglages",
    "Done": "Terminé",
    "Language": "Langue",
    "App language": "Langue de l'app",
    "Auto": "Automatique",
    "Downloaded IPAs": "IPA téléchargés",
    "%@ used": "%@ utilisés",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "Aucun IPA téléchargé. Ceux que vous installez depuis l'onglet Installer sont conservés ici.",
    "Downloaded %@": "Téléchargé le %@",
    "Delete this download?": "Supprimer ce téléchargement ?",
    "Delete": "Supprimer",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "« %@ » (%@) sera supprimé. Vous pourrez le retélécharger à tout moment depuis l'onglet Installer.",
    "Couldn't delete %@: %@": "Impossible de supprimer %@ : %@",
    "Server": "Serveur",
    "Custom…": "Personnalisé…",
    "Server URL": "URL du serveur",
    "Anisette Server": "Serveur Anisette",
    "Device IP": "IP de l'appareil",
    "Advanced": "Avancé",
    "Clear": "Effacer",
    "Activity Log (%d)": "Journal d'activité (%d)",

    // MARK: - Release channels & downloads

    "Stable": "Stable",
    "Nightly": "Nightly",
    "couldn't find the IPA in the %@ %@ release":
        "impossible de trouver l'IPA dans la version %@ de %@",
    "%@ has no %@ release right now": "%@ n'a aucune version %@ pour le moment",
    "bad asset URL": "URL de ressource incorrecte",

    // MARK: - Engine failures

    "Enter your Apple ID email + password.":
        "Saisissez l'e-mail et le mot de passe de votre Apple ID.",
    "Two-factor verification was cancelled.":
        "La validation en deux étapes a été annulée.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Identifiant Apple ou mot de passe incorrect. Vérifiez l'e-mail et le mot de passe de votre compte Apple, puis réessayez.",
    "Apple ID sign-in failed: %@": "Échec de la connexion à l'Apple ID : %@",
    "Apple ID sign-in failed on %@. Last error: %@":
        "Échec de la connexion à l'Apple ID sur %@. Dernière erreur : %@",
    "the anisette server": "le serveur anisette",
    "all %d anisette servers": "les %d serveurs anisette",
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
    "Wi-Fi is off. Connect to a Wi-Fi network, then try again.":
        "Le Wi-Fi est désactivé. Connectez-vous à un réseau Wi-Fi, puis réessayez.",
    "LocalDevVPN isn't connected. Turn it on, then try again.":
        "LocalDevVPN n'est pas connecté. Activez-le, puis réessayez.",
    "Apple allows only 3 signing certificates per Apple ID and this one already has 3, so a new one can't be made. Open the Certificates tab, tap “Load certificates”, and revoke an old or expired one to free a slot — then tap Install again. See the steps above.":
        "Apple n'autorise que 3 certificats de signature par Apple ID et celui-ci en a déjà 3 : impossible d'en créer un nouveau. Ouvrez l'onglet Certificats, touchez « Charger les certificats » et révoquez-en un ancien ou expiré pour libérer une place, puis touchez à nouveau Installer. Voir les étapes ci-dessus.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Impossible d'enregistrer cet iPhone%@ auprès de l'équipe de développement de votre Apple ID, Apple ne délivrera donc pas de profil de provisionnement. %@ — voir les étapes ci-dessus.",

    // MARK: - Guide cards

    "Connect to Wi-Fi": "Connectez-vous au Wi-Fi",
    "Open Settings › Wi-Fi and join a network.":
        "Ouvrez Réglages › Wi-Fi et rejoignez un réseau.",
    "LocalDevVPN's tunnel — and the whole install — run over Wi-Fi.":
        "Le tunnel de LocalDevVPN — et toute l'installation — passent par le Wi-Fi.",
    "Then come back here — this continues automatically.":
        "Revenez ensuite ici : la suite se fait toute seule.",

    "Turn on LocalDevVPN": "Activez LocalDevVPN",
    "Open the LocalDevVPN app (install it first if you haven't).":
        "Ouvrez l'app LocalDevVPN (installez-la d'abord si ce n'est pas déjà fait).",
    "Tap Connect so the toggle turns on.":
        "Touchez Connect pour que l'interrupteur s'active.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Laissez le Wi-Fi activé, puis revenez ici : la suite se fait toute seule.",
    "Get LocalDevVPN": "Obtenir LocalDevVPN",

    "Pair this iPhone in Settings": "Jumelez cet iPhone dans Réglages",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Ouvrez l'app Réglages, puis allez dans Confidentialité et sécurité › Mode développeur.",
    "Tap “Pair with SideInstaller”.": "Touchez « Jumeler avec SideInstaller ».",
    "Enter your iPhone’s passcode if it asks for it.":
        "Saisissez le code de votre iPhone s'il vous le demande.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Revenez dans SideInstaller, notez le code qu'il affiche, puis saisissez ce même code dans la demande affichée dans Réglages.",

    "Too many signing certificates": "Trop de certificats de signature",
    "Apple allows only 3 signing certificates per Apple ID, and this one already has 3 — usually left over from setting up AltStore / SideStore on other devices.":
        "Apple n'autorise que 3 certificats de signature par Apple ID et celui-ci en a déjà 3 — en général des restes de la configuration d'AltStore / SideStore sur d'autres appareils.",
    "Open the Certificates tab at the bottom of the screen, make sure your Apple ID is filled in, and tap “Load certificates”.":
        "Ouvrez l'onglet Certificats en bas de l'écran, vérifiez que votre Apple ID est bien renseigné, puis touchez « Charger les certificats ».",
    "Tap “Revoke” on an old or expired certificate to free up a slot. Revoking stops apps already signed with that certificate from launching on other devices, so pick one you no longer use.":
        "Touchez « Révoquer » sur un certificat ancien ou expiré pour libérer une place. La révocation empêche les apps déjà signées avec ce certificat de s'ouvrir sur les autres appareils : choisissez-en un que vous n'utilisez plus.",
    "Come back to the Install tab and tap Install again.":
        "Revenez à l'onglet Installer et touchez à nouveau Installer.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Vous pouvez aussi vous connecter ci-dessus avec un autre Apple ID (ou un compte de secours), puis toucher à nouveau Installer.",

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
]
