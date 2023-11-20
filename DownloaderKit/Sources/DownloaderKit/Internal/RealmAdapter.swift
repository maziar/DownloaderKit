//
//  RealmAdapter.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 10/21/22.
//  Copyright © 2022 Maziar Saadatfar . All rights reserved.
//

import Foundation
import Realm
import RealmSwift

internal protocol RealmAdapter {
  func objects<Element: Object>(_ type: Element.Type) -> Results<Element>

  func write<Result>(
    withoutNotifying tokens: [NotificationToken],
    _ block: () throws -> Result
  ) throws -> Result

  func add(_ object: Object, update: Realm.UpdatePolicy)

  func delete(_ object: ObjectBase)

  func refresh() -> Bool

  func object<Element: Object, KeyType>(ofType type: Element.Type, forPrimaryKey key: KeyType) -> Element?

  func deleteAll()
}

