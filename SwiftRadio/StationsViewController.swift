//
//  StationsViewController.swift
//  Swift Radio
//
//  Created by Matthew Fecher on 7/19/15.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import CoreData
class StationsViewController: UIViewController, UIGestureRecognizerDelegate {
      var currentStation: RadioStation!
    var history = [NSManagedObject]()
    var fvrStringTitleArray : [String] = []
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    var segment : Bool = true
    @IBAction func indexChanged(_ sender: UISegmentedControl) {
        switch segmentedControl.selectedSegmentIndex {
            
           case 0:
            segment = true
            DispatchQueue.main.async {
                self.loadStationsFromJSON()
                self.tableView.reloadData()
            }

            
        case 1:
            segment = false
            self.fetchData()
            DispatchQueue.main.async {
                self.loadStationsFromJSON()
                self.tableView.reloadData()
                self.segment = true
                self.loadStationsFromJSON()
                self.segment = false
            }
           default:
               break;
           }
    }
    // MARK: - IB UI
    // MARK: Variables declearations
       let appDelegate = UIApplication.shared.delegate as! AppDelegate //Singlton instance
       var context:NSManagedObjectContext!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var stationNowPlayingButton: UIButton!
    @IBOutlet weak var nowPlayingAnimationImageView: UIImageView!
    
    // MARK: - Properties
    
    @IBAction func OpenMenu(_ sender: Any) {
        
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                       let newViewController = storyBoard.instantiateViewController(withIdentifier: "PopUpMenuViewController") as! MenuViewController
                       self.navigationController?.pushViewController(newViewController, animated: true)
    }
    
    let radioPlayer = RadioPlayer()
    
    // Weak reference to update the NowPlayingViewController
    weak var nowPlayingViewController: NowPlayingViewController?
    
    // MARK: - Lists
    
    var stations = [RadioStation]() {
        didSet {
            guard stations != oldValue else { return }
            stationsDidUpdate()
        }
    }
    
    var searchedStations = [RadioStation]()
    
    var previousStation: RadioStation?
    
    // MARK: - UI
    
    var searchController: UISearchController = {
        return UISearchController(searchResultsController: nil)
    }()
    
    var refreshControl: UIRefreshControl = {
        return UIRefreshControl()
    }()
    
    //*****************************************************************
    // MARK: - ViewDidLoad
    //*****************************************************************
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchController.isActive = true
        fetchData()
        Constants.addBannerViewToView(viewController: self)
        // Register 'Nothing Found' cell xib
        let cellNib = UINib(nibName: "NothingFoundCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "NothingFound")
        
        // Setup Player
        radioPlayer.delegate = self
        
        // Load Data
        loadStationsFromJSON()
        
        // Setup TableView
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.separatorStyle = .none
        
        // Setup Pull to Refresh
        setupPullToRefresh()
        
        // Create NowPlaying Animation
        createNowPlayingAnimation()
        
        // Activate audioSession
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            if kDebugLog { print("audioSession could not be activated") }
        }
        
        // Setup Search Bar
        setupSearchController()
        
        // Setup Remote Command Center
        setupRemoteCommandCenter()
        
        // Setup Handoff User Activity
        setupHandoffUserActivity()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
         Constants.showInterstitial(viewController: self)
        //title = "Swift Radio"
    }

    //*****************************************************************
    // MARK: - Setup UI Elements
    //*****************************************************************
    
    func setupPullToRefresh() {
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh", attributes: [.foregroundColor: UIColor.white])
        refreshControl.backgroundColor = .black
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }
    
    func createNowPlayingAnimation() {
        nowPlayingAnimationImageView.animationImages = AnimationFrames.createFrames()
        nowPlayingAnimationImageView.animationDuration = 0.7
    }
    
    func createNowPlayingBarButton() {
        guard navigationItem.rightBarButtonItem == nil else { return }
        let btn = UIBarButtonItem(title: "", style: .plain, target: self, action:#selector(nowPlayingBarButtonPressed))
        btn.image = UIImage(named: "btn-nowPlaying")
        navigationItem.rightBarButtonItem = btn
    }
    
    //*****************************************************************
    // MARK: - Actions
    //*****************************************************************
    
    @objc func nowPlayingBarButtonPressed() {
        performSegue(withIdentifier: "NowPlaying", sender: self)
    }
    
    @IBAction func nowPlayingPressed(_ sender: UIButton) {
        performSegue(withIdentifier: "NowPlaying", sender: self)
    }
    
    @objc func refresh(sender: AnyObject) {
        // Pull to Refresh
        loadStationsFromJSON()
        
        // Wait 2 seconds then refresh screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.refreshControl.endRefreshing()
            self.view.setNeedsDisplay()
        }
    }
    
    //*****************************************************************
    // MARK: - Load Station Data
    //*****************************************************************
    
    func loadStationsFromJSON() {
        stations.removeAll()
        fetchData()
        // Turn on network indicator in status bar
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        // Get the Radio Stations
        DataManager.getStationDataWithSuccess() { (data) in
            self.stations.removeAll()
            // Turn off network indicator in status bar
            defer {
                DispatchQueue.main.async { UIApplication.shared.isNetworkActivityIndicatorVisible = false }
            }
            
            if kDebugLog { print("Stations JSON Found") }
            
            guard let data = data, let jsonDictionary = try? JSONDecoder().decode([String: [RadioStation]].self, from: data), var stationsArray = jsonDictionary["station"] else {
                if kDebugLog { print("JSON Station Loading Error") }
                return
            }
          
            self.stations = stationsArray
            stationsArray.removeAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.segment == false{
            let output = self.stations.filter{ self.fvrStringTitleArray.contains($0.name) }
            self.stations = output
                }
                
                }
                
            }
        }
    
    //*****************************************************************
    // MARK: - Segue
    //*****************************************************************
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "NowPlaying", let nowPlayingVC = segue.destination as? NowPlayingViewController else { return }
        
        title = ""
        
        let newStation: Bool
        
        if let indexPath = (sender as? IndexPath) {
            // User clicked on row, load/reset station
            radioPlayer.station = searchController.isActive ? searchedStations[indexPath.row] : stations[indexPath.row]
            newStation = radioPlayer.station != previousStation
            previousStation = radioPlayer.station
        } else {
            // User clicked on Now Playing button
            newStation = false
        }
        
        nowPlayingViewController = nowPlayingVC
        nowPlayingVC.load(station: radioPlayer.station, track: radioPlayer.track, isNewStation: newStation)
        nowPlayingVC.delegate = self
    }
    
    //*****************************************************************
    // MARK: - Private helpers
    //*****************************************************************
    
    private func stationsDidUpdate() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
            guard let currentStation = self.radioPlayer.station else { return }
            
            // Reset everything if the new stations list doesn't have the current station
            if self.stations.firstIndex(of: currentStation) == nil { self.resetCurrentStation() }
        }
    }
    
    // Reset all properties to default
    private func resetCurrentStation() {
        radioPlayer.resetRadioPlayer()
        nowPlayingAnimationImageView.stopAnimating()
        stationNowPlayingButton.setTitle("Choose a station above to begin", for: .normal)
        stationNowPlayingButton.isEnabled = false
        navigationItem.rightBarButtonItem = nil
    }
    
    // Update the now playing button title
    private func updateNowPlayingButton(station: RadioStation?, track: Track?) {
        guard let station = station else { resetCurrentStation(); return }
        
        var playingTitle = station.name + ": "
        
        if track?.title == station.name {
            playingTitle += "Now playing ..."
        } else if let track = track {
            playingTitle += track.title + " - " + track.artist
        }
        
        stationNowPlayingButton.setTitle(playingTitle, for: .normal)
        stationNowPlayingButton.isEnabled = true
        createNowPlayingBarButton()
    }
    
    func startNowPlayingAnimation(_ animate: Bool) {
        animate ? nowPlayingAnimationImageView.startAnimating() : nowPlayingAnimationImageView.stopAnimating()
    }
    
    private func getIndex(of station: RadioStation?) -> Int? {
        guard let station = station, let index = stations.firstIndex(of: station) else { return nil }
        return index
    }
    
    //*****************************************************************
    // MARK: - Remote Command Center Controls
    //*****************************************************************
    
    func setupRemoteCommandCenter() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { event in
            return .success
        }
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { event in
            return .success
        }
        
        // Add handler for Next Command
        commandCenter.nextTrackCommand.addTarget { event in
            return .success
        }
        
        // Add handler for Previous Command
        commandCenter.previousTrackCommand.addTarget { event in
            return .success
        }
    }
    
    //*****************************************************************
    // MARK: - MPNowPlayingInfoCenter (Lock screen)
    //*****************************************************************
    
    func updateLockScreen(with track: Track?) {
        
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        
        if let image = track?.artworkImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { size -> UIImage in
                return image
            })
        }
        
        if let artist = track?.artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }
        
        if let title = track?.title {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }
        
        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

//*****************************************************************
// MARK: - TableViewDataSource
//*****************************************************************

extension StationsViewController: UITableViewDataSource {
    
    @objc(tableView:heightForRowAtIndexPath:)
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90.0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if searchController.isActive {

            return searchedStations.count
        }
        else {
            return stations.isEmpty ? 1 : stations.count
       }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if stations.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NothingFound", for: indexPath) 
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            return cell
            
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StationCell", for: indexPath) as! StationTableViewCell
            
            // alternate background color
            cell.backgroundColor = (indexPath.row % 2 == 0) ? UIColor.clear : UIColor.black.withAlphaComponent(0.2)
            cell.favImage.isUserInteractionEnabled = true
            let station =  searchController.isActive ? searchedStations[indexPath.row] : stations[indexPath.row]
            cell.configureStationCell(station: station)
            if segment == true{
                if stations[indexPath.row].name == SearchbyName(number: station.name){
                  cell.favImage.image = UIImage(named: "fillHeart")
                }
                else{
                    cell.favImage.image = UIImage(named: "heart")
                    
                }
           
            }
            else{
                cell.favImage.image = UIImage(named: "fillHeart")
            }
            let tap = UIGestureRecognizer(target: self, action: #selector(StationsViewController.tapped(_:)))
            cell.favImage.addGestureRecognizer(tap)
            return cell
        }
    }
    @objc func tapped(_ sender:AnyObject){
        print("tappedonImage")
    }
}

//*****************************************************************
// MARK: - TableViewDelegate
//*****************************************************************

extension StationsViewController: UITableViewDelegate {
    
    
     func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var delete : UITableViewRowAction! = nil
        if segment == false{
            delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
                
                self.deleteObject(name: self.stations[indexPath.row].name)
                self.loadStationsFromJSON()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    tableView.reloadData()
                }
                
              }
       
        }
        else{
            delete = UITableViewRowAction(style: .normal, title: "Favourties") { (action, indexPath) in
                         
            let currentCell = tableView.cellForRow(at: indexPath) as! StationTableViewCell
                if self.Search(number: currentCell.stationNameLabel.text!) != 0{print("number Already Exist")
                    
                }
             else{
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            let managedContext = appDelegate!.persistentContainer.viewContext
             let entity =
                 NSEntityDescription.entity(forEntityName: "Entity",
                                            in: managedContext)!
             
             let fvr = NSManagedObject(entity: entity,
                                       insertInto: managedContext)
             
            
             fvr.setValue(currentCell.stationNameLabel.text , forKey: "name")
             
             do {
                 try managedContext.save()
                self.history.append(fvr)
                tableView.reloadData()
             } catch let error as NSError {
                 print("Could not save. \(error), \(error.userInfo)")
             }
             }
            }
        }

         return [delete]
     }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if segment == false{
        deleteObject(name: stations[indexPath.row].name)
        tableView.reloadData()
        }
        else{
            let currentCell = tableView.cellForRow(at: indexPath) as! StationTableViewCell
             if Search(number: currentCell.stationNameLabel.text!) != 0{print("number Already Exist")}
             else{
             guard let appDelegate =
                 UIApplication.shared.delegate as? AppDelegate else {
                     return
             }
             let managedContext = appDelegate.persistentContainer.viewContext
             let entity =
                 NSEntityDescription.entity(forEntityName: "Entity",
                                            in: managedContext)!
             
             let fvr = NSManagedObject(entity: entity,
                                       insertInto: managedContext)
             
            
             fvr.setValue(currentCell.stationNameLabel.text , forKey: "name")
             
             do {
                 try managedContext.save()
                 history.append(fvr)
             } catch let error as NSError {
                 print("Could not save. \(error), \(error.userInfo)")
             }
             }
        }
         
    }
 
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        if radioPlayer.player.isPlaying{
//            if  currentStation.name == stations[indexPath.row].name{
//                print("Playing")
//            }
//            else{
//                tableView.deselectRow(at: indexPath, animated: true)
//                performSegue(withIdentifier: "NowPlaying", sender: indexPath)
//            }
//        }
//        else{
        tableView.deselectRow(at: indexPath, animated: true)
        performSegue(withIdentifier: "NowPlaying", sender: indexPath)
        //}
        
        
    }
}

//*****************************************************************
// MARK: - UISearchControllerDelegate / Setup
//*****************************************************************

extension StationsViewController: UISearchResultsUpdating,UISearchBarDelegate {
    
    func setupSearchController() {
        guard searchable else { return }
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.sizeToFit()
        
         //Add UISearchController to the tableView
        tableView.tableHeaderView = searchController.searchBar
        tableView.tableHeaderView?.backgroundColor = UIColor.clear
        definesPresentationContext = true
        searchController.hidesNavigationBarDuringPresentation = false
        
        // Style the UISearchController
        searchController.searchBar.barTintColor = UIColor.clear
        searchController.searchBar.tintColor = UIColor.white
        
        // Hide the UISearchController
        tableView.setContentOffset(CGPoint(x: 0.0, y: searchController.searchBar.frame.size.height), animated: false)
       
        // iOS 13 or greater
        if  #available(iOS 13.0, *) {
            // Make text readable in black searchbar
            searchController.searchBar.barStyle = .black
            // Set a black keyborad for UISearchController's TextField
            searchController.searchBar.searchTextField.keyboardAppearance = .dark
        } else {
            let searchTextField = searchController.searchBar.value(forKey: "_searchField") as? UITextField
            searchTextField?.keyboardAppearance = .dark
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        
        searchedStations.removeAll(keepingCapacity: false)
        searchedStations = stations.filter { $0.name.range(of: searchText, options: [.caseInsensitive]) != nil }
        self.tableView.reloadData()
    }
}

//*****************************************************************
// MARK: - RadioPlayerDelegate
//*****************************************************************

extension StationsViewController: RadioPlayerDelegate {
    
    func playerStateDidChange(_ playerState: FRadioPlayerState) {
        nowPlayingViewController?.playerStateDidChange(playerState, animate: true)
    }
    
    func playbackStateDidChange(_ playbackState: FRadioPlaybackState) {
        nowPlayingViewController?.playbackStateDidChange(playbackState, animate: true)
        startNowPlayingAnimation(radioPlayer.player.isPlaying)
    }
    
    func trackDidUpdate(_ track: Track?) {
        updateLockScreen(with: track)
        updateNowPlayingButton(station: radioPlayer.station, track: track)
        updateHandoffUserActivity(userActivity, station: radioPlayer.station, track: track)
        nowPlayingViewController?.updateTrackMetadata(with: track)
    }
    
    func trackArtworkDidUpdate(_ track: Track?) {
        updateLockScreen(with: track)
        nowPlayingViewController?.updateTrackArtwork(with: track)
    }
}

//*****************************************************************
// MARK: - Handoff Functionality - GH
//*****************************************************************

extension StationsViewController {
    
    func setupHandoffUserActivity() {
        userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity?.becomeCurrent()
    }
    
    func updateHandoffUserActivity(_ activity: NSUserActivity?, station: RadioStation?, track: Track?) {
        guard let activity = activity else { return }
        activity.webpageURL = (track?.title == station?.name) ? nil : getHandoffURL(from: track)
        updateUserActivityState(activity)
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        super.updateUserActivityState(activity)
    }
    
    private func getHandoffURL(from track: Track?) -> URL? {
        guard let track = track else { return nil }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "google.com"
        components.path = "/search"
        components.queryItems = [URLQueryItem]()
        components.queryItems?.append(URLQueryItem(name: "q", value: "\(track.artist) \(track.title)"))
        return components.url
    }
}

//*****************************************************************
// MARK: - NowPlayingViewControllerDelegate
//*****************************************************************

extension StationsViewController: NowPlayingViewControllerDelegate {
    
    func didPressPlayingButton() {
        radioPlayer.player.togglePlaying()
    }
    
    func didPressStopButton() {
        radioPlayer.player.stop()
    }
    
    func didPressNextButton() {
        guard let index = getIndex(of: radioPlayer.station) else { return }
        radioPlayer.station = (index + 1 == stations.count) ? stations[0] : stations[index + 1]
        handleRemoteStationChange()
    }
    
    func didPressPreviousButton() {
        guard let index = getIndex(of: radioPlayer.station) else { return }
        radioPlayer.station = (index == 0) ? stations.last : stations[index - 1]
        handleRemoteStationChange()
    }
    
    func handleRemoteStationChange() {
        if let nowPlayingVC = nowPlayingViewController {
            // If nowPlayingVC is presented
            nowPlayingVC.load(station: radioPlayer.station, track: radioPlayer.track)
            nowPlayingVC.stationDidChange()
        } else if let station = radioPlayer.station {
            // If nowPlayingVC is not presented (change from remote controls)
            radioPlayer.player.radioURL = URL(string: station.streamURL)
        }
    }
    
    func fetchData()
    {  fvrStringTitleArray.removeAll()
         print("Fetching Data..")
         let appDelegate = UIApplication.shared.delegate as! AppDelegate
         let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Entity")
         request.returnsObjectsAsFaults = false
        
            
         do {
             let result = try context.fetch(request)
             for data in result as! [NSManagedObject] {
                 let fvrtitle = data.value(forKey: "name") as! String
                fvrStringTitleArray.append(fvrtitle)
                 print(fvrtitle)
                if segment == false{
                    tableView.reloadData()
                }
             }
         } catch {
             print("Fetching data Failed")
         }
     }
    func Search(number: String) -> Int
    {
        var count: Int = 0
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Entity")
        let searchString = number
        request.predicate = NSPredicate(format: "name == %@", searchString)
        do {
            let result = try context.fetch(request)
            if result.count > 0 {
                for online in result {
                    _ = (online as AnyObject).value(forKey: "name") as? String
                }
                count = result.count
            } else {
                
            }
         
        } catch {
            print(error)
        }
        
        return count
    }
    
    func deleteObject(name: String){
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Entity")
        let searchString = name
        request.predicate = NSPredicate(format: "name == %@", searchString)  // equal
        do {
            let result = try context.fetch(request)
            if result.count > 0 {
                // Delete _all_ objects:
                for object in result {
                    context.delete(object as! NSManagedObject)
                    stations.removeAll(where: { $0.name == name })
                }
                
                // Or delete first object:
                if result.count > 0 {
                    context.delete(result[0] as! NSManagedObject)
                }
                try context.save()
                
                DispatchQueue.main.async {
                    self.loadStationsFromJSON()
                    self.tableView.reloadData()
                }
                
            } else {
                
            }
            
        } catch {
            print(error)
        }
    }
    
    func deleteAllRecords() {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        let context = delegate.persistentContainer.viewContext

        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Entity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)

        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print ("There was an error")
        }
    }
    func SearchbyName(number: String) -> String
    {
        var name : String?
        var count: Int = 0
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Entity")
        let searchString = number
        request.predicate = NSPredicate(format: "name == %@", searchString)
        do {
            let result = try context.fetch(request)
            if result.count > 0 {
                for online in result {
                    name = (online as AnyObject).value(forKey: "name") as? String
                }
              
            } else {
                name = "Nothing"
            }
         
        } catch {
            print(error)
        }
          return name!
    }
}
