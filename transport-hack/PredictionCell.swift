//
//  PredictionCell.swift
//  transport-hack
//
//  Created by Aly Lin on 2023-09-23.
//

import Foundation
import UIKit
import RealityKit
import ARKit
import CoreLocation
import Vision

class PredictionCell: UITableViewCell {
    
    // Define UILabels for the properties you want to display
    private let routeNameLabel = UILabel()
    private let predictedDepartureLabel = UILabel()
    private let predictedDelayLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Add the labels as subviews
        addSubview(routeNameLabel)
        addSubview(predictedDepartureLabel)
        addSubview(predictedDelayLabel)
        
        // Setup constraints (here's an example for one, but you'd set them for all labels)
        routeNameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            routeNameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            routeNameLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 10),
            routeNameLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -10)
            // ... add constraints for the other labels too
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with prediction: Prediction) {
        // Set the text properties with the prediction data
        routeNameLabel.text = "Route Name: \(prediction.RouteName)"
        predictedDepartureLabel.text = "Predicted Departure: \(prediction.PredictedDeparture)"
        predictedDelayLabel.text = "Predicted Delay: \(prediction.PredictedDelayInSeconds) seconds"
    }
}
