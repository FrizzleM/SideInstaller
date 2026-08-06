import Foundation

/// Italian copy, on the same contract as `spanishStrings`.
let italianStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "Annulla",
    "Copy": "Copia",
    "Email": "Email",
    "Password": "Password",
    "Install": "Installa",
    "Installing": "Installazione in corso",
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
    "Custom .ipa": "IPA personalizzato",
    "Import .ipa": "Importa .ipa",
    "Importing…": "Importazione…",
    "Replace": "Sostituisci",
    "iOS %@ required": "Serve iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Questo iPhone ha iOS %@, su cui SideInstaller non può installare nulla. Aggiorna a iOS %@ in Impostazioni › Generali › Aggiornamento software.",
    "Wi-Fi required": "Serve il Wi-Fi",
    "Loopback VPN required": "Serve una VPN loopback",
    "Turn on a loopback VPN — LocalDevVPN, ClashMi, or any app that tunnels to this iPhone. The install runs over it.":
        "Attiva una VPN loopback: LocalDevVPN, ClashMi o qualsiasi app che crei un tunnel verso questo iPhone. L'installazione ci passa sopra.",
    "Pairing code": "Codice di abbinamento",
    "Type this into the prompt in Settings.":
        "Scrivi questo codice nella richiesta che compare in Impostazioni.",
    "Install stopped": "Installazione interrotta",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ è installato. Completa il passaggio di autorizzazione qui sopra per aprirlo.",
    "Action needed": "Serve il tuo intervento",

    // MARK: - Install steps

    "Connect the VPN": "Connettere la VPN",
    "Pair with this iPhone": "Abbinare questo iPhone",
    "Open the device link": "Aprire il collegamento al dispositivo",
    "Sign in to Apple ID": "Accedere con l'Apple ID",
    "Download %@": "Scaricare %@",
    "Use your imported IPA": "Usa l'IPA importato",
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
    "Scanning": "Ricerca in corso",
    "Rescan apps": "Cerca di nuovo",
    "Scan installed apps": "Cerca le app installate",
    "Turn on a loopback VPN to scan and install. The write runs over its tunnel.":
        "Attiva una VPN loopback per cercare e installare. La scrittura passa dal suo tunnel.",
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
    "requesting Local Network…": "richiesta di accesso alla rete locale…",
    "Local Network denied": "accesso alla rete locale negato",
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
    "Refreshing": "Aggiornamento in corso",
    "Signing in": "Accesso in corso",
    "Refresh": "Aggiorna",
    "Load certificates": "Carica i certificati",
    "%d certificate(s)": "%d certificato/i",
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
    "imported": "importato",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "Nessun IPA scaricato. Quelli che installi dalla scheda Installa vengono conservati qui.",
    "Downloaded %@": "Scaricato il %@",
    "Added %@": "Aggiunto %@",
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
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "GitHub sta limitando le richieste da questa rete — non è bloccato, e il limite si azzera da solo. Riprova %@.",
    "GitHub answered HTTP %d%@": "GitHub ha risposto HTTP %d%@",
    "couldn't reach GitHub: %@": "impossibile raggiungere GitHub: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "la risposta di GitHub non conteneva le informazioni sulla release (%@) — qualcosa su questa rete potrebbe averla sostituita.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "ciò che è stato scaricato come %@ non è un IPA — qualcosa su questa rete ha restituito una pagina, oppure il trasferimento si è interrotto.",

    // MARK: - Engine failures

    "Enter your Apple ID email + password.":
        "Inserisci email e password del tuo Apple ID.",
    "Two-factor verification was cancelled.":
        "La verifica a due fattori è stata annullata.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID o password non corretti. Controlla l'email e la password del tuo Apple Account e riprova.",
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
    "No loopback VPN is connected. Turn one on, then try again.":
        "Nessuna VPN loopback è connessa. Attivane una, poi riprova.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ non è un IPA valido: probabilmente il download ha restituito una pagina di errore, oppure la copia si è interrotta a metà. Sostituiscilo e tocca Installa di nuovo.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ non è un IPA. Scegli il file .ipa vero e proprio: se sembra giusto, forse il download ha salvato una pagina di errore o si è interrotto a metà.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Non hai ancora importato nessun IPA. Tocca “Importa .ipa” e scegline uno.",
    "Couldn't import %@: %@": "Impossibile importare %@: %@",
    "there's nothing to download for a custom IPA — import one first":
        "non c'è nulla da scaricare per un IPA personalizzato: importalo prima",
    "your app": "la tua app",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple non rilascia un certificato di firma per questo Apple ID: segnala che ne esiste già uno, o che una richiesta è ancora in sospeso (errore 7460). SideInstaller non è riuscito a riutilizzare il certificato già presente, quindi si è fermato invece di sostituirlo. Vedi i passaggi qui sopra.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Non è stato possibile registrare questo iPhone%@ nel team di sviluppo del tuo Apple ID, quindi Apple non rilascerà un profilo di provisioning. %@ — vedi i passaggi qui sopra.",

    // MARK: - Guide cards

    "Connect to Wi-Fi": "Connettiti al Wi-Fi",
    "Open Settings › Wi-Fi and join a network.":
        "Apri Impostazioni › Wi-Fi e collegati a una rete.",
    "Then come back here — this continues automatically.":
        "Poi torna qui: il processo va avanti da solo.",

    "Turn on a loopback VPN": "Attiva una VPN loopback",
    "Open a VPN app that tunnels to this iPhone — LocalDevVPN, ClashMi, or another. Any of them works.":
        "Apri un'app VPN che crei un tunnel verso questo iPhone: LocalDevVPN, ClashMi o un'altra. Va bene qualsiasi.",
    "If GitHub is blocked where you are, pick one that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Se dove sei GitHub è bloccato, scegline una che sappia anche fare da proxy: iOS tiene attiva una sola VPN alla volta, quindi un tunnel solo locale non lascia nulla con cui scaricare SideStore.",
    "Tap Connect so the toggle turns on.":
        "Tocca Connect per far scattare l'interruttore.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Lascia il Wi-Fi attivo e torna qui: il processo va avanti da solo.",
    "Get LocalDevVPN": "Scarica LocalDevVPN",
    "Import an .ipa first": "Importa prima un .ipa",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Tocca “Importa .ipa” qui sopra e scegli il file: può trovarsi ovunque arrivi l'app File, iCloud Drive o una chiavetta USB compresi.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "Oppure copialo in File › Sul mio iPhone › SideInstaller, dove SideInstaller lo trova comunque.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "È la strada da seguire dove GitHub è bloccato: procurati l'IPA su un dispositivo qualsiasi, portalo qui e installalo.",

    "Pair this iPhone in Settings": "Abbina questo iPhone in Impostazioni",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Apri l'app Impostazioni, poi vai in Privacy e sicurezza › Modalità sviluppatore.",
    "Tap “Pair with SideInstaller”.": "Tocca “Abbina a SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.":
        "Inserisci il codice del tuo iPhone se te lo chiede.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Torna in SideInstaller, leggi il codice che ti mostra e scrivi lo stesso codice nella richiesta in Impostazioni.",

    "A signing certificate already exists": "Esiste già un certificato di firma",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Apple ha restituito l'errore 7460: questo Apple ID ha già un certificato di sviluppo iOS, oppure una richiesta è ancora in sospeso.",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideInstaller non è riuscito a riutilizzarlo. Succede quando il certificato è stato rilasciato altrove — AltStore, SideStore, Sideloadly o Xcode su un altro dispositivo — quindi la chiave privata che serve non è su questo iPhone.",
    "Use “Revoke and retry” above, or open the Certificates tab, tap “Load certificates”, and revoke it there.":
        "Usa “Revoca e riprova” qui sopra, oppure apri la scheda Certificati, tocca “Carica i certificati” e revocalo da lì.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "La revoca è definitiva: tutte le app già firmate con quel certificato smettono di aprirsi, su qualsiasi dispositivo.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "In alternativa, accedi qui sopra con un altro Apple ID (o uno di riserva) e tocca di nuovo Installa.",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "Esiste già un certificato",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple non rilascia un secondo certificato di firma per questo Apple ID. Revocare quello che c'è già fa proseguire l'installazione, ma è un'operazione irreversibile.",
    "Loading certificates": "Caricamento certificati",
    "Revoke and retry": "Revoca e riprova",
    "Which certificate should be revoked?": "Quale certificato vuoi revocare?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple segnala un certificato su questo Apple ID, ma la lista è arrivata vuota. Potrebbe essere una richiesta ancora in sospeso: aspetta qualche minuto e tocca di nuovo Installa.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "Tutte le app già firmate con il certificato che scegli smetteranno di aprirsi, su qualsiasi dispositivo, comprese quelle installate con AltStore, SideStore o da un computer. L'operazione è irreversibile. L'installazione riparte subito dopo.",
    " (expired)": " (scaduto)",

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
        "Tocca il tuo Apple ID sotto “App dello sviluppatore”, poi tocca Autorizza.",
    "Open %@ from your Home Screen — you're done.":
        "Apri %@ dalla schermata Home: è tutto pronto.",

    "Import the certificate into LiveContainer": "Importa il certificato in LiveContainer",
    "Open LiveContainer from your Home Screen.":
        "Apri LiveContainer dalla schermata Home.",
    "Tap the Settings tab.": "Tocca la scheda Settings.",
    "Tap “Import Certificate From SideStore”.":
        "Tocca “Import Certificate From SideStore”.",
    "Wrong device IP": "IP del dispositivo errato",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "L’indirizzo in Impostazioni › Avanzate › IP del dispositivo è uno che questo iPhone possiede già, quindi non c’è nulla all’altro capo a cui connettersi.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "Reimpostalo su 10.7.0.1, il valore predefinito. In LocalDevVPN è il valore in Impostazioni › Device IP, non l’indirizzo nella schermata principale, che è il capo del tunnel stesso.",
    "If you changed LocalDevVPN's addresses, put its Device IP here, and make sure its Tunnel IP and subnet mask cover it.":
        "Se hai cambiato gli indirizzi di LocalDevVPN, inserisci qui il suo Device IP e verifica che il suo Tunnel IP e la maschera di sottorete lo comprendano.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "L’associazione di questo iPhone lo richiede: SideInstaller si annuncia sulla rete locale perché Impostazioni lo trovi.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Connettiti a una rete Wi-Fi. L’associazione di questo iPhone lo richiede: SideInstaller deve essere individuabile sulla rete locale.",
]
