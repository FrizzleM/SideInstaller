import SwiftUI

// MARK: - First-run setup

/// First-run Apple ID setup, shown once after the TOS screen. The saved account
/// is used by every screen that signs in. Can be skipped and set later in
/// Settings › Account.
struct AccountSetupView: View {
    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false
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
                    header.cascadeItem(0)
                    card.cascadeItem(1)
                    buttons.cascadeItem(2)
                }
                .padding(20)
                .padding(.top, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onAppear { focus = .email }
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
                .buttonStyle(.plain)
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
        .onAppear {
            if let account = target.account { email = account.appleID }
            focus = target.account == nil ? .email : .password
        }
    }
}
