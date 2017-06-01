//
//  LabelSliderControl.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 28/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

protocol LabelSliderDisplayable {
    var displayName: String { get }
}

class LabelSliderControl: UIControl {
    
    let slider = UISlider()
    let label = UILabel()
    let verticalPadding: CGFloat = 6
    
    var discreteValues: [LabelSliderDisplayable] = [] {
        didSet {
            label.text = discreteValues.isEmpty ? nil : discreteValues[nearestIndex].displayName
        }
    }
    
    var isDiscrete = true {
        didSet { updateSliderTrack() }
    }
    
    private(set) var labelX: NSLayoutConstraint!
    private var currentTitleIndex = 0
    private var sliderBounds: CGFloat = 0
    
    var steps: Int {
        return discreteValues.count - 1
    }
    
    var nearestIndex: Int {
        let nearest = slider.value * Float(steps)
        return Int(nearest.rounded())
    }
    
    var nearestSliderValue: Float {
        return Float(nearestIndex) / Float(steps)
    }
    
    var selectedDiscreteValue: LabelSliderDisplayable? {
        get {
            let index = nearestIndex
            return isDiscrete && index < discreteValues.endIndex ? discreteValues[index] : nil
        } set {
            guard let newValue = newValue,
                let index = discreteValues.index(where: { $0.displayName == newValue.displayName })
                else { slider.value = 0; return }
            currentTitleIndex = index
            slider.value = Float(index) / Float(steps)
            updateLabelPosition()
        }
    }
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        labelX = label.centerXAnchor.constraint(equalTo: slider.leadingAnchor)
        labelX.priority = 500
        isOpaque = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .offBlack
        label.font = .systemFont(ofSize: 14)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        addSubview(slider)
        addSubview(label)
        
        NSLayoutConstraint.activate([
            layoutMarginsGuide.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            layoutMarginsGuide.trailingAnchor.constraint(equalTo: slider.trailingAnchor),
            layoutMarginsGuide.bottomAnchor.constraint(equalTo: slider.bottomAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor),
            layoutMarginsGuide.trailingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor),
            layoutMarginsGuide.topAnchor.constraint(equalTo: label.topAnchor),
            label.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: verticalPadding),
            labelX
            ])
        
        updateSliderTrack()
    }
    
    // MARK: - View
    
    override var intrinsicContentSize: CGSize {
        return CGSize(
            width: UIViewNoIntrinsicMetric,
            height: slider.intrinsicContentSize.height + label.intrinsicContentSize.height + verticalPadding)
    }
    
    override func draw(_ rect: CGRect) {
        guard isDiscrete, !discreteValues.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        let height: CGFloat = 8
        let y = slider.frame.midY
        let minX = sliderThumbRect(value: 0).midX
        let maxX = sliderThumbRect(value: 1).midX
        
        context.move(to: CGPoint(x: minX, y: y))
        context.addLine(to: CGPoint(x: maxX, y: y))
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.strokePath()
        
        for step in (0...steps) {
            let x = sliderThumbRect(value: Float(step) / Float(steps)).midX
            context.move(to: CGPoint(x: x, y: y - height / 2))
            context.addLine(to: CGPoint(x: x, y: y + height / 2))
            context.setStrokeColor(UIColor.darkGray.cgColor)
            context.strokePath()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLabelPosition()
    }
    
    // MARK: - Slider actions
    
    func sliderValueChanged(_ sender: UISlider) {
        updateLabelPosition()
        let index = nearestIndex
        if index != currentTitleIndex {
            currentTitleIndex = index
            label.text = discreteValues[index].displayName
            sendActions(for: .valueChanged)
        }
    }
    
    func sliderTouchUp(_ sender: UISlider) {
        guard isDiscrete, !discreteValues.isEmpty else { return }
        sender.value = self.nearestSliderValue
        sender.sendActions(for: .valueChanged)
        UIView.animate(withDuration: 0.1) {
            self.layoutIfNeeded()
        }
    }
    
    // MARK: - Appearance
    
    func sliderThumbRect(value: Float) -> CGRect {
        return slider.thumbRect(
            forBounds: slider.bounds,
            trackRect: slider.trackRect(forBounds: slider.bounds),
            value: value)
    }
    
    func updateSliderTrack() {
        contentMode = isDiscrete ? .redraw : .scaleToFill
        let color: UIColor? = isDiscrete ? .clear : nil
        slider.minimumTrackTintColor = color
        slider.maximumTrackTintColor = color
        if isDiscrete {
            setNeedsDisplay()
        }
    }
    
    func updateLabelPosition() {
        labelX.constant = sliderThumbRect(value: slider.value).midX
    }
}
