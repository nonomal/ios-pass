//
// NoteDetailViewModel.swift
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

import Client
import Core

final class NoteDetailViewModel: BaseItemDetailViewModel, DeinitPrintable, ObservableObject {
    deinit { print(deinitMessage) }

    @Published private(set) var name = ""
    @Published private(set) var note = ""
    @Published private(set) var createTime = 0
    @Published private(set) var modifyTime = 0

    override func bindValues() {
        self.createTime = Int(itemContent.item.createTime)
        self.modifyTime = Int(itemContent.item.modifyTime)
        if case .note = itemContent.contentData {
            self.name = itemContent.name
            self.note = itemContent.note
        } else {
            fatalError("Expecting note type")
        }
    }
}
