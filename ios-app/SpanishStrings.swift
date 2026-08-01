import Foundation

/// Spanish copy, keyed by the English source string every call site passes to
/// `L(_:)`. English is the source language, so there is no English table — a key
/// missing from here simply renders as the English it already is.
///
/// Keys with `%@` / `%d` are `String(format:)` patterns: the placeholders must
/// all survive translation, in a count and order the call site can satisfy.
/// Product and third-party UI names (SideStore, LiveContainer, LocalDevVPN,
/// Apple ID, and labels quoted from other apps' English interfaces) stay as they
/// are — translating them would send the user looking for a button that doesn't
/// exist.
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
    "Replace": "Sustituir",
    "iOS %@ required": "Se requiere iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Este iPhone tiene iOS %@, y con esa versión SideInstaller no puede instalar nada. Actualiza a iOS %@ o posterior en Ajustes › General › Actualización de software.",
    "Wi-Fi required": "Se requiere Wi-Fi",
    "Connect to a Wi-Fi network. The loopback tunnel and the install run over it.":
        "Conéctate a una red Wi-Fi. El túnel loopback y la instalación pasan por esa red.",
    "Loopback VPN required": "Se requiere una VPN loopback",
    "Turn on a loopback VPN — LocalDevVPN, ClashMi, or any app that tunnels to this iPhone. The install runs over it.":
        "Activa una VPN loopback: LocalDevVPN, ClashMi o cualquier app que haga un túnel a este iPhone. La instalación pasa por ella.",
    "Pairing code": "Código de emparejamiento",
    "Type this into the prompt in Settings.":
        "Escribe este código en el mensaje que aparece en Ajustes.",
    "Install stopped": "Instalación detenida",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ ya está instalado. Completa el paso de confianza de arriba para abrirlo.",
    "Action needed": "Necesita tu atención",

    // MARK: - Install steps

    "Connect the VPN": "Conectar la VPN",
    "Pair with this iPhone": "Emparejar con este iPhone",
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
    "Connect to Wi-Fi to scan and install. The loopback tunnel runs over it.":
        "Conéctate al Wi-Fi para buscar e instalar. El túnel loopback pasa por esa red.",
    "Turn on a loopback VPN to scan and install. The write runs over its tunnel.":
        "Activa una VPN loopback para buscar e instalar. La escritura se hace por su túnel.",
    "%d supported app installed": "%d app compatible instalada",
    "%d supported apps installed": "%d apps compatibles instaladas",
    "No supported apps found": "No se han encontrado apps compatibles",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Instala antes una app como SideStore, StikDebug o Feather y vuelve a buscar.",
    "Install pairing": "Instalar emparejamiento",
    "Pairing file ready. You can export it or install it into an app below.":
        "Archivo de emparejamiento listo. Puedes exportarlo o instalarlo en una app aquí abajo.",
    "Pairing file installed into %@.": "Archivo de emparejamiento instalado en %@.",

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
    "%d of 3 certificates": "%d de 3 certificados",
    "No certificates": "Sin certificados",
    "This Apple ID has no development certificates to revoke.":
        "Este Apple ID no tiene certificados de desarrollo que revocar.",
    "Expired": "Caducado",
    "Expires %@": "Caduca el %@",
    "Unnamed certificate": "Certificado sin nombre",
    "Enter your Apple ID email and password first.":
        "Introduce primero el correo y la contraseña de tu Apple ID.",
    "This certificate has no serial number, so it can't be revoked.":
        "Este certificado no tiene número de serie, así que no se puede revocar.",

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

    // MARK: - Engine failures

    "Enter your Apple ID email + password.":
        "Introduce el correo y la contraseña de tu Apple ID.",
    "Two-factor verification was cancelled.": "Se ha cancelado la verificación en dos pasos.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID o contraseña incorrectos. Comprueba el correo y la contraseña de tu Apple Account y vuelve a intentarlo.",
    "Apple ID sign-in failed: %@": "No se ha podido iniciar sesión con el Apple ID: %@",
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
    "Wi-Fi is off. Connect to a Wi-Fi network, then try again.":
        "El Wi-Fi está desactivado. Conéctate a una red Wi-Fi e inténtalo de nuevo.",
    "No loopback VPN is connected. Turn one on, then try again.":
        "No hay ninguna VPN loopback conectada. Activa una e inténtalo de nuevo.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ no es un IPA válido: es probable que la descarga devolviera una página de error o que la copia se cortara a medias. Sustitúyelo y toca Instalar otra vez.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ no es un IPA. Elige el archivo .ipa en sí; si parece correcto, puede que la descarga guardara una página de error o se cortara a medias.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Aún no has importado ningún IPA. Toca “Importar .ipa” y elige uno.",
    "Couldn't import %@: %@": "No se ha podido importar %@: %@",
    "there's nothing to download for a custom IPA — import one first":
        "no hay nada que descargar para un IPA personalizado: impórtalo primero",
    "your app": "tu app",
    "Apple allows only 3 signing certificates per Apple ID and this one already has 3, so a new one can't be made. Open the Certificates tab, tap “Load certificates”, and revoke an old or expired one to free a slot — then tap Install again. See the steps above.":
        "Apple solo permite 3 certificados de firma por Apple ID y este ya tiene 3, así que no se puede crear otro. Abre la pestaña Certificados, toca “Cargar certificados” y revoca uno antiguo o caducado para liberar un espacio; después toca Instalar otra vez. Consulta los pasos de arriba.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "No se ha podido registrar este iPhone%@ en el equipo de desarrollo de tu Apple ID, así que Apple no emitirá un perfil de aprovisionamiento. %@ — consulta los pasos de arriba.",

    // MARK: - Guide cards

    "Connect to Wi-Fi": "Conéctate al Wi-Fi",
    "Open Settings › Wi-Fi and join a network.": "Abre Ajustes › Wi-Fi y únete a una red.",
    "The loopback tunnel — and the whole install — run over Wi-Fi.":
        "El túnel loopback —y toda la instalación— pasan por el Wi-Fi.",
    "Then come back here — this continues automatically.":
        "Después vuelve aquí: el proceso continúa solo.",

    "Turn on a loopback VPN": "Activa una VPN loopback",
    "Open a VPN app that tunnels to this iPhone — LocalDevVPN, ClashMi, or another. Any of them works.":
        "Abre una app de VPN que haga un túnel a este iPhone: LocalDevVPN, ClashMi u otra. Cualquiera sirve.",
    "If GitHub is blocked where you are, pick one that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Si GitHub está bloqueado donde estás, elige una que además pueda hacer de proxy: iOS solo permite una VPN a la vez, así que un túnel solo local no deja por dónde descargar SideStore.",
    "Tap Connect so the toggle turns on.":
        "Toca Connect para que el interruptor se active.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Deja el Wi-Fi activado y vuelve aquí: el proceso continúa solo.",
    "Get LocalDevVPN": "Obtener LocalDevVPN",
    "Import an .ipa first": "Importa un .ipa primero",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Toca “Importar .ipa” arriba y elige el archivo: puede estar en cualquier sitio al que llegue la app Archivos, incluidos iCloud Drive o una unidad USB.",
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

    "Too many signing certificates": "Demasiados certificados de firma",
    "Apple allows only 3 signing certificates per Apple ID, and this one already has 3 — usually left over from setting up AltStore / SideStore on other devices.":
        "Apple solo permite 3 certificados de firma por Apple ID y este ya tiene 3 — normalmente son restos de configurar AltStore / SideStore en otros dispositivos.",
    "Open the Certificates tab at the bottom of the screen, make sure your Apple ID is filled in, and tap “Load certificates”.":
        "Abre la pestaña Certificados en la parte inferior de la pantalla, comprueba que hayas introducido tu Apple ID y toca “Cargar certificados”.",
    "Tap “Revoke” on an old or expired certificate to free up a slot. Revoking stops apps already signed with that certificate from launching on other devices, so pick one you no longer use.":
        "Toca “Revocar” en un certificado antiguo o caducado para liberar un espacio. Al revocarlo, las apps ya firmadas con ese certificado dejarán de abrirse en otros dispositivos, así que elige uno que ya no uses.",
    "Come back to the Install tab and tap Install again.":
        "Vuelve a la pestaña Instalar y toca Instalar otra vez.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Otra opción: inicia sesión arriba con otro Apple ID (o uno de repuesto) y toca Instalar otra vez.",

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
]
