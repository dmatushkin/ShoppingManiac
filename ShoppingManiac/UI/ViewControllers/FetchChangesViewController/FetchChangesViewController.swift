//
//  FetchChangesViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/15/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import RxSwift
import PKHUD

class FetchChangesViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    private let cloudLoader = CloudLoader(cloudKitUtils: CloudKitUtils(operations: CloudKitOperations(), storage: CloudKitTokenStorage()))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityIndicator.startAnimating()
        self.cloudLoader.fetchChanges(localDb: false).concat(self.cloudLoader.fetchChanges(localDb: true)).observeOn(MainScheduler.asyncInstance).subscribe(onError: self.hasError, onCompleted: self.proceed).disposed(by: self.disposeBag)
    }
    
    private func proceed() {
        self.activityIndicator.stopAnimating()
        self.performSegue(withIdentifier: "proceedSegue", sender: self)
    }
    
    private func hasError(error: Error) {
        self.proceed()
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
}
