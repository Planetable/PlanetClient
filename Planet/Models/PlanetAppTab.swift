import Foundation


enum PlanetAppTab: Int, Hashable {
    case latest
    case myPlanets
    case drafts

    func name() -> String {
        switch self {
        case .latest:
            return "Latest"
        case .myPlanets:
            return "My Planets"
        case .drafts:
            return "Drafts"
        }
    }
}
