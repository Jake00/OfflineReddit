//
//  DynamicTypeResponder.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 8/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

final class DynamicTypeResponder: NSObject {
    
    private var table = WeakKeyDictionary<NSObject, Style>()
    private var tableViews: [Weak<UITableView>] = []
    private let styles = UIFontTextStyle.all
    
    func style(for font: UIFont) -> UIFontTextStyle? {
        return styles.first { font == .preferredFont(forTextStyle: $0) }
    }
    
    private class Style {
        let keyPath: String
        let style: UIFontTextStyle
        let weight: UIFont.Weight?
        
        init(keyPath: String, style: UIFontTextStyle, weight: UIFont.Weight?) {
            self.keyPath = keyPath; self.style = style; self.weight = weight
        }
    }
    
    // MARK: - Shared instance
    
    static let shared = DynamicTypeResponder()
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredTextSizeChanged(_:)),
            name: .UIContentSizeCategoryDidChange,
            object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setting
    
    private dynamic func preferredTextSizeChanged(_ notification: Notification) {
        for (weak, container) in table {
            guard let view = weak.value else { continue }
            setFont(from: container, on: view)
        }
        for tableView in tableViews {
            tableView.value?.reloadData()
        }
    }
    
    private func setFont(from container: Style, on view: NSObject) {
        let font: UIFont = container.weight.map {
            .preferredFont(forTextStyle: container.style, weight: $0)
            } ?? .preferredFont(forTextStyle: container.style)
        
        view.setValue(font, forKeyPath: container.keyPath)
    }
    
    // MARK: - Watching
    
    func watch<T: DynamicTypeRespondable>(
        _ view: T,
        style: UIFontTextStyle? = nil,
        weight: UIFont.Weight? = nil
        ) where T: NSObject {
        
        guard let style = style ?? (view.value(forKeyPath: view.fontKeyPath) as? UIFont).flatMap(self.style(for:))
            else { return }
        
        let container = Style(keyPath: view.fontKeyPath, style: style, weight: weight)
        setFont(from: container, on: view)
        table[view] = container
    }
    
    func watch(_ tableView: UITableView) {
        tableViews.append(Weak(tableView))
    }
}

// MARK: - Responder viewable

protocol DynamicTypeRespondable: NSObjectProtocol {
    var fontKeyPath: String { get }
}

extension DynamicTypeRespondable where Self: NSObject {
    
    func enableDynamicType(style: UIFontTextStyle? = nil, weight: UIFont.Weight? = nil) {
        DynamicTypeResponder.shared.watch(self, style: style, weight: weight)
    }
}

extension UILabel: DynamicTypeRespondable {
    var fontKeyPath: String { return "font" }
}

extension UIButton: DynamicTypeRespondable {
    var fontKeyPath: String { return "titleLabel.font" }
}

extension UITextField: DynamicTypeRespondable {
    var fontKeyPath: String { return "font" }
}

extension UITextView: DynamicTypeRespondable {
    var fontKeyPath: String { return "font" }
}

extension UITableView {
    
    func enableDynamicTypeReloading() {
        DynamicTypeResponder.shared.watch(self)
    }
}

// MARK: - All text styles

extension UIFontTextStyle {
    
    static var all: [UIFontTextStyle] {
        return [
            .title1,
            .title2,
            .title3,
            .headline,
            .subheadline,
            .body,
            .callout,
            .footnote,
            .caption1,
            .caption2
        ]
    }
}
