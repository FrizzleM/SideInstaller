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

    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "Ti servirà un file di abbinamento",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "Questo iPhone usa iOS %@. Solo iOS %@ può abbinarsi da solo, quindi dovrai creare un file di abbinamento su un computer — con jitterbugpair o pymobiledevice3 — e importarlo nell'app. SideInstaller ti guida passo passo.",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "Accedi con il tuo Apple ID",
    "Don't worry, these are stored locally":
        "Tranquillo, restano salvati solo su questo iPhone",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "Salvato nel portachiavi di questo iPhone e inviato solo ad Apple durante l'accesso.",
    "Continue": "Continua",
    "Set this up later": "Configuralo più tardi",
    "Add Apple ID": "Aggiungi Apple ID",
    "Edit Apple ID": "Modifica Apple ID",
    "Save": "Salva",
    "Enter the password again to save this Apple ID.":
        "Inserisci di nuovo la password per salvare questo Apple ID.",
    "Account": "Account",
    "In use": "In uso",
    "Edit": "Modifica",
    "Remove": "Rimuovi",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "Nessun Apple ID salvato. Aggiungine uno e SideInstaller lo userà per ogni accesso.",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "Salvato nel portachiavi di questo iPhone e inviato solo ad Apple durante l'accesso. Scorri una riga per modificarne la password o per rimuoverla.",
    "Remove this Apple ID?": "Rimuovere questo Apple ID?",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "“%@” e la password salvata verranno eliminati da questo iPhone. Il tuo account Apple non cambia.",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "Il portachiavi di questo iPhone ha rifiutato di salvare la password (errore %d), quindi resta in memoria solo finché SideInstaller è aperto.",
    "No Apple ID saved. Add one in Settings › Account.":
        "Nessun Apple ID salvato. Aggiungine uno in Impostazioni › Account.",

    "Add your Apple ID": "Aggiungi il tuo Apple ID",
    "Open Settings with the gear at the top right.":
        "Apri le Impostazioni con l'ingranaggio in alto a destra.",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "Nella sezione Account, tocca “Aggiungi Apple ID” e inserisci email e password.",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "Strumenti",

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
    "or": "oppure",
    "Paste a download link": "Incolla un link di download",
    "Downloading… %d%%": "Download… %d%%",
    "iOS %@ required": "Serve iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Questo iPhone ha iOS %@, su cui SideInstaller non può installare nulla. Aggiorna a iOS %@ in Impostazioni › Generali › Aggiornamento software.",
    "Wi-Fi required": "Serve il Wi-Fi",
    "Pairing code": "Codice di abbinamento",
    "Type this into the prompt in Settings.":
        "Scrivi questo codice nella richiesta che compare in Impostazioni.",
    "Install stopped": "Installazione interrotta",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ è installato. Completa il passaggio di autorizzazione qui sopra per aprirlo.",
    "Action needed": "Serve il tuo intervento",
    "Step %@ of %@": "Passaggio %@ di %@",
    "Show all steps": "Mostra tutti i passaggi",
    "Show fewer steps": "Mostra meno passaggi",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "Serve LocalDevVPN",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "Installa LocalDevVPN e connettila. L'installazione passa dal suo tunnel.",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Connetti LocalDevVPN per cercare e installare. La scrittura passa dal suo tunnel.",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "Connetti LocalDevVPN. La simulazione passa dal suo tunnel, come tutto il resto qui.",
    "LocalDevVPN isn't connected. Connect it, then try again.":
        "LocalDevVPN non è connessa. Connettila e riprova.",
    "Connect LocalDevVPN": "Connetti LocalDevVPN",
    "Install LocalDevVPN from the App Store and open it.":
        "Installa LocalDevVPN dall'App Store e aprila.",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Se GitHub è bloccato dove sei, usa una VPN che sappia anche instradare il tuo traffico: iOS esegue una VPN alla volta, quindi un tunnel solo locale non lascia nulla da cui scaricare SideStore.",

    // MARK: - Install steps

    "Connect the VPN": "Connettere la VPN",
    "Get pairing file": "Ottieni il file di abbinamento",
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
    "%d supported app installed": "%d app compatibile installata",
    "%d supported apps installed": "%d app compatibili installate",
    "No supported apps found": "Nessuna app compatibile trovata",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Installa prima un'app come SideStore, StikDebug o Feather, poi cerca di nuovo.",
    "Install pairing": "Installa l'abbinamento",
    "Pairing file ready. You can export it or install it into an app below.":
        "File di abbinamento pronto. Puoi esportarlo o installarlo in un'app qui sotto.",
    "Pairing file installed into %@.": "File di abbinamento installato in %@.",

    // Importing a pairing file (iOS 26 and below)

    "Import pairing file": "Importa il file di abbinamento",
    "How do I make one?": "Come lo creo?",
    "imported pairing file": "file di abbinamento importato",
    "No pairing file yet — tap “Import pairing file” first.":
        "Nessun file di abbinamento — tocca prima “Importa il file di abbinamento”.",
    "Pairing file missing — import it first.": "File di abbinamento mancante: importalo prima.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ non è un file di abbinamento. Scegli il file creato dal tuo computer — un .mobiledevicepairing o .plist che contiene il record di abbinamento di questo iPhone.",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "iOS %@ non può creare il proprio file di abbinamento: serve iOS %@. Importane uno creato su un computer in “File di abbinamento”, poi riprova.",

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
    "This certificate has no serial number, so it can't be revoked.":
        "Questo certificato non ha un numero di serie, quindi non può essere revocato.",

    // MARK: - Location tab

    "Location spoofing": "Simulazione posizione",
    "Not simulating": "Non in simulazione",
    "Simulated": "Simulata",
    "Pick a place": "Scegli un luogo",
    "Search for a place": "Cerca un luogo",
    "Nothing found for “%@”.": "Nessun risultato per “%@”.",
    "Set location": "Imposta posizione",
    "Setting": "Impostazione",
    "Reset to real location": "Torna alla posizione reale",
    "Location set to %@.": "Posizione impostata su %@.",
    "Location reset. The device is using its own again.":
        "Posizione ripristinata. Il dispositivo usa di nuovo la sua.",
    "That isn't a valid coordinate.": "Quella coordinata non è valida.",
    "Location session closed — set it up again.":
        "La sessione di posizione è chiusa: preparala di nuovo.",
    "Downloading %@ failed (HTTP %d).": "Il download di %@ non è riuscito (HTTP %d).",
    "Couldn't build the download URL for %@.": "Impossibile costruire l'URL di download per %@.",

    // MARK: - Entitlements tab

    "Entitlements": "Permessi",
    "Load apps": "Carica le app",
    "%d App ID": "%d App ID",
    "%d App IDs": "%d App ID",
    "No App IDs": "Nessun App ID",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "Questo Apple ID non ha ancora registrato nessuna app. Installane una con SideInstaller, poi torna qui.",
    "Memory and performance": "Memoria e prestazioni",
    "Other free capabilities": "Altre funzionalità gratuite",
    "Recommended": "Consigliati",
    "Select all": "Seleziona tutto",
    "None": "Nessuno",
    "Enable %d selected": "Attiva %d selezionati",
    "Asking Apple": "Richiesta ad Apple",
    "%d of %d enabled": "%d di %d attivati",
    "Install the app again for these to take effect.":
        "Installa di nuovo l'app perché abbiano effetto.",

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
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "quel link ha risposto HTTP %d — non è un download diretto, oppure richiede l'accesso.",

    // MARK: - Engine failures

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
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ non è un IPA valido: probabilmente il download ha restituito una pagina di errore, oppure la copia si è interrotta a metà. Sostituiscilo e tocca Installa di nuovo.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ non è un IPA. Scegli il file .ipa vero e proprio: se sembra giusto, forse il download ha salvato una pagina di errore o si è interrotto a metà.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Non hai ancora importato nessun IPA. Tocca “Importa .ipa” e scegline uno.",
    "Couldn't import %@: %@": "Impossibile importare %@: %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "SideInstaller non può scaricare quel link. Incolla l'indirizzo https:// completo da cui si scarica l'.ipa.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "Quel link non ha restituito un IPA. Deve scaricare il file direttamente: una pagina che si limita a linkare l'.ipa, o che prima chiede di accedere, qui arriva come pagina web.",
    "Couldn't download that link: %@": "Impossibile scaricare quel link: %@",
    "there's nothing to download for a custom IPA — import one first":
        "non c'è nulla da scaricare per un IPA personalizzato: importalo prima",
    "your app": "la tua app",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple non rilascia un certificato di firma per questo Apple ID: segnala che ne esiste già uno, o che una richiesta è ancora in sospeso (errore 7460). SideInstaller non è riuscito a riutilizzare il certificato già presente, quindi si è fermato invece di sostituirlo. Vedi i passaggi qui sopra.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Non è stato possibile registrare questo iPhone%@ nel team di sviluppo del tuo Apple ID, quindi Apple non rilascerà un profilo di provisioning. %@ — vedi i passaggi qui sopra.",
    "Connect to Wi-Fi": "Connettiti al Wi-Fi",
    "Open Settings › Wi-Fi and join a network.": "Apri Impostazioni › Wi-Fi e collegati a una rete.",
    "Then come back here — this continues automatically.":
        "Poi torna qui: il processo va avanti da solo.",
    "Tap Connect so the toggle turns on.": "Tocca Connect per far scattare l'interruttore.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Lascia il Wi-Fi attivo e torna qui: il processo va avanti da solo.",
    "Get LocalDevVPN": "Scarica LocalDevVPN",
    "Import an .ipa first": "Importa prima un .ipa",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Tocca “Importa .ipa” qui sopra e scegli il file: può trovarsi ovunque arrivi l'app File, iCloud Drive o una chiavetta USB compresi.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "Oppure incolla un link di download diretto sotto quel pulsante: SideInstaller scarica l'.ipa da sé.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "Oppure apri l'app File, tieni premuto l'.ipa, tocca Condividi e scegli SideInstaller: così il file arriva senza passare dal selettore.",
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
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "Usa “Revoca e riprova” qui sopra, oppure apri Certificati nella scheda Strumenti, tocca “Carica i certificati” e revocalo da lì.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "La revoca è definitiva: tutte le app già firmate con quel certificato smettono di aprirsi, su qualsiasi dispositivo.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "In alternativa, accedi qui sopra con un altro Apple ID (o uno di riserva) e tocca di nuovo Installa.",

    // MARK: - Guide cards

    // Guide: import a pairing file

    "Import a pairing file": "Importa un file di abbinamento",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@ è la prima versione in cui un iPhone può abbinarsi da solo. Su questo il file di abbinamento va creato su un computer.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "Su un Mac, un PC Windows o Linux, collega questo iPhone, autorizza il computer ed esegui jitterbugpair (oppure “pymobiledevice3 lockdown pair”).",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "Invia il file che ottieni — un .mobiledevicepairing o .plist — a questo iPhone, con AirDrop, iCloud Drive o un cavo.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "Torna qui, tocca “Importa il file di abbinamento” e scegli il file. Da lì in poi funziona tutto come su iOS %@.",
    "Get jitterbugpair": "Scarica jitterbugpair",

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

    // MARK: - About

    "About": "Info",
    "Version %@ (%@)": "Versione %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller installa SideStore e LiveContainer direttamente sul tuo iPhone, senza bisogno di un PC.",
    "Everything runs on the device: your Apple ID signs the apps locally and is never sent anywhere, and there's no server, no account and no analytics behind any of it.":
        "Funziona tutto sul dispositivo: il tuo Apple ID firma le app in locale e non viene mai inviato da nessuna parte, e dietro non ci sono server, account o statistiche.",

    "Links": "Link",
    "Source code": "Codice sorgente",
    "Read it, audit it or open a pull request on GitHub.":
        "Leggilo, verificalo o apri una pull request su GitHub.",
    "Get help, report bugs and follow what's being worked on.":
        "Chiedi aiuto, segnala bug e segui gli sviluppi.",
    "Support the project": "Sostieni il progetto",
    "SideInstaller is free. Ko-fi is there if you'd like to chip in anyway.":
        "SideInstaller è gratuito. Ko-fi c’è se vuoi contribuire lo stesso.",

    "Special thanks": "Ringraziamenti speciali",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "Per idevice, la libreria con cui SideInstaller comunica con il tuo iPhone. Senza, niente di tutto questo esisterebbe.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Per il supporto e per aver individuato i bug poi corretti.",

    "Built with": "Realizzato con",
    "The open-source work this app is built on:":
        "Il lavoro open source su cui questa app si appoggia:",
    "Pairing, the tunnel and the install itself — by jkcoxson, MIT.":
        "Associazione, tunnel e installazione vera e propria — di jkcoxson, MIT.",
    "Apple ID sign-in, certificates and on-device signing — by nab138, MIT.":
        "Accesso con Apple ID, certificati e firma sul dispositivo — di nab138, MIT.",
    "The sideloading app this installs for you.":
        "L’app di sideloading che questa installa per te.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Esegue le app sideloadate senza consumare uno slot per ognuna.",
    "The developer disk image location spoofing mounts — mirrored by doronz88.":
        "La developer disk image montata dalla simulazione della posizione — mirror di doronz88.",
    "Plus the Rust crates tokio, serde, plist, base64 and tracing.":
        "Più i crate Rust tokio, serde, plist, base64 e tracing.",

    "Where to get it": "Dove scaricarlo",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "Solo le build sulla pagina di installazione e sul repository ufficiali sono mie. Chiunque può forkare il codice, aggiungere un ladro di credenziali e distribuirlo con lo stesso nome e la stessa icona: non affidare il tuo Apple ID a una copia presa altrove.",
    "Install page": "Pagina di installazione",
    "Terms": "Termini",
]
