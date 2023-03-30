//
// SettingsView.swift
// Proton Pass - Created on 28/09/2022.
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

import Core
import SwiftUI
import UIComponents

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            GeneralSettingsSection(viewModel: viewModel)
            SecondSection(viewModel: viewModel)
            ApplicationSection(viewModel: viewModel)
            DeleteAccountSection(onDelete: viewModel.deleteAccount)
        }
        .navigationTitle("Settings")
    }
}

private struct SecondSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section {
            askBeforeTrashingOption
            themeOption
        }
    }

    private var askBeforeTrashingOption: some View {
        Toggle(isOn: $viewModel.askBeforeTrashing) {
            Text("Ask Before Trashing")
        }
        .tint(.interactionNorm)
    }

    @ViewBuilder
    private var themeOption: some View {
        if #unavailable(iOS 16.0) {
            HStack {
                Text("Theme")
                Spacer()
                Label(title: {
                    Text(viewModel.theme.description)
                }, icon: {
                    Image(uiImage: viewModel.theme.icon)
                })
                .foregroundColor(.secondary)
                ChevronRight()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: viewModel.updateTheme)
        } else {
            Picker("Theme", selection: $viewModel.theme) {
                ForEach(Theme.allCases, id: \.rawValue) { theme in
                    HStack {
                        Label(title: {
                            Text(theme.description)
                        }, icon: {
                            Image(uiImage: theme.icon)
                        })
                    }
                    .tag(theme)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ApplicationSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section(content: {
            HStack {
                Text("View Logs")
                Spacer()
                ChevronRight()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: viewModel.viewLogs)

            Button(action: viewModel.fullSync) {
                Text("Force Synchronization")
            }
            .foregroundColor(.interactionNorm)
        }, header: {
            Text("Application")
        }, footer: {
            Text("Download all your items again to make sure you are in sync.")
        })
    }
}

private struct DeleteAccountSection: View {
    let onDelete: (() -> Void)

    var body: some View {
        Section(content: {
            Button(action: onDelete) {
                Text("Delete Account")
                    .foregroundColor(.red)
            }
        }, footer: {
            // swiftlint:disable:next line_length
            Text("This will permanently delete your account and all of its data. You will not be able to reactivate this account.")
        })
    }
}
