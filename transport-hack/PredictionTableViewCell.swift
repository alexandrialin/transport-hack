import UIKit
import RealityKit
import ARKit
import CoreLocation
import Vision
//  PredictionTableViewCell.swift
//  transport-hack
//
//  Created by Aly Lin on 2023-09-23.
//

class PredictionTableViewCell: UITableViewCell {
    
    let routeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 36)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 36)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        addSubview(routeLabel)
        addSubview(timeLabel)
        
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupConstraints() {
        // Route label constraints (align to left side)
        NSLayoutConstraint.activate([
            routeLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 15),
            routeLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
        
        // Time label constraints (align to right side)
        NSLayoutConstraint.activate([
            timeLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -15),
            timeLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
}

