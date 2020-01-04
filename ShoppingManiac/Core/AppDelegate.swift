//
//  AppDelegate.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import CloudKit
import SwiftyBeaver
import RxSwift
import PKHUD

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    static var discoverabilityStatus: Bool = false

    static let documentsRootDirectory: URL = {
        return FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).first!
    }()
    
    private let disposeBag = DisposeBag()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        application.registerForRemoteNotifications()
        
        let log = SwiftyBeaver.self
        log.addDestination(FileDestination())
        log.addDestination(ConsoleDestination())
        
        let defaultCoreDataFileURL = AppDelegate.documentsRootDirectory.appendingPathComponent((Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "ShoppingManiac", isDirectory: false).appendingPathExtension("sqlite")
        let store = SQLiteStore(fileURL: defaultCoreDataFileURL, localStorageOptions: .allowSynchronousLightweightMigration)
        _ = try? CoreStoreDefaults.dataStack.addStorageAndWait(store)
        CloudShare.setupUserPermissions()        
        CloudSubscriptions.setupSubscriptions()
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification {
            SwiftyBeaver.debug(String(describing: notification))
            CloudLoader.fetchChanges(localDb: false).concat(CloudLoader.fetchChanges(localDb: true)).observeOnMain().subscribe(onError: { error in
                SwiftyBeaver.debug(error.localizedDescription)
                completionHandler(.noData)
            }, onCompleted: {
                SwiftyBeaver.debug("loading updates done")
                LocalNotifications.newDataAvailable.post(value: ())
                completionHandler(.newData)
            }).disposed(by: self.disposeBag)
        } else {
            completionHandler(.noData)
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        let operation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        operation.qualityOfService = .userInteractive
        operation.perShareCompletionBlock = {[weak self] metadata, share, error in
            guard let self = self else {return}
            if let error = error {
                SwiftyBeaver.debug("sharing accept error \(error.localizedDescription)")
            } else {
                SwiftyBeaver.debug("sharing accepted successfully")
                DispatchQueue.main.async {
                    HUD.show(.labeledProgress(title: "Loading data", subtitle: nil))
                }
                CloudLoader.loadShare(metadata: metadata).observeOnMain().subscribe(onNext: {[weak self] list in
                    HUD.hide()
                    guard let list = CoreStoreDefaults.dataStack.fetchExisting(list) else { return }
                    self?.showList(list: list)
                }, onError: {error in
                    HUD.flash(.labeledError(title: "Data loading error", subtitle: error.localizedDescription), delay: 3)
                }, onCompleted: {
                    SwiftyBeaver.debug("loading lists done")
                    LocalNotifications.newDataAvailable.post(value: ())
                }).disposed(by: self.disposeBag)
            }
        }
        CKContainer.default().add(operation)
    }

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        let data = try? Data(contentsOf: url)
        if let jsonObject = (try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions())) as? NSDictionary, let list = ShoppingList.importShoppingList(fromJsonData: jsonObject) {
            self.showList(list: list)
        }
        return true
    }
    
    private func showList(list: ShoppingList) {
        if let topController = self.window?.rootViewController as? UITabBarController, let navigation = topController.viewControllers?.first as? UINavigationController, let listController = navigation.viewControllers.first as? ShoppingListsListViewController {
            topController.selectedIndex = 0
            listController.dismiss(animated: false, completion: nil)
            listController.showList(list: list)
        }
    }

    class func topViewController(rootViewController: UIViewController?) -> UIViewController? {
        guard let rootViewController = rootViewController else { return nil }
        if let controller = rootViewController as? UITabBarController {
            return AppDelegate.topViewController(rootViewController: controller.selectedViewController)
        } else if let controller = rootViewController as? UINavigationController {
            return AppDelegate.topViewController(rootViewController: controller.visibleViewController)
        } else if let controller = rootViewController.presentedViewController {
            return AppDelegate.topViewController(rootViewController: controller)
        } else {
            return rootViewController
        }
    }

    class func topViewController() -> UIViewController? {
        guard let rootViewController = (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController else { return nil }
        return AppDelegate.topViewController(rootViewController: rootViewController)
    }

    class func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            if let topViewController = AppDelegate.topViewController() {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let closeAction = UIAlertAction(title: "Close", style: .cancel) { [weak alert] _ in
                    alert?.dismiss(animated: true, completion: nil)
                }
                alert.addAction(closeAction)
                topViewController.present(alert, animated: true, completion: nil)
            }
        }
    }

    class func showConfirm(title: String, message: String, onDone: @escaping (() -> Void)) {
        DispatchQueue.main.async {
            if let topViewController = AppDelegate.topViewController() {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let closeAction = UIAlertAction(title: "Close", style: .cancel) { [weak alert] _ in
                    alert?.dismiss(animated: false, completion: nil)
                    onDone()
                }
                alert.addAction(closeAction)
                topViewController.present(alert, animated: true, completion: nil)
            }
        }
    }

    class func showQuestion(title: String, message: String, question: String, cancelString: String = "Close", onController controller: UIViewController? = nil, onDone: @escaping (() -> Void)) {
        DispatchQueue.main.async {
            if let topViewController = controller ?? AppDelegate.topViewController() {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let questionAction = UIAlertAction(title: question, style: .default) { [weak alert] _ in
                    alert?.dismiss(animated: true, completion: nil)
                    onDone()
                }
                let closeAction = UIAlertAction(title: cancelString, style: .cancel) { [weak alert] _ in
                    alert?.dismiss(animated: true, completion: nil)
                }
                alert.addAction(questionAction)
                alert.addAction(closeAction)
                topViewController.present(alert, animated: true, completion: nil)
            }
        }
    }
}
