import SwiftUI

struct GameRoomResolveIssueSheet: View {
    let openIssues: [MachineIssue]
    let onSave: (UUID, Date, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIssueID: UUID?
    @State private var resolvedAt = Date()
    @State private var resolution = ""

    var body: some View {
        NavigationStack {
            Form {
                if openIssues.isEmpty {
                    Text("No open issues.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Issue", selection: $selectedIssueID) {
                        ForEach(openIssues) { issue in
                            Text(issue.symptom).tag(Optional(issue.id))
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("Resolved", selection: $resolvedAt)

                    TextField("Resolution Notes", text: $resolution, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Resolve Issue")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedIssueID == nil {
                    selectedIssueID = openIssues.first?.id
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppToolbarCancelAction { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppToolbarConfirmAction(title: "Save", isDisabled: selectedIssueID == nil) {
                        guard let selectedIssueID else { return }
                        onSave(selectedIssueID, resolvedAt, gameRoomNormalizedOptional(resolution))
                        dismiss()
                    }
                }
            }
        }
    }
}
