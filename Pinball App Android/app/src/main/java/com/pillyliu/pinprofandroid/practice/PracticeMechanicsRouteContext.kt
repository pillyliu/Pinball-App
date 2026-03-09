package com.pillyliu.pinprofandroid.practice

internal data class PracticeMechanicsRouteContext(
    val store: PracticeStore,
    val mechanicsSelectedSkill: String,
    val onMechanicsSelectedSkillChange: (String) -> Unit,
    val mechanicsCompetency: Float,
    val onMechanicsCompetencyChange: (Float) -> Unit,
    val mechanicsNote: String,
    val onMechanicsNoteChange: (String) -> Unit,
    val onOpenDeadFlipTutorials: () -> Unit,
)
