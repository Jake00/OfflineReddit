//
//  InfoToolbar.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 26/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

protocol InfoToolbarStylable {
    var infoBarTintColor: UIColor { get }
    var infoBarItemsColor: UIColor { get }
    var infoBarImage: UIImage? { get }
}

class InfoToolbar: UIToolbar {
    
    let titleLabel = UILabel()
    let imageView = UIImageView()
    
    fileprivate var showingTimer: Timer?
    fileprivate var hidingConstraint: NSLayoutConstraint?
    fileprivate var showingConstraint: NSLayoutConstraint?
    fileprivate var image: UIImage? {
        didSet {
            if let image = image {
                imageView.image = image
            }
        }
    }
    
    // MARK: - Undo
    
    private(set) weak var undoButton: UIButton?
    
    var undo: (() -> Void)? {
        didSet { updateUndoButton() }
    }
    
    func updateUndoButton() {
        guard self.undoButton == nil, undo != nil else {
            self.undoButton?.removeFromSuperview()
            return
        }
        
        let undoButton = UIButton(type: .system)
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        undoButton.setTitle(SharedText.undo, for: .normal)
        undoButton.setTitleColor(.white, for: .normal)
        undoButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        undoButton.addTarget(self, action: #selector(undoButtonPressed(_:)), for: .touchUpInside)
        self.undoButton = undoButton
        addSubview(undoButton)
        NSLayoutConstraint.activate([
            undoButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            undoButton.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            undoButton.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            undoButton.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor)
            ])
    }
    
    private dynamic func undoButtonPressed(_ sender: UIButton) {
        undo?()
    }
    
    // MARK: - Style
    
    enum Style: InfoToolbarStylable {
        case success
        
        var infoBarTintColor: UIColor {
            switch self {
            case .success: return UIColor(red: 0, green: 0.55, blue: 0, alpha: 1)
            }
        }
        
        var infoBarItemsColor: UIColor {
            switch self {
            case .success: return .white
            }
        }
        
        var infoBarImage: UIImage? {
            switch self {
            case .success: return #imageLiteral(resourceName: "checked").withRenderingMode(.alwaysTemplate)
            }
        }
    }
    
    var style: InfoToolbarStylable? {
        didSet { updateStyle() }
    }
    
    private func updateStyle() {
        barTintColor = style?.infoBarTintColor
        let itemsColor = style?.infoBarItemsColor ?? .white
        titleLabel.textColor = itemsColor
        imageView.tintColor = itemsColor
        if image == nil {
            imageView.image = style?.infoBarImage
        }
    }
    
    // MARK: - Init
    
    convenience init(style: Style) {
        self.init(frame: .zero)
        self.style = style
        updateStyle()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        preservesSuperviewLayoutMargins = true
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(200, for: .horizontal)
        titleLabel.font = .systemFont(ofSize: 16, weight: UIFontWeightMedium)
        titleLabel.numberOfLines = 2
        
        addSubview(imageView)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            layoutMarginsGuide.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: -8),
            layoutMarginsGuide.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            layoutMarginsGuide.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            layoutMarginsGuide.bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            { () -> NSLayoutConstraint in
                let constraint = layoutMarginsGuide.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
                constraint.priority = 500
                return constraint
            }()])
    }
}

// MARK: - Show / hide

extension UIViewController {
    
    var infoToolbar: InfoToolbar? {
        return view.subviews
            .flatMap { $0 as? InfoToolbar }
            .first { $0.hidingConstraint?.isActive == false }
    }
    
    func showInfoToolbar(title: String, image: UIImage? = nil, style: InfoToolbar.Style = .success, duration: TimeInterval = 3, undo: (() -> Void)? = nil) {
        let infoToolbar = self.infoToolbar ?? InfoToolbar(style: style)
        infoToolbar.translatesAutoresizingMaskIntoConstraints = false
        infoToolbar.titleLabel.text = title
        infoToolbar.undo = undo.map { undo in { undo(); self.hideInfoToolbar() }}
        infoToolbar.showingTimer?.invalidate()
        infoToolbar.showingTimer = Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(hideInfoToolbar), userInfo: nil, repeats: false)
        
        guard self.infoToolbar == nil else { return }
        
        view.addSubview(infoToolbar)
        
        infoToolbar.showingConstraint = bottomLayoutGuide.topAnchor.constraint(equalTo: infoToolbar.bottomAnchor)
        let hiding = bottomLayoutGuide.bottomAnchor.constraint(equalTo: infoToolbar.topAnchor)
        infoToolbar.hidingConstraint = hiding
        
        NSLayoutConstraint.activate([
            hiding,
            view.leadingAnchor.constraint(equalTo: infoToolbar.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: infoToolbar.trailingAnchor)
            ])
        
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            hiding.isActive = false
            infoToolbar.showingConstraint?.isActive = true
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func hideInfoToolbar() {
        guard let infoToolbar = infoToolbar else { return }
        infoToolbar.showingTimer?.invalidate()
        infoToolbar.showingTimer = nil
        infoToolbar.undo = nil
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            infoToolbar.showingConstraint?.isActive = false
            infoToolbar.hidingConstraint?.isActive = true
            self.view.layoutIfNeeded()
        }, completion: { _ in
            infoToolbar.removeFromSuperview()
        })
    }
}
