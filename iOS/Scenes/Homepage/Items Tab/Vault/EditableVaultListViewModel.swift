//
// EditableVaultListViewModel.swift
// Proton Pass - Created on 08/03/2023.
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
import Combine
import Core
import Entities
import Factory
import Foundation
import Macro

@MainActor
protocol EditableVaultListViewModelDelegate: AnyObject {
    func editableVaultListViewModelWantsToConfirmDelete(vault: Vault,
                                                        delegate: any DeleteVaultAlertHandlerDelegate)
}

@MainActor
final class EditableVaultListViewModel: ObservableObject, DeinitPrintable {
    @Published private(set) var loading = false
    @Published private(set) var state = VaultManagerState.loading

    @Published private(set) var secureLinks: [SecureLink]?

    let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)

    private let setShareInviteVault = resolve(\UseCasesContainer.setShareInviteVault)
    private let getUserShareStatus = resolve(\UseCasesContainer.getUserShareStatus)
    private let canUserPerformActionOnVault = resolve(\UseCasesContainer.canUserPerformActionOnVault)
    private let leaveShare = resolve(\UseCasesContainer.leaveShare)
    private let syncEventLoop = resolve(\SharedServiceContainer.syncEventLoop)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let vaultsManager = resolve(\SharedServiceContainer.vaultsManager)
//    private let getSecureLinkList = resolve(\UseCasesContainer.getSecureLinkList)

    private var cancellables = Set<AnyCancellable>()

    var hasTrashItems: Bool {
        vaultsManager.getItemCount(for: .trash) > 0
    }

    weak var delegate: (any EditableVaultListViewModelDelegate)?

    init() {
        setUp()
    }

    deinit { print(deinitMessage) }

    func select(_ selection: VaultSelection) {
        vaultsManager.select(selection)
    }

    func isSelected(_ selection: VaultSelection) -> Bool {
        vaultsManager.isSelected(selection)
    }

    func canShare(vault: Vault) -> Bool {
        getUserShareStatus(for: vault) != .cantShare && !vault.shared
    }

    func canEdit(vault: Vault) -> Bool {
        canUserPerformActionOnVault(for: vault) && vault.isOwner
    }

    func canMoveItems(vault: Vault) -> Bool {
        canUserPerformActionOnVault(for: vault)
    }

    func showSecureLinkList() {
        guard let secureLinks else {
            return
        }
        router.present(for: .secureLinks(secureLinks))
    }
}

// MARK: - Private APIs

private extension EditableVaultListViewModel {
    func setUp() {
        vaultsManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                state = newState
            }
            .store(in: &cancellables)
//
//        Task { [weak self] in
//            guard let self else { return }
//            do {
//                secureLinks = try await getSecureLinkList()
//            } catch {
//                logger.error(error)
//                router.display(element: .displayErrorBanner(error))
//            }
//        }
    }

    func doDelete(vault: Vault) {
        Task { [weak self] in
            guard let self else { return }
            defer { loading = false }
            do {
                loading = true
                try await vaultsManager.delete(vault: vault)
                vaultsManager.refresh()
                router.display(element: .infosMessage(#localized("Vault « %@ » deleted", vault.name)))
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }
}

// MARK: - Public APIs

extension EditableVaultListViewModel {
    func createNewVault() {
        router.present(for: .vaultCreateEdit(vault: nil))
    }

    func edit(vault: Vault) {
        router.present(for: .vaultCreateEdit(vault: vault))
    }

    func share(vault: Vault) {
        if getUserShareStatus(for: vault) == .canShare {
            setShareInviteVault(with: .existing(vault))
            router.present(for: .sharingFlow(.none))
        } else {
            router.present(for: .upselling(.default))
        }
    }

    func leaveVault(vault: Vault) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await leaveShare(with: vault.shareId)
                syncEventLoop.forceSync()
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func delete(vault: Vault) {
        delegate?.editableVaultListViewModelWantsToConfirmDelete(vault: vault, delegate: self)
    }

    func restoreAllTrashedItems() {
        Task { [weak self] in
            guard let self else { return }
            defer { loading = false }
            do {
                logger.trace("Restoring all trashed items")
                loading = true
                try await vaultsManager.restoreAllTrashedItems()
                router.display(element: .successMessage(#localized("All items restored"),
                                                        config: .refresh))
                logger.info("Restored all trashed items")
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func emptyTrash() {
        Task { [weak self] in
            guard let self else { return }
            defer { loading = false }
            do {
                logger.trace("Emptying all trashed items")
                loading = true
                try await vaultsManager.permanentlyDeleteAllTrashedItems()
                router.display(element: .infosMessage(#localized("All items permanently deleted"),
                                                      config: .refresh))
                logger.info("Emptied all trashed items")
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func itemCount(for selection: VaultSelection) -> Int {
        vaultsManager.getItemCount(for: selection)
    }
}

// MARK: - DeleteVaultConfirmationDelegate

extension EditableVaultListViewModel: DeleteVaultAlertHandlerDelegate {
    func confirmDelete(vault: Vault) {
        doDelete(vault: vault)
    }
}
