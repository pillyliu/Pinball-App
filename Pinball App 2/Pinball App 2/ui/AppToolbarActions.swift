import SwiftUI

struct AppToolbarCancelAction: View {
    var title: LocalizedStringKey = "Cancel"
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
    }
}

struct AppToolbarConfirmAction: View {
    let title: LocalizedStringKey
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .disabled(isDisabled)
    }
}

struct AppToolbarDoneAction: View {
    var title: LocalizedStringKey = "Done"
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
    }
}
