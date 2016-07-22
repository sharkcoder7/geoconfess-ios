//
//  NotificationManager.swift
//  GeoConfess
//
//  Created  by Sergei Volkov on April 30, 2016.
//  Reviewed by Paulo Mattos on May 31, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Manages all notifications received by the user.
/// Entry point available at `User.current.notifications`.
final class NotificationManager: Observable, AppObserver {
	
	private unowned let user: User
	
	init(forUser user: User) {
		self.user = user
		App.addObserver(self)
		resetFakeNotificationsSpawner()
		resetMeetRequestsCache()
		resetMessagesCache()
		resetNotificationsCache()
	}

	deinit {
		App.removeObserver(self)
		cancelFakeNotificationsSpawner()
		cancelNotificationsCacheRefresh()
	}
	
	func appDidUpdateConfiguration(config: App.Configuration) {
		resetFakeNotificationsSpawner() // This must come first.
		resetMeetRequestsCache()
		resetMessagesCache()
		resetNotificationsCache() // ...and this last.
	}

	// MARK: - Updating Notifications

	/// Last 99 notifications of current user not older than 1 month.
	///
	/// The notifications are sorted in *chronological* order (ie, newest comes last).
	private(set) var notifications: [Notification] = [ ] {
		didSet {
			notifications.sortInPlace()
			let inserted = Set(notifications).subtract(oldValue)
			let deleted  = Set(oldValue).subtract(notifications)
			addMeetRequestsFromNewNotifications(inserted)
			addMessagesFromNewNotifications(inserted)
			if inserted.count > 0 {
				notifyObservers {
					$0.notificationManager(self, didAddNotifications: inserted.sort())
				}
			}
			if deleted.count > 0 {
				notifyObservers {
					$0.notificationManager(self, didDeleteNotifications: deleted.sort())
				}
			}
		}
	}
	
	var unreadCount: Int {
		return notifications.filter { $0.unread }.count
	}
	
	private var notificationsRefreshTimer: Timer?
	
	private func resetNotificationsCache() {
		log("Resetting notifications...")
		let count = notifications.count
		notifications.removeAll()
		notificationsAlreadyReturned.removeAll()
		cancelNotificationsCacheRefresh()
		updateNotificationsCache()
		log("Resetting notifications... OK (\(count) deleted)")
	}
	
	private func cancelNotificationsCacheRefresh() {
		notificationsRefreshTimer?.dispose()
		notificationsRefreshTimer = nil
	}
	
	private func updateNotificationsCache() {
		preconditionIsMainQueue()
		let logLabel = "Updating notifications"
		log("\(logLabel)...")
		
		func scheduleNextUpdateWithTimeInterval(interval: Double) {
			notificationsRefreshTimer = Timer.scheduledTimerWithTimeInterval(interval) {
				[weak self] in
				guard self != nil else { return }
				self!.updateNotificationsCache()
			}
		}
		getNewNotifications() {
			result in
			preconditionIsMainQueue()
			switch result {
			case .Success(let newNotifications):
				log("\(logLabel)... OK (\(newNotifications.count) new)")
				let rate = NotificationManager.notificationsRefreshRate
				scheduleNextUpdateWithTimeInterval(rate)
                self.notifications += newNotifications
			case .Failure(let error):
				let wait = randomDoubleInRange(4...8)
				logError("\(logLabel)... FAILED. " +
					"Will try again in \(wait) seconds...\n\(error)")
				scheduleNextUpdateWithTimeInterval(wait)
			}
		}
	}

	private static var notificationsRefreshRate: NSTimeInterval {
		let key = "Notifications Refresh Rate (seconds)"
		let refreshRate = (App.properties[key]! as! NSNumber).doubleValue
		assert(refreshRate > 0)
		return refreshRate
	}

	// MARK: - Meet Requests
	
	private var meetRequestsByID = [ResourceID: MeetRequest]()
	
	/// All latest meet requests.
	var meetRequests: Set<MeetRequest> {
		return Set(meetRequestsByID.values)
	}

	func meetRequestForPriest(priestID: ResourceID) -> MeetRequest? {
		for meetRequest in meetRequests {
			if meetRequest.priest.id == priestID {
				return meetRequest
			}
		}
		return nil
	}
	
	private func resetMeetRequestsCache() {
		meetRequestsByID.removeAll()
	}

	private func addMeetRequestsFromNewNotifications(notifications: Set<Notification>) {
		var latest = [ResourceID: MeetRequest]()
		for notification in notifications.sort().reverse() {
			switch notification.model {
			case .MeetRequestNotification(let meetRequest):
				if latest[meetRequest.id] == nil {
					latest[meetRequest.id] = meetRequest
				}
			case .MessageNotification:
				break
			}
		}
		for (id, meetRequest) in latest {
			meetRequestsByID[id] = meetRequest
		}
		return
	}

	/// Sends a meet request to the specified priest.
	func sendMeetRequestTo(priestID: ResourceID,
	                       completion: Result<MeetRequest, NSError> -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/meet_requests/create.html
		let createRequestURL = "\(App.serverAPI)/requests"
		let request: [String: AnyObject] = [
			"priest_id": NSNumber(unsignedLongLong: priestID),
			"latitude":  user.location!.coordinate.latitude,
			"longitude": user.location!.coordinate.longitude
		]
		let params: [String: AnyObject] = [
			"access_token": user.oauth.accessToken,
			"request": request
		]
		Alamofire.request(.POST, createRequestURL, parameters: params).responseJSON {
			response in
			preconditionIsMainQueue()
			switch response.result {
			case .Success(let value):
				let meetRequest = MeetRequest(fromJSON: JSON(value))!
				precondition(self.meetRequestsByID[meetRequest.id] == nil)
				self.meetRequestsByID[meetRequest.id] = meetRequest
				completion(.Success(meetRequest))
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}
	
	// MARK: - Messages

	private var messagesByID = [ResourceID: Message]() {
		didSet {
			let inserted = Set(messagesByID.values).subtract(oldValue.values)
			if inserted.count > 0 {
				notifyObservers {
					$0.notificationManager(self, didAddMessages: inserted.sort())
				}
			}
		}
	}

	/// All messages *sent* or *received* by this user *ever*.
	///
	/// The messages are sorted in *chronological* order (ie, newest comes last).
	var messages: [Message] {
		return messagesByID.values.sort()
	}
	
	private func resetMessagesCache() {
		messagesByID.removeAll()
		getAllUserMessages()
	}
	
	private func addMessagesFromNewNotifications(notifications: Set<Notification>) {
		var latest = [ResourceID: Message]()
		for notification in notifications.sort().reverse() {
			switch notification.model {
			case .MessageNotification(let message):
				if latest[message.id] == nil {
					latest[message.id] = message
				}
			case .MeetRequestNotification:
				break
			}
		}
		for (id, message) in latest {
			messagesByID[id] = message
		}
		return
	}
	
	/// Downloads the *complete* chat history for this user.
	private func getAllUserMessages() {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/messages/index.html
		let userMessgesURL = "\(App.serverAPI)/messages"
		let params: [String: AnyObject] = [
			"access_token": user.oauth.accessToken,
		]
		let logLabel = "Getting all messages..."
		log("\(logLabel)...")
		Alamofire.request(.GET, userMessgesURL, parameters: params).responseJSON {
			[weak self] response in
			preconditionIsMainQueue()
			guard self != nil else { return }
			switch response.result {
			case .Success(let data):
				let messageArrayJSON = JSON(data).array!
				for messageJSON in messageArrayJSON {
					let message = Message(fromJSON: messageJSON)!
					precondition(self!.messagesByID[message.id] == nil)
					self!.messagesByID[message.id] = message
				}
				log("\(logLabel)... OK (\(messageArrayJSON.count) downloaded)")
			case .Failure(let error):
				logError("\(logLabel)... FAILED (\(error))")
			}
		}
	}
	
	/// Sends a message to the specified user.
	func sendMessageTo(userID: ResourceID, text: String,
	                   completion: Result<Void, NSError> -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/messages/create.html
		let createMessageURL = "\(App.serverAPI)/messages"
		let message: [String: AnyObject] = [
			"sender_id":    NSNumber(unsignedLongLong: user.id),
			"recipient_id": NSNumber(unsignedLongLong: userID),
			"text":         text
		]
		let params: [String: AnyObject] = [
			"access_token": user.oauth.accessToken,
			"message": message
		]
		Alamofire.request(.POST, createMessageURL, parameters: params).responseString {
			[weak self] response in
			preconditionIsMainQueue()
			guard self != nil else { return }
			switch response.result {
			case .Success(let value):
				assert(value.isEmpty)
				completion(.Success())
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}
	
	// MARK: - Observing Notifications
	
	/// Observers list. The actual type is `ObserverSet<NotificationObserver>`.
	private var notificationObservers = ObserverSet()
	
	func addObserver(observer: NotificationObserver) {
		notificationObservers.addObserver(observer)
	}
	
	func removeObserver(observer: NotificationObserver) {
		notificationObservers.removeObserver(observer)
	}
	
	/// Fires notification to observers.
	private func notifyObservers(notify: (NotificationObserver) -> Void) {
		notificationObservers.notifyObservers {
			notify($0 as! NotificationObserver)
		}
	}

	// MARK: - Spawning Fake Notifications

	private var newFakeNotifications = [Notification]()
	private var fakeNotificationsSpawnTimer: Timer?
	
	private func resetFakeNotificationsSpawner() {
		newFakeNotifications.removeAll()
		cancelFakeNotificationsSpawner()
		
		if NotificationManager.spawnFakeNotifications {
			Timer.scheduledTimerWithTimeInterval(0.25) {
				[weak self] in
				guard self != nil else { return }
				self!.generateFakeNotification()
			}
		}
	}
	
	private func cancelFakeNotificationsSpawner() {
		fakeNotificationsSpawnTimer?.dispose()
		fakeNotificationsSpawnTimer = nil
	}
	
	private var nextFakeNotificationID: ResourceID = 100_000
	private var nextFakeMeetRequestID:  ResourceID = 100_000
	private var nextFakeMessgeID:       ResourceID = 100_000

	/// Generate a single fake notification.
	/// We do it from JSON to improve test coverage.
	private func generateFakeNotification() {
		preconditionIsMainQueue()
		let logLabel = "Generating fake notifications"
		log("\(logLabel)...")
		
		var fakeNotification: Notification! = nil
		repeat {
			switch randomIntInRange(0...4) {
			case 0:  fakeNotification = fakeMeetRequestAt(.Sent)
			case 1:  fakeNotification = fakeMeetRequestAt(.Received)
			case 2:  fakeNotification = fakeMeetRequestAt(.Accepted)
			case 3:  fakeNotification = fakeMeetRequestAt(.Refused)
			case 4:  fakeNotification = fakeMessage()
			default: preconditionFailure("Should never happen!")
			}
		} while fakeNotification == nil
		
		newFakeNotifications.append(fakeNotification!)
		let rate = NotificationManager.fakeNotificationsSpawnRate
		fakeNotificationsSpawnTimer = Timer
			.scheduledTimerWithTimeInterval(rate) {
				[weak self] in
				guard self != nil else { return }
				assert(self!.fakeNotificationsSpawnTimer != nil)
				self!.generateFakeNotification()
		}
		log("\(logLabel)... OK (\(newFakeNotifications.count) new)")
	}

	private func fakeMeetRequestAt(action: Notification.Action) -> Notification? {
		let status: MeetRequest.Status
		switch action {
		case .Sent:
			status = .Pending // A priest can also be a penitent.
		case .Received:
			guard user.role == .Priest else { return nil }
			status = .Pending
		case .Accepted:
			status = .Accepted
		case .Refused:
			status = .Refused
		}
		
		// Fake **meet request**.
		var meetRequest = [String: JSON]()
		meetRequest["id"] = JSON(nextFakeMeetRequestID)
		meetRequest["status"] = JSON(status.rawValue)
		switch action {
		case .Sent, .Accepted, .Refused:
			meetRequest["penitent"] = JSON(["id": JSON(user.id)	])
			meetRequest["priest"] = JSON([
				"id":      123_456,
				"name":    "FakePriest",
				"surname": "Fakey"]
			)
		case .Received:
			assert(user.role == .Priest)
			meetRequest["priest"] = JSON(["id": JSON(user.id)])
			meetRequest["penitent"] = JSON([
				"id":      123_456_789,
				"name":    "FakePenitent",
				"surname": "Fakey"]
			)
		}
		nextFakeMeetRequestID  += 1
		
		// Fake **notification**.
		let notification: [String: JSON] = [
			"id":           JSON(nextFakeNotificationID),
			"unread":       true,
			"model":        "MeetRequest",
			"action":       JSON(action.rawValue),
			"meet_request": JSON(meetRequest)
		]
		nextFakeNotificationID += 1
		
		// We do a *full* JSON serialization to stress test our code.
		return jsonEncodingDecodingForNotification(JSON(notification))
	}
	
	private func fakeMessage() -> Notification {
		// Fake **message**.
		var message = [String: JSON]()
		message["id"] = JSON(nextFakeMessgeID)
		message["sender_id"] = 123_456
		message["recipient_id"] = JSON(user.id)
		message["text"] = "Hello from outer space!"
		message["created_at"] = JSON(Message.dateFormatter.stringFromDate(NSDate()))
		message["updated_at"] = JSON(Message.dateFormatter.stringFromDate(NSDate()))
		nextFakeMessgeID += 1
		
		// Fake **notification**.
		let notification: [String: JSON] = [
			"id":      JSON(nextFakeNotificationID),
			"unread":  true,
			"model":   "Message",
			"action":  "received",
			"message": JSON(message)
		]
		nextFakeNotificationID += 1
		
		// We do a *full* JSON serialization to stress test our code.
		return jsonEncodingDecodingForNotification(JSON(notification))
	}
	
	private func jsonEncodingDecodingForNotification(json: JSON) -> Notification {
		let jsonString = json.description
		let jsonEncoding = jsonString.dataUsingEncoding(
			NSUTF8StringEncoding, allowLossyConversion: false)!
		return Notification(fromJSON: JSON(data: jsonEncoding))!
	}

	private static var spawnFakeNotifications: Bool {
		let key = "Spawn Fake Notifications"
		let spawn = (App.properties[key]! as! NSNumber).boolValue
		return spawn
	}
	
	private static var fakeNotificationsSpawnRate: NSTimeInterval {
		let key = "Fake Notifications Mean Spawn Rate (seconds)"
		let spawnRate = (App.properties[key]! as! NSNumber).doubleValue
		assert(spawnRate >= 0)
		let minRate = max(spawnRate - 3, 0.1)
		let maxRate = spawnRate + 3
		return randomDoubleInRange(minRate...maxRate)
	}
	
	// MARK: - Fetching New Notifications
	
	/// Fetches new *real* and *fake* user notifications from the server.
	private func getNewNotifications(completion: Result<[Notification], NSError>
												 -> Void) {
		getAllNotifications(forUser: user) {
			[weak self] result in
			guard self != nil else { return }
			preconditionIsMainQueue()
			switch result {
			
			case .Success(let allNotifications):
				let newNotifications = self!.filterNewNotifications(
					allNotifications + self!.newFakeNotifications)
				self!.newFakeNotifications.removeAll()
				completion(.Success(newNotifications))

			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}

	private var notificationsAlreadyReturned = Set<ResourceID>()
	
	private func filterNewNotifications(all: [Notification]) -> [Notification] {
		var newNotifications = [Notification]()
		for notification in all {
			if !notificationsAlreadyReturned.contains(notification.id) {
				notificationsAlreadyReturned.insert(notification.id)
				newNotifications.append(notification)
			}
		}
		return newNotifications
	}
}

// MARK: - NotificationManager Observer Protocol

/// User model events.
protocol NotificationObserver: class, Observer {

	/// New notifications were inserted.
	func notificationManager(manager: NotificationManager,
	                         didAddNotifications notifications: [Notification])
	
	/// Old notifications were deleted.
	func notificationManager(manager: NotificationManager,
	                         didDeleteNotifications notifications: [Notification])
	
	/// New messages were received (or sent).
	func notificationManager(manager: NotificationManager,
	                         didAddMessages messages: [Message])

}

// MARK: - Utility Functions

/// Fetches all user notifications from the server.
private func getAllNotifications(forUser user: User,
								 completion: Result<[Notification], NSError> -> Void) {
	// The corresponding API is documented here:
	// https://geoconfess.herokuapp.com/apidoc/V1/notifications
	let getNotificationsURL = "\(App.serverAPI)/notifications"
	let params: [String: AnyObject] = [
		"access_token": user.oauth.accessToken
	]
	Alamofire.request(.GET, getNotificationsURL, parameters: params).responseJSON {
		response in
		switch response.result {
		case .Success(let value):
			var notifications = [Notification]()
			for notification in JSON(value).array! {
				let notification = Notification(fromJSON: notification)!
				notifications.append(notification)
			}
			completion(.Success(notifications))
		case .Failure(let error):
			completion(.Failure(error))
		}
	}
}



