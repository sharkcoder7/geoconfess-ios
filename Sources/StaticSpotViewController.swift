//
//  StaticSpotViewController.swift
//  GeoConfess
//
//  Created b y Christian Dimitrov on April 16, 2016.
//  Reviewed by Paulo Mattos on June 4, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

final class StaticSpotViewController: AppViewControllerWithToolbar {
	
    @IBOutlet weak private var spotNameLabel: UILabel!
    @IBOutlet weak private var spotAddressLabel: UILabel!
    @IBOutlet weak private var recurrencesLabel: UILabel!

    @IBOutlet weak private var routeButton: UIButton!
	
	private var staticSpot: Spot!
	
	static func instantiateForSpot(staticSpot: Spot) -> StaticSpotViewController {
		let storyboard = UIStoryboard(name: "MeetRequests", bundle: nil)
		let viewController = storyboard.instantiateViewControllerWithIdentifier(
			"StaticSpotViewController") as! StaticSpotViewController
		viewController.staticSpot = staticSpot
		return viewController
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		guard case .Static(let spotAddress, let spotRecurrences)
			= staticSpot.activityType else {
			preconditionFailure("Static spot expected")
		}
		
		spotNameLabel.text = staticSpot.name
		
		var address = [String]()
		if let street   = spotAddress.street   { address.append(street)	  }
		if let postCode = spotAddress.postCode { address.append(postCode) }
		if let city     = spotAddress.city     { address.append(city)     }
		spotAddressLabel.text = address.joinWithSeparator(", ")
		
		if let recurrence = spotRecurrences.first {
			recurrencesLabel.text = recurrence.displayDescription
		}
    }
    
	@IBAction func routeButtonTapped(sender: AnyObject) {
		let mapVC = self.storyboard!
			.instantiateViewControllerWithIdentifier("AppleMapVC") as! AppleMapVC
		mapVC.staticspot = staticSpot!
		navigationController!.pushViewController(mapVC, animated: true)
	}
}