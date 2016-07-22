//
//  PriestPasswordViewController.swift
//  GeoConfess
//
//  Created by whitesnow0827 on 3/5/16.
//  Copyright © 2016 Andrei Costache. All rights reserved.
//

import UIKit
import AWSMobileAnalytics
import AWSCognito
import AWSS3
import AWSCore
import Photos
import MobileCoreServices
import AssetsLibrary
import Alamofire
import SwiftyJSON

final class PriestPasswordViewController: AppViewController,
	UITextFieldDelegate, UIActionSheetDelegate,
	UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak private var priestPasswordField: UITextField!
    @IBOutlet weak private var priestConfirmField: UITextField!
    @IBOutlet weak private var notificationTick: Tick!
    @IBOutlet weak private var progressView: UIProgressView!
    @IBOutlet weak private var containProgressView: UIView!
	
	@IBOutlet weak private var signUpButton: UIButton!
	
    override func viewDidLoad() {
        super.viewDidLoad()

		resignFirstResponderWithOuterTouches(priestPasswordField, priestConfirmField)
		
		view.alpha = 1.0
        containProgressView.hidden = true
		progressView.progress = 0.0
		
		// TODO: Configure authentication with Cognito.
    }
	
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        precondition(priest != nil)
        
        priestPasswordField.text = nil
        priestConfirmField.text = nil
        notificationTick.on = false
        
        signUpButton.enabled = false
        signUpButton.backgroundColor = UIButton.disabledColor
		
		// TODO: This code seems to resets the password field *after* taking a photo.
		/*
		if !takingPhoto {
			priestPasswordField.becomeFirstResponder()
		}
		*/
    }
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		takingPhoto = false
	}

    private var priest: PriestSignUp!
    
    func willEnterPasswordFor(priest: PriestSignUp) {
        self.priest = priest
    }

    @IBAction private func notificationTickChanged(sender: Tick) {
        /* empty */
    }

	
	// MARK: - UITextFieldDelegate Protocol
	
	/// Called when 'return' key pressed. return NO to ignore.
    func textFieldShouldReturn(textField: UITextField) -> Bool {
		switch textField {
        case priestPasswordField:
            priestConfirmField.becomeFirstResponder()
        case priestConfirmField:
            priestConfirmField.resignFirstResponder()
            if signUpButton.enabled {
                signUpButtonTapped(signUpButton)
            }
        default:
            preconditionFailure("Unexpected UITextField")
        }
        return true
    }
	
	/// The text field calls this method whenever the user types a new
	/// character in the text field or deletes an existing character.
	func textField(textField: UITextField,
	shouldChangeCharactersInRange range: NSRange, replacementString replacement: String)
	-> Bool {
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
		print("password: \(priestPassword)")
		print("confirm password: \(confirmPriestPassword)")
		return true
	}
	
	// MARK: - Password Information
	
	private var priestPassword: String = ""
	private var confirmPriestPassword: String = ""
	
	private func updatePasswordInfoFrom(textField: UITextField, with text: String) {
        switch textField {
        case priestPasswordField:
            priestPassword = text
        case priestConfirmField:
            confirmPriestPassword = text
        default:
            preconditionFailure("Unexpected UITextField")
        }
    }
    
	private var hasAllMandatoryFields: Bool {
		return !priestPassword.isEmpty && !confirmPriestPassword.isEmpty &&
				isPhotoUploaded
	}

    @IBAction func signUpButtonTapped(sender: AnyObject) {
		precondition(hasAllMandatoryFields)
		guard User.isValidPassword(priestPassword) else {
			showAlert(
				title: "Mot de passe",
				message: "Le mot de passe doit faire plus de 6 caractères.") {
					self.priestPasswordField.becomeFirstResponder()
			}
			return
		}
		guard priestPassword == confirmPriestPassword else {
			showAlert(
				title: "Confirmation mot de passe",
				message: "Les mots de passe doivent être identiques.") {
					self.priestConfirmField.becomeFirstResponder()
			}
			return
		}
        guard isPhotoUploaded else {
			showAlert(
				title: "Celebret",
				message: "Veuillez uploader votre celebret pour continuer.")
            return
        }
		signUpPriest()
	}
	
	private func signUpPriest() {
        priest.password = priestPassword
        priest.nearbyPriestNotification = notificationTick.on
        priest.receiveNewsletter = true
        priest.celebretURL = celebretURL
        
        showProgressHUD()
        priest.signUp(thenLogin: true) {
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
	
	// MARK: - Taking a Photo
	
	private var isPhotoUploaded: Bool = false
	private var takingPhoto: Bool = false
	private var imagePicker: UIImagePickerController!
	private var image: UIImage = UIImage()
	private var celebretURL: NSURL = NSURL()
	
	private var uploadCompletionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
	private var uploadFileURL: NSURL?
	
	private var filesize: Int64 = 0
	private var amountUploaded: Int64 = 0
	
	@IBAction func cameraButtonTapped(sender: UIButton) {
		takingPhoto = true
		print("password: \(priestPassword)")
		print("confirm password: \(confirmPriestPassword)")
		let actionSheet = UIActionSheet(
			title: "Souhaitez-vous  :",
			delegate: self,
			cancelButtonTitle: "Cancel",
			destructiveButtonTitle: nil,
			otherButtonTitles: "Prendre une photo", "Choisir dans la galerie")
		actionSheet.showInView(view)
	}
	
	func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
		switch buttonIndex {
		case 1:
			takeAPhoto()
		case 2:
			selectedPhotoFromGallery()
		default:
			break
		}
	}
	
	private func selectedPhotoFromGallery() {
		imagePicker =  UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.allowsEditing = true
		imagePicker.sourceType = .PhotoLibrary
		
		presentViewController(imagePicker, animated: true, completion: nil)
	}

	private func takeAPhoto() {
		guard UIImagePickerController.isSourceTypeAvailable(.Camera) else {
			showAlert(title: "Erreur", message: "L'appareil photo est indisponible!")
			return
		}
		imagePicker =  UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.allowsEditing = true
		imagePicker.sourceType = .Camera
		presentViewController(imagePicker, animated: true, completion: nil)
	}
	
	private func update() {
		let percentageUploaded = Float(amountUploaded) / Float(filesize) * 100
		
		print(NSString(format:"Chargement: %.0f%%", percentageUploaded) as String)
		
		let progress = Float(amountUploaded) / Float(filesize)
		containProgressView.hidden = false
		view.userInteractionEnabled = false
		view.alpha = 0.7
		progressView.progress = progress
		print("Progress is: %f",progress)
	}
	
	func imagePickerControllerDidCancel(picker: UIImagePickerController) {
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	func imagePickerController(picker: UIImagePickerController,
	                           didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		let image = info[UIImagePickerControllerOriginalImage] as! UIImage
		let imageData = UIImageJPEGRepresentation(image, 0.1)
		
		print("password: \(priestPassword)")
		print("confirm password: \(confirmPriestPassword)")
		
		
		let path = (NSTemporaryDirectory() as NSString)
			.stringByAppendingPathComponent("image.jpg")
		imageData!.writeToFile(path as String, atomically: true)
		
		let url = NSURL(fileURLWithPath: path as String)
		
		let uploadRequest = AWSS3TransferManagerUploadRequest()
		uploadRequest.bucket = "geoconfessapp"
		uploadRequest.ACL = AWSS3ObjectCannedACL.PublicRead
		
		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "dd_MM_yyyy_hh_mm_ss"
		let strKey = "\(dateFormatter.stringFromDate(NSDate())).jpg"
		
		uploadRequest.key = strKey
		uploadRequest.contentType = "image/jpeg"
		uploadRequest.body = url;
		uploadRequest.uploadProgress = {
			[unowned self]
			(bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) in
			dispatch_sync(dispatch_get_main_queue(), {
				() -> Void in
				self.amountUploaded = totalBytesSent
				self.filesize = totalBytesExpectedToSend
				self.update()
			})
		}
		
		let transferManager = AWSS3TransferManager.defaultS3TransferManager()
		let upload = transferManager.upload(uploadRequest)
		upload.continueWithExecutor(AWSExecutor.mainThreadExecutor(), withBlock: {
			[unowned self]
			task -> AnyObject in
			if task.error != nil {
				logError("Upload error: \(task.error)")
			} else {
				self.containProgressView.hidden = true
				self.view.userInteractionEnabled = true
				self.view.alpha = 1.0
				self.celebretURL = NSURL(string:
					"https://geoconfessapp.s3.amazonaws.com/\(strKey)")!
				log("Uploading photo to: \(self.celebretURL)")
				self.isPhotoUploaded = true
				
				if self.hasAllMandatoryFields {
					self.signUpButton.enabled = true
					self.signUpButton.backgroundColor = UIButton.enabledColor
				} else {
					self.signUpButton.enabled = false
					self.signUpButton.backgroundColor = UIButton.disabledColor
				}
			}
			return "all done"
			}
		)
		
		// End if photo library upload.
		dismissViewControllerAnimated(true, completion: nil)
	}
}
