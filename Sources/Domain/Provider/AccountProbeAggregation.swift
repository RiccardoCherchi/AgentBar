import Foundation

/// Aggregates usage from several per-account probes into a single snapshot.
///
/// Each account's quotas are tagged with the account label, so the menu renders
/// one grouped section per account (the same mechanism the Oh My Pi provider
/// uses for its upstream accounts). One failing account does not sink the rest:
/// its failure is only surfaced when every account fails.
public enum AccountProbeAggregation {
    private enum Outcome: Sendable {
        case success(UsageSnapshot)
        case failure(String)
    }

    /// Probes every account concurrently and merges the results.
    ///
    /// - Parameters:
    ///   - providerId: The provider these accounts belong to.
    ///   - accounts: The configured accounts, in display order.
    ///   - makeProbe: Builds a probe bound to one account's credentials.
    /// - Throws: The last per-account error when no account succeeds.
    public static func refresh(
        providerId: String,
        accounts: [ProviderAccountConfig],
        makeProbe: @escaping @Sendable (ProviderAccountConfig) -> any UsageProbe
    ) async throws -> UsageSnapshot {
        var results: [(account: ProviderAccountConfig, outcome: Outcome)] = []
        results.reserveCapacity(accounts.count)

        await withTaskGroup(of: (ProviderAccountConfig, Outcome).self) { group in
            for account in accounts {
                group.addTask {
                    let probe = makeProbe(account)
                    do {
                        return (account, .success(try await probe.probe()))
                    } catch {
                        return (account, .failure(error.localizedDescription))
                    }
                }
            }
            for await result in group {
                results.append(result)
            }
        }

        // Restore configured order; the task group yields completion order.
        let order = Dictionary(
            uniqueKeysWithValues: accounts.enumerated().map { ($1.accountId, $0) }
        )
        results.sort { (order[$0.account.accountId] ?? 0) < (order[$1.account.accountId] ?? 0) }

        var quotas: [UsageQuota] = []
        var firstSnapshot: UsageSnapshot?
        var lastError: String?

        for result in results {
            switch result.outcome {
            case let .success(snapshot):
                if firstSnapshot == nil { firstSnapshot = snapshot }
                quotas.append(contentsOf: snapshot.quotas.map { $0.withGroup(result.account.label) })
            case let .failure(message):
                lastError = message
            }
        }

        guard let firstSnapshot else {
            throw ProbeError.executionFailed(lastError ?? "No accounts could be probed")
        }

        return UsageSnapshot(
            providerId: providerId,
            quotas: quotas,
            capturedAt: Date(),
            accountEmail: firstSnapshot.accountEmail,
            accountOrganization: firstSnapshot.accountOrganization,
            loginMethod: firstSnapshot.loginMethod,
            accountTier: firstSnapshot.accountTier
        )
    }
}
