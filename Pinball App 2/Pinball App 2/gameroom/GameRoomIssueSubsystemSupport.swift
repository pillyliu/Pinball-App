import Foundation

extension MachineIssueSubsystem {
    var displayTitle: String {
        switch self {
        case .popBumper: return "Pop Bumper"
        case .shooterLane: return "Shooter Lane"
        case .switchMatrix: return "Switch Matrix"
        case .toyMech: return "Toy Mech"
        default:
            return rawValue
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }
}
