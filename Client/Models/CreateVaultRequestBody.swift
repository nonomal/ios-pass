//
// CreateVaultRequestBody.swift
// Proton Pass - Created on 12/07/2022.
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

import Crypto
import ProtonCore_DataModel
import ProtonCore_KeyManager

typealias Encryptor = ProtonCore_KeyManager.Encryptor

public struct CreateVaultRequestBody: Encodable {
    public let addressID: String
    public let content: String
    public let contentFormatVersion: Int
    public let contentEncryptedAddressSignature: String
    public let contentEncryptedVaultSignature: String
    public let vaultKey: String
    public let vaultKeyPassphrase: String
    public let vaultKeySignature: String
    public let keyPacket: String
    public let keyPacketSignature: String
    public let signingKey: String
    public let signingKeyPassphrase: String
    public let signingKeyPassphraseKeyPacket: String
    public let acceptanceSignature: String
    public let itemKey: String
    public let itemKeyPassphrase: String
    public let itemKeyPassphraseKeyPacket: String
    public let itemKeySignature: String

    private enum CodingKeys: String, CodingKey {
        case addressID = "AddressID"
        case content = "Content"
        case contentFormatVersion = "ContentFormatVersion"
        case contentEncryptedAddressSignature = "ContentEncryptedAddressSignature"
        case contentEncryptedVaultSignature = "ContentEncryptedVaultSignature"
        case vaultKey = "VaultKey"
        case vaultKeyPassphrase = "VaultKeyPassphrase"
        case vaultKeySignature = "VaultKeySignature"
        case keyPacket = "KeyPacket"
        case keyPacketSignature = "KeyPacketSignature"
        case signingKey = "SigningKey"
        case signingKeyPassphrase = "SigningKeyPassphrase"
        case signingKeyPassphraseKeyPacket = "SigningKeyPassphraseKeyPacket"
        case acceptanceSignature = "AcceptanceSignature"
        case itemKey = "ItemKey"
        case itemKeyPassphrase = "ItemKeyPassphrase"
        case itemKeyPassphraseKeyPacket = "ItemKeyPassphraseKeyPacket"
        case itemKeySignature = "ItemKeySignature"
    }

    public init(addressID: String,
                content: String,
                contentFormatVersion: Int,
                contentEncryptedAddressSignature: String,
                contentEncryptedVaultSignature: String,
                vaultKey: String,
                vaultKeyPassphrase: String,
                vaultKeySignature: String,
                keyPacket: String,
                keyPacketSignature: String,
                signingKey: String,
                signingKeyPassphrase: String,
                signingKeyPassphraseKeyPacket: String,
                acceptanceSignature: String,
                itemKey: String,
                itemKeyPassphrase: String,
                itemKeyPassphraseKeyPacket: String,
                itemKeySignature: String) {
        self.addressID = addressID
        self.content = content
        self.contentFormatVersion = contentFormatVersion
        self.contentEncryptedAddressSignature = contentEncryptedAddressSignature
        self.contentEncryptedVaultSignature = contentEncryptedVaultSignature
        self.vaultKey = vaultKey
        self.vaultKeyPassphrase = vaultKeyPassphrase
        self.vaultKeySignature = vaultKeySignature
        self.keyPacket = keyPacket
        self.keyPacketSignature = keyPacketSignature
        self.signingKey = signingKey
        self.signingKeyPassphrase = signingKeyPassphrase
        self.signingKeyPassphraseKeyPacket = signingKeyPassphraseKeyPacket
        self.acceptanceSignature = acceptanceSignature
        self.itemKey = itemKey
        self.itemKeyPassphrase = itemKeyPassphrase
        self.itemKeyPassphraseKeyPacket = itemKeyPassphraseKeyPacket
        self.itemKeySignature = itemKeySignature
    }

    // swiftlint:disable:next function_body_length
    public init(addressKey: AddressKey, vault: VaultProvider) throws {
        // Generate signing key
        let (signingKey, signingKeyPassphrase) = try CryptoUtils.generateKey(name: "VaultSigningKey",
                                                                             email: "vault_signing@proton")
        let encryptedSigningKeyPassphrase = try Encryptor.encrypt(signingKeyPassphrase,
                                                                  key: addressKey.key.publicKey)
        let (signingKeyPassphraseKeyPacket, signingKeyPassphraseDataPacket) =
        try CryptoUtils.splitPGPMessage(encryptedSigningKeyPassphrase)

        let signingKeyFingerprint = try CryptoUtils.getFingerprint(key: signingKey)
        let signingKeySignature = try Encryptor.sign(list: Data(signingKeyFingerprint.utf8),
                                                     addressKey: addressKey.key.privateKey,
                                                     addressPassphrase: addressKey.keyPassphrase)
        // Generate vault key
        let (vaultKey, vaultKeyPassphrase) = try CryptoUtils.generateKey(name: "VaultKey",
                                                                         email: "vault@proton")
        let encryptedVaultKeyPassphrase = try Encryptor.encrypt(vaultKeyPassphrase,
                                                                key: addressKey.key.publicKey)
        let (vaultKeyPassphraseKeyPacket, vaultKeyPassphraseDataPacket) =
        try CryptoUtils.splitPGPMessage(encryptedVaultKeyPassphrase)

        let vaultKeyFingerprint = try CryptoUtils.getFingerprint(key: vaultKey)
        let vaultKeySignature = try Encryptor.sign(list: Data(vaultKeyFingerprint.utf8),
                                                   addressKey: signingKey,
                                                   addressPassphrase: signingKeyPassphrase)

        // Generate item key
        let (itemKey, itemKeyPassphrase) = try CryptoUtils.generateKey(name: "ItemKey",
                                                                       email: "item@proton")
        let encryptedItemKeyPassphrase = try Encryptor.encrypt(itemKeyPassphrase, key: vaultKey)
        let (itemKeyPassphraseKeyPacket, itemKeyPassphraseDataPacket) =
        try CryptoUtils.splitPGPMessage(encryptedItemKeyPassphrase)

        let itemKeyFingerprint = try CryptoUtils.getFingerprint(key: itemKey)
        let itemKeySignature = try Encryptor.sign(list: Data(itemKeyFingerprint.utf8),
                                                  addressKey: signingKey,
                                                  addressPassphrase: signingKeyPassphrase)

        guard let keyRing = CryptoKeyRing(.init(fromArmored: vaultKey.publicKey)) else {
            throw CryptoError.failedToGenerateKeyRing
        }

        let vaultData = try vault.data()
        guard let encryptedVaultData = try keyRing.encrypt(.init(vaultData), privateKey: nil).data else {
            throw CryptoError.failedToEncrypt
        }
        let nameVaultKeySignature = try Encryptor.sign(list: vaultData,
                                                       addressKey: vaultKey,
                                                       addressPassphrase: vaultKeyPassphrase)

        let signedVaultKeyPassphraseKeyPacket = try Encryptor.sign(list: vaultKeyPassphraseKeyPacket,
                                                                   addressKey: vaultKey,
                                                                   addressPassphrase: vaultKeyPassphrase)

        let nameAddressSignature = try Encryptor.sign(list: vaultData,
                                                      addressKey: addressKey.key.privateKey,
                                                      addressPassphrase: addressKey.keyPassphrase)

        let encryptedNameAddressSignature = try Encryptor.encrypt(nameAddressSignature, key: vaultKey)
        let encryptedNameVaultKeySignature = try Encryptor.encrypt(nameVaultKeySignature, key: vaultKey)

        self = .init(addressID: addressKey.addressId,
                     content: encryptedVaultData.base64EncodedString(),
                     contentFormatVersion: 1,
                     contentEncryptedAddressSignature:
                        try CryptoUtils.unarmorAndBase64(data: encryptedNameAddressSignature,
                                                         name: "encryptedNameAddressSignature"),
                     contentEncryptedVaultSignature:
                        try CryptoUtils.unarmorAndBase64(data: encryptedNameVaultKeySignature,
                                                         name: "encryptedNameVaultKeySignature"),
                     vaultKey: vaultKey,
                     vaultKeyPassphrase: vaultKeyPassphraseDataPacket.base64EncodedString(),
                     vaultKeySignature: try CryptoUtils.unarmorAndBase64(data: vaultKeySignature,
                                                                         name: "vaultKeySignature"),
                     keyPacket: vaultKeyPassphraseKeyPacket.base64EncodedString(),
                     keyPacketSignature:
                        try CryptoUtils.unarmorAndBase64(data: signedVaultKeyPassphraseKeyPacket,
                                                         name: "signedVaultKeyPassphraseKeyPacket"),
                     signingKey: signingKey,
                     signingKeyPassphrase: signingKeyPassphraseDataPacket.base64EncodedString(),
                     signingKeyPassphraseKeyPacket: signingKeyPassphraseKeyPacket.base64EncodedString(),
                     acceptanceSignature: try CryptoUtils.unarmorAndBase64(data: signingKeySignature,
                                                                           name: "signingKeySignature"),
                     itemKey: itemKey,
                     itemKeyPassphrase: itemKeyPassphraseDataPacket.base64EncodedString(),
                     itemKeyPassphraseKeyPacket: itemKeyPassphraseKeyPacket.base64EncodedString(),
                     itemKeySignature: try CryptoUtils.unarmorAndBase64(data: itemKeySignature,
                                                                        name: "itemKeySignature"))
    }
}
