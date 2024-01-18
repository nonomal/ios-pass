//
// ForkSession.swift
// Proton Pass - Created on 17/01/2024.
// Copyright (c) 2024 Proton Technologies AG
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
import Foundation
@preconcurrency import ProtonCoreServices

public protocol ForkSessionUseCase: Sendable {
    func execute() async throws -> String
}

public extension ForkSessionUseCase {
    func callAsFunction() async throws -> String {
        try await execute()
    }
}

public final class ForkSession: ForkSessionUseCase {
    private let apiService: any APIService

    public init(apiService: any APIService) {
        self.apiService = apiService
    }

    public func execute() async throws -> String {
        try await Task.sleep(seconds: 1)
        return ""
        /*
         let endpoint = ForkSessionEndpoint(request: .init(payload: "",
                                                           childClientId: "pass-ios",
                                                           independent: 1))
         let response = try await apiService.exec(endpoint: endpoint)
         return response.selector
          */
    }
}
