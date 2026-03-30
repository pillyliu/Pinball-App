import SwiftUI

struct GameRoomEditMachinePanelStack<
    NamePanel: View,
    AddMachinePanel: View,
    AreaPanel: View,
    EditMachinesPanel: View
>: View {
    let editMachinesTitle: String
    @Binding var isNameExpanded: Bool
    @Binding var isAddMachineExpanded: Bool
    @Binding var isAreasExpanded: Bool
    @Binding var isEditMachinesExpanded: Bool
    @ViewBuilder let namePanel: () -> NamePanel
    @ViewBuilder let addMachinePanel: () -> AddMachinePanel
    @ViewBuilder let areaPanel: () -> AreaPanel
    @ViewBuilder let editMachinesPanel: () -> EditMachinesPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GameRoomEditMachineDisclosurePanel(title: "Name", isExpanded: $isNameExpanded) {
                namePanel()
            }
            GameRoomEditMachineDisclosurePanel(title: "Add Machine", isExpanded: $isAddMachineExpanded) {
                addMachinePanel()
            }
            GameRoomEditMachineDisclosurePanel(title: "Areas", isExpanded: $isAreasExpanded) {
                areaPanel()
            }
            GameRoomEditMachineDisclosurePanel(title: editMachinesTitle, isExpanded: $isEditMachinesExpanded) {
                editMachinesPanel()
            }
        }
    }
}

struct GameRoomEditMachineDisclosurePanel<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content()
                .padding(.top, 8)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .appPanelStyle()
    }
}
