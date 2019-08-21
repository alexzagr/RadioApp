//
//  ViewController.swift
//  TrollFamily
//
//  Created by Alex Zagrebin on 13/08/2019.
//  Copyright © 2019 Alexey Zagrebin. All rights reserved.
//

import UIKit
import FontAwesome
import AVFoundation

protocol RadioMetadataListener: class {
    func didReceiveMetadata(meta: Dictionary<RadioListener.MetadataListenerTypes, AVMetadataItem>)
}

struct Constants {
    static let urlMainSite = URL(string: "http://")!
    static let urlAboutUs = URL(string: "http://")!
    static let urlStream = URL(string:"http://")!
    static let urlSongProperties = URL(string: "http://")
}

class RadioListener: NSObject {
    
    //getting metadata
    enum MetadataListenerTypes {
        case Artist
        case SongName
    }
    
    weak var delegate: RadioMetadataListener?
    
    //initialization values
    private var avAudioSession:AVAudioSession!
    private var audioURLAsset: AVURLAsset!
    private var avPlayer:AVPlayer!
    private var audioItem: AVPlayerItem!
    
    public var url: URL {
        get {
            return audioURLAsset.url
        }
    }
    
    public var volume: Float? {
        didSet {
            if let vol = volume {
                avPlayer.volume = vol
            }
        }
    }
    
    init(with url: URL) {
        super.init()
        
        initialize(with: url)
    }
    
    func initialize(with url: URL) {
        avAudioSession = AVAudioSession.sharedInstance()
        try! avAudioSession.setCategory(.playback, mode: .default, options: [])
        try! avAudioSession.setActive(true)
        
        audioURLAsset = AVURLAsset.init(url: url)
        audioItem = AVPlayerItem(asset: self.audioURLAsset)
        avPlayer = AVPlayer(playerItem: self.audioItem)

    }
    
    func createObservers() {
        unowned let bySelf = self
        self.audioItem.addObserver(bySelf, forKeyPath: "commonMetadata", options: NSKeyValueObservingOptions(), context: nil)
    }
    
    func removeObservers() {
        self.audioItem.removeObserver(self, forKeyPath: "commonMetadata")
    }
    
    func gettingMetadata () {
        let playerItem = self.audioItem
        let metadataList = playerItem!.asset.commonMetadata
        
        var tempDictionary = Dictionary<MetadataListenerTypes, AVMetadataItem>()
        for item in metadataList {
            if item.commonKey!.rawValue == "title" {
                tempDictionary[.SongName] = item
            }
            if item.commonKey!.rawValue == "artist" {
                tempDictionary[.Artist] = item
            }
        }
        
        if tempDictionary.count > 0 && delegate != nil {
            delegate!.didReceiveMetadata(meta: tempDictionary)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        gettingMetadata()
    }
    
    func play() {
        self.avPlayer.play()
    }
    
    func pause() {
        self.avPlayer.pause()
    }
    
    deinit {
        removeObservers()
    }
}

class RadioController: UIViewController, RadioMetadataListener {
    private var player: RadioListener!

    private var slider: RangeSlider!
    @IBOutlet private var imageViewLogo: UIImageView!
    @IBOutlet private var sliderView: UIView!
    
    @IBOutlet private var buttonPlay: UIButton!
    @IBOutlet private var labelInAir: UILabel!
    @IBOutlet private var labelTrackTitle: UILabel!
    
    func didReceiveMetadata(meta: Dictionary<RadioListener.MetadataListenerTypes, AVMetadataItem>) {
    
        let metadata = meta[.Artist]
        if let artistValue = metadata?.value {
            //check and set AVMetadataItem Value
        }
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initialize()
    }
    
    func initialize() {
        player = RadioListener.init(with: Constants.urlStream)
        player.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        self.slider = RangeSlider.init(frame: CGRect.init(origin: CGPoint.init(x: 0, y: 0), size: self.sliderView.frame.size))
        self.sliderView.addSubview(self.slider)
        self.slider.addTarget(self, action: #selector(self.volumeChanged), for: .valueChanged)
        
        self.buttonPlay.layer.borderColor = UIColor.init(rgb: 0xDEBDC2).cgColor
        self.buttonPlay.layer.borderWidth = 1
        
        let bnimage = self.resizeImage(image: UIImage.init(named: "play-solid")!, targetHeight: 14)
        self.buttonPlay.setImage(bnimage, for: [.normal])
        self.buttonPlay.setImage(bnimage, for: [.normal, .highlighted])
        self.buttonPlay.imageEdgeInsets = UIEdgeInsets.init(top: 0, left: 4, bottom: 0, right: 0)
        
        let bnimage2 = self.resizeImage(image: UIImage.init(named: "pause-solid")!, targetHeight: 14)
        self.buttonPlay.setImage(bnimage2, for: [.selected])
        self.buttonPlay.setImage(bnimage2, for: [.selected, .highlighted])
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.slider.frame = CGRect.init(origin: CGPoint.zero, size: self.sliderView.frame.size)
        self.buttonPlay.layer.cornerRadius = self.buttonPlay.frame.size.height / 2
    }
    
    func loadSongName() {
        let task = URLSession.shared.dataTask(with: Constants.urlSongProperties!) {(data, response, error) in
            guard let data = data else { return }
            
            let a = self.parserJSON(data: data as NSData) as String
            DispatchQueue.main.async {
                self.labelTrackTitle.text = a
                self.labelTrackTitle.isHidden = false
            }
        }
        
        task.resume()
    }
    
    func parserJSON(data: NSData) -> NSString{
        if let s = NSString(data:data as Data, encoding: String.Encoding.utf8.rawValue) {
            var ss = s.components(separatedBy: "(")
            ss.remove(at: 0)
            var sss:NSString = ss.joined(separator: "") as NSString
            sss = sss.substring(to: sss.length - 1) as NSString
            
            var dictonary:NSDictionary?
            if let data = sss.data(using: String.Encoding.utf8.rawValue) {
                
                do {
                    dictonary =  try JSONSerialization.jsonObject(with: data as Data, options: []) as? [String:AnyObject] as NSDictionary?
                    
                    if let myDictionary = dictonary
                    {
                        if let current: NSDictionary = myDictionary.object(forKey: "current") as? NSDictionary{
                            
                            if let metadata: NSDictionary = (current.object(forKey: "metadata") as? NSDictionary) {
                                
                                if let trackTitle:NSString = (metadata["track_title"] as! NSString).components(separatedBy: "Troll44").first! as NSString? {
                                    
                                    return trackTitle as NSString
                                }
                                
                            }
                            
                        } else if let currentShowName: NSString = ((myDictionary["currentShow"] as! NSArray).firstObject as! NSDictionary)["name"] as? NSString {
                            
                            return currentShowName
                            
                        } else {
                            return "НАПОЙ СЕМЬЮ"
                            
                        }
                        
                    }
                } catch let error as NSError {
                    print(error)
                }
            }
            
        }
        
        return ""
    }
    
    func animateLogo() {
        let i = UIImage(named: "logo_b")
        
        let crossFade = CABasicAnimation.init(keyPath: "contents")
        crossFade.duration = 2.5;
        crossFade.fromValue = self.imageViewLogo.image?.cgImage;
        crossFade.toValue = i?.cgImage;
        crossFade.autoreverses = true
        crossFade.repeatCount = .infinity
        
        self.imageViewLogo.layer.add(crossFade, forKey: "animateContents")
    }
    
    func stopAnimate() {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.imageViewLogo.layer.removeAllAnimations()
        }
        
        let i = UIImage(named: "logo")
        
        let crossFade = CABasicAnimation.init(keyPath: "contents")
        crossFade.duration = 1.0;
        crossFade.fromValue = self.imageViewLogo.layer.presentation()?.value(forKeyPath: "contents") ?? 0.0
        crossFade.toValue = i?.cgImage;
        crossFade.repeatCount = 1
        
        self.imageViewLogo.layer.add(crossFade, forKey: "animateContents")
        CATransaction.commit()
    }
    
    @IBAction func buttonSiteTapped() {
        let action = UIAlertAction.init(title: "На сайт", style: .default, handler: { (action) in
            UIApplication.shared.open(Constants.urlMainSite, options: [:], completionHandler: nil)
        })
        
        let action2 = UIAlertAction.init(title: "Остаться", style: .cancel, handler: { (action) in
            
        })
        
        let contr = UIAlertController.init(title: "Сообщение", message: "Хотите перейти на сайт?", preferredStyle: .alert)
        contr.addAction(action)
        contr.addAction(action2)
        
        self.present(contr, animated: true) {
            
        }
    }
    
    @IBAction func buttonAboutTapped() {
        let action = UIAlertAction.init(title: "На страницу", style: .default, handler: { (action) in
            UIApplication.shared.open(Constants.urlAboutUs, options: [:], completionHandler: nil)
        })
        
        let action2 = UIAlertAction.init(title: "Остаться", style: .cancel, handler: { (action) in
            
        })
        
        let contr = UIAlertController.init(title: "Сообщение", message: "Хотите перейти на страницу создателя?", preferredStyle: .alert)
        contr.addAction(action)
        contr.addAction(action2)
        
        self.present(contr, animated: true) {
            
        }
    }
    
    @IBAction func buttonPlayTapped(sender: UIButton) {
        //   if let button = sender as? UIButton {
        if sender.isSelected {
            // set deselected
            sender.isSelected = false
            buttonPlay.imageEdgeInsets = UIEdgeInsets.init(top: 0, left: 4, bottom: 0, right: 0)
            
            player.pause()
            self.labelInAir.isHidden = true
            self.labelTrackTitle.isHidden = true
            
            self.labelTrackTitle.text = " "
            
            self.stopAnimate()
        } else {
            // set selected
            sender.isSelected = true
            buttonPlay.imageEdgeInsets = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
            
            player.play()
            self.loadSongName()
            self.labelInAir.isHidden = false
            
            self.animateLogo()
        
        }
    }
    
    @objc func volumeChanged(sender: RangeSlider) {
        let value = sender.upperValue
        player.volume = Float(value)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
}

extension RadioController {
    func resizeImage(image: UIImage, targetHeight: CGFloat) -> UIImage {
        // Get current image size
        let size = image.size
        
        // Compute scaled, new size
        let heightRatio = targetHeight / size.height
        let newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Create new image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Return new image
        return newImage!
    }
}

