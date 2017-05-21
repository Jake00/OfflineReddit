//
//  ReusableCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

protocol ReusableCell: class {
    static var reuseIdentifier: String { get }
}

extension ReusableCell {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

protocol ReusableNibCell: ReusableCell {
    static var nib: UINib { get }
}

extension ReusableNibCell {
    static var nib: UINib {
        return UINib(nibName: reuseIdentifier, bundle: nil)
    }
}

// swiftlint:disable force_cast

extension UITableView {
    
    func registerReusableCell<T: UITableViewCell>(_: T.Type) where T: ReusableCell {
        register(T.self, forCellReuseIdentifier: T.reuseIdentifier)
    }
    
    func registerReusableNibCell<T: UITableViewCell>(_: T.Type) where T: ReusableNibCell {
        register(T.nib, forCellReuseIdentifier: T.reuseIdentifier)
    }
    
    func dequeueReusableCell<T: UITableViewCell>(for indexPath: IndexPath) -> T where T: ReusableCell {
        return self.dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as! T
    }
    
    func registerReusableHeaderFooterView<T: UITableViewHeaderFooterView>(_: T.Type) where T: ReusableCell {
        register(T.self, forHeaderFooterViewReuseIdentifier: T.reuseIdentifier)
    }
    
    func registerReusableHeaderFooterNibView<T: UITableViewHeaderFooterView>(_: T.Type) where T: ReusableNibCell {
        register(T.nib, forHeaderFooterViewReuseIdentifier: T.reuseIdentifier)
    }
    
    func dequeueReusableHeaderFooterView<T: UITableViewHeaderFooterView>() -> T? where T: ReusableCell {
        return self.dequeueReusableHeaderFooterView(withIdentifier: T.reuseIdentifier) as! T?
    }
}

extension UICollectionView {
    
    func registerReusableCell<T: UICollectionViewCell>(_: T.Type) where T: ReusableCell {
        register(T.self, forCellWithReuseIdentifier: T.reuseIdentifier)
    }
    
    func registerReusableNibCell<T: UICollectionViewCell>(_: T.Type) where T: ReusableNibCell {
        register(T.nib, forCellWithReuseIdentifier: T.reuseIdentifier)
    }
    
    func dequeueReusableCell<T: UICollectionViewCell>(for indexPath: IndexPath) -> T where T: ReusableCell {
        return self.dequeueReusableCell(withReuseIdentifier: T.reuseIdentifier, for: indexPath) as! T
    }
    
    func registerReusableSupplementaryView<T: ReusableCell>(_ elementKind: String, _: T.Type) {
        register(T.self, forSupplementaryViewOfKind: elementKind, withReuseIdentifier: T.reuseIdentifier)
    }
    
    func registerReusableSupplementaryNibView<T: ReusableNibCell>(_ elementKind: String, _: T.Type) {
        register(T.nib, forSupplementaryViewOfKind: elementKind, withReuseIdentifier: T.reuseIdentifier)
    }
    
    func dequeueReusableSupplementaryView<T: UICollectionViewCell>(_ elementKind: String, for indexPath: IndexPath) -> T where T: ReusableCell {
        return self.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: T.reuseIdentifier, for: indexPath) as! T
    }
}
