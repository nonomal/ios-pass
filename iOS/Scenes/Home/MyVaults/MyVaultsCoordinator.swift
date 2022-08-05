//
// MyVaultsCoordinator.swift
// Proton Pass - Created on 07/07/2022.
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
import Core
import ProtonCore_Login
import ProtonCore_Services
import SwiftUI
import UIKit

protocol MyVaultsCoordinatorDelegate: AnyObject {
    func myVautsCoordinatorWantsToShowSidebar()
    func myVautsCoordinatorWantsToShowLoadingHud()
    func myVautsCoordinatorWantsToHideLoadingHud()
    func myVautsCoordinatorWantsToAlertError(_ error: Error)
}

final class MyVaultsCoordinator: Coordinator {
    weak var delegate: MyVaultsCoordinatorDelegate?

    private lazy var myVaultsViewController: UIViewController = {
        let myVaultsView = MyVaultsView(viewModel: .init(coordinator: self))
        return UIHostingController(rootView: myVaultsView)
    }()

    override var root: Presentable { myVaultsViewController }
    let apiService: APIService
    let sessionData: SessionData
    let vaultSelection: VaultSelection
    let repository: RepositoryProtocol

    init(apiService: APIService,
         sessionData: SessionData,
         vaultSelection: VaultSelection) {
        self.apiService = apiService
        self.sessionData = sessionData
        self.vaultSelection = vaultSelection

        let localDatasource = LocalDatasource(inMemory: false)
        let credential = sessionData.userData.credential
        let userId = sessionData.userData.user.ID
        let remoteDatasource = RemoteDatasource(authCredential: credential,
                                                apiService: apiService)
        self.repository = Repository(userId: userId,
                                     localDatasource: localDatasource,
                                     remoteDatasource: remoteDatasource)
        super.init(router: .init(), navigationType: .newFlow(hideBar: false))
    }

    func showSidebar() {
        delegate?.myVautsCoordinatorWantsToShowSidebar()
    }

    func showCreateItemView() {
        let createItemView = CreateItemView(coordinator: self)
        let createItemViewController = UIHostingController(rootView: createItemView)
        if #available(iOS 15.0, *) {
            createItemViewController.sheetPresentationController?.detents = [.medium()]
        }
        router.present(createItemViewController, animated: true)
    }

    func showCreateVaultView() {
        let createVaultViewModel = CreateVaultViewModel(coordinator: self)
        createVaultViewModel.delegate = self
        let createVaultView = CreateVaultView(viewModel: createVaultViewModel)
        let createVaultViewController = UIHostingController(rootView: createVaultView)
        if #available(iOS 15.0, *) {
            createVaultViewController.sheetPresentationController?.detents = [.medium()]
        }
        router.present(createVaultViewController, animated: true)
    }

    func showLoadingHud() {
        delegate?.myVautsCoordinatorWantsToShowLoadingHud()
    }

    func hideLoadingHud() {
        delegate?.myVautsCoordinatorWantsToHideLoadingHud()
    }

    func alert(error: Error) {
        delegate?.myVautsCoordinatorWantsToAlertError(error)
    }

    func dismissTopMostModal() {
        router.toPresentable().presentedViewController?.dismiss(animated: true)
    }

    private func dismissTopMostModalAndPresent(viewController: UIViewController) {
        let present: () -> Void = { [unowned self] in
            self.router.toPresentable().present(viewController, animated: true, completion: nil)
        }

        if let presentedViewController = router.toPresentable().presentedViewController {
            presentedViewController.dismiss(animated: true, completion: present)
        } else {
            present()
        }
    }

    func handleCreateNewItemOption(_ option: CreateNewItemOption) {
        switch option {
        case .login:
            let createLoginView = CreateLoginView(coordinator: self)
            let createLoginViewController = UIHostingController(rootView: createLoginView)
            dismissTopMostModalAndPresent(viewController: createLoginViewController)
        case .alias:
            let createAliasView = CreateAliasView(coordinator: self)
            let createAliasViewController = UIHostingController(rootView: createAliasView)
            dismissTopMostModalAndPresent(viewController: createAliasViewController)
        case .note:
            let createNoteViewModel = CreateNoteViewModel(coordinator: self)
            let createNoteView = CreateNoteView(viewModel: createNoteViewModel)
            let createNewNoteController = UIHostingController(rootView: createNoteView)
            if #available(iOS 15, *) {
                createNewNoteController.sheetPresentationController?.detents = [.medium()]
            }
            dismissTopMostModalAndPresent(viewController: createNewNoteController)
        case .password:
            let viewModel = GeneratePasswordViewModel(coordinator: self)
            let generatePasswordView = GeneratePasswordView(viewModel: viewModel)
            let generatePasswordViewController = UIHostingController(rootView: generatePasswordView)
            if #available(iOS 15, *) {
                generatePasswordViewController.sheetPresentationController?.detents = [.medium()]
            }
            dismissTopMostModalAndPresent(viewController: generatePasswordViewController)
        }
    }
}

// MARK: - CreateVaultViewModelDelegate
extension MyVaultsCoordinator: CreateVaultViewModelDelegate {
    func createVaultViewModelBeginsLoading() {
        delegate?.myVautsCoordinatorWantsToShowLoadingHud()
    }

    func createVaultViewModelStopsLoading() {
        delegate?.myVautsCoordinatorWantsToHideLoadingHud()
    }

    func createVaultViewModelWantsToBeDismissed() {
        dismissTopMostModal()
    }

    func createVaultViewModelDidCreateShare(share: PartialShare) {
        // Set vaults to empty to trigger refresh
        vaultSelection.update(vaults: [])
        dismissTopMostModal()
    }

    func createVaultViewModelFailedToCreateShare(error: Error) {
        delegate?.myVautsCoordinatorWantsToAlertError(error)
    }
}

extension MyVaultsCoordinator {
    /// For preview purposes
    static var preview: MyVaultsCoordinator {
        .init(apiService: DummyApiService.preview,
              sessionData: .preview,
              vaultSelection: .preview)
    }
}
