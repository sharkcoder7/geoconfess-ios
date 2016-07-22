//
//  UserPasswordViewController.swift
//  GeoConfess
//
//  Created by whitesnow0827 on March 4, 2016.
//  Reviewed by Paulo Mattos on May 26, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Controls the **User Password** screen.
final class UserPasswordViewController: AppViewController, UITextFieldDelegate {

	override func viewDidLoad() {
		super.viewDidLoad()
		resignFirstResponderWithOuterTouches(
			passwordTextField, passwordConfirmationTextField)
	}
	
	/// Do any additional setup before showing the view.
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		precondition(penitent != nil)

		passwordTextField.text = nil
		passwordConfirmationTextField.text = nil
		notificationTick.on = false
		
		signUpButton.enabled = false
		signUpButton.backgroundColor = UIButton.disabledColor
		
		passwordTextField.becomeFirstResponder()
	}

	private var penitent: PenitentSignUp!
	
	func willEnterPasswordFor(penitent: PenitentSignUp) {
		self.penitent = penitent
	}

	// MARK: - Entering Passwords

	@IBOutlet weak private var passwordTextField: UITextField!
	@IBOutlet weak private var passwordConfirmationTextField: UITextField!
	@IBOutlet weak private var notificationTick: Tick!
	@IBOutlet weak private var signUpButton: UIButton!
	
	/// The text field calls this method whenever the user types a new
	/// character in the text field or deletes an existing character.
	func textField(textField: UITextField,
	               shouldChangeCharactersInRange range: NSRange,
				   replacementString replacement: String) -> Bool {
		let textBeforeChange: NSString = textField.text!
		let textAfterChange = textBeforeChange.stringByReplacingCharactersInRange(
			range, withString: replacement)
		
		updatePasswordInfoFrom(textField, with: textAfterChange)
		if hasAllMandatoryFields {
			signUpButton.enabled = true
			signUpButton.backgroundColor = UIButton.enabledColor
		} else {
			signUpButton.enabled = false
			signUpButton.backgroundColor = UIButton.disabledColor
		}
		return true
	}

	/// Called when *return key* pressed. Return false to ignore.
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		switch textField {
		case passwordTextField:
			passwordConfirmationTextField.becomeFirstResponder()
		case passwordConfirmationTextField:
			passwordConfirmationTextField.resignFirstResponder()
			if signUpButton.enabled {
				signUpButtonTapped(signUpButton)
			}
		default:
			preconditionFailure("Unexpected UITextField")
		}
		return true
	}
	
	// MARK: - Password Information

	private var penitentPassword: String = ""
	private var confirmPenitentPassword: String = ""
	
	private func updatePasswordInfoFrom(textField: UITextField, with text: String) {
		switch textField {
		case passwordTextField:
			penitentPassword = text
		case passwordConfirmationTextField:
			confirmPenitentPassword = text
		default:
			preconditionFailure("Unexpected UITextField")
		}
	}
	
	private var hasAllMandatoryFields: Bool {
		return !penitentPassword.isEmpty && !confirmPenitentPassword.isEmpty
	}
	
	@IBAction private func notificationTickChanged(sender: Tick) {
		/* empty */
	}

	// MARK: - Sign Up Workflow

	@IBAction func signUpButtonTapped(sender: UIButton) {
		precondition(hasAllMandatoryFields)
		guard User.isValidPassword(penitentPassword) else {
			showAlert(
				title: "Mot de passe",
				message: "Le mot de passe doit faire plus de 6 caractères.") {
					self.passwordTextField.becomeFirstResponder()
			}
			return
		}
		guard penitentPassword == confirmPenitentPassword else {
			showAlert(
				title: "Confirmation mot de passe",
				message: "Les mots de passe doivent être identiques.") {
					self.passwordConfirmationTextField.becomeFirstResponder()
			}
			return
		}
		signUpUser()
	}
	
	private func signUpUser() {
		penitent.password = penitentPassword
		penitent.nearbyPriestNotification = notificationTick.on
		penitent.receiveNewsletter = false
		
		showProgressHUD()
		penitent.signUp(thenLogin: true) {
			result in
			self.dismissProgressHUD()
			switch result {
			case .Success:
				self.performSegueWithIdentifier("enterApp", sender: self)
			case .Failure(let error):
				self.showAlert(message: error.localizedDescription)
			}
		}
	}
}
