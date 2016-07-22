//
//  UserSignUp.swift
//  GeoConfess
//
//  Created by Paulo Mattos on May 26, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

// MARK: - UserSignUp Class

/// Common sign up information for *petinents* and *priests*.
class UserSignUp {
	
	var name: String = ""
	var surname: String = ""
	var email: String = ""
	var telephone: String = ""

	var password: String = ""
	var nearbyPriestNotification: Bool!
	var receiveNewsletter: Bool!
	
	private let role: User.Role
	
	init(role: User.Role) {
		self.role = role
	}
	
	private var hasAllMandatoryFields: Bool {
		return !name.isEmpty && !surname.isEmpty && !email.isEmpty && !password.isEmpty
	}
	
	func signUp(thenLogin doLogin: Bool, completion: (Result<Void, NSError>) -> Void) {
		precondition(hasAllMandatoryFields)
		precondition(User.isValidEmail(email))
		precondition(telephone.isEmpty || User.isValidPhoneNumber(telephone))
		
		// This API endpoint is documented here:
		// https://geoconfess.herokuapp.com/apidoc/V1/registrations/create.html
		let URL = NSURL(string: "\(App.serverAPI)/registrations")
		Alamofire.request(.POST, URL!, parameters: paramsForSignUp()).responseJSON {
			response in
			switch response.result {
			case .Success(let data):
				let json = JSON(data).dictionary!
				guard json["result"]?.string == "success" else {
					let errors = json["errors"]!.dictionary!
					if let error = errors["email"] {
						logError("Email: \(error)\n")
					}
					if let error = errors["password"] {
						logError("Password: \(error)\n")
					}
					if let error = errors["phone"] {
						logError("Phone: \(error)\n")
					}
					completion(.Failure(NSError(code: .InternalServerError)))
					return
				}
				if doLogin {
					self.loginUser(completion)
				} else {
					completion(.Success())
				}
			case .Failure(let error):
				logError("Sign up: \(error)")
				completion(.Failure(NSError(code: .InternetConnectivityError)))
			}
		}
	}
	
	private func loginUser(completion: (Result<Void, NSError>) -> Void) {
		User.loginInBackground(username: email, password: password) {
			result in
			switch result {
			case .Success:
				completion(.Success())
			case .Failure(let error):
				completion(.Failure(error))
			}
		}
	}
	
	private func paramsForSignUp() -> [String: AnyObject] {
		let user = [
			"role"         : role.rawValue,
			"email"        : email,
			"password"     : password,
			"name"         : name,
			"surname"      : surname,
			"phone"        : telephone,
			"notification" : "\(nearbyPriestNotification!)",
			"newsletter"   : "\(receiveNewsletter!)"
		]
		return ["user" : user]
	}
}

// MARK: - PenitentSignUp Class

/// Penitent sign up information.
final class PenitentSignUp: UserSignUp {

	init() {
		super.init(role: .Penitent)
	}
}

// MARK: - PriestSignUp Class

/// Priest sign up information.
final class PriestSignUp: UserSignUp {
	
	var celebretURL: NSURL! = nil

	init() {
		super.init(role: .Priest)
	}
	
	override var hasAllMandatoryFields: Bool {
		return super.hasAllMandatoryFields && celebretURL != nil
	}
	
	private override func paramsForSignUp() -> [String : AnyObject] {
		guard let celebretURL = celebretURL else { preconditionFailure() }
		
		var params = super.paramsForSignUp()
		var user = params["user"] as! [String : String]
		user["celebret_url"] = String(celebretURL)
		params["user"] = user
		return params
	}
}
