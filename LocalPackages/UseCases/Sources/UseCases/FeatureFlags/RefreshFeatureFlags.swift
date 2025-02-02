//
// RefreshFeatureFlags.swift
// Proton Pass - Created on 02/08/2023.
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
import Core

public protocol RefreshFeatureFlagsUseCase: Sendable {
    func execute()
}

public extension RefreshFeatureFlagsUseCase {
    func callAsFunction() {
        execute()
    }
}

public final class RefreshFeatureFlags: @unchecked Sendable, RefreshFeatureFlagsUseCase {
    private let repository: FeatureFlagsRepositoryProtocol
    private let userDataProvider: UserDataProvider
    private let logger: Logger

    public init(repository: FeatureFlagsRepositoryProtocol,
                userDataProvider: UserDataProvider,
                logManager: LogManagerProtocol) {
        self.repository = repository
        self.userDataProvider = userDataProvider
        logger = .init(manager: logManager)
    }

    public func execute() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let userId = try userDataProvider.getUserId()
                logger.trace("Refreshing features fags for user \(userId)")
                try await repository.refreshFlags()
                logger.trace("Finished updating local flags for user \(userId)")
            } catch {
                logger.error(error)
            }
        }
    }
}
