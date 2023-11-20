//
//  DownloadKitResult.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 10/21/22.
//  Copyright © 2022 Maziar Saadatfar . All rights reserved.
//

import Foundation

/// Represents downloader result in three cases: `success`, `cancelled`, `failure`
/// - Tag: DownloadKitResult
public enum DownloadKitResult {
  case success(DownloadKitRequest)
  case cancelled(DownloadKitRequest)
  case failure(DownloadKitRequest, DownloaderKitError)

  /// Returns original request.
  var request: DownloadKitRequest {
    switch self {
    case .success(let request): return request
    case .cancelled(let request): return request
    case .failure(let request, _): return request
    }
  }

  /// If this is a failed result, returns error.
  /// Otherwise, returns `nil`
  var error: DownloaderKitError? {
    switch self {
    case .success: return nil
    case .cancelled: return nil
    case .failure(_, let error): return error
    }
  }
}
