//
//  DownloadKitTask+init.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 10/21/22.
//  Copyright © 2022 Maziar Saadatfar . All rights reserved.
//

import Foundation

extension DownloadKitTask {
  internal init(from entity: DownloadTaskEntity) {
    self.init(
      identifier: entity.identifier,
      url: URL(string: entity.url)!,
      destinationURL: URL(fileURLWithPath: entity.destinationURL),
      state: entity.downloadState
    )
  }
}
