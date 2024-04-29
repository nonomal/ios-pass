//
// TelemetryEventsSection.swift
// Proton Pass - Created on 25/04/2023.
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
import DesignSystem
import Entities
import Factory
import SwiftUI

struct TelemetryEventsSection: View {
    var body: some View {
        NavigationLink(destination: { TelemetryEventsView() },
                       label: { Text(verbatim: "Telemetry events") })
    }
}

private struct TelemetryEventUiModel: Identifiable {
    var id: String { event.uuid }
    let event: TelemetryEvent
    let relativeDate: String

    init(event: TelemetryEvent, formatter: RelativeDateTimeFormatter) {
        self.event = event
        relativeDate = formatter.localizedString(for: Date(timeIntervalSince1970: event.time),
                                                 relativeTo: .now)
    }
}

@MainActor
private final class TelemetryEventsViewModel: ObservableObject {
    private let telemetryEventRepository = resolve(\SharedRepositoryContainer.telemetryEventRepository)
    private let userDataProvider = resolve(\SharedDataContainer.userDataProvider)

    @Published private(set) var uiModels = [TelemetryEventUiModel]()
    @Published private(set) var relativeThreshold = ""
    @Published private(set) var error: Error?

    init() {
        refresh()
    }

    func refresh() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let formatter = RelativeDateTimeFormatter()
                if let threshold = await telemetryEventRepository.scheduler.getThreshold() {
                    let relativeDate = formatter.localizedString(for: threshold, relativeTo: .now)
                    relativeThreshold = "Next batch \(relativeDate)"
                }
                let userId = try userDataProvider.getUserId()
                let events = try await telemetryEventRepository.getAllEvents(userId: userId)
                // Reverse to move new events to the top of the list
                uiModels = events.reversed().map { TelemetryEventUiModel(event: $0,
                                                                         formatter: formatter) }
                error = nil
            } catch {
                self.error = error
            }
        }
    }
}

private struct TelemetryEventsView: View {
    @StateObject private var viewModel = TelemetryEventsViewModel()

    var body: some View {
        if let error = viewModel.error {
            RetryableErrorView(errorMessage: error.localizedDescription, onRetry: viewModel.refresh)
        } else {
            if viewModel.uiModels.isEmpty {
                Form {
                    Text(verbatim: "No events")
                        .foregroundStyle(PassColor.textWeak.toColor)
                }
            } else {
                eventsList
            }
        }
    }

    private var eventsList: some View {
        Form {
            Section(content: {
                ForEach(viewModel.uiModels) { uiModel in
                    EventView(uiModel: uiModel)
                }
            }, header: {
                Text(verbatim: "\(viewModel.uiModels.count) pending event(s)")
            })
        }
        .navigationTitle(viewModel.relativeThreshold)
    }
}

private struct EventView: View {
    let uiModel: TelemetryEventUiModel

    var body: some View {
        let event = uiModel.event
        Label(title: {
            VStack(alignment: .leading) {
                Text(uiModel.event.type.emoji)
                    .foregroundStyle(PassColor.textNorm.toColor)

                Text(uiModel.relativeDate)
                    .font(.footnote)
                    .foregroundStyle(PassColor.textWeak.toColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }, icon: {
            CircleButton(icon: event.type.icon,
                         iconColor: event.type.iconColor,
                         backgroundColor: event.type.backgroundColor)
        })
    }
}

private extension TelemetryEventType {
    var icon: UIImage {
        switch self {
        case let .create(type):
            type.regularIcon
        case let .read(type):
            type.regularIcon
        case let .update(type):
            type.regularIcon
        case let .delete(type):
            type.regularIcon
        case .autofillDisplay, .autofillTriggeredFromApp, .autofillTriggeredFromSource:
            // swiftlint:disable:next force_unwrapping
            UIImage(systemName: "rectangle.and.pencil.and.ellipsis")!
        case .searchClick, .searchTriggered:
            // swiftlint:disable:next force_unwrapping
            UIImage(systemName: "magnifyingglass")!
        case .twoFaCreation, .twoFaUpdate:
            // swiftlint:disable:next force_unwrapping
            UIImage(systemName: "2.circle")!
        case .passkeyAuth, .passkeyCreate, .passkeyDisplay:
            PassIcon.passkey
        case .monitorAddCustomEmailFromSuggestion,
             .monitorDisplayDarkWebMonitoring,
             .monitorDisplayExcludedItems,
             .monitorDisplayHome,
             .monitorDisplayMissing2FA,
             .monitorDisplayMonitoringEmailAliases,
             .monitorDisplayMonitoringProtonAddresses,
             .monitorDisplayReusedPasswords,
             .monitorDisplayWeakPasswords,
             .monitorItemDetailFromMissing2FA,
             .monitorItemDetailFromReusedPassword,
             .monitorItemDetailFromWeakPassword:
            // swiftlint:disable:next force_unwrapping
            UIImage(systemName: "person.badge.shield.checkmark.fill")!
        }
    }

    var iconColor: UIColor {
        switch self {
        case let .create(type):
            type.normMajor1Color
        case let .read(type):
            type.normMajor1Color
        case let .update(type):
            type.normMajor1Color
        case let .delete(type):
            type.normMajor1Color
        case .autofillDisplay,
             .autofillTriggeredFromApp,
             .autofillTriggeredFromSource,
             .passkeyAuth,
             .passkeyCreate,
             .passkeyDisplay:
            PassColor.signalInfo
        case .searchClick, .searchTriggered:
            PassColor.signalDanger
        case .twoFaCreation, .twoFaUpdate:
            ItemContentType.login.normMajor1Color
        case .monitorAddCustomEmailFromSuggestion,
             .monitorDisplayDarkWebMonitoring,
             .monitorDisplayExcludedItems,
             .monitorDisplayHome,
             .monitorDisplayMissing2FA,
             .monitorDisplayMonitoringEmailAliases,
             .monitorDisplayMonitoringProtonAddresses,
             .monitorDisplayReusedPasswords,
             .monitorDisplayWeakPasswords,
             .monitorItemDetailFromMissing2FA,
             .monitorItemDetailFromReusedPassword,
             .monitorItemDetailFromWeakPassword:
            ItemContentType.note.normMajor1Color
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case let .create(type):
            type.normMinor1Color
        case let .read(type):
            type.normMinor1Color
        case let .update(type):
            type.normMinor1Color
        case let .delete(type):
            type.normMinor1Color
        case .autofillDisplay,
             .autofillTriggeredFromApp,
             .autofillTriggeredFromSource,
             .passkeyAuth,
             .passkeyCreate,
             .passkeyDisplay:
            PassColor.signalInfo.withAlphaComponent(0.16)
        case .searchClick, .searchTriggered:
            PassColor.signalDanger.withAlphaComponent(0.16)
        case .twoFaCreation, .twoFaUpdate:
            ItemContentType.login.normMinor1Color
        case .monitorAddCustomEmailFromSuggestion,
             .monitorDisplayDarkWebMonitoring,
             .monitorDisplayExcludedItems,
             .monitorDisplayHome,
             .monitorDisplayMissing2FA,
             .monitorDisplayMonitoringEmailAliases,
             .monitorDisplayMonitoringProtonAddresses,
             .monitorDisplayReusedPasswords,
             .monitorDisplayWeakPasswords,
             .monitorItemDetailFromMissing2FA,
             .monitorItemDetailFromReusedPassword,
             .monitorItemDetailFromWeakPassword:
            ItemContentType.note.normMinor1Color
        }
    }

    var emoji: String {
        switch self {
        case .create:
            "Create ➕"
        case .read:
            "Read 🗒️"
        case .update:
            "Update ✏️"
        case .delete:
            "Delete ❌"
        case .autofillDisplay:
            "AutoFill extension opened 🔑"
        case .autofillTriggeredFromSource:
            "Autofilled from QuickType bar ⌨️"
        case .autofillTriggeredFromApp:
            "Autofilled from extension 📱"
        case .searchClick:
            "Pick search result 🔎"
        case .searchTriggered:
            "Open search 🔎"
        case .twoFaCreation:
            "Create 2FA"
        case .twoFaUpdate:
            "Update 2FA"
        case .passkeyCreate:
            "Create passkey"
        case .passkeyAuth:
            "Authenticate with passkey"
        case .passkeyDisplay:
            "Display passkeys"
        case .monitorDisplayHome:
            "Display monitor homepage"
        case .monitorDisplayWeakPasswords:
            "Display weak passwords"
        case .monitorDisplayReusedPasswords:
            "Display reused passwords"
        case .monitorDisplayMissing2FA:
            "Display missing 2FA"
        case .monitorDisplayExcludedItems:
            "Display exluced items"
        case .monitorDisplayDarkWebMonitoring:
            "Display dark web monitoring"
        case .monitorDisplayMonitoringProtonAddresses:
            "Display monitored Proton addresses"
        case .monitorDisplayMonitoringEmailAliases:
            "Display monitored aliases"
        case .monitorAddCustomEmailFromSuggestion:
            "Add custom email from suggestion"
        case .monitorItemDetailFromWeakPassword:
            "View item detail from weak password list"
        case .monitorItemDetailFromMissing2FA:
            "View item detail from missing 2FA list"
        case .monitorItemDetailFromReusedPassword:
            "View item detail from reused password list"
        }
    }
}
