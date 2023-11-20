//
//  DIGraph.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 10/21/22.
//  Copyright © 2022 Maziar Saadatfar . All rights reserved.
//

import Foundation
import Realm
import RealmSwift

/// - Throws: `DownloaderKitError.notFound` or `DownloaderKitError.databaseError`.
internal typealias RealmInitializer = () throws -> RealmAdapter

internal enum DIGraph {
  private static let DownloaderKitPath = "hoc081098_DownloaderKit"
  private static let realmFilePath = "DownloaderKit_default.realm"
  private static var fileManager: FileManager { .default }

  /// - Throws: `DownloaderKitError.notFound` if not found.
  internal static func provideDownloaderKitDirectory() throws -> URL {
    let url = Self.fileManager
      .urls(for: .documentDirectory, in: .userDomainMask)
      .first!
      .appendingPathComponent(Self.DownloaderKitPath, isDirectory: true)

    if !Self.fileManager.fileExists(atPath: url.path) {
      do {
        try Self.fileManager.createDirectory(at: url, withIntermediateDirectories: true)
      } catch {
        throw DownloaderKitError.fileDeletingError(error)
      }
    }

    return url
  }

  /// - Throws: `DownloaderKitError.notFound` or `DownloaderKitError.databaseError`.
  internal static func provideRealmAdapter() throws -> RealmAdapter {
    let fileURL = try Self.provideDownloaderKitDirectory()
      .appendingPathComponent(Self.realmFilePath)

    let configuration = Realm.Configuration(
      fileURL: fileURL,
      // Set the new schema version. This must be greater than the previously used
      // version (if you've never set a schema version before, the version is 0).
      schemaVersion: 2,

      // Set the block which will be called automatically when opening a Realm with
      // a schema version lower than the one set above
      migrationBlock: { migration, oldSchemaVersion in
        // We haven’t migrated anything yet, so oldSchemaVersion == 0
        if oldSchemaVersion < 1 {
          // Nothing to do!
          // Realm will automatically detect new properties and removed properties
          // And will update the schema on disk automatically
        }
        if oldSchemaVersion < 2 {
          migration.enumerateObjects(ofType: DownloadTaskEntity.className()) { oldObject, newObject in
            let fileName = oldObject!["fileName"] as! String
            let savedDir = oldObject!["savedDir"] as! String
            newObject!["destinationURL"] = URL(fileURLWithPath: savedDir).appendingPathComponent(fileName).path

            print("[DownloaderKit] [DEBUG] Migrated: \(newObject!["destinationURL"]!)")
          }
        }
      }
    )

    do {
      return try Realm(configuration: configuration)
    } catch {
      throw DownloaderKitError.databaseError(error)
    }
  }

  internal static func prodiveLocalDataSource(options: DownloaderKitOptions) -> LocalDataSource {
    return RealLocalDataSource(
      realmInitializer: Self.provideRealmAdapter
    )
  }

  internal static func provideDownloaderKit(options: DownloaderKitOptions) -> DownloaderKit {
    RealDownloader(
      options: options,
      dataSource: Self.prodiveLocalDataSource(options: options),
      fileManager: Self.fileManager
    )
  }
}
