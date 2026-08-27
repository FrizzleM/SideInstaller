import Foundation

/// French copy, on the same contract as `spanishStrings`. Uses the formal
/// "vous" and iOS's own French vocabulary for anything on screen.

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

    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "Il vous faudra un fichier de jumelage",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "Cet iPhone est sous iOS %@. Seul iOS %@ peut se jumeler tout seul : vous devrez créer un fichier de jumelage sur un ordinateur — avec jitterbugpair ou pymobiledevice3 — puis l'importer dans l'app. SideInstaller vous guide pas à pas.",

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
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "Enregistré dans le trousseau de cet iPhone, et envoyé uniquement à Apple lors de la connexion. Balayez une ligne pour modifier son mot de passe ou la supprimer.",
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
    "Custom .ipa": "IPA personnalisé",
    "Import .ipa": "Importer un .ipa",
    "Importing…": "Importation…",
    "Replace": "Remplacer",
    "or": "ou",
    "Paste a download link": "Collez un lien de téléchargement",
    "Downloading… %d%%": "Téléchargement… %d%%",
    "iOS %@ required": "iOS %@ requis",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Cet iPhone est sous iOS %@, sur lequel SideInstaller ne peut rien installer. Mettez à jour vers iOS %@ ou une version ultérieure dans Réglages › Général › Mise à jour logicielle.",
    "Wi-Fi required": "Wi-Fi requis",
    "Pairing code": "Code de jumelage",
    "Type this into the prompt in Settings.":
        "Saisissez ce code dans la demande affichée dans Réglages.",
    "Install stopped": "Installation interrompue",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ est installé. Terminez l'étape de confiance ci-dessus pour l'ouvrir.",
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
    "%d supported app installed": "%d app compatible installée",
    "%d supported apps installed": "%d apps compatibles installées",
    "No supported apps found": "Aucune app compatible trouvée",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Installez d'abord une app comme SideStore, StikDebug ou Feather, puis relancez la recherche.",
    "Install pairing": "Installer le jumelage",
    "Pairing file ready. You can export it or install it into an app below.":
        "Fichier de jumelage prêt. Vous pouvez l'exporter ou l'installer dans une app ci-dessous.",
    "Pairing file installed into %@.": "Fichier de jumelage installé dans %@.",

    // Importing a pairing file (iOS 26 and below)

    "Import pairing file": "Importer le fichier de jumelage",
    "How do I make one?": "Comment en créer un ?",
    "imported pairing file": "fichier de jumelage importé",
    "No pairing file yet — tap “Import pairing file” first.":
        "Aucun fichier de jumelage — touchez d'abord « Importer le fichier de jumelage ».",
    "Pairing file missing — import it first.": "Fichier de jumelage manquant : importez-le d'abord.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ n'est pas un fichier de jumelage. Choisissez le fichier créé par votre ordinateur — un .mobiledevicepairing ou .plist contenant l'enregistrement de jumelage de cet iPhone.",
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
    "Couldn't build the download URL for %@.":
        "Impossible de construire l'URL de téléchargement pour %@.",

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
    "%d app": "%d app",
    "%d apps": "%d apps",
    "%d app needs refreshing": "%d app à renouveler",
    "%d apps need refreshing": "%d apps à renouveler",
    "No sideloaded apps": "Aucune app sideloadée",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Rien sur cet appareil n'a été installé avec un profil de provisionnement. Les apps de l'App Store n'expirent pas, elles ne figurent donc pas ici.",
    "No matching profile": "Aucun profil correspondant",
    "Expires today": "Expire aujourd'hui",
    "Expires tomorrow": "Expire demain",
    "Expires in %d days — %@": "Expire dans %d jours — %@",
    "Expired %@": "Expiré le %@",
    "Unused profiles": "Profils inutilisés",
    "Issued to App IDs no installed app is running on.":
        "Émis pour des App ID sur lesquels aucune app installée ne tourne.",
    "Older profiles": "Profils plus anciens",
    "Bundle identifier": "Identifiant du bundle",
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
    "Sign in to their Apple ID": "Se connecter à leur Apple ID",
    "Download SideInstaller": "Télécharger SideInstaller",
    "Install on their iPhone": "Installer sur leur iPhone",
    "Enter the other iPhone's IP address. It's in Settings › Wi-Fi, next to the network it's on.":
        "Saisissez l'adresse IP de l'autre iPhone. Elle se trouve dans Réglages › Wi-Fi, à côté du réseau auquel il est connecté.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "« %@ » n'est pas une adresse IPv4. Elle doit ressembler à 192.168.1.42.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ est une adresse que cet iPhone possède déjà. Side by Side installe sur l'iPhone de quelqu'un d'autre : utilisez le sien. Pour installer sur celui-ci, utilisez l'onglet Installer.",
    "Enter the Apple ID to sign with, and its password.":
        "Saisissez l'Apple ID avec lequel signer, et son mot de passe.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Le Wi-Fi est désactivé. Les deux iPhone doivent être sur le même réseau Wi-Fi pour que cela fonctionne.",
    "The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute.":
        "Le téléchargement de la version n'était pas un IPA. GitHub renvoie peut-être une page d'erreur — réessayez dans une minute.",
    "Couldn't download the latest SideInstaller release: %@":
        "Impossible de télécharger la dernière version de SideInstaller : %@",
    "No SideInstaller IPA downloaded.": "Aucun IPA SideInstaller téléchargé.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise.":
        "Apple refuse de délivrer un certificat de signature pour cet Apple ID : elle indique qu'il en existe déjà un (erreur 7460). Il faut d'abord en révoquer un — avec l'outil Certificats s'il s'agit de l'Apple ID enregistré dans Réglages › Compte, sinon sur developer.apple.com en vous y connectant avec.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple n'a pas enregistré leur iPhone auprès de l'équipe de développement de cet Apple ID, elle ne délivrera donc pas de profil de provisionnement. %@",
    "No pair record for their iPhone.":
        "Aucun enregistrement de jumelage pour leur iPhone.",
    "The link to their iPhone dropped — start again.":
        "La liaison avec leur iPhone a été perdue — recommencez.",
    "Set up someone else's iPhone": "Configurer l'iPhone de quelqu'un d'autre",
    "Same Wi-Fi network": "Même réseau Wi-Fi",
    "How it works": "Comment ça marche",
    "This installs SideInstaller onto another iPhone on the same Wi-Fi network — no computer and no cable. Their iPhone will ask them to trust this one; they have to be holding it, unlocked, when you tap Install.":
        "Installe SideInstaller sur un autre iPhone du même réseau Wi-Fi — sans ordinateur ni câble. Leur iPhone leur demandera de faire confiance à celui-ci ; ils doivent l'avoir en main, déverrouillé, au moment où vous touchez Installer.",
    "Their iPhone": "Leur iPhone",
    "IP address (e.g. 192.168.1.42)": "Adresse IP (par ex. 192.168.1.42)",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "Sur leur iPhone : Réglages › Wi-Fi › ⓘ à côté du réseau, puis « Adresse IP ».",
    "This iPhone is %@, so theirs will look similar.":
        "Cet iPhone est %@, le leur y ressemblera.",
    "Apple ID to sign with": "Apple ID avec lequel signer",
    "Usually theirs, so the app is signed to their account and their free developer slots. Held only until this page is closed — never saved to this iPhone, and the password is never sent anywhere but Apple.":
        "Le leur, en général : l'app est alors signée avec leur compte et leurs emplacements de développeur gratuits. Conservé uniquement tant que cette page est ouverte — jamais enregistré sur cet iPhone, et le mot de passe n'est envoyé qu'à Apple.",
    "Use my saved Apple ID instead": "Utiliser plutôt mon Apple ID enregistré",
    "Steps": "Étapes",
    "Waiting for them to tap Trust…": "En attente qu'ils touchent Faire confiance…",
    "%d%% downloaded": "%d%% téléchargés",
    "%d%% uploaded": "%d%% envoyés",
    "Start the install": "Lancer l'installation",
    "Install again": "Installer à nouveau",
    "Clear their details": "Effacer leurs informations",
    "Last step: they trust %@": "Dernière étape : ils font confiance à %@",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "Sur leur iPhone : Réglages › Général › VPN et gestion des appareils.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "Touchez l'Apple ID sous « App de développeur », puis touchez Faire confiance.",
    "Open it from their Home Screen — they're set up.":
        "Ouvrez-la depuis leur écran d'accueil — c'est terminé.",

    // MARK: - Settings

    "Settings": "Réglages",
    "Done": "Terminé",
    "Language": "Langue",
    "App language": "Langue de l'app",
    "Auto": "Automatique",
    "Downloaded IPAs": "IPA téléchargés",
    "%@ used": "%@ utilisés",
    "imported": "importé",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "Aucun IPA téléchargé. Ceux que vous installez depuis l'onglet Installer sont conservés ici.",
    "Downloaded %@": "Téléchargé le %@",
    "Added %@": "Ajouté %@",
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
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub limite les requêtes de ce réseau — il n'est pas bloqué, et la limite se réinitialise d'elle-même. Réessayez %@.",
    "GitHub answered HTTP %d%@": "GitHub a répondu HTTP %d%@",
    "couldn't reach GitHub: %@": "impossible de joindre GitHub : %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "la réponse de GitHub n'était pas les informations de version (%@) — quelque chose sur ce réseau les a peut-être remplacées.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "ce qui a été téléchargé sous le nom %@ n'est pas un IPA — quelque chose sur ce réseau a renvoyé une page, ou le transfert s'est interrompu.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "ce lien a répondu HTTP %d — ce n'est pas un téléchargement direct, ou il exige une connexion.",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.":
        "La validation en deux étapes a été annulée.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Identifiant Apple ou mot de passe incorrect. Vérifiez l'e-mail et le mot de passe de votre compte Apple, puis réessayez.",
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
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ n'est pas un IPA valide : le téléchargement a sans doute renvoyé une page d'erreur, ou la copie s'est arrêtée en cours de route. Remplacez-le et touchez Installer à nouveau.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ n'est pas un IPA. Choisissez le fichier .ipa lui-même ; s'il semble correct, le téléchargement a peut-être enregistré une page d'erreur, ou s'est arrêté en route.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Aucun IPA importé pour l'instant. Touchez « Importer un .ipa » et choisissez-en un.",
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
    "Pair this iPhone in Settings": "Jumelez cet iPhone dans Réglages",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Ouvrez l'app Réglages, puis allez dans Confidentialité et sécurité › Mode développeur.",
    "Tap “Pair with SideInstaller”.": "Touchez « Jumeler avec SideInstaller ».",
    "Enter your iPhone’s passcode if it asks for it.":
        "Saisissez le code de votre iPhone s'il vous le demande.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Revenez dans SideInstaller, notez le code qu'il affiche, puis saisissez ce même code dans la demande affichée dans Réglages.",
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
    "If you changed LocalDevVPN's addresses, put its Device IP here, and make sure its Tunnel IP and subnet mask cover it.":
        "Si vous avez modifié les adresses de LocalDevVPN, indiquez ici son Device IP et vérifiez que son Tunnel IP et son masque de sous-réseau le couvrent.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "L’appairage de cet iPhone en a besoin : SideInstaller s’annonce sur le réseau local pour que Réglages le trouve.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Connectez-vous à un réseau Wi-Fi. L’appairage de cet iPhone en a besoin : SideInstaller doit être détectable sur le réseau local.",

    // MARK: - About

    "About": "À propos",
    "Version %@ (%@)": "Version %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller installe SideStore et LiveContainer directement sur votre iPhone, sans PC.",

    "Links": "Liens",
    "Source code": "Code source",
    "Support the project": "Soutenir le projet",

    "Special thanks": "Remerciements",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "Pour idevice, la bibliothèque avec laquelle SideInstaller communique avec votre iPhone. Rien de tout cela n’existerait sans elle.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Pour le soutien et pour avoir repéré les bugs qui ont ensuite été corrigés.",
    "For the Japanese translation.": "Pour la traduction japonaise.",

    "Built with": "Construit avec",
    "The open source work this app is built on:":
        "Le travail open source sur lequel cette app repose :",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "L’appairage, le tunnel et l’installation elle-même. Par jkcoxson, MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "La connexion à l’Apple ID, les certificats et la signature sur l’appareil. Par nab138, MIT.",
    "The sideloading app this installs for you.":
        "L’app de sideloading que celle-ci installe pour vous.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Exécute les apps sideloadées sans consommer un emplacement pour chacune.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "L’image disque développeur que monte la simulation de position. Miroir de doronz88.",

    "Where to get it": "Où le télécharger",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "Seules les versions publiées sur la page d’installation et le dépôt officiels sont les miennes. N’importe qui peut forker le code, y ajouter un voleur d’identifiants et le diffuser sous le même nom et la même icône : ne confiez pas votre Apple ID à une copie trouvée ailleurs.",
    "Install page": "Page d’installation",
    "Terms": "Conditions",
]
