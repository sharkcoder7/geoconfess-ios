//
//  UserSignUpViewController.swift
//  GeoConfess
//
//  Created by whitesnow0827 on March 4, 2016.
//  Reviewed by Paulo Mattos on May 26, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

/// Controls the **User Sign Up** screen.
final class UserSignUpViewController: AppViewController, UITextFieldDelegate {

	@IBOutlet weak private var signUpButton: UIButton!
	
    override func viewDidLoad() {
        super.viewDidLoad()
		resignFirstResponderWithOuterTouches(
			nameTextField, surnameTextField,
			emailTextField, telephoneTextField)
		
		print("Screen height: \(UIScreen.mainScreen().bounds.height)")
    }
    
	/// Do any additional setup before showing the view.
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		surnameTextField.becomeFirstResponder()
	}
	
	// MARK: - Entering Penitent Information

	@IBOutlet weak private var surnameTextField:   UITextField!
	@IBOutlet weak private var nameTextField:      UITextField!
	@IBOutlet weak private var emailTextField:     UITextField!
	@IBOutlet weak private var telephoneTextField: UITextField!
	
	/// The text field calls this method whenever the user types a new
	/// character in the text field or deletes an existing character.
	func textField(textField: UITextField,
	               shouldChangeCharactersInRange range: NSRange,
				   replacementString replacement: String) -> Bool {
		let textBeforeChange: NSString = textField.text!
		let textAfterChange = textBeforeChange.stringByReplacingCharactersInRange(
			range, withString: replacement)

		updateUserInfoFrom(textField, with: textAfterChange)
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
		case surnameTextField:
			nameTextField.becomeFirstResponder()
		case nameTextField:
			emailTextField.becomeFirstResponder()
		case emailTextField:
			telephoneTextField.becomeFirstResponder()
		case telephoneTextField:
			telephoneTextField.resignFirstResponder()
			if signUpButton.enabled {
				signUpButtonTapped(signUpButton)
			}
		default:
			preconditionFailure("unexpected UITextField")
		}
		return true
	}
	
	@IBAction func signUpButtonTapped(button: UIButton) {
		precondition(hasAllMandatoryFields)
		guard User.isValidEmail(penitent.email) else {
			showAlert(title: "Adresse mail",
			          message: "Votre adresse email n’est pas valide!") {
				self.emailTextField.becomeFirstResponder()
			}
			return
		}
		guard penitent.telephone.isEmpty ||
			  User.isValidPhoneNumber(penitent.telephone) else {
			showAlert(title: "Téléphone",
					  message: "Numéro de téléphone invalide!") {
				self.telephoneTextField.becomeFirstResponder()
			}
			return
		}
		performSegueWithIdentifier("enterPassword", sender: self)
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		precondition(segue.identifier == "enterPassword")
		
		let passwordVC = segue.destinationViewController as! UserPasswordViewController
		passwordVC.willEnterPasswordFor(penitent)
	}
	
	// MARK: - Penitent Information
	
	private let penitent = PenitentSignUp()

	var hasAllMandatoryFields: Bool {
		return !penitent.name.isEmpty &&
			   !penitent.surname.isEmpty &&
			   !penitent.email.isEmpty
	}

	private func updateUserInfoFrom(textField: UITextField, with text: String) {
		switch textField {
		case surnameTextField:
			penitent.surname = text
		case nameTextField:
			penitent.name = text
		case emailTextField:
			penitent.email = text
		case telephoneTextField:
			penitent.telephone = text
		default:
			preconditionFailure("unexpected UITextField")
		}
	}
}

