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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
        
    static var discoverabilityStatus: Bool = false

    static let documentsRootDirectory: URL = {
        return FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).first!
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let defaultCoreDataFileURL = AppDelegate.documentsRootDirectory.appendingPathComponent((Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "ShoppingManiac", isDirectory: false).appendingPathExtension("sqlite")
        let store = SQLiteStore(fileURL: defaultCoreDataFileURL, localStorageOptions: .allowSynchronousLightweightMigration)
        let _ = try? CoreStore.addStorageAndWait(store)
        CloudShare.setupUserPermissions()
        return true
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
    
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShareMetadata) {
        let operation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        operation.qualityOfService = .userInteractive
        operation.perShareCompletionBlock = { metadata, share, error in
            if let error = error {
                print("sharing accept error \(error.localizedDescription)")
            }
        }
        CKContainer.default().add(operation)
    }

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        let data = try? Data(contentsOf: url)
        if let jsonObject = (try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions())) as? NSDictionary, let list = self.importShoppingList(fromJsonData: jsonObject) {
            if let topController = self.window?.rootViewController as? UITabBarController, let navigation = topController.viewControllers?.first as? UINavigationController, let listController = navigation.viewControllers.first as? ShoppingListsListViewController {
                topController.selectedIndex = 0
                listController.dismiss(animated: false, completion: nil)
                listController.listToShow = list
                listController.performSegue(withIdentifier: "shoppingListSegue", sender: self)
            }
        }
        return true
    }
    
    func importShoppingList(fromJsonData jsonData: NSDictionary) -> ShoppingList? {
        do {
            let list: ShoppingList = try CoreStore.perform(synchronous: { transaction in
                let list = transaction.create(Into<ShoppingList>())
                list.name = jsonData["name"] as? String
                list.jsonDate = (jsonData["date"] as? String) ?? ""
                if let itemsArray = jsonData["items"] as? [NSDictionary] {
                    for itemDict in itemsArray {
                        let shoppingListItem = transaction.create(Into<ShoppingListItem>())
                        if let goodName = itemDict["good"] as? String, goodName.count > 0 {
                            if let good = transaction.fetchOne(From<Good>().where(Where("name == %@", goodName))) {
                                shoppingListItem.good = good
                            } else {
                                let good = transaction.create(Into<Good>())
                                good.name = goodName
                                shoppingListItem.good = good
                            }
                        }
                        if let storeName = itemDict["store"] as? String, storeName.count > 0 {
                            if let store = transaction.fetchOne(From<Store>().where(Where("name == %@", storeName))) {
                                shoppingListItem.store = store
                            } else {
                                let store = transaction.create(Into<Store>())
                                store.name = storeName
                                shoppingListItem.store = store
                            }
                        }
                        shoppingListItem.purchased = (itemDict["purchased"] as? NSNumber)?.boolValue ?? false
                        shoppingListItem.price = (itemDict["price"] as? NSNumber)?.floatValue ?? 0
                        shoppingListItem.quantity = (itemDict["quantity"] as? NSNumber)?.floatValue ?? 0
                        shoppingListItem.isWeight = (itemDict["isWeight"] as? NSNumber)?.boolValue ?? false
                        shoppingListItem.jsonPurchaseDate = (itemDict["purchaseDate"] as? String) ?? ""
                        shoppingListItem.list = list
                    }
                }
                return list
            })
            return CoreStore.fetchExisting(list)
        } catch {
            return nil
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
                let closeAction = UIAlertAction(title: "Close", style: .cancel) { [weak alert] action in
                    alert?.dismiss(animated: true, completion: nil)
                }
                alert.addAction(closeAction)
                topViewController.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    class func showConfirm(title: String, message: String, onDone: @escaping (()->())) {
        DispatchQueue.main.async {
            if let topViewController = AppDelegate.topViewController() {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let closeAction = UIAlertAction(title: "Close", style: .cancel) { [weak alert] action in
                    alert?.dismiss(animated: false, completion: nil)
                    onDone()
                }
                alert.addAction(closeAction)
                topViewController.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    class func showQuestion(title: String, message: String, question: String, cancelString: String = "Close", onController controller: UIViewController? = nil, onDone: @escaping (()->())) {
        DispatchQueue.main.async {
            if let topViewController = controller ?? AppDelegate.topViewController() {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let questionAction = UIAlertAction(title: question, style: .default) { [weak alert] action in
                    alert?.dismiss(animated: true, completion: nil)
                    onDone()
                }
                let closeAction = UIAlertAction(title: cancelString, style: .cancel) { [weak alert] action in
                    alert?.dismiss(animated: true, completion: nil)
                }
                alert.addAction(questionAction)
                alert.addAction(closeAction)
                topViewController.present(alert, animated: true, completion: nil)
            }
        }
    }
}

