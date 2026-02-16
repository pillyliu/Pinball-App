package com.pillyliu.pinballandroid.practice

internal enum class JournalFilter(val label: String) {
    All("All"),
    Study("Study"),
    Practice("Practice"),
    Scores("Scores"),
    Notes("Notes"),
    League("League"),
}

internal enum class QuickActivity(val label: String) {
    Score("Score"),
    Rulesheet("Rulesheet"),
    Tutorial("Tutorial"),
    Gameplay("Gameplay"),
    Playfield("Playfield"),
    Practice("Practice"),
    Mechanics("Mechanics"),
}

internal enum class QuickEntryOrigin(val keySuffix: String) {
    Score("score"),
    Study("study"),
    Practice("practice"),
    Mechanics("mechanics"),
}

internal enum class GroupDashboardDateField {
    Start,
    End,
}

internal enum class GroupEditorDateField {
    Start,
    End,
}
