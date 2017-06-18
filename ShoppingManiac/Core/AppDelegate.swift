//
//  AppDelegate.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    static let documentsRootDirectory: URL = {
        return FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).first!
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let defaultCoreDataFileURL = AppDelegate.documentsRootDirectory.appendingPathComponent((Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "ShoppingManiac", isDirectory: false).appendingPathExtension("sqlite")
        let store = SQLiteStore(fileURL: defaultCoreDataFileURL, localStorageOptions: .allowSynchronousLightweightMigration)
        let _ = try? CoreStore.addStorageAndWait(store)
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
                        if let goodName = itemDict["good"] as? String, goodName.characters.count > 0 {
                            if let good = transaction.fetchOne(From<Good>(), Where("name == %@", goodName)) {
                                shoppingListItem.good = good
                            } else {
                                let good = transaction.create(Into<Good>())
                                good.name = goodName
                                shoppingListItem.good = good
                            }
                        }
                        if let storeName = itemDict["store"] as? String, storeName.characters.count > 0 {
                            if let store = transaction.fetchOne(From<Store>(), Where("name == %@", storeName)) {
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
            return list
        } catch {
            return nil
        }
    }
}

