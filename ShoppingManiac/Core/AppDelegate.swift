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
import DependencyInjection
import CloudKitSync

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    static var discoverabilityStatus: Bool = false

    static let documentsRootDirectory: URL = {
        return FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).first!
    }()

	private var cancellables = Set<AnyCancellable>()
	@Autowired
	private var cloudLoader: CloudKitSyncLoaderProtocol
	@Autowired
	private var cloudShare: CloudKitSyncShareProtocol

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		DIProvider.shared
			.register(forType: CloudKitSyncOperationsProtocol.self, dependency: CloudKitOperations.self)
			.register(forType: CloudKitSyncTokenStorageProtocol.self, dependency: CloudKitTokenStorage.self)
			.register(forType: CloudKitSyncUtilsProtocol.self, dependency: CloudKitSyncUtils.self)
			.register(forType: CloudKitSyncShareProtocol.self, dependency: CloudKitSyncShare.self)
			.register(forType: CloudKitSyncLoaderProtocol.self, dependency: CloudKitSyncLoader.self)

		application.registerForRemoteNotifications()
        let log = SwiftyBeaver.self
        log.addDestination(ConsoleDestination())
        
        let defaultCoreDataFileURL = AppDelegate.documentsRootDirectory.appendingPathComponent((Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "ShoppingManiac", isDirectory: false).appendingPathExtension("sqlite")
        let store = SQLiteStore(fileURL: defaultCoreDataFileURL, localStorageOptions: .allowSynchronousLightweightMigration)
        _ = try? CoreStoreDefaults.dataStack.addStorageAndWait(store)
		cloudShare.setupUserPermissions(itemType: ShoppingList.self).sink(receiveCompletion: { completion in
			switch completion {
			case .finished:
				AppDelegate.discoverabilityStatus = true
			case .failure(let error):
				AppDelegate.showAlert(title: "CloudKit permissions error", message: error.localizedDescription)
			}
		}, receiveValue: {}).store(in: &self.cancellables)
        CloudSubscriptions.setupSubscriptions()
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification {
            SwiftyBeaver.debug(String(describing: notification))
			self.cloudLoader.fetchChanges(localDb: false, itemType: ShoppingList.self)
				.flatMap({[unowned self] _ in self.cloudLoader.fetchChanges(localDb: true, itemType: ShoppingList.self)})
					.observeOnMain()
					.sink(receiveCompletion: {completion in
				switch completion {
				case .finished:
					SwiftyBeaver.debug("loading updates done")
					completionHandler(.newData)
				case .failure(let error):
					SwiftyBeaver.debug(error.localizedDescription)
					completionHandler(.noData)
				}
			}, receiveValue: {_ in }).store(in: &self.cancellables)
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
		HUD.show(.labeledProgress(title: "Loading data", subtitle: nil))
		self.cloudLoader.loadShare(metadata: cloudKitShareMetadata, itemType: ShoppingList.self).observeOnMain().sink(receiveCompletion: {completion in
			HUD.hide()
			switch completion {
			case .finished:
				SwiftyBeaver.debug("loading lists done")
			case .failure(let error):
				AppDelegate.showAlert(title: "Data loading error", message: error.localizedDescription)
			}
		}, receiveValue: {[weak self] list in
			guard let list = CoreStoreDefaults.dataStack.fetchExisting(list) else { return }
			self?.showList(list: list)
		}).store(in: &self.cancellables)
    }

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
		return application(app, handleOpen: url)
	}

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        if let data = try? Data(contentsOf: url),
			let jsonObject = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())) as? NSDictionary,
			let list = ShoppingList.importShoppingList(fromJsonData: jsonObject) {
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
