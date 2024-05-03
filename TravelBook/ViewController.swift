//
//  ViewController.swift
//  TravelBook
//
//  Created by Elif Soylu on 4.05.2024.
//

import UIKit
import MapKit
import CoreLocation // kullanıcının konumunu almak için
import CoreData

class ViewController: UIViewController , MKMapViewDelegate , CLLocationManagerDelegate {

    @IBOutlet weak var commentText: UITextField!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!

    var locationManager = CLLocationManager() // konumu kullanmak için yönetici
    var chosenLongitude = Double()
    var chosenLatitude = Double()
    
    var selectedTitle = ""
    var selectedTitleId : UUID?
    var annotationTitle = ""
    var annotationSubtitle = ""
    var annotationLatitude = Double()
    var annotationLongitude = Double()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // tam konum almak için best kullanılır
        locationManager.requestWhenInUseAuthorization() // uygulamayı kullanırken takip etsin
        locationManager.startUpdatingLocation() // kullanıcının yerini almaya başlar
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(chooseLocation(gestureRecognizer:)))// uzun basınca çağıracak
        
        gestureRecognizer.minimumPressDuration = 2 // ne kadar basılı tutucak
        mapView.addGestureRecognizer(gestureRecognizer)
        
        if selectedTitle != "" { // boş ise
            //CoreData
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
            fetchRequest.returnsObjectsAsFaults = false
            let idString = selectedTitleId!.uuidString
            
            fetchRequest.predicate = NSPredicate(format: "id = %@", idString)
            
            do{
                let results = try context.fetch(fetchRequest)
                if results.count > 0 {
                    
                    for result in results as! [ NSManagedObject] {
                        
                        if let title = result.value(forKey: "title") as? String {
                            annotationTitle = title
                            
                        if let subtitle = result.value(forKey: "subtitle") as? String {
                                annotationSubtitle =  subtitle
                                
                                if let latitude = result.value(forKey: "latitude") as? Double {
                                    annotationLatitude = latitude
                                    
                                    if let longitude = result.value(forKey: "longitude") as? Double {
                                        annotationLongitude = longitude
                                        
                                        let annotation = MKPointAnnotation()
                                        annotation.title = annotationTitle
                                        annotation.subtitle = annotationSubtitle
                                        let coordinate = CLLocationCoordinate2D(latitude: annotationLatitude, longitude: annotationLongitude)
                                        annotation.coordinate = coordinate
                                        mapView.addAnnotation(annotation)
                                        nameText.text = annotationTitle
                                        commentText.text = annotationSubtitle
                                        
                                        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                        let region = MKCoordinateRegion(center: coordinate, span: span)
                                        mapView.setRegion(region, animated: true)
                                    }
                                }
                            }
                        }
                    }
                }
                }catch {
                    print("error")
                }
            
        }else {
            
        }
        
    }
    @objc func chooseLocation(gestureRecognizer : UILongPressGestureRecognizer) {
        //tıklanılan yerin kordinatlarını alıp pin oluşturma
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: self.mapView)
            let touchCoordinates = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView) // dokunulan noktayı koordinat sistemine çevir
            
            chosenLatitude = touchCoordinates.latitude
            chosenLongitude = touchCoordinates.longitude
        
            let annotation = MKPointAnnotation() // pin
            annotation.coordinate = touchCoordinates
            annotation.title = nameText.text
            annotation.subtitle = commentText.text
            self.mapView.addAnnotation(annotation) // ekleme
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = CLLocationCoordinate2D(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // zoomlanacak span
        let region = MKCoordinateRegion(center: location, span: span)
        mapView.setRegion(region, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { // kullanıcının yerinini pinle göstermek istemiyorum tıklanılan yeri göstermek istiyorum
            return nil
        }
        
        let resuId = "myAnnotation"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: resuId) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: resuId)
            pinView?.canShowCallout = true //baloncukla birlikte ekstra bilgi vermek
            pinView?.tintColor = UIColor.black
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure) // detay gösterme butonu
            pinView?.rightCalloutAccessoryView = button
            
            
            
        }else {
            pinView?.annotation = annotation
        }
        return pinView
        
    }
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) { // i işsartine tıklandıysa ne olucak
        if selectedTitle != "" {
            let requestLocation = CLLocation(latitude: annotationLatitude, longitude: annotationLongitude)
            CLGeocoder().reverseGeocodeLocation(requestLocation) { (placemarks, error) in
            
                if let placemark = placemarks {
                    if placemark.count > 0  {
                        let newPlacemark = MKPlacemark(placemark: placemark[0])
                        let item = MKMapItem(placemark: newPlacemark)
                        item.name = self.annotationTitle
                        
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] //arabayla
                        item.openInMaps(launchOptions: launchOptions)
                    }
                }
               
            }
        }
    }
    
    @IBAction func saveButtonClicked(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        let newPlace = NSEntityDescription.insertNewObject(forEntityName: "Places", into: context) // cordata objesine ulaşmak için
        newPlace.setValue(nameText.text, forKey: "title")
        newPlace.setValue(commentText.text, forKey: "subtitle")
        newPlace.setValue(chosenLatitude, forKey: "latitude")
        newPlace.setValue(chosenLongitude, forKey: "longitude")
        newPlace.setValue(UUID(), forKey: "id")
        
        do{
            try context.save()
            print("success")
        }catch{
            print("error")
        }
        NotificationCenter.default.post(name: NSNotification.Name("newPlace"), object: nil)
        navigationController?.popViewController(animated: true)// bir önceki viewcontrollera dönmek için
        
        
    }

}


