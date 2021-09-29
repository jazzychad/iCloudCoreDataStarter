//
//  ThingView.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/24/21.
//

import UIKit

class ThingView: UIView {

    var amountLabel: UILabel = UILabel()

    override func layoutSubviews() {
        super.layoutSubviews()

        if amountLabel.superview == nil {
            amountLabel.translatesAutoresizingMaskIntoConstraints = false
            amountLabel.backgroundColor = .black
            amountLabel.textColor = .white
            self.addSubview(amountLabel)
            NSLayoutConstraint.activate([
                amountLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                amountLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor)
            ])
        }
    }

}
