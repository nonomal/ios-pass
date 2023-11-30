//
// ItemsTabTopBar.swift
// Proton Pass - Created on 30/11/2023.
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
import ProtonCoreUIFoundations
import SwiftUI

struct ItemsTabTopBar: View {
    @StateObject private var viewModel = ItemsTabTopBarViewModel()
    @Binding var isEditMode: Bool
    let onSearch: () -> Void
    let onShowVaultList: () -> Void
    let onMove: () -> Void
    let onTrash: () -> Void
    let onRestore: () -> Void
    let onPermanentlyDelete: () -> Void

    var body: some View {
        ZStack {
            if isEditMode {
                editModeView
            } else {
                viewModeView
            }
        }
        .animation(.default, value: isEditMode)
        .frame(height: 60)
    }
}

private extension ItemsTabTopBar {
    var viewModeView: some View {
        HStack {
            switch viewModel.vaultSelection {
            case .all:
                CircleButton(icon: PassIcon.brandPass,
                             iconColor: VaultSelection.all.color,
                             backgroundColor: VaultSelection.all.color.withAlphaComponent(0.16),
                             type: .big,
                             action: onShowVaultList)
                    .frame(width: kSearchBarHeight)

            case let .precise(vault):
                CircleButton(icon: vault.displayPreferences.icon.icon.bigImage,
                             iconColor: vault.displayPreferences.color.color.color,
                             backgroundColor: vault.displayPreferences.color.color.color.withAlphaComponent(0.16),
                             action: onShowVaultList)
                    .frame(width: kSearchBarHeight)

            case .trash:
                CircleButton(icon: IconProvider.trash,
                             iconColor: VaultSelection.trash.color,
                             backgroundColor: VaultSelection.trash.color.withAlphaComponent(0.16),
                             action: onShowVaultList)
                    .frame(width: kSearchBarHeight)
            }

            ZStack {
                Color(uiColor: PassColor.backgroundStrong)
                HStack {
                    Image(uiImage: IconProvider.magnifier)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text(viewModel.vaultSelection.searchBarPlacehoder)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundColor(Color(uiColor: PassColor.textWeak))
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .frame(height: kSearchBarHeight)
            .onTapGesture(perform: onSearch)

            ItemsTabOptionsButton {
                isEditMode = true
            }
        }
        .padding(.horizontal)
    }
}

private extension ItemsTabTopBar {
    var editModeView: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack {
                Button(action: {
                    isEditMode = false
                }, label: {
                    Text("Done")
                        .fontWeight(.bold)
                        .foregroundStyle(PassColor.interactionNormMajor2.toColor)
                })

                Spacer()

                switch viewModel.vaultSelection {
                case .all, .precise:
                    Button(action: onMove) {
                        Image(uiImage: IconProvider.folderArrowIn)
                            .foregroundStyle(PassColor.textNorm.toColor)
                    }
                    .padding(.horizontal)

                    Button(action: onTrash) {
                        Image(uiImage: IconProvider.trash)
                            .foregroundStyle(PassColor.textNorm.toColor)
                    }

                case .trash:
                    Button(action: onRestore) {
                        Image(uiImage: IconProvider.clockRotateLeft)
                            .foregroundStyle(PassColor.textNorm.toColor)
                    }
                    .padding(.horizontal)

                    Button(action: onTrash) {
                        Image(uiImage: IconProvider.trashCross)
                            .foregroundStyle(PassColor.textNorm.toColor)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            PassDivider()
        }
    }
}
