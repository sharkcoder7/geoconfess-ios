//
//  Notification.swift
//  GeoConfess
//
//  Created  by Sergei Volkov on April 25, 2016.
//  Reviewed by Paulo Mattos on May 31, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

// MARK: - Notification Class

/// Encapsulates all supported notifications types.
final class Notification: RESTObject, JSONDecoding, JSONCoding, Equatable,
						  Hashable, Comparable, CustomStringConvertible {

	// MARK: Notification Properties

	/// Uniquely identifies this notification.
	let id: ResourceID
	
	/// The object embedded in this notification.
	let model: Model
	
	/// The action being reported by this notification.
	let action: Action

	var hashValue: Int {
		return Int(id)
	}
	
	enum Model: Equatable {
        case MeetRequestNotification(MeetRequest)
        case MessageNotification(Message)
    }

    enum Action: String {
		
		/// Meet request or message *sent* by user.
		case Sent = "sent"
		
		/// Meet request or message *received* by user.
		case Received = "received"
		
		/// Meet request *accepted* by priest.
		case Accepted = "accepted"
		
		/// Meet request *refused* by priest.
		case Refused = "refused"
    }

	// MARK: Creating Notifications

	/// Creates a new notification.
	init(id: ResourceID, model: Model, action: Action, unread: Bool) {
		self.id     = id
		self.model  = model
		self.action = action
		self.unread = unread
	}

	/// Parses JSON-encoded notification. See the
	/// [API documentation](https://geoconfess.herokuapp.com/apidoc/V1/notifications)
	/// for some examples.
    convenience init?(fromJSON jsonValue: JSON) {
		// We only really check core stuff -- all remaining errors will crash hard.
		guard let json       = jsonValue.dictionary   else { return nil }
		guard let id         = json["id"]?.uInt64     else { return nil }
		guard let modelName  = json["model"]?.string  else { return nil }
		guard let actionName = json["action"]?.string else { return nil }

		let model: Model
		switch modelName {
		case "MeetRequest":
			let meetRequest = MeetRequest(fromJSON: json["meet_request"]!)!
			model = .MeetRequestNotification(meetRequest)
		case "Message":
			let message = Message(fromJSON: json["message"]!)!
			model = .MessageNotification(message)
		default:
			preconditionFailure("Unexpected notification model: \(modelName)")
		}
		
		let action = Action(rawValue: actionName)!
		let unread = json["unread"]!.bool!
		self.init(id: id, model: model, action: action, unread: unread)
    }
	
	// MARK: Marking Notification as Read
	
	/// Has this notification been ready by the *user*?
	private(set) var unread: Bool
	
	func markAsRead(completion: Result<Void, NSError> -> Void) {
		// The corresponding API is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/notifications
		let markReadURL = "\(App.serverAPI)/notifications/\(id)/mark_read"
		let params: [String: AnyObject] = [
			"access_token": User.current.oauth.accessToken
		]
		unread = false
		Alamofire.request(.PUT, markReadURL, parameters: params).responseJSON {
			response in
			switch response.result {
			case .Success:
				completion(.Success())
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}
	
	// MARK: JSON Encoding and String Conversion
	
	func toJSON() -> JSON {
		var json: [String: JSON] = [
			"id":      JSON(id),
			"unread":  JSON(unread),
			"action":  JSON(action.rawValue)
		]
		switch model {
			case .MeetRequestNotification(let meetRequest):
				json["model"] = "MeetRequest"
				json["meet_request"] = meetRequest.toJSON()
			case .MessageNotification(let message):
				json["model"]   = "Message"
				json["message"] = message.toJSON()
		}
		return JSON(json)
	}
	
	var description: String {
		return "Notification: \n\(toJSON().description)"
	}
}

func ==(left: Notification, right: Notification) -> Bool {
	return left.id     == right.id      &&
		   left.unread == right.unread  &&
		   left.action == right.action  &&
		   left.model  == right.model
}

func <(left: Notification, right: Notification) -> Bool {
	return left.id < right.id
}

func ==(a: Notification.Model, b: Notification.Model) -> Bool {
	switch (a, b) {
	case (.MeetRequestNotification(let x), .MeetRequestNotification(let y)):
		return x == y
	case (.MessageNotification(let x), .MessageNotification(let y)):
		return x == y
	default:
		return false
	}
}

// MARK: - Meet Request Class

/// Meet requests between penitent and priest.
final class MeetRequest: JSONDecoding, JSONCoding,
						 Equatable, Hashable, CustomStringConvertible {
	let id: ResourceID
	let penitent: UserInfo
	let priest: UserInfo
	
	init?(fromJSON jsonValue: JSON) {
		guard let json = jsonValue.dictionary else { return nil }
		
		self.id = json["id"]!.uInt64!
		self.status = Status(rawValue: json["status"]!.string!)!
		self.penitent = UserInfo(embeddedInJSON: json, forRole: .Penitent)!
		self.priest   = UserInfo(embeddedInJSON: json, forRole: .Priest)!
	}
	
	// MARK: - Request Status

	enum Status: String {
		case Pending  = "pending"
		case Accepted = "accepted"
		case Refused  = "refused"
	}
	private(set) var status: Status

	func accept(completion: Result<Void, NSError> -> Void) {
		status = .Accepted
		reply(accept: true, completion: completion)
	}
	
	func refuse(completion: Result<Void, NSError> -> Void) {
		status = .Refused
		reply(accept: false, completion: completion)
	}
	
	private func reply(accept accept: Bool, completion: Result<Void, NSError> -> Void) {
		// The corresponding API is documented here:
		//https://geoconfess.herokuapp.com/apidoc/V1/meet_requests
		let action = accept ? "accept" : "refuse"
		let replyURL = "\(App.serverAPI)/requests/\(id)/\(action)"
		let params: [String: AnyObject] = [
			"access_token": User.current.oauth.accessToken
		]
		Alamofire.request(.PUT, replyURL, parameters: params).responseJSON {
			response in
			switch response.result {
			case .Success:
				completion(.Success())
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}

	func toJSON() -> JSON {
		let json: [String: JSON] = [
			"id":       JSON(id),
			"status":   JSON(status.rawValue),
			"penitent": penitent.toJSON(),
			"priest":   priest.toJSON()
		]
		return JSON(json)
	}
	
	var hashValue: Int {
		return Int(id)
	}
	
	var description: String {
		return "MeetRequest: \n\(toJSON())"
	}
}

func ==(left: MeetRequest, right: MeetRequest) -> Bool {
	return left.id       == right.id       &&
		   left.status   == right.status   &&
		   left.penitent == right.penitent &&
		   left.priest   == right.priest
}

extension User {
	
	/// Returns the user role *in* the specified meet request.
	///
	/// You are not expected to understand this.
	func roleAt(meetRequest: MeetRequest) -> User.Role {
		switch self.id {
		case meetRequest.penitent.id:
			return .Penitent
		case meetRequest.priest.id:
			return .Priest
		default:
			preconditionFailure("Malformed meet request")
		}
	}
}

// MARK: - Message Class

/// Message between users.
final class Message: JSONDecoding, JSONCoding, Equatable,
					 Hashable, Comparable, CustomStringConvertible {
	
	let id: ResourceID
	let createdAt: NSDate
	let updatedAt: NSDate
	
	let senderID: ResourceID
	let recipientID: ResourceID
	let text: String
	
	init?(fromJSON jsonValue: JSON) {
		// We only really check core stuff -- all remaining errors will crash hard.
		guard let json = jsonValue.dictionary else { return nil }
		guard let id   = json["id"]?.uInt64   else { return nil }
		
		self.id = id
		self.senderID = json["sender_id"]!.uInt64!
		self.recipientID = json["recipient_id"]!.uInt64!
		self.text = json["text"]!.string!
		
		let dateFormatter = Message.dateFormatter
		self.createdAt = dateFormatter.dateFromString(json["created_at"]!.string!)!
		self.updatedAt = dateFormatter.dateFromString(json["updated_at"]!.string!)!
	}
	
	func toJSON() -> JSON {
		let dateFormatter = Message.dateFormatter
		let json: [String: JSON] = [
			"id":           JSON(id),
			"sender_id":    JSON(senderID),
			"recipient_id": JSON(recipientID),
			"text":         JSON(text),
			"created_at":   JSON(dateFormatter.stringFromDate(createdAt)),
			"updated_at":   JSON(dateFormatter.stringFromDate(updatedAt))
		]
		return JSON(json)
	}
	
	var hashValue: Int {
		return Int(id)
	}
	
	var description: String {
		return toJSON().description
	}
	
	static let dateFormatter = {
		() -> NSDateFormatter in
		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
		dateFormatter.timeZone = NSTimeZone(name: "UTC")
		return dateFormatter
	}()
}

func ==(left: Message, right: Message) -> Bool {
	return left.id          == right.id          &&
		   left.senderID    == right.senderID    &&
		   left.recipientID == right.recipientID &&
		   left.text        == right.text        &&
		   left.createdAt   == right.createdAt   &&
		   left.updatedAt   == right.updatedAt
}

func <(left: Message, right: Message) -> Bool {
	return left.id < right.id
}

/*

func showNotification(id: UInt,
                      completion: (success: Bool?, error: NSError?) -> Void){
	var params = [String: AnyObject]()
	params["access_token"] = User.current.oauth.accessToken
	
	let url = App.serverAPI + "/notifications/" + "\(id)";
	
	Alamofire.request(.GET, url, parameters: params).responseJSON {
		response in
		switch response.result {
		case .Success:
			completion(success: true, error: nil)
		case .Failure(let error):
			logError("Show notification error: \(error)")
			completion(success: false, error: error)
		}
	}
}

*/