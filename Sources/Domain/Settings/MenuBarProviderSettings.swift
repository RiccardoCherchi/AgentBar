import Foundation

/// Display choices belonging to one provider. An empty primary key follows its first quota.
public struct MenuBarProviderSettings: Codable, Sendable, Equatable {
    public var primaryQuotaKey: String
    public var secondaryQuotaKey: String
    public var stacked: Bool
    public var stackedSize: String
    /// Custom menu bar color as a 6-digit hex string (no "#"), or nil to use
    /// the status-based color. Lets several providers be told apart by color
    /// now that the menu bar no longer draws provider icons.
    public var colorHex: String?

    public init(primaryQuotaKey: String = "", secondaryQuotaKey: String = "",
                stacked: Bool = false, stackedSize: String = "small", colorHex: String? = nil) {
        self.primaryQuotaKey = primaryQuotaKey
        self.secondaryQuotaKey = secondaryQuotaKey
        self.stacked = stacked
        self.stackedSize = stackedSize
        self.colorHex = colorHex
    }
}
