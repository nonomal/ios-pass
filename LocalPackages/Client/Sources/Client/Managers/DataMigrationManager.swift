//
// DataMigrationManager.swift
// Proton Pass - Created on 20/06/2024.
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

import Entities
import Foundation

public struct MigrationType: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let userAppData = MigrationType(rawValue: 1 << 0)
    public static let credentialsAppData = MigrationType(rawValue: 1 << 1)
    public static let all: [MigrationType] = [.userAppData, .credentialsAppData]
}

public protocol DataMigrationManagerProtocol: Sendable {
    func addMigration(_ migration: MigrationType) async throws
    func hasMigrationOccurred(_ migration: MigrationType) async throws -> Bool
    func missingMigrations(_ migrations: [MigrationType]) async throws -> [MigrationType]
    func revertMigration(_ migration: MigrationType) async throws
}

public actor DataMigrationManager: DataMigrationManagerProtocol {
    private let datasource: any LocalDataMigrationDatasourceProtocol

    public init(datasource: any LocalDataMigrationDatasourceProtocol) {
        self.datasource = datasource
    }

    public func addMigration(_ migration: MigrationType) async throws {
        var status = try await datasource.getMigrations() ?? MigrationStatus(completedMigrations: 0)

        status.completedMigrations |= migration.rawValue

        try await datasource.upsert(migrations: status)
    }

    public func hasMigrationOccurred(_ migration: MigrationType) async throws -> Bool {
        guard let status = try await datasource.getMigrations() else {
            return false
        }

        return status.completedMigrations & migration.rawValue == migration.rawValue
    }

    public func missingMigrations(_ migrations: [MigrationType]) async throws -> [MigrationType] {
        guard let status = try await datasource.getMigrations() else {
            return migrations
        }

        return migrations.filter { (status.completedMigrations & $0.rawValue) != $0.rawValue }
    }

    public func revertMigration(_ migration: MigrationType) async throws {
        guard var status = try await datasource.getMigrations() else {
            return
        }

        status.completedMigrations &= ~migration.rawValue

        try await datasource.upsert(migrations: status)
    }
}
