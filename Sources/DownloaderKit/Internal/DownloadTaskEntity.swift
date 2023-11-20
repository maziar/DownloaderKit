//
//  DownloadTaskEntity.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 10/21/22.
//  Copyright © 2022 Maziar Saadatfar . All rights reserved.
//

import Foundation
import Realm
import RealmSwift

internal final class DownloadTaskEntity: Object {
  @Persisted(primaryKey: true) var identifier: String = ""
  @Persisted var url: String = ""
  @Persisted var destinationURL: String = ""
  @Persisted var updatedAt: Date = .init()

  @Persisted private var state: RawState = .undefined
  @Persisted private var bytesWritten: Int64? = nil
  @Persisted private var totalBytes: Int64? = nil

  enum RawState: Int, PersistableEnum {
    case undefined
    case enqueued
    case downloading
    case completed
    case failed
    case cancelled

    init(from downloadState: DownloadKitState) {
      switch downloadState {
      case .undefined:
        self = .undefined
      case .enqueued:
        self = .enqueued
      case .downloading:
        self = .downloading
      case .completed:
        self = .completed
      case .failed:
        self = .failed
      case .cancelled:
        self = .cancelled
      }
    }
  }

  /// Must be in transaction
  convenience init(
    identifier: String,
    url: URL,
    destinationURL: URL,
    state: DownloadKitState,
    updatedAt: Date
  ) {
    self.init()
    self.identifier = identifier
    self.url = url.absoluteString
    self.destinationURL = destinationURL.path
    self.updatedAt = updatedAt
    self.update(to: state)
  }

  /// Must be in transaction
  func update(to state: DownloadKitState) {
    self.state = .init(from: state)
    if case .downloading(let bytesWritten, let totalBytes, _) = state {
      self.bytesWritten = bytesWritten
      self.totalBytes = totalBytes
    } else {
      self.bytesWritten = nil
      self.totalBytes = nil
    }
  }

  var downloadState: DownloadKitState {
    switch state {
    case .undefined:
      return .undefined
    case .enqueued:
      return .enqueued
    case .downloading:
      let bytesWritten = self.bytesWritten!
      let totalBytes = self.totalBytes!

      return .downloading(
        bytesWritten: bytesWritten,
        totalBytes: totalBytes,
        percentage: percentage(bytesWritten: bytesWritten, totalBytes: totalBytes)
      )
    case .completed:
      return .completed
    case .failed:
      return .failed
    case .cancelled:
      return .cancelled
    }
  }
}
