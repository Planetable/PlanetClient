import Foundation


/// Info returned from /v0/info
struct PlanetServerInfo: Codable {
    var hostName: String // Host name
    var version: String // Planet version
    var ipfsPeerID: String
    var ipfsVersion: String // IPFS (Kubo) version
    var ipfsPeerCount: Int
}
