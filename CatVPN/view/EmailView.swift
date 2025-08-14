//
//  EmailView.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/1/15.
//

import SwiftUI
import MessageUI

struct EmailView: UIViewControllerRepresentable {
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        // 检查设备是否支持邮件
//        guard MFMailComposeViewController.canSendMail() else {
//            logDebug("设备不支持发送邮件")
//            // 返回一个空的控制器，但这种情况不应该发生
//            return MFMailComposeViewController()
//        }
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        
        // 固定设置
        mailComposer.setToRecipients(["support@catvpn.com"])
        mailComposer.setSubject("Feedback")
        mailComposer.setMessageBody("", isHTML: false)
        
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // 不需要更新
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailView
        
        init(_ parent: EmailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
            parent.onDismiss?()
        }
    }
    
    // 检查设备是否支持发送邮件
    static func canSendEmail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }
}
