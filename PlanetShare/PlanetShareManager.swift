//
//  PlanetShareManager.swift
//  PlanetShare
//

import Foundation
import UIKit
import Intents


class PlanetShareManager: NSObject {
    static let shared = PlanetShareManager()
    static let lastSharedPlanetID: String = "PlanetLastSharedPlanetIDKey"

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
        interaction.groupIdentifier = planet.id
        try await interaction.donate()
    }
    
    func removeDonatedPlanet(planetID: String) async throws {
        try await INInteraction.delete(with: planetID)
    }

}
