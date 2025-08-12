////
////  BannerScreen.swift
////  CatVPN
////
////  Created by Stephen Schaaf on 2025/8/7.
////
//
//import Foundation
//import UIKit
//
//class BannerScreen : UIViewController{
//    private var countdownTimer = 6
//    private let skipAdContainerView = UIView()
//    private let skipAdCountdownLabel = UILabel()
//    private var isAdClicked = false
//    private var isAdClickDelayed = false
//    private var isAdClickPenetrated = false
//    
//    var onClose: (() -> Void)?
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        configureAdManager()
//        configureUI()
//        configureObservers()
//        startCountdownTimer()
//    }
//    
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
//    
//    private func configureAdManager() {
//        YaAdController.instance.isAdShowing = true
//        
//        let randomDelayPenetration = Int.random(in: 1...100)
//        let randomPenetration = Int.random(in: 1...100)
//        isAdClickPenetrated = YaAdController.instance.clickPenetration >= randomPenetration
//        
//        isAdClickDelayed = YaAdController.instance.clickDelay >= randomDelayPenetration
//        
//        
//        if let bannerAdView = YaAdController.instance.getBannerAd() {
//            configureBannerAdView(bannerAdView)
//        } else {
//            dismissAd()
//        }
//        
//    }
//    
//    private func configureBannerAdView(_ bannerAdView: UIView) {
//        view.addSubview(bannerAdView)
//        bannerAdView.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            bannerAdView.topAnchor.constraint(equalTo: view.topAnchor),
//            bannerAdView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            bannerAdView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            bannerAdView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        ])
//        
//        YaAdController.instance.bannerController.onAdClicked = { [weak self] in
//            self?.isAdClicked = true
//        }
//    }
//    
//    private func configureUI() {
//        view.backgroundColor = .white
//        
//        skipAdContainerView.translatesAutoresizingMaskIntoConstraints = false
//        skipAdContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
//        skipAdContainerView.layer.cornerRadius = 10
//        view.addSubview(skipAdContainerView)
//        
//        skipAdCountdownLabel.textAlignment = .center
//        skipAdCountdownLabel.textColor = .white
//        skipAdCountdownLabel.font = UIFont(name: "PingFangSC-Regular", size: 14)
//        //skipAdCountdownLabel.text = String(format: "Skip Ad Time".localized(), countdownTimer)
//        skipAdCountdownLabel.text = String(format: "Skip Ad Time", countdownTimer)
//        skipAdCountdownLabel.isUserInteractionEnabled = !isAdClickPenetrated
//        skipAdContainerView.isUserInteractionEnabled = !isAdClickPenetrated
//        
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSkipAdTap))
//        skipAdCountdownLabel.addGestureRecognizer(tapGesture)
//        
//        configureSkipAdContainer()
//    }
//    
//    private func configureSkipAdContainer() {
//        skipAdContainerView.addSubview(skipAdCountdownLabel)
//        skipAdCountdownLabel.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            skipAdContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
//            skipAdContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            
//            skipAdCountdownLabel.topAnchor.constraint(equalTo: skipAdContainerView.topAnchor, constant: 4),
//            skipAdCountdownLabel.leadingAnchor.constraint(equalTo: skipAdContainerView.leadingAnchor, constant: 10),
//            skipAdCountdownLabel.bottomAnchor.constraint(equalTo: skipAdContainerView.bottomAnchor, constant: -4),
//            skipAdCountdownLabel.trailingAnchor.constraint(equalTo: skipAdContainerView.trailingAnchor, constant: -10),
//            skipAdCountdownLabel.heightAnchor.constraint(equalToConstant: 30)
//        ])
//    }
//    
//    private func configureObservers() {
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleAppWillEnterForeground),
//            name: UIApplication.willEnterForegroundNotification,
//            object: nil
//        )
//    }
//    
//    @objc private func handleAppWillEnterForeground() {
//        if isAdClicked {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                self.dismissAd()
//            }
//        }
//    }
//    
//    @objc private func handleSkipAdTap() {
//        if countdownTimer <= 1 {
//            dismissAd()
//        }
//    }
//    
//    private func dismissAd() {
//        dismiss(animated: true) {
//            YaAdController.instance.isAdShowing = false
//            self.onClose?()
//            debugPrint("App has come dismissAd")
//        }
//    }
//    
//    private func startCountdownTimer() {
//        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
//            guard let self = self else { return }
//            
//            if self.countdownTimer > 0 {
//                self.countdownTimer -= 1
//                self.updateSkipAdCountdownLabel()
//            } else {
//                self.skipAdCountdownLabel.isUserInteractionEnabled = true
//                self.skipAdContainerView.isUserInteractionEnabled = true
//                self.updateSkipAdCountdownLabel()
//                timer.invalidate()
//            }
//        }
//    }
//    
//    private func updateSkipAdCountdownLabel() {
//        if countdownTimer <= 0 {
//            if !isAdClickDelayed || !isAdClickPenetrated {
//                skipAdCountdownLabel.isUserInteractionEnabled = true
//                skipAdContainerView.isUserInteractionEnabled = true
//            }
//            //skipAdCountdownLabel.text = "Skip Ad".localized()
//            skipAdCountdownLabel.text = "Skip Ad"
//        } else {
//            //skipAdCountdownLabel.text = String(format: "Skip Ad Time".localized(), countdownTimer)
//            skipAdCountdownLabel.text = String(format: "Skip Ad Time", countdownTimer)
//        }
//    }
//}
