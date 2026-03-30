import SwiftUI

private let quickEntryPracticeCategories: [PracticeCategory] = [.general, .modes, .multiball, .shots]

func practiceQuickEntryCategoryLabel(_ category: PracticeCategory) -> String {
    switch category {
    case .general: return "General"
    case .modes: return "Modes"
    case .multiball: return "Multiball"
    case .shots: return "Shots"
    case .strategy: return "Strategy"
    }
}

struct PracticeQuickEntryModeFields: View {
    let selectedActivity: QuickEntryActivity
    let videoSourceOptions: [String]
    let mechanicsSkills: [String]
    let detectedMechanicsTags: [String]
    let scoreFieldFocused: FocusState<Bool>.Binding
    let onOpenScoreScanner: () -> Void

    @Binding var scoreText: String
    @Binding var scoreContext: ScoreContext
    @Binding var tournamentName: String
    @Binding var rulesheetProgress: Double
    @Binding var videoKind: VideoProgressInputKind
    @Binding var selectedVideoSource: String
    @Binding var videoWatchedTime: String
    @Binding var videoTotalTime: String
    @Binding var videoPercent: Double
    @Binding var practiceMinutes: String
    @Binding var practiceCategory: PracticeCategory
    @Binding var mechanicsSkill: String
    @Binding var mechanicsCompetency: Double
    @Binding var mechanicsNote: String
    @Binding var noteText: String

    private var selectedVideoSourceLabel: String {
        let trimmed = selectedVideoSource.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Video" : trimmed
    }

    private var selectedMechanicsSkillLabel: String {
        let trimmed = mechanicsSkill.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Skill" : trimmed
    }

    private var selectedPracticeCategoryLabel: String {
        practiceQuickEntryCategoryLabel(practiceCategory)
    }

    var body: some View {
        switch selectedActivity {
        case .score:
            TextField("Score", text: $scoreText)
                .font(.subheadline)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()
                .focused(scoreFieldFocused)
                .onChange(of: scoreText) { _, newValue in
                    let formatted = formatPracticeScoreInputWithCommas(newValue)
                    if formatted != newValue { scoreText = formatted }
                }

            Button {
                onOpenScoreScanner()
            } label: {
                Label("Scan Score", systemImage: "viewfinder")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .appControlStyle()
                    .contentShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Picker("Context", selection: $scoreContext) {
                ForEach(ScoreContext.allCases) { context in
                    Text(context.label).tag(context)
                }
            }
            .appSegmentedControlStyle()

            if scoreContext == .tournament {
                practiceEntryStyledTextField("Tournament name", text: $tournamentName)
            }

        case .rulesheet:
            practiceEntrySliderRow(title: "Rulesheet progress", value: $rulesheetProgress)
            practiceEntryStyledMultilineTextEditor("Optional notes", text: $noteText)

        case .tutorialVideo, .gameplayVideo:
            Menu {
                if videoSourceOptions.isEmpty {
                    Text("No video sources")
                } else {
                    ForEach(videoSourceOptions, id: \.self) { source in
                        Button {
                            selectedVideoSource = source
                        } label: {
                            AppSelectableMenuRow(text: source, isSelected: selectedVideoSource == source)
                        }
                    }
                }
            } label: {
                AppCompactDropdownLabel(text: selectedVideoSourceLabel)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Video")

            Picker("Input mode", selection: $videoKind) {
                ForEach(practiceVideoInputKindOptions) { kind in
                    Text(practiceVideoInputKindLabel(kind)).tag(kind)
                }
            }
            .appSegmentedControlStyle()

            if videoKind == .clock {
                HStack(alignment: .top, spacing: 10) {
                    PracticeTimePopoverField(title: "Watched", value: $videoWatchedTime)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PracticeTimePopoverField(title: "Duration", value: $videoTotalTime)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                practiceEntrySliderRow(title: "Percent watched", value: $videoPercent)
            }

            practiceEntryStyledMultilineTextEditor("Optional notes", text: $noteText)

        case .playfield:
            practiceEntryStyledMultilineTextEditor("Optional notes", text: $noteText)

        case .practice:
            Menu {
                ForEach(quickEntryPracticeCategories) { category in
                    Button {
                        practiceCategory = category
                    } label: {
                        AppSelectableMenuRow(
                            text: category == .general ? "General" : category.label,
                            isSelected: practiceCategory == category
                        )
                    }
                }
            } label: {
                AppCompactDropdownLabel(text: selectedPracticeCategoryLabel)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Practice type")

            practiceEntryStyledTextField("Practice minutes (optional)", text: $practiceMinutes, keyboard: .numberPad)
            practiceEntryStyledMultilineTextEditor("Optional notes", text: $noteText)

        case .mechanics:
            Menu {
                ForEach(mechanicsSkills, id: \.self) { skill in
                    Button {
                        mechanicsSkill = skill
                    } label: {
                        AppSelectableMenuRow(text: skill, isSelected: mechanicsSkill == skill)
                    }
                }
            } label: {
                AppCompactDropdownLabel(text: selectedMechanicsSkillLabel)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Skill")

            HStack {
                Text("Competency")
                Spacer()
                Text("\(Int(mechanicsCompetency))/5")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            Slider(value: $mechanicsCompetency, in: 1...5, step: 1)

            practiceEntryStyledMultilineTextEditor("Optional notes", text: $mechanicsNote)

            if !detectedMechanicsTags.isEmpty {
                Text("Detected tags: \(detectedMechanicsTags.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
