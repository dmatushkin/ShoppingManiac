//
//  FetchChangesViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/15/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import PKHUD
import Combine
import CloudKitSync
import DependencyInjection

class FetchChangesViewController: UIViewController {
    
	private var cancellables = Set<AnyCancellable>()
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
	@Autowired
	private var cloudLoader: CloudKitSyncLoaderProtocol
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityIndicator.startAnimating()
		self.cloudLoader.fetchChanges(localDb: false, itemType: CloudKitShoppingList.self)
			.flatMap({ $0.persistModelChanges() })
			.flatMap({[unowned self] _ in self.cloudLoader.fetchChanges(localDb: true, itemType: CloudKitShoppingList.self)})
			.flatMap({ $0.persistModelChanges() })
			.observeOnMain().sink(receiveCompletion: {completion in
			switch completion {
			case .finished:
				self.proceed()
			case .failure(let error):
				self.hasError(error: error)
			}
		}, receiveValue: {_ in }).store(in: &self.cancellables)
    }
    
    private func proceed() {
        self.activityIndicator.stopAnimating()
        self.performSegue(withIdentifier: "proceedSegue", sender: self)
    }
    
    private func hasError(error: Error) {
		error.showError(title: "CloudKit update error")
        self.proceed()
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
}
