import UIKit
import RealityKit
import ARKit
import CoreLocation
import Vision

class ViewController: UIViewController, CLLocationManagerDelegate, ARSessionDelegate, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var arView: ARView!
    let tableView = UITableView()
    var locationManager: CLLocationManager!
    var userLocation: CLLocation?
    var busStops: [BusStop] = []
    var busStopAnchors: [AnchorEntity] = []
    // Change selectedPrediction to selectedPredictions and adjust its type
    var selectedPredictions: [Prediction]?
    var arrowEntity: ModelEntity?
    var currentTextAnchor: AnchorEntity?
    let busStopLabel = UILabel()
    


    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("ViewController initialized")
        
        // Core Location Setup
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.stopUpdatingLocation()
        locationManager.startUpdatingLocation()

        
        // AR Configuration
        let configuration = ARWorldTrackingConfiguration()
        if let trackedImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: Bundle.main) {
            configuration.detectionImages = trackedImages
            configuration.maximumNumberOfTrackedImages = 2
        }
        arView.session.run(configuration)
        arView.session.delegate = self
        
        // Set up constraints for ARView
        arView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leftAnchor.constraint(equalTo: view.leftAnchor),
            arView.rightAnchor.constraint(equalTo: view.rightAnchor),
            arView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7)
        ])
        setupBusStopLabel()
        pointArrowTowardsNearestBusStop()
        // Setup the table view
        setupTableView()
    }
    
    func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BusStopCell")
        
        // Constraints for the tableView to occupy the bottom part of the screen
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: arView.bottomAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return busStops.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BusStopCell", for: indexPath)
        cell.textLabel?.text = busStops[indexPath.row].name
        return cell
    }
    
    // Core Location delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("Location Updated: \(location)")
            userLocation = location

            // Always update the arrow's rotation to the nearest bus stop
            updateNearestBusStopLabel()

            fetchNearbyBusStops(location: location)
            
        }
    }
    func updateNearestBusStopLabel() {
        guard let userLocation = userLocation, !busStops.isEmpty else { return }

        // Sort the bus stops by their distance to the user
        let sortedBusStops = busStops.sorted {
            let distance1 = userLocation.distance(from: $0.location)
            let distance2 = userLocation.distance(from: $1.location)
            return distance1 < distance2
        }

        // Get up to the nearest 4 bus stops
        let nearestFourBusStops = Array(sortedBusStops.prefix(4))

        // Construct the label string
        var labelText = ""
        for (index, busStop) in nearestFourBusStops.enumerated() {
            let distance = userLocation.distance(from: busStop.location)
            labelText += "Bus Stop \(index + 1): \(busStop.name)\nDistance: \(String(format: "%.2f", distance)) meters\n\n"
        }

        // Update the label
        busStopLabel.text = labelText
    }




    func setupBusStopLabel() {
        let labelHeight: CGFloat = 200  // Adjust as needed
        let topPadding: CGFloat = 40  // Adjust this value for desired padding from the top

        busStopLabel.frame = CGRect(x: 0, y: topPadding, width: UIScreen.main.bounds.width, height: labelHeight)
        busStopLabel.textAlignment = .left  // Or .center if you want it centered
        busStopLabel.textColor = .white
        busStopLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        busStopLabel.numberOfLines = 0
        busStopLabel.layer.cornerRadius = 10
        busStopLabel.clipsToBounds = true

        view.addSubview(busStopLabel)
    }



    
    func recognizeStopID(in image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("Failed to recognize text: \(error)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            for observation in observations {
                let potentialText = observation.topCandidates(1).first?.string ?? ""
                let components = potentialText.split(separator: " ")
                if let index = components.firstIndex(where: { $0.caseInsensitiveCompare("Stop") == .orderedSame }), index < components.count - 2, components[index + 1].caseInsensitiveCompare("ID") == .orderedSame {
                    let stopID = components[index + 2]
                    completion(String(stopID))
                    return
                }
                
            }
            
            completion(nil)
        }
        
        try? requestHandler.perform([request])
    }
    
    func fetchNearbyBusStops(location: CLLocation) {
        let radius: Double = 1000
        let apiKey = "AIzaSyDPEV1OqNFXW3_zZlxln-wt3Mi70g0aptQ" // Replace with your Google Places API Key
        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location.coordinate.latitude),\(location.coordinate.longitude)&radius=\(radius)&type=bus_station&key=\(apiKey)"
        
        if let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if let error = error {
                    // Print network error
                    print("Network error: \(error.localizedDescription)")
                    return
                }
                
                if let data = data {
                    do {
                        let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]
                        if let results = jsonResult?["results"] as? [[String: Any]] {
                            self.busStops = results.compactMap { (dict) -> BusStop? in
                                if let id = dict["place_id"] as? String,
                                   let name = dict["name"] as? String,
                                   let geometry = dict["geometry"] as? [String: Any],
                                   let location = geometry["location"] as? [String: Double],
                                   let lat = location["lat"],
                                   let lon = location["lng"] {
                                    return BusStop(id: id, name: name, location: CLLocation(latitude: lat, longitude: lon))
                                }
                                return nil
                            }
                            
                            // Print if no bus stops are found
                            if self.busStops.isEmpty {
                                print("No bus stops found within the specified radius.")
                            } else {
                                // Print the fetched bus stops to the console
                                for busStop in self.busStops {
                                    print("Stop ID: \(busStop.id), Name: \(busStop.name), Location: \(busStop.location.coordinate.latitude), \(busStop.location.coordinate.longitude)")
                                    
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                                self.pointArrowTowardsNearestBusStop()
                                self.updateNearestBusStopLabel()
                                
                            }
                        }
                    } catch {
                        print("Failed to parse JSON: \(error)")
                    }
                }
            }.resume()
        }
    }
    
    // ARSession delegate
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let imageAnchor = anchor as? ARImageAnchor,
               let image = UIImage(named: imageAnchor.referenceImage.name ?? "") {
                
                recognizeStopID(in: image) { stopID in
                    guard let id = stopID, let validStopId = Int(id) else {
                        print("Failed to recognize the Stop ID in the image.")
                        return
                    }
                    
                    self.fetchPredictions(forStopId: validStopId) { predictions in
                        if let predictions = predictions, !predictions.isEmpty {
                            // Instead of taking just the first prediction, we store all the predictions
                            self.selectedPredictions = predictions
                            
                            DispatchQueue.main.async {
                                self.performSegue(withIdentifier: "showDetailsSegue", sender: self)
                            }
                        }
                    }
                    
                    let textEntity = ModelEntity(mesh: .generateText("Stop ID: \(id)"))
                    textEntity.scale = [0.001, 0.001, 0.001]
                    textEntity.transform.rotation = simd_quatf(angle: -Float.pi / 2, axis: [1, 0, 0])
                    textEntity.scale = [0.001, 0.001, -0.001]
                    
                    let anchorEntity = AnchorEntity(anchor: imageAnchor)
                    anchorEntity.addChild(textEntity)
                    self.arView.scene.addAnchor(anchorEntity)
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetailsSegue",
           let detailsVC = segue.destination as? DetailsViewController {
            detailsVC.predictions = selectedPredictions
        }
    }
    
    
    func fetchPredictions(forStopId stopId: Int, completion: @escaping ([Prediction]?) -> Void) {
        let apiKey = "5BE6D03B8B0033DB1656D4FED69594ED"  // replace with your API key
        let urlString = "https://api.actransit.org/transit/stops/\(stopId)/predictions?token=\(apiKey)"
        
        if let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if let error = error {
                    print("Network error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let data = data {
                    print(String(data: data, encoding: .utf8) ?? "Could not convert data to string")
                    
                    do {
                        // Initialize the date formatter
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                        
                        // Initialize the JSON decoder
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(dateFormatter)
                        
                        let predictions = try decoder.decode([Prediction].self, from: data)
                        
                        // Sort the predictions based on the PredictedDeparture date
                        let sortedPredictions = predictions.sorted(by: { $0.PredictedDeparture < $1.PredictedDeparture })
                        
                        // Take the next five predictions
                        let nextFivePredictions = Array(sortedPredictions.prefix(5))
                        
                        completion(nextFivePredictions)
                    } catch {
                        print("Failed to parse JSON: \(error)")
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            }.resume()
        }
    }
    
    func pointArrowTowardsNearestBusStop() {
        guard let userLocation = userLocation else {
            print("User location is not available.")
            return
        }

        // Simply call the new function
        updateNearestBusStopLabel()
    }








    func calculateAngleBetween(_ userLocation: CLLocation, and busStopLocation: CLLocation) -> Double {
        let dx = busStopLocation.coordinate.longitude - userLocation.coordinate.longitude
        let dy = busStopLocation.coordinate.latitude - userLocation.coordinate.latitude
        
        let angle = atan2(dy, dx)
        return -angle // Negative because Y-axis rotation in RealityKit is opposite to 2D coordinate rotation
    }

}

extension CLLocationCoordinate2D {
    func bearing(to point: CLLocationCoordinate2D) -> Float {
        let lat1 = self.latitude.degreesToRadians
        let lon1 = self.longitude.degreesToRadians

        let lat2 = point.latitude.degreesToRadians
        let lon2 = point.longitude.degreesToRadians

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let radiansBearing = atan2(y, x)

        return Float(radiansBearing)
    }
}

extension Double {
    var degreesToRadians: Double { return self * .pi / 180.0 }
}


struct BusStop {
    var id: String
    var name: String
    var location: CLLocation
    var distanceFromUser: CLLocationDistance?  // New property
}

struct Prediction: Codable {
    var StopId: Int
    var TripId: Int
    var VehicleId: Int
    var RouteName: String
    var PredictedDelayInSeconds: Int
    var PredictedDeparture: Date  // Change this to Date type
    var PredictionDateTime: Date
}



