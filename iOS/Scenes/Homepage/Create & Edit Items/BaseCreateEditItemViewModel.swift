//
// BaseCreateEditItemViewModel.swift
// Proton Pass - Created on 19/08/2022.
// Copyright (c) 2022 Proton Technologies AG
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
import DocScanner
import Entities
import Factory
import Foundation
import Macro
import ProtonCoreLogin
import SwiftUI

@MainActor
protocol CreateEditItemViewModelDelegate: AnyObject {
    func createEditItemViewModelWantsToAddCustomField(delegate: any CustomFieldAdditionDelegate,
                                                      shouldDisplayTotp: Bool)
    func createEditItemViewModelWantsToEditCustomFieldTitle(_ uiModel: CustomFieldUiModel,
                                                            delegate: any CustomFieldEditionDelegate)
}

enum ItemMode: Equatable, Hashable {
    case create(shareId: String, type: ItemCreationType)
    case clone(ItemContent)
    case edit(ItemContent)

    var isEditMode: Bool {
        switch self {
        case .edit:
            true
        default:
            false
        }
    }
}

enum ItemCreationType: Equatable, Hashable {
    case note(title: String, note: String)
    case alias
    // swiftlint:disable:next enum_case_associated_values_count
    case login(title: String? = nil,
               url: String? = nil,
               note: String? = nil,
               totpUri: String? = nil,
               autofill: Bool,
               passkeyCredentialRequest: PasskeyCredentialRequest? = nil)
    case creditCard

    case identity

    var itemContentType: ItemContentType {
        switch self {
        case .note:
            .note
        case .alias:
            .alias
        case .login:
            .login
        case .creditCard:
            .creditCard
        case .identity:
            .identity
        }
    }
}

@MainActor
class BaseCreateEditItemViewModel: ObservableObject, CustomFieldAdditionDelegate, CustomFieldEditionDelegate {
    @Published private(set) var selectedVault: Vault
    @Published private(set) var isFreeUser = false
    @Published private(set) var isSaving = false
    @Published private(set) var canAddMoreCustomFields = true
    @Published private(set) var canScanDocuments = false
    @Published var recentlyAddedOrEditedField: CustomFieldUiModel?

    @Published var customFieldUiModels = [CustomFieldUiModel]()
    @Published var isObsolete = false
    @Published var isShowingDiscardAlert = false

    // Scanning
    @Published var isShowingScanner = false
    let scanResponsePublisher: PassthroughSubject<(any ScanResult)?, any Error> = .init()

    let mode: ItemMode
    let itemRepository = resolve(\SharedRepositoryContainer.itemRepository)
    let upgradeChecker: any UpgradeCheckerProtocol
    let logger = resolve(\SharedToolingContainer.logger)
    let vaults: [Vault]
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let getMainVault = resolve(\SharedUseCasesContainer.getMainVault)
    private let vaultsManager = resolve(\SharedServiceContainer.vaultsManager)
    private let addTelemetryEvent = resolve(\SharedUseCasesContainer.addTelemetryEvent)

    var hasEmptyCustomField: Bool {
        customFieldUiModels.filter { $0.customField.type != .text }.contains(where: \.customField.content.isEmpty)
    }

    var isSaveable: Bool { true }

    var shouldUpgrade: Bool { false }

    var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    /// Only able to select vault when creating items
    var editableVault: Vault? {
        if case .create = mode {
            selectedVault
        } else {
            nil
        }
    }

    weak var delegate: (any CreateEditItemViewModelDelegate)?
    var cancellables = Set<AnyCancellable>()

    init(mode: ItemMode,
         upgradeChecker: any UpgradeCheckerProtocol,
         vaults: [Vault]) throws {
        let vaultShareId: String
        switch mode {
        case let .create(shareId, _):
            vaultShareId = shareId
        case let .clone(itemContent), let .edit(itemContent):
            vaultShareId = itemContent.shareId
            customFieldUiModels = itemContent.customFields.map { .init(customField: $0) }
        }

        guard let vault = vaults.first(where: { $0.shareId == vaultShareId }) ?? vaults.first else {
            throw PassError.vault(.vaultNotFound(vaultShareId))
        }

        if vault.canEdit {
            selectedVault = vault
        } else {
            guard let vault = vaults.twoOldestVaults.owned ?? vaults.first else {
                throw PassError.vault(.vaultNotFound(vaultShareId))
            }
            selectedVault = vault
        }
        self.mode = mode
        self.upgradeChecker = upgradeChecker
        self.vaults = vaults
        bindValues()
        setUp()
    }

    func bindValues() {}

    // swiftlint:disable:next unavailable_function
    func itemContentType() -> ItemContentType {
        fatalError("Must be overridden by subclasses")
    }

    // swiftlint:disable:next unavailable_function
    func generateItemContent() async -> ItemContentProtobuf? {
        fatalError("Must be overridden by subclasses")
    }

    /// The new passkey associated with this item
    func newPasskey() async throws -> CreatePasskeyResponse? { nil }

    func saveButtonTitle() -> String {
        switch mode {
        case .clone, .create:
            #localized("Create")
        case .edit:
            #localized("Save")
        }
    }

    func additionalEdit() async throws {}

    func generateAliasCreationInfo() -> AliasCreationInfo? { nil }
    func generateAliasItemContent() -> ItemContentProtobuf? { nil }

    func telemetryEventTypes() -> [TelemetryEventType] { [] }

    func customFieldEdited(_ uiModel: CustomFieldUiModel, newTitle: String) {
        guard let index = customFieldUiModels.firstIndex(where: { $0.id == uiModel.id }) else {
            let message = "Custom field with id \(uiModel.id) not found"
            logger.error(message)
            assertionFailure(message)
            return
        }
        recentlyAddedOrEditedField = uiModel
        customFieldUiModels[index] = uiModel.update(title: newTitle)
    }

    func customFieldEdited(_ uiModel: CustomFieldUiModel, content: String) {
        guard let index = customFieldUiModels.firstIndex(where: { $0.id == uiModel.id }) else {
            let message = "Custom field with id \(uiModel.id) not found"
            logger.error(message)
            assertionFailure(message)
            return
        }
        recentlyAddedOrEditedField = uiModel
        customFieldUiModels[index] = uiModel.update(content: content)
    }

    func customFieldAdded(_ customField: CustomField) {
        let uiModel = CustomFieldUiModel(customField: customField)
        customFieldUiModels.append(uiModel)
        recentlyAddedOrEditedField = uiModel
    }
}

// MARK: - Private APIs

private extension BaseCreateEditItemViewModel {
    func setUp() {
        Task { [weak self] in
            guard let self else { return }
            do {
                isFreeUser = try await upgradeChecker.isFreeUser()
                canAddMoreCustomFields = !isFreeUser
                canScanDocuments = DocScanner.isSupported
                if isFreeUser,
                   case .create = mode, vaults.count > 1,
                   let mainVault = await getMainVault() {
                    selectedVault = mainVault
                }
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }

        vaultsManager.$vaultSelection
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selection in
                guard let self,
                      let newSelectedVault = selection.preciseVault,
                      newSelectedVault != selectedVault else {
                    return
                }
                selectedVault = newSelectedVault
            }
            .store(in: &cancellables)
    }

    func createItem(for type: ItemContentType) async throws -> SymmetricallyEncryptedItem? {
        let shareId = selectedVault.shareId
        guard let itemContent = await generateItemContent() else {
            logger.warning("No item content")
            return nil
        }

        switch type {
        case .alias:
            if let aliasCreationInfo = generateAliasCreationInfo() {
                return try await itemRepository.createAlias(info: aliasCreationInfo,
                                                            itemContent: itemContent,
                                                            shareId: shareId)
            } else {
                assertionFailure("aliasCreationInfo should not be null")
                logger.warning("Can not create alias because creation info is empty")
                return nil
            }

        case .login:
            if let aliasCreationInfo = generateAliasCreationInfo(),
               let aliasItemContent = generateAliasItemContent() {
                let (_, createdLoginItem) = try await itemRepository
                    .createAliasAndOtherItem(info: aliasCreationInfo,
                                             aliasItemContent: aliasItemContent,
                                             otherItemContent: itemContent,
                                             shareId: shareId)
                return createdLoginItem
            }

        default:
            break
        }

        return try await itemRepository.createItem(itemContent: itemContent, shareId: shareId)
    }

    /// Return `true` if item is edited, `false` otherwise
    func editItem(oldItemContent: ItemContent) async throws -> Bool {
        try await additionalEdit()
        let itemId = oldItemContent.itemId
        let shareId = oldItemContent.shareId
        guard let oldItem = try await itemRepository.getItem(shareId: shareId,
                                                             itemId: itemId) else {
            throw PassError.itemNotFound(oldItemContent)
        }
        guard let newItemContent = await generateItemContent() else {
            logger.warning("No new item content")
            return false
        }
        guard !oldItemContent.protobuf.isLooselyEqual(to: newItemContent) else {
            logger.trace("Skipped editing because no changes \(oldItemContent.debugDescription)")
            return false
        }
        try await itemRepository.updateItem(oldItem: oldItem.item,
                                            newItemContent: newItemContent,
                                            shareId: oldItem.shareId)
        return true
    }
}

// MARK: - Public APIs

extension BaseCreateEditItemViewModel {
    func addCustomField() {
        delegate?.createEditItemViewModelWantsToAddCustomField(delegate: self, shouldDisplayTotp: true)
    }

    func editCustomFieldTitle(_ uiModel: CustomFieldUiModel) {
        delegate?.createEditItemViewModelWantsToEditCustomFieldTitle(uiModel, delegate: self)
    }

    func upgrade() {
        router.present(for: .upgradeFlow)
    }

    func openScanner() {
        isShowingScanner = true
    }

    @objc
    func save() {
        Task { [weak self] in
            guard let self else { return }

            defer { isSaving = false }
            isSaving = true

            do {
                let handleCreation: (ItemContentType) async throws -> Void = { [weak self] type in
                    guard let self else { return }
                    logger.trace("Creating item")
                    if let createdItem = try await createItem(for: type) {
                        logger.info("Created \(createdItem.debugDescription)")
                        let passkey = try await newPasskey()
                        router.present(for: .createItem(item: createdItem,
                                                        type: itemContentType(),
                                                        createPasskeyResponse: passkey))
                    }
                }

                switch mode {
                case let .create(_, type):
                    try await handleCreation(type.itemContentType)

                case let .clone(itemContent):
                    try await handleCreation(itemContent.type)

                case let .edit(oldItemContent):
                    logger.trace("Editing \(oldItemContent.debugDescription)")
                    let updated = try await editItem(oldItemContent: oldItemContent)
                    logger.info("Edited \(oldItemContent.debugDescription)")
                    router.present(for: .updateItem(type: itemContentType(), updated: updated))
                }

                addTelemetryEvent(with: telemetryEventTypes())
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    /// Refresh the item to detect changes.
    /// When changes happen, announce via `isObsolete` boolean  so the view can act accordingly
    func refresh() {
        guard case let .edit(itemContent) = mode else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let updatedItem =
                    try await itemRepository.getItem(shareId: itemContent.shareId,
                                                     itemId: itemContent.item.itemID) else {
                    return
                }
                isObsolete = itemContent.item.revision != updatedItem.item.revision
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func changeVault() {
        router.present(for: .vaultSelection)
    }
}
