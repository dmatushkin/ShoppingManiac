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
import PKHUD
import SwiftEntryKit
import Combine

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    static var discoverabilityStatus: Bool = false

    static let documentsRootDirectory: URL = {
        return FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).first!
    }()

	private var cancellables = Set<AnyCancellable>()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        application.registerForRemoteNotifications()
		DIProvider.shared
			.register(forType: CloudKitOperationsProtocol.self, dependency: CloudKitOperations.self)
			.register(forType: CloudKitTokenStorgeProtocol.self, dependency: CloudKitTokenStorage.self)
			.register(forType: CloudKitUtilsProtocol.self, dependency: CloudKitUtils.self)
		
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
			CloudLoader().fetchChanges(localDb: false).append(CloudLoader().fetchChanges(localDb: true)).observeOnMain().sink(receiveCompletion: {completion in
				switch completion {
				case .finished:
					SwiftyBeaver.debug("loading updates done")
					LocalNotifications.newDataAvailable.post(value: ())
					completionHandler(.newData)
				case .failure(let error):
					SwiftyBeaver.debug(error.localizedDescription)
					completionHandler(.noData)
				}
			}, receiveValue: {}).store(in: &self.cancellables)
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
				CloudLoader().loadShare(metadata: metadata).observeOnMain().sink(receiveCompletion: {completion in
					switch completion {
					case .finished:
						SwiftyBeaver.debug("loading lists done")
						LocalNotifications.newDataAvailable.post(value: ())
					case .failure(let error):
						HUD.flash(.labeledError(title: "Data loading error", subtitle: error.localizedDescription), delay: 3)
					}
				}, receiveValue: {[weak self] list in
					HUD.hide()
                    guard let list = CoreStoreDefaults.dataStack.fetchExisting(list) else { return }
                    self?.showList(list: list)
				}).store(in: &self.cancellables)
            }
        }
        CKContainer.default().add(operation)
    }

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
		return application(app, handleOpen: url)
	}

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        let data = try? Data(contentsOf: url)
        if let jsonObject = (try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions())) as? NSDictionary, let list = ShoppingList.importShoppingList(fromJsonData: jsonObject) {
            self.showList(list: list)
        }
        return true
    }
    
    private func showList(list: ShoppingList) {
		if let controllers = (self.window?.rootViewController as? UINavigationController)?.viewControllers, controllers.count > 1, let topController = controllers[1] as? UITabBarController, let listViewController = ((topController.viewControllers?.first as? ListSplitViewController)?.viewControllers.first as? UINavigationController)?.viewControllers.first as? ShoppingListsListViewController {
			topController.selectedIndex = 0
			listViewController.navigationController?.popToRootViewController(animated: false)
			listViewController.showList(list: list)
		}
    }

    class func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
			var attributes = EKAttributes.topFloat
			attributes.entryBackground = .color(color: EKColor(UIColor(named: "cancelColor")!))
			attributes.popBehavior = .animated(animation: .init(translate: .init(duration: 0.3), scale: .init(from: 1, to: 0.7, duration: 0.7)))
			attributes.shadow = .active(with: .init(color: .black, opacity: 0.5, radius: 10, offset: .zero))
			attributes.statusBar = .dark
			attributes.scroll = .enabled(swipeable: true, pullbackAnimation: .jolt)

			let title = EKProperty.LabelContent(text: title, style: .init(font: UIFont.systemFont(ofSize: 18), color: EKColor(.black)))
			let description = EKProperty.LabelContent(text: message, style: .init(font: UIFont.systemFont(ofSize: 15), color: EKColor(.black)))
			let simpleMessage = EKSimpleMessage(title: title, description: description)
			let alertMessage = EKAlertMessage(simpleMessage: simpleMessage,
											  buttonBarContent: .init(with: [],
																	  separatorColor: EKColor(.clear),
																	  expandAnimatedly: false))

			let contentView = EKAlertMessageView(with: alertMessage)
			SwiftEntryKit.display(entry: contentView, using: attributes)
        }
    }
}
