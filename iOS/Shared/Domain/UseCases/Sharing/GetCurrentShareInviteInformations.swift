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

struct SharingInfos {
    let vault: Vault?
    let email: String?
    let role: String?
    let itemsNum: Int?
}

protocol GetCurrentShareInviteInformationsUseCase: Sendable {
    func execute() async -> SharingInfos
}

extension GetCurrentShareInviteInformationsUseCase {
    func callAsFunction() async -> SharingInfos {
        await execute()
    }
}

final class GetCurrentShareInviteInformations: GetCurrentShareInviteInformationsUseCase {
    private let shareInviteService: ShareInviteServiceProtocol

    init(shareInviteService: ShareInviteServiceProtocol) {
        self.shareInviteService = shareInviteService
    }

    func execute() async -> SharingInfos {
        let vault = await shareInviteService.currentSelectedVault
        let email = await shareInviteService.currentDestinationUserEmail
        let role = await shareInviteService.currentUserRole
        let itemNum = await shareInviteService.currentSelectedVaultItems

        return SharingInfos(vault: vault, email: email, role: role, itemsNum: itemNum)
    }
}
