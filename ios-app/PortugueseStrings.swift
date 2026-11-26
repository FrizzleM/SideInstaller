import Foundation

/// Brazilian Portuguese translations, keyed by the English string passed to
/// `L(_:)`. Missing keys fall back to English. Keep `%@`/`%d` placeholders, and
/// leave product and third-party UI names in English.
///
/// Uses the pt-BR terms iOS shows (Ajustes, Arquivos, Tela de Início).

let portugueseStrings: [String: String] = [

    // MARK: - Shared

    "Expiry date": "Validade",
    "Signed date": "Data da assinatura",
    "Bundle ID": "Bundle ID",
    "Not enough free space on this iPhone to download this IPA — it needs %@, but only %@ is free. Free some space and try again.":
        "Não há espaço livre suficiente neste iPhone para baixar este IPA: são necessários %@, mas só restam %@ livres. Libere espaço e tente novamente.",
    "Free space: %@": "Espaço livre: %@",
    "Apple ID":
        "Apple ID",
    "Cancel": "Cancelar",
    "Copy": "Copiar",
    "Copy logs": "Copiar registros",
    "Email": "E-mail",
    "No unsigned IPA in the library.":
        "Nenhum IPA sem assinatura na biblioteca.",
    "Once the install starts, tap the Install button at the bottom to see progress.":
        "Depois que a instalação começar, toque no botão Instalar na parte inferior para ver o progresso.",
    "Password": "Senha",
    "Install": "Instalar",
    // U-UI (0.9.102): new tab bar / source + file list redesign.
    "Apps": "Apps",
    "Pick an IPA to install with your Apple ID.":
        "Escolha um IPA para instalar com seu ID Apple.",
    "Signing method":
        "Método de assinatura",
    "Sources": "Fontes",
    "AppStore": "AppStore",
    "企业证书":
        "Certificado empresarial",
    "用 Apple ID 安装":
        "Instalar com ID Apple",
    "软件源": "Fontes de software",
    "文件列表": "Lista de arquivos",
    "筛选": "Filtrar",
    "正在刷新数据中…": "Atualizando os dados…",
    "最后更新：%@": "Última atualização: %@",
    "应用文件夹库": "Biblioteca de pastas de apps",
    "应用 - %@": "App - %@",
    "No downloaded IPAs. Ones you install from a source or a file are cached here.": "Nenhum IPA baixado. Os instalados a partir de uma fonte ou arquivo ficam em cache aqui.",
    "%d 个 IPA · %@": "%d IPA · %@",
    "清空全部": "Apagar tudo",
    "清空全部 %d 个下载？": "Apagar os %d downloads?",
    "还没有文件。点上面「导入文件」放 IPA 进来，或在源页面下载后这里会出现。": "Ainda não há arquivos. Toque em «Importar arquivo» acima para adicionar um IPA, ou baixe um na página de fontes.",
    "文件库里还没有没签过的 IPA。去文件页导入一个，或者去设置里的企业证书页点「从文件导入」。": "Ainda não há IPA não assinado na biblioteca. Importe um na página Arquivos ou toque em «Importar arquivo» na página de certificados empresariais em Ajustes.",
    "先去设置里的企业证书页，把证书、描述文件和密码备齐。": "Primeiro, prepare o certificado, o perfil e a senha no grupo de certificados da página de certificados empresariais em Ajustes.",
    "还没有已签名的 IPA。用设置里企业证书页的「仅签名」签好就会存到这里，随时能装、能分享。": "Ainda não há IPA assinado. Assine um com «Somente assinar» na página de certificados empresariais em Ajustes: ele ficará aqui, pronto para instalar e compartilhar.",
    "Installing": "Instalando",
    "Installed": "Instalado",
    "Install history": "Histórico de instalações",
    "No installs yet.": "Nenhuma instalação ainda.",
    "Something went wrong": "Algo deu errado",
    "an app by Frizzle": "um app de Frizzle",
    "device": "dispositivo",

    // MARK: - Welcome

    "I have accepted the": "Eu aceito os",
    "Start": "Começar",

    "You'll need a pairing file": "Você vai precisar de um arquivo de pareamento",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "Este iPhone tem o iOS %@. Só o iOS %@ consegue parear consigo mesmo, então você vai precisar criar um arquivo de pareamento num computador — com o jitterbugpair ou o pymobiledevice3 — e importá-lo no app. O SideInstaller te guia pelo processo.",

    // iOS 27 runs on this iPhone: recommended at setup

    "Update to iOS %@": "Atualize para o iOS %@",
    "This iPhone can run iOS %@, where SideInstaller works without a computer: the iPhone pairs with itself, so there's no pairing file to make. Update in Settings › General › Software Update.":
        "Este iPhone pode rodar o iOS %@, em que o SideInstaller funciona sem computador: o iPhone pareia consigo mesmo, então não é preciso criar um arquivo de pareamento. Atualize em Ajustes › Geral › Atualização de Software.",
    "OK": "OK",

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
    "Enter the code Apple just sent to your trusted device.":
        "Digite o código que a Apple acabou de enviar ao seu dispositivo confiável.",
    "Enter the code Apple texted to %@.":
        "Digite o código que a Apple enviou por SMS para %@.",
    "Enter the code Apple texted to your phone.":
        "Digite o código que a Apple enviou por SMS para o seu telefone.",
    "Apple is calling %@. Enter the code you hear.":
        "A Apple está ligando para %@. Digite o código que você ouvir.",
    "Apple is calling your phone. Enter the code you hear.":
        "A Apple está ligando para o seu telefone. Digite o código que você ouvir.",
    "Choose how Apple should send your verification code.":
        "Escolha como a Apple deve enviar o seu código de verificação.",
    "Choose How to Get a Code":
        "Escolha como receber o código",
    "Verify":
        "Verificar",
    "Didn't get it?":
        "Não recebeu?",
    "Send a new code to my devices":
        "Enviar um novo código para meus dispositivos",
    "Text me a new code":
        "Enviar um novo código por SMS",
    "Call me again":
        "Ligar de novo",
    "Send a code to my Apple devices":
        "Enviar um código para meus dispositivos Apple",
    "Text %@":
        "SMS para %@",
    "Call %@":
        "Ligar para %@",
    "Checking the code…":
        "Verificando o código…",
    "Requesting a new code…":
        "Solicitando um novo código…",
    "Sending a code to your devices…":
        "Enviando um código para seus dispositivos…",
    "Texting a code to %@…":
        "Enviando um código por SMS para %@…",
    "Calling %@…":
        "Ligando para %@…",

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
    "SideInstaller recognizes this as %@ and sets it up just like its own download.":
        "O SideInstaller reconhece isto como %@ e o configura como se ele mesmo o tivesse baixado.",
    "Downloading… %d%%": "Baixando… %d%%",
    "Downloading": "Baixando",
    "Queued": "Na fila",
    "iOS %@ required": "É necessário o iOS %@",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "Este iPhone tem o iOS %@, e nessa versão o SideInstaller não consegue instalar nada. Atualize para o iOS %@ ou mais recente em Ajustes › Geral › Atualização de Software.",
    "Wi-Fi required": "É necessário Wi-Fi",
    "Pairing code": "Código de pareamento",
    "Type this into the prompt in Settings.":
        "Digite este código no aviso que aparece nos Ajustes.",
    "Install stopped": "Instalação interrompida",
    "Close": "Fechar",
    "Yes": "Sim",
    "No": "Não",
    "Closing this popup will end the process. Are you sure?":
        "Fechar este pop-up vai encerrar o processo. Tem certeza?",
    "Cancel the install?": "Cancelar a instalação?",
    "%@ is installed. Finish the trust step above to open it.":
        "O %@ está instalado. Conclua a etapa de confiança acima para abri-lo.",
    "%@ is installed. Finish the trust step below to open it.":
        "O %@ está instalado. Conclua a etapa de confiança abaixo para abri-lo.",
    "Success: last steps": "Pronto: últimas etapas",
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
    "No loopback VPN is connected, and automatic tunnel start is off. Turn on “Start LocalDevVPN when needed” in Settings, then tap Install again.": "Nenhuma VPN de loopback está conectada e o início automático do túnel está desligado. Ative “Iniciar o LocalDevVPN quando necessário” em Ajustes e toque em Instalar novamente.",
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
    "Use a custom .ipa instead": "Usar um .ipa personalizado",
    "Pick an .ipa to install.": "Escolha o .ipa a instalar.",
    "Signed with the Apple ID and installed as it is, without a pairing file.": "Assinado com o Apple ID e instalado como está, sem arquivo de pareamento.",
    "Open %@.": "Abra o app %@.",
    "Sign the app": "Assinar o app",
    "Finish setup": "Concluir a configuração",

    // MARK: - Pairing tab

    "Pairing file ready": "Arquivo de pareamento pronto",
    "No pairing file": "Sem arquivo de pareamento",
    "Pairing file": "Arquivo de pareamento",
    "Pairing file is being generated. Wait for it to finish, then try again.": "O arquivo de emparelhamento está sendo gerado. Aguarde a conclusão e tente novamente.",
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
    "Install pairing into all apps": "Instalar pareamento em todos os apps",
    "Installing into all apps": "Instalando em todos os apps",
    "Pairing file installed into all %d apps.": "Arquivo de pareamento instalado nos %d apps.",
    "Couldn't write into %@.": "Não foi possível gravar em %@.",
    "The %@ record isn't a plist dictionary.": "O registro %@ não é um dicionário plist.",

    "Import pairing file": "Importar arquivo de pareamento",
    "How do I make one?": "Como faço um?",
    "(Optional)": "(Opcional)",
    "imported pairing file": "arquivo de pareamento importado",
    "No pairing file yet — tap “Import pairing file” first.":
        "Ainda não há arquivo de pareamento — toque em “Importar arquivo de pareamento” primeiro.",
    "Pairing file missing — import it first.":
        "Arquivo de pareamento ausente — importe-o primeiro.",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ não é um arquivo de pareamento. Escolha o arquivo que seu computador criou — um .mobiledevicepairing ou .plist com o registro de pareamento deste iPhone.",
    "%@ isn't installed on this iPhone, so there's nowhere to import the certificate.":
        "%@ não está instalado neste iPhone, por isso não há onde importar o certificado.",
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
    "Apps signed with this certificate:\n%@": "Apps assinados com este certificado:\n%@",
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

    // Export: the certificate SideInstaller signs with, as a .p12
    "Import to %@": "Importar para %@",
    "Exporting": "Exportando",

    // MARK: - SideStore's certificate (sidestore://certificate)

    "Use SideStore's certificate": "Usar o certificado do SideStore",
    "Checking the certificate": "Verificando o certificado",
    "SideStore opens and sends back its certificate. SideInstaller then signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "O SideStore abre e devolve o certificado dele. Depois o SideInstaller também assina com ele, então com um Apple ID gratuito nenhum dos dois apps precisa revogar o do outro.",
    "Apple won't issue a second signing certificate for this Apple ID. If SideStore made the one it has, SideInstaller can sign with that one too, and nothing is revoked. Revoking it lets the install continue as well — but it can't be undone.":
        "A Apple não emite um segundo certificado de assinatura para este Apple ID. Se o que existe foi criado pelo SideStore, o SideInstaller também pode assinar com ele, sem revogar nada. Revogá-lo também deixa a instalação seguir — mas isso não pode ser desfeito.",
    "If SideStore made it, tap “Use SideStore's certificate” above: SideInstaller signs with that one too, and nothing is revoked.":
        "Se foi o SideStore que o criou, toque em “Usar o certificado do SideStore” acima: o SideInstaller também assina com ele, e nada é revogado.",
    "SideInstaller signs with “%@” from now on. Nothing was revoked, so the apps already signed with it keep working.":
        "A partir de agora o SideInstaller assina com “%@”. Nada foi revogado, então os apps já assinados com ele continuam funcionando.",
    "SideInstaller already signs with “%@”.": "O SideInstaller já assina com “%@”.",
    "That certificate isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID (SideStore may be signed in with a different one). Nothing was changed.":
        "Esse certificado não é deste Apple ID: ele foi revogado ou pertence a outro Apple ID (talvez o SideStore esteja conectado com outro). Nada foi alterado.",
    "Couldn't use that certificate: %@": "Não foi possível usar esse certificado: %@",
    "SideStore isn't installed on this iPhone, so there's no certificate to get from it.":
        "O SideStore não está instalado neste iPhone, então não há certificado para pegar dele.",
    "Inside LiveContainer, SideStore can't send its certificate back to SideInstaller, and LiveContainer doesn't hold one yet. In LiveContainer's Settings, tap “Import Certificate From SideStore” (sign in to SideStore first if it has no certificate), then try again here.":
        "Dentro do LiveContainer, o SideStore não consegue devolver o certificado dele ao SideInstaller, e o LiveContainer ainda não tem um. Nas Settings do LiveContainer, toque em “Import Certificate From SideStore” (entre no SideStore primeiro se ele não tiver certificado) e tente de novo aqui.",
    "The certificate LiveContainer holds for SideStore isn't one of this Apple ID's: it has been revoked, or it belongs to another Apple ID. Nothing was changed. If SideStore has made a new one since, tap “Refresh Certificate from SideStore” in LiveContainer's Settings, then try again here.":
        "O certificado que o LiveContainer guarda para o SideStore não é deste Apple ID: ele foi revogado ou pertence a outro Apple ID. Nada foi alterado. Se o SideStore criou um novo desde então, toque em “Refresh Certificate from SideStore” nas Settings do LiveContainer e tente de novo aqui.",
    "SideInstaller takes SideStore's certificate from LiveContainer and signs with it too, so on a free Apple ID neither app has to revoke the other's.":
        "O SideInstaller pega o certificado do SideStore no LiveContainer e também assina com ele, então com um Apple ID gratuito nenhum dos dois apps precisa revogar o do outro.",
    "Sign with this certificate?": "Assinar com este certificado?",
    "A link sent SideInstaller a signing certificate. Only use it if you asked for one: SideInstaller will sign apps with it from now on, in place of its own. It's used only if it's one of your Apple ID's certificates.":
        "Um link enviou ao SideInstaller um certificado de assinatura. Só use se você pediu um: a partir de agora o SideInstaller vai assinar os apps com ele, no lugar do próprio. Ele só é usado se for um dos certificados do seu Apple ID.",
    "Use it": "Usar",
    "That link was meant to carry a signing certificate, but what it holds can't be read.":
        "Esse link deveria trazer um certificado de assinatura, mas o conteúdo não pode ser lido.",

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
    "The download of %@ came back empty. Try again.": "O download de %@ veio vazio. Tente novamente.",
    "Couldn't build the download URL for %@.":
        "Não foi possível montar o endereço de download de %@.",
    "Couldn't build the certificate link.": "Não foi possível criar o link do certificado.",

    // Location › saved places and GPX routes.
    "Saved places": "Lugares salvos",
    "Save this place": "Salvar este lugar",
    "Name": "Nome",
    "Show on map": "Mostrar no mapa",
    "Tap Save under the map to keep the spot under the pin. Tapping a saved place sets it straight away.":
        "Toque em Salvar abaixo do mapa para guardar o ponto sob o alfinete. Ao tocar em um lugar salvo, ele é definido na hora.",
    "Play a GPX route": "Reproduzir uma rota GPX",
    "Import a .gpx file and the device moves along it at the speed you pick, then stays at its last point.":
        "Importe um arquivo .gpx e o dispositivo o percorre na velocidade que você escolher; no fim, fica no último ponto.",
    "Import GPX file": "Importar arquivo GPX",
    "Couldn't read %@ as a GPX file.": "Não foi possível ler %@ como arquivo GPX.",
    "%@ has no track, route or waypoints in it.": "%@ não tem trilhas, rotas nem waypoints.",
    "As recorded": "Como gravado",
    "Walk": "A pé",
    "Cycle": "De bicicleta",
    "Drive": "De carro",
    "Speed": "Velocidade",
    "Play route": "Reproduzir rota",
    "Playing route · %d%%": "Reproduzindo rota · %d%%",
    "Stop here": "Parar aqui",
    "%@ of %@": "%@ de %@",
    "Route finished. The device stays at its last point.":
        "Rota concluída. O dispositivo fica no último ponto.",
    "Route stopped. The device stays where it got to.":
        "Rota interrompida. O dispositivo fica onde chegou.",
    "Route playback stopped: %@": "A reprodução da rota parou: %@",
    // Location › planned routes (OpenStreetMap).
    "Add stop": "Adicionar parada",
    "Add as stop": "Adicionar como parada",
    "Plan a route": "Planejar uma rota",
    "Travel by": "Meio de transporte",
    "Goes along each street at its speed limit, from OpenStreetMap. A street without one mapped gets the usual limit for its kind of road.":
        "Percorre cada rua no limite de velocidade dela, segundo o OpenStreetMap. Uma rua sem limite mapeado recebe o limite habitual para o tipo de via.",
    "Rides streets and paths a bike can take, at a cycling pace.":
        "Percorre ruas e caminhos por onde passa uma bicicleta, em ritmo de ciclista.",
    "Walks streets and paths at a walking pace.": "Percorre ruas e caminhos em ritmo de caminhada.",
    "Start where the device is": "Começar onde o dispositivo está",
    "Move the map so the pin is on a place, then tap Add stop. Add as many as you like: the route goes to each in order.":
        "Mova o mapa para que o alfinete fique sobre um lugar e toque em Adicionar parada. Adicione quantas quiser: a rota passa por cada uma na ordem.",
    "The device's location": "Localização do dispositivo",
    "Stop %d": "Parada %d",
    "Clear stops": "Limpar paradas",
    "Move up": "Mover para cima",
    "Move down": "Mover para baixo",
    "Find route": "Encontrar rota",
    "Finding route": "Procurando rota",
    "Add one more stop to plan a route.": "Adicione mais uma parada para planejar uma rota.",
    "Routes from OpenStreetMap, © OpenStreetMap contributors":
        "Rotas do OpenStreetMap, © colaboradores do OpenStreetMap",
    "Speed limits are mapped for all of it.":
        "Os limites de velocidade estão mapeados em todo o percurso.",
    "Speed limits are mapped for %d%% of it; the rest is estimated.":
        "Os limites de velocidade estão mapeados em %d%% do percurso; o resto é estimado.",
    "Average %@": "Média de %@",
    "Speed limit %@": "Limite de velocidade %@",
    "No speed limit · going %@": "Sem limite de velocidade · a %@",
    "No limit mapped · going %@": "Sem limite mapeado · a %@",
    "Going %@": "A %@",
    "No street name": "Rua sem nome",
    "Estimated speed limit %@": "Limite de velocidade estimado %@",
    "No speed limit": "Sem limite de velocidade",
    "No route found between these stops. Move them onto roads or paths, or travel another way.":
        "Nenhuma rota encontrada entre essas paradas. Mova-as para ruas ou caminhos, ou tente outro meio de transporte.",
    "A stop is too far from any road or path. Move it closer and try again.":
        "Uma parada está longe demais de qualquer rua ou caminho. Aproxime-a e tente de novo.",
    "Too many stops for the route server. Take some out and try again.":
        "Paradas demais para o servidor de rotas. Remova algumas e tente de novo.",
    "That route is too long for the route server. Make it shorter, or split it up.":
        "Essa rota é longa demais para o servidor de rotas. Encurte-a ou divida-a.",
    "The route server is busy. Try again in a minute.":
        "O servidor de rotas está ocupado. Tente de novo em um minuto.",

    // MARK: - Entitlements tab

    "Entitlements": "Permissões",
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

    // Refresh all: signing the installed apps again.
    "iOS %@ isn't supported — SideInstaller needs iOS %@ or later.":
        "O iOS %@ não é compatível: o SideInstaller precisa do iOS %@ ou posterior.",
    "An install is already running. Wait for it to finish, then refresh.":
        "Já tem uma instalação em andamento. Espere ela terminar e renove depois.",
    "A refresh is already running. Wait for it to finish, then try again.":
        "Uma renovação já está em andamento. Aguarde a conclusão e tente novamente.",
    "A signing is already running. Wait for it to finish, then try again.":
        "Uma assinatura já está em andamento. Aguarde a conclusão e tente novamente.",
    "Still reading the device. Try again in a moment.":
        "Ainda lendo o dispositivo. Tente novamente em instantes.",
    "Load failed. Showing the last loaded list.":
        "Falha ao carregar. Exibindo a última lista carregada.",
    "Skipped: this app stopped being refreshable after the run started. Its IPA may have been deleted.":
        "Ignorado: este app deixou de poder ser atualizado após o início. O IPA pode ter sido excluído.",
    "Skipped: this app has no team on its signing profile, so it can't be refreshed.":
        "Ignorado: o perfil de assinatura deste app não tem equipa, por isso não pode ser atualizado.",
    "Revoked, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.":
        "Revogado, mas a lista de certificados não pôde ser atualizada. Pode estar desatualizada até recarregar.",

    "Imported, but the certificate list couldn't be refreshed. The list may be out of date until you reload it.":
        "Importado, mas a lista de certificados não pôde ser atualizada. Pode estar desatualizada até recarregar.",
    "Skipped: refresh stopped.":
        "Ignorado: atualização interrompida.",
    "The pairing wasn't handed over in the newer format. SideStore may ask for the pairing file.":
        "O emparelhamento não foi entregue no novo formato. O SideStore pode pedir o arquivo de emparelhamento.",
    "The signing certificate wasn't handed over. SideStore may ask to resign itself on first sign-in.":
        "O certificado de assinatura não foi entregue. O SideStore pode pedir uma nova assinatura no primeiro login.",
    "Cellular Install (OTA)":
        "Instalação por dados (OTA)",
    "Pairing Install":
        "Instalação por emparelhamento",
    "Upload these two files to R2, then install: %@ and %@. Upload via the WebDAV bridge https://r2-webdav.wozofa.workers.dev or the R2 console; .plist as text/xml, .ipa as application/octet-stream. After uploading, tap “Uploaded, Start Install”.":
        "Envie estes dois arquivos para o R2 e instale: %@ e %@. Envie pelo ponte WebDAV https://r2-webdav.wozofa.workers.dev ou pelo console R2; .plist como text/xml, .ipa como application/octet-stream. Depois de enviar, toque em “Já enviado, instalar”.",
    "Uploaded, Start Install":
        "Já enviado, instalar",
    "After installing, the first launch will say “Untrusted Enterprise Developer”: go to Settings → General → VPN & Device Management to trust the certificate, tap “Allow and Restart”, then open the app again.":
        "Depois de instalar, a primeira abertura dirá “Desenvolvedor empresarial não confiável”: vá em Ajustes → Geral → VPN e Gerenciamento de Dispositivos para confiar no certificado, toque em “Permitir e reiniciar” e abra o app novamente.",
    "Cellular install couldn't open the system installer: check the R2 links, or use pairing install instead.":
        "A instalação por dados não conseguiu abrir o instalador do sistema: verifique os links R2 ou use a instalação por emparelhamento.",
    "SideStore's anisette settings weren't set. If its sign-in fails with -80046, turn off On-device Anisette and Auto Rotation and pick “SideStore (New)”.":
        "Não foi possível aplicar as configurações de anisette do SideStore. Se o login falhar com -80046, desative o Anisette no dispositivo e a rotação automática, e escolha “SideStore (New)”。",
    "Last refresh (its notification couldn't be delivered): %@":
        "Última atualização (a notificação não pôde ser entregue): %@",
    "Getting ready": "Preparando",
    "Stopping after this app": "Parando depois deste app",
    "Refreshing %@": "Renovando %@",
    "Refreshed. Its seven days start again now.":
        "Renovado. Os sete dias começam de novo agora.",
    "Nothing was refreshed.": "Nada foi renovado.",
    "Refreshed %d of %d apps.": "%d de %d apps renovados.",
    "Refresh all apps?": "Renovar todos os apps?",
    "Refresh all": "Renovar todos",
    "Renew this app": "Renovar esta app",
    "%d app can be signed again from an IPA already on this iPhone.":
        "%d app pode ser assinado de novo a partir de um IPA que já está neste iPhone.",
    "%d apps can be signed again from IPAs already on this iPhone.":
        "%d apps podem ser assinados de novo a partir de IPAs que já estão neste iPhone.",
    "Reload": "Recarregar",
    "Waiting": "Aguardando",
    "In progress": "Em andamento",
    "Failed": "Falhou",
    "%d app here has no IPA in SideInstaller, so it can't be refreshed from this page. Refresh it in whatever installed it, or import its .ipa first.":
        "%d app aqui não tem IPA no SideInstaller, então não dá para renová-lo por esta página. Renove-o no app que o instalou, ou importe o .ipa dele antes.",
    "%d apps here have no IPA in SideInstaller, so they can't be refreshed from this page. Refresh them in whatever installed them, or import their .ipa first.":
        "%d apps aqui não têm IPA no SideInstaller, então não dá para renová-los por esta página. Renove-os no app que os instalou, ou importe os .ipa deles antes.",
    "%d app": "%d app",
    "%d apps": "%d apps",
    "%d app needs refreshing": "%d app precisa ser renovado",
    "%d apps need refreshing": "%d apps precisam ser renovados",
    "No sideloaded apps": "Nenhum app por sideload",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "Nada neste dispositivo foi instalado com um perfil de provisionamento. Apps da App Store não expiram, por isso não aparecem aqui.",
    "No apps were read. Tap Reload to read this iPhone again; pair it and turn on Developer Mode first if nothing shows.":
        "Nenhum app foi lido. Toque em Recarregar para ler este iPhone novamente; se nada aparecer, primeiro emparelhe-o e ative o Modo de Desenvolvedor.",
    "No matching apps.": "Nenhum app correspondente.",
    "No matching profile": "Nenhum perfil correspondente",
    "Expires today": "Expira hoje",
    "Expires tomorrow": "Expira amanhã",
    "Expires in %d days — %@": "Expira em %d dias — %@",
    "Expired %@": "Expirou em %@",
    "Unused profiles": "Perfis sem uso",
    "Issued to App IDs no installed app is running on.":
        "Emitidos para App IDs que nenhum app instalado está usando.",
    "Older profiles": "Perfis mais antigos",
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
    "Install on their iPhone": "Instalar no iPhone dele",
    "The iPhone that paired was this one. Pair from their iPhone's Settings instead. To install on this iPhone, use the Install tab.":
        "O iPhone que pareou foi este. Faça o pareamento pelos Ajustes do iPhone dele. Para instalar neste iPhone, use a aba Instalar.",
    "Enter the Apple ID to sign with, and its password.":
        "Digite o Apple ID que vai assinar o app e a senha dele.",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "O Wi-Fi está desligado. Os dois iPhones precisam estar na mesma rede Wi-Fi para isso funcionar.",
    "The release download wasn't an IPA. GitHub may be returning an error page, so try again in a minute.":
        "O download da versão não era um IPA. O GitHub pode estar devolvendo uma página de erro, então tente de novo daqui a pouco.",
    "Couldn't download the latest SideInstaller release: %@":
        "Não foi possível baixar a versão mais recente do SideInstaller: %@",
    "No SideInstaller IPA downloaded.": "Nenhum IPA do SideInstaller foi baixado.",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first. Use the Certificates tool if this is the Apple ID saved in Settings › Account, or developer.apple.com signed in as it otherwise.":
        "A Apple não emite um certificado de assinatura para este Apple ID: ela informa que já existe um (erro 7460). É preciso revogar um antes. Use a ferramenta Certificados, se este for o Apple ID salvo em Ajustes › Conta, ou developer.apple.com conectado com ele, caso contrário.",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "A Apple não registrou o iPhone dele na equipe de desenvolvimento deste Apple ID, então não vai emitir um perfil de provisionamento. %@",
    "No pair record for their iPhone.": "Nenhum registro de pareamento para o iPhone dele.",
    "The link to their iPhone dropped. Start again.":
        "A conexão com o iPhone dele caiu. Comece de novo.",
    "Set up someone else's iPhone": "Configure o iPhone de outra pessoa",
    "Same Wi-Fi network": "Mesma rede Wi-Fi",
    "Apple ID to sign with": "Apple ID que vai assinar",
    "Waiting for them to pair in Settings…":
        "Aguardando ele parear nos Ajustes…",
    "Waiting for them to enter the code…":
        "Aguardando ele digitar o código…",
    "Pair their iPhone in Settings":
        "Pareie o iPhone dele nos Ajustes",
    "Their iPhone won't ask by itself. Pairing starts from its Settings.":
        "O iPhone dele não vai pedir sozinho. O pareamento começa nos Ajustes dele.",
    "On their iPhone, open Settings › Privacy & Security › Developer Mode.":
        "No iPhone dele, abra Ajustes › Privacidade e Segurança › Modo de Desenvolvedor.",
    "Tap “Pair with %@”.":
        "Toque em “Parear com o %@”.",
    "Enter their iPhone’s passcode if it asks for it.":
        "Digite o código do iPhone dele, se ele pedir.",
    "Type the code that appears here into the prompt on their iPhone.":
        "Digite o código que aparece aqui no aviso do iPhone dele.",
    "Type this into the prompt on their iPhone.":
        "Digite este código no aviso que aparece no iPhone dele.",
    "SideInstaller is already waiting for an iPhone to pair with it, from the Install tab, the Pairing page, or an earlier attempt here. Finish that pairing, or close and reopen SideInstaller, then try again.":
        "O SideInstaller já está esperando um iPhone parear com ele, pela aba Instalar, pela página Pareamento ou por uma tentativa anterior aqui. Termine esse pareamento, ou feche e abra o SideInstaller de novo, e tente outra vez.",
    "Pairing with their iPhone didn't finish: %@":
        "O pareamento com o iPhone dele não terminou: %@",
    "Their iPhone at %@ refused the connection. It only accepts one while Developer Mode is on, and iOS asks to confirm Developer Mode again after every restart: on their iPhone, turn it on under Settings › Privacy & Security › Developer Mode, then try again.":
        "O iPhone dele em %@ recusou a conexão. Ele só aceita com o Modo de Desenvolvedor ligado, e o iOS pede para confirmar de novo depois de cada reinício: no iPhone dele, ative em Ajustes › Privacidade e Segurança › Modo de Desenvolvedor e tente outra vez.",
    "Couldn't reach their iPhone at %@. Check that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Não foi possível alcançar o iPhone dele em %@. Confira se os dois iPhones estão na mesma rede Wi-Fi e se a Rede Local está ativada para o SideInstaller nos Ajustes deste iPhone. Redes de convidados e redes públicas muitas vezes impedem que os aparelhos se comuniquem.",
    "%d%% downloaded": "%d%% baixado",
    "%@ downloaded": "%@ baixados",
    "%d%% uploaded": "%d%% enviado",
    "Start the install": "Iniciar a instalação",
    "Clear their details": "Limpar os dados dele",
    "This iPhone is still paired with theirs. Clearing forgets it.":
        "Este iPhone ainda está pareado com o dele. Limpar desfaz esse pareamento.",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "No iPhone dele: Ajustes › Geral › VPN e Gerenciamento de Dispositivo.",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "Toque no Apple ID em “App do Desenvolvedor” e depois em Confiar.",

    // MARK: - Side by Side, step by step

    "Needs LocalDevVPN on their iPhone": "Requer o LocalDevVPN no iPhone dele",
    "Couldn't download %@: %@": "Não foi possível baixar %@: %@",
    "Couldn't find %@ in Downloads. Download it again first.": "Não encontrei %@ em Downloads. Baixe novamente primeiro.",
    "The IPA for %@ in Downloads is a different clone. Its bundle ID doesn't match this history entry. Download this clone's IPA first.": "O IPA de %@ em Downloads é outro clone. O ID do pacote não corresponde a este registro. Baixe primeiro o IPA deste clone.",
    "Their iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. They need to delete one, then you can try again.":
        "O iPhone dele já tem três apps assinados com um Apple ID gratuito, o máximo que o iOS permite, contando os expirados. É preciso apagar um, e então você pode tentar de novo.",
    "%@ is on their iPhone, but its pairing file couldn't be added (%@). Run Side by Side again, or import a pairing file in %@.":
        "%@ está no iPhone dele, mas não foi possível adicionar o arquivo de pareamento (%@). Rode o Side by Side de novo ou importe um arquivo de pareamento no %@.",
    "Get started": "Começar",
    "What should go on their iPhone?": "O que vai para o iPhone dele?",
    "Pick one. You can come back for another one later.":
        "Escolha um. Você pode voltar para outro depois.",
    "Which Apple ID signs it?": "Qual Apple ID assina?",
    "The app is signed with it, and needs it again every 7 days to keep opening. Use the iPhone owner's.":
        "O app é assinado com ele e precisa dele de novo a cada 7 dias para continuar abrindo. Use o do dono do iPhone.",
    "Their Apple ID": "O Apple ID dele",
    "Recommended: they keep their apps signed with it.":
        "Recomendado: com ele, os apps dele continuam assinados.",
    "My Apple ID": "Meu Apple ID",
    "Only if you'll keep their apps signed yourself: they won't have this Apple ID's password.":
        "Só se você mesmo for manter os apps dele assinados: ele não terá a senha deste Apple ID.",
    "Used for this install only, and never saved.": "Usado só nesta instalação e nunca salvo.",
    "Apple may send a code to their devices, so keep their iPhone close.":
        "A Apple pode enviar um código para os dispositivos dele: mantenha o iPhone dele por perto.",
    "Get their iPhone ready": "Prepare o iPhone dele",
    "Do this on their iPhone, then start.": "Faça isto no iPhone dele e depois comece.",
    "Connect their iPhone to the same Wi-Fi network as this one.":
        "Conecte o iPhone dele à mesma rede Wi-Fi deste.",
    "Turn on Developer Mode under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.":
        "Ative o Modo de Desenvolvedor em Ajustes › Privacidade e Segurança › Modo de Desenvolvedor e confirme depois de reiniciar.",
    "Unlock their iPhone and keep it next to this one.":
        "Desbloqueie o iPhone dele e deixe-o ao lado deste.",
    "Installing %@ on their iPhone": "Instalando %@ no iPhone dele",
    "Waiting for their iPhone…": "Aguardando o iPhone dele…",
    "Looking for their iPhone…": "Procurando o iPhone dele…",
    "Handing over the pairing file…": "Entregando o arquivo de pareamento…",
    "Change details": "Alterar dados",
    "%@ is on their iPhone": "%@ está no iPhone dele",
    "Finish on their iPhone": "Conclua no iPhone dele",
    "This iPhone no longer keeps a pairing with theirs.":
        "Este iPhone não guarda mais um pareamento com o dele.",
    "Install another app": "Instalar outro app",
    "Get LocalDevVPN from the App Store and connect it: SideStore works through it.":
        "Baixe o LocalDevVPN na App Store e conecte-o: o SideStore funciona por ele.",
    "Open SideStore and sign in with the same Apple ID. Its pairing file is already in place.":
        "Abra o SideStore e entre com o mesmo Apple ID. O arquivo de pareamento já está no lugar.",
    "Open LiveContainer, go to its Settings tab, and tap “Import Certificate From SideStore”.":
        "Abra o LiveContainer, vá até a aba Settings e toque em “Import Certificate From SideStore”.",

    // MARK: - Settings

    "Settings": "Ajustes",
    "Done": "OK",
    "Language": "Idioma",
    "App language": "Idioma do app",
    "Sounds": "Sons",
    "Sound effects": "Efeitos sonoros",
    "Auto": "Automático",
    // The Tunnel section: starting LocalDevVPN from here.
    "Tunnel": "Túnel",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic — the device just isn't listening on its pairing port. That port only opens while Developer Mode is on, and iOS asks for it again after every restart: turn it on under Settings › Privacy & Security › Developer Mode, then try again. If it's already on, pair this iPhone again under “Pairing file”.":
        "Algo em %@:%d recusou a conexão, então o túnel está funcionando: é o dispositivo que não está escutando na porta de pareamento. Essa porta só abre com o Modo de Desenvolvedor ligado, e o iOS pede de novo depois de cada reinício: ative em Ajustes › Privacidade e Segurança › Modo de Desenvolvedor e tente outra vez. Se já estiver ligado, pareie este iPhone de novo em “Arquivo de pareamento”.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port: Developer Mode is off. Turn it on under Settings › Privacy & Security › Developer Mode (the iPhone restarts), then try again.":
        "Algo em %@:%d recusou a conexão, então o túnel está funcionando, mas este iPhone não está escutando na porta de pareamento: o Modo de Desenvolvedor está desligado. Ative em Ajustes › Privacidade e Segurança › Modo de Desenvolvedor (o iPhone reinicia) e tente outra vez.",
    "Something at %@:%d refused the connection, so the tunnel is carrying traffic, but this iPhone isn't listening on its pairing port, although Developer Mode is on. Pair this iPhone again under “Pairing file”, then try again. If it still fails, restart the iPhone.":
        "Algo em %@:%d recusou a conexão, então o túnel está funcionando, mas este iPhone não está escutando na porta de pareamento, embora o Modo de Desenvolvedor esteja ligado. Pareie este iPhone de novo em “Arquivo de pareamento” e tente outra vez. Se ainda falhar, reinicie o iPhone.",
    "Something at %@:%d took the connection but didn't answer as this iPhone's pairing port, and no other port answered as one either. Check that LocalDevVPN is the VPN that's on and that Developer Mode is on (Settings › Privacy & Security › Developer Mode), then try again. If it still fails, restart the iPhone.":
        "Algo em %@:%d aceitou a conexão, mas não respondeu como a porta de pareamento deste iPhone, e nenhuma outra porta respondeu como ela. Verifique se a VPN ligada é a LocalDevVPN e se o Modo de Desenvolvedor está ligado (Ajustes › Privacidade e Segurança › Modo de Desenvolvedor) e tente outra vez. Se ainda falhar, reinicie o iPhone.",
    "Start LocalDevVPN when needed": "Iniciar o LocalDevVPN quando for preciso",
    "Start LocalDevVPN now": "Iniciar o LocalDevVPN agora",
    "LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you.":
        "O LocalDevVPN não está instalado. Baixe-o na App Store e o SideInstaller poderá iniciá-lo para você.",
    "When on, operations that need the tunnel try the built-in tunnel first and start LocalDevVPN when needed. When off, LocalDevVPN is never started automatically; the built-in tunnel still starts on demand, and the manual pill switch is unaffected.":
        "Quando ativado, as operações que precisam do túnel tentam primeiro o túnel integrado e iniciam o LocalDevVPN quando necessário. Quando desativado, o LocalDevVPN nunca é iniciado automaticamente; o túnel integrado continua iniciando sob demanda, e o interruptor manual (pill) não é afetado.",

    "imported": "importado",
    "Downloaded %@": "Baixado em %@",
    "Added %@": "Adicionado em %@",
    "Delete": "Apagar",
    "Couldn't delete %@: %@": "Não foi possível apagar %@: %@",
    "Server": "Servidor",
    "Custom…": "Personalizado…",
    "Server URL": "URL do servidor",
    "Anisette Server": "Servidor Anisette",
    "Starts with %@": "Começa por %@",
    "Only the server picked in Settings › Anisette Server was tried. Choose Auto there to let SideInstaller try the others when one fails.":
        "Só o servidor escolhido em Ajustes › Servidor Anisette foi tentado. Escolha Automático lá para o SideInstaller tentar os outros quando um falhar.",
    "Device IP": "IP do dispositivo",
    "Advanced": "Avançado",
    "Clear": "Limpar",
    "Clear install history?": "Limpar o histórico de instalação?",
    "Activity Log (%d)": "Registro de atividade (%d)",
    "没有匹配的日志。": "Nenhum registro correspondente.",
    "Verbose logging": "Registro detalhado",
    "Adds the messages exchanged with iOS to the log, for tracking down a connection problem. Leave it off otherwise, as they quickly fill the log.":
        "Adiciona ao registro as mensagens trocadas com o iOS, para encontrar um problema de conexão. Fora isso, deixe desligado, pois elas enchem o registro rapidamente.",

    // Settings › Developer Mode: AMFI requests over the device link.
    "Developer Mode": "Modo de Desenvolvedor",
    "Developer disk image": "Imagem de disco do desenvolvedor",
    "Downloaded": "Baixada",
    "Not downloaded": "Não baixada",
    "Re-download": "Baixar novamente",
    "Show Developer Mode in Settings": "Mostrar o Modo de Desenvolvedor nos Ajustes",
    "Turn on Developer Mode": "Ativar o Modo de Desenvolvedor",
    "Asking this iPhone…": "Consultando este iPhone…",
    "Turn on Developer Mode?": "Ativar o Modo de Desenvolvedor?",
    "Turn On and Restart": "Ativar e reiniciar",
    "This iPhone restarts right away. Once you unlock it, tap Turn On in the alert that appears. iOS allows this only while the iPhone has no passcode.":
        "Este iPhone reinicia na hora. Depois de desbloquear, toque em Ativar no alerta que aparecer. O iOS só permite isso quando o iPhone não tem código.",
    "Developer Mode is already on.": "O Modo de Desenvolvedor já está ativado.",
    "Developer Mode now shows under Settings › Privacy & Security, near the bottom. Turn it on there, and iOS restarts to finish.":
        "O Modo de Desenvolvedor agora aparece em Ajustes › Privacidade e Segurança, perto do fim. Ative por lá, e o iOS reinicia para concluir.",
    "Developer Mode is set to turn on, and this iPhone restarts now. Once you unlock it, tap Turn On.":
        "O Modo de Desenvolvedor vai ser ativado, e este iPhone reinicia agora. Depois de desbloquear, toque em Ativar.",
    "An install is already running. Wait for it to finish, then try again.":
        "Já tem uma instalação em andamento. Espere ela terminar e tente de novo.",
    "An import is already running. Wait for it to finish, then try again.": "Já há uma importação em andamento. Aguarde a conclusão e tente novamente.",
    "%@ will be signed again with the Apple ID that signed it and installed over the copy on this device. It keeps its data, and its seven days start over.": "%@ será assinado novamente com o ID Apple que o assinou e instalado sobre a cópia neste dispositivo. Ele mantém os dados e os sete dias começam de novo.",
    "%d apps will be signed again, each with the Apple ID that signed it, and installed over the copies on this device. They keep their data, and their seven days start over.": "%d apps serão assinados novamente, cada um com o ID Apple que o assinou, e instalados sobre as cópias neste dispositivo. Eles mantêm os dados e os sete dias começam de novo.",
    "%d app here is signed under a team that matches no saved Apple ID, so it is left out. Switch to the Apple ID that signed it and sign in once, then reload, and it will join the list. Enterprise-signed apps stay excluded.": "%d app aqui foi assinado por uma equipe que não corresponde a nenhum ID Apple salvo, por isso ficou de fora. Mude para o ID Apple que o assinou, inicie sessão uma vez e recarregue; ele entrará na lista. Apps assinados por empresa continuam excluídos.",
    "%d apps here are signed under teams that match no saved Apple ID, so they are left out. Switch to the Apple ID that signed them and sign in once, then reload, and they will join the list. Enterprise-signed apps stay excluded.": "%d apps aqui foram assinados por equipes que não correspondem a nenhum ID Apple salvo, por isso ficaram de fora. Mude para o ID Apple que os assinou, inicie sessão uma vez e recarregue; eles entrarão na lista. Apps assinados por empresa continuam excluídos.",
    "These apps were signed under %d Apple IDs, so each group is signed with its own Apple ID.": "Estes apps foram assinados com %d IDs Apple, por isso cada grupo é assinado com o seu próprio ID Apple.",
    "Couldn't sign in as %@ (%@). Switch to that account and refresh again.": "Não foi possível iniciar sessão como %@ (%@). Mude para essa conta e tente novamente.",
    "Skipped: no saved Apple ID matches this app's team (%@). Switch to that account and refresh again.": "Ignorado: nenhum ID Apple salvo corresponde à equipe deste app (%@). Mude para essa conta e tente novamente.",
    "Skipped: signed in as %@, but this app's team is %@. Switch to that account and refresh again.": "Ignorado: sessão iniciada como %@, mas a equipe deste app é %@. Mude para essa conta e tente novamente.",
    "Refreshing %@ as %@": "Renovando %@ como %@",
    "Invalid device IP": "IP do dispositivo inválido",
    "The address was invalid, reset to 10.7.0.1.": "O endereço era inválido; foi redefinido para 10.7.0.1.",
    "Bundle Identifier": "Identificador do bundle",
    "rpath": "rpath",
    "iOS turns Developer Mode on from here only while this iPhone has no passcode. Tap “Show Developer Mode in Settings” and turn it on there instead.":
        "O iOS só ativa o Modo de Desenvolvedor daqui quando este iPhone não tem código. Toque em “Mostrar o Modo de Desenvolvedor nos Ajustes” e ative por lá.",
    "This iPhone didn't take the Developer Mode request: %@":
        "Este iPhone não aceitou o pedido do Modo de Desenvolvedor: %@",

    // MARK: - Release channels & downloads

    "Stable": "Estável",
    "Nightly": "Nightly",

    // Version picker (Advanced)

    "%@ version": "Versão do %@",
    "Latest": "Mais recente",
    "Latest (%@)": "Mais recente (%@)",
    "Couldn't load the other versions: %@": "Não foi possível carregar as outras versões: %@",
    "Try again": "Tentar de novo",
    "Retry failed items": "Tentar novamente os itens com falha",

    "couldn't find the IPA in the %@ %@ release":
        "não foi possível encontrar o IPA na versão %@ %@",
    "%@ has no %@ release right now": "o %@ não tem nenhuma versão %@ no momento",
    "bad asset URL": "endereço de arquivo inválido",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "O GitHub está limitando as requisições desta rede — ela não está bloqueada, e o limite se resolve sozinho. Tente de novo %@.",
    "GitHub isn't serving %@ right now — the repository has been taken down, moved or made private, so there's nothing to download. Nothing is wrong with this iPhone or its network.":
        "O GitHub não está disponibilizando %@ no momento — o repositório foi removido, movido ou tornado privado, então não há nada para baixar. Não há nada de errado com este iPhone nem com a rede dele.",
    "couldn't reach GitHub: %@": "não foi possível acessar o GitHub: %@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "A resposta do GitHub não trazia informações de versão (%@) — algo nesta rede pode tê-la substituído.",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "o que foi baixado como %@ não é um IPA — algo nesta rede devolveu uma página no lugar, ou a transferência parou no meio.",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "esse link respondeu HTTP %d — ele não é um download direto, ou exige que você entre numa conta.",
    "GitHub has no build of %@'s %@ branch to download right now.":
        "O GitHub não tem agora nenhuma versão do branch %2$@ de %1$@ para baixar.",
    "couldn't download %@ through nightly.link, which passes on GitHub's builds: %@":
        "não foi possível baixar %@ pelo nightly.link, que repassa as versões compiladas pelo GitHub: %@",
    "the %@ build that arrived isn't the file GitHub recorded, so it isn't installed. Try again later.":
        "a versão de %@ que chegou não é o arquivo que o GitHub registrou, então ela não será instalada. Tente de novo mais tarde.",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "A verificação em duas etapas foi cancelada.",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID ou senha incorretos. Confira o e-mail e a senha da sua conta Apple e tente de novo.",
    "Apple ID sign-in failed on %@. Error: %@":
        "Falha ao entrar no Apple ID em %@. Erro: %@",
    "Apple ID sign-in failed on %@. Error via %@: %@":
        "Falha ao entrar no Apple ID em %@. Erro via %@: %@",
    "Apple's sign-in server refused the request (HTTP 503). It isn't your password or the anisette server, so trying more servers won't help. Try again later, or update SideInstaller.":
        "O servidor de login da Apple recusou a solicitação (HTTP 503). Não é a sua senha nem o servidor anisette, então tentar outros servidores não vai adiantar. Tente de novo mais tarde ou atualize o SideInstaller.",
    "“%@” makes its anisette data with Apple's Android library, and Apple now refuses to finish signing in through those servers (error -80046), after your password and code. In Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "“%@” gera os dados anisette com a biblioteca Android da Apple, e agora a Apple se recusa a concluir o login por esses servidores (erro -80046), depois da sua senha e do código. Em Ajustes › Servidor Anisette, escolha Automático ou um servidor Mac como “SideStore (New)”.",
    "Apple refused to finish signing in (error -80046), even through a Mac anisette server, the kind it still accepted. Try again later, or check for a SideInstaller update.":
        "A Apple se recusou a concluir o login (erro -80046), mesmo por um servidor anisette Mac, o tipo que ela ainda aceitava. Tente de novo mais tarde ou veja se há uma atualização do SideInstaller.",
    "Apple refused to finish signing in through “%@” (error -80046). It now only accepts sign-ins through anisette servers on its macOS library: in Settings › Anisette Server, choose Auto or a Mac server such as “SideStore (New)”.":
        "A Apple se recusou a concluir o login por “%@” (erro -80046). Agora ela só aceita logins por servidores anisette com a biblioteca macOS dela: em Ajustes › Servidor Anisette, escolha Automático ou um servidor Mac como “SideStore (New)”.",
    "Apple won't send a code by text or call to this sign-in, so it was sent to your Apple devices.":
        "A Apple não envia código por SMS nem por ligação para este login, então ele foi enviado para seus dispositivos Apple.",
    "Apple didn't confirm sending a code to your Apple devices. If one arrived, enter it; if not, try another way.":
        "A Apple não confirmou o envio de um código para seus dispositivos Apple. Se chegou um, digite-o; se não, tente de outra forma.",
    "SideInstaller can't reach Apple's sign-in server (gsa.apple.com), though this iPhone has an internet connection. Something is blocking it: a firewall, a DNS filter or ad blocker, Screen Time content restrictions, or another VPN app. Turn it off or try another network, then try again.":
        "O SideInstaller não consegue acessar o servidor de login da Apple (gsa.apple.com), embora este iPhone esteja conectado à internet. Algo está bloqueando: um firewall, um filtro de DNS ou bloqueador de anúncios, as restrições de conteúdo do Tempo de Uso ou outro app de VPN. Desative-o ou tente outra rede e tente de novo.",
    "SideInstaller can't reach Apple: Cellular Data is turned off for it. Turn SideInstaller on in Settings › Cellular, or join a Wi-Fi network with internet access, then try again.":
        "O SideInstaller não consegue acessar a Apple: os dados celulares estão desativados para ele. Ative o SideInstaller em Ajustes › Celular ou conecte-se a uma rede Wi-Fi com acesso à internet e tente de novo.",
    "SideInstaller can't reach Apple: iOS isn't letting it use Wi-Fi. In Settings › Apps › SideInstaller › Wireless Data, choose WLAN & Cellular Data, then try again.":
        "O SideInstaller não consegue acessar a Apple: o iOS não permite que ele use o Wi-Fi. Em Ajustes › Apps › SideInstaller › Dados Sem Fio, escolha WLAN e Dados Celulares e tente de novo.",
    "SideInstaller can't reach Apple: a VPN set to carry all traffic is disconnected, so iOS is holding traffic back. Reconnect it, or turn off its kill switch or Connect On Demand, then try again.":
        "O SideInstaller não consegue acessar a Apple: uma VPN configurada para levar todo o tráfego está desconectada, então o iOS está retendo o tráfego. Reconecte-a ou desative o kill switch ou a conexão sob demanda dela e tente de novo.",
    "SideInstaller can't reach Apple: this iPhone has no internet connection. Connect to Wi-Fi or turn on cellular data, then try again.":
        "O SideInstaller não consegue acessar a Apple: este iPhone está sem conexão com a internet. Conecte-se a uma rede Wi-Fi ou ative os dados celulares e tente de novo.",
    "Apple is temporarily limiting sign-ins for this Apple ID or network (HTTP 429). Trying other servers won't help, and every attempt can extend the wait, so leave it a while before signing in again.":
        "A Apple está limitando temporariamente os logins deste Apple ID ou desta rede (HTTP 429). Tentar outros servidores não vai adiantar, e cada tentativa pode aumentar a espera, então aguarde um pouco antes de entrar de novo.",
    "If you're sure the password is right, Apple may be limiting sign-in attempts: wait a while before trying again.":
        "Se você tem certeza de que a senha está correta, a Apple pode estar limitando as tentativas de login: aguarde um pouco antes de tentar de novo.",
    "Apple has locked this Apple Account for security reasons (error -20209), so every sign-in fails until it's unlocked. Reset its password at iforgot.apple.com, then sign in again with the new password.":
        "A Apple bloqueou esta conta Apple por motivos de segurança (erro -20209), então todo login falha até ela ser desbloqueada. Redefina a senha em iforgot.apple.com e entre de novo com a nova senha.",
    "the anisette server": "o servidor anisette",
    "all %d anisette servers": "todos os %d servidores anisette",
    "%d anisette servers (%d skipped)": "%d servidores anisette (%d ignorados)",
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
    "No IPA on this iPhone":
        "Nenhum IPA correspondente neste iPhone",
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
    "Bring the .ipa yourself": "Traga você mesmo o .ipa",
    "%@ can't be downloaded while its GitHub repository is offline. The other apps still install as usual.":
        "Não dá para baixar o %@ enquanto o repositório dele no GitHub estiver fora do ar. Os outros apps continuam instalando normalmente.",
    "To install it anyway, get its .ipa from somewhere you trust, name it %@, and copy it into Files › On My iPhone › SideInstaller.":
        "Para instalá-lo mesmo assim, consiga o .ipa dele em uma fonte em que você confie, dê a ele o nome %@ e copie-o para Arquivos › No meu iPhone › SideInstaller.",
    "Then tap Install again — SideInstaller uses your file instead of downloading one.":
        "Depois, toque em Instalar de novo — o SideInstaller usa o seu arquivo em vez de baixar um.",
    "If you reach GitHub through a VPN or proxy app, turn off LocalDevVPN and turn that one on: iOS runs only one VPN at a time.":
        "Se você acessa o GitHub por um app de VPN ou proxy, desative o LocalDevVPN e ative esse app: o iOS mantém só uma VPN por vez.",
    "Tap “Get the .ipa” below and save the file, or download it on another device and bring it over.":
        "Toque em “Obter o .ipa” abaixo e salve o arquivo, ou baixe-o em outro aparelho e traga-o para cá.",
    "Back in SideInstaller, pick Custom .ipa under Install, tap “Import .ipa” and choose the file. SideInstaller recognizes %@ and sets it up just like its own download.":
        "De volta ao SideInstaller, escolha .ipa personalizado em Instalar, toque em “Importar .ipa” e escolha o arquivo. O SideInstaller reconhece %@ e o configura como se ele mesmo o tivesse baixado.",
    "Turn LocalDevVPN back on, then tap Install.":
        "Ative o LocalDevVPN de novo e toque em Instalar.",
    "Get the .ipa": "Obter o .ipa",
    "Pair this iPhone in Settings": "Pareie este iPhone nos Ajustes",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "Abra o app Ajustes e vá em Privacidade e Segurança › Modo de Desenvolvedor.",
    "Tap “Pair with SideInstaller”.": "Toque em “Parear com o SideInstaller”.",
    "Enter your iPhone’s passcode if it asks for it.":
        "Digite o código do seu iPhone, se ele pedir.",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "Volte ao SideInstaller, veja o código que ele mostra e digite esse mesmo código no aviso que aparece nos Ajustes.",
    "Type the code that appears at the top of the screen into the prompt in Settings. If none appears, come back to SideInstaller to read it.":
        "Digite o código que aparece no topo da tela no aviso que aparece nos Ajustes. Se não aparecer nenhum, volte ao SideInstaller para ver.",
    "Allow notifications when SideInstaller asks: that's how the pairing code reaches you in Settings.":
        "Permita as notificações quando o SideInstaller pedir: é assim que o código de pareamento chega até você nos Ajustes.",

    // The pairing Live Activity
    "Privacy & Security › Developer Mode › Pair with SideInstaller":
        "Privacidade e Segurança › Modo de Desenvolvedor › Parear com o SideInstaller",
    "Paired": "Pareado",
    "Tap to return to SideInstaller.": "Toque para voltar ao SideInstaller.",

    // The install's progress outside the app
    "Installing %@": "Instalando %@",
    "Paused": "Pausado",
    "Ignore this version": "Ignorar esta versão",
    "已忽略的更新": "Atualizações ignoradas",
    "没有已忽略的更新。": "Nenhuma atualização ignorada.",
    "所有已忽略的版本都将重新提示更新。": "Todas as versões ignoradas voltarão a sugerir atualizações.",
    "Pause": "Pausar",
    "Pause all": "Pausar tudo",
    "Resume": "Continuar",
    "Resume all": "Retomar tudo",
    "Open": "Abrir",
    "Open SideInstaller to finish the install.":
        "Abra o SideInstaller para concluir a instalação.",
    "Check the App IDs it needs, then tap Install.":
        "Confira os App IDs necessários e depois toque em Instalar.",
    "Tap Trust": "Toque em Confiar",
    "Unlock this iPhone and tap Trust when it asks.":
        "Desbloqueie este iPhone e toque em Confiar quando ele pedir.",

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

    // Guide: reset a locked Apple Account

    "Reset your Apple Account password": "Redefina a senha da sua conta Apple",
    "Apple has locked this Apple Account for security reasons, often after too many sign-in attempts. Every sign-in fails until it's unlocked, so tapping Install again won't help yet.":
        "A Apple bloqueou esta conta Apple por motivos de segurança, geralmente depois de tentativas de login demais. Todo login falha até ela ser desbloqueada, então tocar em Instalar de novo ainda não adianta.",
    "Open iForgot, enter this Apple Account's email, and follow Apple's steps to unlock it and reset its password.":
        "Abra o iForgot, digite o e-mail desta conta Apple e siga os passos da Apple para desbloqueá-la e redefinir a senha.",
    "Back in SideInstaller, open Settings › Account, swipe left on this Apple ID, tap Edit, and enter the new password.":
        "De volta ao SideInstaller, abra Ajustes › Conta, deslize este Apple ID para a esquerda, toque em Editar e digite a nova senha.",
    "Then tap Install again.": "Depois, toque em Instalar de novo.",
    "Open iForgot": "Abrir o iForgot",
    "Apple won't let this Apple Account use developer services because of its owner's age (error 1102). Sign in with an adult's Apple Account instead.":
        "A Apple não deixa esta conta Apple usar os serviços para desenvolvedores por causa da idade do titular (erro 1102). Entre com a conta Apple de um adulto.",
    "This Apple ID has no App IDs left (error 9120). A free Apple ID can register 10 a week, and each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Este Apple ID não tem mais App IDs disponíveis (erro 9120). Um Apple ID gratuito pode registrar 10 por semana, e cada um conta por 7 dias, então espere alguns expirarem ou entre com outro Apple ID.",
    "This iPhone already has three apps signed with a free Apple ID, the most iOS allows, counting expired ones. Delete one of them, then try again.":
        "Este iPhone já tem três apps assinados com um Apple ID gratuito, o máximo que o iOS permite, contando os expirados. Apague um deles e tente de novo.",
    "This Apple Account can't sign apps":
        "Esta conta Apple não pode assinar apps",
    "Apple only lets adults use the developer services SideInstaller signs apps with, and it reports that this Apple Account belongs to someone younger (error 1102).":
        "A Apple só deixa adultos usarem os serviços para desenvolvedores com que o SideInstaller assina apps, e informa que esta conta Apple pertence a alguém mais novo (erro 1102).",
    "Sign in with an adult's Apple Account instead: open Settings › Account and add it there.":
        "Entre com a conta Apple de um adulto: abra Ajustes › Conta e adicione-a lá.",
    "Apple won't let this Apple Account use developer services until its email address is verified (error 2160). Verify it at account.apple.com, then try again.":
        "A Apple não deixa esta conta Apple usar os serviços para desenvolvedores até o endereço de e-mail dela ser verificado (erro 2160). Verifique-o em account.apple.com e tente de novo.",
    "Verify your Apple Account's email":
        "Verifique o e-mail da sua conta Apple",
    "Apple won't let this Apple Account sign apps until its email address is verified (error 2160). Signing in again or through another anisette server won't change that.":
        "A Apple não deixa esta conta Apple assinar apps até o endereço de e-mail dela ser verificado (erro 2160). Entrar de novo ou usar outro servidor anisette não muda isso.",
    "Sign in at account.apple.com with this Apple Account and verify its email address when Apple asks. Apple sends the code or link to that address, so check its spam folder too.":
        "Entre em account.apple.com com esta conta Apple e verifique o endereço de e-mail quando a Apple pedir. A Apple envia o código ou o link para esse endereço, então confira também a pasta de spam.",
    "Open Apple Account":
        "Abrir a conta Apple",
    "No App IDs left this week": "Sem App IDs nesta semana",
    "They can't be deleted sooner. Wait until some expire, then tap Install again.":
        "Não dá para apagá-los antes. Espere alguns expirarem e toque em Instalar de novo.",
    "Or sign in with a different (or spare) Apple ID in Settings › Account, then tap Install again.":
        "Ou entre com outro Apple ID (ou um reserva) em Ajustes › Conta e toque em Instalar de novo.",
    "Three sideloaded apps already": "Já há três apps por sideload",
    "iOS allows three apps signed with a free Apple ID on an iPhone at a time, and it refused a fourth.":
        "O iOS permite três apps assinados com um Apple ID gratuito em um iPhone ao mesmo tempo, e recusou um quarto.",
    "Expired apps count too. Delete one you no longer need from the Home Screen.":
        "Apps expirados também contam. Apague da Tela de Início um que você não usa mais.",

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
    "iOS refused the connection to %@ on this iPhone, before anything was sent. It does that for this iPhone's own addresses, like the “Connected to” address on LocalDevVPN's main screen. Device IP, in Settings › Advanced, has to be the address under LocalDevVPN's Settings › Device IP: 10.7.0.1 by default. If it already is, turn LocalDevVPN off and on again, then try again.":
        "O iOS recusou a conexão com %@ neste iPhone, antes de qualquer coisa ser enviada. Ele faz isso com os endereços do próprio iPhone, como o que aparece depois de “Connected to” na tela principal do LocalDevVPN. O IP do dispositivo, em Ajustes › Avançado, precisa ser o endereço em Settings › Device IP do LocalDevVPN (o padrão é 10.7.0.1). Se já for, desligue e ligue o LocalDevVPN de novo e tente outra vez.",
    "This iPhone hung up on the connection as soon as it opened. From iOS 26.4 on it does that to lockdown pairing files, like this one, when they come through LocalDevVPN. Pair this iPhone with itself instead: tap “Regenerate” under Tools › Pairing, or tap Install, which pairs it first.":
        "Este iPhone derrubou a conexão assim que ela abriu. A partir do iOS 26.4, ele faz isso com arquivos de pareamento lockdown, como este, quando chegam pelo LocalDevVPN. Em vez disso, pareie este iPhone consigo mesmo: toque em “Gerar de novo” em Ferramentas › Pareamento, ou toque em Instalar, que pareia primeiro.",
    "This iPhone hung up on the connection as soon as it opened. Since iOS 26.4 it does that to lockdown pairing files, like this one, when they come through LocalDevVPN, so a new one of the same kind won't help. A remote pairing file still works: on a computer, open idevice_pair, choose “Remote pairing”, click “Create”, then “Save to file…”, and import the file under “Pairing file”.":
        "Este iPhone derrubou a conexão assim que ela abriu. A partir do iOS 26.4, ele faz isso com arquivos de pareamento lockdown, como este, quando chegam pelo LocalDevVPN, então fazer outro do mesmo tipo não vai adiantar. Um arquivo de pareamento “Remote pairing” continua funcionando: num computador, abra o idevice_pair, escolha “Remote pairing”, clique em “Create” e depois em “Save to file…”, e importe o arquivo em “Arquivo de pareamento”.",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "Parear este iPhone depende disso: o SideInstaller se anuncia na rede local para os Ajustes o encontrarem.",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Conecte-se a uma rede Wi-Fi. Parear este iPhone depende disso — o SideInstaller precisa ser encontrável na rede local.",

    // MARK: - About

    "About": "Sobre",
    "Version %@ (%@)": "Versão %@ (%@)",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "O SideInstaller instala o SideStore e o LiveContainer direto no seu iPhone, sem precisar de computador.",
    "Checking for updates…": "Verificando atualizações…",
    "Checking for updates… Tap again to cancel.": "Verificando atualizações… Toque novamente para cancelar.",
    "You're up to date.": "Você está atualizado.",
    "Couldn't check for updates. Check your connection and try again.":
        "Não foi possível verificar atualizações. Verifique sua conexão e tente novamente.",

    "Links": "Links",
    "Source code": "Código-fonte",
    "Support the project": "Apoie o projeto",
    "Crypto": "Cripto",
    "Donation wallets for Bitcoin, Ethereum and Solana.":
        "Carteiras para doações em Bitcoin, Ethereum e Solana.",
    "Crypto donations": "Doações em cripto",
    "Donations are entirely optional. They don't buy anything, unlock any feature or get you anything in return; they're just a way to say thanks if SideInstaller has helped you.":
        "As doações são totalmente opcionais. Elas não compram nada, não desbloqueiam nenhum recurso nem dão nada em troca; são só uma forma de agradecer se o SideInstaller te ajudou.",
    "Coin": "Moeda",
    "Network: %@": "Rede: %@",
    "QR code for the %@ address": "Código QR do endereço %@",
    "Copied": "Copiado",
    "Send each coin only on the network shown. Crypto sent on another network can't be recovered.":
        "Envie cada moeda apenas pela rede indicada. Criptomoedas enviadas por outra rede não podem ser recuperadas.",

    "Special thanks": "Agradecimentos especiais",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "Pelo idevice, a biblioteca com que o SideInstaller conversa com o seu iPhone. Nada disso existe sem ela.",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "Pelo apoio e por apontar os erros que foram corrigidos por causa dele.",
    "For the Japanese translation.": "Pela tradução para o japonês.",
    "For the Korean translation.": "Pela tradução para o coreano.",
    "For the Turkish translation.": "Pela tradução para o turco.",

    "Built with": "Feito com",
    "The open source work this app is built on:":
        "O trabalho de código aberto em que este app se apoia:",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "O pareamento, o túnel e a própria instalação. De jkcoxson, MIT.",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Login no Apple ID, certificados e assinatura no próprio aparelho. De nab138, MIT.",
    "The code signer isideload uses for each app. By Dadoum, LGPL-2.1.":
        "O assinador de código que o isideload usa em cada app. De Dadoum, LGPL-2.1.",
    "The sideloading app this installs for you.": "O app de sideload que isto instala para você.",
    "Runs sideloaded apps without spending an app slot on each one.":
        "Roda apps de sideload sem gastar um espaço de app com cada um.",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "A imagem de disco de desenvolvedor que a simulação de localização monta. Espelhada por doronz88.",

    "Terms": "Termos",

    // MARK: - Madeira

    "%@ needs iOS %d or later. This iPhone runs iOS %@.":
        "O %@ precisa do iOS %d ou posterior. Este iPhone usa o iOS %@.",
    "%@ needs iOS %@ or later. This iPhone runs iOS %@.": "O %@ precisa do iOS %@ ou posterior. Este iPhone usa o iOS %@.",
    "Minimum iOS": "iOS mínimo",
    "SHA-256": "SHA-256",
    "Show all": "Mostrar tudo",
    "Open Madeira from your Home Screen.": "Abra o Madeira pela Tela de Início.",
    "In its setup, under “Set up JIT”, pick “In-app with pairing file”: SideInstaller already put the file there, so tap “Continue”.":
        "Na configuração dele, em “Set up JIT”, escolha “In-app with pairing file”: o SideInstaller já colocou o arquivo lá, então toque em “Continue”.",
    "In its setup, under “Set up JIT”, pick how this iPhone gets JIT.":
        "Na configuração dele, em “Set up JIT”, escolha como este iPhone vai ter JIT.",
    "Madeira renews its own signing from now on, when it's open and LocalDevVPN is connected. SideInstaller gave it a sign-in for that: a token for Apple's developer service, not your password. Madeira can forget it under Settings › Signing.":
        "A partir de agora o Madeira renova a própria assinatura, quando está aberto e o LocalDevVPN está conectado. O SideInstaller deu a ele um acesso para isso: um token do serviço de desenvolvedor da Apple, não a sua senha. O Madeira pode esquecê-lo em Settings › Signing.",
    "Its signing lasts 7 days. Before they run out, refresh it here under Tools › Sideloaded apps.":
        "A assinatura dele dura 7 dias. Antes de acabarem, renove aqui em Ferramentas › Apps instalados por sideload.",
    "This pairing file has no RPPairing record, the only kind %@ reads.":
        "Este arquivo de pareamento não tem um registro RPPairing, o único tipo que o %@ lê.",
    "Runs Windows PC games on your iPhone. By Will Faust, GPL-3.0.":
        "Roda jogos de PC para Windows no seu iPhone. De Will Faust, GPL-3.0.",

    // MARK: - App ID cost

    "App IDs for this app": "App IDs deste app",
    "Cost": "Custo",
    "Left now": "Restam agora",
    "Left after": "Restarão",
    "New App IDs": "Novos App IDs",
    "This Apple ID doesn't have enough App IDs left: this app needs %d, and %d are left. Each one counts for 7 days, so wait for some to expire or sign in with another Apple ID.":
        "Este Apple ID não tem App IDs suficientes: este app precisa de %d e restam %d. Cada um conta por 7 dias, então espere alguns expirarem ou entre com outro Apple ID.",
    "The next one frees up on %@.": "O próximo é liberado em %@.",
    "Your Apple ID already has every App ID this app needs, so installing it uses none.":
        "Seu Apple ID já tem todos os App IDs de que este app precisa, então instalá-lo não usa nenhum.",
    "Signing registers one App ID for the app, and its extensions share it. It counts for 7 days.":
        "A assinatura registra um único App ID para o app, compartilhado por suas extensões. Ele conta por 7 dias.",
    "This Apple ID can register %d a week.":
        "Este Apple ID pode registrar %d por semana.",

    // MARK: - Links (sideinstaller://install, sideinstaller://pairingFile)

    "Install from a link?": "Instalar a partir de um link?",
    "Download and install": "Baixar e instalar",
    "SideInstaller will download this .ipa, then sign it with your Apple ID and install it. Only go ahead if you trust where the link came from.":
        "O SideInstaller vai baixar este .ipa, assiná-lo com seu Apple ID e instalá-lo. Só continue se você confia na origem do link.",
    "It replaces %@, the custom .ipa you have now.": "Ele substitui %@, o .ipa personalizado que você tem agora.",
    "Use SideStore's pairing file?": "Usar o arquivo de pareamento do SideStore?",
    "Import this pairing file?": "Importar este arquivo de pareamento?",
    "Import": "Importar",
    "SideStore sent back the pairing file it has. SideInstaller will connect to this iPhone with it.":
        "O SideStore devolveu o arquivo de pareamento que tem. O SideInstaller vai usá-lo para se conectar a este iPhone.",
    "A link sent SideInstaller a pairing file. Only import it if you asked for one: SideInstaller will connect to this iPhone with it.":
        "Um link enviou ao SideInstaller um arquivo de pareamento. Só importe se você pediu um: o SideInstaller vai usá-lo para se conectar a este iPhone.",
    "It replaces %@.": "Ele substitui %@.",
    "It replaces the pairing file in use now.": "Ele substitui o arquivo de pareamento em uso agora.",
    "Get it from SideStore": "Pegar do SideStore",
    "SideStore opens and sends back the pairing file it has.":
        "O SideStore abre e devolve o arquivo de pareamento que tem.",
    "SideStore isn't installed on this iPhone, so there's no pairing file to get from it.":
        "O SideStore não está instalado neste iPhone, então não há arquivo de pareamento para pegar dele.",
    "SideInstaller takes the pairing file LiveContainer's built-in SideStore has.":
        "O SideInstaller pega o arquivo de pareamento do SideStore integrado ao LiveContainer.",
    "This is the pairing file LiveContainer's built-in SideStore has. SideInstaller will connect to this iPhone with it.":
        "Este é o arquivo de pareamento do SideStore integrado ao LiveContainer. O SideInstaller vai usá-lo para se conectar a este iPhone.",
    "In LiveContainer's Multitask Mode, SideInstaller can't open the built-in SideStore's files. Open SideInstaller in LiveContainer without Multitask Mode, then try again, or tap “Import pairing file” and pick the file your computer made.":
        "No Modo Multitarefa do LiveContainer, o SideInstaller não consegue abrir os arquivos do SideStore integrado. Abra o SideInstaller no LiveContainer fora do Modo Multitarefa e tente de novo, ou toque em “Importar arquivo de pareamento” e escolha o arquivo que seu computador criou.",
    "Inside LiveContainer, SideStore can't send its pairing file back to SideInstaller, and LiveContainer's built-in SideStore has none that SideInstaller can use. Tap “Import pairing file” and pick the file your computer made, or import one into SideStore first, then try again here.":
        "Dentro do LiveContainer, o SideStore não consegue devolver o arquivo de pareamento ao SideInstaller, e o SideStore integrado ao LiveContainer não tem nenhum que o SideInstaller possa usar. Toque em “Importar arquivo de pareamento” e escolha o arquivo que seu computador criou, ou importe um no SideStore primeiro e tente de novo aqui.",
    "That install link has no .ipa in it. It needs ?url= followed by the https:// address the .ipa downloads from.":
        "Esse link de instalação não tem nenhum .ipa. Ele precisa de ?url= seguido do endereço https:// de onde o .ipa é baixado.",
    "That link was meant to carry a pairing file, but what it holds can't be read.":
        "Esse link deveria trazer um arquivo de pareamento, mas o conteúdo não pode ser lido.",
    "That link carries a file, but it isn't a pairing file.":
        "Esse link traz um arquivo, mas não é um arquivo de pareamento.",

    // MARK: - Report a problem

    "Report a problem": "Relatar um problema",
    "Report this problem": "Relatar este problema",
    "Opens a GitHub issue with this app's details, its log and crash logs.":
        "Abre uma issue no GitHub com os detalhes do app, o registro e os relatórios de falhas.",
    "What happened?": "O que aconteceu?",
    "What were you doing, and what went wrong?": "O que você estava fazendo e o que deu errado?",
    "Say what you tapped, what you expected and what happened instead. English is best, but any language is fine.":
        "Diga o que você tocou, o que esperava e o que aconteceu no lugar. Inglês é melhor, mas qualquer idioma serve.",
    "Included": "Incluído",
    "Device": "Dispositivo",
    "App": "App",
    "Stopped at": "Parou em",
    "not connected": "não conectado",
    "none": "nenhum",
    "made on this iPhone": "criado neste iPhone",
    "Runs inside LiveContainer": "Rodando dentro do LiveContainer",
    "on": "ligado",
    "off": "desligado",
    "unknown": "desconhecido",
    "yes": "sim",
    "no": "não",
    "latest": "mais recente",
    "custom server": "servidor personalizado",
    "Auto, starts with %@": "Auto, começa por %@",
    "Error": "Erro",
    "Activity log": "Registro de atividade",
    "%d lines": "%d linhas",
    "Your Apple ID, device name, serial numbers and keys are taken out of the log first.":
        "O Apple ID, o nome do dispositivo, os números de série e as chaves são removidos do registro antes.",
    "Crash logs": "Relatórios de falhas",
    "Looking for crash logs …": "Procurando relatórios de falhas …",
    "Look for crash logs on this iPhone": "Procurar relatórios de falhas neste iPhone",
    "Look again": "Procurar de novo",
    "No crash logs from SideStore, LiveContainer or Madeira in the last %d days.":
        "Nenhum relatório de falhas do SideStore, LiveContainer ou Madeira nos últimos %d dias.",
    "iOS hands SideInstaller its own crashes the next time it opens. Crash logs from SideStore, LiveContainer and Madeira are read from this iPhone through LocalDevVPN.":
        "O iOS entrega ao SideInstaller as próprias falhas na próxima vez que ele abre. Os relatórios de falhas do SideStore, LiveContainer e Madeira são lidos deste iPhone pelo LocalDevVPN.",
    "Open a GitHub issue": "Abrir uma issue no GitHub",
    "Share the report": "Compartilhar o relatório",
    "Preview the report": "Ver o relatório",
    "Report": "Relatório",
    "The issue opens filled in. When the log is too long for that, SideInstaller copies it for you to paste at the end of the issue. The whole report is also saved in %@.":
        "A issue abre já preenchida. Quando o registro é longo demais para isso, o SideInstaller o copia para você colar no fim da issue. O relatório completo também fica salvo em %@.",
    "Files › On My iPhone": "Arquivos › No Meu iPhone",
    "Copy the full log": "Copiar o registro completo",
    "Paste the log into the issue": "Cole o registro na issue",
    "Open GitHub": "Abrir o GitHub",
    "The full log is too long to fill in, so SideInstaller copied it. On GitHub, tap the end of the text, choose Paste, then submit the issue.":
        "O registro completo é longo demais para ser preenchido, então o SideInstaller o copiou. No GitHub, toque no fim do texto, escolha Colar e envie a issue.",
    "Describe the problem above first.": "Descreva o problema acima primeiro.",
    "Couldn't save the report: %@": "Não foi possível salvar o relatório: %@",

    // MARK: - Official download check

    "Did you download SideInstaller from sideinstaller.net?":
        "Você baixou o SideInstaller de sideinstaller.net?",
    "SideInstaller is open source, so anyone can publish a modified copy that steals the Apple ID typed into it. Only sideinstaller.net is official.":
        "O SideInstaller é de código aberto, então qualquer pessoa pode publicar uma cópia modificada que rouba o Apple ID digitado nela. Somente sideinstaller.net é oficial.",
    "Yes, from sideinstaller.net":
        "Sim, de sideinstaller.net",
    "No, or I'm not sure":
        "Não, ou não tenho certeza",
    "Don't sign in with this copy":
        "Não entre com esta cópia",
    "Copies from anywhere other than sideinstaller.net are unofficial and may have been changed to steal your Apple ID. Delete this one and install SideInstaller from sideinstaller.net, then sign in there.":
        "Cópias de qualquer lugar que não seja sideinstaller.net não são oficiais e podem ter sido alteradas para roubar seu Apple ID. Apague esta, instale o SideInstaller de sideinstaller.net e entre por lá.",
    "Open sideinstaller.net":
        "Abrir sideinstaller.net",
    "Back":
        "Voltar",
    "I understand the risks":
        "Eu entendo os riscos",
    "Use an unofficial copy?":
        "Usar uma cópia não oficial?",
    "If this copy was changed, it can send your Apple ID and password to someone else. Continue only if you trust where it came from.":
        "Se esta cópia foi alterada, ela pode enviar seu Apple ID e sua senha para outra pessoa. Continue apenas se você confia na origem dela.",

    // MARK: - Side by Side: their address, and the pairing file SideInstaller gets

    "Couldn't reach their iPhone at %@. Check the address (Settings › Wi-Fi › ⓘ on their iPhone), that both iPhones are on the same Wi-Fi network, and that Local Network is on for SideInstaller in this iPhone's Settings. Guest and public networks often keep devices from reaching each other.":
        "Não foi possível alcançar o iPhone dele em %@. Confira o endereço (Ajustes › Wi-Fi › ⓘ no iPhone dele), se os dois iPhones estão na mesma rede Wi-Fi e se a Rede Local está ativada para o SideInstaller nos Ajustes deste iPhone. Redes de convidados e redes públicas muitas vezes impedem que os aparelhos se comuniquem.",
    "Their iPhone": "O iPhone dele",
    "They tapped “Don't Trust” on their iPhone. Start again, and have them tap Trust.":
        "Ele tocou em “Não Confiar” no iPhone dele. Comece de novo e peça para ele tocar em Confiar.",
    "Pairs from its Settings": "Pareia pelos Ajustes",
    "Waiting for them to tap Trust…": "Aguardando ele tocar em Confiar…",
    "Tap Trust on their iPhone": "Toque em Confiar no iPhone dele",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "No iPhone dele: Ajustes › Wi-Fi › ⓘ ao lado da rede e depois “Endereço IP”.",
    "Unlock their iPhone, then tap Trust in the prompt that comes up.":
        "Desbloqueie o iPhone dele e toque em Confiar no aviso que aparecer.",
    "This iPhone is %@, so theirs will look similar.": "Este iPhone é %@, então o dele será parecido.",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "“%@” não é um endereço IPv4. Ele deve ser parecido com 192.168.1.42.",
    "Do you have the device's IP?": "Você tem o IP do aparelho?",
    "Optional": "Opcional",
    "SideInstaller asks their iPhone to pair directly. Needed below iOS 27.":
        "O SideInstaller pede ao iPhone dele que se pareie diretamente. Necessário abaixo do iOS 27.",
    "Their iPhone pairs from its own Settings, which needs iOS 27.":
        "O iPhone dele se pareia pelos próprios Ajustes, o que exige o iOS 27.",
    "IP address": "Endereço IP",
    "Their iPhone runs iOS %@. From iOS 26.4 on, SideInstaller can't use the pairing their iPhone gives over Wi-Fi, so it needs a pairing file made on a computer.":
        "O iPhone dele está no iOS %@. A partir do iOS 26.4, o SideInstaller não consegue usar o pareamento que o iPhone dele dá pelo Wi-Fi, então precisa de um arquivo de pareamento feito num computador.",
    "Get LocalDevVPN from the App Store and connect it: SideInstaller works through it.":
        "Baixe o LocalDevVPN na App Store e conecte-o: o SideInstaller funciona por ele.",
    "Open SideInstaller. Its pairing file is already in place.":
        "Abra o SideInstaller. O arquivo de pareamento já está no lugar.",
    "Open SideInstaller and import a pairing file made on a computer.":
        "Abra o SideInstaller e importe um arquivo de pareamento feito num computador.",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone, so use theirs. To install on this one, use the Install tab.":
        "%@ é um endereço que este iPhone já tem. O Side by Side instala no iPhone de outra pessoa, então use o dela. Para instalar neste aqui, use a aba Instalar.",
    "Their iPhone runs iOS %@. From iOS 26.4 on, %@ can't use the pairing their iPhone gives over Wi-Fi. iOS 27 pairs from its own Settings instead, which works: update their iPhone, then try again and answer No when asked for its IP.":
        "O iPhone dele está no iOS %@. A partir do iOS 26.4, o %@ não consegue usar o pareamento que o iPhone dele dá pelo Wi-Fi. O iOS 27 se pareia pelos próprios Ajustes, o que funciona: atualize o iPhone dele e tente de novo, respondendo Não quando o IP for pedido.",

    // MARK: - AltStore

    "couldn't reach %@: %@":
        "não foi possível acessar %@: %@",
    "%@ answered HTTP %d":
        "%@ respondeu HTTP %d",
    "%@'s list of apps couldn't be read (%@). Something on this network may have replaced it.":
        "não foi possível ler a lista de apps de %@ (%@). Algo nesta rede pode tê-la substituído.",
    "the %@ that arrived isn't the file %@ lists, so it isn't installed. Try again later.":
        "o %@ que chegou não é o arquivo listado em %@, então ele não será instalado. Tente de novo mais tarde.",
    "%@ lists no version of %@ that runs on iOS %@.":
        "%@ não lista nenhuma versão do %@ que rode no iOS %@.",
    "Open AltStore from your Home Screen and sign in with your Apple ID.":
        "Abra o AltStore pela Tela de Início e entre com seu Apple ID.",
    "To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings. Its pairing file is already in place, so the setup skips pairing.":
        "Para instalar e renovar apps sem computador, toque em “Set up Remote AltServer” nos ajustes do AltStore. O arquivo de pareamento já está no lugar, então a configuração pula o pareamento.",
    "To install and refresh apps without a computer, tap “Set up Remote AltServer” in AltStore's Settings and follow its steps.":
        "Para instalar e renovar apps sem computador, toque em “Set up Remote AltServer” nos ajustes do AltStore e siga os passos.",
    "Open AltStore and sign in with the same Apple ID.":
        "Abra o AltStore e entre com o mesmo Apple ID.",

    // MARK: - LAN transfer (browser page)

    "File not found": "Arquivo não encontrado",
    "Invalid path": "Caminho inválido",
    "Couldn't parse the upload": "Não foi possível processar o envio",
    "No such page": "Não existe essa página",
    "Download": "Baixar",
    "Download complete": "Download concluído",
    "%@ downloaded. You can install it from the Downloads page.": "%@ baixado. Você pode instalá-lo na página de downloads.",
    "Delete this file?": "Excluir este arquivo?",
    "This directory is empty": "(Este diretório está vazio)",
    "SideInstaller LAN Transfer": "Transferência LAN do SideInstaller",
    "SideInstaller File Transfer": "Transferência de arquivos do SideInstaller",
    "Upload": "Enviar",
    "File": "Arquivo",
    "Size": "Tamanho",
    "Add": "Adicionar",
    "Add Source": "Adicionar fonte",
    "Anyone on your LAN can access it without a password. Turn it off when done.": "Qualquer pessoa na sua LAN pode acessá-lo sem senha. Desligue quando terminar.",
    "Appearance": "Aparência",
    "Apple ID sign-in failed on %@. Last error: %@": "Falha ao entrar com o ID Apple em %@. Último erro: %@",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). Revoke it under Tools › Certificates, then refresh again.": "A Apple não emitirá um certificado de assinatura para este ID Apple: ela informa que já existe um (erro 7460). Revogue-o em Ferramentas › Certificados e atualize novamente.",
    "Auto Refresh": "Atualização automática",
    "Built-in tunnel interface": "Interface do túnel integrado",
    "Built-in tunnel: interface 10.7.1.1/32 and peer 10.7.0.1/32 by default. Address changes take effect the next time the tunnel connects.": "Túnel integrado: interface 10.7.1.1/32 e peer 10.7.0.1/32 por padrão. Alterações de endereço entram em vigor na próxima conexão do túnel.",
    "Certificate password:": "Senha do certificado:",
    "Couldn't reach the device at %@:%d at all. The loopback VPN is most likely off, or Device IP isn't the address it carries: in LocalDevVPN that's the one under Settings › Device IP (10.7.0.1 by default), not the “Connected to” address on its main screen. First check that the phone and the computer are on the same Wi-Fi (the local tunnel needs a local network).": "Não foi possível acessar o dispositivo em %@:%d. O VPN de loopback provavelmente está desligado, ou o IP do dispositivo não é o endereço que ele usa: no LocalDevVPN, é o que está em Ajustes › IP do dispositivo (10.7.0.1 por padrão), não o endereço \"Conectado a\" na tela principal. Primeiro verifique se o telefone e o computador estão no mesmo Wi-Fi (o túnel local precisa de uma rede local).",
    "Dark": "Escuro",
    "Every app and app extension SideInstaller signs needs an App ID. A free Apple ID can register 10 a week, and each one counts for 7 days.": "Cada app e extensão que o SideInstaller assina precisa de um ID de app. Um ID Apple gratuito pode registrar 10 por semana, e cada um vale por 7 dias.",
    "Export certificate (p12)": "Exportar certificado (p12)",
    "Follow System": "Seguir o sistema",
    "Import failed": "Falha na importação",
    "Light": "Claro",
    "Loading…": "Carregando…",
    "Location is not set to “Always”, so only silent audio is keeping the app alive — renewal from the lock screen may be suspended. Set Location to “Always” in Settings.": "A localização não está definida como \"Sempre\", então só o áudio silencioso está mantendo o app ativo — a renovação na tela de bloqueio pode ser suspensa. Defina a localização como \"Sempre\" em Ajustes.",
    "No IPA imported.": "Nenhum IPA importado.",
    "No sources yet. Tap + to add one.": "Ainda não há fontes. Toque em + para adicionar uma.",
    "Refresh apps automatically in background": "Atualizar apps automaticamente em segundo plano",
    "SideInstaller stays alive in the background (silent audio + location) and checks every 30 minutes. Apps whose signing expires within 3 days are re-signed automatically. Location access must be set to “Always” and the tunnel must stay connected (the built-in tunnel is enough). The system also wakes the app in the background from time to time to run a check — don't swipe it away from the app switcher.": "O SideInstaller permanece ativo em segundo plano (áudio silencioso + localização) e verifica a cada 30 minutos. Apps cuja assinatura expira em 3 dias são assinadas novamente automaticamente. O acesso à localização deve estar definido como \"Sempre\" e o túnel deve permanecer conectado (o túnel integrado basta). O sistema também acorda o app em segundo plano de vez em quando para executar uma verificação — não o feche no seletor de apps.",
    "Skipped: not signed by the team you're signed in as, so a certificate-signed app is never re-signed here.": "Ignorado: não assinado pela equipe com a qual você entrou, então um app assinado por certificado nunca é assinado novamente aqui.",
    "Source URL": "URL da fonte",
    "That isn't a usable source link.": "Esse não é um link de fonte utilizável.",
    "The built-in tunnel couldn't start. See the log for the reason, then try again.": "O túnel integrado não pôde iniciar. Veja o registro para saber o motivo e tente novamente.",
    "Transfer files to Documents over LAN": "Transferir arquivos para Documents via LAN",
    "Tunnel peer (device IP)": "Peer do túnel (IP do dispositivo)",
    "Tunnel standby": "Túnel em espera",
    "WebDAV failed to start": "Falha ao iniciar o WebDAV",
    "WebDAV file service": "Serviço de arquivos WebDAV",
    "Wi-Fi not connected": "Wi-Fi não conectado",
    "导出描述文件": "Exportar perfil de provisionamento",
    "导出后可在 LiveContainer 里导入同一张证书，不用再找原文件；密码不一起导出，导入时再填一次。": "Depois de exportar, você pode importar o mesmo certificado no LiveContainer sem procurar o arquivo original; a senha não é exportada, você a digitará novamente na importação.",
    "名字不能以. 开头": "O nome não pode começar com um ponto",
    // SIDE-35 (0.9.124): new keys.
    "Modified edition": "Edição modificada",
    "Archive": "Arquivo",
    "%@ (extracted)": "%@ (extraído)",
    "Source is too large": "A fonte é grande demais",
    "Folders can't be deleted": "As pastas não podem ser excluídas",
    // SIDE-36 (0.9.125): new keys.
    "Couldn't read this source": "Não foi possível ler esta fonte",
    "Listing certificates failed: %@": "Falha ao listar os certificados: %@",
    "Revoke failed: %@": "Falha ao revogar: %@",
    "Couldn't parse p12 export result.": "Não foi possível analisar o resultado da exportação p12.",
    "Export failed: %@": "Falha na exportação: %@",
    "Listing App IDs failed: %@": "Falha ao listar os IDs de app: %@",
    "Enabling entitlements failed: %@": "Falha ao ativar os direitos: %@",
    "Waiting for this install to finish…": "Aguardando esta instalação terminar…",
    "This file is being installed. Wait until it finishes.": "Este arquivo está sendo instalado. Aguarde terminar.",
    "The device answered on the RSD port at %@, then the tunnel port it opened was unreachable on that same address — dropped or refused, across %@. The device is there; what's in front of it is forwarding some ports and not others. The tunnel opens on a fresh high port every attempt, so a rule-based proxy that forwards the RSD port alone can never cover it. Use a loopback VPN that blanket-forwards every port on the RSD subnet. Re-pairing won't help — the pairing is fine.": "O dispositivo respondeu na porta RSD em %@, mas a porta do túnel que ele abriu estava inacessível nesse mesmo endereço — descartada ou recusada, em %@. O dispositivo está lá; o que está na frente só encaminha algumas portas e não outras. O túnel abre em uma porta alta nova a cada tentativa, então um proxy baseado em regras que só encaminha a porta RSD nunca vai cobrir tudo. Use uma VPN de loopback que encaminhe todas as portas da sub-rede RSD. Emparelhar de novo não vai ajudar — o emparelhamento está certo.",
    "The tunnel port never answered and never refused on any address (%@) — the connection is being swallowed rather than rejected. That's usually a VPN or firewall dropping traffic on the RSD subnet. Check the VPN is still up, then try again.": "A porta do túnel nunca respondeu nem recusou em nenhum endereço (%@) — a conexão está sendo engolida em vez de recusada. Isso geralmente é uma VPN ou firewall descartando o tráfego na sub-rede RSD. Verifique se a VPN ainda está ativa e tente novamente.",
    "Something accepted the tunnel connection but failed the encrypted handshake on top of it. Either another process holds that port, or this pairing file's key no longer matches the device. Pair again, and if that doesn't take, restart the loopback VPN.": "Algo aceitou a conexão do túnel, mas falhou no handshake criptografado. Ou outro processo está ocupando essa porta, ou a chave deste arquivo de emparelhamento não corresponde mais ao dispositivo. Emparelhe novamente e, se não resolver, reinicie a VPN de loopback.",
    "The device rejected this pairing file: it's for a different device, or the pairing was revoked (a reset, a restore, or Developer Mode being turned off). Pair with this iPhone again to get a fresh file.": "O dispositivo rejeitou este arquivo de emparelhamento: é de outro dispositivo, ou o emparelhamento foi revogado (uma redefinição, uma restauração ou o Modo de Desenvolvedor desligado). Emparelhe este iPhone novamente para obter um novo arquivo.",
    "The tunnel didn't come up, and the failure didn't match any known cause. The raw error is in the log.": "O túnel não subiu e a falha não corresponde a nenhuma causa conhecida. O erro bruto está no registro.",
    "Diagnostics: remote pairing advertisement: %@; Developer Mode: %@.": "Diagnóstico: anúncio de emparelhamento remoto: %@; Modo de Desenvolvedor: %@.",
    "No anisette servers are configured.": "Nenhum servidor anisette configurado.",
    "Sign-in failed.": "Falha ao entrar.",
    "This folder can't be renamed or moved.": "Esta pasta não pode ser renomeada nem movida.",
    "This file is being signed. Wait until it finishes.": "Este arquivo está sendo assinado. Aguarde terminar.",
    "This file is being renewed. Wait until it finishes.": "Este arquivo está sendo renovado. Aguarde terminar.",
    "This only clears the list. Installed apps are not affected.": "Isso só limpa a lista. Os apps instalados não são afetados.",
    "empty account config": "Configuração da conta vazia",
    "%d files, first %@: %@": "%d arquivos, o primeiro %@ : %@",
    "%@ isn't listed": "%@ não está listado",
    "the data couldn't be read": "Não foi possível ler os dados",
    "Couldn't reach this iPhone. Check the connection and try again.": "Não foi possível conectar a este iPhone. Verifique a conexão e tente novamente.",
    "the connection to this iPhone failed": "a conexão com este iPhone falhou.",

    // MARK: - SIDE-43+44 (0.9.132)
    "This Apple ID has no development team. Sign in at developer.apple.com once to create one, then try again.": "Este ID Apple não tem uma equipe de desenvolvimento. Entre em developer.apple.com uma vez para criar uma e tente novamente.",
    "That certificate belongs to another Apple ID, or it was revoked.": "Esse certificado pertence a outro ID Apple ou foi revogado.",
    "That App ID is no longer on this team.": "Esse ID de app não está mais nesta equipe.",
    "That file isn't a certificate archive (.p12). Check the file and try again.": "Esse arquivo não é um pacote de certificados (.p12). Verifique o arquivo e tente novamente.",
    "There's no signing certificate on this Apple ID yet. Install an app first — that's what creates it.": "Ainda não há certificado de assinatura neste ID Apple. Instale um app primeiro — é a instalação que o cria.",
    "Check the network connection and try again.": "Verifique a conexão de rede e tente novamente.",
    "Apple didn't accept the sign-in. Check the Apple ID and password, then try again.": "A Apple não aceitou o início de sessão. Verifique o ID Apple e a senha e tente novamente.",
    "Sign-ins are being limited right now. Wait a few minutes and try again.": "Os inícios de sessão estão limitados no momento. Aguarde alguns minutos e tente novamente.",
    "Apple's service didn't answer. Try again in a bit.": "O serviço da Apple não respondeu. Tente novamente em instantes.",
    "This iPhone is out of storage space. Free some space and try again.": "Este iPhone está sem espaço de armazenamento. Libere espaço e tente novamente.",
    "A file this step needed is missing. Check the file library and try again.": "Falta um arquivo necessário para esta etapa. Verifique a biblioteca de arquivos e tente novamente.",
    "Something went wrong. Check the activity log and try again.": "Algo deu errado. Verifique o registro de atividades e tente novamente.",
    "Couldn't read the certificate list.": "Não foi possível ler a lista de certificados.",
    "Couldn't read what the import did.": "Não foi possível ler o resultado da importação.",
    "Couldn't read the App ID list.": "Não foi possível ler a lista de IDs de app.",
    "Couldn't read Apple's reply.": "Não foi possível ler a resposta da Apple.",
    "瘦身改包解压失败。": "Falha ao descompactar para redução do pacote.",
    "瘦身改包压包失败。": "Falha ao compactar para redução do pacote.",
    "Pairing file for another iPhone": "Arquivo de pareamento de outro iPhone",
    "This pairing file belongs to another iPhone (UDID %@). The iPhone connected now is %@.": "Este arquivo de pareamento pertence a outro iPhone (UDID %@). O iPhone conectado agora é %@.",
    "The route server couldn't plan this route.": "O servidor de rotas não conseguiu planejar esta rota.",
    "Their iPhone connected but stopped responding before asking for a code. Try pairing again.": "O iPhone deles conectou, mas parou de responder antes de pedir um código. Tente parear novamente.",
    "The pairing code wasn't entered in time. Pair again and enter the code when it appears.": "O código de pareamento não foi digitado a tempo. Pareie novamente e digite o código quando ele aparecer.",
    "Their iPhone rejected this pairing file: it's for a different device, or the pairing was revoked (a reset, a restore, or Developer Mode being turned off). Pair with their iPhone again to get a fresh file.":
        "O iPhone dele rejeitou este arquivo de pareamento: ele pertence a outro aparelho, ou o pareamento foi revogado (uma redefinição, uma restauração ou o Modo de Desenvolvedor desativado). Pareie o iPhone dele novamente para obter um arquivo novo.",
    "Their iPhone answered, but the tunnel port it opened couldn't be reached — something between the two iPhones is forwarding some ports and not others. Check both iPhones are on the same Wi-Fi network (not a guest network), and that Local Network is on for SideInstaller in this iPhone's Settings. Re-pairing won't help — the pairing is fine.":
        "O iPhone dele respondeu, mas não foi possível alcançar a porta do túnel que ele abriu — algo entre os dois iPhones está liberando apenas algumas portas. Confira se os dois iPhones estão na mesma rede Wi-Fi (não uma rede de convidados) e se a Rede Local está ativada para o SideInstaller nos Ajustes deste iPhone. Parear de novo não vai ajudar — o pareamento está bom.",
    "Their iPhone never answered the tunnel port and never refused it — the connection is being swallowed rather than rejected. That's usually the Wi-Fi network or a firewall dropping traffic on the way. Check both iPhones are on the same Wi-Fi network, then try again.":
        "O iPhone dele nunca respondeu à porta do túnel nem a recusou — a conexão está sendo engolida, não rejeitada. Geralmente é a rede Wi-Fi ou um firewall descartando o tráfego no caminho. Confira se os dois iPhones estão na mesma rede Wi-Fi e tente outra vez.",
    "Something accepted the tunnel connection but the encrypted handshake on top of it failed. Either another process holds that port, or this pairing file's key no longer matches their iPhone. Pair again.":
        "Algo aceitou a conexão do túnel, mas o aperto de mão criptografado por cima falhou. Ou outro processo está segurando essa porta, ou a chave deste arquivo de pareamento não corresponde mais ao iPhone dele. Pareie novamente.",
    "GitHub answered HTTP %d":
        "O GitHub respondeu HTTP %d",
    "The code was incorrect. Try again.":
        "O código estava incorreto. Tente novamente.",
    "A code was already sent and is still valid. Enter it.":
        "Um código já foi enviado e ainda é válido. Digite-o.",
    "That way isn't available. Choose another way.":
        "Esse método não está disponível. Escolha outro.",
    "That didn't work. Try another way.":
        "Não funcionou. Tente outro método.",
    // MARK: - Developer team

    "Free · %@": "Gratuita · %@",
    "Paid · %@": "Paga · %@",
    "This Apple Account is on %d developer teams. Pick the one that signs.":
        "Esta conta Apple está em %d equipes de desenvolvimento. Escolha a que assina.",
    "Which Team?": "Qual equipe?",
    "Signed this copy of SideInstaller": "Assinou esta cópia do SideInstaller",
    "A free team's apps last 7 days; a paid team's last a year.":
        "Os apps de uma equipe gratuita duram 7 dias; os de uma equipe paga, um ano.",
    "An app installed with another team isn't replaced: signing it with this one installs a second copy.":
        "Um app instalado com outra equipe não é substituído: assiná-lo com esta instala uma segunda cópia.",
    "SideInstaller remembers the pick for this Apple ID. To pick again, open Settings › Account, swipe the Apple ID left and tap Team.":
        "O SideInstaller lembra a escolha para este Apple ID. Para escolher de novo, abra Ajustes › Conta, deslize o Apple ID para a esquerda e toque em Equipe.",
    "No developer team was picked, so the sign-in stopped.":
        "Nenhuma equipe de desenvolvimento foi escolhida, então o login parou.",
    "Your Apple Account is on more than one developer team. Open SideInstaller and pick the one that signs.":
        "Sua conta Apple está em mais de uma equipe de desenvolvimento. Abra o SideInstaller e escolha a que assina.",
    "Pick the team again?": "Escolher a equipe de novo?",
    "Pick Again": "Escolher de novo",
    "The next sign-in with “%@” asks which developer team signs.":
        "O próximo login com “%@” vai perguntar qual equipe de desenvolvimento assina.",
    // Shortcuts actions (ShortcutsSupport.swift and the *Shortcuts.swift files).
    "%@ can't be refreshed: SideInstaller has no IPA to sign it again from. Refresh it in whatever installed it, or import its .ipa into SideInstaller first.":
        "Não dá para renovar o %@: o SideInstaller não tem o IPA para assiná-lo de novo. Renove-o no app que o instalou, ou importe antes o .ipa dele no SideInstaller.",
    "%@ is installed.":
        "O %@ está instalado.",
    "Apple is asking you to finish signing in. Continue in SideInstaller to answer it.":
        "A Apple está pedindo para você terminar o login. Continue no SideInstaller para responder.",
    "LocalDevVPN is connected.":
        "O LocalDevVPN está conectado.",
    "LocalDevVPN isn't connected. Connect it before this action runs: Shortcuts' Set VPN action can, or turn on “Start LocalDevVPN when needed” in SideInstaller's Settings.":
        "O LocalDevVPN não está conectado. Conecte-o antes de esta ação rodar: a ação de VPN do Atalhos consegue fazer isso. Ou ative “Iniciar o LocalDevVPN quando for preciso” nos Ajustes do SideInstaller.",
    "LocalDevVPN isn't connected. Continue in SideInstaller to connect it.":
        "O LocalDevVPN não está conectado. Continue no SideInstaller para conectá-lo.",
    "No route is playing.":
        "Nenhuma rota está sendo reproduzida.",
    "Open SideInstaller and accept its terms first.":
        "Abra o SideInstaller e aceite os termos dele primeiro.",
    "Pick where the route starts, or set a location first.":
        "Escolha onde a rota começa, ou defina uma localização primeiro.",
    "Route started: %@, about %@.":
        "Rota iniciada: %@, cerca de %@.",
    "That place has no coordinates. Pick it on the map, or type its address.":
        "Esse lugar não tem coordenadas. Escolha-o no mapa ou digite o endereço.",
    "The install didn't start. Open SideInstaller to see why.":
        "A instalação não começou. Abra o SideInstaller para ver o motivo.",

    // MARK: - Sources

    "Suggested":
        "Sugeridas",

    "Paste the link of a SideStore or AltStore source, or of a .json source file. Its apps, their updates and release notes show here.":
        "Cole o link de uma fonte do SideStore ou AltStore, ou de um arquivo de fonte .json. Os apps, as atualizações e as notas de versão aparecem aqui.",
    "Add a source":
        "Adicionar uma fonte",
    "Updates":
        "Atualizações",
    "Update":
        "Atualizar",
    "Your sources":
        "Suas fontes",
    "Check for updates":
        "Verificar atualizações",
    "Copy link":
        "Copiar link",
    "Source options":
        "Opções da fonte",
    "What's new":
        "Novidades",
    "Version history":
        "Histórico de versões",
    "This version has no release notes.":
        "Esta versão não tem notas de versão.",
    "%d update":
        "%d atualização",
    "%d updates":
        "%d atualizações",
    "%d updates · Total size: %@": "%d atualizações · Tamanho total: %@",
    "%d 个可更新": "%d atualizações disponíveis",
    "全部更新进行中，等它跑完再批量安装。":
        "Uma atualização de todos os apps está em andamento. Aguarde terminar antes de instalar em lote.",
    "全部更新进行中，等它跑完再重装。":
        "Uma atualização de todos os apps está em andamento. Aguarde terminar antes de reinstalar.",
    "全部更新进行中，等它跑完再重试。":
        "Uma atualização de todos os apps está em andamento. Aguarde terminar antes de tentar novamente.",
    "全部更新进行中，等它跑完再续签。": "Uma atualização de todos os apps está em andamento. Aguarde terminar antes de renovar.",
    "An update-all batch is running. Wait for it to finish, then try again.":
        "Uma atualização de todos os apps está em andamento. Aguarde terminar e tente novamente.",
    "全部更新进行中，等它跑完再更新。":
        "Uma atualização de todos os apps está em andamento. Aguarde terminar antes de atualizar.",
    "上次刷新失败：%@": "Última atualização falhou: %@",
    "已停止更新：成功 %d 个，剩余 %d 个未更新。":
        "Atualização interrompida: %d com sucesso, %d restantes não atualizados.",
    "%d source":
        "%d fonte",
    "%d sources":
        "%d fontes",
    "Update to %@":
        "Atualizar para %@",
    "Update now": "Atualizar agora",
    "Install %@ %@?":
        "Instalar %@ %@?",
    "Version %@ · from %@":
        "Versão %@ · de %@",
    "%@ installed · %@ available":
        "%@ instalada · %@ disponível",
    "%@ installed · up to date":
        "%@ instalada · atualizada",
    "That source is already added.":
        "Essa fonte já foi adicionada.",
    "The source answered with HTTP %d.":
        "A fonte respondeu com HTTP %d.",
    "Couldn't reach the source: %@":
        "Não foi possível acessar a fonte: %@",
    "That isn't a source link. Paste the whole https:// address of the source.":
        "Isso não é um link de fonte. Cole o endereço https:// completo da fonte.",
    "That link didn't return a source. It has to be the source's JSON file itself.":
        "Esse link não retornou uma fonte. Ele precisa ser o próprio arquivo JSON da fonte.",
    "Downloads the IPA from the source, then signs it with your Apple ID and installs it, as a custom .ipa would be.":
        "Baixa o IPA da fonte, depois o assina com seu Apple ID e o instala, como um .ipa personalizado.",
    "This version is older than the newest one. It's installed over the copy on this iPhone, which may not open data a newer version saved.":
        "Esta versão é mais antiga que a mais recente. Ela é instalada sobre a cópia deste iPhone, que pode não abrir dados salvos por uma versão mais nova.",
    "This version is older than the one on this iPhone (%@). Installed over it, it may not open data the newer version saved.":
        "Esta versão é mais antiga que a deste iPhone (%@). Instalada por cima, ela pode não abrir dados salvos pela versão mais nova.",

    // MARK: - JIT

    "%@ has the JIT memory it asked for, so SideInstaller let go of it. JIT stays on until it quits.":
        "%@ já tem a memória JIT que pediu, então o SideInstaller o soltou. O JIT fica ativo até o app fechar.",
    "%@ of JIT memory prepared": "%@ de memória JIT preparada",
    "%d app can use JIT": "%d app pode usar JIT",
    "%d apps can use JIT": "%d apps podem usar JIT",
    "Attach and detach": "Anexar e desanexar",
    "Attaching the debugger": "Anexando o depurador",
    "Auto: %@": "Automático: %@",
    "Connecting to this iPhone's debugger": "Conectando ao depurador deste iPhone",
    "Couldn't open %@ under the debugger: %@": "Não foi possível abrir %@ com o depurador: %@",
    "Couldn't reach the debugger on this iPhone: %@":
        "Não foi possível acessar o depurador deste iPhone: %@",
    "Enable JIT": "Ativar JIT",
    "Continue JIT for %@": "Continuar JIT para %@",
    "JIT is on for %@ until it quits.": "O JIT está ativo para %@ até ele fechar.",
    "JIT is on. SideInstaller stays attached while %@ runs: keep SideInstaller in the background, since closing it ends JIT.":
        "O JIT está ativo. O SideInstaller fica anexado enquanto %@ roda: deixe o SideInstaller em segundo plano, porque fechá-lo encerra o JIT.",
    "JIT needs Developer Mode. Turn it on under Settings › Privacy & Security › Developer Mode, and confirm it after the restart.":
        "O JIT precisa do Modo de Desenvolvedor. Ative-o em Ajustes › Privacidade e Segurança › Modo de Desenvolvedor e confirme depois de reiniciar.",
    "JIT on for %@": "JIT ativo para %@",
    "Legacy": "Legado",
    "No app on this iPhone is signed for development, which a debugger needs. Install the app with SideStore or SideInstaller, which sign apps that way, then load the apps again.":
        "Nenhum app neste iPhone está assinado para desenvolvimento, que é o que um depurador precisa. Instale o app com o SideStore ou o SideInstaller, que assinam os apps assim, e carregue os apps de novo.",
    "No apps can use JIT": "Nenhum app pode usar JIT",
    "Opening %@": "Abrindo %@",
    "Quit %@": "Fechar %@",
    "The debugger couldn't attach to %@ (%@). Install it again with SideStore or SideInstaller, which sign apps so a debugger can attach.":
        "O depurador não conseguiu se anexar a %@ (%@). Instale-o de novo com o SideStore ou o SideInstaller, que assinam os apps para que um depurador possa se anexar.",
    "The debugger lost %@ (%@). Open it with JIT again.":
        "O depurador perdeu %@ (%@). Abra-o com JIT de novo.",
    "Universal": "Universal",

    // MARK: - Batch install, history empty state & clear-downloads failures (0.9.151)

    "安装所选": "Instalar seleção",
    "正在安装第 %d/%d 个：%@": "Instalando %d/%d: %@",
    "批量安装完成：%d 个已安装。": "Instalação em lote concluída: %d instalados.",
    "批量安装完成：成功 %d 个，失败 %d 个。失败：%@": "Instalação em lote concluída: %d com sucesso, %d com falha. Falhas: %@",
    "等 %d 个": "e mais %d",
    "其中 %d 个不是 IPA，已跳过。": "%d não eram IPA e foram ignorados.",
    "已有安装在进行，先等当前安装完成再批量安装。": "Já há uma instalação em curso. Espere terminar antes da instalação em lote.",
    "已有安装在进行，先等当前安装完成再试。": "Já há uma instalação em curso. Espere terminar e tente novamente.",
    "正在签名，等它跑完再批量安装。": "Assinando. Espere terminar antes da instalação em lote.",
    "Installed apps will be listed here.": "Os apps instalados serão listados aqui.",
    "以下 %d 个删除失败：%@": "Não foi possível excluir %d: %@",

    // MARK: - F1 source toggle, F2 source export/import & F3 download rename (0.9.152)

    "Enabled": "Ativa",
    "Names can't be empty, contain /, or start with .": "Os nomes não podem estar vazios, conter / nem começar com .",
    "Export sources": "Exportar fontes",
    "Import sources": "Importar fontes",
    "The clipboard has no source list to import.": "A área de transferência não tem uma lista de fontes para importar.",
    "Imported %d, already added %d, failed %d.": "%d importadas, %d já adicionadas, %d com falha.",

    // MARK: - F3 update-all, F4 batch move & F5 log export (0.9.154)

    "全部更新": "Atualizar tudo",
    "正在更新第 %d/%d 个：%@": "Atualizando %d/%d: %@",
    "正在读取已装 App…": "A ler as apps instaladas…",
    "全部更新完成：%d 个已更新。": "Atualizações concluídas: %d atualizadas.",
    "全部更新完成：成功 %d 个，失败 %d 个。失败：%@": "Atualizações concluídas: %d com sucesso, %d com falha. Falhas: %@",
    "移动": "Mover",
    "已移动 %d 个。": "%d movidos.",
    "已移动 %d 个，失败 %d 个。失败：%@": "%d movidos, %d com falha. Falhas: %@",
    "导出日志": "Exportar registro",

    // MARK: - F-C download speed/ETA & F-G Wi-Fi only downloads (0.9.156)

    "%@/s": "%@/s",
    "%@ left": "restam %@",
    "Download over cellular?": "Baixar com dados móveis?",
    "Size: %@": "Tamanho: %@",
    "Size unknown": "Tamanho desconhecido",
    "You're on cellular data. This download will use your mobile data.": "Você está usando dados móveis. Este download usará seus dados móveis.",
    "Wi-Fi only downloads": "Downloads somente por Wi-Fi",
    "When on, a download over cellular data asks first, so a large IPA doesn't use your mobile data.": "Quando ativado, um download com dados móveis pergunta primeiro, para que um IPA grande não use seus dados móveis.",
    "Downloads": "Downloads",

    // MARK: - F-3 enterprise certificate expiry notice (0.9.157)

    "Enterprise certificate expiring": "Certificado empresarial prestes a expirar",
    "The enterprise certificate expires on %@. Re-import it in time.": "O certificado empresarial expira em %@. Reimporte-o a tempo.",
    "The enterprise provisioning profile expires on %@. Re-import it in time.": "O perfil de provisionamento empresarial expira em %@. Reimporte-o a tempo.",

    // MARK: - 0.9.159: delete after install, downgrade check, dev-cert notice

    "Delete the IPA after installing": "Excluir o IPA após a instalação",
    "Deletes the source IPA after a successful install. Files used for renewal are kept.": "Exclui o IPA de origem após uma instalação bem-sucedida. Os arquivos usados para renovação são mantidos.",
    "Install an older version?": "Instalar uma versão mais antiga?",
    "Installed: %@ · This IPA: %@": "Instalada: %@ · Este IPA: %@",
    "Couldn't read their iPhone's iOS version. Reconnect and try again — installing without it could put an app their iPhone can't run on it.": "Não foi possível ler a versão do iOS do iPhone deles. Reconecte e tente novamente — instalar sem saber pode colocar um app que o iPhone deles não consegue executar.",
    "Development certificate expiring": "Certificado de desenvolvimento expirando",
    "The development certificate \"%@\" expires on %@. Renew it in time, or installs will fail.": "O certificado de desenvolvimento \"%@\" expira em %@. Renove-o a tempo, ou as instalações falharão.",
    "This IPA asks for %@, which a free Apple ID certificate can't provide. Those features will silently stop working after install.": "Este IPA pede %@, o que um certificado Apple ID gratuito não pode fornecer. Esses recursos pararão de funcionar silenciosamente após a instalação.",
    "Before you install": "Antes de instalar",
    "Reinstall all": "Reinstalar tudo",
    "Reinstall all finished: %d succeeded, %d failed, %d skipped.": "Reinstalação concluída: %d com êxito, %d com falha, %d ignoradas.",
    "Failed: %@": "Falha: %@",
    "Still getting ready. Try again in a moment.": "Ainda preparando. Tente novamente em instantes.",

    // MARK: - 0.9.161: uninstall, clean up old versions, last-checked, partial pairing write

    "Uninstall": "Desinstalar",
    "Uninstall %@?": "Desinstalar %@?",
    "This removes %@ from this iPhone, including its data.": "Isto remove %@ deste iPhone, incluindo os seus dados.",
    "SideInstaller can't uninstall itself.": "O SideInstaller não pode desinstalar-se a si próprio.",
    "Clean up old versions": "Limpar versões antigas",
    "Clean up %d old versions?": "Limpar %d versões antigas?",
    "Only the newest version of each app is kept. Deleted files can't be recovered.": "Só a versão mais recente de cada app é mantida. Os ficheiros eliminados não podem ser recuperados.",
    "Cleaned up %d old versions.": "%d versões antigas limpas.",
    "No old versions to clean up.": "Não há versões antigas para limpar.",
    "%d files skipped (in use or needed for renewal).": "%d ficheiros ignorados (em uso ou necessários para a renovação).",
    "%d files couldn't be deleted: %@": "Não foi possível eliminar %d ficheiros: %@",
    "Checked just now": "Verificado agora mesmo",
    "Checked %d minutes ago": "Verificado há %d minutos",
    "Checked %d hours ago": "Verificado há %d horas",
    "Checked %d days ago": "Verificado há %d dias",
    "Pairing file installed into %@, but couldn't be written into %@.": "Ficheiro de emparelhamento instalado em %@, mas não foi possível escrevê-lo em %@.",

    // 0.9.164
    "Loop route": "Repetir a rota em ciclo",
    "Newer than installed %@": "Mais recente que a instalada %@",
    "Older than installed %@": "Mais antiga que a instalada %@",
    "Same as installed %@": "Igual à instalada %@",
    "Show in Downloads": "Mostrar em Downloads",
    "Still installing — check the Install page for progress.": "Ainda a instalar — consulte a página de instalação para ver o progresso.",
    "Installing — tap to cancel": "A instalar — toque para cancelar",

    // 0.9.166
    "All": "Tudo",
    "Succeeded": "Bem-sucedidos",
    "Restore real location when done": "Restaurar a localização real ao terminar",
    "Import a .gpx file and the device moves along it at the speed you pick. When it ends, the device stays at its last point, unless restoring the real location when done is on.": "Importe um arquivo .gpx e o dispositivo o percorre na velocidade que você escolher. No fim, fica no último ponto, a menos que a restauração da localização real esteja ativada.",
    "移动“%@”？": "Mover \"%@\"?",
    "This is the IPA on the Install tab. Moving it empties that slot — install it from its new folder instead.": "Este é o IPA da aba Instalar. Movê-lo esvazia esse espaço — instale-o a partir da nova pasta.",
    "Move": "Mover",
    "其中 %d 个因拒绝降级而跳过。": "%d foram ignorados por recusarem o downgrade.",

    // 0.9.167
    "Folder": "Pasta",
    "Export history": "Exportar histórico",
    "No files match the current filter.": "Nenhum arquivo corresponde ao filtro atual.",

    // 0.9.174
    "Retry all": "Tentar tudo novamente",
    "Skip": "Pular",
    "Clear all": "Limpar tudo",
    "Clear all failed downloads?": "Limpar todos os downloads com falha?",
    "全部更新进行中，等它跑完再安装。": "Uma atualização de todos os apps está em andamento. Aguarde terminar antes de instalar.",
    "其中 %d 个已跳过。": "Dos quais %d foram ignorados.",

]
