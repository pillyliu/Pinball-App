import SwiftUI

struct PracticeGroupDashboardContext {
    let store: PracticeStore
    let selectedGroup: CustomGameGroup?
    let dashboardReloadRevision: Int
    let gameTransition: Namespace.ID
    let onOpenCreateGroup: () -> Void
    let onOpenEditSelectedGroup: () -> Void
    let onOpenGame: (String, String?) -> Void
    let onRemoveGameFromGroup: (String, UUID) -> Void
}
