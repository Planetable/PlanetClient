//
//  ViewUtils.swift
//  Planet
//
//  Created by Xin Liu on 11/2/23.
//

import Foundation
import SwiftUI

struct ViewUtils {
    static let presetGradients = [
        Gradient(colors: [Color(hex: 0x88D3FA), Color(hex: 0x4C9FED)]), // Sky Blue
        Gradient(colors: [Color(hex: 0xFACE76), Color(hex: 0xF5AD67)]), // Orange
        Gradient(colors: [Color(hex: 0xD8A9F0), Color(hex: 0xCA77E9)]), // Pink
        Gradient(colors: [Color(hex: 0xF39066), Color(hex: 0xF0636E)]), // Red
        Gradient(colors: [Color(hex: 0xACDB86), Color(hex: 0x74C771)]), // Green
        Gradient(colors: [Color(hex: 0x8AB2FB), Color(hex: 0x6469FA)]), // Violet
        Gradient(colors: [Color(hex: 0x7FE9D7), Color(hex: 0x5DC6B8)]) // Cyan
    ]

    static let emojiList: [String] = [
        "🐶",
        "🐱",
        "🐭",
        "🐹",
        "🐰",
        "🦊",
        "🐻",
        "🐼",
        "🐨",
        "🐯",
        "🦁",
        "🐮",
        "🐷",
        "🐸",
        "🐵",
        "🙈",
        "🙉",
        "🙊",
        "🐒",
        "🐔",
        "🐧",
        "🐦",
        "🐤",
        "🐣",
        "🐥",
        "🦆",
        "🦅",
        "🦉",
        "🦇",
        "🐺",
        "🐗",
        "🐴",
        "🦄",
        "🐝",
        "🐛",
        "🦋",
        "🐌",
        "🐞",
        "🐜",
        "🕷",
        "🕸",
        "🦂",
        "🐢",
        "🐍",
        "🦎",
        "🦖",
        "🦕",
        "🐙",
        "🦑",
        "🦐",
        "🦞",
        "🦀",
        "🐡",
        "🐠",
        "🐟",
        "🐬",
        "🐳",
        "🐋",
        "🦈",
        "🦭",
        "🐊",
        "🐅",
        "🐆",
        "🦓",
        "🦍",
        "🦧",
        "🦣",
        "🐘",
        "🦛",
        "🦏",
        "🐪",
        "🐫",
        "🦒",
        "🦘"
    ]

    static func getPresetGradient(from uuid: UUID) -> Gradient {
        let leastSignificantUInt8 = uuid.uuid.15
        let index = Int(leastSignificantUInt8) % presetGradients.count
        return presetGradients[index]
    }

    static func getPresetGradient(from walletAddress: String) -> Gradient {
        let characters: [UInt8] = Array(walletAddress.utf8)
        let lastCharUInt8 = characters.last!
        let index = Int(lastCharUInt8) % presetGradients.count
        return presetGradients[index]
    }

    static func getEmoji(from walletAddress: String) -> String {
        let characters: [UInt8] = Array(walletAddress.utf8)
        let lastCharUInt8 = characters.last!
        let index = Int(lastCharUInt8) % emojiList.count
        return emojiList[index]
    }
}
