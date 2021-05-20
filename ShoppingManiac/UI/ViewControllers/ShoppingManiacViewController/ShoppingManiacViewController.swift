//
//  ShoppingManiacViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import MessageUI
import Combine

class ShoppingManiacViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    private var keyboardCancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setBottomOffset(keyboardInfo: UIKeyboardInfo(info: [:]))
        LocalNotifications.keyboardWillChangeFrame.listen().sink(receiveCompletion: {_ in }, receiveValue: {[weak self] value in
            self?.setBottomOffset(keyboardInfo: value)
        }).store(in: &keyboardCancellables)
        LocalNotifications.keyboardWillHide.listen().map({_ in UIKeyboardInfo(info: [:])}).sink(receiveCompletion: {_ in }, receiveValue: {[weak self] value in
            self?.setBottomOffset(keyboardInfo: value)
        }).store(in: &keyboardCancellables)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.view.endEditing(true)
        for item in self.keyboardCancellables {
            item.cancel()
        }
        self.keyboardCancellables = []
    }
        
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    private func setBottomOffset(keyboardInfo: UIKeyboardInfo) {
        let offset = keyboardInfo.frame.size.height
        let bottomAreaHeight = self.view.safeAreaInsets.bottom - self.additionalSafeAreaInsets.bottom
        UIView.animate(withDuration: keyboardInfo.animationDuration, animations: { [weak self] in
            self?.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: offset > 0 ? offset - bottomAreaHeight : 0, right: 0)
        })
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
