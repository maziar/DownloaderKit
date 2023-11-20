//
//  DownloadKitRequest.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 7/4/20.
//  Copyright © 2020 Maziar Saadatfar . All rights reserved.
//

import Foundation

/// Specifying parameters for work that should be enqueued.
public struct DownloadKitRequest: Hashable {

  /// The unique identifier of download request
  public let identifier: String

  /// The download url
  public let url: URL

  /// The local file URL where the downloaded file will be saved
  public let destinationURL: URL

  public init(
    identifier: String,
    url: URL,
    destinationURL: URL
  ) {
    self.identifier = identifier
    self.url = url
    self.destinationURL = destinationURL
  }
}
