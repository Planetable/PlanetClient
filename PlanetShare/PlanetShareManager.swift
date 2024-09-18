//
//  PlanetShareManager.swift
//  PlanetShare
//

import Foundation
import Intents


class PlanetShareManager: NSObject {
    static let shared = PlanetShareManager()
    
    func donatePost(forPlanet planet: Planet, content: String) async throws {
        let planetName = INSpeakableString(spokenPhrase: planet.name)
        let postIntent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content,
            speakableGroupName: planetName,
            conversationIdentifier: planet.id,
            serviceName: nil,
            sender: nil,
            attachments: nil)
        let planetAvatarImage: INImage? = {
            guard let avatarURL = planet.avatarURL else { return nil }
            do {
                let avatarData = try Data(contentsOf: avatarURL)
                return INImage(imageData: avatarData)
            } catch {
                return nil
            }
        }()
        postIntent.setImage(planetAvatarImage, forParameterNamed: \.speakableGroupName)
        let interaction = INInteraction(intent: postIntent, response: nil)
        try await interaction.donate()
    }
    
    func removeDonatedPlanet(_ planet: Planet) throws {
        // MARK: TODO: ?
    }
}
