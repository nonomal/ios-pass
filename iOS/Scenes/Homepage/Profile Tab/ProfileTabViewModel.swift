//
// ProfileTabViewModel.swift
// Proton Pass - Created on 07/03/2023.
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
import Macro
import ProtonCoreLogin
import ProtonCoreServices
import Screens
import SwiftUI
import UseCases

@MainActor
protocol ProfileTabViewModelDelegate: AnyObject {
    func profileTabViewModelWantsToShowSettingsMenu()
    func profileTabViewModelWantsToShowFeedback()
    func profileTabViewModelWantsToQaFeatures()
}

@MainActor
final class ProfileTabViewModel: ObservableObject, DeinitPrintable {
    deinit { print(deinitMessage) }

    private let credentialManager = resolve(\SharedServiceContainer.credentialManager)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let preferencesManager = resolve(\SharedToolingContainer.preferencesManager)
    private let accessRepository = resolve(\SharedRepositoryContainer.accessRepository)
    private let localAccessDatasource = resolve(\SharedRepositoryContainer.localAccessDatasource)
    private let organizationRepository = resolve(\SharedRepositoryContainer.organizationRepository)
    private let notificationService = resolve(\SharedServiceContainer.notificationService)
    private let securitySettingsCoordinator: SecuritySettingsCoordinator

    private let policy = resolve(\SharedToolingContainer.localAuthenticationEnablingPolicy)
    private let checkBiometryType = resolve(\SharedUseCasesContainer.checkBiometryType)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)

    // Use cases
    private let indexAllLoginItems = resolve(\SharedUseCasesContainer.indexAllLoginItems)
    private let unindexAllLoginItems = resolve(\SharedUseCasesContainer.unindexAllLoginItems)
    private let openAutoFillSettings = resolve(\UseCasesContainer.openAutoFillSettings)
    private let getSharedPreferences = resolve(\SharedUseCasesContainer.getSharedPreferences)
    private let updateSharedPreferences = resolve(\SharedUseCasesContainer.updateSharedPreferences)
    private let secureLinkManager = resolve(\ServiceContainer.secureLinkManager)
    private let getFeatureFlagStatus = resolve(\SharedUseCasesContainer.getFeatureFlagStatus)
    private let apiManager = resolve(\SharedToolingContainer.apiManager)

    @LazyInjected(\SharedServiceContainer.userManager) private var userManager: any UserManagerProtocol
    @LazyInjected(\SharedToolingContainer.authManager) private var authManager: any AuthManagerProtocol
    @LazyInjected(\SharedUseCasesContainer.fullVaultsSync) private var fullVaultsSync: any FullVaultsSyncUseCase
    @LazyInjected(\SharedUseCasesContainer.switchUser) private var switchUser: any SwitchUserUseCase
    @LazyInjected(\UseCasesContainer
        .createApiService) private var createApiService: any CreateApiServiceUseCase

    @Published private(set) var localAuthenticationMethod: LocalAuthenticationMethodUiModel = .none
    @Published private(set) var appLockTime: AppLockTime
    @Published private(set) var canUpdateAppLockTime = true
    @Published private(set) var fallbackToPasscode: Bool
    /// Whether user has picked Proton Pass as AutoFill provider in Settings
    @Published private(set) var autoFillEnabled = false
    @Published private(set) var quickTypeBar: Bool
    @Published private(set) var automaticallyCopyTotpCode: Bool
    @Published private(set) var showAutomaticCopyTotpCodeExplanation = false
    @Published private(set) var plan: Plan?
    @Published private(set) var secureLinks: [SecureLink]?

    // Accounts management
    @Published private var currentActiveUser: UserData?
    var activeAccountDetail: AccountCellDetail? {
        if let currentActiveUser {
            .init(id: currentActiveUser.userId,
                  isPremium: isPremiumUser(currentActiveUser.userId),
                  initial: currentActiveUser.initial,
                  displayName: currentActiveUser.displayName,
                  email: currentActiveUser.email)
        } else {
            nil
        }
    }

    /// User data of all logged in accounts
    @Published private var userAccounts = [UserData]()
    var accountDetails: [AccountCellDetail] {
        userAccounts.map { .init(id: $0.userId,
                                 isPremium: isPremiumUser($0.userId),
                                 initial: $0.initial,
                                 displayName: $0.displayName,
                                 email: $0.email) }
    }

    /// Accesses of all logged in accounts
    @Published private var accesses = [UserAccess]()
    @Published var showLoginFlow = false
    @Published var newLoggedUser: Result<LoginViewResult?, LoginViewError> = .success(nil)

    private var cancellables = Set<AnyCancellable>()
    weak var delegate: (any ProfileTabViewModelDelegate)?

    var isSecureLinkActive: Bool {
        getFeatureFlagStatus(with: FeatureFlagType.passPublicLinkV1)
    }

    var isMultiAccountActive: Bool {
        getFeatureFlagStatus(with: FeatureFlagType.passAccountSwitchV1)
    }

    func getApiService() -> any APIService {
        createApiService()
    }

    init(childCoordinatorDelegate: any ChildCoordinatorDelegate) {
        plan = accessRepository.access.value?.access.plan
        let securitySettingsCoordinator = SecuritySettingsCoordinator()
        securitySettingsCoordinator.delegate = childCoordinatorDelegate
        self.securitySettingsCoordinator = securitySettingsCoordinator

        let preferences = getSharedPreferences()
        appLockTime = preferences.appLockTime
        fallbackToPasscode = preferences.fallbackToPasscode
        quickTypeBar = preferences.quickTypeBar
        automaticallyCopyTotpCode = preferences.automaticallyCopyTotpCode && preferences
            .localAuthenticationMethod != .none
        refresh()
        setUp()
    }
}

// MARK: - Public APIs

extension ProfileTabViewModel {
    func upgrade() {
        router.present(for: .upgradeFlow)
    }

    func refreshPlan() async {
        do {
            accesses = try await localAccessDatasource.getAllAccesses()
            plan = try await accessRepository.refreshAccess().access.plan
        } catch {
            handle(error: error)
        }
    }

    func editLocalAuthenticationMethod() {
        Task { [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editMethod()
        }
    }

    func editAppLockTime() {
        guard canUpdateAppLockTime else { return }
        Task { [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editAppLockTime()
        }
    }

    func editPINCode() {
        Task { [weak self] in
            guard let self else {
                return
            }
            securitySettingsCoordinator.editPINCode()
        }
    }

    func handleEnableAutoFillAction() {
        openAutoFillSettings()
    }

    func toggleFallbackToPasscode() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let newValue = !fallbackToPasscode
                try await updateSharedPreferences(\.fallbackToPasscode, value: newValue)
                fallbackToPasscode = newValue
            } catch {
                handle(error: error)
            }
        }
    }

    func toggleQuickTypeBar() {
        Task { [weak self] in
            guard let self else { return }
            defer { router.display(element: .globalLoading(shouldShow: false)) }
            do {
                router.display(element: .globalLoading(shouldShow: true))
                let newValue = !quickTypeBar
                async let updateSharedPreferences: () = updateSharedPreferences(\.quickTypeBar,
                                                                                value: newValue)
                async let reindex: () = reindexCredentials(newValue)
                _ = try await (updateSharedPreferences, reindex)
                quickTypeBar = newValue
            } catch {
                handle(error: error)
            }
        }
    }

    func toggleAutomaticCopyTotpCode() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let localAuthenticationMethod = getSharedPreferences().localAuthenticationMethod
                if !automaticallyCopyTotpCode, localAuthenticationMethod == .none {
                    showAutomaticCopyTotpCodeExplanation = true
                    return
                }
                let newValue = !automaticallyCopyTotpCode
                if newValue {
                    notificationService.requestNotificationPermission()
                }
                try await updateSharedPreferences(\.automaticallyCopyTotpCode, value: newValue)
                automaticallyCopyTotpCode = newValue && localAuthenticationMethod != .none
            } catch {
                handle(error: error)
            }
        }
    }

    func manageAccount(_ account: AccountCellDetail) {
        router.action(.manage(userId: account.id))
    }

    func showSettingsMenu() {
        delegate?.profileTabViewModelWantsToShowSettingsMenu()
    }

    func showPrivacyPolicy() {
        router.navigate(to: .urlPage(urlString: ProtonLink.privacyPolicy))
    }

    func showTermsOfService() {
        router.navigate(to: .urlPage(urlString: ProtonLink.termsOfService))
    }

    func showImportInstructions() {
        router.navigate(to: .urlPage(urlString: ProtonLink.howToImport))
    }

    func showTutorial() {
        router.present(for: .tutorial)
    }

    func showFeedback() {
        delegate?.profileTabViewModelWantsToShowFeedback()
    }

    func qaFeatures() {
        delegate?.profileTabViewModelWantsToQaFeatures()
    }

    func `switch`(to account: AccountCellDetail) {
        guard account.id != currentActiveUser?.userId else { return }
        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                try await switchUser(userId: account.id)
            } catch {
                handle(error: error)
            }
        }
    }

    func signOut(account: AccountCellDetail) {
        router.action(.signOut(userId: account.id))
    }
}

// MARK: - Secure link

extension ProfileTabViewModel {
    func fetchSecureLinks() {
        Task { [weak self] in
            guard let self else { return }
            do {
                secureLinks = try await secureLinkManager.updateSecureLinks()
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func showSecureLinkList() {
        router.present(for: .secureLinks)
    }

    func upsell(entryPoint: UpsellEntry) {
        router.present(for: .upselling(entryPoint.defaultConfiguration))
    }
}

// MARK: - Private APIs

private extension ProfileTabViewModel {
    func setUp() {
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                refresh()
            }
            .store(in: &cancellables)

        preferencesManager
            .sharedPreferencesUpdates
            .receive(on: DispatchQueue.main)
            .filter(\.appLockTime)
            .sink { [weak self] newValue in
                guard let self else { return }
                appLockTime = newValue
            }
            .store(in: &cancellables)

        preferencesManager
            .sharedPreferencesUpdates
            .receive(on: DispatchQueue.main)
            .filter(\.localAuthenticationMethod)
            .sink { [weak self] _ in
                guard let self else { return }
                refreshLocalAuthenticationMethod()
                showAutomaticCopyTotpCodeExplanation = false
            }
            .store(in: &cancellables)

        $plan
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] plan in
                guard let self else { return }
                if plan.isBusinessUser {
                    applyOrganizationSettings()
                }
            }
            .store(in: &cancellables)

        secureLinkManager.currentSecureLinks
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLinks in
                guard let self, secureLinks != newLinks else { return }
                secureLinks = newLinks
            }
            .store(in: &cancellables)

        userManager
            .currentActiveUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                currentActiveUser = user
                Task { [weak self] in
                    guard let self else {
                        return
                    }
                    userAccounts = await (try? userManager.getAllUsers()) ?? []
                    await refreshPlan()
                    fetchSecureLinks()
                }
            }
            .store(in: &cancellables)

        $newLoggedUser
            .dropFirst()
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self else { return }
                showLoginFlow = false
                newLoggedUser = .success(nil)
                parseNewUser(result: result)
            }
            .store(in: &cancellables)
    }

    func forceSync() async throws {
        router.present(for: .fullSync)
        logger.info("Doing full sync")
        try await fullVaultsSync()
        logger.info("Done full sync")
        router.display(element: .successMessage(config: .refresh))
    }

    func refresh() {
        Task { [weak self] in
            guard let self else { return }
            autoFillEnabled = await credentialManager.isAutoFillEnabled
            refreshLocalAuthenticationMethod()
        }
    }

    func refreshLocalAuthenticationMethod() {
        switch getSharedPreferences().localAuthenticationMethod {
        case .none:
            localAuthenticationMethod = .none
            automaticallyCopyTotpCode = false
        case .biometric:
            do {
                let biometryType = try checkBiometryType(policy: policy)
                localAuthenticationMethod = .biometric(biometryType)
            } catch {
                // Fallback to `none`, not much we can do except displaying the error
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
                localAuthenticationMethod = .none
            }
        case .pin:
            localAuthenticationMethod = .pin
        }
    }

    func applyOrganizationSettings() {
        Task { [weak self] in
            guard let self else { return }
            do {
                if let organization = try await organizationRepository.getOrganization() {
                    canUpdateAppLockTime = organization.settings?.appLockTime == nil
                }
            } catch {
                handle(error: error)
            }
        }
    }

    func reindexCredentials(_ indexable: Bool) async throws {
        // When not enabled, iOS already deleted the credential database.
        // Attempting to populate this database will throw an error anyway so early exit here
        guard autoFillEnabled else { return }
        logger.trace("Reindexing credentials")
        if indexable {
            try await indexAllLoginItems()
        } else {
            try await unindexAllLoginItems()
        }
        logger.info("Reindexed credentials")
    }

    func isPremiumUser(_ userId: String) -> Bool {
        accesses.first(where: { $0.userId == userId })?.access.plan.isFreeUser == false
    }

    func handle(error: any Error) {
        logger.error(error)
        router.display(element: .displayErrorBanner(error))
    }
}

private extension UserData {
    var userId: String { user.ID }
    var displayName: String { user.name ?? "?" }
    var email: String { user.email ?? "?" }
    var initial: String { user.name?.first?.uppercased() ?? user.email?.first?.uppercased() ?? "?" }
}

// MARK: - New user login

private extension ProfileTabViewModel {
    func parseNewUser(result: Result<LoginViewResult?, LoginViewError>) {
        Task { [weak self] in
            guard let self else { return }
            do {
                switch result {
                case let .success(newUser):
                    guard let newUser else {
                        return
                    }
                    // give the time to the login screen to dismiss
                    try? await Task.sleep(for: .seconds(1))
                    try await userManager.addAndMarkAsActive(userData: newUser.userData)
                    await apiManager.updateCurrentSession(userId: newUser.userData.userId)
                    try await preferencesManager.switchUserPreferences(userId: newUser.userData.userId)
                    if newUser.hasExtraPassword {
                        try await preferencesManager.updateUserPreferences(\.extraPasswordEnabled,
                                                                           value: true)
                    }
                    try await forceSync()
                case let .failure(error):
                    let currentUserId = try await userManager.getActiveUserId()

                    // This must be done as the authManager sets the new session id in apimanger/apiservice
                    // during the extra password flow
                    // We must revert to previous user session id and remove all session in auth session
                    // linked to the failed user
                    await apiManager.updateCurrentSession(userId: currentUserId)
                    authManager.clearSessions(userId: error.value)
                }
            } catch {
                handle(error: error)
            }
        }
    }
}
