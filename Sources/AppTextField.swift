//
//  CustomTextField.swift
//  GeoConfess
//
//  Created by Paulo Mattos on May 29, 2016.
//  Copyright © 2016 KTO. All rights reserved.
//

import UIKit

/// A customized `UITextField` control.
@IBDesignable
final class AppTextField: UITextField {

	private let standardTextFieldHeight = CGFloat(32)

	override func awakeFromNib() {
		super.awakeFromNib()
		setUpView()
	}
	
	override func prepareForInterfaceBuilder() {
		super.prepareForInterfaceBuilder()
		setUpView()
	}

	private var initialized = false

	private func setUpView() {
		assert(contentVerticalAlignment == .Center)
		setUpPasswordField()
		setUpDynamicBackgroundColor()
		initialized = true
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		#if TARGET_INTERFACE_BUILDER
			// This can only happens during IB updates only!
			if !initialized { return }
		#else
			assert(initialized)
			assert(bounds.height == standardTextFieldHeight)
		#endif
	}
	
	// MARK: - Drawing and Positioning Overrides
	
	private let xPadding = CGFloat(8)
	private let yPadding = CGFloat(5)
	
	override func textRectForBounds(bounds: CGRect) -> CGRect {
		let rect = CGRectInset(bounds, xPadding, yPadding)
		return rect
	}

	override func editingRectForBounds(bounds: CGRect) -> CGRect {
		return textRectForBounds(bounds)
	}
	
	/// Hack for correctly *centering* the `placeholder` text.
	/// Maybe this has something to do with our custom font (ie, *AdventPro Light*).
	override func placeholderRectForBounds(bounds: CGRect) -> CGRect {
		return textRectForBounds(bounds)
	}
	
	// MARK: - Hacks for Password Field

	@IBInspectable
	var fontHackForPasswords: Bool = false
	
	private var customFont: UIFont!
	private var passwordFieldSetUp = false
	
	override var secureTextEntry: Bool {
		didSet {
			precondition(!passwordFieldSetUp, "On the fly changes not supported yet")
		}
	}
	
	private func setUpPasswordField() {
		guard secureTextEntry else { return }
		customFont = font!
		addTarget(self, action: #selector(passwordFieldEditingChanged),
		          forControlEvents: .EditingChanged)
		addTarget(self, action: #selector(passwordFieldEditingDidBegin),
		          forControlEvents: .EditingDidBegin)
		passwordFieldSetUp = true
	}
	
	/// This hack is because secure text fields don't play well with custom fonts.
	/// Based on http://stackoverflow.com/a/21670181/819340
	@objc private func passwordFieldEditingChanged() {
		assert(secureTextEntry)
		guard fontHackForPasswords else { return }
		if text!.isEmpty {
			font = customFont
		} else {
			font = UIFont.systemFontOfSize(customFont.pointSize - 1)
		}
	}

	/// Clears password when editing begins.
	@objc private func passwordFieldEditingDidBegin() {
		assert(secureTextEntry)
		if let delegate = delegate {
			let string: NSString = text!
			let wholeString = NSRange(location: 0, length: string.length)
			let allowed = delegate.textField?(
				self, shouldChangeCharactersInRange: wholeString,
				replacementString: "")
			if allowed != nil { assert(allowed!) }
		}
		text = nil
		font = customFont
	}

	// MARK: - Colored Background
	
	@IBInspectable
	var coloredBackground: Bool = false
	
	/// The background color used when the field is active.
	private let backgroundColorWhenEditing = UIColor(red: 237/255, green: 95/255,
	                                                 blue: 83/255, alpha: 0.5)
	private var backgroundColorWhenNotEditing: UIColor!
	
	private var textColorWhenEditing = UIColor.whiteColor()
	private var textColorWhenNotEditing: UIColor!
	
	private func setUpDynamicBackgroundColor() {
		guard coloredBackground else { return }
		textColorWhenNotEditing = textColor
		backgroundColorWhenNotEditing = backgroundColor
		addTarget(self, action: #selector(textFieldEditingDidBegin),
		          forControlEvents: .EditingDidBegin)
		addTarget(self, action: #selector(textFieldEditingDidEnd),
		          forControlEvents: .EditingDidEnd)
	}
	
	@objc private func textFieldEditingDidBegin() {
		textColor = textColorWhenEditing
		backgroundColor = backgroundColorWhenEditing
		setPlaceholderColor(UIColor.whiteColor())
	}
	
	@objc private func textFieldEditingDidEnd() {
		textColor = textColorWhenNotEditing
		backgroundColor = backgroundColorWhenNotEditing
		setPlaceholderColor(UIColor.lightGrayColor())
	}
	
	private func setPlaceholderColor(color: UIColor) {
		setValue(color, forKeyPath: "_placeholderLabel.textColor")
	}

	// MARK: - Horizontal Line

	@IBInspectable
	var horizontalLine: Bool = false
	
	//var hiddenHorizontalLine = false

	override func drawRect(rect: CGRect) {
		super.drawRect(rect)
		
		guard horizontalLine && !editing else { return }
		let size = bounds.size
		let bottomLeft  = CGPoint(x: 0, y: size.height)
		let bottomRight = CGPoint(x: size.width, y: size.height)
		let horizontalLinePath = UIBezierPath()
		horizontalLinePath.moveToPoint(bottomLeft)
		horizontalLinePath.addLineToPoint(bottomRight)
		
		UIColor.lightGrayColor().setStroke()
		horizontalLinePath.stroke()
	}
}
