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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("ViewController initialized")
        
        // Core Location Setup
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
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
                    
                    // Fetch predictions for the recognized stop ID
                    self.fetchPredictions(forStopId: validStopId) { predictions in
                        if let predictions = predictions, !predictions.isEmpty {
                            let prediction = predictions[0]
                            print("RouteName: \(prediction.RouteName), PredictedDeparture: \(prediction.PredictedDeparture)")
                            
                            // Set the prediction to be passed to the next view controller
                            self.selectedPrediction = prediction
                            
                            // Perform segue to show DetailsViewController
                            DispatchQueue.main.async {
                                self.performSegue(withIdentifier: "showDetailsSegue", sender: self)
                            }
                        }
                    }
                    
                    // AR visualization
                    print("Recognized Stop ID: \(id)")
                    
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

    // New variable to store the prediction before segue
    var selectedPrediction: Prediction?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetailsSegue",
           let detailsVC = segue.destination as? DetailsViewController {
            detailsVC.prediction = selectedPrediction
        }
    }

    func loadModel() {
            guard let blueModel = try? ModelEntity.load(named: "Blue_0.usdz") else {
                print("Failed to load the Blue_0 model.")
                return
            }

            let anchor = AnchorEntity(world: [0, 0, -0.5]) // Adjust position as necessary
            anchor.addChild(blueModel)
            arView.scene.addAnchor(anchor)
        }
    
    func addArrowPointingToNearestBusStop() {
            guard let userLocation = userLocation else { return }

            var nearestBusStop: BusStop?
            var shortestDistance = Double.infinity

            for busStop in busStops {
                let distance = userLocation.distance(from: busStop.location)
                if distance < shortestDistance {
                    nearestBusStop = busStop
                    shortestDistance = distance
                }
            }

            guard let nearestStop = nearestBusStop else {
                print("No nearby bus stop found!")
                return
            }

            let bearing = calculateBearing(from: userLocation, to: nearestStop.location)
            let anchorEntity = AnchorEntity(world: userLocation.coordinate.transformToARWorldPosition())
        guard let arrowModel = try? ModelEntity.load(named: "yourConeModel.usdz") else {
            print("Failed to load the cone model.")
            return
        }
            arrowModel.transform.rotation = simd_quatf(angle: -Float.pi / 2 + Float(bearing), axis: [0, 0, 1])
            anchorEntity.addChild(arrowModel)
            arView.scene.addAnchor(anchorEntity)
        }

        func calculateBearing(from startLocation: CLLocation, to endLocation: CLLocation) -> Double {
            let lat1 = startLocation.coordinate.latitude.toRadians()
            let lon1 = startLocation.coordinate.longitude.toRadians()

            let lat2 = endLocation.coordinate.latitude.toRadians()
            let lon2 = endLocation.coordinate.longitude.toRadians()

            let dLon = lon2 - lon1

            let y = sin(dLon) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

            let radiansBearing = atan2(y, x)
            return radiansBearing
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let location = locations.last {
                print("Location Updated: \(location)")
                userLocation = location
                fetchNearbyBusStops(location: location)

                // Call the function to add the arrow after fetching the bus stops
                addArrowPointingToNearestBusStop()
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
                        // Initialize the date formatter
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                        // Initialize the JSON decoder
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(dateFormatter)
                        
                        let predictions = try decoder.decode([Prediction].self, from: data)
                        completion(predictions)
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
}

extension Double {
    func toRadians() -> Double {
        return self * .pi / 180.0
    }
    
    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
}

extension CLLocationCoordinate2D {
    func transformToARWorldPosition() -> SIMD3<Float> {
        return SIMD3<Float>(Float(self.latitude), 0, Float(self.longitude))
    }
}
struct BusStop {
    var id: String
    var name: String
    var location: CLLocation
}
struct Prediction: Codable {
    var StopId: Int
    var TripId: Int
    var VehicleId: Int
    var RouteName: String
    var PredictedDelayInSeconds: Int
    var PredictedDeparture: Date
    var PredictionDateTime: Date
}
