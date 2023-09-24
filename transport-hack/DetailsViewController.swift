import UIKit
import RealityKit
import ARKit
import CoreLocation
import Vision

class DetailsViewController: UIViewController {
    
    var prediction: Prediction?

    @IBOutlet weak var stopIdLabel: UILabel!
    @IBOutlet weak var tripIdLabel: UILabel!
    @IBOutlet weak var vehicleIdLabel: UILabel!
    @IBOutlet weak var routeNameLabel: UILabel!
    @IBOutlet weak var predictedDelayLabel: UILabel!
    @IBOutlet weak var predictedDepartureLabel: UILabel!
    @IBOutlet weak var predictionDateTimeLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Populate the UI with the prediction data
        if let prediction = self.prediction {
            stopIdLabel.text = "Stop ID: \(prediction.StopId)"
            tripIdLabel.text = "Trip ID: \(prediction.TripId)"
            vehicleIdLabel.text = "Vehicle ID: \(prediction.VehicleId)"
            routeNameLabel.text = "Route Name: \(prediction.RouteName)"
            predictedDelayLabel.text = "Predicted Delay (in seconds): \(prediction.PredictedDelayInSeconds)"
            predictedDepartureLabel.text = "Predicted Departure: \(prediction.PredictedDeparture)"
            predictionDateTimeLabel.text = "Prediction Date and Time: \(prediction.PredictionDateTime)"
        }
    }
}
