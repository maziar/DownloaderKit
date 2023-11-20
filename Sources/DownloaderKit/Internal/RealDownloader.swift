//
//  RealDownloader.swift
//  DownloaderKit
//
//  Created by Maziar Saadatfar  on 10/21/22.
//  Copyright © 2022 Maziar Saadatfar . All rights reserved.
//

import Foundation
import RxSwift
import RxRelay
import RxRealm
import RxAlamofire
import Alamofire
import UIKit

/// The command that enqueues a download request or cancel by identifier or cancel all.
internal enum Command {
  case enqueue(request: DownloadKitRequest)
  case cancel(identifier: String)
  case cancelAll
}

private enum Schedulers {
  static var mainScheduler: MainScheduler { .instance }
  static var concurrentMainScheduler: ConcurrentMainScheduler { .instance }
}

internal final class RealDownloader: DownloaderKit {
  // MARK: Dependencies
  private let options: DownloaderKitOptions
  private let dataSource: LocalDataSource
  private let fileManager: FileManager

  // MARK: ReactiveX
  private let commandS = PublishRelay<Command>()
  private let downloadResultS = PublishRelay<DownloadKitResult>()
  private let disposeBag = DisposeBag()

  // MARK: Schedulers

  /// Safe because we always access it in main queue
  private lazy var throttleScheduler = SerialDispatchQueueScheduler(
    qos: .userInitiated,
    internalSerialQueueName: "com.downloaderkit.throttle.serial-queue"
  )
  
  // MARK: Initializer

  internal init(options: DownloaderKitOptions, dataSource: LocalDataSource, fileManager: FileManager) {
    self.options = options
    self.dataSource = dataSource
    self.fileManager = fileManager

    NotificationCenter
      .default
      .addObserver(
        self,
        selector: #selector(applicationWillTerminate),
        name: UIApplication.willTerminateNotification,
        object: nil
      )

    self
      .commandS
      .compactMap {
        if case .enqueue(request: let request) = $0 { return request }
        return nil
      }
      .map { [weak self] request in self?.executeDownload(request) ?? .empty() }
      .merge(maxConcurrent: options.maxConcurrent)
      .subscribe()
      .disposed(by: self.disposeBag)
  }

  // MARK: Private helpers

  /// Cancel all task. Delete temporary files
  @objc private func applicationWillTerminate(notification: Notification) {
    let d = DispatchSemaphore(value: 0)

    _ = self
      .dataSource
      .cancelAll()
      .andThen(.deferred { [fileManager] in
        let temporaryDirectory = fileManager.temporaryDirectory
         
        try fileManager
           .contentsOfDirectory(atPath: temporaryDirectory.path)
           .map { temporaryDirectory.appendingPathComponent($0) }
           .forEach { try fileManager.removeItem(at: $0) }
         
        return .empty()
      })
      .subscribe { event in
        switch event {
        case .completed:
          print("[DownloaderKit] [INFO] clean up successfully")
        case .error(let error):
          print("[DownloaderKit] [INFO] failed to clean up: \(error)")
        }

        d.signal()
    }

    d.wait()
  }

  /// Execute download request, update local database and send result.
  /// All errors is sent to `downloadResultS` and  is discarded afterwards.
  /// - Parameter request: Download request
  /// - Returns: a Completable that always completed
  private func executeDownload(_ request: DownloadKitRequest) -> Completable {
    Completable
      .deferred { [weak self, downloadResultS, dataSource] () -> Completable in
        guard let self = self else { return .empty() }

        // check already cancelled before
        guard let task = try dataSource.getOptional(by: request.identifier), task.canDownload else {
          print("[DownloaderKit] [DEBUG] Task with identifier: \(request.identifier) does not exist or be cancelled")
          return .empty()
        }

        let urlRequest = URLRequest(url: request.url)
        let destination: DownloadRequest.Destination = { (temporaryURL, response) in
          (
            request.destinationURL,
            [.createIntermediateDirectories, .removePreviousFile]
          )
        }
        
        #if DEBUG
        MainScheduler.ensureRunningOnMainThread()
        #endif

        // Is task completed naturally
        var isCompleted = false

        return RxAlamofire
          .download(urlRequest, to: destination)
          .flatMap { $0.rx.progress() }
          .observe(on: Schedulers.mainScheduler)
          .do(
            onCompleted: {
              #if DEBUG
              MainScheduler.ensureRunningOnMainThread()
              #endif

              isCompleted = true
            }
          )
          .take(until: self.cancelCommand(for: request.identifier))
          .throttle(self.options.throttleProgress, latest: true, scheduler: self.throttleScheduler)
          .distinctUntilChanged()
          .materialize()
          .observe(on: Schedulers.mainScheduler)
          .map { progress -> (state: DownloadKitState, error: Error?) in
            #if DEBUG
            MainScheduler.ensureRunningOnMainThread()
            #endif
            
            return (progress.asDownloadState(isCompleted), progress.error)
          }
          .do(
            onNext: { (state, error) in
              #if DEBUG
              MainScheduler.ensureRunningOnMainThread()
              #endif

              if case .completed = state {
                downloadResultS.accept(.success(request))
              }
              else if case .cancelled = state {
                downloadResultS.accept(.cancelled(request))
              }
              else if case .failed = state, let error = error {
                downloadResultS.accept(.failure(request, .downloadError(error)))
              }
            }
          )
          .concatMap { (state, _) -> Completable in
            dataSource.update(
              id: request.identifier,
              state: state
            )
          }
          .asCompletable()
      }
      .catch { error in
        print("[DownloaderKit] [ERROR] Unhandled error: \(error)")
        return .empty()
      }
      .subscribe(on: Schedulers.concurrentMainScheduler)
  }

  /// Filter command cancel task that has id equals to `identifierNeedCancel`
  private func cancelCommand(for identifierNeedCancel: String) -> Observable<Void> {
    self.commandS.compactMap {
      if case .cancel(let identifier) = $0, identifier == identifierNeedCancel {
        return ()
      }
      if case .cancelAll = $0 {
        return ()
      }
      return nil
    }
  }
  
  fileprivate func send(command: Command) {
    print("[DownloaderKit] [DEBUG] send command=\(command), thread=\(Thread.current), queue=\(currentDispatchQueueLabel())")

    #if DEBUG
    MainScheduler.ensureRunningOnMainThread()
    #endif
    
    self.commandS.accept(command)
  }
}

// MARK: Observe state by identifier
extension RealDownloader {
  func observe(by identifier: String) -> Observable<DownloadKitTask?> {
    Observable
      .deferred { [dataSource] () -> Observable<DownloadKitTask?> in
        if let task = try dataSource.getOptional(by: identifier) {
          return Observable
            .from(object: task, emitInitialValue: true)
            .map { .init(from: $0) }
        }

        return Observable
          .collection(
            from: try dataSource.getResults(by: identifier),
            synchronousStart: true,
            on: .main
          )
          .map { results in results.first.map { .init(from: $0) } }
      }
      .subscribe(on: Schedulers.concurrentMainScheduler)
      .distinctUntilChanged()
  }

}

// MARK: Observe state by identifiers
extension RealDownloader {
  func observe<T: Sequence>(by identifiers: T) -> Observable<[String: DownloadKitTask]>
  where T.Element == String
  {
    Observable
      .deferred { [dataSource] () -> Observable<[String: DownloadKitTask]> in
        Observable
          .collection(
            from: try dataSource.getResults(by: Set(identifiers)),
            synchronousStart: true,
            on: .main
          )
          .map { results in
            let taskById = results.map { ($0.identifier, DownloadKitTask.init(from: $0)) }
            return Dictionary(uniqueKeysWithValues: taskById)
          }
          .distinctUntilChanged()
      }
      .subscribe(on: Schedulers.concurrentMainScheduler)
  }
}

// MARK: Download result observable
extension RealDownloader {
  var downloadResult$: Observable<DownloadKitResult> { self.downloadResultS.asObservable() }
}

// MARK: Enqueue download request
extension RealDownloader {
  func enqueue(_ request: DownloadKitRequest) -> Completable {
    // insert or update task into database
    // and then, send command to enqueue download request
    self.dataSource
      .insertOrUpdate(
        identifier: request.identifier,
        url: request.url,
        destinationURL: request.destinationURL,
        state: .enqueued
      )
      .onCompleted(send: .enqueue(request: request), in: self)
  }
}

// MARK: Cancel by identifier
extension RealDownloader {
  func cancel(by identifier: String) -> Completable {
    // send command to cancel downloading task
    // and then, mask task as cancelled to prevent executing enqueued task
    self.dataSource
      .update(id: identifier, state: .cancelled)
      .onSubscribed(send: .cancel(identifier: identifier), in: self)
  }
}

// MARK: Cancel all
extension RealDownloader {
  func cancelAll() -> Completable {
    self.dataSource
      .cancelAll()
      .onSubscribed(send: .cancelAll, in: self)
  }
}

// MARK: Remove by identifier
extension RealDownloader {
  func remove(by identifier: String, and deleteFile: @escaping (DownloadKitTask) -> Bool) -> Completable {
    self.dataSource
      .remove(by: identifier)
      .flatMapCompletable { [fileManager] entity -> Completable in
        .deferred {
          print("[DownloaderKit] [DEBUG] remove thread=\(Thread.current), queue=\(currentDispatchQueueLabel())")

          // remove file if needed
          try fileManager.removeFile(of: .init(from: entity), deleteFile)
          return .empty()
        }
      }
      .onSubscribed(send: .cancel(identifier: identifier), in: self)
  }
}

// MARK: Remove all
extension RealDownloader {
  func removeAll(deleteFile: @escaping (DownloadKitTask) -> Bool) -> Completable {
    self.dataSource
      .removeAll()
      .flatMapCompletable { [fileManager] entites -> Completable in
        .deferred { () -> Completable in
          print("[DownloaderKit] [DEBUG] removeAll thread=\(Thread.current), queue=\(currentDispatchQueueLabel())")

          // remove files if needed
          try entites.forEach { try fileManager.removeFile(of: .init(from: $0), deleteFile) }
          return .empty()
        }
      }
      .onSubscribed(send: .cancelAll, in: self)
  }
}

// MARK: Completable + onSubscribed + onCompleted
extension Completable {
  /// On subscribed, will send `command` on `ConcurrentMainScheduler`.
  fileprivate func onSubscribed(send command: Command, in downloader: RealDownloader) -> Completable {
     self
      .do(onSubscribed: { [weak downloader] in downloader?.send(command: command) })
      .subscribe(on: Schedulers.concurrentMainScheduler)
  }
  
  /// On completed, will send `command` on `MainScheduler`.
  fileprivate func onCompleted(send command: Command, in downloader: RealDownloader) -> Completable {
    self
      .observe(on: Schedulers.mainScheduler)
      .do(onCompleted: { [weak downloader] in downloader?.send(command: command) })
  }
}
