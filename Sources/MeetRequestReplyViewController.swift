//
//  MeetRequestReplyViewController.swift
//  GeoConfess
//
//  Created by Paulo Mattos on June 4, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import Foundation

final class MeetRequestReplyViewController: AppViewControllerWithToolbar {
	
	@IBOutlet weak private var penitentLabel: UILabel!
	
	@IBOutlet weak private var acceptButton: UIButton!
	@IBOutlet weak private var refuseButton: UIButton!
	
	private var meetRequest: MeetRequest!
	
	func replyToMeetRequest(meetRequest: MeetRequest) {
		self.meetRequest = meetRequest
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		penitentLabel.text = meetRequest.penitent.name
	}
	
	@IBAction func acceptButtonTapped(sender: UIButton) {
		assert(sender === acceptButton)
		meetRequest.accept {
			result in
			self.navigationController.popViewControllerAnimated(true)
		}
	}

	@IBAction func refuseButtonTapped(sender: UIButton) {
		assert(sender === refuseButton)
		meetRequest.refuse {
			result in
			self.navigationController.popViewControllerAnimated(true)
		}
	}
}