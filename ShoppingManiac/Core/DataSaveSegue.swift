//
//  DataSaveSegue.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19/12/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreData
import RxSwift

class DataSaveSegue: UIStoryboardSegue {

    var errorMessage: String?
    var processBlock: (NSManagedObjectContext) -> Bool = {transaction in return true}
    private let disposeBag = DisposeBag()

    override func perform() {
        DAO.performAsync(updates: {[weak self] context -> Bool in
            guard let self = self else { return false }
            return self.processBlock(context)
        }).observeOn(MainScheduler.asyncInstance).subscribe(onNext: {result in
            if result {
                self.realPerform()
            } else {
                self.showAlert(message: self.errorMessage ?? "Error saving data")
            }
        }).disposed(by: self.disposeBag)
    }

    private func realPerform() {
        super.perform()
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        let closeAction = UIAlertAction(title: "Close", style: .cancel) { [weak alert] _ in
            alert?.dismiss(animated: true, completion: nil)
        }
        alert.addAction(closeAction)
        self.source.present(alert, animated: true, completion: nil)
    }
}
