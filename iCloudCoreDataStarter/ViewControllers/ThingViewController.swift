//
//  ThingViewController.swift
//  iCloudCoreDataStarter
//
//  Created by Chad Etzel on 9/27/21.
//

import UIKit

class ThingViewController: UIViewController {

    private var thingView: ThingView!
    private var amountSlider: UISlider!
    private var colorWell: UIColorWell!
    private var saveButton: UIButton!

    let thing: Thing

    required init?(thing: Thing) {
        self.thing = thing
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground

        thingView = ThingView()
        thingView.translatesAutoresizingMaskIntoConstraints = false
        thingView.amountLabel.text = "\(Int64(self.thing.amount))"
        thingView.backgroundColor = self.thing.color
        self.view.addSubview(thingView)

        amountSlider = UISlider()
        amountSlider.translatesAutoresizingMaskIntoConstraints = false
        amountSlider.minimumValue = 1
        amountSlider.maximumValue = 1000
        amountSlider.value = Float(thing.amount)
        amountSlider.isContinuous = true
        amountSlider.addTarget(self, action: #selector(_sliderValueDidChange(sender:)), for: .valueChanged)
        self.view.addSubview(amountSlider)

        colorWell = UIColorWell()
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.selectedColor = thing.color
        colorWell.addTarget(self, action: #selector(_colorWellValueDidChange(sender:)), for: .valueChanged)
        self.view.addSubview(colorWell)

        saveButton = UIButton(type: .system)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(_saveButtonDidTap(sender:)), for: .touchUpInside)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10.0
        self.view.addSubview(saveButton)


        NSLayoutConstraint.activate([
            // thingView
            thingView.heightAnchor.constraint(equalToConstant: 150.0),
            thingView.widthAnchor.constraint(equalToConstant: 150.0),
            thingView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 10.0),
            thingView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),

            // amountSlider
            amountSlider.topAnchor.constraint(equalTo: thingView.bottomAnchor, constant: 15.0),
            amountSlider.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.8),
            amountSlider.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),

            // colorWell
            colorWell.topAnchor.constraint(equalTo: amountSlider.bottomAnchor, constant: 15.0),
            colorWell.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),

            // saveButton
            saveButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120.0),
            saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 60.0),
            saveButton.topAnchor.constraint(equalTo: colorWell.bottomAnchor, constant: 25.0),
            saveButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])

    }

    @objc private func _sliderValueDidChange(sender: UISlider) {
        thingView.amountLabel.text = "\(Int64(sender.value))"
    }

    @objc private func _colorWellValueDidChange(sender: UIColorWell) {
        thingView.backgroundColor = sender.selectedColor
    }

    @objc private func _saveButtonDidTap(sender: UIButton) {

        let thingPrimitive = ThingPrimitive(amount: Int64(self.amountSlider.value), color: self.colorWell.selectedColor, thing: self.thing)
        let _ = Thing.upsertThingFromPrimitive(thingPrimitive)
        CoreDataStack.shared.saveContext()
        self.dismiss(animated: true, completion: nil)
    }

}
