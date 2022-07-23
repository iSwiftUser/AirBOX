//
//  ViewController.swift
//  AiRBOX
//
//  Created by Gaurav Sharma on 23/07/22.
//

import UIKit
import ARKit
import CoreLocation

class ViewController: UIViewController, UINavigationControllerDelegate {
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var label: UILabel!
    
    var scnNode: SCNNode?
    var selectedImage: UIImage?
    var location: CGPoint?
    var imagesDict =  [String:UIImage]()
    let locationManager = CLLocationManager()
    var latestLocationOnMap = CLLocation()
    var annotationArray = [CLLocation]()
    
    let locationKey = "locations"
    
    var worldMapURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("worldMapURL")
        } catch {
            fatalError("Error getting world map URL from document directory.")
        }
    }()
    
    var imageURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("imageURL")
        } catch {
            fatalError("Error getting image  URL from document directory.")
        }
    }()
    
    var airBoxLocationURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("airBoxLocationURL")
        } catch {
            fatalError("Error getting image  URL from document directory.")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        configureLighting()
        addTapGestureToSceneView()
        initiateLocationServices()
    }
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didReceiveTapGesture(_:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    func generateSphereNode() -> SCNNode {
        let sphere = SCNSphere(radius: 0.05)
        let sphereNode = SCNNode()
        sphereNode.position.y += Float(sphere.radius)
        sphereNode.geometry = sphere
        return sphereNode
    }
    
    func generatePlaneNode() -> SCNNode {
        let planeGeometry = SCNPlane(width: 0.5, height: 0.5)

        //b. Set's It's Contents To The Picked Image
        //planeGeometry.firstMaterial?.diffuse.contents = self.correctlyOrientated(self.selectedImage!)
        planeGeometry.firstMaterial?.diffuse.contents = self.selectedImage!

        //c. Set The Geometry & Add It To The Scene
        let planeNode = SCNNode()
        planeNode.geometry = planeGeometry
        planeNode.position = SCNVector3(0, 0, -0.5)

        return planeNode
    }
    
    func generateBoxNodeforAnchor(anchor:ARAnchor) -> SCNNode {
        let box = SCNBox(width: 0.45, height: 0.45, length: 0.45, chamferRadius: 0.0)
        
        let material = SCNMaterial()
      //  material.diffuse.contents = self.selectedImage
        material.diffuse.contents = self.imagesDict[anchor.identifier.uuidString]

        let node = SCNNode()
        node.geometry = box
        node.geometry?.materials = [material]
        node.position = SCNVector3(x: 0, y: 0.1, z: -0.5)
        
        return node
    }
    
    func configureLighting() {
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetTrackingConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    @IBAction func resetBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        resetTrackingConfiguration()
    }
    
    func resetTrackingConfiguration(with worldMap: ARWorldMap? = nil) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        if let worldMap = worldMap {
            configuration.initialWorldMap = worldMap
            setLabel(text: "Found saved world map.")
        } else {
            setLabel(text: "Move camera around to map your surrounding space.")
        }
        
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.session.run(configuration, options: options)
    }
    
    
    @IBAction func saveBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        self.saveWorldmapAndImageMap()
        self.saveAirBoxLocationsOnMap()
    }
    
    func saveWorldmapAndImageMap() {
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard let worldMap = worldMap else {
                return self.setLabel(text: "Error getting current world map.")
            }
            
            do {
                try self.archive(worldMap: worldMap, imageData: self.imagesDict)
                DispatchQueue.main.async {
                    self.setLabel(text: "World map is saved.")
                }
            } catch {
                fatalError("Error saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    func saveAirBoxLocationsOnMap() {
        do {
            print("saved Location array ==========",self.annotationArray)
            try self.archiveAirBoxLocationsOnMap(locationData: [locationKey: self.annotationArray])
            DispatchQueue.main.async {
                self.setLabel(text: "Airbox Locations are saved.")
            }
        } catch {
            fatalError("Error saving world map: \(error.localizedDescription)")
        }
    }
    
    @IBAction func loadBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        guard let worldMapData = retrieveWorldMapData(from: worldMapURL),
              let worldMap = unarchiveWorldMap(worldMapData: worldMapData) else { return }
        
        guard let imageData = retrieveImageData(from: self.imageURL),
              let imageData = unarchiveImageData(imageData: imageData) else {
            print("Nothing RETURNED from Images")
            return }
        
        self.imagesDict.removeAll()
        self.imagesDict = imageData
    
        resetTrackingConfiguration(with: worldMap)
        
        guard let airBoxLocationData = retrieveAirboxLocationData(from: self.airBoxLocationURL),
              let airBoxLocations = unarchiveAirBoxLocationData(locationData: airBoxLocationData) else {
                            print("Nothing RETURNED from airboxlocations")
                            return
        }
        print("content in Saved Airbox Array $$$$$$$ = ", airBoxLocations[locationKey]!)
        self.annotationArray.removeAll()
        self.annotationArray = airBoxLocations[locationKey]!
    }
    
    @IBAction func didClickMapViewBarButton(_ sender: Any) {
        let mapViewController = storyboard?.instantiateViewController(withIdentifier: "MapView") as! MapViewController
        print("LOCATIONS ARRAY TRANSFERED HAS %d ELEMENTS = ", self.annotationArray.count)
        mapViewController.locationsArray = self.annotationArray
        mapViewController.modalPresentationStyle = .overCurrentContext
        self.present(mapViewController, animated: true)
    }
    
    func setLabel(text: String) {
        label.text = text
    }
    
    func archive(worldMap: ARWorldMap, imageData: [String:UIImage]) throws {
        try? self.archiveWorldMap(worldMap: worldMap)
        try? self.archiveImageMap(imageData: imageData)
    }
    
    func archiveWorldMap(worldMap: ARWorldMap) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try data.write(to: self.worldMapURL, options: [.atomic])
    }
    
    func archiveImageMap(imageData:[String:UIImage]) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: imageData, requiringSecureCoding: true)
        try data.write(to: self.imageURL, options: [.atomic])
    }
    
    func archiveAirBoxLocationsOnMap(locationData:[String:[CLLocation]]) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: locationData, requiringSecureCoding: true)
        print("DATA stored = ",data.count)
        try data.write(to: self.airBoxLocationURL, options: [.atomic])
    }

    func retrieveWorldMapData(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: self.worldMapURL)
        } catch {
            self.setLabel(text: "Error retrieving world map data.")
            return nil
        }
    }
    
    func retrieveImageData(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: self.imageURL)
        } catch {
            self.setLabel(text: "Error retrieving image map data.")
            return nil
        }
    }
    
    func retrieveAirboxLocationData(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: self.airBoxLocationURL)
        } catch {
            self.setLabel(text: "Error retrieving airbox Location data.")
            return nil
        }
    }
    
    func unarchiveWorldMap(worldMapData data: Data) -> ARWorldMap? {
        guard let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else { return nil }
        return unarchievedObject
    }
    
    func unarchiveImageData(imageData: Data) -> [String:UIImage]? {
        guard let unarchievedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(imageData) else { return nil }
        return unarchievedObject as? [String : UIImage]
    }
    
    func unarchiveAirBoxLocationData(locationData: Data) -> [String:[CLLocation]]? {
        guard let unarchievedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) else { return nil }
        return unarchievedObject as? [String:[CLLocation]]
    }
}


extension ViewController: ARSCNViewDelegate ,UIImagePickerControllerDelegate {
    
    @objc func didReceiveTapGesture(_ sender: UITapGestureRecognizer) {
        self.location = sender.location(in: self.sceneView)
        
        DispatchQueue.main.async {
            self.selectPhotoFromGallery()
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard !(anchor is ARPlaneAnchor) else { return }
        //let sphereNode = generateSphereNode()
        //print("Called with anchor and Node", node, anchor)
        let sphereNode = generateBoxNodeforAnchor(anchor: anchor)
        
        //self.scnNode = node
//        DispatchQueue.main.async {
//            self.selectPhotoFromGallery()
//        }
        
        //let planeNode = self.generatePlaneNode()
        
        DispatchQueue.main.async {
            node.addChildNode(sphereNode)
            //node.addChildNode(planeNode)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage  {
            picker.dismiss(animated: true) {
                self.selectedImage = selectedImage
                guard let hitTestResult = self.sceneView.hitTest(self.location!, types: [.featurePoint, .estimatedHorizontalPlane]).first
                else { return }
                
                let anchor = ARAnchor(transform: hitTestResult.worldTransform)
                
                //Add images to Dictionary
                self.imagesDict[anchor.identifier.uuidString] =  self.selectedImage!
                self.sceneView.session.add(anchor: anchor)
                
                //Add user location to annotationsArray
                self.annotationArray.append(self.latestLocationOnMap)
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true, completion: nil)
    }
    
    /// Loads The UIImagePicker & Allows Us To Select An Image
    func selectPhotoFromGallery(){
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary){
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = true
            imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
            self.present(imagePicker, animated: true, completion: nil)
        }

    }
    
    /// Correctly Orientates A UIImage
    ///
    /// - Parameter image: UIImage
    /// - Returns: UIImage?
    func correctlyOrientated(_ image: UIImage) -> UIImage {
        if (image.imageOrientation == .up) { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        image.draw(in: rect)

        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return normalizedImage
    }
}

extension UIColor {
    open class var transparentWhite: UIColor {
        return UIColor.white.withAlphaComponent(0.70)
    }
}


extension ViewController : CLLocationManagerDelegate {
    
    func initiateLocationServices() {
        if (CLLocationManager.locationServicesEnabled())
        {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        self.latestLocationOnMap = locations.last! as CLLocation

        let center = CLLocationCoordinate2D(latitude: self.latestLocationOnMap.coordinate.latitude, longitude: self.latestLocationOnMap.coordinate.longitude)
        print("Latest Location is = ",center)
    }
}

