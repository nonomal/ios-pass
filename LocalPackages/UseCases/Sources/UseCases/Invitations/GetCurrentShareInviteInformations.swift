//
//
// GetCurrentShareInviteInformations.swift
// Proton Pass - Created on 20/07/2023.
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

// sourcery: AutoMockable
public protocol GetCurrentShareInviteInformationsUseCase {
    func execute() -> SharingInfos
}

public extension GetCurrentShareInviteInformationsUseCase {
    func callAsFunction() -> SharingInfos {
        execute()
    }
}

public final class GetCurrentShareInviteInformations: GetCurrentShareInviteInformationsUseCase {
    private let shareInviteService: ShareInviteServiceProtocol

    public init(shareInviteService: ShareInviteServiceProtocol) {
        self.shareInviteService = shareInviteService
    }

    public func execute() -> SharingInfos {
        let vault = shareInviteService.currentSelectedVault
        let email = shareInviteService.currentDestinationUserEmail
        let role = shareInviteService.currentUserRole
        let receiverPublicKeys = shareInviteService.receiverPublicKeys
        let itemNum = shareInviteService.currentSelectedVaultItems

        return SharingInfos(vault: vault.value,
                            email: email,
                            role: role,
                            receiverPublicKeys: receiverPublicKeys,
                            itemsNum: itemNum)
    }
}
