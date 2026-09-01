import Foundation

/// Portuguese copy, keyed by the English source string passed to `L(_:)`. A
/// missing key renders as that English. `%@` and `%d` placeholders must survive
/// translation, and product or third-party UI names stay in English.
///
/// Written in Brazilian Portuguese: iOS's own labels use the pt-BR terms
/// (Ajustes, Arquivos, Tela de Início), so the paths in this copy match what a
/// reader actually sees on the device.

let portugueseStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "Cancelar",
    "Copy": "Copiar",
    "Email": "E-mail",
    "Password": "Senha",
    "Install": "Instalar",
    "Installing": "Instalando",
    "Installed": "Instalado",
    "Something went wrong": "Algo deu errado",
    "an app by Frizzle": "um app de Frizzle",
    "device": "dispositivo",

    // MARK: - Welcome

    "I have accepted the": "Eu aceito os",
    "Start": "Começar",

    "You'll need a pairing file": "Você vai precisar de um arquivo de pareamento",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "Este iPhone tem o iOS %@. Só o iOS %@ consegue parear consigo mesmo, então você vai precisar criar um arquivo de pareamento num computador — com o jitterbugpair ou o pymobiledevice3 — e importá-lo no app. O SideInstaller te guia pelo processo.",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "Entre com seu Apple ID",
    "Don't worry, these are stored locally": "Fique tranquilo: isso fica guardado só neste iPhone",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "Guardado no chaveiro deste iPhone e enviado apenas à Apple no momento de entrar.",
    "Continue": "Continuar",
    "Set this up later": "Configurar depois",
    "Add Apple ID": "Adicionar Apple ID",
    "Edit Apple ID": "Editar Apple ID",
    "Save": "Salvar",
    "Enter the password again to save this Apple ID.":
        "Digite a senha novamente para salvar este Apple ID.",
    "Account": "Conta",
    "In use": "Em uso",
    "Edit": "Editar",
    "Remove": "Remover",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "Nenhum Apple ID salvo ainda. Adicione um e o SideInstaller vai usá-lo sempre que precisar entrar.",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "Guardado no chaveiro deste iPhone e enviado apenas à Apple no momento de entrar. Deslize uma linha para editar a senha ou removê-la.",
    "Remove this Apple ID?": "Remover este Apple ID?",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "“%@” e a senha salva serão apagados deste iPhone. Nada muda na sua conta Apple.",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "O chaveiro deste iPhone recusou guardar a senha (erro %d), então ela fica na memória só até o SideInstaller ser encerrado.",
    "No Apple ID saved. Add one in Settings › Account.":
        "Nenhum Apple ID salvo. Adicione um em Ajustes › Conta.",

    "Add your Apple ID": "Adicione seu Apple ID",
    "Open Settings with the gear at the top right.":
        "Abra os ajustes na engrenagem no canto superior direito.",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "Em Conta, toque em “Adicionar Apple ID” e digite seu e-mail e sua senha.",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "Ferramentas",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "Pareamento",
    "Certificates": "Certificados",
    "Two-Factor Code": "Código de dois fatores",
    "6-digit code": "Código de 6 dígitos",
    "Submit": "Enviar",
    "Enter the code Apple just sent to your trusted device.":
        "Digite o código que a Apple acabou de enviar ao seu dispositivo confiável.",

    // MARK: - Install tab

    "Tunnel connected": "Túnel conectado",
    "Tunnel off": "Túnel desligado",
    "Update available": "Atualização disponível",
    "SideInstaller %@ is available — you're on %@.":
        "O SideInstaller %@ está disponível — você está no %@.",
    "Get the latest version": "Baixar a versão mais recente",
    "Release": "Versão",
    "Reinstall": "Reinstalar",
    "Install %@": "Instalar %@",
    "Custom .ipa": ".ipa personalizado",
    "Import .ipa": "Importar .ipa",
    "Importing…": "Importando…",
    "Replace": "Substituir",
    "or": "ou",
    "Paste a download link": "Cole um link de download",
    "Downloading… %d%%": "Baixando… %d%%",
    "iOS %@ required": "É necessário o iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Este iPhone tem o iOS %@, e nessa versão o SideInstaller não consegue instalar nada. Atualize para o iOS %@ ou mais recente em Ajustes › Geral › Atualização de Software.",
    "Wi-Fi required": "É necessário Wi-Fi",
    "Pairing code": "Código de pareamento",
    "Type this into the prompt in Settings.":
        "Digite este código no aviso que aparece nos Ajustes.",
    "Install stopped": "Instalação interrompida",
    "%@ is installed. Finish the trust step above to open it.":
        "O %@ está instalado. Conclua a etapa de confiança acima para abri-lo.",
    "Action needed": "Ação necessária",
    "Step %@ of %@": "Etapa %@ de %@",
    "Show all steps": "Mostrar todas as etapas",
    "Show fewer steps": "Mostrar menos etapas",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "É necessário o LocalDevVPN",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "Instale o LocalDevVPN e conecte-o. A instalação passa pelo túnel dele.",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "Conecte o LocalDevVPN para buscar e instalar. A gravação passa pelo túnel dele.",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "Conecte o LocalDevVPN. A simulação passa pelo túnel dele, como todo o resto aqui.",
    "LocalDevVPN isn't connected. Connect it, then try again.":
        "O LocalDevVPN não está conectado. Conecte-o e tente de novo.",
    "Connect LocalDevVPN": "Conectar o LocalDevVPN",
    "Install LocalDevVPN from the App Store and open it.":
        "Instale o LocalDevVPN pela App Store e abra-o.",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "Se o GitHub estiver bloqueado onde você está, use uma VPN que também encaminhe seu tráfego: o iOS mantém uma VPN por vez, então um túnel apenas local não deixa nenhum caminho para baixar o SideStore.",

    // MARK: - Install steps

    "Connect the VPN": "Conectar a VPN",
    "Get pairing file": "Obter o arquivo de pareamento",
    "Open the device link": "Abrir a conexão com o dispositivo",
    "Sign in to Apple ID": "Entrar no Apple ID",
    "Download %@": "Baixar o %@",
    "Use your imported IPA": "Usar o IPA importado",
    "Sign the app": "Assinar o app",
    "Finish setup": "Concluir a configuração",

    // MARK: - Pairing tab

    "Pairing file ready": "Arquivo de pareamento pronto",
    "No pairing file": "Sem arquivo de pareamento",
    "Pairing file": "Arquivo de pareamento",
    "Pairing…": "Pareando…",
    "Regenerate": "Gerar de novo",
    "Generate pairing file": "Gerar arquivo de pareamento",
    "Export pairing file": "Exportar arquivo de pareamento",
    "Pair in Settings": "Parear nos Ajustes",
    "Install into an app": "Instalar em um app",
    "Scanning": "Procurando",
    "Rescan apps": "Procurar apps de novo",
    "Scan installed apps": "Procurar apps instalados",
    "%d supported app installed": "%d app compatível instalado",
    "%d supported apps installed": "%d apps compatíveis instalados",
    "No supported apps found": "Nenhum app compatível encontrado",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "Instale antes um app como SideStore, StikDebug ou Feather e procure de novo.",
    "Install pairing": "Instalar pareamento",
    "Pairing file ready. You can export it or install it into an app below.":
        "Arquivo de pareamento pronto. Você pode exportá-lo ou instalá-lo em um app abaixo.",
    "Pairing file installed into %@.": "Arquivo de pareamento instalado no %@.",

    "Import pairing file": "Importar arquivo de pareamento",
    "How do I make one?": "Como faço um?",
    "imported pairing file": "arquivo de pareamento importado",
    "No pairing file yet — tap “Import pairing file” first.":
        "Ainda não há arquivo de pareamento — toque em “Importar arquivo de pareamento” primeiro.",
    "Pairing file missing — import it first.":
        "Arquivo de pareamento ausente — importe-o primeiro.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ não é um arquivo de pareamento. Escolha o arquivo que seu computador criou — um .mobiledevicepairing ou .plist com o registro de pareamento deste iPhone.",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "O iOS %@ não consegue criar o próprio arquivo de pareamento — isso exige o iOS %@. Importe um feito num computador em “Arquivo de pareamento” e tente de novo.",

    // MARK: - Pairing service status

    "not paired": "não pareado",
    "connected": "conectado",
    "requesting Local Network…": "solicitando acesso à rede local…",
    "Local Network denied": "acesso à rede local negado",
    "waiting for device…": "aguardando o dispositivo…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "anunciando — abra Ajustes › Privacidade e Segurança › Modo de Desenvolvedor",
    "enter PIN %@ in Settings": "digite o PIN %@ nos Ajustes",
    "paired: %@ (%dB)": "pareado: %@ (%d B)",
    "failed: empty pairing file": "falhou: arquivo de pareamento vazio",
    "failed: %@": "falhou: %@",
    "Pairing is already in progress.": "Já há um pareamento em andamento.",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "A permissão de rede local está desativada. Ative-a em Ajustes › SideInstaller › Rede Local e tente de novo.",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "O pareamento gerou um arquivo vazio. Confirme que você aprovou a solicitação de pareamento e tente de novo.",

    // MARK: - Certificates tab

    "Revoke this certificate?": "Revogar este certificado?",
    "Revoke": "Revogar",
    "Revoking": "Revogando",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "“%@” será revogado. Os apps já assinados com ele vão parar de abrir em todos os dispositivos. Isso não pode ser desfeito.",
    "Refreshing": "Atualizando",
    "Signing in": "Entrando",
    "Refresh": "Atualizar",
    "Load certificates": "Carregar certificados",
    "%d certificate(s)": "%d certificado(s)",
    "No certificates": "Nenhum certificado",
    "This Apple ID has no development certificates to revoke.":
        "Este Apple ID não tem certificados de desenvolvimento para revogar.",
    "Expired": "Expirado",
    "Expires %@": "Expira em %@",
    "Unnamed certificate": "Certificado sem nome",
    "This certificate has no serial number, so it can't be revoked.":
        "Este certificado não tem número de série, então não pode ser revogado.",

    // MARK: - Location tab

    "Location spoofing": "Simulação de localização",
    "Not simulating": "Sem simulação",
    "Simulated": "Simulada",
    "Pick a place": "Escolha um lugar",
    "Search for a place": "Buscar um lugar",
    "Nothing found for “%@”.": "Nada encontrado para “%@”.",
    "Set location": "Definir localização",
    "Setting": "Definindo",
    "Reset to real location": "Voltar à localização real",
    "Location set to %@.": "Localização definida para %@.",
    "Location reset. The device is using its own again.":
        "Localização restaurada. O dispositivo voltou a usar a própria.",
    "That isn't a valid coordinate.": "Isso não é uma coordenada válida.",
    "Location session closed — set it up again.":
        "A sessão de localização foi encerrada — configure-a de novo.",
    "Downloading %@ failed (HTTP %d).": "Falha ao baixar %@ (HTTP %d).",
    "Couldn't build the download URL for %@.":
        "Não foi possível montar o endereço de download de %@.",

    // MARK: - Entitlements tab

    "Entitlements": "Entitlements",
    "Load apps": "Carregar apps",
    "%d App ID": "%d App ID",
    "%d App IDs": "%d App IDs",
    "No App IDs": "Nenhum App ID",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "Este Apple ID ainda não registrou nenhum app. Instale algo com o SideInstaller primeiro e volte aqui.",
    "Memory and performance": "Memória e desempenho",
    "Other free capabilities": "Outros recursos gratuitos",
    "Beta": "Beta",
    "Recommended": "Recomendado",
    "Select all": "Selecionar tudo",
    "None": "Nenhum",
    "Enable %d selected": "Ativar %d selecionados",
    "Asking Apple": "Consultando a Apple",
    "%d of %d enabled": "%d de %d ativados",
    "Install the app again for these to take effect.":
        "Instale o app de novo para que isso passe a valer.",

    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "Apps instalados por sideload",
    "Reading the device": "Lendo o dispositivo",
    "%d app": "%d app",
    "%d apps": "%d apps",
    "%d app needs refreshing": "%d app precisa ser renovado",
    "%d apps need refreshing": "%d apps precisam ser renovados",
    "No sideloaded apps": "Nenhum app por sideload",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Nada neste dispositivo foi instalado com um perfil de provisionamento. Apps da App Store não expiram, por isso não aparecem aqui.",
    "No matching profile": "Nenhum perfil correspondente",
    "Expires today": "Expira hoje",
    "Expires tomorrow": "Expira amanhã",
    "Expires in %d days — %@": "Expira em %d dias — %@",
    "Expired %@": "Expirou em %@",
    "Unused profiles": "Perfis sem uso",
    "Issued to App IDs no installed app is running on.":
        "Emitidos para App IDs que nenhum app instalado está usando.",
    "Older profiles": "Perfis mais antigos",
    "Bundle identifier": "Identificador do pacote",
    "App ID": "App ID",
    "Version": "Versão",
    "Profile name": "Nome do perfil",
    "Team": "Equipe",
    "Team ID": "ID da equipe",
    "Issued": "Emitido",
    "Profile UUID": "UUID do perfil",
    "Capabilities": "Recursos",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "App ID curinga — abrange qualquer identificador de pacote abaixo dele e não pode ter recursos específicos de um app.",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "O dispositivo não tem perfil de provisionamento para este App ID. O app pode já ter parado de abrir — instale-o de novo para resolver.",

    // MARK: - Side by Side tool

    "Side by Side": "Side by Side",
    "Pair with their iPhone": "Parear com o iPhone dele",
    "Sign in to their Apple ID": "Entrar no Apple ID dele",
    "Download SideInstaller": "Baixar o SideInstaller",
    "Install on their iPhone": "Instalar no iPhone dele",
    "Enter the other iPhone's IP address. It's in Settings › Wi-Fi, next to the network it's on.":
        "Digite o endereço IP do outro iPhone. Ele está em Ajustes › Wi-Fi, ao lado da rede em que o aparelho está.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” não é um endereço IPv4. Ele deve ser parecido com 192.168.1.42.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ é um endereço que este iPhone já tem. O Side by Side instala no iPhone de outra pessoa — use o dela. Para instalar neste aqui, use a aba Instalar.",
    "Enter the Apple ID to sign with, and its password.":
        "Digite o Apple ID que vai assinar o app e a senha dele.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "O Wi-Fi está desligado. Os dois iPhones precisam estar na mesma rede Wi-Fi para isso funcionar.",
    "The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute.":
        "O download da versão não era um IPA. O GitHub pode estar devolvendo uma página de erro — tente de novo daqui a pouco.",
    "Couldn't download the latest SideInstaller release: %@":
        "Não foi possível baixar a versão mais recente do SideInstaller: %@",
    "No SideInstaller IPA downloaded.": "Nenhum IPA do SideInstaller foi baixado.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise.":
        "A Apple não emite um certificado de assinatura para este Apple ID: ela informa que já existe um (erro 7460). É preciso revogar um antes — pela ferramenta Certificados, se este for o Apple ID salvo em Ajustes › Conta, ou em developer.apple.com conectado com ele, caso contrário.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "A Apple não registrou o iPhone dele na equipe de desenvolvimento deste Apple ID, então não vai emitir um perfil de provisionamento. %@",
    "No pair record for their iPhone.": "Nenhum registro de pareamento para o iPhone dele.",
    "The link to their iPhone dropped — start again.":
        "A conexão com o iPhone dele caiu — comece de novo.",
    "Set up someone else's iPhone": "Configure o iPhone de outra pessoa",
    "Same Wi-Fi network": "Mesma rede Wi-Fi",
    "Their iPhone": "O iPhone dele",
    "IP address (e.g. 192.168.1.42)": "Endereço IP (ex.: 192.168.1.42)",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "No iPhone dele: Ajustes › Wi-Fi › ⓘ ao lado da rede e depois “Endereço IP”.",
    "This iPhone is %@, so theirs will look similar.":
        "Este iPhone é %@, então o dele será parecido.",
    "Apple ID to sign with": "Apple ID que vai assinar",
    "Tip: Use the iPhone/iPad owner's Apple account credentials":
        "Dica: use as credenciais da conta Apple do dono do iPhone/iPad",
    "Use my saved Apple ID instead": "Usar o meu Apple ID salvo",
    "Steps": "Etapas",
    "Waiting for them to tap Trust…": "Aguardando ele tocar em Confiar…",
    "%d%% downloaded": "%d%% baixado",
    "%d%% uploaded": "%d%% enviado",
    "Start the install": "Iniciar a instalação",
    "Install again": "Instalar de novo",
    "Clear their details": "Limpar os dados dele",
    "Last step: they trust %@": "Última etapa: ele confia no %@",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "No iPhone dele: Ajustes › Geral › VPN e Gerenciamento de Dispositivo.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "Toque no Apple ID em “App do Desenvolvedor” e depois em Confiar.",
    "Open it from their Home Screen — they're set up.":
        "Abra pela Tela de Início dele — está tudo pronto.",

    // MARK: - Settings

    "Settings": "Ajustes",
    "Done": "OK",
    "Language": "Idioma",
    "App language": "Idioma do app",
    "Auto": "Automático",
    "Downloaded IPAs": "IPAs baixados",
    "%@ used": "%@ em uso",
    "imported": "importado",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "Nenhum IPA baixado. Os que você instala pela aba Instalar ficam guardados aqui.",
    "Downloaded %@": "Baixado em %@",
    "Added %@": "Adicionado em %@",
    "Delete this download?": "Apagar este download?",
    "Delete": "Apagar",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "“%@” (%@) será removido. Você pode baixá-lo de novo quando quiser pela aba Instalar.",
    "Couldn't delete %@: %@": "Não foi possível apagar %@: %@",
    "Server": "Servidor",
    "Custom…": "Personalizado…",
    "Server URL": "URL do servidor",
    "Anisette Server": "Servidor Anisette",
    "Device IP": "IP do dispositivo",
    "Advanced": "Avançado",
    "Clear": "Limpar",
    "Activity Log (%d)": "Registro de atividade (%d)",

    // MARK: - Release channels & downloads

    "Stable": "Estável",
    "Nightly": "Nightly",
    "couldn't find the IPA in the %@ %@ release":
        "não foi possível encontrar o IPA na versão %@ %@",
    "%@ has no %@ release right now": "o %@ não tem nenhuma versão %@ no momento",
    "bad asset URL": "endereço de arquivo inválido",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "O GitHub está limitando as requisições desta rede — ela não está bloqueada, e o limite se resolve sozinho. Tente de novo %@.",
    "GitHub answered HTTP %d%@": "O GitHub respondeu HTTP %d%@",
    "couldn't reach GitHub: %@": "não foi possível acessar o GitHub: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "A resposta do GitHub não trazia informações de versão (%@) — algo nesta rede pode tê-la substituído.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "o que foi baixado como %@ não é um IPA — algo nesta rede devolveu uma página no lugar, ou a transferência parou no meio.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "esse link respondeu HTTP %d — ele não é um download direto, ou exige que você entre numa conta.",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "A verificação em duas etapas foi cancelada.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID ou senha incorretos. Confira o e-mail e a senha da sua conta Apple e tente de novo.",
    "Apple ID sign-in failed on %@. Last error: %@":
        "Falha ao entrar no Apple ID em %@. Último erro: %@",
    "the anisette server": "o servidor anisette",
    "all %d anisette servers": "todos os %d servidores anisette",
    "Not signed in.": "Não conectado.",
    "No SideStore IPA downloaded.": "Nenhum IPA do SideStore foi baixado.",
    "Signing failed: %@": "Falha ao assinar: %@",
    "No signed bundle to install.": "Nenhum pacote assinado para instalar.",
    "Device link dropped — reconnect.": "A conexão com o dispositivo caiu — reconecte.",
    "Pairing didn't finish — no pairing file yet.":
        "O pareamento não foi concluído — ainda não há arquivo de pareamento.",
    "Pairing file missing — pairing must run first.":
        "Arquivo de pareamento ausente — o pareamento precisa ser feito antes.",
    "Pairing file missing — generate it first.": "Arquivo de pareamento ausente — gere-o primeiro.",
    "No pairing file yet — tap “Generate pairing file” first.":
        "Ainda não há arquivo de pareamento — toque em “Gerar arquivo de pareamento” primeiro.",
    "%@ isn't installed yet — install must run first.":
        "O %@ ainda não está instalado — a instalação precisa ser feita antes.",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ não é um IPA válido — o download provavelmente devolveu uma página de erro, ou a cópia parou no meio. Substitua-o e toque em Instalar de novo.",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ não é um IPA. Escolha o próprio arquivo .ipa — se ele parece correto, o download pode ter salvado uma página de erro no lugar, ou parado no meio.",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "Nenhum IPA importado ainda. Toque em “Importar .ipa” e escolha um.",
    "Couldn't import %@: %@": "Não foi possível importar %@: %@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "Esse não é um link que o SideInstaller consiga baixar. Cole o endereço https:// completo de onde o .ipa é baixado.",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "Esse link não devolveu um IPA. Ele precisa baixar o próprio arquivo — uma página que só aponta para o .ipa, ou que pede login antes, chega aqui como página da web.",
    "Couldn't download that link: %@": "Não foi possível baixar esse link: %@",
    "there's nothing to download for a custom IPA — import one first":
        "não há o que baixar para um IPA personalizado — importe um primeiro",
    "your app": "seu app",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "A Apple não emite um certificado de assinatura para este Apple ID: ela informa que já existe um, ou que um pedido continua pendente (erro 7460). O SideInstaller não conseguiu reaproveitar o certificado que já está lá, então parou em vez de substituí-lo. Veja as etapas acima.",
    " (UDID %@)": " (UDID %@)",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "Não foi possível registrar este iPhone%@ na equipe de desenvolvimento do seu Apple ID, então a Apple não vai emitir um perfil de provisionamento. %@ — veja as etapas acima.",
    "Connect to Wi-Fi": "Conecte-se ao Wi-Fi",
    "Open Settings › Wi-Fi and join a network.": "Abra Ajustes › Wi-Fi e entre numa rede.",
    "Then come back here — this continues automatically.":
        "Depois volte para cá — isto continua automaticamente.",
    "Tap Connect so the toggle turns on.": "Toque em Connect para a chave ligar.",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Mantenha o Wi-Fi ligado e volte para cá — isto continua automaticamente.",
    "Get LocalDevVPN": "Baixar o LocalDevVPN",
    "Import an .ipa first": "Importe um .ipa primeiro",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "Toque em “Importar .ipa” acima e escolha o arquivo — ele pode estar em qualquer lugar que o app Arquivos alcance, inclusive no iCloud Drive ou num pen drive.",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "Ou cole um link de download direto abaixo desse botão, e o SideInstaller busca o .ipa sozinho.",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "Ou abra o app Arquivos, mantenha o .ipa pressionado, toque em Compartilhar e escolha o SideInstaller — assim o arquivo é entregue sem passar pelo seletor.",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "Ou copie-o para Arquivos › No meu iPhone › SideInstaller, onde o SideInstaller também o encontra.",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "É por aqui que se resolve onde o GitHub está bloqueado: baixe o IPA em qualquer aparelho, traga-o para cá e instale-o aqui.",
    "Pair this iPhone in Settings": "Pareie este iPhone nos Ajustes",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Abra o app Ajustes e vá em Privacidade e Segurança › Modo de Desenvolvedor.",
    "Tap “Pair with SideInstaller”.": "Toque em “Parear com o SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.":
        "Digite o código do seu iPhone, se ele pedir.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Volte ao SideInstaller, veja o código que ele mostra e digite esse mesmo código no aviso que aparece nos Ajustes.",
    "A signing certificate already exists": "Já existe um certificado de assinatura",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "A Apple devolveu o erro 7460: este Apple ID já tem um certificado de desenvolvimento iOS, ou um pedido continua pendente.",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "O SideInstaller não conseguiu reaproveitá-lo. Isso acontece quando o certificado foi emitido em outro lugar — AltStore, SideStore, Sideloadly ou Xcode em outro aparelho — e a chave privada de que ele precisa não está neste iPhone.",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "Use “Revogar e tentar de novo” acima, ou abra Certificados na aba Ferramentas, toque em “Carregar certificados” e revogue por lá.",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "Revogar é definitivo: todo app já assinado com esse certificado para de abrir, em todos os aparelhos.",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "Como alternativa, entre com outro Apple ID (ou um reserva) acima e toque em Instalar de novo.",

    // MARK: - Guide cards

    "Import a pairing file": "Importe um arquivo de pareamento",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "O iOS %@ é a primeira versão em que um iPhone consegue parear consigo mesmo. Neste aqui, o arquivo de pareamento precisa ser feito num computador.",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "Num Mac, PC com Windows ou máquina Linux, conecte este iPhone, confie no computador e rode o jitterbugpair (ou “pymobiledevice3 lockdown pair”).",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "Envie o arquivo que ele gerar — um .mobiledevicepairing ou .plist — para este iPhone, por AirDrop, iCloud Drive ou cabo.",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "Volte para cá, toque em “Importar arquivo de pareamento” e escolha-o. Daí em diante tudo funciona como no iOS %@.",
    "Get jitterbugpair": "Baixar o jitterbugpair",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "Já existe um certificado",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "A Apple não emite um segundo certificado de assinatura para este Apple ID. Revogar o que já existe deixa a instalação seguir — mas isso não pode ser desfeito.",
    "Loading certificates": "Carregando certificados",
    "Revoke and retry": "Revogar e tentar de novo",
    "Which certificate should be revoked?": "Qual certificado deve ser revogado?",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "A Apple informa que há um certificado neste Apple ID, mas nenhum veio na lista. Pode ser um pedido ainda pendente — espere alguns minutos e toque em Instalar de novo.",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "Todo app já assinado com o certificado que você escolher vai parar de abrir, em todos os aparelhos — inclusive apps instalados pelo AltStore, pelo SideStore ou por um computador. Isso não pode ser desfeito. A instalação é repetida logo em seguida.",
    " (expired)": " (expirado)",

    "Couldn't register this device": "Não foi possível registrar este dispositivo",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "Seu Apple ID atingiu o limite de dispositivos registrados. Contas gratuitas só podem registrar alguns aparelhos por ano e não conseguem remover os antigos até o ano virar.",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "Solução mais simples: coloque outro Apple ID (ou um reserva) nos campos acima e toque em Instalar de novo.",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "O SideInstaller não conseguiu adicionar este iPhone à equipe de desenvolvimento do seu Apple ID automaticamente. Tocar em Instalar de novo costuma funcionar — o serviço de desenvolvedor da Apple fica indisponível de vez em quando.",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "Se continuar falhando, adicione o dispositivo manualmente. O UDID dele é:",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "Cole isso no formulário “Register a Device” do portal Apple Developer (isso exige uma conta paga do Apple Developer) e toque em Instalar de novo.",
    "Open device list": "Abrir a lista de dispositivos",

    "Last step: trust %@": "Última etapa: confie no %@",
    "Open Settings › General › VPN & Device Management.":
        "Abra Ajustes › Geral › VPN e Gerenciamento de Dispositivo.",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "Toque no seu Apple ID em “App do Desenvolvedor” e depois em Confiar.",
    "Open %@ from your Home Screen — you're done.":
        "Abra o %@ pela Tela de Início — está tudo pronto.",

    "Import the certificate into LiveContainer": "Importe o certificado no LiveContainer",
    "Open LiveContainer from your Home Screen.": "Abra o LiveContainer pela Tela de Início.",
    "Tap the Settings tab.": "Toque na aba Settings.",
    "Tap “Import Certificate From SideStore”.": "Toque em “Import Certificate From SideStore”.",
    "Wrong device IP": "IP do dispositivo incorreto",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "O endereço em Ajustes › Avançado › IP do dispositivo é um que este iPhone já tem, então não há nada do outro lado para se conectar.",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "Volte para 10.7.0.1, o padrão. No LocalDevVPN esse é o valor em Settings › Device IP — não o endereço da tela principal, que é a ponta do próprio túnel.",
    "If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one.":
        "Se você mudou os endereços do LocalDevVPN, copie o Device IP dele para cá — inclusive o /32, se aparecer um.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Parear este iPhone depende disso: o SideInstaller se anuncia na rede local para os Ajustes o encontrarem.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Conecte-se a uma rede Wi-Fi. Parear este iPhone depende disso — o SideInstaller precisa ser encontrável na rede local.",

    // MARK: - About

    "About": "Sobre",
    "Version %@ (%@)": "Versão %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "O SideInstaller instala o SideStore e o LiveContainer direto no seu iPhone, sem precisar de computador.",

    "Links": "Links",
    "Source code": "Código-fonte",
    "Support the project": "Apoie o projeto",

    "Special thanks": "Agradecimentos especiais",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "Pelo idevice, a biblioteca com que o SideInstaller conversa com o seu iPhone. Nada disso existe sem ela.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Pelo apoio e por apontar os erros que foram corrigidos por causa dele.",
    "For the Japanese translation.": "Pela tradução para o japonês.",

    "Built with": "Feito com",
    "The open source work this app is built on:":
        "O trabalho de código aberto em que este app se apoia:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "O pareamento, o túnel e a própria instalação. De jkcoxson, MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Login no Apple ID, certificados e assinatura no próprio aparelho. De nab138, MIT.",
    "The sideloading app this installs for you.": "O app de sideload que isto instala para você.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Roda apps de sideload sem gastar um espaço de app com cada um.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "A imagem de disco de desenvolvedor que a simulação de localização monta. Espelhada por doronz88.",

    "Where to get it": "Onde baixar",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "Só as versões da página de instalação e do repositório oficiais são minhas. Qualquer um pode bifurcar o código, acrescentar um ladrão de credenciais e publicá-lo com o mesmo nome e ícone — então não confie seu Apple ID a uma cópia de outro lugar.",
    "Install page": "Página de instalação",
    "Terms": "Termos",
]
