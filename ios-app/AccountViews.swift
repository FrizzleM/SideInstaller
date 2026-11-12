import SwiftUI

// MARK: - Official download check

/// Asked once, before an Apple ID is first typed in: was this copy downloaded
/// from sideinstaller.net? The app is open source, so anyone can publish a
/// copy that sends the Apple ID somewhere else. "No" says why that's a risk
/// and where the official app is, with only Back to answer again.
///
/// The first-run setup lays the same pieces out as a page of its own
/// (`SetupView`), with the buttons at its foot.
struct OfficialSourceCheck: View {
    /// Set once the user says the app came from sideinstaller.net.
    static let defaultsKey = "confirmedOfficialSource"
    static let websiteURL = URL(string: UpdateChecker.installPageURL)!

    @EnvironmentObject private var loc: Localizer
    @State private var unofficial = false
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if unofficial {
                VStack(spacing: 24) {
                    OfficialSourceWarning()
                    OfficialSourceWarningActions(onBack: { unofficial = false }, onConfirm: onConfirm)
                }
                .transition(.cardAppear)
            } else {
                VStack(spacing: 24) {
                    OfficialSourceQuestion()
                    OfficialSourceAnswers(onYes: onConfirm) { unofficial = true }
                }
                .transition(.cardAppear)
            }
        }
        .animation(.smooth(duration: 0.35), value: unofficial)
    }
}

/// The question, and why it's asked.
struct OfficialSourceQuestion: View {
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
                .setupObject(0)
            Text(L("Did you download SideInstaller from sideinstaller.net?"))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .setupObject(1)
            Text(L("SideInstaller is open source, so anyone can publish a modified copy that steals the Apple ID typed into it. Only sideinstaller.net is official."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .setupObject(2)
        }
    }
}

/// Its two answers.
struct OfficialSourceAnswers: View {
    let onYes: () -> Void
    let onNo: () -> Void
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        VStack(spacing: 12) {
            Button(L("Yes, from sideinstaller.net"), action: onYes)
                .buttonStyle(PrimaryButtonStyle())
                .setupObject(3)
            Button(action: onNo) {
                Text(L("No, or I'm not sure"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(), sound: .press)
            .controlSize(.large)
            .setupObject(4)
        }
    }
}

/// What "No" says: don't sign in with this copy.
struct OfficialSourceWarning: View {
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Don't sign in with this copy"))
                    .font(.headline)
                Text(L("Copies from anywhere other than sideinstaller.net are unofficial and may have been changed to steal your Apple ID. Delete this one and install SideInstaller from sideinstaller.net, then sign in there."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

/// Under the warning: the way to the official app, Back to answer again, and
/// a dim way past it for those who know the risk.
struct OfficialSourceWarningActions: View {
    let onBack: () -> Void
    let onConfirm: () -> Void
    @EnvironmentObject private var loc: Localizer
    @State private var confirmRisk = false

    var body: some View {
        VStack(spacing: 16) {
            Link(destination: OfficialSourceCheck.websiteURL) {
                Text(L("Open sideinstaller.net"))
            }
            .buttonStyle(PrimaryButtonStyle())
            Button(L("Back"), action: onBack)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain, sound: .tap)

            // Kept small and dim on purpose, and behind a confirmation, so
            // it's there for people who know what they're doing without
            // reading as the way on.
            Button(L("I understand the risks")) { confirmRisk = true }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .buttonStyle(.plain, sound: .tap)
                .padding(.top, 8)
        }
        .alert(L("Use an unofficial copy?"), isPresented: $confirmRisk) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Continue"), role: .destructive, action: onConfirm)
        } message: {
            Text(L("If this copy was changed, it can send your Apple ID and password to someone else. Continue only if you trust where it came from."))
        }
    }
}

/// Which of the two credential fields has the keyboard.
enum AccountField: Hashable { case email, password }

// MARK: - Add / edit sheet

/// What the editor is open for: a new Apple ID, or one already saved.
enum AccountEditorTarget: Identifiable {
    case new
    case existing(SavedAccount)

    var id: String {
        switch self {
        case .new:               return "new"
        case let .existing(acc): return acc.id.uuidString
        }
    }

    var account: SavedAccount? {
        if case let .existing(acc) = self { return acc }
        return nil
    }
}

/// Sheet to add an Apple ID or update a saved one. Saving makes it the active
/// account.
struct AccountEditor: View {
    @EnvironmentObject private var accounts: AccountStore
    @AppStorage(OfficialSourceCheck.defaultsKey) private var confirmedOfficialSource = false
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    let target: AccountEditorTarget

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: AccountField?

    private var canSave: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            // Someone who skipped first-run setup hasn't been asked yet.
            if confirmedOfficialSource || target.account != nil {
                form
            } else {
                ScrollView {
                    OfficialSourceCheck {
                        confirmedOfficialSource = true
                        // Once the form has replaced the question.
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            focus = .email
                        }
                    }
                    .padding(20)
                    .pageColumn()
                }
                .navigationTitle(L("Add Apple ID"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L("Cancel")) { dismiss() }
                    }
                }
            }
        }
        .onAppear {
            if let account = target.account { email = account.appleID }
            guard confirmedOfficialSource || target.account != nil else { return }
            focus = target.account == nil ? .email : .password
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField(L("Email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
                SecureField(L("Password"), text: $password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
            } footer: {
                // Saved passwords aren't displayed, so editing requires
                // entering the password again.
                Text(target.account == nil
                     ? L("Saved in this iPhone's keychain, and sent only to Apple when signing in.")
                     : L("Enter the password again to save this Apple ID."))
            }
        }
        .navigationTitle(target.account == nil ? L("Add Apple ID") : L("Edit Apple ID"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(L("Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("Save")) {
                    accounts.save(appleID: email, password: password, replacing: target.account)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }
}
