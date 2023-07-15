//
// GetLocalAuthenticationMethodsUseCase.swift
// Proton Pass - Created on 13/07/2023.
// Copyright (c) 2023 Proton Technologies AG
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

import Factory

@preconcurrency import LocalAuthentication

/// Get supported local authentication  methods
protocol GetLocalAuthenticationMethodsUseCase: Sendable {
    func execute() throws -> [LocalAuthenticationMethodUiModel]
}

extension GetLocalAuthenticationMethodsUseCase {
    func callAsFunction() throws -> [LocalAuthenticationMethodUiModel] {
        try execute()
    }
}

final class GetLocalAuthenticationMethods: GetLocalAuthenticationMethodsUseCase {
    private let checkBiometryType = resolve(\SharedUseCasesContainer.checkBiometryType)
    private let policy = resolve(\SharedToolingContainer.localAuthenticationCheckingPolicy)

    init() {}

    func execute() throws -> [LocalAuthenticationMethodUiModel] {
        do {
            let biometryType = try checkBiometryType(for: policy)
            if biometryType.usable {
                return [.none, .biometric(biometryType), .pin]
            }
        } catch {
            // We only want to throw unexpected errors
            // If biometry is not available for whatever reason, we just ignore it
            if let laError = error as? LAError {
                switch laError.code {
                case .biometryLockout,
                     .biometryNotAvailable,
                     .biometryNotEnrolled:
                    return [.none, .pin]
                default:
                    throw error
                }
            }
            throw error
        }
        return [.none, .pin]
    }
}
