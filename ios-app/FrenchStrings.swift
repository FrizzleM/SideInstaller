import Foundation

/// French translations (same rules as `spanishStrings`). Uses formal "vous" and
/// iOS's French UI terms.

let frenchStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "Annuler",
    "Copy": "Copier",
    "Copy logs": "Copier les journaux",
    "Email": "E-mail",
    "Password": "Mot de passe",
    "Install": "Installer",
    "Installing": "Installation en cours",
    "Cancelling": "Annulation en cours",
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
    "SideInstaller %@ is available — you're on %@.":
        "SideInstaller %@ est disponible — vous utilisez la %@.",
    "Get the latest version": "Obtenir la dernière version",
    "From the website": "Depuis le site web",
    "Sign it with your Apple ID": "La signer avec votre Apple ID",
    "Install it in LiveContainer": "L'installer dans LiveContainer",
    "LiveContainer isn't installed on this iPhone.": "LiveContainer n'est pas installé sur cet iPhone.",
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

    // Export: the certificate SideInstaller signs with, as a .p12
    "This certificate has no serial number, so it can't be exported.":
        "Ce certificat n'a pas de numéro de série, il ne peut donc pas être exporté.",
    "Only the certificate SideInstaller signs with can be exported: the private key of any other stays on the device that asked Apple for it.":
        "Seul le certificat avec lequel SideInstaller signe peut être exporté : la clé privée de tout autre reste sur l'appareil qui l'a demandé à Apple.",
    "Couldn't export the certificate: %@": "Impossible d'exporter le certificat : %@",
    "Export certificate": "Exporter le certificat",
    "Export": "Exporter",
    "Exporting": "Exportation",
    "Saves this certificate and its private key as a .p12 file, for another signing app or a computer to sign with. Choose a password for it: you'll need it to import the file. Keep the file to yourself.":
        "Enregistre ce certificat et sa clé privée dans un fichier .p12, avec lequel une autre app de signature ou un ordinateur peut signer. Choisissez un mot de passe : il vous faudra pour importer le fichier. Ne le donnez à personne.",
    "SideInstaller can export only the certificate it signs with, and none of these is it: a certificate's private key stays on the device that asked Apple for it.":
        "SideInstaller ne peut exporter que le certificat avec lequel il signe, et aucun de ceux-ci ne l'est : la clé privée d'un certificat reste sur l'appareil qui l'a demandé à Apple.",
    "SideInstaller signs with this one": "SideInstaller signe avec celui-ci",

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
    "Couldn't build the download URL for %@.":
        "Impossible de construire l'URL de téléchargement pour %@.",

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
    "The route server couldn't plan this route (%@).":
        "Le serveur d'itinéraires n'a pas pu planifier cet itinéraire (%@).",

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
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Under Tools › Certificates, use SideStore's certificate or revoke that one, then refresh again.":
        "Apple ne délivre pas de certificat de signature pour cet Apple ID : elle indique qu'il en existe déjà un (erreur 7460). Dans Outils › Certificats, utilisez le certificat de SideStore ou révoquez celui-ci, puis renouvelez à nouveau.",
    "An install is already running. Wait for it to finish, then refresh.":
        "Une installation est déjà en cours. Attendez qu'elle se termine, puis renouvelez.",
    "Getting ready": "Préparation",
    "Stopping after this app": "Arrêt après cette app",
    "Refreshing %@": "Renouvellement de %@",
    "Signed by team %@, not the one you're signed in as — refreshing it here would install a second copy.":
        "Signée par l'équipe %@, pas celle avec laquelle vous êtes connecté : la renouveler ici installerait une deuxième copie.",
    "Refreshed. Its seven days start again now.":
        "Renouvelée. Ses sept jours repartent maintenant.",
    "Nothing was refreshed.": "Rien n'a été renouvelé.",
    "Refreshed %d of %d apps.": "%d app sur %d renouvelées.",
    "Refresh all apps?": "Renouveler toutes les apps ?",
    "Refresh all": "Tout renouveler",
    "%@ will be signed again with your Apple ID and installed over the copy on this device. It keeps its data, and its seven days start over.":
        "%@ sera signée à nouveau avec votre Apple ID et installée par-dessus la copie présente sur cet appareil. Elle conserve ses données et ses sept jours repartent de zéro.",
    "%d apps will be signed again with your Apple ID and installed over the copies on this device. They keep their data, and their seven days start over.":
        "%d apps seront signées à nouveau avec votre Apple ID et installées par-dessus les copies présentes sur cet appareil. Elles conservent leurs données et leurs sept jours repartent de zéro.",
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
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "« %@ » n'est pas une adresse IPv4. Elle doit ressembler à 192.168.1.42.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ est une adresse que cet iPhone possède déjà. Side by Side installe sur l'iPhone de quelqu'un d'autre : utilisez le sien. Pour installer sur celui-ci, utilisez l'onglet Installer.",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "L'iPhone qui s'est jumelé est celui-ci. Jumelez depuis les Réglages de leur iPhone. Pour installer sur cet iPhone, utilisez l'onglet Installer.",
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
    "Their iPhone needs iOS %@ — SideInstaller pairs itself once it's installed, and nothing older can.":
        "Leur iPhone doit être sous iOS %@ : une fois installé, SideInstaller se jumelle tout seul, ce que les versions antérieures ne peuvent pas faire.",
    "Their iPhone": "Leur iPhone",
    "IP address (optional)": "Adresse IP (facultative)",
    "Optional: leave it empty, and it fills in when their iPhone pairs.":
        "Facultative : laissez-la vide, elle se remplit quand leur iPhone se jumelle.",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "Sur leur iPhone : Réglages › Wi-Fi › ⓘ à côté du réseau, puis « Adresse IP ».",
    "This iPhone is %@, so theirs will look similar.":
        "Cet iPhone est %@, le leur y ressemblera.",
    "Apple ID to sign with": "Apple ID avec lequel signer",
    "Tip: Use the iPhone/iPad owner's Apple account credentials":
        "Astuce : utilisez les identifiants du compte Apple du propriétaire de l'iPhone/iPad",
    "Use my saved Apple ID instead": "Utiliser plutôt mon Apple ID enregistré",
    "Steps": "Étapes",
    "Waiting for them to tap Trust…": "En attente qu'ils touchent Faire confiance…",
    "Waiting for them to pair in Settings…":
        "En attente qu'ils jumellent l'iPhone dans Réglages…",
    "Waiting for them to enter the code…":
        "En attente qu'ils saisissent le code…",
    "Pair their iPhone in Settings":
        "Jumelez leur iPhone dans Réglages",
    "Their iPhone won't ask by itself — pairing starts from its Settings.":
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
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "Ils ont touché « Ne pas faire confiance » sur leur iPhone. Recommencez et demandez-leur de toucher Faire confiance.",
    "SideInstaller is already waiting for an iPhone to pair with it — from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "SideInstaller attend déjà qu'un iPhone se jumelle avec lui — depuis l'onglet Installer, la page Jumelage ou une tentative précédente ici. Terminez ce jumelage, ou fermez puis rouvrez SideInstaller, puis réessayez.",
    "Pairing with their iPhone didn't finish: %@":
        "Le jumelage avec leur iPhone n'a pas abouti : %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "Leur iPhone à l'adresse %@ a refusé la connexion. Il n'en accepte qu'avec le mode développeur activé, et iOS demande de le confirmer de nouveau après chaque redémarrage : sur leur iPhone, activez-le dans Réglages › Confidentialité et sécurité › Mode développeur, puis réessayez.",
    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Impossible de joindre leur iPhone à l'adresse %@. Vérifiez l'adresse (Réglages › Wi-Fi › ⓘ sur leur iPhone), que les deux iPhone sont sur le même réseau Wi-Fi et que Réseau local est activé pour SideInstaller dans les Réglages de cet iPhone. Les réseaux invités et publics empêchent souvent les appareils de communiquer entre eux.",
    "The link to their iPhone didn't come up: %@":
        "La liaison avec leur iPhone n'a pas pu s'établir : %@",
    "%d%% downloaded": "%d%% téléchargés",
    "%d%% uploaded": "%d%% envoyés",
    "Start the install": "Lancer l'installation",
    "Install again": "Installer à nouveau",
    "Clear their details": "Effacer leurs informations",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "Cet iPhone est toujours jumelé avec le leur. Effacer supprime ce jumelage.",
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
    // The Tunnel section: starting LocalDevVPN from here.
    "Tunnel": "Tunnel",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.":
        "Quelque chose sur %@:%d a refusé la connexion : le tunnel fonctionne donc, c'est l'appareil qui n'écoute pas sur son port de jumelage. Ce port ne s'ouvre qu'avec le mode développeur activé, et iOS le redemande après chaque redémarrage : activez-le dans Réglages › Confidentialité et sécurité › Mode développeur, puis réessayez. S'il est déjà activé, jumelez de nouveau cet iPhone depuis « Fichier de jumelage ».",
    "Start LocalDevVPN when needed": "Lancer LocalDevVPN au besoin",
    "Start LocalDevVPN now": "Lancer LocalDevVPN maintenant",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "LocalDevVPN n'est pas installé. Téléchargez-le sur l'App Store et SideInstaller pourra le lancer pour vous.",

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
    "Starts with %@": "Commence par %@",
    "Auto starts with the server that signed in last, then tries the others, the ones most likely to work first.":
        "Le mode Automatique commence par le serveur de la dernière connexion réussie, puis essaie les autres, en commençant par ceux qui ont le plus de chances de fonctionner.",
    "Only this server is tried. If it fails, so does sign-in: choose Auto to have SideInstaller try the others.":
        "Seul ce serveur est essayé. S'il échoue, la connexion échoue aussi : choisissez Automatique pour que SideInstaller essaie les autres.",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "Seul le serveur choisi dans Réglages › Serveur Anisette a été essayé. Choisissez Automatique à cet endroit pour que SideInstaller essaie les autres quand l'un échoue.",
    "Device IP": "IP de l'appareil",
    "Advanced": "Avancé",
    "Clear": "Effacer",
    "Activity Log (%d)": "Journal d'activité (%d)",

    // Settings › Developer Mode: AMFI requests over the device link.
    "Developer Mode": "Mode développeur",
    "Show Developer Mode in Settings": "Afficher le mode développeur dans Réglages",
    "Turn on Developer Mode": "Activer le mode développeur",
    "Asking this iPhone…": "Interrogation de cet iPhone…",
    "Both need a link to this iPhone that already works: LocalDevVPN plus a pairing file, such as one imported on iOS 17.4 to 26. On iOS 27 the link itself needs Developer Mode, so they can't bring back a missing option there.":
        "Les deux nécessitent une liaison avec cet iPhone qui fonctionne déjà : LocalDevVPN et un fichier de jumelage, par exemple importé sous iOS 17.4 à 26. Sous iOS 27, la liaison elle-même nécessite le mode développeur : ils ne peuvent donc pas faire réapparaître l'option si elle a disparu.",
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

    "couldn't find the IPA in the %@ %@ release":
        "impossible de trouver l'IPA dans la version %@ de %@",
    "%@ has no %@ release right now": "%@ n'a aucune version %@ pour le moment",
    "bad asset URL": "URL de ressource incorrecte",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub limite les requêtes de ce réseau — il n'est pas bloqué, et la limite se réinitialise d'elle-même. Réessayez %@.",
    "GitHub answered HTTP %d%@": "GitHub a répondu HTTP %d%@",
    "GitHub isn't serving %@ right now — the repository has been taken down, moved or made private, so there's nothing to download. Nothing is wrong with this iPhone or its network.":
        "GitHub ne propose pas %@ pour le moment — le dépôt a été retiré, déplacé ou rendu privé, il n'y a donc rien à télécharger. Cet iPhone et son réseau n'y sont pour rien.",
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
    "Apple ID sign-in failed on %@. Error: %@":
        "Échec de la connexion à l'Apple ID sur %@. Erreur : %@",
    "Apple ID sign-in failed on %@. Error via %@: %@":
        "Échec de la connexion à l'Apple ID sur %@. Erreur via %@ : %@",
    "Apple's sign-in server refused the request (HTTP 503). It isn't your password or the anisette server, so trying more servers won't help. Try again later, or update SideInstaller.":
        "Le serveur de connexion d'Apple a refusé la requête (HTTP 503). Ce n'est ni votre mot de passe ni le serveur anisette : essayer d'autres serveurs n'y changera rien. Réessayez plus tard ou mettez à jour SideInstaller.",
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
    "Every app SideInstaller signs needs an App ID, which its extensions share. A free Apple ID can register 10 a week, and each one counts for 7 days.":
        "Chaque app que SideInstaller signe a besoin d'un App ID, que ses extensions partagent. Un Apple ID gratuit peut en enregistrer 10 par semaine, et chacun compte pendant 7 jours.",
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
    "From iOS 26.4 on it has to be a remote pairing file: this iPhone hangs up on lockdown ones, like jitterbugpair's, when they come through LocalDevVPN.":
        "Depuis iOS 26.4, ce doit être un fichier « Remote pairing » : cet iPhone coupe la connexion avec les fichiers lockdown, comme celui de jitterbugpair, quand ils passent par LocalDevVPN.",
    "Get idevice_pair": "Télécharger idevice_pair",
    "Make a remote pairing file": "Créer un fichier « Remote pairing »",
    "The pairing file you imported is a lockdown one. Since iOS 26.4, this iPhone hangs up on those when they come through LocalDevVPN, so it can't connect, and a new one of the same kind won't either.":
        "Le fichier de jumelage que vous avez importé est de type lockdown. Depuis iOS 26.4, cet iPhone coupe la connexion avec ces fichiers quand ils passent par LocalDevVPN : il ne peut donc pas se connecter, et un nouveau fichier du même type non plus.",
    "Come back here, tap “Replace” on the Pairing file card, and pick it.":
        "Revenez ici, touchez « Remplacer » sur la carte « Fichier de jumelage » et choisissez-le.",
    "On a Mac, Windows PC or Linux box, open idevice_pair, plug this iPhone in, and tap Trust if it asks. Pick it, choose “Remote pairing”, click “Create”, and keep this iPhone unlocked until it's done.":
        "Sur un Mac, un PC Windows ou Linux, ouvrez idevice_pair, branchez cet iPhone et faites confiance à l'ordinateur s'il le demande. Sélectionnez-le, choisissez « Remote pairing », cliquez sur « Create » et gardez cet iPhone déverrouillé jusqu'à la fin.",
    "Click “Save to file…” and send the file to this iPhone, by AirDrop, iCloud Drive or a cable. A pairing file exported from iLoader works too.":
        "Cliquez sur « Save to file… » et envoyez le fichier vers cet iPhone, par AirDrop, iCloud Drive ou un câble. Un fichier de jumelage exporté depuis iLoader fonctionne aussi.",

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
    "Device IP is %@, one of this iPhone's own addresses, and iOS won't let an app connect to those. In Settings › Advanced, set Device IP to the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default, not the “Connected to” address on its main screen.":
        "L’IP de l’appareil est %@, l’une des adresses de cet iPhone, et iOS ne laisse aucune app s’y connecter. Dans Réglages › Avancé, indiquez comme IP de l’appareil l’adresse sous Réglages › Device IP dans LocalDevVPN (10.7.0.1 par défaut), et non celle qui suit « Connecté à » sur son écran principal.",
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "iOS a refusé la connexion à %@ sur cet iPhone, avant que quoi que ce soit ne soit envoyé. Il le fait pour les adresses de cet iPhone lui-même, comme celle qui suit « Connecté à » sur l’écran principal de LocalDevVPN. L’IP de l’appareil, dans Réglages › Avancé, doit être l’adresse sous Réglages › Device IP dans LocalDevVPN (10.7.0.1 par défaut). Si c’est déjà le cas, désactivez puis réactivez LocalDevVPN, puis réessayez.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "Cet iPhone a coupé la connexion dès son ouverture. Depuis iOS 26.4, il le fait avec les fichiers de jumelage lockdown, comme celui-ci, quand ils passent par LocalDevVPN. Jumelez plutôt cet iPhone avec lui-même : touchez « Régénérer » dans Outils › Jumelage, ou touchez Installer, qui le jumelle d'abord.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "Cet iPhone a coupé la connexion dès son ouverture. Depuis iOS 26.4, il le fait avec les fichiers de jumelage lockdown, comme celui-ci, quand ils passent par LocalDevVPN : en refaire un du même type n'y changera rien. Un fichier de jumelage « Remote pairing » fonctionne toujours : sur un ordinateur, ouvrez idevice_pair, choisissez « Remote pairing », cliquez sur « Create » puis sur « Save to file… », et importez le fichier dans « Fichier de jumelage ».",
    "This iPhone hung up on the connection: from iOS 26.4 on, it does that to lockdown pairing files like this one when they come through LocalDevVPN. See the steps above.":
        "Cet iPhone a coupé la connexion : depuis iOS 26.4, il le fait avec les fichiers de jumelage lockdown comme celui-ci quand ils passent par LocalDevVPN. Voir les étapes ci-dessus.",
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

    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.":
        "%@ nécessite iOS %d ou une version ultérieure. Cet iPhone utilise iOS %@.",
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
    "Share the report": "Partager le rapport",
    "Preview the report": "Aperçu du rapport",
    "Report": "Rapport",
    "The report is saved in Files › On My iPhone › SideInstaller › Reports. On GitHub, attach it with “Paste, drop, or click to add files” below the text, then submit the issue.":
        "Le rapport est enregistré dans Fichiers › Sur mon iPhone › SideInstaller › Reports. Sur GitHub, joins-le avec « Paste, drop, or click to add files » sous le texte, puis envoie le ticket.",
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
]
