//
// OnboardingViewState.swift
// Proton Pass - Created on 08/12/2022.
// Copyright (c) 2022 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import Foundation

enum OnboardingViewState {
    case autoFill
    case autoFillEnabled
    case biometricAuthenticationTouchID
    case biometricAuthenticationFaceID
    case faceIDEnabled
    case touchIDEnabled
    case aliases

    var title: String {
        switch self {
        case .autoFill:
            "Enjoy the magic of AutoFill".localized
        case .autoFillEnabled:
            "Log in to apps instantly".localized
        case .biometricAuthenticationFaceID, .biometricAuthenticationTouchID:
            "Protect your most sensitive data".localized
        case .faceIDEnabled:
            "Face ID enabled".localized
        case .touchIDEnabled:
            "Touch ID enabled".localized
        case .aliases:
            "Control what lands in your inbox".localized
        }
    }

    var description: String {
        switch self {
        case .autoFill:
            "Turn on AutoFill to let Proton Pass fill in login details for you⏤10 seconds that will save you hours"
                .localized
        case .autoFillEnabled:
            "When logging in to a site or service, tap the Proton Pass icon to automatically fill in your login details"
                .localized
        case .biometricAuthenticationFaceID, .biometricAuthenticationTouchID:
            "Set Proton Pass to unlock with your face or fingerprint so only you have access".localized
        case .faceIDEnabled, .touchIDEnabled:
            "Now you can unlock Proton Pass only when you need it⏤quickly and securely".localized
        case .aliases:
            "Stop sharing your real email address. Instead hide it with email aliases⏤a Proton Pass exclusive."
                .localized
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .autoFill:
            "Go to Settings".localized
        case .biometricAuthenticationTouchID:
            "Enable Touch ID".localized
        case .biometricAuthenticationFaceID:
            "Enable Face ID".localized
        case .aliases:
            "Start using Proton Pass".localized
        case .autoFillEnabled, .faceIDEnabled, .touchIDEnabled:
            "Next".localized
        }
    }

    var secondaryButtonTitle: String? {
        switch self {
        case .autoFill, .biometricAuthenticationFaceID, .biometricAuthenticationTouchID:
            "Not now".localized
        case .aliases, .autoFillEnabled, .faceIDEnabled, .touchIDEnabled:
            nil
        }
    }
}
