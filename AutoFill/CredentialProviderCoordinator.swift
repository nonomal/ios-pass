//
// CredentialProviderCoordinator.swift
// Proton Pass - Created on 27/09/2022.
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

@preconcurrency import AuthenticationServices
import Client
@preconcurrency import Combine
import Core
import DesignSystem
import Entities
import Factory
import Macro
import Screens
import SwiftUI

typealias UserForNewItemSubject = PassthroughSubject<UserUiModel, Never>

@MainActor
final class CredentialProviderCoordinator: DeinitPrintable {
    /// Self-initialized properties
    private let setUpSentry = resolve(\SharedUseCasesContainer.setUpSentry)
    private let setCoreLoggerEnvironment = resolve(\SharedUseCasesContainer.setCoreLoggerEnvironment)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let userForNewItemSubject = UserForNewItemSubject()

    private weak var rootViewController: UIViewController?
    private weak var context: ASCredentialProviderExtensionContext?
    private var cancellables = Set<AnyCancellable>()

    // Use cases
    private let completeConfiguration = resolve(\AutoFillUseCaseContainer.completeConfiguration)
    private let cancelAutoFill = resolve(\AutoFillUseCaseContainer.cancelAutoFill)
    private let sendErrorToSentry = resolve(\SharedUseCasesContainer.sendErrorToSentry)

    // Lazily injected because some use cases are dependent on repositories
    // which are not registered when the user is not logged in
    @LazyInjected(\SharedUseCasesContainer.addTelemetryEvent) private var addTelemetryEvent
    @LazyInjected(\SharedUseCasesContainer.indexAllLoginItems) private var indexAllLoginItems
    @LazyInjected(\AutoFillUseCaseContainer.checkAndAutoFill) private var checkAndAutoFill
    @LazyInjected(\AutoFillUseCaseContainer.completeAutoFill) private var completeAutoFill
    @LazyInjected(\AutoFillUseCaseContainer.completePasskeyRegistration) private var completePasskeyRegistration
    @LazyInjected(\SharedViewContainer.bannerManager) private var bannerManager
    @LazyInjected(\SharedServiceContainer.upgradeChecker) private var upgradeChecker
    @LazyInjected(\SharedServiceContainer.vaultsManager) private var vaultsManager
    @LazyInjected(\SharedUseCasesContainer.getSharedPreferences) private var getSharedPreferences
    @LazyInjected(\SharedUseCasesContainer.getUserPreferences) private var getUserPreferences
    @LazyInjected(\SharedUseCasesContainer.setUpBeforeLaunching) private var setUpBeforeLaunching
    @LazyInjected(\SharedServiceContainer.userManager) private var userManager
    @LazyInjected(\SharedRepositoryContainer.itemRepository) private var itemRepository
    @LazyInjected(\SharedToolingContainer.authManager) private var authManager
    @LazyInjected(\SharedUseCasesContainer.logOutAllAccounts) var logOutAllAccounts
    @LazyInjected(\SharedUseCasesContainer.refreshFeatureFlags) var refreshFeatureFlags
    @LazyInjected(\SharedUseCasesContainer.getUserUiModels) var getUserUiModels

    /// Derived properties
    private var lastChildViewController: UIViewController?
    private var currentCreateEditItemViewModel: BaseCreateEditItemViewModel?
    private var credentialsViewModel: CredentialsViewModel?
    private var generatePasswordCoordinator: GeneratePasswordCoordinator?
    private var customCoordinator: (any CustomCoordinator)?
    private var startTask: Task<Void, Never>?

    private var topMostViewController: UIViewController? {
        rootViewController?.topMostViewController
    }

    init(rootViewController: UIViewController, context: ASCredentialProviderExtensionContext) {
        SharedViewContainer.shared.register(rootViewController: rootViewController)
        self.rootViewController = rootViewController
        self.context = context

        // Post init
        setUpSentry()
        setCoreLoggerEnvironment()
        AppearanceSettings.apply()
        setUpRouting()
    }

    deinit {
        startTask?.cancel()
        startTask = nil
        print(deinitMessage)
    }

    /// Necessary set up like initializing preferences and theme before starting user flow
    func setUpAndStart(mode: AutoFillMode) {
        startTask?.cancel()
        startTask = nil
        startTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await setUpBeforeLaunching(rootContainer: .viewController(rootViewController))
                refreshFeatureFlags()
                // This need to be set after user data is loaded as we now depend on active user id to set session
                // to the api service
                authManager.sessionWasInvalidated
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] sessionInfos in
                        guard let self, let userId = sessionInfos.userId else { return }
                        logOut(userId: userId,
                               error: PassError.unexpectedLogout,
                               sessionId: sessionInfos.sessionId)
                    }
                    .store(in: &cancellables)
                try await start(mode: mode)
            } catch {
                handle(error: error)
            }
        }
    }
}

private extension CredentialProviderCoordinator {
    func start(mode: AutoFillMode) async throws {
        let users = try await getUserUiModels()
        switch mode {
        case let .showAllLogins(identifiers, requestParams):
            handleShowAllLoginsMode(users: users,
                                    identifiers: identifiers,
                                    passkeyRequestParams: requestParams)

        case let .checkAndAutoFill(request):
            handleCheckAndAutoFill(request)

        case let .authenticateAndAutofill(request):
            handleAuthenticateAndAutofill(request)

        case .configuration:
            configureExtension()

        case let .passkeyRegistration(request):
            handlePasskeyRegistration(users: users, request: request)

        case let .showOneTimeCodes(identifiers):
            handleShowOneTimeCodes(users: users, identifiers: identifiers)
        }
    }

    func handleShowAllLoginsMode(users: [UserUiModel],
                                 identifiers: [ASCredentialServiceIdentifier],
                                 passkeyRequestParams: (any PasskeyRequestParametersProtocol)?) {
        guard let context else { return }

        guard userManager.activeUserId != nil else {
            showNotLoggedInView()
            return
        }

        let viewModel = CredentialsViewModel(users: users,
                                             serviceIdentifiers: identifiers,
                                             passkeyRequestParams: passkeyRequestParams,
                                             context: context,
                                             userForNewItemSubject: userForNewItemSubject)
        viewModel.delegate = self
        credentialsViewModel = viewModel
        showView(CredentialsView(viewModel: viewModel))

        addNewEvent(type: .autofillDisplay)
        if passkeyRequestParams != nil {
            addNewEvent(type: .passkeyDisplay)
        }
    }

    func handleCheckAndAutoFill(_ request: AutoFillRequest) {
        Task { [weak self] in
            guard let self, let context else { return }
            do {
                guard let recordIdentifier = request.recordIdentifier else {
                    throw ASExtensionError(.credentialIdentityNotFound)
                }

                let ids = try IDs.deserializeBase64(recordIdentifier)
                guard let item = try await itemRepository.getItem(shareId: ids.shareId, itemId: ids.itemId) else {
                    throw ASExtensionError(.credentialIdentityNotFound)
                }

                let localAuthenticationMethod = getSharedPreferences().localAuthenticationMethod
                try await checkAndAutoFill(request,
                                           userId: item.userId,
                                           context: context,
                                           localAuthenticationMethod: localAuthenticationMethod)
            } catch {
                logger.error(error)
                cancelAutoFill(reason: .failed, context: context)
            }
        }
    }

    func handleAuthenticateAndAutofill(_ request: AutoFillRequest) {
        let viewModel = LockedCredentialViewModel(request: request) { [weak self] result in
            guard let self, let context else { return }
            switch result {
            case let .success((credential, itemContent)):
                Task { [weak self] in
                    guard let self else { return }
                    try? await completeAutoFill(quickTypeBar: false,
                                                identifiers: request.serviceIdentifiers,
                                                credential: credential,
                                                itemContent: itemContent,
                                                context: context)
                }
            case let .failure(error):
                handle(error: error)
            }
        }
        showView(LockedCredentialView(viewModel: viewModel))
    }

    func handlePasskeyRegistration(users: [UserUiModel],
                                   request: PasskeyCredentialRequest) {
        guard let context else { return }
        let viewModel = PasskeyCredentialsViewModel(users: users,
                                                    request: request,
                                                    context: context,
                                                    userForNewItemSubject: userForNewItemSubject)
        viewModel.delegate = self
        let view = PasskeyCredentialsView(viewModel: viewModel)
        showView(view)
    }

    func handleShowOneTimeCodes(users: [UserUiModel],
                                identifiers: [ASCredentialServiceIdentifier]) {
        guard userManager.activeUserId != nil else {
            showNotLoggedInView()
            return
        }
        guard let context else { return }
        #if DEBUG
        /// As of iOS 18.0, the list of service identifiers is always empty
        /// even though iOS could detect the OTP form
        /// So we mock it for testing purpose
        let filth = ASCredentialServiceIdentifier(identifier: "https://autofilth.lol", type: .URL)
        let viewModel = OneTimeCodesViewModel(users: users,
                                              serviceIdentifiers: [filth],
                                              context: context,
                                              userForNewItemSubject: userForNewItemSubject)
        #else
        let viewModel = OneTimeCodesViewModel(users: users,
                                              serviceIdentifiers: identifiers,
                                              context: context,
                                              userForNewItemSubject: userForNewItemSubject)
        #endif
        viewModel.delegate = self
        showView(OneTimeCodesView(viewModel: viewModel))
    }
}

private extension CredentialProviderCoordinator {
    func configureExtension() {
        guard let context else { return }
        guard let activeUserId = userManager.activeUserId else {
            showNotLoggedInView()
            return
        }

        let view = ExtensionSettingsView(onDismiss: { [weak self] in
            guard let self else { return }
            completeConfiguration(context: context)
        }, onLogOut: { [weak self] _ in
            guard let self else { return }
            logOut(userId: activeUserId) { [weak self] in
                guard let self else { return }
                completeConfiguration(context: context)
            }
        })
        showView(view)
    }
}

extension CredentialProviderCoordinator: ExtensionCoordinator {
    public func getRootViewController() -> UIViewController? {
        rootViewController
    }

    public func getLastChildViewController() -> UIViewController? {
        lastChildViewController
    }

    public func setLastChildViewController(_ viewController: UIViewController) {
        lastChildViewController = viewController
    }
}

// MARK: - Setup & Utils

private extension CredentialProviderCoordinator {
    func setUpRouting() {
        router
            .newSheetDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                guard let self else { return }
                switch destination {
                case .upgradeFlow:
                    startUpgradeFlow()
                case let .createItem(item, type, response):
                    handleItemCreation(item, type: type, response: response)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        router
            .globalElementDisplay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                guard let self else { return }
                switch destination {
                case let .globalLoading(shouldShow):
                    if shouldShow {
                        showLoadingHud()
                    } else {
                        hideLoadingHud()
                    }
                case let .displayErrorBanner(error):
                    bannerManager.displayTopErrorMessage(error)
                case let .errorMessage(message):
                    bannerManager.displayTopErrorMessage(message)
                default:
                    return
                }
            }
            .store(in: &cancellables)
    }

    func presentSelectUserActionSheet(_ users: [UserUiModel]) {
        let alert = UIAlertController(title: #localized("Select account"),
                                      message: nil,
                                      preferredStyle: .actionSheet)
        for user in users {
            alert.addAction(.init(title: user.email ?? user.displayName ?? "?",
                                  style: .default,
                                  handler: { [weak self] _ in
                                      guard let self else { return }
                                      userForNewItemSubject.send(user)
                                  }))
        }

        alert.addAction(.init(title: #localized("Cancel"), style: .cancel))
        present(alert)
    }

    func handle(error: any Error) {
        guard let context else { return }
        let defaultHandler: (any Error) -> Void = { [weak self] error in
            guard let self else { return }
            logger.error(error)
            alert(error: error) { [weak self] in
                guard let self else { return }
                cancelAutoFill(reason: .failed, context: context)
            }
        }

        guard let error = error as? PassError,
              case let .credentialProvider(reason) = error else {
            defaultHandler(error)
            return
        }

        switch reason {
        case .userCancelled:
            cancelAutoFill(reason: .userCanceled, context: context)
            return

        case .failedToAuthenticate:
            guard let userId = userManager.activeUserId else {
                return defaultHandler(error)
            }
            return logOut(userId: userId) { [weak self] in
                guard let self else { return }
                // swiftlint:disable:next todo
                // TODO: should we always call the cancelAutoFill as we will be able to have multiple account for one user
                // this means we should in some case only reload the data to remove the deleted content.
                cancelAutoFill(reason: .failed, context: context)
            }

        default:
            defaultHandler(error)
        }
    }

    func addNewEvent(type: TelemetryEventType) {
        addTelemetryEvent(with: type)
    }

    func logOut(userId: String,
                error: (any Error)? = nil,
                sessionId: String? = nil,
                completion: (() -> Void)? = nil) {
        Task { [weak self] in
            guard let self else { return }
            if let error {
                sendErrorToSentry(error, userId: userId, sessionId: sessionId)
            }

            do {
                try await logOutAllAccounts()
                showNotLoggedInView()
            } catch {
                logger.error(error)
            }
            completion?()
        }
    }
}

// MARK: - Views for routing

private extension CredentialProviderCoordinator {
    func showNotLoggedInView() {
        guard let context else { return }
        let view = NotLoggedInView(variant: .autoFillExtension) { [weak self] in
            guard let self else { return }
            cancelAutoFill(reason: .userCanceled, context: context)
        }
        showView(view)
    }

    func showCreateNewItem(_ info: LoginCreationInfo) async {
        do {
            let vaults = info.vaults
            let lastCreateItemVault = vaults.first { $0.shareId == getUserPreferences().lastCreatedItemShareId }
            let shareId = (lastCreateItemVault ?? vaults.oldestOwned)?.shareId ?? ""

            let userId = info.userId
            // Temporarily switch the on-memory active user and reload the vaults contents
            // This is to work-around the fact that many of our repositories, use cases, view models
            // still depend on the active user instead of dynamically take a userID
            // especially when creating new login items we need to check some limitations
            // (login with 2FA, custom fields...)
            try await userManager.switchActiveUser(with: userId, onMemory: true)
            try await vaultsManager.asyncRefresh(userId: userId)

            let creationType = ItemCreationType.login(title: info.url?.host,
                                                      url: info.url?.schemeAndHost,
                                                      autofill: true,
                                                      passkeyCredentialRequest: info.request)
            let viewModel = try CreateEditLoginViewModel(mode: .create(shareId: shareId,
                                                                       type: creationType),
                                                         upgradeChecker: upgradeChecker,
                                                         vaults: vaults)
            viewModel.delegate = self
            present(CreateEditLoginView(viewModel: viewModel),
                    dismissBeforePresenting: true)
            currentCreateEditItemViewModel = viewModel
        } catch {
            logger.error(error)
            bannerManager.displayTopErrorMessage(error)
        }
    }

    func showGeneratePasswordView(delegate: any GeneratePasswordViewModelDelegate) {
        let coordinator = GeneratePasswordCoordinator(generatePasswordViewModelDelegate: delegate,
                                                      mode: .createLogin)
        coordinator.delegate = self
        coordinator.start()
        generatePasswordCoordinator = coordinator
    }

    func handleCreatedItem(_ itemContentType: ItemContentType) {
        topMostViewController?.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            bannerManager.displayBottomSuccessMessage(itemContentType.creationMessage)
        }
    }

    func present(_ view: some View, dismissBeforePresenting: Bool) {
        let viewController = UIHostingController(rootView: view)
        present(viewController, dismissBeforePresenting: dismissBeforePresenting)
    }

    func present(_ viewController: UIViewController,
                 animated: Bool = true,
                 dismissible: Bool = false,
                 dismissBeforePresenting: Bool = false) {
        viewController.isModalInPresentation = !dismissible
        viewController.overrideUserInterfaceStyle = rootViewController?
            .overrideUserInterfaceStyle ?? .unspecified
        if dismissBeforePresenting {
            rootViewController?.topMostViewController.dismiss(animated: animated) { [weak self] in
                guard let self else { return }
                rootViewController?.topMostViewController.present(viewController,
                                                                  animated: animated)
            }
        } else {
            topMostViewController?.present(viewController, animated: animated)
        }
    }

    func startUpgradeFlow() {
        let alert = UIAlertController(title: "Upgrade",
                                      message: "Please open Proton Pass app to upgrade",
                                      preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okButton)
        rootViewController?.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            rootViewController?.present(alert, animated: true)
        }
    }
}

// MARK: - GeneratePasswordCoordinatorDelegate

extension CredentialProviderCoordinator: GeneratePasswordCoordinatorDelegate {
    func generatePasswordCoordinatorWantsToPresent(viewController: UIViewController) {
        present(viewController)
    }
}

// MARK: - CreateEditItemViewModelDelegate

extension CredentialProviderCoordinator: CreateEditItemViewModelDelegate {
    func createEditItemViewModelWantsToAddCustomField(delegate: any CustomFieldAdditionDelegate,
                                                      shouldDisplayTotp: Bool) {
        guard let rootViewController else {
            return
        }
        customCoordinator = CustomFieldAdditionCoordinator(rootViewController: rootViewController,
                                                           delegate: delegate,
                                                           shouldShowTotp: shouldDisplayTotp)
        customCoordinator?.start()
    }

    func createEditItemViewModelWantsToEditCustomFieldTitle(_ uiModel: CustomFieldUiModel,
                                                            delegate: any CustomFieldEditionDelegate) {
        guard let rootViewController else {
            return
        }
        customCoordinator = CustomFieldEditionCoordinator(rootViewController: rootViewController,
                                                          delegate: delegate,
                                                          uiModel: uiModel)
        customCoordinator?.start()
    }

    func handleItemCreation(_ item: SymmetricallyEncryptedItem,
                            type: ItemContentType,
                            response: CreatePasskeyResponse?) {
        switch type {
        case .login:
            Task { [weak self] in
                guard let self, let context else { return }
                do {
                    if getSharedPreferences().quickTypeBar {
                        try await indexAllLoginItems()
                    }
                    if let response {
                        completePasskeyRegistration(response, context: context)
                    } else {
                        credentialsViewModel?.select(item: item)
                    }
                } catch {
                    logger.error(error)
                }
            }

        case .alias:
            if let email = item.item.aliasEmail {
                context?.completeRequest(withSelectedCredential: .init(user: email, password: ""))
            }

        default:
            handleCreatedItem(type)
        }
        addNewEvent(type: .create(type))
    }
}

// MARK: - CreateEditLoginViewModelDelegate

extension CredentialProviderCoordinator: CreateEditLoginViewModelDelegate {
    func createEditLoginViewModelWantsToGenerateAlias(options: AliasOptions,
                                                      creationInfo: AliasCreationLiteInfo,
                                                      delegate: any AliasCreationLiteInfoDelegate) {
        let viewModel = CreateAliasLiteViewModel(options: options, creationInfo: creationInfo)
        viewModel.aliasCreationDelegate = delegate
        let view = CreateAliasLiteView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        viewController.sheetPresentationController?.detents = [.medium()]
        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController, dismissible: true)
    }

    func createEditLoginViewModelWantsToGeneratePassword(_ delegate: any GeneratePasswordViewModelDelegate) {
        showGeneratePasswordView(delegate: delegate)
    }
}

extension CredentialProviderCoordinator: AutoFillViewModelDelegate {
    func autoFillViewModelWantsToCreateNewItem(_ info: LoginCreationInfo) {
        Task { [weak self] in
            guard let self else { return }
            await showCreateNewItem(info)
        }
    }

    func autoFillViewModelWantsToSelectUser(_ users: [Entities.UserUiModel]) {
        presentSelectUserActionSheet(users)
    }

    func autoFillViewModelWantsToCancel() {
        if let context {
            cancelAutoFill(reason: .userCanceled, context: context)
        } else {
            assertionFailure("AutoFill context should not be nil")
        }
    }

    func autoFillViewModelWantsToLogOut() {
        guard let userId = userManager.activeUserId else { return }
        logOut(userId: userId)
    }

    func autoFillViewModelWantsToPresentSortTypeList(selectedSortType: SortType,
                                                     delegate: any SortTypeListViewModelDelegate) {
        guard let rootViewController else {
            return
        }
        let viewModel = SortTypeListViewModel(sortType: selectedSortType)
        viewModel.delegate = delegate
        let view = SortTypeListView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * SortType.allCases.count + 60
        viewController.setDetentType(.custom(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController, dismissible: true)
    }
}
