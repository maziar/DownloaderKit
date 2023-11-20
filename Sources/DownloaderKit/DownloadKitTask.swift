//
//  DownloadKitTask.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 7/15/20.
//  Copyright © 2020 Maziar Saadatfar . All rights reserved.
//

import Foundation

/// A model class encapsulates all information about download task
public struct DownloadKitTask: Hashable {
  /// The unique identifier of download request
  public let identifier: String

  /// The download url
  public let url: URL

  /// The local file URL where the downloaded file will be saved
  public let destinationURL: URL

  /// The latest state of download task
  public let state: DownloadKitState
  
  public init(
    identifier: String,
    url: URL,
    destinationURL: URL,
    state: DownloadKitState
  ) {
    self.identifier = identifier
    self.url = url
    self.destinationURL = destinationURL
    self.state = state
  }
}

// MARK: DownloadKitTask + request
extension DownloadKitTask {
  /// The request that executes this task
  public var request: DownloadKitRequest {
    .init(
      identifier: self.identifier,
      url: self.url,
      destinationURL: self.destinationURL
    )
  }
}
