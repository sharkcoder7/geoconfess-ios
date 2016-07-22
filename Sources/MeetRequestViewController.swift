//
//  MeetRequestViewController.swift
//  GeoConfess
//
//  Created  by Christian Dimitrov on April 15, 2016.
//  Reviewed by Paulo Mattos on May 5, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

final class MeetRequestViewController: AppViewControllerWithToolbar {
	
    @IBOutlet weak private var priestNameLabel: UILabel!
    @IBOutlet weak private var priestDistanceLabel: UILabel!
    @IBOutlet weak private var sendButton: UIButton!
    @IBOutlet weak private var favoriteButton: UIButton!
	
	private let sendImage    = UIImage(named: "Envoyer Une Demande Button")!
	private let pendingImage = UIImage(named: "Demande Déjà Envoyée Button")!
	private let refusedImage = UIImage(named: "Demande Refusée Button")!
	
	private var priest: UserInfo!
	
	static func instantiateForPriest(priest: UserInfo) -> MeetRequestViewController {
		let storyboard = UIStoryboard(name: "MeetRequests", bundle: nil)
		let viewController = storyboard.instantiateViewControllerWithIdentifier(
			"MeetRequestViewController") as! MeetRequestViewController
		viewController.priest = priest
		return viewController
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		/* empty */
    }
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		let sendButtonImage: UIImage
		let user = User.current!
		let priestID = priest.id
		if let meetRequest = user.notificationManager.meetRequestForPriest(priestID) {
			sendButton.enabled = false
			switch meetRequest.status {
			case .Pending, .Accepted:
				sendButtonImage = pendingImage
			case .Refused:
				sendButtonImage = refusedImage
			}
		} else {
			sendButton.enabled = true
			sendButtonImage = sendImage
		}
		
		sendButton.setImage(sendButtonImage, forState: .Normal)
		priestNameLabel.text = priest.surname
		priestDistanceLabel.text = String(format: "à %.0f mètres", calculateDistance())
	}
	
    /// Calculates distance from user to priest.
    func calculateDistance() -> CLLocationDistance {
		guard let priestLocation = priest.location else { return 0 }
        let userLocation = User.current.location!
		return userLocation.distanceFromLocation(CLLocation(at: priestLocation))
    }
    
    /// Send request to a priest.
    @IBAction func sendRequest(sender: UIButton) {
		let user = User.current!
		let priestID = priest.id
		assert(user.notificationManager.meetRequestForPriest(priestID) == nil)
		showProgressHUD()
		user.notificationManager.sendMeetRequestTo(priestID) {
			result in
			self.dismissProgressHUD()
			switch result {
			case .Success(let meetRequest):
				self.sendButton.enabled = false
				self.sendButton.setImage(self.pendingImage, forState: .Normal)
				print("\(meetRequest)")
			case .Failure(let error):
				self.showAlertForNetworkError(error)
			}
		}
    }
}
