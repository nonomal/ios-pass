// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// Proton Pass.
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
// swiftlint:disable all

@testable import Client
import Core
import CoreData
import Entities
import ProtonCoreServices

final class PublicKeyRepositoryProtocolMock: @unchecked Sendable, PublicKeyRepositoryProtocol {
    // MARK: - getPublicKeys
    var getPublicKeysEmailThrowableError: Error?
    var closureGetPublicKeys: () -> () = {}
    var invokedGetPublicKeys = false
    var invokedGetPublicKeysCount = 0
    var invokedGetPublicKeysParameters: (email: String, Void)?
    var invokedGetPublicKeysParametersList = [(email: String, Void)]()
    var stubbedGetPublicKeysResult: [PublicKey]!

    func getPublicKeys(email: String) async throws -> [PublicKey] {
        invokedGetPublicKeys = true
        invokedGetPublicKeysCount += 1
        invokedGetPublicKeysParameters = (email, ())
        invokedGetPublicKeysParametersList.append((email, ()))
        if let error = getPublicKeysEmailThrowableError {
            throw error
        }
        closureGetPublicKeys()
        return stubbedGetPublicKeysResult
    }
}
