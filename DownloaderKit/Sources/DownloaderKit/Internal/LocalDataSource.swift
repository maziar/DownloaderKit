//
//  LocalDataSource.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 10/21/22.
//  Copyright © 2022 Maziar Saadatfar . All rights reserved.
//

import Foundation
import RxSwift
import RealmSwift
import Realm

internal protocol LocalDataSource {

  /// Update download state for download task
  func update(id: String, state: DownloadKitState) -> Completable

  /// Insert or update download task
  func insertOrUpdate(
    identifier: String,
    url: URL,
    destinationURL: URL,
    state: DownloadKitState
  ) -> Completable

  /// Get `Results` by multiple ids.
  /// Executing on main thread.
  /// - Throws: `DownloaderKitError.databaseError`
  func getResults(by ids: Set<String>) throws -> Results<DownloadTaskEntity>

  /// Get `Results` by single id.
  /// Executing on main thread.
  /// - Throws: `DownloaderKitError.databaseError`
  func getResults(by id: String) throws -> Results<DownloadTaskEntity>

  /// Get single task by id.
  /// Executing on main thread.
  /// - Throws: `DownloaderKitError.notFound` if not found or `DownloaderKitError.databaseError`.
  func get(by id: String) throws -> DownloadTaskEntity

  /// Mask all enqueued or running tasks as cancelled.
  func cancelAll() -> Completable

  /// Remove task from database.
  func remove(by id: String) -> Single<DownloadTaskEntity>

  /// Remove all tasks
  func removeAll() -> Single<[DownloadTaskEntity]>
}

extension LocalDataSource {
  /// Get single task by id, or `nil` if not found
  /// Executing on main thread.
  /// - Throws: `DownloaderKitError.databaseError`.
  func getOptional(by id: String) throws -> DownloadTaskEntity? {
    do {
      return try self.get(by: id)
    } catch let error as DownloaderKitError {
      if case .notFound = error {
        return nil
      }
      throw error
    }
  }
}
