//
// UnindexAllLoginItems.swift
// Proton Pass - Created on 03/08/2023.
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

import Client

/// Empty credential database
public protocol UnindexAllLoginItemsUseCase: Sendable {
    func execute() async throws
}

public extension UnindexAllLoginItemsUseCase {
    func callAsFunction() async throws {
        try await execute()
    }
}

public final class UnindexAllLoginItems: Sendable, UnindexAllLoginItemsUseCase {
    private let manager: CredentialManagerProtocol

    public init(manager: CredentialManagerProtocol) {
        self.manager = manager
    }

    public func execute() async throws {
        try await manager.removeAllCredentials()
    }
}
