//
//  ChatViewController.swift
//  GeoConfess
//
//  Created  by Sergei Volkov on May 5, 2016.
//  Reviewed by Paulo Mattos on June 5, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit
import JSQMessagesViewController

/// Controls the main chat view.
///
/// This is a *embedded* view controller, so events
/// `viewWillAppear` and `viewWillDisappear` will not be fired.
final class ChatViewController: JSQMessagesViewController,
								JSQMessagesComposerTextViewPasteDelegate,
								NotificationObserver,
						  		UINavigationControllerDelegate,
						  		UIImagePickerControllerDelegate {
	
	private var localUser: User!
	private var remoteUser: UserInfo!
	
	func chatWithUser(recipient: UserInfo) {
		precondition(view != nil)
		
		localUser  = User.current!
		remoteUser = recipient

		// Required for JSQMessagesCollectionViewDataSource protocol.
		senderId = "\(localUser.id)"
		senderDisplayName = localUser.name
		
		localUser.notificationManager.addObserver(self)
		reloadMessages()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.backgroundColor = UIColor.clearColor()
		showTypingIndicator = false
		collectionView.backgroundColor = UIColor.clearColor()
		collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero
		collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero
		
		let toolbar = inputToolbar.contentView
		let cameraImage = UIImage(named: "Button_Camera_Capture")!
		toolbar.leftBarButtonItem.setImage(cameraImage, forState: .Normal)
		toolbar.leftBarButtonItem.setImage(cameraImage, forState: .Highlighted)
		toolbar.leftBarButtonItemWidth = 30
		toolbar.rightBarButtonItem.setTitle("Envoyer", forState: .Normal)
		toolbar.rightBarButtonItem.setTitle("Envoyer", forState: .Highlighted)
		toolbar.rightBarButtonItemWidth = 64
	}

	override func didMoveToParentViewController(parent: UIViewController?) {
		super.didMoveToParentViewController(parent)
		// Closing view controller?
		if parent == nil {
			localUser.notificationManager.removeObserver(self)
		}
	}
	
    // MARK: - Messages Data Model
	
	/// This is the UI level messages model.
	private var messages = [JSQMessage]()

	func notificationManager(manager: NotificationManager,
	                         didAddMessages newMessages: [Message]) {
		for message in newMessages {
			if message.senderID == remoteUser.id {
				precondition(message.recipientID == localUser.id)
				messages.append(JSQMessage(fromSenderOf: message))
			}
		}
		collectionView.reloadData()
	}

	func notificationManager(manager: NotificationManager,
	                         didAddNotifications notifications: [Notification]) {
		/* empty */
	}
	
	func notificationManager(manager: NotificationManager,
	                         didDeleteNotifications notifications: [Notification]) {
		// This might be a data model fresh, so is better to reload all messages.
		reloadMessages()
	}
	
	private func reloadMessages() {
		messages.removeAll()
		for message in localUser.notificationManager.messages {
			if message.senderID == localUser.id && message.recipientID == remoteUser.id {
				messages.append(JSQMessage(fromSenderOf: message))
			}
			if message.senderID == remoteUser.id && message.recipientID == localUser.id {
				messages.append(JSQMessage(fromSenderOf: message))
			}
		}
		collectionView.reloadData()
	}

    override func collectionView(
		collectionView: UICollectionView,
		numberOfItemsInSection section: Int) -> Int {
		return messages.count
    }
    
	override func collectionView(
		collectionView: JSQMessagesCollectionView!,
		messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
		return messages[indexPath.item]
	}
	
    override func collectionView(
		collectionView: UICollectionView,
		cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(
			collectionView, cellForItemAtIndexPath: indexPath)
			as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        if message.senderID == localUser.id {
            cell.textView.textColor = UIColor.whiteColor()
        } else {
            cell.textView.textColor = UIColor.blackColor()
        }
        return cell
    }
	
    override func collectionView(
		collectionView: JSQMessagesCollectionView!,
		didDeleteMessageAtIndexPath indexPath: NSIndexPath!) {
        messages.removeAtIndex(indexPath.item)
    }
    
    override func collectionView(
		collectionView: JSQMessagesCollectionView!,
		messageBubbleImageDataForItemAtIndexPath
		indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        
        if message.senderID == localUser.id {
            return bubbleFactory.outgoingMessagesBubbleImageWithColor(
				UIColor(red: 237/255, green: 95/255, blue: 103/255, alpha: 1.0))
        } else {
            return bubbleFactory.incomingMessagesBubbleImageWithColor(
				UIColor.lightGrayColor())
        }
    }
    
    override func collectionView(
		collectionView: JSQMessagesCollectionView!,
		avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!)
		-> JSQMessageAvatarImageDataSource! {
        /**
         *  Return your previously created avatar image data objects.
         *
         *  Note: these the avatars will be sized according to these values:
         *
         *  self.collectionView.collectionViewLayout.incomingAvatarViewSize
         *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize
         *
         *  Override the defaults in `viewDidLoad`
         */
        return nil
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 didTapCellAtIndexPath indexPath: NSIndexPath!,
								 touchLocation: CGPoint) {
        print("TODO: Need to do some translation heaya!")
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!,
                                 header headerView: JSQMessagesLoadEarlierHeaderView!,
								 didTapLoadEarlierMessagesButton sender: UIButton!) {
        print("TODO: need to load earlier messages")
    }
	
	// MARK: - Sending Text Messages
	
	override func didPressSendButton(button: UIButton!, withMessageText text: String!,
	                                 senderId: String!, senderDisplayName: String!,
	                                 date: NSDate!) {
		/**
		*  Sending a message. Your implementation of
		*  this method should do *at least* the following:
		*
		*  1. Play sound (optional)
		*  2. Add new id<JSQMessageData> object to your data source
		*  3. Call `finishSendingMessage`
		*/
		sendTextMessage(text, fromMe: true, date: date!, playSound: true)
	}
	
	private func sendTextMessage(text: String, fromMe: Bool,
	                             date: NSDate, playSound: Bool) {
		localUser.notificationManager.sendMessageTo(remoteUser.id, text: text) {
			result in
			switch result {
			case .Success:
				break
			case .Failure(let error):
				logError("sendTextMessage failed: \(error)")
			}
		}
		let userID   = fromMe ? localUser.id   : remoteUser.id
		let userName = fromMe ? localUser.name : remoteUser.name
		let message = JSQMessage(senderID: userID, senderName: userName,
		                         date: date, text: text)
		messages.append(message)
		
		if playSound {
			JSQSystemSoundPlayer.jsq_playMessageSentSound()
		}
		finishSendingMessageAnimated(true)
		receiveFakeReply()
	}
	
	func composerTextView(textView: JSQMessagesComposerTextView!,
	                      shouldPasteWithSender sender: AnyObject!) -> Bool {
		guard let image = UIPasteboard.generalPasteboard().image else { return true }
		
		let imageMedia = JSQPhotoMediaItem(image: image)
		let message = JSQMessage(senderID: localUser.id, senderName: localUser.name,
		                         date: NSDate(), media: imageMedia)
		messages.append(message)
		finishSendingMessage()
		return false
	}
	
	// MARK: - Sending Images

	private var imagePicker: UIImagePickerController!
	
	/// This is where we prompt for a multimedia message (audio, video, or location).
	override func didPressAccessoryButton(sender: UIButton!) {
		inputToolbar.contentView.textView?.resignFirstResponder()
		
		imagePicker = UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.sourceType = .PhotoLibrary
		
		presentViewController(imagePicker, animated: true, completion: nil)
	}
	
	func imagePickerController(
		picker: UIImagePickerController,
		didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		if picker.sourceType == UIImagePickerControllerSourceType.PhotoLibrary {
			let image = info[UIImagePickerControllerOriginalImage] as! UIImage
			sendImage(image, fromMe: true, playSound: true)
			dismissViewControllerAnimated(true, completion: nil);
		}
	}
	
	private func sendImage(image: UIImage, fromMe: Bool, playSound: Bool) {
		let userID   = fromMe ? localUser.id   : remoteUser.id
		let userName = fromMe ? localUser.name : remoteUser.name
		
		let photoItem = JSQPhotoMediaItem(image: image)
		photoItem.appliesMediaViewMaskAsOutgoing = fromMe
		let photoMessage = JSQMessage(
			senderID: 	userID,
			senderName: userName,
			date: 		NSDate(),
			media: 		photoItem)
		
		if playSound {
			JSQSystemSoundPlayer.jsq_playMessageSentSound()
		}
		messages.append(photoMessage)
		finishSendingMessageAnimated(true)
		receiveFakeReply()
	}
	
	// MARK: - Messages Refresh
	
	private var refreshControl: UIRefreshControl!
	
	private func addRefreshControl() {
		refreshControl = UIRefreshControl()
		refreshControl.attributedTitle =
			NSAttributedString(string: "Chargement des messages récents...")
		refreshControl.addTarget(
			self, action: #selector(self.loadEarlierMessages),
			forControlEvents: UIControlEvents.ValueChanged)
		collectionView.addSubview(refreshControl!)
	}
	
	@objc private func loadEarlierMessages() {
		refreshControl!.endRefreshing()
	}
	
	// MARK: - Testing Mode
	
	private func receiveFakeReply() {
		guard ChatViewController.chatBotEnabled else { return }
		
		showTypingIndicator = !showTypingIndicator
		scrollToBottomAnimated(true)
		runAfterDelay(1.5) {
			JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
			let newMessage = JSQMessage(
				senderID:	self.remoteUser.id,
				senderName:	self.remoteUser.name,
				date:		NSDate(),
				text: 		"I am here")
			self.messages.append(newMessage)
			self.finishReceivingMessageAnimated(true)
		}
	}
	
	private static var chatBotEnabled: Bool {
		let key = "Simple Chat Bot Enabled"
		let chatbot = (App.properties[key]! as! NSNumber).boolValue
		return chatbot
	}
}

// MARK: - JSQMessage Extensions

extension JSQMessage {
	
	convenience init(senderID: ResourceID, senderName: String,
	                 date: NSDate, text: String) {
		self.init(senderId: String(senderID), senderDisplayName: senderName,
		          date: date, text: text)
	}

	convenience init(senderID: ResourceID, senderName: String,
	                 date: NSDate, media: JSQMessageMediaData) {
		self.init(senderId: String(senderID), senderDisplayName: senderName,
		          date: date, media: media)
	}

	convenience init(fromSenderOf message: Message) {
		let senderId = message.senderID
		let name = "User_\(message.senderID)"
		self.init(senderID: senderId, senderName: name,
		          date: message.createdAt, text: message.text)
	}

	convenience init(fromRecipientOf message: Message) {
		let senderId = message.recipientID
		let name = "User_\(message.recipientID)"
		self.init(senderID: senderId, senderName: name,
		          date: message.createdAt, text: message.text)
	}
	
	var senderID: ResourceID {
		return ResourceID(senderId)!
	}
}
