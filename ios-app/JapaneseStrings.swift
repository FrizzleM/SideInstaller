import Foundation

/// Japanese copy, on the same contract as `spanishStrings`. Settings paths
/// and "tap" follow Apple's own ja wording, "revoke" is 失効, and the second
/// person is left implicit wherever natural (no お客様/あなた unless needed).

let japaneseStrings: [String: String] = [

    // MARK: - Shared

    "Cancel": "キャンセル",
    "Copy": "コピー",
    "Email": "メールアドレス",
    "Password": "パスワード",
    "Install": "インストール",
    "Installing": "インストール中",
    "Installed": "インストール済み",
    "Something went wrong": "問題が発生しました",
    "an app by Frizzle": "Frizzle 制作のアプリ",
    "device": "デバイス",

    // MARK: - Welcome

    "I have accepted the": "同意します：",
    "Start": "開始",

    // Pre-iOS 27: the pairing file has to be imported

    "You'll need a pairing file": "ペアリングファイルが必要です",
    "This iPhone runs iOS %@. Only iOS %@ can pair with itself, so you'll have to make a pairing file on a computer — with jitterbugpair or pymobiledevice3 — and import it in the app. SideInstaller walks you through it.":
        "この iPhone は iOS %@ で動作しています。自分自身とペアリングできるのは iOS %@ 以降のみのため、パソコンで jitterbugpair または pymobiledevice3 を使ってペアリングファイルを作成し、アプリにインポートする必要があります。手順は SideInstaller が案内します。",

    // MARK: - Account setup & Settings › Account

    "Sign in with your Apple ID": "Apple ID でサインイン",
    "Don't worry, these are stored locally":
        "ご安心ください。これらの情報は端末内にのみ保存されます",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in.":
        "この iPhone のキーチェーンに保存され、サインイン時にのみ Apple に送信されます。",
    "Continue": "続ける",
    "Set this up later": "あとで設定する",
    "Add Apple ID": "Apple ID を追加",
    "Edit Apple ID": "Apple ID を編集",
    "Save": "保存",
    "Enter the password again to save this Apple ID.": "この Apple ID を保存するには、パスワードをもう一度入力してください。",
    "Account": "アカウント",
    "In use": "使用中",
    "Edit": "編集",
    "Remove": "削除",
    "No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in.":
        "保存された Apple ID はまだありません。追加すると、SideInstaller はサインインのたびにそれを使用します。",
    "Saved in this iPhone's keychain, and sent only to Apple when signing in. Swipe a row to edit its password or remove it.":
        "この iPhone のキーチェーンに保存され、サインイン時にのみ Apple に送信されます。行を左にスワイプするとパスワードの編集や削除ができます。",
    "Remove this Apple ID?": "この Apple ID を削除しますか？",
    "“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.":
        "「%@」と保存されているパスワードがこの iPhone から削除されます。Apple アカウント自体には影響ありません。",
    "This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.":
        "この iPhone のキーチェーンがパスワードの保存を拒否したため（エラー %d）、SideInstaller を終了するまでの間だけ保持されます。",
    "No Apple ID saved. Add one in Settings › Account.": "保存された Apple ID がありません。「設定 › アカウント」で追加してください。",

    "Add your Apple ID": "Apple ID を追加",
    "Open Settings with the gear at the top right.": "右上の歯車アイコンから設定を開きます。",
    "Under Account, tap “Add Apple ID” and enter your email and password.":
        "「アカウント」で「Apple ID を追加」をタップし、メールアドレスとパスワードを入力します。",

    // MARK: - Tabs, Tools menu & two-factor prompt

    "Tools": "ツール",

    // MARK: - Tabs & two-factor prompt

    "Pairing": "ペアリング",
    "Certificates": "証明書",
    "Two-Factor Code": "二段階認証コード",
    "6-digit code": "6 桁のコード",
    "Submit": "送信",
    "Enter the code Apple just sent to your trusted device.":
        "信頼できるデバイスに Apple から送信されたコードを入力してください。",

    // MARK: - Install tab

    "Tunnel connected": "トンネル接続済み",
    "Tunnel off": "トンネル未接続",
    "Update available": "アップデートがあります",
    "SideInstaller %@ is available — you're on %@.":
        "SideInstaller %@ が公開されています（現在お使いのバージョン：%@）。",
    "Get the latest version": "最新バージョンを取得",
    "Release": "チャンネル",
    "Reinstall": "再インストール",
    "Install %@": "%@ をインストール",
    "Custom .ipa": "カスタム .ipa",
    "Import .ipa": ".ipa をインポート",
    "Importing…": "インポート中…",
    "Replace": "置き換え",
    "or": "または",
    "Paste a download link": "ダウンロードリンクを貼り付け",
    "Downloading… %d%%": "ダウンロード中… %d%%",
    "iOS %@ required": "iOS %@ が必要です",
    "This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.":
        "この iPhone は iOS %@ で動作しており、SideInstaller ではインストールできません。「設定 › 一般 › ソフトウェア・アップデート」から iOS %@ 以降に更新してください。",
    "Wi-Fi required": "Wi-Fi が必要です",
    "Pairing code": "ペアリングコード",
    "Type this into the prompt in Settings.":
        "この番号を「設定」のダイアログに入力してください。",
    "Install stopped": "インストールが停止しました",
    "%@ is installed. Finish the trust step above to open it.":
        "%@ はインストールされています。上記の信頼手順を完了すると開けます。",
    "Action needed": "対応が必要です",
    "Step %@ of %@": "手順 %@／%@",
    "Show all steps": "すべての手順を表示",
    "Show fewer steps": "手順を折りたたむ",

    // MARK: - LocalDevVPN

    "LocalDevVPN required": "LocalDevVPN が必要です",
    "Install LocalDevVPN and connect it. The install runs over its tunnel.":
        "LocalDevVPN をインストールして接続してください。インストールはこのトンネル経由で行われます。",
    "Connect LocalDevVPN to scan and install. The write runs over its tunnel.":
        "スキャンとインストールを行うには LocalDevVPN を接続してください。書き込みはこのトンネル経由で行われます。",
    "Connect LocalDevVPN. Spoofing runs over its tunnel, like everything else here.":
        "LocalDevVPN を接続してください。位置情報の偽装も、ここでの他の処理と同様にこのトンネル経由で行われます。",
    "LocalDevVPN isn't connected. Connect it, then try again.": "LocalDevVPN が接続されていません。接続してから再度お試しください。",
    "Connect LocalDevVPN": "LocalDevVPN を接続",
    "Install LocalDevVPN from the App Store and open it.": "App Store から LocalDevVPN をインストールして開いてください。",
    "If GitHub is blocked where you are, use a VPN that can proxy your traffic too: iOS runs one VPN at a time, so a local-only tunnel leaves nothing to download SideStore through.":
        "お住まいの地域で GitHub がブロックされている場合は、通信もプロキシできる VPN を使用してください。iOS では一度に 1 つの VPN しか動作しないため、ローカル通信専用のトンネルだけでは SideStore をダウンロードする経路がなくなってしまいます。",

    // MARK: - Install steps

    "Connect the VPN": "VPN を接続",
    "Get pairing file": "ペアリングファイルを取得",
    "Open the device link": "デバイスへの接続を開く",
    "Sign in to Apple ID": "Apple ID でサインイン",
    "Download %@": "%@ をダウンロード",
    "Use your imported IPA": "インポート済みの IPA を使用",
    "Sign the app": "アプリに署名",
    "Finish setup": "設定を完了",

    // MARK: - Pairing tab

    "Pairing file ready": "ペアリングファイルの準備ができました",
    "No pairing file": "ペアリングファイルがありません",
    "Pairing file": "ペアリングファイル",
    "Pairing…": "ペアリング中…",
    "Regenerate": "再生成",
    "Generate pairing file": "ペアリングファイルを生成",
    "Export pairing file": "ペアリングファイルを書き出す",
    "Pair in Settings": "「設定」でペアリング",
    "Install into an app": "アプリにインストール",
    "Scanning": "スキャン中",
    "Rescan apps": "アプリを再スキャン",
    "Scan installed apps": "インストール済みアプリをスキャン",
    "%d supported app installed": "対応アプリが %d 個インストールされています",
    "%d supported apps installed": "対応アプリが %d 個インストールされています",
    "No supported apps found": "対応アプリが見つかりません",
    "Install an app like SideStore, StikDebug, or Feather first, then rescan.":
        "先に SideStore、StikDebug、Feather などのアプリをインストールしてから、再度スキャンしてください。",
    "Install pairing": "ペアリングをインストール",
    "Pairing file ready. You can export it or install it into an app below.":
        "ペアリングファイルの準備ができました。書き出すか、以下のアプリにインストールできます。",
    "Pairing file installed into %@.": "ペアリングファイルを %@ にインストールしました。",

    // Importing a pairing file (iOS 26 and below)

    "Import pairing file": "ペアリングファイルをインポート",
    "How do I make one?": "作成方法は？",
    "imported pairing file": "インポート済みのペアリングファイル",
    "No pairing file yet — tap “Import pairing file” first.": "まだペアリングファイルがありません。先に「ペアリングファイルをインポート」をタップしてください。",
    "Pairing file missing — import it first.": "ペアリングファイルがありません。先にインポートしてください。",
    "%@ isn't a pairing file. Pick the file your computer made — a .mobiledevicepairing or .plist holding this iPhone's pair record.":
        "%@ はペアリングファイルではありません。パソコンで作成した、この iPhone のペアリング情報を含む .mobiledevicepairing または .plist ファイルを選択してください。",
    "iOS %@ can't create its own pairing file — that needs iOS %@. Import one made on a computer under “Pairing file”, then try again.":
        "iOS %@ は自分自身のペアリングファイルを作成できません。それには iOS %@ 以降が必要です。「ペアリングファイル」からパソコンで作成したファイルをインポートしてから、再度お試しください。",

    // MARK: - Pairing service status

    "not paired": "未ペアリング",
    "connected": "接続済み",
    "requesting Local Network…": "ローカルネットワークの許可を要求中…",
    "Local Network denied": "ローカルネットワークの許可が拒否されました",
    "waiting for device…": "デバイスを待機中…",
    "advertising — open Settings › Privacy & Security › Developer Mode":
        "アドバタイズ中 —「設定 › プライバシーとセキュリティ › デベロッパモード」を開いてください",
    "enter PIN %@ in Settings": "「設定」で PIN コード %@ を入力してください",
    "paired: %@ (%dB)": "ペアリング済み：%@（%d バイト）",
    "failed: empty pairing file": "失敗：ペアリングファイルが空です",
    "failed: %@": "失敗：%@",
    "Pairing is already in progress.": "ペアリングは既に進行中です。",
    "Local Network permission is off. Enable it in Settings › SideInstaller › Local Network, then try again.":
        "ローカルネットワークの許可がオフになっています。「設定 › SideInstaller › ローカルネットワーク」で有効にしてから、再度お試しください。",
    "Pairing produced an empty file. Make sure you approved the pairing request, then try again.":
        "ペアリングの結果、空のファイルが生成されました。ペアリングの要求を承認したことを確認してから、再度お試しください。",

    // MARK: - Certificates tab

    "Revoke this certificate?": "この証明書を失効させますか？",
    "Revoke": "失効させる",
    "Revoking": "失効処理中",
    "“%@” will be revoked. Apps already signed with it will stop launching on every device. This can't be undone.":
        "「%@」が失効します。この証明書で署名済みのアプリは、すべてのデバイスで起動できなくなります。この操作は取り消せません。",
    "Refreshing": "更新中",
    "Signing in": "サインイン中",
    "Refresh": "更新",
    "Load certificates": "証明書を読み込む",
    "%d certificate(s)": "証明書 %d 件",
    "No certificates": "証明書がありません",
    "This Apple ID has no development certificates to revoke.":
        "この Apple ID には失効させる開発用証明書がありません。",
    "Expired": "期限切れ",
    "Expires %@": "%@ に期限切れ",
    "Unnamed certificate": "名前のない証明書",
    "This certificate has no serial number, so it can't be revoked.":
        "この証明書にはシリアル番号がないため、失効させることができません。",

    // MARK: - Location tab

    "Location spoofing": "位置情報の偽装",
    "Not simulating": "偽装していません",
    "Simulated": "位置情報を偽装中",
    "Pick a place": "場所を選択",
    "Search for a place": "場所を検索",
    "Nothing found for “%@”.": "「%@」の検索結果はありませんでした。",
    "Set location": "位置情報を設定",
    "Setting": "設定中",
    "Reset to real location": "実際の位置情報に戻す",
    "Location set to %@.": "位置情報を %@ に設定しました。",
    "Location reset. The device is using its own again.": "位置情報をリセットしました。デバイスは再び本来の位置情報を使用します。",
    "That isn't a valid coordinate.": "有効な座標ではありません。",
    "Location session closed — set it up again.": "位置情報のセッションが終了しました。もう一度設定してください。",
    "Downloading %@ failed (HTTP %d).": "%@ のダウンロードに失敗しました（HTTP %d）。",
    "Couldn't build the download URL for %@.": "%@ のダウンロード URL を作成できませんでした。",

    // MARK: - Entitlements tab

    "Entitlements": "エンタイトルメント",
    "Load apps": "アプリを読み込む",
    "%d App ID": "App ID %d 件",
    "%d App IDs": "App ID %d 件",
    "No App IDs": "App ID がありません",
    "This Apple ID hasn't registered any apps yet. Install something with SideInstaller first, then come back.":
        "この Apple ID にはまだ登録されたアプリがありません。先に SideInstaller で何かインストールしてから戻ってきてください。",
    "Memory and performance": "メモリとパフォーマンス",
    "Other free capabilities": "その他の無料機能",
    "Beta": "ベータ",
    "Recommended": "推奨",
    "Select all": "すべて選択",
    "None": "選択解除",
    "Enable %d selected": "選択した %d 項目を有効化",
    "Asking Apple": "Apple に問い合わせ中",
    "%d of %d enabled": "%d／%d 件が有効",
    "Install the app again for these to take effect.": "これらの変更を反映するには、アプリを再インストールしてください。",

    // MARK: - Sideloaded apps tab

    "Sideloaded apps": "サイドロード済みアプリ",
    "Reading the device": "デバイスを読み取り中",
    "%d app": "アプリ %d 個",
    "%d apps": "アプリ %d 個",
    "%d app needs refreshing": "%d 個のアプリに更新が必要です",
    "%d apps need refreshing": "%d 個のアプリに更新が必要です",
    "No sideloaded apps": "サイドロード済みアプリがありません",
    "Nothing on this device was installed with a provisioning profile. App Store apps don't expire, so they aren't listed here.":
        "このデバイスにはプロビジョニングプロファイルでインストールされたアプリがありません。App Store のアプリは期限切れにならないため、ここには表示されません。",
    "No matching profile": "一致するプロファイルがありません",
    "Expires today": "本日期限切れ",
    "Expires tomorrow": "明日期限切れ",
    "Expires in %d days — %@": "あと %d 日で期限切れ — %@",
    "Expired %@": "%@ に期限切れ",
    "Unused profiles": "未使用のプロファイル",
    "Issued to App IDs no installed app is running on.":
        "インストール済みのアプリが使用していない App ID に発行されたものです。",
    "Older profiles": "古いプロファイル",
    "Bundle identifier": "バンドル識別子",
    "App ID": "App ID",
    "Version": "バージョン",
    "Profile name": "プロファイル名",
    "Team": "チーム",
    "Team ID": "チーム ID",
    "Issued": "発行日時",
    "Profile UUID": "プロファイル UUID",
    "Capabilities": "機能",
    "Wildcard App ID — it covers any bundle id under it, and can't carry app-specific capabilities.":
        "ワイルドカード App ID：配下のあらゆるバンドル ID をカバーするため、アプリ固有の機能を持たせることはできません。",
    "The device has no provisioning profile for this App ID. The app may already have stopped launching — install it again to fix that.":
        "デバイスにこの App ID 用のプロビジョニングプロファイルがありません。アプリが既に起動できなくなっている可能性があります。再インストールすれば解決します。",

    // MARK: - Settings

    "Settings": "設定",
    "Done": "完了",
    "Language": "言語",
    "App language": "アプリの言語",
    "Auto": "自動",
    "Downloaded IPAs": "ダウンロード済みの IPA",
    "%@ used": "%@ を使用中",
    "imported": "インポート済み",
    "No downloaded IPAs. Ones you install from the Install tab are cached here.":
        "ダウンロード済みの IPA はありません。「インストール」タブからインストールしたものがここにキャッシュされます。",
    "Downloaded %@": "%@ にダウンロード",
    "Added %@": "%@ に追加",
    "Delete this download?": "このダウンロードを削除しますか？",
    "Delete": "削除",
    "“%@” (%@) will be removed. You can download it again any time from the Install tab.":
        "「%@」（%@）が削除されます。「インストール」タブからいつでも再ダウンロードできます。",
    "Couldn't delete %@: %@": "%@ を削除できませんでした：%@",
    "Server": "サーバー",
    "Custom…": "カスタム…",
    "Server URL": "サーバー URL",
    "Anisette Server": "Anisette サーバー",
    "Device IP": "デバイス IP",
    "Advanced": "詳細設定",
    "Clear": "消去",
    "Activity Log (%d)": "アクティビティログ（%d）",

    // MARK: - Release channels & downloads

    "Stable": "安定版",
    "Nightly": "Nightly",
    "couldn't find the IPA in the %@ %@ release":
        "%@ チャンネルの %@ リリースに IPA が見つかりませんでした",
    "%@ has no %@ release right now": "%@ には現在 %@ リリースがありません",
    "bad asset URL": "ダウンロードリソースの URL が不正です",
    "GitHub is rate-limiting this network — it isn't blocked, and the limit clears itself. Try again %@.":
        "このネットワークからのアクセスが GitHub によりレート制限されています。ブロックされているわけではなく、制限は自動的に解除されます。%@ 後に再度お試しください。",
    "GitHub answered HTTP %d%@": "GitHub の応答：HTTP %d%@",
    "couldn't reach GitHub: %@": "GitHub に接続できませんでした：%@",
    "GitHub's answer wasn't release information (%@) — something on this network may have replaced it.":
        "GitHub の応答がリリース情報ではありませんでした（%@）。このネットワーク上の何かが内容を置き換えている可能性があります。",
    "what downloaded as %@ isn't an IPA — something on this network returned a page instead, or the transfer stopped partway.":
        "%@ としてダウンロードされたものは IPA ではありません。このネットワーク上の何かがページを返したか、転送が途中で中断された可能性があります。",
    "that link answered HTTP %d — it isn't a direct download, or it needs a sign-in.":
        "そのリンクの応答は HTTP %d でした。直接ダウンロードできるリンクではないか、サインインが必要です。",

    // MARK: - Engine failures

    "Two-factor verification was cancelled.": "二段階認証がキャンセルされました。",
    "Incorrect Apple ID or password. Check your Apple Account email and password, then try again.":
        "Apple ID またはパスワードが正しくありません。Apple アカウントのメールアドレスとパスワードを確認してから、再度お試しください。",
    "Apple ID sign-in failed on %@. Last error: %@":
        "%@ での Apple ID サインインに失敗しました。直近のエラー：%@",
    "the anisette server": "anisette サーバー",
    "all %d anisette servers": "%d 個すべての anisette サーバー",
    "Not signed in.": "サインインしていません。",
    "No SideStore IPA downloaded.": "SideStore の IPA がダウンロードされていません。",
    "Signing failed: %@": "署名に失敗しました：%@",
    "No signed bundle to install.": "インストールできる署名済みのバンドルがありません。",
    "Device link dropped — reconnect.":
        "デバイスとの接続が切断されました。再接続してください。",
    "Pairing didn't finish — no pairing file yet.":
        "ペアリングが完了していません。まだペアリングファイルがありません。",
    "Pairing file missing — pairing must run first.":
        "ペアリングファイルがありません。先にペアリングを行う必要があります。",
    "Pairing file missing — generate it first.":
        "ペアリングファイルがありません。先に生成してください。",
    "No pairing file yet — tap “Generate pairing file” first.":
        "まだペアリングファイルがありません。先に「ペアリングファイルを生成」をタップしてください。",
    "%@ isn't installed yet — install must run first.":
        "%@ はまだインストールされていません。先にインストールを行う必要があります。",
    "%@ isn't a valid IPA — the download it came from probably returned an error page, or the copy stopped partway. Replace it and tap Install again.":
        "%@ は有効な IPA ではありません。ダウンロード元がエラーページを返したか、コピーが途中で中断された可能性があります。差し替えてから、もう一度「インストール」をタップしてください。",
    "%@ isn't an IPA. Pick the .ipa file itself — if it looks right, the download may have saved an error page instead, or stopped partway.":
        "%@ は IPA ではありません。.ipa ファイル自体を選択してください。問題なさそうに見える場合は、ダウンロード時にエラーページが保存されたか、途中で中断された可能性があります。",
    "No IPA imported yet. Tap “Import .ipa” and pick one.":
        "まだ IPA がインポートされていません。「.ipa をインポート」をタップして選択してください。",
    "Couldn't import %@: %@": "%@ をインポートできませんでした：%@",
    "That isn't a link SideInstaller can download. Paste the whole https:// address the .ipa downloads from.":
        "SideInstaller がダウンロードできるリンクではありません。.ipa のダウンロード元となる https:// で始まる完全なアドレスを貼り付けてください。",
    "That link didn't return an IPA. It has to download the file itself — a page that only links to the .ipa, or one that asks you to sign in first, arrives here as a web page.":
        "そのリンクは IPA を返しませんでした。ファイル自体を直接ダウンロードできるリンクである必要があります。.ipa へのリンクを掲載しているだけのページや、先にサインインを求めるページは、ここでは単なる Web ページとして扱われます。",
    "Couldn't download that link: %@": "そのリンクをダウンロードできませんでした：%@",
    "there's nothing to download for a custom IPA — import one first":
        "カスタム IPA にはダウンロードする内容がありません。先にインポートしてください",
    "your app": "お使いのアプリ",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists, or that a request for one is still pending (error 7460). SideInstaller couldn't reuse the certificate that's already there, so it stopped instead of replacing it. See the steps above.":
        "Apple はこの Apple ID に署名用証明書を発行しません。既に証明書が存在するか、発行のリクエストが処理中であると報告されています（エラー 7460）。SideInstaller は既存の証明書を再利用できなかったため、それを置き換えずに処理を停止しました。上記の手順をご覧ください。",
    " (UDID %@)": "（UDID %@）",
    "Couldn't register this iPhone%@ with your Apple ID's developer team, so Apple won't issue a provisioning profile. %@ — see the steps above.":
        "この iPhone%@ を Apple ID の Developer チームに登録できなかったため、Apple はプロビジョニングプロファイルを発行しません。%@ — 上記の手順をご覧ください。",
    "Connect to Wi-Fi": "Wi-Fi に接続",
    "Open Settings › Wi-Fi and join a network.": "「設定 › Wi-Fi」を開き、ネットワークに接続してください。",
    "Then come back here — this continues automatically.": "その後こちらに戻ってください。続きは自動的に進みます。",
    "Tap Connect so the toggle turns on.": "「Connect」をタップしてスイッチをオンにしてください。",
    "Keep Wi-Fi on, then come back here — this continues automatically.":
        "Wi-Fi をオンのままにして、こちらに戻ってください。続きは自動的に進みます。",
    "Get LocalDevVPN": "LocalDevVPN を入手",
    "Import an .ipa first": "先に .ipa をインポートしてください",
    "Tap “Import .ipa” above and pick the file — it can live anywhere the Files app can reach, including iCloud Drive or a USB drive.":
        "上の「.ipa をインポート」をタップしてファイルを選択してください。iCloud Drive や USB ドライブなど、「ファイル」アプリからアクセスできる場所であればどこでも構いません。",
    "Or paste a direct download link under that button, and SideInstaller fetches the .ipa itself.":
        "または、そのボタンの下にダウンロードリンクを直接貼り付ければ、SideInstaller が自動的に .ipa を取得します。",
    "Or open the Files app, press and hold the .ipa, tap Share, and pick SideInstaller — that hands the file over without the picker.":
        "または「ファイル」アプリを開き、.ipa を長押しして「共有」をタップし、SideInstaller を選択してください。ファイル選択画面を経由せずに渡せます。",
    "Or copy it into Files › On My iPhone › SideInstaller, where SideInstaller also finds it.":
        "あるいは「ファイル › このiPhone内 › SideInstaller」にコピーしておいても、SideInstaller が見つけられます。",
    "This is the way in where GitHub is blocked: fetch the IPA on any device, bring it over, and install it here.":
        "GitHub がブロックされている環境では、この方法が有効です。別のデバイスで IPA を取得し、こちらに持ってきてインストールしてください。",
    "Pair this iPhone in Settings": "「設定」でこの iPhone をペアリング",
    "Open the Settings app, then go to Privacy & Security › Developer Mode.":
        "「設定」アプリを開き、「プライバシーとセキュリティ › デベロッパモード」に進んでください。",
    "Tap “Pair with SideInstaller”.": "「SideInstaller とペアリング」をタップしてください。",
    "Enter your iPhone’s passcode if it asks for it.": "パスコードの入力を求められた場合は、iPhone のパスコードを入力してください。",
    "Come back to SideInstaller, read the code it shows you, then type that same code into the prompt in Settings.":
        "SideInstaller に戻り、表示されているコードを確認したら、同じコードを「設定」のダイアログに入力してください。",
    "A signing certificate already exists": "既に署名用証明書が存在します",
    "Apple returned error 7460: this Apple ID already has an iOS development certificate, or a request for one is still pending.":
        "Apple からエラー 7460 が返されました。この Apple ID には既に iOS 開発用証明書が存在するか、発行のリクエストが処理中です。",
    "SideInstaller couldn't reuse it. That happens when the certificate was issued somewhere else — AltStore, SideStore, Sideloadly or Xcode on another device — so the private key it needs isn't on this iPhone.":
        "SideInstaller はその証明書を再利用できませんでした。これは、証明書が他の場所（別のデバイスの AltStore、SideStore、Sideloadly、Xcode など）で発行された場合に起こります。必要な秘密鍵がこの iPhone にないためです。",
    "Use “Revoke and retry” above, or open Certificates in the Tools tab, tap “Load certificates”, and revoke it there.":
        "上の「失効させて再試行」を使うか、「ツール」タブの「証明書」を開いて「証明書を読み込む」をタップし、そこで失効させてください。",
    "Revoking is permanent: every app already signed with that certificate stops launching, on every device.":
        "証明書の失効は取り消せません。その証明書で署名済みのすべてのアプリが、すべてのデバイスで起動できなくなります。",
    "Alternatively, sign in with a different (or spare) Apple ID above, then tap Install again.":
        "または、上で別の（もしくは予備の）Apple ID でサインインしてから、もう一度「インストール」をタップしてください。",

    // MARK: - Guide cards

    // Guide: import a pairing file

    "Import a pairing file": "ペアリングファイルをインポート",
    "iOS %@ is the first version an iPhone can pair with itself on. On this one the pairing file has to be made on a computer.":
        "iOS %@ は、iPhone が自分自身とペアリングできるようになった最初のバージョンです。それ以前のバージョンでは、ペアリングファイルをパソコンで作成する必要があります。",
    "On a Mac, Windows PC or Linux box, plug this iPhone in, trust the computer, and run jitterbugpair (or “pymobiledevice3 lockdown pair”).":
        "Mac、Windows パソコン、または Linux マシンにこの iPhone を接続し、そのコンピュータを信頼したうえで、jitterbugpair（または「pymobiledevice3 lockdown pair」）を実行してください。",
    "Send the file it writes — a .mobiledevicepairing or .plist — to this iPhone, by AirDrop, iCloud Drive or a cable.":
        "生成されたファイル（.mobiledevicepairing または .plist）を、AirDrop、iCloud Drive、またはケーブルでこの iPhone に転送してください。",
    "Come back here, tap “Import pairing file”, and pick it. Everything after that works as it does on iOS %@.":
        "こちらに戻り、「ペアリングファイルをインポート」をタップして選択してください。それ以降の流れは iOS %@ と同じです。",
    "Get jitterbugpair": "jitterbugpair を入手",

    // MARK: - Revoke-and-retry (Apple error 7460)

    "A certificate already exists": "既に証明書が存在します",
    "Apple won't issue a second signing certificate for this Apple ID. Revoking the one it already has lets the install continue — but it can't be undone.":
        "Apple はこの Apple ID に 2 つ目の署名用証明書を発行しません。既存の証明書を失効させればインストールを続行できますが、この操作は取り消せません。",
    "Loading certificates": "証明書を読み込み中",
    "Revoke and retry": "失効させて再試行",
    "Which certificate should be revoked?": "どの証明書を失効させますか？",
    "Apple reports a certificate on this Apple ID, but none came back in the list. It may be a request that's still pending — wait a few minutes and tap Install again.":
        "Apple はこの Apple ID に証明書があると報告していますが、一覧には表示されませんでした。発行リクエストがまだ処理中の可能性があります。数分待ってから、もう一度「インストール」をタップしてください。",
    "Every app already signed with the certificate you pick will stop launching, on every device — including apps installed by AltStore, SideStore, or a computer. This can't be undone. The install retries straight afterwards.":
        "選択した証明書で署名済みのすべてのアプリが、AltStore、SideStore、パソコンでインストールしたものも含め、すべてのデバイスで起動できなくなります。この操作は取り消せません。失効後、インストールは自動的に再試行されます。",
    " (expired)": "（期限切れ）",

    "Couldn't register this device": "このデバイスを登録できませんでした",
    "Your Apple ID has hit its limit of registered devices. Free accounts can only register a handful of devices per year and can't remove old ones until the year resets.":
        "この Apple ID は登録デバイス数の上限に達しています。無料アカウントでは年間に登録できるデバイス数がわずかで、年が切り替わるまで古いデバイスを削除することもできません。",
    "Easiest fix: put a different (or spare) Apple ID in the fields above, then tap Install again.":
        "最も簡単な解決方法は、上の入力欄に別の（もしくは予備の）Apple ID を入力し、もう一度「インストール」をタップすることです。",
    "SideInstaller couldn't add this iPhone to your Apple ID's developer team automatically. Tapping Install again often works — Apple's developer service is sometimes briefly unavailable.":
        "SideInstaller はこの iPhone を Apple ID の Developer チームに自動で追加できませんでした。もう一度「インストール」をタップすると成功することがよくあります。Apple の開発者向けサービスが一時的に利用できないことがあるためです。",
    "If it keeps failing, add the device by hand. Its UDID is:":
        "それでも失敗する場合は、手動でデバイスを追加してください。UDID は次のとおりです：",
    "Paste that into the “Register a Device” form in the Apple Developer portal (this requires a paid Apple Developer account), then tap Install again.":
        "それを Apple Developer サイトの「Register a Device」フォームに貼り付けてください（有料の Apple Developer アカウントが必要です）。その後、もう一度「インストール」をタップしてください。",
    "Open device list": "デバイス一覧を開く",

    "Last step: trust %@": "最後の手順：%@ を信頼",
    "Open Settings › General › VPN & Device Management.":
        "「設定 › 一般 › VPN とデバイス管理」を開いてください。",
    "Tap your Apple ID under “Developer App”, then tap Trust.":
        "「デベロッパ App」の下にある自分の Apple ID をタップし、「信頼」をタップしてください。",
    "Open %@ from your Home Screen — you're done.":
        "ホーム画面から %@ を開けば完了です。",

    "Import the certificate into LiveContainer": "証明書を LiveContainer にインポート",
    "Open LiveContainer from your Home Screen.": "ホーム画面から LiveContainer を開いてください。",
    "Tap the Settings tab.": "「Settings」タブをタップしてください。",
    "Tap “Import Certificate From SideStore”.":
        "「Import Certificate From SideStore」をタップしてください。",
    "Wrong device IP": "デバイス IP が正しくありません",
    "The address in Settings › Advanced › Device IP is one this iPhone already holds, so there's nothing at the other end to connect to.":
        "「設定 › 詳細設定 › デバイス IP」に入力されているアドレスは、この iPhone が既に持っているものです。そのため、接続先が存在しません。",
    "Set it back to 10.7.0.1, the default. In LocalDevVPN that's the value under Settings › Device IP — not the address on its main screen, which is the tunnel's own end.":
        "初期値の 10.7.0.1 に戻してください。LocalDevVPN では、これは「Settings › Device IP」にある値です。メイン画面に表示されているアドレス（トンネル自身の端点）とは異なります。",
    "If you changed LocalDevVPN's addresses, copy its Device IP here — including the /32, if it shows one.":
        "LocalDevVPN のアドレスを変更している場合は、その Device IP をここにコピーしてください。末尾に /32 が付いていれば、そのまま含めて構いません。",
    "Pairing this iPhone needs it: SideInstaller advertises itself on the local network for Settings to find.":
        "この iPhone のペアリングには Wi-Fi が必要です。SideInstaller は「設定」アプリから見つけてもらうために、ローカルネットワーク上で自身をアドバタイズします。",
    "Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network.":
        "Wi-Fi ネットワークに接続してください。この iPhone のペアリングには、SideInstaller がローカルネットワーク上で見つけられる状態である必要があります。",

    // MARK: - Side by Side tool

    // The tool's name is left in English everywhere, as SideStore's is.
    "Side by Side": "Side by Side",
    "Set up someone else's iPhone": "他の人の iPhone をセットアップ",
    "Steps": "手順",
    "Same Wi-Fi network": "同じ Wi-Fi ネットワーク",
    "Their iPhone": "相手の iPhone",
    "This iPhone is %@, so theirs will look similar.": "この iPhone は %@ です。相手のアドレスもこれに近い形になります。",
    "IP address (e.g. 192.168.1.42)": "IP アドレス（例：192.168.1.42）",
    "Enter the other iPhone's IP address. It's in Settings › Wi-Fi, next to the network it's on.":
        "相手の iPhone の IP アドレスを入力してください。「設定」>「Wi-Fi」の、接続中のネットワークの横で確認できます。",
    "On their iPhone: Settings › Wi-Fi › ⓘ next to the network, then “IP Address”.":
        "相手の iPhone で「設定」>「Wi-Fi」>ネットワーク横の ⓘ >「IP アドレス」の順に開きます。",
    "“%@” isn't an IPv4 address. It should look like 192.168.1.42.":
        "「%@」は IPv4 アドレスではありません。192.168.1.42 のような形式で入力してください。",
    "%@ is an address this iPhone already holds. Side by Side installs onto someone else's iPhone — use theirs. To install on this one, use the Install tab.":
        "%@ はこの iPhone 自身のアドレスです。Side by Side は他の人の iPhone にインストールするための機能なので、相手のアドレスを入力してください。この iPhone にインストールするには「インストール」タブを使用してください。",
    "Wi-Fi is off. Both iPhones have to be on the same Wi-Fi network for this to work.":
        "Wi-Fi がオフになっています。この機能を使うには、両方の iPhone が同じ Wi-Fi ネットワークに接続されている必要があります。",
    "Pair with their iPhone": "相手の iPhone とペアリング",
    "No pair record for their iPhone.": "相手の iPhone のペアリングレコードがありません。",
    "The link to their iPhone dropped — start again.": "相手の iPhone との接続が切断されました。最初からやり直してください。",
    "Sign in to their Apple ID": "相手の Apple ID でサインイン",
    "Apple ID to sign with": "署名に使用する Apple ID",
    "Enter the Apple ID to sign with, and its password.": "署名に使用する Apple ID とそのパスワードを入力してください。",
    "Tip: Use the iPhone/iPad owner's Apple account credentials":
        "ヒント：その iPhone/iPad の持ち主の Apple アカウントの認証情報を使ってください",
    "Use my saved Apple ID instead": "保存済みの自分の Apple ID を使用",
    "Clear their details": "入力した情報を消去",
    "Download SideInstaller": "SideInstaller をダウンロード",
    "Couldn't download the latest SideInstaller release: %@": "SideInstaller の最新リリースをダウンロードできませんでした：%@",
    "The release download wasn't an IPA. GitHub may be returning an error page — try again in a minute.":
        "ダウンロードされたファイルが IPA ではありませんでした。GitHub がエラーページを返している可能性があります。しばらくしてからもう一度お試しください。",
    "No SideInstaller IPA downloaded.": "SideInstaller の IPA がダウンロードされていません。",
    "Start the install": "インストールを開始",
    "Install on their iPhone": "相手の iPhone にインストール",
    "Install again": "もう一度インストール",
    "%d%% downloaded": "%d%% ダウンロード済み",
    "%d%% uploaded": "%d%% アップロード済み",
    "Apple wouldn't register their iPhone with this Apple ID's developer team, so it won't issue a provisioning profile. %@":
        "Apple がこの Apple ID の開発者チームに相手の iPhone を登録できなかったため、プロビジョニングプロファイルが発行されません。%@",
    "Apple won't issue a signing certificate for this Apple ID: it reports that one already exists (error 7460). One has to be revoked first — with the Certificates tool if this is the Apple ID saved in Settings › Account, and at developer.apple.com signed in as it otherwise.":
        "Apple がこの Apple ID の署名証明書を発行しません。すでに証明書が存在すると報告されています（エラー 7460）。まず既存の証明書を失効させる必要があります。「設定」>「アカウント」に保存されている Apple ID の場合は「証明書」ツールで、それ以外の場合は developer.apple.com にその Apple ID でサインインして失効させてください。",
    "Last step: they trust %@": "最後の手順：相手が %@ を信頼します",
    "Waiting for them to tap Trust…": "相手が「信頼」をタップするのを待っています…",
    "On their iPhone: Settings › General › VPN & Device Management.":
        "相手の iPhone で「設定」>「一般」>「VPN とデバイス管理」を開きます。",
    "Tap the Apple ID under “Developer App”, then tap Trust.":
        "「デベロッパ App」の下にある Apple ID をタップし、「信頼」をタップします。",
    "Open it from their Home Screen — they're set up.": "あとはホーム画面から開くだけで、セットアップは完了です。",

    // MARK: - About

    "About": "このアプリについて",
    "Version %@ (%@)": "バージョン %@（%@）",
    "SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved.":
        "SideInstaller は、パソコンを使わずに SideStore と LiveContainer を iPhone に直接インストールします。",

    "Links": "リンク",
    "Source code": "ソースコード",
    "Support the project": "プロジェクトを支援",

    "Special thanks": "特別な感謝",
    "For idevice, the library SideInstaller talks to your iPhone through. None of this exists without it.":
        "idevice に感謝します。SideInstaller はこのライブラリを通じて iPhone と通信しています。これがなければ何も成り立ちません。",
    "For the support, and for spotting the bugs that got fixed because of it.":
        "これまでのご支援と、そのおかげで発見・修正できたバグに感謝します。",
    "For the Japanese translation.": "日本語への翻訳に感謝します。",

    "Built with": "使用しているオープンソース",
    "The open source work this app is built on:": "このアプリの基盤となっているオープンソースの成果：",
    "Pairing, the tunnel and the install itself. By jkcoxson, MIT.":
        "ペアリング、トンネル、インストール本体。jkcoxson 開発、MIT ライセンス。",
    "Apple ID sign in, certificates and signing on the device. By nab138, MIT.":
        "Apple ID サインイン、証明書、デバイス上での署名。nab138 開発、MIT ライセンス。",
    "The sideloading app this installs for you.":
        "このアプリがインストールするサイドロード用アプリです。",
    "Runs sideloaded apps without spending an app slot on each one.":
        "アプリごとにスロットを消費することなく、サイドロードしたアプリを実行します。",
    "The developer disk image location spoofing mounts. Mirrored by doronz88.":
        "位置情報の偽装に使用する Developer Disk Image をマウントします。doronz88 によりミラーされています。",

    "Where to get it": "入手先について",
    "Only the builds on the official install page and repository are mine. Anyone can fork the source, add a credential stealer and ship it under the same name and icon — so don't trust your Apple ID to a copy from anywhere else.":
        "公式のインストールページとリポジトリにあるビルドのみが本物です。誰でもソースコードを fork し、認証情報を盗むコードを仕込んで、同じ名前とアイコンで配布することができます。そのため、他所から入手したコピーに Apple ID を入力しないでください。",
    "Install page": "インストールページ",
    "Terms": "利用規約",
]
