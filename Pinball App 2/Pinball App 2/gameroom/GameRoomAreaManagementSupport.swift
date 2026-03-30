import SwiftUI

struct GameRoomVenueNamePanel: View {
    @Binding var venueNameDraft: String
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("GameRoom Name", text: $venueNameDraft)
                .textFieldStyle(.roundedBorder)

            Button("Save", action: onSave)
                .buttonStyle(AppPrimaryActionButtonStyle())
        }
    }
}

struct GameRoomAreaManagementPanel: View {
    @Binding var newAreaName: String
    @Binding var newAreaOrder: Int
    let areas: [GameRoomArea]
    let onSave: () -> Void
    let onEditArea: (GameRoomArea) -> Void
    let onDeleteArea: (GameRoomArea) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                TextField("Area name", text: $newAreaName)
                    .textFieldStyle(.roundedBorder)

                TextField("Area order", value: $newAreaOrder, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .keyboardType(.numberPad)
            }

            Button("Save", action: onSave)
                .buttonStyle(AppPrimaryActionButtonStyle())

            if areas.isEmpty {
                AppPanelEmptyCard(text: "No areas yet. Add an area like Upstairs or Basement to keep area order consistent across machines.")
            } else {
                VStack(spacing: 8) {
                    ForEach(areas) { area in
                        GameRoomAreaRow(
                            area: area,
                            onEditArea: onEditArea,
                            onDeleteArea: onDeleteArea
                        )
                    }
                }
            }
        }
    }
}

struct GameRoomAreaRow: View {
    let area: GameRoomArea
    let onEditArea: (GameRoomArea) -> Void
    let onDeleteArea: (GameRoomArea) -> Void

    var body: some View {
        HStack {
            Button {
                onEditArea(area)
            } label: {
                Text("\(area.name) (\(area.areaOrder))")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(role: .destructive) {
                onDeleteArea(area)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(AppCompactIconActionButtonStyle())
        }
    }
}
