import SwiftUI
import Domain
import Infrastructure

/// Settings card for managing the accounts configured on a provider.
///
/// Each account is real: DeepSeek accounts hold their own API key, and
/// Claude/Codex accounts point at their own CLI config directory
/// (`CLAUDE_CONFIG_DIR` / `CODEX_HOME`). All configured accounts are probed
/// and shown at once — there is no single "active" account.
struct AccountManagementCard: View {
    let providerId: String
    let providerName: String

    @State private var settings = AppSettings.shared
    @Environment(\.appTheme) private var theme
    @State private var isExpanded = false
    @State private var showAddSheet = false
    @State private var accounts: [ProviderAccountConfig] = []
    @State private var accountsWithKeys: Set<String> = []
    @State private var keyAccount: ProviderAccountConfig?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Divider()
                .background(theme.glassBorder)
                .padding(.vertical, 8)

            VStack(spacing: 8) {
                if accounts.isEmpty {
                    emptyState
                } else {
                    ForEach(accounts, id: \.accountId) { account in
                        accountRow(account)
                    }
                }

                addAccountButton
            }
        } label: {
            header
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                .fill(theme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                        .stroke(theme.glassBorder, lineWidth: 1)
                )
        )
        .onAppear(perform: reload)
        .sheet(isPresented: $showAddSheet) {
            AddAccountSheet(
                providerId: providerId,
                providerName: providerName,
                existingAccountIds: accounts.map(\.accountId),
                onAdd: addAccount,
                onCancel: { showAddSheet = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { keyAccount != nil },
            set: { if !$0 { keyAccount = nil } }
        )) {
            if let account = keyAccount {
                SetAccountSheet(
                    providerName: providerName,
                    account: account,
                    onSave: { key, budget in setAccountSettings(key: key, budget: budget, for: account) },
                    onCancel: { keyAccount = nil }
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(theme.accentGradient)
                    .frame(width: 32, height: 32)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Accounts")
                    .font(.system(size: 14, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s") · all monitored together")
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("No extra accounts. Add one to track another \(providerName) login alongside the default.")
            .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }

    // MARK: - Account Row

    private func accountRow(_ account: ProviderAccountConfig) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(theme.glassBackground)
                    .frame(width: 24, height: 24)

                Text(initialLetter(for: account))
                    .font(.system(size: 10, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.label)
                    .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let subtitle = subtitle(for: account) {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if providerId == "deepseek" {
                let hasKey = accountsWithKeys.contains(account.accountId)
                Button {
                    keyAccount = account
                } label: {
                    Image(systemName: hasKey ? "key.fill" : "key")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(hasKey ? theme.statusHealthy : theme.accentPrimary)
                }
                .buttonStyle(.plain)
                .help(hasKey ? "Replace API key" : "Set API key")
            }

            Button(role: .destructive) {
                removeAccount(account)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Remove account")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Add Account

    private var addAccountButton: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))

                Text("Add Account")
                    .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
            }
            .foregroundStyle(theme.accentPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.accentPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func reload() {
        accounts = settings.multiAccount.accounts(forProvider: providerId)
        accountsWithKeys = Set(
            accounts
                .filter {
                    settings.multiAccount.accountSecret(
                        forProvider: providerId,
                        accountId: $0.accountId,
                        name: "apiKey"
                    ) != nil
                }
                .map(\.accountId)
        )
    }

    private func setAccountSettings(key: String, budget: String, for account: ProviderAccountConfig) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            settings.multiAccount.setAccountSecret(
                trimmedKey,
                forProvider: providerId,
                accountId: account.accountId,
                name: "apiKey"
            )
        }

        var probeConfig = account.probeConfig
        let trimmedBudget = budget.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBudget.isEmpty {
            probeConfig.removeValue(forKey: "balanceBudget")
        } else {
            probeConfig["balanceBudget"] = trimmedBudget
        }
        settings.multiAccount.updateAccount(
            ProviderAccountConfig(
                accountId: account.accountId,
                label: account.label,
                email: account.email,
                organization: account.organization,
                probeConfig: probeConfig
            ),
            forProvider: providerId
        )

        keyAccount = nil
        reload()
    }

    private func addAccount(_ config: ProviderAccountConfig, secret: String?) {
        settings.multiAccount.addAccount(config, forProvider: providerId)
        if let secret {
            settings.multiAccount.setAccountSecret(
                secret,
                forProvider: providerId,
                accountId: config.accountId,
                name: "apiKey"
            )
        }
        showAddSheet = false
        reload()
    }

    private func removeAccount(_ account: ProviderAccountConfig) {
        settings.multiAccount.removeAccount(accountId: account.accountId, forProvider: providerId)
        reload()
    }

    private func initialLetter(for account: ProviderAccountConfig) -> String {
        String((account.label.isEmpty ? account.accountId : account.label).prefix(1)).uppercased()
    }

    private func subtitle(for account: ProviderAccountConfig) -> String? {
        var parts: [String] = []
        if providerId == "deepseek" {
            parts.append(accountsWithKeys.contains(account.accountId) ? "Key set" : "No key")
            if let budget = account.probeConfig["balanceBudget"], !budget.isEmpty {
                parts.append("Budget $\(budget)")
            }
        }
        if let email = account.email, !email.isEmpty { parts.append(email) }
        if let dir = account.probeConfig["configDir"], !dir.isEmpty { parts.append(dir) }
        if let organization = account.organization, !organization.isEmpty { parts.append(organization) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Add Account Sheet

private struct AddAccountSheet: View {
    let providerId: String
    let providerName: String
    let existingAccountIds: [String]
    let onAdd: (ProviderAccountConfig, String?) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var label = ""
    @State private var email = ""
    @State private var organization = ""
    @State private var apiKey = ""
    @State private var budget = ""
    @State private var configDir = ""

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var needsAPIKey: Bool { providerId == "deepseek" }
    private var needsConfigDir: Bool { providerId == "claude" || providerId == "codex" }

    private var canSubmit: Bool {
        guard !trimmedLabel.isEmpty else { return false }
        if needsAPIKey { return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if needsConfigDir { return !configDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Add \(providerName) Account")
                    .font(.system(size: 15, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text(credentialHint)
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            field(title: "LABEL", text: $label, prompt: "Personal")
            field(title: "EMAIL (OPTIONAL)", text: $email, prompt: "you@example.com")
            field(title: "ORGANIZATION (OPTIONAL)", text: $organization, prompt: "Acme Corp")

            if needsAPIKey {
                secureField(title: "API KEY", text: $apiKey, prompt: "sk-...")
                field(title: "BALANCE BUDGET (OPTIONAL)", text: $budget, prompt: "20.00")
            }

            if needsConfigDir {
                field(
                    title: "CONFIG DIRECTORY",
                    text: $configDir,
                    prompt: providerId == "claude" ? "~/.claude-work" : "~/.codex-work"
                )
            }

            HStack(spacing: 8) {
                Spacer()

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                Button(action: submit) {
                    Text("Add Account")
                        .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.accentPrimary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.5)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var credentialHint: String {
        switch providerId {
        case "deepseek":
            "Each account uses its own DeepSeek API key."
        case "claude", "codex":
            "Point at a separate config directory you have logged into (run the CLI with CLAUDE_CONFIG_DIR/CODEX_HOME set)."
        default:
            "Name it so you can tell it apart from your other logins."
        }
    }

    private func field(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(title)

            TextField("", text: text, prompt: Text(prompt).foregroundStyle(theme.textTertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(fieldBackground)
        }
    }

    private func secureField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(title)

            SecureField("", text: text, prompt: Text(prompt).foregroundStyle(theme.textTertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(fieldBackground)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textSecondary)
            .tracking(0.5)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(theme.glassBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.glassBorder, lineWidth: 1)
            )
    }

    private func submit() {
        guard canSubmit else { return }

        var probeConfig: [String: String] = [:]
        if needsConfigDir {
            probeConfig["configDir"] = configDir.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if needsAPIKey {
            let trimmedBudget = budget.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedBudget.isEmpty {
                probeConfig["balanceBudget"] = trimmedBudget
            }
        }

        let config = ProviderAccountConfig(
            accountId: Self.uniqueAccountId(from: trimmedLabel, existing: existingAccountIds),
            label: trimmedLabel,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            organization: organization.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            probeConfig: probeConfig
        )

        let secret = needsAPIKey
            ? apiKey.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            : nil

        onAdd(config, secret)
    }

    /// Derives a stable, readable account id from the label ("Work - Acme" →
    /// "work-acme"), suffixing a counter when that id is already taken.
    private static func uniqueAccountId(from label: String, existing: [String]) -> String {
        let base = slug(label)
        guard existing.contains(base) else { return base }

        var counter = 2
        while existing.contains("\(base)-\(counter)") {
            counter += 1
        }
        return "\(base)-\(counter)"
    }

    private static func slug(_ text: String) -> String {
        var result = ""
        var lastWasSeparator = false
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
                lastWasSeparator = false
            } else if !lastWasSeparator, !result.isEmpty {
                result.append("-")
                lastWasSeparator = true
            }
        }
        while result.hasSuffix("-") {
            result.removeLast()
        }
        return result.isEmpty ? "account" : result
    }
}

// MARK: - Set Account Sheet

/// Sets the API key and optional balance budget for a single DeepSeek account.
private struct SetAccountSheet: View {
    let providerName: String
    let account: ProviderAccountConfig
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var apiKey = ""
    @State private var budget: String

    init(
        providerName: String,
        account: ProviderAccountConfig,
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.providerName = providerName
        self.account = account
        self.onSave = onSave
        self.onCancel = onCancel
        _budget = State(initialValue: account.probeConfig["balanceBudget"] ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings for \(account.label)")
                    .font(.system(size: 15, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("The API key is stored in the Keychain; the budget applies only to this \(providerName) account.")
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API KEY")
                    .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)

                SecureField("", text: $apiKey, prompt: Text("Leave blank to keep the current key").foregroundStyle(theme.textTertiary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(fieldBackground)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("BALANCE BUDGET (OPTIONAL)")
                    .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)

                TextField("", text: $budget, prompt: Text("20.00").foregroundStyle(theme.textTertiary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(fieldBackground)
            }

            HStack(spacing: 8) {
                Spacer()

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                Button {
                    onSave(apiKey, budget)
                } label: {
                    Text("Save")
                        .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.accentPrimary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(theme.glassBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.glassBorder, lineWidth: 1)
            )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}