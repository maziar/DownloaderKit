//
//  DownloaderKit.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 7/4/20.
//  Copyright © 2020 Maziar Saadatfar . All rights reserved.
//

import Foundation
import RxSwift

// MARK: - DownloaderKit

public protocol DownloaderKit {
  // MARK: Observer
  
  /// Observe state of download task by id
  /// - Parameter identifier: request id
  /// - Returns: an `Observable` that emits nil if task does not exist, otherwise it will emit the download task.
  func observe(by identifier: String) -> Observable<DownloadKitTask?>

  /// Observe state of download tasks by multiple ids
  /// - Parameter identifiers: request ids
  /// - Returns: an `Observable` that emits a dictionary with id as key, download task as value
  func observe<T: Sequence>(by identifiers: T) -> Observable<[String: DownloadKitTask]> where T.Element == String

  /// Download result event observable
  /// # Reference:
  /// [DownloadKitResult](x-source-tag://DownloadKitResult)
  var downloadResult$: Observable<DownloadKitResult> { get }

  // MARK: Enqueue

  /// Enqueue a download request
  func enqueue(_ request: DownloadKitRequest) -> Completable

  // MARK: Cancel (also delete files)

  /// Cancel enqueued and running download task by identifier
  func cancel(by identifier: String) -> Completable

  /// Cancel all enqueued and running download tasks
  func cancelAll() -> Completable

  // MARK: Remove (and delete files)

  /// Delete a download task from database.
  /// If the given task is running, it is canceled as well.
  /// If the task is completed and result from invoking `deleteFile` is true, the downloaded file will be deleted.
  func remove(by identifier: String, and deleteFile: @escaping (DownloadKitTask) -> Bool) -> Completable

  /// Delete all tasks from database.
  /// Canceled all running tasks.
  /// If the task is completed and result from invoking `deleteFile` is true, the downloaded file will be deleted.
  func removeAll(deleteFile: @escaping (DownloadKitTask) -> Bool) -> Completable
}

extension DownloaderKit {
  /// Delete a download task from database.
  /// If the given task is running, it is canceled as well.
  /// If the task is completed, the downloaded file will be deleted.
  public func removeAndDeleteFile(by identifier: String) -> Completable {
    self.remove(by: identifier) { _ in true }
  }

  /// Delete all tasks from database.
  /// Canceled all running tasks.
  /// If the task is completed, the downloaded files will be deleted.
  public func removeAllAndDeleteFiles() -> Completable {
    self.removeAll { _ in true }
  }
}

/// Provide `DownloaderKit` from `DownloaderKitOptions`
public enum DownloaderKitFactory {

  /// Provide `DownloaderKit` from `DownloaderKitOptions`
  public static func makeDownloader(with options: DownloaderKitOptions) -> DownloaderKit {
    DIGraph.provideDownloaderKit(options: options)
  }
}
