import Foundation

/// Spanish copy, keyed by the English source string passed to `L(_:)`. A missing
/// key renders as that English. `%@` and `%d` placeholders must survive
/// translation, and product or third-party UI names stay in English.

let spanishStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "Cancelar",
    "Copy": "Copiar",
    "Email": "Correo electrónico",
    "Password": "Contraseña",
    "Install": "Instalar",
    "Installing": "Instalando",
    "Installed": "Instalado",
    "Something went wrong": "Algo ha ido mal",
    "an app by Frizzle": "una app de Frizzle",
    "device": "dispositivo",

    // MARK: - Welcome

    "I have accepted the": "Acepto los",
    "Start": "Comenzar",

    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "Necesitarás un archivo de emparejamiento",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "Este iPhone usa iOS %@. Solo iOS %@ puede emparejarse consigo mismo, así que tendrás que crear un archivo de emparejamiento en un ordenador — con jitterbugpair o pymobiledevice3 — e importarlo en la app. SideInstaller te guía paso a paso.",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "Inicia sesión con tu Apple ID",
    "Don't worry, these are stored locally":
        "Tranquilo, se guardan solo en este iPhone",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "Se guarda en el llavero de este iPhone y solo se envía a Apple al iniciar sesión.",
    "Continue": "Continuar",
    "Set this up later": "Configurarlo más tarde",
    "Add Apple ID": "Añadir Apple ID",
    "Edit Apple ID": "Editar Apple ID",
    "Save": "Guardar",
    "Enter the password again to save this Apple ID.":
        "Introduce de nuevo la contraseña para guardar este Apple ID.",
    "Account": "Cuenta",
    "In use": "En uso",
    "Edit": "Editar",
    "Remove": "Eliminar",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "Aún no hay ningún Apple ID guardado. Añade uno y SideInstaller lo usará en cada inicio de sesión.",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "Se guarda en el llavero de este iPhone y solo se envía a Apple al iniciar sesión. Desliza una fila para editar su contraseña o eliminarla.",
    "Remove this Apple ID?": "¿Eliminar este Apple ID?",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "“%@” y su contraseña guardada se borrarán de este iPhone. Tu cuenta de Apple no cambia.",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "El llavero de este iPhone no ha aceptado guardar la contraseña (error %d), así que solo se conserva mientras SideInstaller esté abierto.",
    "No Apple ID saved. Add one in Settings › Account.":
        "No hay ningún Apple ID guardado. Añade uno en Ajustes › Cuenta.",

    "Add your Apple ID": "Añade tu Apple ID",
    "Open Settings with the gear at the top right.":
        "Abre los Ajustes con el engranaje de la esquina superior derecha.",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "En la sección Cuenta, toca “Añadir Apple ID” e introduce tu correo y tu contraseña.",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "Herramientas",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "Emparejamiento",
    "Certificates": "Certificados",
    "Two-Factor Code": "Código de verificación",
    "6-digit code": "Código de 6 dígitos",
    "Submit": "Enviar",
    "Enter the code Apple just sent to your trusted device.":
        "Introduce el código que Apple acaba de enviar a tu dispositivo de confianza.",

    // MARK: - Install tab

    "Tunnel connected": "Túnel conectado",
    "Tunnel off": "Túnel desactivado",
    "Update available": "Actualización disponible",
    "SideInstaller %@ is available — you're on %@.":
        "SideInstaller %@ ya está disponible — tienes instalada la %@.",
    "Get the latest version": "Obtener la última versión",
    "Release": "Canal",
    "Reinstall": "Reinstalar",
    "Install %@": "Instalar %@",
    "Custom .ipa": "IPA personalizado",
    "Import .ipa": "Importar .ipa",
    "Importing…": "Importando…",
    "Replace": "Sustituir",
    "or": "o",
    "Paste a download link": "Pega un enlace de descarga",
    "Downloading… %d%%": "Descargando… %d%%",
    "iOS %@ required": "Se requiere iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Este iPhone tiene iOS %@, y con esa versión SideInstaller no puede instalar nada. Actualiza a iOS %@ o posterior en Ajustes › General › Actualización de software.",
    "Wi-Fi required": "Se requiere Wi-Fi",
    "Pairing code": "Código de emparejamiento",
    "Type this into the prompt in Settings.":
        "Escribe este código en el mensaje que aparece en Ajustes.",
    "Install stopped": "Instalación detenida",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ ya está instalado. Completa el paso de confianza de arriba para abrirlo.",
    "Action needed": "Necesita tu atención",
    "Step %@ of %@": "Paso %@ de %@",
    "Show all steps": "Mostrar todos los pasos",
    "Show fewer steps": "Mostrar menos pasos",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "Se requiere LocalDevVPN",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "Instala LocalDevVPN y conéctala. La instalación pasa por su túnel.",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Conecta LocalDevVPN para buscar e instalar. La escritura se hace por su túnel.",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "Conecta LocalDevVPN. La simulación pasa por su túnel, como todo lo demás aquí.",
    "LocalDevVPN isn't connected. Connect it, then try again.":
        "LocalDevVPN no está conectada. Conéctala e inténtalo de nuevo.",
    "Connect LocalDevVPN": "Conecta LocalDevVPN",
    "Install LocalDevVPN from the App Store and open it.":
        "Instala LocalDevVPN desde la App Store y ábrela.",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Si GitHub está bloqueado donde estás, usa una VPN que también pueda enrutar tu tráfico: iOS ejecuta una VPN a la vez, así que un túnel solo local no deja por dónde descargar SideStore.",

    // MARK: - Install steps

    "Connect the VPN": "Conectar la VPN",
    "Get pairing file": "Obtener el archivo de emparejamiento",
    "Open the device link": "Abrir el enlace con el dispositivo",
    "Sign in to Apple ID": "Iniciar sesión en el Apple ID",
    "Download %@": "Descargar %@",
    "Use your imported IPA": "Usar tu IPA importado",
    "Sign the app": "Firmar la app",
    "Finish setup": "Finalizar la configuración",

    // MARK: - Pairing tab

    "Pairing file ready": "Archivo de emparejamiento listo",
    "No pairing file": "Sin archivo de emparejamiento",
    "Pairing file": "Archivo de emparejamiento",
    "Pairing…": "Emparejando…",
    "Regenerate": "Regenerar",
    "Generate pairing file": "Generar archivo de emparejamiento",
    "Export pairing file": "Exportar archivo de emparejamiento",
    "Pair in Settings": "Empareja en Ajustes",
    "Install into an app": "Instalar en una app",
    "Scanning": "Buscando",
    "Rescan apps": "Buscar apps otra vez",
    "Scan installed apps": "Buscar apps instaladas",
    "%d supported app installed": "%d app compatible instalada",
    "%d supported apps installed": "%d apps compatibles instaladas",
    "No supported apps found": "No se han encontrado apps compatibles",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Instala antes una app como SideStore, StikDebug o Feather y vuelve a buscar.",
    "Install pairing": "Instalar emparejamiento",
    "Pairing file ready. You can export it or install it into an app below.":
        "Archivo de emparejamiento listo. Puedes exportarlo o instalarlo en una app aquí abajo.",
    "Pairing file installed into %@.": "Archivo de emparejamiento instalado en %@.",

    // Importing a pairing file (iOS 26 and below)

    "Import pairing file": "Importar archivo de emparejamiento",
    "How do I make one?": "¿Cómo lo creo?",
    "imported pairing file": "archivo de emparejamiento importado",
    "No pairing file yet — tap “Import pairing file” first.":
        "Aún no hay archivo de emparejamiento: toca primero “Importar archivo de emparejamiento”.",
    "Pairing file missing — import it first.": "Falta el archivo de emparejamiento: impórtalo primero.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ no es un archivo de emparejamiento. Elige el archivo que creó tu ordenador — un .mobiledevicepairing o .plist con el registro de emparejamiento de este iPhone.",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "iOS %@ no puede crear su propio archivo de emparejamiento: eso necesita iOS %@. Importa uno creado en un ordenador en “Archivo de emparejamiento” y vuelve a intentarlo.",

    // MARK: - Pairing service status

    "not paired": "sin emparejar",
    "connected": "conectado",
    "requesting Local Network…": "solicitando acceso a la red local…",
    "Local Network denied": "acceso a la red local denegado",
    "waiting for device…": "esperando al dispositivo…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "visible en la red — abre Ajustes › Privacidad y seguridad › Modo desarrollador",
    "enter PIN %@ in Settings": "introduce el PIN %@ en Ajustes",
    "paired: %@ (%dB)": "emparejado: %@ (%d B)",
    "failed: empty pairing file": "error: archivo de emparejamiento vacío",
    "failed: %@": "error: %@",
    "Pairing is already in progress.": "Ya hay un emparejamiento en curso.",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "El permiso de red local está desactivado. Actívalo en Ajustes › SideInstaller › Red local e inténtalo de nuevo.",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "El emparejamiento ha generado un archivo vacío. Asegúrate de aceptar la solicitud de emparejamiento e inténtalo de nuevo.",

    // MARK: - Certificates tab

    "Revoke this certificate?": "¿Revocar este certificado?",
    "Revoke": "Revocar",
    "Revoking": "Revocando",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "Se revocará “%@”. Las apps ya firmadas con él dejarán de abrirse en todos los dispositivos. Esto no se puede deshacer.",
    "Refreshing": "Actualizando",
    "Signing in": "Iniciando sesión",
    "Refresh": "Actualizar",
    "Load certificates": "Cargar certificados",
    "%d certificate(s)": "%d certificado(s)",
    "No certificates": "Sin certificados",
    "This Apple ID has no development certificates to revoke.":
        "Este Apple ID no tiene certificados de desarrollo que revocar.",
    "Expired": "Caducado",
    "Expires %@": "Caduca el %@",
    "Unnamed certificate": "Certificado sin nombre",
    "This certificate has no serial number, so it can't be revoked.":
        "Este certificado no tiene número de serie, así que no se puede revocar.",

    // MARK: - Location tab

    "Location spoofing": "Simulación de ubicación",
    "Not simulating": "Sin simular",
    "Simulated": "Simulada",
    "Pick a place": "Elige un lugar",
    "Search for a place": "Busca un lugar",
    "Nothing found for “%@”.": "No se ha encontrado nada para “%@”.",
    "Set location": "Fijar ubicación",
    "Setting": "Fijando",
    "Reset to real location": "Volver a la ubicación real",
    "Location set to %@.": "Ubicación fijada en %@.",
    "Location reset. The device is using its own again.":
        "Ubicación restablecida. El dispositivo vuelve a usar la suya.",
    "That isn't a valid coordinate.": "Esa coordenada no es válida.",
    "Location session closed — set it up again.":
        "La sesión de ubicación se ha cerrado: vuelve a prepararla.",
    "Downloading %@ failed (HTTP %d).": "La descarga de %@ ha fallado (HTTP %d).",
    "Couldn't build the download URL for %@.":
        "No se ha podido construir la URL de descarga de %@.",

    // MARK: - Entitlements tab

    "Entitlements": "Permisos",
    "Load apps": "Cargar apps",
    "%d App ID": "%d App ID",
    "%d App IDs": "%d App ID",
    "No App IDs": "Sin App IDs",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "Este Apple ID todavía no ha registrado ninguna app. Instala algo con SideInstaller y vuelve aquí.",
    "Memory and performance": "Memoria y rendimiento",
    "Other free capabilities": "Otras capacidades gratuitas",
    "Recommended": "Recomendados",
    "Select all": "Seleccionar todo",
    "None": "Ninguno",
    "Enable %d selected": "Activar %d seleccionados",
    "Asking Apple": "Consultando a Apple",
    "%d of %d enabled": "%d de %d activados",
    "Install the app again for these to take effect.":
        "Vuelve a instalar la app para que surtan efecto.",

    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "Apps sideloadeadas",
    "Reading the device": "Leyendo el dispositivo",
    "%d app": "%d app",
    "%d apps": "%d apps",
    "%d app needs refreshing": "%d app por renovar",
    "%d apps need refreshing": "%d apps por renovar",
    "No sideloaded apps": "Ninguna app sideloadeada",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Nada de este dispositivo se instaló con un perfil de aprovisionamiento. Las apps de la App Store no caducan, así que no aparecen aquí.",
    "No matching profile": "Ningún perfil coincidente",
    "Expires today": "Caduca hoy",
    "Expires tomorrow": "Caduca mañana",
    "Expires in %d days — %@": "Caduca en %d días — %@",
    "Expired %@": "Caducó el %@",
    "Unused profiles": "Perfiles sin usar",
    "Issued to App IDs no installed app is running on.":
        "Emitidos para App ID en los que no se ejecuta ninguna app instalada.",
    "Older profiles": "Perfiles más antiguos",
    "Bundle identifier": "Identificador del paquete",
    "App ID": "App ID",
    "Version": "Versión",
    "Profile name": "Nombre del perfil",
    "Team": "Equipo",
    "Team ID": "ID del equipo",
    "Issued": "Emitido",
    "Profile UUID": "UUID del perfil",
    "Capabilities": "Capacidades",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "App ID con comodín: cubre cualquier bundle id por debajo y no puede llevar capacidades específicas de una app.",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "El dispositivo no tiene ningún perfil de aprovisionamiento para este App ID. Puede que la app ya no arranque: instálala de nuevo para arreglarlo.",

    // MARK: - Side by Side tool

    // The tool's name is left in English everywhere, as SideStore's is.
    "Side by Side": "Side by Side",
    "Pair with their iPhone": "Emparejar con su iPhone",
    "Sign in to their Apple ID": "Iniciar sesión en su Apple ID",
    "Download SideInstaller": "Descargar SideInstaller",
    "Install on their iPhone": "Instalar en su iPhone",
    "Enter the other iPhone's IP address. It's in Settings › Wi-Fi, next to the network it's on.":
        "Introduce la dirección IP del otro iPhone. Está en Ajustes › Wi-Fi, junto a la red a la que está conectado.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” no es una dirección IPv4. Debe tener este aspecto: 192.168.1.42.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ es una dirección que este iPhone ya tiene. Side by Side instala en el iPhone de otra persona: usa el suyo. Para instalar en este, usa la pestaña Instalar.",
    "Enter the Apple ID to sign with, and its password.":
        "Introduce el Apple ID con el que firmar y su contraseña.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "El Wi-Fi está apagado. Ambos iPhone tienen que estar en la misma red Wi-Fi para que esto funcione.",
    "The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute.":
        "La descarga de la versión no era un IPA. Puede que GitHub esté devolviendo una página de error: inténtalo de nuevo en un minuto.",
    "Couldn't download the latest SideInstaller release: %@":
        "No se pudo descargar la última versión de SideInstaller: %@",
    "No SideInstaller IPA downloaded.": "No se ha descargado ningún IPA de SideInstaller.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise.":
        "Apple no emite un certificado de firma para este Apple ID: informa de que ya existe uno (error 7460). Primero hay que revocar uno: con la herramienta Certificados si este es el Apple ID guardado en Ajustes › Cuenta, y si no, en developer.apple.com con la sesión iniciada en él.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple no ha registrado su iPhone en el equipo de desarrollo de este Apple ID, así que no emitirá un perfil de aprovisionamiento. %@",
    "No pair record for their iPhone.":
        "No hay registro de emparejamiento para su iPhone.",
    "The link to their iPhone dropped — start again.":
        "Se ha perdido el enlace con su iPhone: empieza de nuevo.",
    "Set up someone else's iPhone": "Configura el iPhone de otra persona",
    "Same Wi-Fi network": "Misma red Wi-Fi",
    "How it works": "Cómo funciona",
    "This installs SideInstaller onto another iPhone on the same Wi-Fi network — no computer and no cable. Their iPhone will ask them to trust this one; they have to be holding it, unlocked, when you tap Install.":
        "Instala SideInstaller en otro iPhone de la misma red Wi-Fi: sin ordenador y sin cable. Su iPhone les pedirá que confíen en este; tienen que tenerlo en la mano, desbloqueado, cuando toques Instalar.",
    "Their iPhone": "Su iPhone",
    "IP address (e.g. 192.168.1.42)": "Dirección IP (p. ej. 192.168.1.42)",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "En su iPhone: Ajustes › Wi-Fi › ⓘ junto a la red y luego “Dirección IP”.",
    "This iPhone is %@, so theirs will look similar.":
        "Este iPhone es %@, así que el suyo se parecerá.",
    "Apple ID to sign with": "Apple ID con el que firmar",
    "Usually theirs, so the app is signed to their account and their free developer slots. Held only until this page is closed — never saved to this iPhone, and the password is never sent anywhere but Apple.":
        "Normalmente el suyo, así la app se firma con su cuenta y sus slots de desarrollador gratuitos. Se guarda solo mientras esta página esté abierta: nunca se almacena en este iPhone, y la contraseña no se envía a nadie salvo a Apple.",
    "Use my saved Apple ID instead": "Usar mi Apple ID guardado",
    "Steps": "Pasos",
    "Waiting for them to tap Trust…": "Esperando a que toquen Confiar…",
    "%d%% downloaded": "%d%% descargado",
    "%d%% uploaded": "%d%% subido",
    "Start the install": "Iniciar la instalación",
    "Install again": "Instalar otra vez",
    "Clear their details": "Borrar sus datos",
    "Last step: they trust %@": "Último paso: confían en %@",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "En su iPhone: Ajustes › General › VPN y gestión de dispositivos.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "Toca el Apple ID en “App de desarrollador” y luego toca Confiar.",
    "Open it from their Home Screen — they're set up.":
        "Ábrela desde su pantalla de inicio: ya está listo.",

    // MARK: - Settings

    "Settings": "Ajustes",
    "Done": "Listo",
    "Language": "Idioma",
    "App language": "Idioma de la app",
    "Auto": "Automático",
    "Downloaded IPAs": "IPA descargados",
    "%@ used": "%@ ocupados",
    "imported": "importado",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "No hay IPA descargados. Los que instales desde la pestaña Instalar se guardan aquí.",
    "Downloaded %@": "Descargado el %@",
    "Added %@": "Añadido %@",
    "Delete this download?": "¿Eliminar esta descarga?",
    "Delete": "Eliminar",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "Se eliminará “%@” (%@). Puedes volver a descargarlo cuando quieras desde la pestaña Instalar.",
    "Couldn't delete %@: %@": "No se ha podido eliminar %@: %@",
    "Server": "Servidor",
    "Custom…": "Personalizado…",
    "Server URL": "URL del servidor",
    "Anisette Server": "Servidor Anisette",
    "Device IP": "IP del dispositivo",
    "Advanced": "Avanzado",
    "Clear": "Borrar",
    "Activity Log (%d)": "Registro de actividad (%d)",

    // MARK: - Release channels & downloads

    "Stable": "Estable",
    "Nightly": "Nightly",
    "couldn't find the IPA in the %@ %@ release":
        "no se ha encontrado el IPA en la versión %@ de %@",
    "%@ has no %@ release right now": "%@ no tiene ninguna versión %@ ahora mismo",
    "bad asset URL": "URL del recurso incorrecta",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub está limitando las peticiones de esta red — no está bloqueado, y el límite se restablece solo. Inténtalo de nuevo %@.",
    "GitHub answered HTTP %d%@": "GitHub ha respondido HTTP %d%@",
    "couldn't reach GitHub: %@": "no se ha podido conectar con GitHub: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "la respuesta de GitHub no era información de la versión (%@) — puede que algo en esta red la haya sustituido.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "lo que se ha descargado como %@ no es un IPA — algo en esta red ha devuelto una página, o la transferencia se ha interrumpido.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "ese enlace respondió HTTP %d — no es una descarga directa, o requiere iniciar sesión.",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "Se ha cancelado la verificación en dos pasos.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID o contraseña incorrectos. Comprueba el correo y la contraseña de tu Apple Account y vuelve a intentarlo.",
    "Apple ID sign-in failed on %@. Last error: %@":
        "No se ha podido iniciar sesión con el Apple ID en %@. Último error: %@",
    "the anisette server": "el servidor anisette",
    "all %d anisette servers": "los %d servidores anisette",
    "Not signed in.": "No has iniciado sesión.",
    "No SideStore IPA downloaded.": "No hay ningún IPA de SideStore descargado.",
    "Signing failed: %@": "Falló la firma: %@",
    "No signed bundle to install.": "No hay ningún paquete firmado que instalar.",
    "Device link dropped — reconnect.":
        "Se ha perdido el enlace con el dispositivo: vuelve a conectarlo.",
    "Pairing didn't finish — no pairing file yet.":
        "El emparejamiento no ha terminado: todavía no hay archivo de emparejamiento.",
    "Pairing file missing — pairing must run first.":
        "Falta el archivo de emparejamiento: primero hay que emparejar.",
    "Pairing file missing — generate it first.":
        "Falta el archivo de emparejamiento: genéralo primero.",
    "No pairing file yet — tap “Generate pairing file” first.":
        "Todavía no hay archivo de emparejamiento: toca antes “Generar archivo de emparejamiento”.",
    "%@ isn't installed yet — install must run first.":
        "%@ todavía no está instalado: primero hay que instalarlo.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ no es un IPA válido: es probable que la descarga devolviera una página de error o que la copia se cortara a medias. Sustitúyelo y toca Instalar otra vez.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ no es un IPA. Elige el archivo .ipa en sí; si parece correcto, puede que la descarga guardara una página de error o se cortara a medias.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Aún no has importado ningún IPA. Toca “Importar .ipa” y elige uno.",
    "Couldn't import %@: %@": "No se ha podido importar %@: %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "SideInstaller no puede descargar ese enlace. Pega la dirección https:// completa desde la que se descarga el .ipa.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "Ese enlace no devolvió un IPA. Tiene que descargar el archivo directamente: una página que solo enlaza al .ipa, o que pide iniciar sesión antes, llega aquí como una página web.",
    "Couldn't download that link: %@": "No se pudo descargar ese enlace: %@",
    "there's nothing to download for a custom IPA — import one first":
        "no hay nada que descargar para un IPA personalizado: impórtalo primero",
    "your app": "tu app",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple no emitirá un certificado de firma para este Apple ID: informa de que ya existe uno, o de que aún hay una solicitud pendiente (error 7460). SideInstaller no ha podido reutilizar el certificado que ya hay, así que se ha detenido en lugar de sustituirlo. Consulta los pasos de arriba.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "No se ha podido registrar este iPhone%@ en el equipo de desarrollo de tu Apple ID, así que Apple no emitirá un perfil de aprovisionamiento. %@ — consulta los pasos de arriba.",
    "Connect to Wi-Fi": "Conéctate al Wi-Fi",
    "Open Settings › Wi-Fi and join a network.": "Abre Ajustes › Wi-Fi y únete a una red.",
    "Then come back here — this continues automatically.":
        "Después vuelve aquí: el proceso continúa solo.",
    "Tap Connect so the toggle turns on.": "Toca Connect para que el interruptor se active.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Deja el Wi-Fi activado y vuelve aquí: el proceso continúa solo.",
    "Get LocalDevVPN": "Obtener LocalDevVPN",
    "Import an .ipa first": "Importa un .ipa primero",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Toca “Importar .ipa” arriba y elige el archivo: puede estar en cualquier sitio al que llegue la app Archivos, incluidos iCloud Drive o una unidad USB.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "O pega un enlace de descarga directa debajo de ese botón y SideInstaller descargará el .ipa por ti.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "O abre la app Archivos, mantén pulsado el .ipa, toca Compartir y elige SideInstaller: así el archivo llega sin pasar por el selector.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "O cópialo en Archivos › En mi iPhone › SideInstaller, donde SideInstaller también lo encuentra.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "Esta es la vía donde GitHub está bloqueado: consigue el IPA en cualquier dispositivo, tráelo e instálalo aquí.",
    "Pair this iPhone in Settings": "Empareja este iPhone en Ajustes",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Abre la app Ajustes y ve a Privacidad y seguridad › Modo desarrollador.",
    "Tap “Pair with SideInstaller”.": "Toca “Emparejar con SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.":
        "Introduce el código de tu iPhone si te lo pide.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Vuelve a SideInstaller, mira el código que te muestra y escribe ese mismo código en el mensaje de Ajustes.",
    "A signing certificate already exists": "Ya existe un certificado de firma",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Apple ha devuelto el error 7460: este Apple ID ya tiene un certificado de desarrollo de iOS, o hay una solicitud pendiente.",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideInstaller no ha podido reutilizarlo. Eso pasa cuando el certificado se emitió en otro sitio — AltStore, SideStore, Sideloadly o Xcode en otro dispositivo —, así que la clave privada que necesita no está en este iPhone.",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "Usa “Revocar y reintentar” arriba, o abre Certificados en la pestaña Herramientas, toca “Cargar certificados” y revócalo desde ahí.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "Revocar es permanente: todas las apps ya firmadas con ese certificado dejarán de abrirse, en todos los dispositivos.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Otra opción: inicia sesión arriba con otro Apple ID (o uno de repuesto) y toca Instalar otra vez.",

    // MARK: - Guide cards

    // Guide: import a pairing file

    "Import a pairing file": "Importar un archivo de emparejamiento",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@ es la primera versión en la que un iPhone puede emparejarse consigo mismo. En este, el archivo de emparejamiento hay que crearlo en un ordenador.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "En un Mac, un PC con Windows o Linux, conecta este iPhone, confía en el ordenador y ejecuta jitterbugpair (o “pymobiledevice3 lockdown pair”).",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "Envía el archivo que genere — un .mobiledevicepairing o .plist — a este iPhone, por AirDrop, iCloud Drive o cable.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "Vuelve aquí, toca “Importar archivo de emparejamiento” y elígelo. A partir de ahí todo funciona como en iOS %@.",
    "Get jitterbugpair": "Descargar jitterbugpair",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "Ya existe un certificado",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple no emitirá un segundo certificado de firma para este Apple ID. Revocar el que ya tiene permite continuar la instalación, pero no se puede deshacer.",
    "Loading certificates": "Cargando certificados",
    "Revoke and retry": "Revocar y reintentar",
    "Which certificate should be revoked?": "¿Qué certificado quieres revocar?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple indica que hay un certificado en este Apple ID, pero la lista ha llegado vacía. Puede que sea una solicitud aún pendiente: espera unos minutos y toca Instalar otra vez.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "Todas las apps ya firmadas con el certificado que elijas dejarán de abrirse, en todos los dispositivos, incluidas las instaladas con AltStore, SideStore o desde un ordenador. Esto no se puede deshacer. La instalación se reintenta justo después.",
    " (expired)": " (caducado)",

    "Couldn't register this device": "No se ha podido registrar este dispositivo",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Tu Apple ID ha alcanzado el límite de dispositivos registrados. Las cuentas gratuitas solo pueden registrar unos pocos dispositivos al año y no pueden quitar los antiguos hasta que el año se reinicia.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "La solución más sencilla: pon otro Apple ID (o uno de repuesto) en los campos de arriba y toca Instalar otra vez.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller no ha podido añadir este iPhone al equipo de desarrollo de tu Apple ID automáticamente. Volver a tocar Instalar suele funcionar: el servicio de desarrollo de Apple a veces deja de estar disponible un rato.",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "Si sigue fallando, añade el dispositivo a mano. Su UDID es:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Pega eso en el formulario “Register a Device” del portal de Apple Developer (esto requiere una cuenta de pago de Apple Developer) y toca Instalar otra vez.",
    "Open device list": "Abrir la lista de dispositivos",

    "Last step: trust %@": "Último paso: confía en %@",
    "Open Settings › General › VPN & Device Management.":
        "Abre Ajustes › General › VPN y gestión de dispositivos.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "Toca tu Apple ID en “App de desarrollador” y luego toca Confiar.",
    "Open %@ from your Home Screen — you're done.":
        "Abre %@ desde la pantalla de inicio: ya está.",

    "Import the certificate into LiveContainer": "Importa el certificado en LiveContainer",
    "Open LiveContainer from your Home Screen.":
        "Abre LiveContainer desde la pantalla de inicio.",
    "Tap the Settings tab.": "Toca la pestaña Settings.",
    "Tap “Import Certificate From SideStore”.":
        "Toca “Import Certificate From SideStore”.",
    "Wrong device IP": "IP de dispositivo incorrecta",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "La dirección en Ajustes › Avanzado › IP del dispositivo es una que este iPhone ya tiene, así que no hay nada al otro extremo a lo que conectarse.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "Vuelve a ponerla en 10.7.0.1, el valor por omisión. En LocalDevVPN es el valor de Ajustes › Device IP, no la dirección de su pantalla principal, que es el extremo del propio túnel.",
    "If you changed LocalDevVPN's addresses, put its Device IP here, and make sure its Tunnel IP and subnet mask cover it.":
        "Si cambiaste las direcciones de LocalDevVPN, pon aquí su Device IP y comprueba que su Tunnel IP y su máscara de subred la abarquen.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Emparejar este iPhone lo necesita: SideInstaller se anuncia en la red local para que Ajustes lo encuentre.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Conéctate a una red Wi-Fi. Emparejar este iPhone lo necesita: SideInstaller tiene que ser localizable en la red local.",

    // MARK: - About

    "About": "Información",
    "Version %@ (%@)": "Versión %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller instala SideStore y LiveContainer directamente en tu iPhone, sin necesidad de un PC.",

    "Links": "Enlaces",
    "Source code": "Código fuente",
    "Support the project": "Apoya el proyecto",

    "Special thanks": "Agradecimientos especiales",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "Por idevice, la biblioteca con la que SideInstaller se comunica con tu iPhone. Sin ella nada de esto existiría.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Por el apoyo y por detectar los fallos que se corrigieron gracias a ello.",

    "Built with": "Creado con",
    "The open source work this app is built on:":
        "El trabajo de código abierto en el que se apoya esta app:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "El emparejamiento, el túnel y la instalación en sí. De jkcoxson, MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Inicio de sesión con Apple ID, certificados y firma en el dispositivo. De nab138, MIT.",
    "The sideloading app this installs for you.":
        "La app de sideloading que esta instala por ti.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Ejecuta apps sideloadeadas sin gastar un espacio de app en cada una.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "La imagen de disco de desarrollador que monta la simulación de ubicación. Replicada por doronz88.",

    "Where to get it": "Dónde conseguirlo",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "Solo las compilaciones de la página de instalación y del repositorio oficiales son mías. Cualquiera puede bifurcar el código, añadirle un ladrón de credenciales y publicarlo con el mismo nombre e icono: no confíes tu Apple ID a una copia de otro sitio.",
    "Install page": "Página de instalación",
    "Terms": "Términos",
]
