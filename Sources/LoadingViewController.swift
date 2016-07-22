//
//  LoadingViewController.swift
//  GeoConfess
//
//  Created  by Sergei Volkov on February 2, 2016.
//  Reviewed by Paulo Mattos on June 4, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// Controls the **loading** screen.
final class LoadingViewController: UIViewController {

    @IBOutlet weak private var loadingProgress: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

		loadingProgress.hidden = false
        loadingProgress.hidesWhenStopped = true
        loadingProgress.startAnimating()
    }
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
	
		// Logins the last successfully logged in user.
		let defaults = NSUserDefaults.standardUserDefaults()
		if let username = defaults.stringForKey(User.lastUserKey),
			let password = defaults.stringForKey(User.lastUserPasswordKey) {
			
			User.loginInBackground(username: username, password: password) {
				result in
				self.loadingProgress.stopAnimating()
				switch result {
				case .Failure:
					self.performSegueWithIdentifier("login", sender: self)
				case .Success:
					self.performSegueWithIdentifier("autoLogin", sender: self)
				}
			}
		} else {
			Timer.scheduledTimerWithTimeInterval(3.5) {
				self.loadingProgress.stopAnimating()
				self.performSegueWithIdentifier("login", sender: self)
			}
		}
    }
}

