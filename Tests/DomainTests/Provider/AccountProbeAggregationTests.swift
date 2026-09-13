import Testing
import Foundation
@testable import Domain

@Suite("AccountProbeAggregation")
struct AccountProbeAggregationTests {

    /// Sendable stub so the concurrent aggregation can call it without Mockable
    /// generics leaking into the task group.
    private struct StubProbe: UsageProbe {
        let snapshot: UsageSnapshot?
        let error: ProbeError?

        func probe() async throws -> UsageSnapshot {
            if let snapshot { return snapshot }
            throw error ?? .executionFailed("stub")
        }

        func isAvailable() async -> Bool { true }
    }

    private func account(_ id: String, label: String? = nil) -> ProviderAccountConfig {
        ProviderAccountConfig(accountId: id, label: label ?? id.capitalized)
    }

    private func snapshot(percent: Double) -> UsageSnapshot {
        UsageSnapshot(
            providerId: "deepseek",
            quotas: [
                UsageQuota(percentRemaining: percent, quotaType: .modelSpecific("Balance"), providerId: "deepseek")
            ],
            capturedAt: Date()
        )
    }

    @Test
    func `merges every account's quotas tagged with its label`() async throws {
        let probes: [String: StubProbe] = [
            "personal": StubProbe(snapshot: snapshot(percent: 80), error: nil),
            "work": StubProbe(snapshot: snapshot(percent: 40), error: nil),
        ]

        let result = try await AccountProbeAggregation.refresh(
            providerId: "deepseek",
            accounts: [account("personal"), account("work")]
        ) { probes[$0.accountId]! }

        #expect(result.quotas.count == 2)
        #expect(result.quotas.map(\.group) == ["Personal", "Work"])
        #expect(result.quotas.map(\.percentRemaining) == [80, 40])
    }

    @Test
    func `configured order wins over completion order`() async throws {
        let probes: [String: StubProbe] = [
            "a": StubProbe(snapshot: snapshot(percent: 10), error: nil),
            "b": StubProbe(snapshot: snapshot(percent: 20), error: nil),
            "c": StubProbe(snapshot: snapshot(percent: 30), error: nil),
        ]

        let result = try await AccountProbeAggregation.refresh(
            providerId: "deepseek",
            accounts: [account("c"), account("a"), account("b")]
        ) { probes[$0.accountId]! }

        #expect(result.quotas.map(\.group) == ["C", "A", "B"])
        #expect(result.quotas.map(\.percentRemaining) == [30, 10, 20])
    }

    @Test
    func `a failing account does not sink the others`() async throws {
        let probes: [String: StubProbe] = [
            "good": StubProbe(snapshot: snapshot(percent: 55), error: nil),
            "bad": StubProbe(snapshot: nil, error: .authenticationRequired),
        ]

        let result = try await AccountProbeAggregation.refresh(
            providerId: "deepseek",
            accounts: [account("good"), account("bad")]
        ) { probes[$0.accountId]! }

        #expect(result.quotas.count == 1)
        #expect(result.quotas.first?.group == "Good")
    }

    @Test
    func `throws when every account fails`() async {
        let probes: [String: StubProbe] = [
            "a": StubProbe(snapshot: nil, error: .authenticationRequired),
            "b": StubProbe(snapshot: nil, error: .executionFailed("boom")),
        ]

        await #expect(throws: (any Error).self) {
            try await AccountProbeAggregation.refresh(
                providerId: "deepseek",
                accounts: [account("a"), account("b")]
            ) { probes[$0.accountId]! }
        }
    }
}
