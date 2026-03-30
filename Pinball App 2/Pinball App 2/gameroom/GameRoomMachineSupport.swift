import SwiftUI

enum GameRoomMachineInputSheet: String, Identifiable {
    case cleanGlass
    case cleanPlayfield
    case swapBalls
    case checkPitch
    case levelMachine
    case generalInspection
    case logIssue
    case resolveIssue
    case ownershipUpdate
    case installMod
    case replacePart
    case addMedia
    case logPlays

    var id: String { rawValue }
}

struct GameRoomMachineInputSheetContent: View {
    let sheet: GameRoomMachineInputSheet
    let machine: OwnedMachine
    @ObservedObject var store: GameRoomStore

    @ViewBuilder
    var body: some View {
        switch sheet {
        case .cleanGlass:
            cleanGlassSheet()
        case .cleanPlayfield:
            cleanPlayfieldSheet()
        case .swapBalls:
            swapBallsSheet()
        case .checkPitch:
            checkPitchSheet()
        case .levelMachine:
            levelMachineSheet()
        case .generalInspection:
            generalInspectionSheet()
        case .logIssue:
            logIssueSheet()
        case .resolveIssue:
            resolveIssueSheet()
        case .ownershipUpdate:
            ownershipUpdateSheet()
        case .installMod:
            installModSheet()
        case .replacePart:
            replacePartSheet()
        case .addMedia:
            addMediaSheet()
        case .logPlays:
            logPlaysSheet()
        }
    }
}
