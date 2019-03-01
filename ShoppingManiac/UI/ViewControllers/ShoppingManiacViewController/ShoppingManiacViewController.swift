//
//  ShoppingManiacViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import MessageUI
import SWCompression

class ShoppingManiacViewController: UIViewController, MFMailComposeViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.view.endEditing(true)
    }
    
    /*override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == UIEventSubtype.motionShake {
            let cacheUrls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            for url in cacheUrls {
                let logUrl = url.appendingPathComponent("swiftybeaver.log")
                if let logData = try? Data(contentsOf: logUrl), MFMailComposeViewController.canSendMail() {
                    let composer = MFMailComposeViewController()
                    composer.mailComposeDelegate = self
                    composer.setSubject("Issue report")
                    composer.addAttachmentData(BZip2.compress(data: logData), mimeType: "application/x-bzip2", fileName: "log.txt.bz2")
                    self.present(composer, animated: true, completion: nil)
                }
            }
        }
    }*/
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
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
