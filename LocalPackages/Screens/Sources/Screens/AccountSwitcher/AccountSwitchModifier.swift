//
// AccountSwitchModifier.swift
// Proton Pass - Created on 26/06/2024.
// Copyright (c) 2024 Proton Technologies AG
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
//

import SwiftUI

public struct AccountSwitchModifier: ViewModifier {
    let details: [any AccountCellDetail]
    let activeId: String
    @Binding var showSwitcher: Bool
    let animationNamespace: Namespace.ID
    let onSelect: (String) -> Void
    let onSignOut: (String) -> Void
    let onDelete: (String) -> Void
    let onAddAccount: () -> Void

    public init(details: [any AccountCellDetail],
                activeId: String,
                showSwitcher: Binding<Bool>,
                animationNamespace: Namespace.ID,
                onSelect: @escaping (String) -> Void,
                onSignOut: @escaping (String) -> Void,
                onDelete: @escaping (String) -> Void,
                onAddAccount: @escaping () -> Void) {
        self.details = details
        self.activeId = activeId
        _showSwitcher = showSwitcher
        self.animationNamespace = animationNamespace
        self.onSelect = onSelect
        self.onSignOut = onSignOut
        self.onDelete = onDelete
        self.onAddAccount = onAddAccount
    }

    public func body(content: Content) -> some View {
        content
            .animation(.default, value: showSwitcher)
            .if(showSwitcher) { view in
                view
                    .overlay {
                        ZStack {
                            Color.black.opacity(0.5)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation {
                                        showSwitcher.toggle()
                                    }
                                }

                            VStack {
                                AccountList(details: details,
                                            activeId: activeId,
                                            animationNamespace: animationNamespace,
                                            onSelect: onSelect,
                                            onSignOut: onSignOut,
                                            onDelete: onDelete,
                                            onAddAccount: onAddAccount)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
            }
    }
}
