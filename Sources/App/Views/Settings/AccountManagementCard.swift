import SwiftUI
import Domain
import Infrastructure

/// Settings card for managing the accounts configured on a provider.
///
/// Offline account management: add, remove, and pick the active account.
/// Definitions persist under `providers.{providerId}.accounts` in
/// settings.json through `MultiAccountSettingsRepository`. Probing each
/// account with its own credentials is a separate follow-up — this card
/// only records which accounts exist.
struct AccountManagementCard: View {
    let providerId: String
    let providerName: String

    @State private var settings = AppSettings.shared
    @Environment(\.appTheme) private var theme
    @State private var isExpanded = false
    @State private var showAddSheet = false
    @State private var accounts: [ProviderAccountConfig] = []
    @State private var activeAccountId: String?

    /// The repository treats a nil active pointer as "first account".
    private var effectiveActiveId: String? {
        activeAccountId ?? accounts.first?.accountId
    }

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
                providerName: providerName,
                existingAccountIds: accounts.map(\.accountId),
                onAdd: addAccount,
                onCancel: { showAddSheet = false }
            )
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

                Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s") configured")
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("No extra accounts. Add one to track a second \(providerName) login.")
            .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }

    // MARK: - Account Row

    private func accountRow(_ account: ProviderAccountConfig) -> some View {
        let isActive = account.accountId == effectiveActiveId

        return HStack(spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(isActive ? theme.accentPrimary : theme.glassBackground)
                    .frame(width: 24, height: 24)

                Text(initialLetter(for: account))
                    .font(.system(size: 10, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(isActive ? .white : theme.textSecondary)
            }

            // Account info
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

            Button(role: .destructive) {
                removeAccount(account)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Remove account")

            // Active indicator / switch
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.statusHealthy)
            } else {
                Button {
                    setActive(account)
                } label: {
                    Text("Use")
                        .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.accentPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .stroke(theme.accentPrimary.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
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
        activeAccountId = settings.multiAccount.activeAccountId(forProvider: providerId)
    }

    private func addAccount(_ config: ProviderAccountConfig) {
        settings.multiAccount.addAccount(config, forProvider: providerId)
        // First account added becomes the active one so the switch has a target.
        if activeAccountId == nil {
            settings.multiAccount.setActiveAccountId(config.accountId, forProvider: providerId)
        }
        showAddSheet = false
        reload()
    }

    private func removeAccount(_ account: ProviderAccountConfig) {
        settings.multiAccount.removeAccount(accountId: account.accountId, forProvider: providerId)
        reload()
    }

    private func setActive(_ account: ProviderAccountConfig) {
        settings.multiAccount.setActiveAccountId(account.accountId, forProvider: providerId)
        reload()
    }

    private func initialLetter(for account: ProviderAccountConfig) -> String {
        String((account.label.isEmpty ? account.accountId : account.label).prefix(1)).uppercased()
    }

    private func subtitle(for account: ProviderAccountConfig) -> String? {
        var parts: [String] = []
        if let email = account.email, !email.isEmpty { parts.append(email) }
        if let organization = account.organization, !organization.isEmpty { parts.append(organization) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Add Account Sheet

private struct AddAccountSheet: View {
    let providerName: String
    let existingAccountIds: [String]
    let onAdd: (ProviderAccountConfig) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var label = ""
    @State private var email = ""
    @State private var organization = ""

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Add \(providerName) Account")
                    .font(.system(size: 15, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Name it so you can tell it apart from your other logins.")
                    .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            field(title: "LABEL", text: $label, prompt: "Personal")
            field(title: "EMAIL (OPTIONAL)", text: $email, prompt: "you@example.com")
            field(title: "ORGANIZATION (OPTIONAL)", text: $organization, prompt: "Acme Corp")

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
                .disabled(trimmedLabel.isEmpty)
                .opacity(trimmedLabel.isEmpty ? 0.5 : 1)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func field(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .tracking(0.5)

            TextField("", text: text, prompt: Text(prompt).foregroundStyle(theme.textTertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.glassBorder, lineWidth: 1)
                        )
                )
        }
    }

    private func submit() {
        guard !trimmedLabel.isEmpty else { return }
        let config = ProviderAccountConfig(
            accountId: Self.uniqueAccountId(from: trimmedLabel, existing: existingAccountIds),
            label: trimmedLabel,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            organization: organization.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        onAdd(config)
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
