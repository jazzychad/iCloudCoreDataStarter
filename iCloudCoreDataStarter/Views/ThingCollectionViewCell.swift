//
//  ThingCollectionViewCell.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/24/21.
//

import UIKit

class ThingCollectionViewCell: UICollectionViewCell {

    var thingView: ThingView = ThingView()
    var selectedCheckmarkImageView: UIImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    weak var collectionViewController: ThingRootCollectionViewController?

    override func layoutSubviews() {
        super.layoutSubviews()

        if self.thingView.superview == nil {
            thingView.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(thingView)
            NSLayoutConstraint.activate([
                thingView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
                thingView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
                thingView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),
                thingView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
            ])
        }

        if self.selectedCheckmarkImageView.superview == nil {
            selectedCheckmarkImageView.translatesAutoresizingMaskIntoConstraints = false
            selectedCheckmarkImageView.tintColor = .systemGreen
            selectedCheckmarkImageView.clipsToBounds = false
            selectedCheckmarkImageView.layer.shadowRadius = 4.0
            selectedCheckmarkImageView.layer.shadowOffset = CGSize(width: 0.0, height:  0.0)
            selectedCheckmarkImageView.layer.shadowColor = UIColor.white.cgColor
            selectedCheckmarkImageView.layer.shadowOpacity = 1.0
            self.contentView.addSubview(selectedCheckmarkImageView)
            NSLayoutConstraint.activate([
                selectedCheckmarkImageView.heightAnchor.constraint(equalToConstant: 30.0),
                selectedCheckmarkImageView.widthAnchor.constraint(equalTo: selectedCheckmarkImageView.heightAnchor, multiplier: 1.0),
                selectedCheckmarkImageView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -5),
                selectedCheckmarkImageView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -5),
            ])
            selectedCheckmarkImageView.isHidden = !isSelected
            _updateUIForSelectionState()
        }
    }

    override var isSelected: Bool {
        didSet {
            _updateUIForSelectionState()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        _updateUIForSelectionState()
    }

    private func _updateUIForSelectionState() {
        if self.isSelected && self.collectionViewController?.collectionView.allowsMultipleSelection == true {
            selectedCheckmarkImageView.isHidden = false
            self.thingView.alpha = 1.0
        } else {
            selectedCheckmarkImageView.isHidden = true

            if self.collectionViewController?.selectionMode == .multi {
                self.thingView.alpha = 0.3
            } else {
                self.thingView.alpha = 1.0
            }
        }
    }
    
}
