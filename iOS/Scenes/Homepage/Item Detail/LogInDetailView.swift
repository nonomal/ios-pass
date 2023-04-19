//
// LogInDetailView.swift
// Proton Pass - Created on 07/09/2022.
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
import ProtonCore_UIFoundations
import SwiftUI
import UIComponents

struct LogInDetailView: View {
    @StateObject private var viewModel: LogInDetailViewModel
    @State private var isShowingPassword = false
    @Namespace private var bottomID

    private var iconTintColor: UIColor { viewModel.itemContent.type.normColor }

    init(viewModel: LogInDetailViewModel) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        if viewModel.isShownAsSheet {
            NavigationView {
                realBody
            }
            .navigationViewStyle(.stack)
        } else {
            realBody
        }
    }

    private var realBody: some View {
        ScrollViewReader { value in
            ScrollView {
                VStack(spacing: 0) {
                    ItemDetailTitleView(itemContent: viewModel.itemContent,
                                        vault: viewModel.vault,
                                        favIconRepository: viewModel.favIconRepository)
                        .padding(.bottom, 40)

                    usernamePassword2FaSection

                    if !viewModel.urls.isEmpty {
                        urlsSection
                            .padding(.top, 8)
                    }

                    if !viewModel.itemContent.note.isEmpty {
                        NoteDetailSection(itemContent: viewModel.itemContent,
                                          vault: viewModel.vault,
                                          theme: viewModel.theme,
                                          favIconRepository: viewModel.favIconRepository)
                            .padding(.top, 8)
                    }

                    ItemDetailMoreInfoSection(
                        itemContent: viewModel.itemContent,
                        onExpand: { withAnimation { value.scrollTo(bottomID, anchor: .bottom) } })
                    .padding(.top, 24)
                    .id(bottomID)

                    if viewModel.isAlias {
                        viewAliasCard
                            .padding(.top)
                    }
                }
                .padding()
                .animation(.default, value: isShowingPassword)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .background(Color(uiColor: PassColor.backgroundNorm))
        .toolbar {
            ItemDetailToolbar(isShownAsSheet: viewModel.isShownAsSheet,
                              itemContent: viewModel.itemContent,
                              onGoBack: viewModel.goBack,
                              onEdit: viewModel.edit,
                              onMoveToAnotherVault: viewModel.moveToAnotherVault,
                              onMoveToTrash: viewModel.moveToTrash,
                              onRestore: viewModel.restore,
                              onPermanentlyDelete: viewModel.permanentlyDelete)
        }
    }

    private var usernamePassword2FaSection: some View {
        VStack(spacing: kItemDetailSectionPadding) {
            usernameRow
            PassSectionDivider()
            passwordRow

            switch viewModel.totpManager.state {
            case .empty:
                EmptyView()
            default:
                PassSectionDivider()
                totpRow
            }
        }
        .padding(.vertical, kItemDetailSectionPadding)
        .roundedDetailSection()
    }

    private var usernameRow: some View {
        HStack(spacing: kItemDetailSectionPadding) {
            ItemDetailSectionIcon(icon: viewModel.isAlias ? IconProvider.alias : IconProvider.user,
                                  color: iconTintColor)

            VStack(alignment: .leading, spacing: kItemDetailSectionPadding / 4) {
                Text("Username or email")
                    .sectionTitleText()

                if viewModel.username.isEmpty {
                    Text("No username")
                        .placeholderText()
                } else {
                    Text(viewModel.username)
                        .sectionContentText()

                    if viewModel.isAlias {
                        Button(action: viewModel.showAliasDetail) {
                            Text("View alias")
                                .font(.callout)
                                .foregroundColor(Color(uiColor: viewModel.itemContent.type.normMajor1Color))
                                .underline(color: Color(uiColor: viewModel.itemContent.type.normMajor1Color))
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: viewModel.copyUsername)
        }
        .padding(.horizontal, kItemDetailSectionPadding)
        .contextMenu {
            Button(action: viewModel.copyUsername) {
                Text("Copy")
            }

            Button(action: {
                viewModel.showLarge(viewModel.username)
            }, label: {
                Text("Show large")
            })
        }
    }
    private var passwordRow: some View {
        HStack(spacing: kItemDetailSectionPadding) {
            ItemDetailSectionIcon(icon: IconProvider.key, color: iconTintColor)

            VStack(alignment: .leading, spacing: kItemDetailSectionPadding / 4) {
                Text("Password")
                    .sectionTitleText()

                if viewModel.password.isEmpty {
                    Text("Empty password")
                        .placeholderText()
                } else {
                    if isShowingPassword {
                        Text(viewModel.coloredPasswordTexts)
                    } else {
                        Text(String(repeating: "•", count: 20))
                            .sectionContentText()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: viewModel.copyPassword)

            Spacer()

            if !viewModel.password.isEmpty {
                CircleButton(icon: isShowingPassword ? IconProvider.eyeSlash : IconProvider.eye,
                             iconColor: viewModel.itemContent.type.normMajor2Color,
                             backgroundColor: viewModel.itemContent.type.normMinor2Color,
                             action: { isShowingPassword.toggle() })
                .fixedSize(horizontal: true, vertical: true)
                .animationsDisabled()
            }
        }
        .padding(.horizontal, kItemDetailSectionPadding)
        .contextMenu {
            Button(action: {
                withAnimation {
                    isShowingPassword.toggle()
                }
            }, label: {
                Text(isShowingPassword ? "Conceal" : "Reveal")
            })

            Button(action: viewModel.copyPassword) {
                Text("Copy")
            }

            Button(action: viewModel.showLargePassword) {
                Text("Show large")
            }
        }
    }

    @ViewBuilder
    private var totpRow: some View {
        if case .empty = viewModel.totpManager.state {
            EmptyView()
        } else {
            HStack(spacing: kItemDetailSectionPadding) {
                ItemDetailSectionIcon(icon: IconProvider.lock, color: iconTintColor)

                VStack(alignment: .leading, spacing: kItemDetailSectionPadding / 4) {
                    Text("2FA token (TOTP)")
                        .sectionTitleText()

                    switch viewModel.totpManager.state {
                    case .empty:
                        EmptyView()
                    case .loading:
                        ProgressView()
                    case .valid(let data):
                        TOTPText(code: data.code)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .invalid:
                        Text("Invalid TOTP URI")
                            .font(.caption)
                            .foregroundColor(Color(uiColor: PassColor.signalDanger))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: viewModel.copyTotpCode)

                switch viewModel.totpManager.state {
                case .valid(let data):
                    TOTPCircularTimer(data: data.timerData)
                        .animation(nil, value: isShowingPassword)
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, kItemDetailSectionPadding)
            .animation(.default, value: viewModel.totpManager.state)
        }
    }

    private var urlsSection: some View {
        HStack(spacing: kItemDetailSectionPadding) {
            ItemDetailSectionIcon(icon: IconProvider.earth, color: iconTintColor)

            VStack(alignment: .leading, spacing: kItemDetailSectionPadding / 4) {
                Text("Website")
                    .sectionTitleText()

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.urls, id: \.self) { url in
                        Button(action: {
                            viewModel.openUrl(url)
                        }, label: {
                            Text(url)
                                .foregroundColor(Color(uiColor: viewModel.itemContent.type.normMajor2Color))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        })
                        .contextMenu {
                            Button(action: {
                                viewModel.openUrl(url)
                            }, label: {
                                Text("Open")
                            })

                            Button(action: {
                                viewModel.copyToClipboard(text: url, message: "Website copied")
                            }, label: {
                                Text("Copy")
                            })
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.default, value: viewModel.urls)
        }
        .padding(kItemDetailSectionPadding)
        .roundedDetailSection()
    }

    private var viewAliasCard: some View {
        Group {
            Text("View and edit details for this alias on the separate alias page. ")
                .font(.callout)
                .foregroundColor(Color(uiColor: PassColor.textNorm)) +
            Text("View")
                .font(.callout)
                .foregroundColor(Color(uiColor: viewModel.itemContent.type.normMajor1Color))
                .underline(color: Color(uiColor: viewModel.itemContent.type.normMajor1Color))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(kItemDetailSectionPadding)
        .background(Color(uiColor: PassColor.backgroundMedium))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: viewModel.showAliasDetail)
    }
}
