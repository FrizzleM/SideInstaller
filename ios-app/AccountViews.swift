import SwiftUI

// MARK: - First-run setup

/// First-run Apple ID setup, shown once after the TOS screen. The saved account
/// is used by every screen that signs in. Can be skipped and set later in
/// Settings › Account.
struct AccountSetupView: View {
    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false
    @AppStorage(OfficialSourceCheck.defaultsKey) private var confirmedOfficialSource = false
    @EnvironmentObject private var accounts: AccountStore
    /// Observed so labels redraw when the language changes.
    @EnvironmentObject private var loc: Localizer

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: AccountField?

    private var canSave: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    if confirmedOfficialSource {
                        header.cascadeItem(0)
                        card.cascadeItem(1)
                        buttons.cascadeItem(2)
                    } else {
                        // No skipping here: "Set this up later" is only on
                        // the sign-in form.
                        OfficialSourceCheck { confirmedOfficialSource = true }
                            .cascadeItem(0)
                    }
                }
                .padding(20)
                .padding(.top, 24)
                .pageColumn()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        // Focus only once the welcome page has zoomed away and the card has
        // faded in. AutoFill pairs the username field with a *visible* password
        // field when it gains focus; focusing during the entrance (card still
        // transparent) makes it fill the email alone, then the password separately.
        .task(id: confirmedOfficialSource) {
            guard confirmedOfficialSource else { return }
            try? await Task.sleep(for: .milliseconds(650))
            focus = .email
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill.badge.checkmark")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Theme.brand)
                .shadow(color: Theme.glow, radius: 20, x: 0, y: 12)
                .padding(.bottom, 4)
            Text(L("Sign in with your Apple ID"))
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(L("Don't worry, these are stored locally"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var card: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                TextField(L("Email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textFieldStyle(.plain)
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
                    .fieldBackground()
                SecureField(L("Password"), text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused($focus, equals: .password)
                    .fieldBackground()
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 14) {
            Button(L("Continue")) {
                accounts.save(appleID: email, password: password)
                hasCompletedAccountSetup = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.35)
            .animation(.snappy(duration: 0.25), value: canSave)

            Button(L("Set this up later")) { hasCompletedAccountSetup = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain, sound: .tap)
        }
    }
}

// MARK: - Official download check

/// Asked once, before an Apple ID is first typed in: was this copy downloaded
/// from sideinstaller.net? The app is open source, so anyone can publish a
/// copy that sends the Apple ID somewhere else. "No" says why that's a risk
/// and where the official app is, with only Back to answer again.
struct OfficialSourceCheck: View {
    /// Set once the user says the app came from sideinstaller.net.
    static let defaultsKey = "confirmedOfficialSource"
    static let websiteURL = URL(string: UpdateChecker.installPageURL)!

    @EnvironmentObject private var loc: Localizer
    @State private var unofficial = false
    @State private var confirmRisk = false
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            if unofficial {
                warning.transition(.cardAppear)
            } else {
                question.transition(.cardAppear)
            }
        }
        .animation(.smooth(duration: 0.35), value: unofficial)
    }

    private var question: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .shadow(color: Theme.glow, radius: 20, x: 0, y: 12)
                    .padding(.bottom, 4)
                Text(L("Did you download SideInstaller from sideinstaller.net?"))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("SideInstaller is open source, so anyone can publish a modified copy that steals the Apple ID typed into it. Only sideinstaller.net is official."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 14) {
                Button(L("Yes, from sideinstaller.net"), action: onConfirm)
                    .buttonStyle(PrimaryButtonStyle())
                Button(L("No, or I'm not sure")) { unofficial = true }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.08)))
                    .buttonStyle(.plain, sound: .press)
            }
        }
    }

    private var warning: some View {
        VStack(spacing: 22) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Don't sign in with this copy"))
                        .font(.headline)
                    Text(L("Copies from anywhere other than sideinstaller.net are unofficial and may have been changed to steal your Apple ID. Delete this one and install SideInstaller from sideinstaller.net, then sign in there."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1))

            VStack(spacing: 14) {
                Link(destination: Self.websiteURL) {
                    Text(L("Open sideinstaller.net"))
                }
                .buttonStyle(PrimaryButtonStyle())
                Button(L("Back")) { unofficial = false }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain, sound: .tap)
            }

            // Kept small and dim on purpose, and behind a confirmation, so
            // it's there for people who know what they're doing without
            // reading as the way on.
            Button(L("I understand the risks")) { confirmRisk = true }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .buttonStyle(.plain, sound: .tap)
                .padding(.top, 24)
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
