//
//  NotificationsViewController.swift
//  GeoConfess
//
//  Created  by Christian Dimitrov on April 19, 2016.
//  Reviewed by Paulo Mattos on June 2, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Controls the notifications UI.
final class NotificationsViewController: AppViewControllerWithToolbar,
										 UITableViewDataSource, UITableViewDelegate {

	// MARK: - View Controller Lifecycle
	
	static func instantiateViewController() -> NotificationsViewController {
		let storyboard = UIStoryboard(name: "MeetRequests", bundle: nil)
		return storyboard.instantiateViewControllerWithIdentifier(
			"NotificationsViewController") as! NotificationsViewController
	}
	
	override func viewDidLoad(){
		super.viewDidLoad()
		
		notificationsTable.delegate = self
		notificationsTable.dataSource = self
		notificationsTable.tableFooterView = UIView()
	}
 
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		let notificationManager = User.current.notificationManager
		notifications = notificationManager.notifications
		notificationManager.addObserver(self)
		notificationsTable.reloadData()
		
		replyToMeetRequest = nil
		chatWithUser = nil
		notificationsTable.selectRowAtIndexPath(nil, animated: false,
		                                        scrollPosition: .None)
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		
		replyToMeetRequest = nil
		chatWithUser = nil
		if let notificationManager = User.current?.notificationManager {
			notificationManager.removeObserver(self)
		}
	}
	
	// MARK: - Notifications Model
	
	private var notifications = [Notification]() {
		didSet {
			notifications = notifications.sort().reverse()
		}
	}
	
	override func notificationManager(
		manager: NotificationManager,
		didAddNotifications notifications: [Notification]) {
		super.notificationManager(manager, didAddNotifications: notifications)
		notificationsDidUpdate(manager.notifications)
	}
	
	override func notificationManager(
		manager: NotificationManager,
		didDeleteNotifications notifications: [Notification]) {
		super.notificationManager(manager, didDeleteNotifications: notifications)
		notificationsDidUpdate(manager.notifications)
	}

	private func notificationsDidUpdate(newNotifications: [Notification]) {
		let oldNotifications = self.notifications
		self.notifications = newNotifications
		
		// Try to insert new notifications in a fast & smooth way, if easy.
		// If too tricky, lets just reload the damn thing!
		if !insertNewNotifications(newNotifications, old: oldNotifications) {
			notificationsTable.reloadData()
		}
		
		// Makes sure latest notification is visible.
		if newNotifications.count > 0 {
			let latestIndex = NSIndexPath(forRow: 0, inSection: 0)
			notificationsTable.scrollToRowAtIndexPath(
				latestIndex, atScrollPosition: .None, animated: true)
		}
	}
	
	private func insertNewNotifications(newNotifications: [Notification],
	                                    old oldNotifications: [Notification]) -> Bool {
		let newNotificationSet = Set(newNotifications)
		let oldNotificationSet = Set(oldNotifications)

		func indexPathsUntil(rowCount: Int) -> [NSIndexPath] {
			var indexPaths = [NSIndexPath]()
			for index in 0..<rowCount {
				indexPaths.append(NSIndexPath(forRow: index, inSection: 0))
			}
			return indexPaths
		}

		if newNotificationSet == oldNotificationSet {
			return true
		}
		if newNotificationSet.isEmpty {
			notificationsTable.deleteRowsAtIndexPaths(
				indexPathsUntil(oldNotificationSet.count), withRowAnimation: .Bottom)
			return true
		}
		if oldNotificationSet.isEmpty {
			notificationsTable.insertRowsAtIndexPaths(
				indexPathsUntil(newNotificationSet.count), withRowAnimation: .Top)
			return true
		}
		if oldNotificationSet.isSubsetOf(newNotificationSet) {
			let diffNotificationSet = newNotificationSet.subtract(oldNotificationSet)
			let oldMaxID = oldNotificationSet.maxElement()!.id
			let newMinID = diffNotificationSet.minElement()!.id
			if newMinID > oldMaxID {
				notificationsTable.insertRowsAtIndexPaths(
					indexPathsUntil(diffNotificationSet.count), withRowAnimation: .Top)
				return true
			}
		}
		return false
	}
	
	// MARK: - Table View Delegate and Data
	
	@IBOutlet weak private var notificationsTable: UITableView!
	
	func tableView(tableView: UITableView,
	               heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return 80
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return notifications.count
	}
	
	func tableView(tableView: UITableView,
	               cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(
			"NotificationCell", forIndexPath: indexPath) as! NotificationCell
		
		let notification = notifications[indexPath.row]
		cell.setNotification(notification)
		return cell
	}
	
	// MARK: - Notification Selection
	
	func tableView(tableView: UITableView,
	               willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
		let user = User.current!
		let notification = notifications[indexPath.row]

		switch notification.model {
		case .MeetRequestNotification(let meetRequest):
			switch user.roleAt(meetRequest) {
			case .Penitent, .Admin:
				switch meetRequest.status {
				case .Pending, .Accepted, .Refused:
					return indexPath // Always selectable.
				}
			case .Priest:
				switch meetRequest.status {
				case .Pending, .Accepted:
					return indexPath
				case .Refused:
					return nil
				}
			}
		case .MessageNotification:
			switch user.role {
			case .Penitent, .Priest, .Admin:
				return indexPath // Always selectable.
			}
		}
	}
	
	func tableView(tableView: UITableView,
	               didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let user = User.current!
		let notification = notifications[indexPath.row]
		print("\(notification)")
		
		switch notification.model {
		case .MeetRequestNotification(let meetRequest):
			switch user.roleAt(meetRequest) {
			case .Penitent, .Admin:
				switch meetRequest.status {
				case .Pending:
					// User lands on priest page for pending request (UI 5.2.2)
					let vc = MeetRequestViewController
						.instantiateForPriest(meetRequest.priest)
					navigationController.pushViewController(vc, animated: true)
				case .Accepted:
					// User lands on chat.
					chatWithUser = meetRequest.priest
					performSegueWithIdentifier("chatWithUser", sender: self)
				case .Refused:
					// User lands on priest page for refused requests.
					let vc = MeetRequestViewController
						.instantiateForPriest(meetRequest.priest)
					navigationController.pushViewController(vc, animated: true)
				}
			case .Priest:
				switch meetRequest.status {
				case .Pending:
					// Priest lands on UI 8.2 (booking request flow).
					replyToMeetRequest = meetRequest
					performSegueWithIdentifier("replyToRequest", sender: self)
				case .Accepted:
					// Priest lands on chat.
					chatWithUser = meetRequest.penitent
					performSegueWithIdentifier("chatWithUser", sender: self)
				case .Refused:
					preconditionFailure("This notification should not be selectable")
					break
				}
			}
		case .MessageNotification(let message):
			switch user.role {
			case .Penitent, .Priest, .Admin:
				// User lands on chat.
				// TODO: User real user information.
				assert(User.current.id == message.recipientID)
				chatWithUser = UserInfo(id: message.senderID,
				                        name: "User_\(message.senderID)",
				                        surname: "USER")
				performSegueWithIdentifier("chatWithUser", sender: self)
			}
		}
	}
	
	private var replyToMeetRequest: MeetRequest?
	private var chatWithUser: UserInfo?
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		switch segue.identifier! {
		case "replyToRequest":
			precondition(replyToMeetRequest != nil)
			let meetRequestReplyVC = segue.destinationViewController
				as! MeetRequestReplyViewController
			meetRequestReplyVC.replyToMeetRequest(replyToMeetRequest!)
		case "chatWithUser":
			precondition(chatWithUser != nil)
			let chatVC = segue.destinationViewController
				as! ChatWrapperViewController
			chatVC.chatWithUser(chatWithUser!)
		default:
			preconditionFailure("Unexpected segue: \(segue.identifier)")
		}
	}
	
	// MARK: - Toolbar Buttons
	
	override func notificatioButtonTapped(buttton: UIButton) {
		guard notifications.count > 0 else { return }
		let latestIndex = NSIndexPath(forRow: 0, inSection: 0)
		notificationsTable.scrollToRowAtIndexPath(
			latestIndex, atScrollPosition: .None, animated: true)
	}
}
