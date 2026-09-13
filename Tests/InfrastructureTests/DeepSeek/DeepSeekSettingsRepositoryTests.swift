import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct DeepSeekSettingsRepositoryTests {
    @Test
    func `user defaults repository persists and removes DeepSeek settings`() {
        let suiteName = "DeepSeekSettingsRepositoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UserDefaultsProviderSettingsRepository(userDefaults: defaults)

        #expect(repository.deepseekAuthEnvVar().isEmpty)
        #expect(repository.hasDeepSeekApiKey() == false)

        repository.setDeepSeekAuthEnvVar("CUSTOM_DEEPSEEK_KEY")
        repository.saveDeepSeekApiKey("sk-test")

        #expect(repository.deepseekAuthEnvVar() == "CUSTOM_DEEPSEEK_KEY")
        #expect(repository.getDeepSeekApiKey() == "sk-test")
        #expect(repository.hasDeepSeekApiKey() == true)

        repository.deleteDeepSeekApiKey()
        #expect(repository.getDeepSeekApiKey() == nil)
        #expect(repository.hasDeepSeekApiKey() == false)
    }

    @Test
    func `JSON repository persists and removes DeepSeek settings`() {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeepSeekJSONSettingsTests.\(UUID().uuidString)")
        let settingsURL = tempDirectory.appendingPathComponent("settings.json")
        let suiteName = "DeepSeekJSONCredentialsTests.\(UUID().uuidString)"
        let credentials = UserDefaults(suiteName: suiteName)!
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
            credentials.removePersistentDomain(forName: suiteName)
        }
        let repository = JSONSettingsRepository(
            store: JSONSettingsStore(fileURL: settingsURL),
            credentials: credentials
        )

        #expect(repository.deepseekAuthEnvVar().isEmpty)
        #expect(repository.hasDeepSeekApiKey() == false)

        repository.setDeepSeekAuthEnvVar("CUSTOM_DEEPSEEK_KEY")
        repository.saveDeepSeekApiKey("sk-test")

        #expect(repository.deepseekAuthEnvVar() == "CUSTOM_DEEPSEEK_KEY")
        #expect(repository.getDeepSeekApiKey() == "sk-test")
        #expect(repository.hasDeepSeekApiKey() == true)

        repository.deleteDeepSeekApiKey()
        #expect(repository.getDeepSeekApiKey() == nil)
        #expect(repository.hasDeepSeekApiKey() == false)
    }

    @Test
    func `budget round-trips and clears`() {
        let suiteName = "DeepSeekBudgetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let userDefaultsRepo = UserDefaultsProviderSettingsRepository(userDefaults: defaults)

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeepSeekBudgetJSONTests.\(UUID().uuidString)")
        let credentialsSuite = "DeepSeekBudgetCredentials.\(UUID().uuidString)"
        let credentials = UserDefaults(suiteName: credentialsSuite)!
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
            credentials.removePersistentDomain(forName: credentialsSuite)
        }
        let jsonRepo = JSONSettingsRepository(
            store: JSONSettingsStore(fileURL: tempDirectory.appendingPathComponent("settings.json")),
            credentials: credentials
        )

        func assertRoundTrip(_ repository: any DeepSeekSettingsRepository) {
            #expect(repository.deepseekBalanceBudget() == nil)
            repository.setDeepSeekBalanceBudget(Decimal(50))
            #expect(repository.deepseekBalanceBudget() == Decimal(50))
            repository.setDeepSeekBalanceBudget(nil)
            #expect(repository.deepseekBalanceBudget() == nil)
        }

        assertRoundTrip(userDefaultsRepo)
        assertRoundTrip(jsonRepo)
    }
}
