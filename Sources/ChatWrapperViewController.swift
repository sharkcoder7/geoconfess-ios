//
//  ChatWrapperViewController.swift
//  GeoConfess
//
//  Created by Sergei Volkov on May 5, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Controls the chat UI.
/// See `ChatViewController` for the actual chat view controller.
final class ChatWrapperViewController: AppViewControllerWithToolbar {
	
	@IBOutlet weak private var chatTitleLabel: UILabel!
	@IBOutlet weak private var chatView: UIView!
	private var chatViewController: ChatViewController!
	
	private var chattingWithUser: UserInfo!
	
	func chatWithUser(otherUser: UserInfo) {
		chattingWithUser = otherUser
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		setChatTitle()
		
		assert(chatViewController == nil)
		chatViewController = storyboard!
			.instantiateViewControllerWithIdentifier("ChatViewController")
			as! ChatViewController
		addChildViewController(chatViewController)
		chatView.addSubview(chatViewController.view)
		chatViewController.didMoveToParentViewController(self)
		chatViewController.chatWithUser(chattingWithUser)
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		
		chatViewController.removeFromParentViewController()
		chatViewController = nil
	}
	
	private func setChatTitle() {
		precondition(chattingWithUser != nil)
		
		func font(name: String) -> [String: AnyObject] {
			return [NSFontAttributeName: UIFont(name: name, size: 19.0)!]
		}
		
		let lightFont = font("adventpro-Lt1")
		let prefix = NSAttributedString(
			string: "CONFESSEUR ", attributes: lightFont)
		
		let boldFont = font("adventpro-Bd3")
		let recipientName = NSAttributedString(
			string: chattingWithUser.name.uppercaseString, attributes: boldFont)
		
		let title = NSMutableAttributedString()
		title.appendAttributedString(prefix)
		title.appendAttributedString(recipientName)
		chatTitleLabel.attributedText = title
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		chatViewController?.view.frame = chatView.bounds
	}
}
