//
// SearchableItem.swift
// Proton Pass - Created on 21/09/2022.
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
import CryptoKit

/// Items that live in memory for search purpose
public struct SearchableItem: ItemTypeIdentifiable {
    public let shareId: String
    public let itemId: String
    public let type: ItemContentType
    public let name: String
    public let note: String
    public let requiredExtras: [String] // E.g: Username for login items
    public let optionalExtras: [String] // E.g: URLs for login items
    public let lastUseTime: Int64
    public let modifyTime: Int64

    public init(from item: SymmetricallyEncryptedItem, symmetricKey: SymmetricKey) throws {
        self.shareId = item.shareId
        self.itemId = item.item.itemID

        let itemContent = try item.getDecryptedItemContent(symmetricKey: symmetricKey)
        self.type = itemContent.contentData.type
        self.name = itemContent.name
        self.note = itemContent.note

        switch itemContent.contentData {
        case .login(let data):
            self.requiredExtras = [data.username]
            self.optionalExtras = data.urls
        default:
            self.requiredExtras = []
            self.optionalExtras = []
        }

        self.lastUseTime = itemContent.item.lastUseTime ?? 0
        self.modifyTime = item.item.modifyTime
    }
}

extension SearchableItem {
    func result(for term: String) -> ItemSearchResult? {
        let title: SearchResultEither
        if let result = SearchUtils.search(query: term, in: name) {
            title = .matched(result)
        } else {
            title = .notMatched(name)
        }

        var detail = [SearchResultEither]()
        if let result = SearchUtils.search(query: term, in: note) {
            detail.append(.matched(result))
        } else {
            detail.append(.notMatched(note))
        }

        for extra in requiredExtras {
            if let result = SearchUtils.search(query: term, in: extra) {
                detail.append(.matched(result))
            } else {
                detail.append(.notMatched(extra))
            }
        }

        for extra in optionalExtras {
            if let result = SearchUtils.search(query: term, in: extra) {
                detail.append(.matched(result))
            }
        }

        let detailNotMatched = detail.allSatisfy { either in
            if case .matched = either {
                return false
            } else {
                return true
            }
        }

        if case .notMatched = title, detailNotMatched {
            return nil
        }

        return .init(shareId: shareId,
                     itemId: itemId,
                     type: type,
                     title: title,
                     detail: detail,
                     lastUseTime: lastUseTime,
                     modifyTime: modifyTime)
    }
}

public extension Array where Element == SearchableItem {
    func result(for term: String) -> [ItemSearchResult] {
        compactMap { $0.result(for: term) }
    }
}
