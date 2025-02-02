//
//
// GetPendingUserInvitations.swift
// Proton Pass - Created on 27/07/2023.
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
import Combine
import Entities

public protocol GetPendingUserInvitationsUseCase: Sendable {
    func execute() -> CurrentValueSubject<[UserInvite], Never>
}

public extension GetPendingUserInvitationsUseCase {
    func callAsFunction() -> CurrentValueSubject<[UserInvite], Never> {
        execute()
    }
}

public final class GetPendingUserInvitations: GetPendingUserInvitationsUseCase {
    private let repository: InviteRepositoryProtocol

    public init(repository: InviteRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() -> CurrentValueSubject<[UserInvite], Never> {
        repository.currentPendingInvites
    }
}
