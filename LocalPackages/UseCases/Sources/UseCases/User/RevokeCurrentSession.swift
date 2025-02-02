//
// RevokeCurrentSession.swift
// Proton Pass - Created on 07/11/2023.
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
//

import Client
import Entities

@preconcurrency import ProtonCoreServices

public protocol RevokeCurrentSessionUseCase: Sendable {
    func execute() async
}

public extension RevokeCurrentSessionUseCase {
    func callAsFunction() async {
        await execute()
    }
}

public final class RevokeCurrentSession: RevokeCurrentSessionUseCase {
    private let apiService: APIService

    public init(apiService: APIService) {
        self.apiService = apiService
    }

    // Do not care if revoke is successful or not
    // because we don't want to prevent users from logging out
    // e.g when there's no internet connection
    public func execute() async {
        _ = try? await apiService.exec(endpoint: RevokeTokenEndpoint())
    }
}
