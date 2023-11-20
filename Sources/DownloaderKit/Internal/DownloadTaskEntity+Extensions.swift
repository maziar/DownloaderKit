//
//  DownloadTaskEntity+Extensions.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 10/21/22.
//  Copyright © 2022 Maziar Saadatfar . All rights reserved.
//

import Foundation


// MARK: DownloadTaskEntity + canCancel + canDownload + canTransition(to:)
extension DownloadTaskEntity {
  /// Enqueued or runnning state
  var canCancel: Bool {
    if self.downloadState == .enqueued { return true }
    if case .downloading = self.downloadState { return true }
    return false
  }

  var canDownload: Bool { self.downloadState != .cancelled }

  func canTransition(to newState: DownloadKitState) -> Bool {
    if self.downloadState == .cancelled {
      switch newState {
      case .undefined, .enqueued:
        return true
      case .downloading, .completed, .failed, .cancelled:
        // cannot transition from .cancelled to finished states or .cancelled itself.
        return false
      }
    }

    return true
  }
}
