//
// ProfileTabView.swift
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

import SwiftUI
import UIComponents

struct ProfileTabView: View {
    @StateObject var viewModel: ProfileTabViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Profile")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView {
                VStack {
                    itemCountSection
                        .padding(.bottom)
                    biometricAuthenticationSection
                    accountAndSettingsSection
                        .padding(.vertical)
                    aboutSection
                    helpCenterSection
                        .padding(.vertical)
                    Text(viewModel.appVersion)
                        .sectionTitleText()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.passBackground)
    }

    private var itemCountSection: some View {
        VStack {
            Text("Items")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            ItemCountView(viewModel: viewModel.itemCountViewModel)
        }
    }

    private var biometricAuthenticationSection: some View {
        VStack {
            Text("Manage my profile")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            OptionRow(height: .medium) {
                switch viewModel.biometricAuthenticator.biometryTypeState {
                case .idle, .initializing:
                    ProgressView()
                case .initialized(let biometryType):
                    if let uiModel = biometryType.uiModel {
                        Toggle(isOn: $viewModel.biometricAuthenticator.enabled) {
                            Label(title: {
                                Text(uiModel.title)
                            }, icon: {
                                if let icon = uiModel.icon {
                                    Image(systemName: icon)
                                        .foregroundColor(.passBrand)
                                } else {
                                    EmptyView()
                                }
                            })
                        }
                        .tint(.passBrand)
                    } else {
                        Text("Biometric authentication not supported")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .error(let error):
                    Text(error.localizedDescription)
                }
            }
            .roundedEditableSection()

            if case .initialized(let biometryType) = viewModel.biometricAuthenticator.biometryTypeState,
               biometryType != .none {
                Text("Unlock Proton Pass with a glance.")
                    .sectionTitleText()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }

    private var accountAndSettingsSection: some View {
        VStack(spacing: 0) {
            TextOptionRow(title: "Account", action: viewModel.showAccountMenu)
            PassDivider()
            TextOptionRow(title: "Settings", action: viewModel.showSettingsMenu)
        }
        .roundedEditableSection()
        .padding(.horizontal)
    }

    private var aboutSection: some View {
        VStack(spacing: kItemDetailSectionPadding) {
            Text("About")
                .sectionHeaderText()
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                /*
                TextOptionRow(title: "Acknowledgments", action: viewModel.showAcknowledgments)
                PassDivider()
                 */
                TextOptionRow(title: "Privacy policy", action: viewModel.showPrivacyPolicy)
                PassDivider()
                TextOptionRow(title: "Terms of service", action: viewModel.showTermsOfService)
            }
            .roundedEditableSection()
        }
        .padding(.horizontal)
    }

    private var helpCenterSection: some View {
        VStack(spacing: kItemDetailSectionPadding) {
            Text("Help center")
                .sectionHeaderText()
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                /*
                TextOptionRow(title: "Tips", action: viewModel.showTips)
                PassDivider()
                 */
                TextOptionRow(title: "Feedback", action: viewModel.showFeedback)
                PassDivider()
                TextOptionRow(title: "Rate app", action: viewModel.rateApp)
            }
            .roundedEditableSection()
        }
        .padding(.horizontal)
    }
}
