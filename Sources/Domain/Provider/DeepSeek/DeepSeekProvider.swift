import Foundation
import Observation

/// DeepSeek AI provider - a rich domain model.
/// Observable class with its own state (isSyncing, snapshot, error).
/// Owns its probe and manages its own data lifecycle.
@MainActor
@Observable
public final class DeepSeekProvider: AIProvider {
    // MARK: - Identity (Protocol Requirement)

    public let id: String = "deepseek"
    public let name: String = "DeepSeek"
    public let cliCommand: String = "" // API-only provider, no CLI

    public var dashboardURL: URL? {
        URL(string: "https://platform.deepseek.com/usage")
    }

    public var statusPageURL: URL? {
        nil
    }

    /// Whether the provider is enabled (persisted via settingsRepository)
    public var isEnabled: Bool {
        didSet {
            settingsRepository.setEnabled(isEnabled, forProvider: id)
        }
    }

    // MARK: - State (Observable)

    /// Whether the provider is currently syncing data
    public private(set) var isSyncing: Bool = false

    /// The current usage snapshot (nil if never refreshed or unavailable)
    public private(set) var snapshot: UsageSnapshot?

    /// The last error that occurred during refresh
    public private(set) var lastError: Error?

    // MARK: - Internal

    /// The probe used to fetch usage data
    private let probe: any UsageProbe
    private let settingsRepository: any DeepSeekSettingsRepository

    /// Optional multi-account support. When an account list is configured, each
    /// account is probed with its own probe instead of the single global probe.
    private let accountRepository: (any MultiAccountSettingsRepository)?
    private let accountProbeFactory: (@Sendable (ProviderAccountConfig) -> any UsageProbe)?

    // MARK: - Initialization

    /// Creates a DeepSeek provider with the specified probe
    /// - Parameter probe: The probe to use for fetching usage data
    /// - Parameter settingsRepository: The repository for persisting settings
    public init(
        probe: any UsageProbe,
        settingsRepository: any DeepSeekSettingsRepository,
        accountRepository: (any MultiAccountSettingsRepository)? = nil,
        accountProbeFactory: (@Sendable (ProviderAccountConfig) -> any UsageProbe)? = nil
    ) {
        self.probe = probe
        self.settingsRepository = settingsRepository
        self.accountRepository = accountRepository
        self.accountProbeFactory = accountProbeFactory
        // Default to disabled - requires API key configuration
        self.isEnabled = settingsRepository.isEnabled(forProvider: "deepseek", defaultValue: false)
    }

    // MARK: - AIProvider Protocol

    public func isAvailable() async -> Bool {
        await probe.isAvailable()
    }

    /// Refreshes the usage data and updates the snapshot.
    /// Sets isSyncing during refresh and captures any errors.
    @discardableResult
    public func refresh() async throws -> UsageSnapshot {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let newSnapshot: UsageSnapshot
            if let accounts = configuredAccounts, let factory = accountProbeFactory {
                newSnapshot = try await AccountProbeAggregation.refresh(
                    providerId: id,
                    accounts: accounts,
                    makeProbe: factory
                )
            } else {
                newSnapshot = try await probe.probe()
            }
            snapshot = newSnapshot
            lastError = nil
            return newSnapshot
        } catch {
            lastError = error
            throw error
        }
    }

    /// Configured accounts, or nil when multi-account is off/unconfigured.
    private var configuredAccounts: [ProviderAccountConfig]? {
        guard let accountRepository else { return nil }
        let accounts = accountRepository.accounts(forProvider: id)
        return accounts.isEmpty ? nil : accounts
    }
}
