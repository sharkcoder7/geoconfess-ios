//
//  PriestSignUpViewController.swift
//  GeoConfess
//
//  Created  by whitesnow0827 on March 5, 2016.
//  Reviewed by Paulo Mattos on May 26, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Controls the **Priest Sign Up** screen.
final class PriestSignUpViewController: AppViewController,
	UITextFieldDelegate, UIScrollViewDelegate {

	@IBOutlet weak private var scrollview: UIScrollView!
	@IBOutlet weak private var signUpButton: UIButton!
	
	/// Do any additional setup after loading the view.
    override func viewDidLoad() {
        super.viewDidLoad()
		
		resignFirstResponderWithOuterTouches(
			nameTextField, surnameTextField,
			emailTextField, telephoneTextField
		)

		scrollview.contentSize.height = 1000
		scrollview.scrollEnabled = true
		scrollview.delegate = self
    }

    /// Do any additional setup before showing the view.
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        surnameTextField.becomeFirstResponder()
    }
    
	// MARK: - Entering Priest Information
	
	@IBOutlet private weak var nameTextField: UITextField!
	@IBOutlet private weak var surnameTextField: UITextField!
	@IBOutlet private weak var emailTextField: UITextField!
	@IBOutlet private weak var telephoneTextField: UITextField!

	/// character in the text field or deletes an existing character.
	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange,
	               replacementString replacement: String) -> Bool {
		let textBeforeChange: NSString = textField.text!
		let textAfterChange = textBeforeChange.stringByReplacingCharactersInRange(
			range, withString: replacement)
			
		updatePriestInfoFrom(textField, with: textAfterChange)
		if hasAllMandatoryFields {
			signUpButton.enabled = true
			signUpButton.backgroundColor = UIButton.enabledColor
		} else {
			signUpButton.enabled = false
			signUpButton.backgroundColor = UIButton.disabledColor
		}
		
		return true
	}
	
	/// Called when 'return' key pressed. Return NO to ignore.
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
                priestSignUpButtonTapped(signUpButton)
            }
        default:
            preconditionFailure("unexpected UITextField")
        }
        return true
    }
	
    private let priest = PriestSignUp()

	private func updatePriestInfoFrom(textField: UITextField, with text: String) {
        switch textField {
        case nameTextField:
            priest.name = text
        case surnameTextField:
            priest.surname = text
        case emailTextField:
            priest.email = text
        case telephoneTextField:
            priest.telephone = text
        default:
            preconditionFailure("unexpected UITextField")
        }
    }

	private var hasAllMandatoryFields: Bool {
		return !priest.name.isEmpty && !priest.surname.isEmpty && !priest.email.isEmpty
	}
	
    @IBAction func priestSignUpButtonTapped(sender: UIButton) {
		precondition(hasAllMandatoryFields)
		guard User.isValidEmail(priest.email) else {
			showAlert(title: "Adresse mail",
			          message: "Votre adresse email n’est pas valide!") {
				self.emailTextField.becomeFirstResponder()
			}
			return
		}
		guard priest.telephone.isEmpty ||
			  User.isValidPhoneNumber(priest.telephone) else {
			showAlert(title: "Téléphone",
			          message: "Numéro de téléphone invalide!") {
				self.telephoneTextField.becomeFirstResponder()
			}
			return
		}

		self.performSegueWithIdentifier("enterPassword", sender: self)
    }
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		precondition(segue.identifier == "enterPassword")
        
        let passwordVC = segue.destinationViewController as! PriestPasswordViewController
        passwordVC.willEnterPasswordFor(priest)
	}
}
