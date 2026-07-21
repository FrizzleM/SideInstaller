import Foundation

/// Italian copy, keyed by the English source string every call site passes to
/// `L(_:)` — same contract as `spanishStrings`: same keys, same placeholders,
/// and product / third-party UI names left alone so the user isn't sent looking
/// for a button that doesn't exist under that name.
let italianStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "Annulla",
    "Copy": "Copia",
    "Email": "Email",
    "Password": "Password",
    "Install": "Installa",
    "Installing": "Installazione",
    "Installed": "Installato",
    "Something went wrong": "Qualcosa è andato storto",
    "an app by Frizzle": "un'app di Frizzle",
    "device": "dispositivo",

    // MARK: - Welcome

    "I have accepted the": "Ho letto e accetto i",
    "Start": "Inizia",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "Abbinamento",
    "Certificates": "Certificati",
    "Two-Factor Code": "Codice di verifica",
    "6-digit code": "Codice a 6 cifre",
    "Submit": "Invia",
    "Enter the code Apple just sent to your trusted device.":
        "Inserisci il codice che Apple ha appena inviato al tuo dispositivo.",

    // MARK: - Install tab

    "Tunnel connected": "Tunnel connesso",
    "Tunnel off": "Tunnel disattivato",
    "Update available": "Aggiornamento disponibile",
    "SideInstaller %@ is available — you're on %@.":
        "SideInstaller %@ è disponibile — tu hai la %@.",
    "Get the latest version": "Scarica l'aggiornamento",
    "Release": "Canale",
    "Reinstall": "Reinstalla",
    "Install %@": "Installa %@",
    "iOS %@ required": "Richiede iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Questo iPhone ha iOS %@, su cui SideInstaller non può installare nulla. Aggiorna a iOS %@ in Impostazioni › Generali › Aggiornamento software.",
    "Wi-Fi required": "Richiede il Wi-Fi",
    "Connect to a Wi-Fi network. LocalDevVPN's tunnel and the install run over it.":
        "Connettiti a una rete Wi-Fi. Il tunnel di LocalDevVPN e l'installazione ci passano sopra.",
    "LocalDevVPN required": "Richiede LocalDevVPN",
    "Open LocalDevVPN and tap Connect. The install runs over its tunnel.":
        "Apri LocalDevVPN e tocca Connect. L'installazione passa dal suo tunnel.",
    "Pairing code": "Codice di abbinamento",
    "Type this into the prompt in Settings.":
        "Scrivi questo codice nella richiesta che compare in Impostazioni.",
    "Install stopped": "Installazione interrotta",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ è installato. Completa il passaggio di autorizzazione qui sopra per aprirlo.",
    "Action needed": "Richiede un'azione",

    // MARK: - Install steps

    "Connect the VPN": "Connettere la VPN",
    "Pair with this iPhone": "Abbinare questo iPhone",
    "Open the device link": "Aprire il collegamento al dispositivo",
    "Sign in to Apple ID": "Accedere con l'Apple ID",
    "Download %@": "Scaricare %@",
    "Sign the app": "Firmare l'app",
    "Finish setup": "Completare la configurazione",

    // MARK: - Pairing tab

    "Pairing file ready": "File di abbinamento pronto",
    "No pairing file": "Nessun file di abbinamento",
    "Pairing file": "File di abbinamento",
    "Pairing…": "Abbinamento…",
    "Regenerate": "Rigenera",
    "Generate pairing file": "Genera il file di abbinamento",
    "Export pairing file": "Esporta il file di abbinamento",
    "Pair in Settings": "Abbina in Impostazioni",
    "Install into an app": "Installa in un'app",
    "Scanning": "Ricerca",
    "Rescan apps": "Cerca di nuovo",
    "Scan installed apps": "Cerca le app installate",
    "Connect to Wi-Fi to scan and install. LocalDevVPN's tunnel runs over it.":
        "Connettiti al Wi-Fi per cercare e installare. Il tunnel di LocalDevVPN ci passa sopra.",
    "Turn on LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Attiva LocalDevVPN per cercare e installare. La scrittura passa dal suo tunnel.",
    "%d supported app installed": "%d app compatibile installata",
    "%d supported apps installed": "%d app compatibili installate",
    "No supported apps found": "Nessuna app compatibile trovata",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Installa prima un'app come SideStore, StikDebug o Feather, poi cerca di nuovo.",
    "Install pairing": "Installa l'abbinamento",
    "Pairing file ready. You can export it or install it into an app below.":
        "File di abbinamento pronto. Puoi esportarlo o installarlo in un'app qui sotto.",
    "Pairing file installed into %@.": "File di abbinamento installato in %@.",

    // MARK: - Pairing service status

    "not paired": "non abbinato",
    "connected": "connesso",
    "requesting Local Network…": "richiesta rete locale…",
    "Local Network denied": "rete locale negata",
    "waiting for device…": "in attesa del dispositivo…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "in ascolto — apri Impostazioni › Privacy e sicurezza › Modalità sviluppatore",
    "enter PIN %@ in Settings": "inserisci il PIN %@ in Impostazioni",
    "paired: %@ (%dB)": "abbinato: %@ (%d B)",
    "failed: empty pairing file": "errore: file di abbinamento vuoto",
    "failed: %@": "errore: %@",
    "Pairing is already in progress.": "C'è già un abbinamento in corso.",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "Il permesso Rete locale è disattivato. Attivalo in Impostazioni › SideInstaller › Rete locale, poi riprova.",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "L'abbinamento ha prodotto un file vuoto. Assicurati di aver accettato la richiesta di abbinamento, poi riprova.",

    // MARK: - Certificates tab

    "Revoke this certificate?": "Revocare questo certificato?",
    "Revoke": "Revoca",
    "Revoking": "Revoca in corso",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "“%@” verrà revocato. Le app già firmate con questo certificato smetteranno di aprirsi su tutti i dispositivi. L'operazione non può essere annullata.",
    "Refreshing": "Aggiornamento",
    "Signing in": "Accesso in corso",
    "Refresh": "Aggiorna",
    "Load certificates": "Carica i certificati",
    "%d of 3 certificates": "%d di 3 certificati",
    "No certificates": "Nessun certificato",
    "This Apple ID has no development certificates to revoke.":
        "Questo Apple ID non ha certificati di sviluppo da revocare.",
    "Expired": "Scaduto",
    "Expires %@": "Scade il %@",
    "Unnamed certificate": "Certificato senza nome",
    "Enter your Apple ID email and password first.":
        "Inserisci prima email e password del tuo Apple ID.",
    "This certificate has no serial number, so it can't be revoked.":
        "Questo certificato non ha un numero di serie, quindi non può essere revocato.",

    // MARK: - Settings

    "Settings": "Impostazioni",
    "Done": "Fine",
    "Language": "Lingua",
    "App language": "Lingua dell'app",
    "Auto": "Automatica",
    "Downloaded IPAs": "IPA scaricati",
    "%@ used": "%@ occupati",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "Nessun IPA scaricato. Quelli che installi dalla scheda Installa vengono conservati qui.",
    "Downloaded %@": "Scaricato il %@",
    "Delete this download?": "Eliminare questo download?",
    "Delete": "Elimina",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "“%@” (%@) verrà rimosso. Puoi riscaricarlo quando vuoi dalla scheda Installa.",
    "Couldn't delete %@: %@": "Impossibile eliminare %@: %@",
    "Server": "Server",
    "Custom…": "Personalizzato…",
    "Server URL": "URL del server",
    "Anisette Server": "Server Anisette",
    "Device IP": "IP del dispositivo",
    "Advanced": "Avanzate",
    "Clear": "Cancella",
    "Activity Log (%d)": "Registro attività (%d)",

    // MARK: - Release channels & downloads

    "Stable": "Stabile",
    "Nightly": "Nightly",
    "couldn't find the IPA in the %@ %@ release":
        "impossibile trovare l'IPA nella release %@ di %@",
    "%@ has no %@ release right now": "%@ al momento non ha nessuna release %@",
    "bad asset URL": "URL della risorsa non valido",

    // MARK: - Engine failures

    "Enter your Apple ID email + password.":
        "Inserisci email e password del tuo Apple ID.",
    "Two-factor verification was cancelled.":
        "La verifica in due passaggi è stata annullata.",
    "Apple ID sign-in failed: %@": "Accesso con l'Apple ID non riuscito: %@",
    "Apple ID sign-in failed on %@. Last error: %@":
        "Accesso con l'Apple ID non riuscito su %@. Ultimo errore: %@",
    "the anisette server": "il server anisette",
    "all %d anisette servers": "tutti e %d i server anisette",
    "Not signed in.": "Accesso non effettuato.",
    "No SideStore IPA downloaded.": "Nessun IPA di SideStore scaricato.",
    "Signing failed: %@": "Firma non riuscita: %@",
    "No signed bundle to install.": "Nessun pacchetto firmato da installare.",
    "Device link dropped — reconnect.":
        "Collegamento al dispositivo perso: riconnettilo.",
    "Pairing didn't finish — no pairing file yet.":
        "L'abbinamento non è stato completato: non c'è ancora un file di abbinamento.",
    "Pairing file missing — pairing must run first.":
        "Manca il file di abbinamento: prima bisogna eseguire l'abbinamento.",
    "Pairing file missing — generate it first.":
        "Manca il file di abbinamento: generalo prima.",
    "No pairing file yet — tap “Generate pairing file” first.":
        "Non c'è ancora un file di abbinamento: tocca prima “Genera il file di abbinamento”.",
    "%@ isn't installed yet — install must run first.":
        "%@ non è ancora installato: prima bisogna installarlo.",
    "Wi-Fi is off. Connect to a Wi-Fi network, then try again.":
        "Il Wi-Fi è disattivato. Connettiti a una rete Wi-Fi e riprova.",
    "LocalDevVPN isn't connected. Turn it on, then try again.":
        "LocalDevVPN non è connesso. Attivalo e riprova.",
    "Apple allows only 3 signing certificates per Apple ID and this one already has 3, so a new one can't be made. Open the Certificates tab, tap “Load certificates”, and revoke an old or expired one to free a slot — then tap Install again. See the steps above.":
        "Apple consente solo 3 certificati di firma per Apple ID e questo ne ha già 3, quindi non se ne può creare un altro. Apri la scheda Certificati, tocca “Carica i certificati” e revocane uno vecchio o scaduto per liberare un posto, poi tocca di nuovo Installa. Vedi i passaggi qui sopra.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Non è stato possibile registrare questo iPhone%@ nel team di sviluppo del tuo Apple ID, quindi Apple non rilascerà un profilo di provisioning. %@ — vedi i passaggi qui sopra.",

    // MARK: - Guide cards

    "Connect to Wi-Fi": "Connettiti al Wi-Fi",
    "Open Settings › Wi-Fi and join a network.":
        "Apri Impostazioni › Wi-Fi e collegati a una rete.",
    "LocalDevVPN's tunnel — and the whole install — run over Wi-Fi.":
        "Il tunnel di LocalDevVPN — e tutta l'installazione — passano dal Wi-Fi.",
    "Then come back here — this continues automatically.":
        "Poi torna qui: il processo va avanti da solo.",

    "Turn on LocalDevVPN": "Attiva LocalDevVPN",
    "Open the LocalDevVPN app (install it first if you haven't).":
        "Apri l'app LocalDevVPN (se non ce l'hai, installala prima).",
    "Tap Connect so the toggle turns on.":
        "Tocca Connect per far scattare l'interruttore.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Lascia il Wi-Fi attivo e torna qui: il processo va avanti da solo.",
    "Get LocalDevVPN": "Scarica LocalDevVPN",

    "Pair this iPhone in Settings": "Abbina questo iPhone in Impostazioni",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Apri l'app Impostazioni, poi vai in Privacy e sicurezza › Modalità sviluppatore.",
    "Tap “Pair with SideInstaller”.": "Tocca “Abbina a SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.":
        "Inserisci il codice del tuo iPhone se te lo chiede.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Torna in SideInstaller, leggi il codice che ti mostra e scrivi lo stesso codice nella richiesta in Impostazioni.",

    "Too many signing certificates": "Troppi certificati di firma",
    "Apple allows only 3 signing certificates per Apple ID, and this one already has 3 — usually left over from setting up AltStore / SideStore on other devices.":
        "Apple consente solo 3 certificati di firma per Apple ID e questo ne ha già 3 — di solito sono avanzi della configurazione di AltStore / SideStore su altri dispositivi.",
    "Open the Certificates tab at the bottom of the screen, make sure your Apple ID is filled in, and tap “Load certificates”.":
        "Apri la scheda Certificati in fondo allo schermo, controlla di aver inserito il tuo Apple ID e tocca “Carica i certificati”.",
    "Tap “Revoke” on an old or expired certificate to free up a slot. Revoking stops apps already signed with that certificate from launching on other devices, so pick one you no longer use.":
        "Tocca “Revoca” su un certificato vecchio o scaduto per liberare un posto. Revocandolo, le app già firmate con quel certificato non si apriranno più sugli altri dispositivi: scegline uno che non usi più.",
    "Come back to the Install tab and tap Install again.":
        "Torna alla scheda Installa e tocca di nuovo Installa.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "In alternativa, accedi qui sopra con un altro Apple ID (o uno di riserva) e tocca di nuovo Installa.",

    "Couldn't register this device": "Impossibile registrare questo dispositivo",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Il tuo Apple ID ha raggiunto il limite di dispositivi registrati. Gli account gratuiti possono registrare solo pochi dispositivi all'anno e non possono rimuovere quelli vecchi finché l'anno non riparte.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "La soluzione più semplice: metti un altro Apple ID (o uno di riserva) nei campi qui sopra e tocca di nuovo Installa.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller non è riuscito ad aggiungere automaticamente questo iPhone al team di sviluppo del tuo Apple ID. Spesso basta toccare di nuovo Installa: il servizio sviluppatori di Apple ogni tanto non è disponibile per qualche momento.",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "Se continua a non funzionare, aggiungi il dispositivo a mano. Il suo UDID è:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Incollalo nel modulo “Register a Device” del portale Apple Developer (serve un account Apple Developer a pagamento), poi tocca di nuovo Installa.",
    "Open device list": "Apri l'elenco dei dispositivi",

    "Last step: trust %@": "Ultimo passaggio: autorizza %@",
    "Open Settings › General › VPN & Device Management.":
        "Apri Impostazioni › Generali › VPN e gestione dispositivi.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "Tocca il tuo Apple ID sotto “App sviluppatore”, poi tocca Autorizza.",
    "Open %@ from your Home Screen — you're done.":
        "Apri %@ dalla schermata Home: è tutto pronto.",

    "Import the certificate into LiveContainer": "Importa il certificato in LiveContainer",
    "Open LiveContainer from your Home Screen.":
        "Apri LiveContainer dalla schermata Home.",
    "Tap the Settings tab.": "Tocca la scheda Settings.",
    "Tap “Import Certificate From SideStore”.":
        "Tocca “Import Certificate From SideStore”.",
]
