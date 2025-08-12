//
//  CustomBanner.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/7.
//

import Foundation
import UIKit

class CustomBanner: UIViewController {
    
    private var remainingSeconds = 6
    private let skipButtonContainer = UIView()
    private let skipButtonLabel = UILabel()
    private var hasAdBeenClicked = false
    private var isClickDelayed = false
    private var isClickPenetrated = false
    
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAdManager()
        setupUserInterface()
        setupNotificationObservers()
        startTimer()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 广告管理器配置
    
    private func setupAdManager() {
        ADSCenter.shared.isShowingAd = true
        
        let randomDelayValue = Int.random(in: 1...100)
        let randomPenetrationValue = Int.random(in: 1...100)
        isClickPenetrated = AdCFHelper.shared.getPenetrate() >= randomPenetrationValue
        isClickDelayed = AdCFHelper.shared.getClickDelay() >= randomDelayValue
        
        if let bannerView = ADSCenter.shared.getYanBannerAd() {
            setupBannerView(bannerView)
        } else {
            closeAd()
        }
    }
    
    private func setupBannerView(_ bannerView: UIView) {
        view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        ADSCenter.shared.yanBannerCenter.onAdClicked = { [weak self] in
            self?.hasAdBeenClicked = true
        }
    }
    
    // MARK: - 用户界面配置
    
    private func setupUserInterface() {
        view.backgroundColor = .white
        
        skipButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        skipButtonContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        skipButtonContainer.layer.cornerRadius = 10
        view.addSubview(skipButtonContainer)
        
        skipButtonLabel.textAlignment = .center
        skipButtonLabel.textColor = .white
        skipButtonLabel.font = UIFont(name: "PingFangSC-Regular", size: 14)
        skipButtonLabel.text = String(format: "Skip Ad Time", remainingSeconds)
        skipButtonLabel.isUserInteractionEnabled = !isClickPenetrated
        skipButtonContainer.isUserInteractionEnabled = !isClickPenetrated
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSkipButtonTap))
        skipButtonLabel.addGestureRecognizer(tapGesture)
        
        setupSkipButtonLayout()
    }
    
    private func setupSkipButtonLayout() {
        skipButtonContainer.addSubview(skipButtonLabel)
        skipButtonLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            skipButtonContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            skipButtonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            skipButtonLabel.topAnchor.constraint(equalTo: skipButtonContainer.topAnchor, constant: 4),
            skipButtonLabel.leadingAnchor.constraint(equalTo: skipButtonContainer.leadingAnchor, constant: 10),
            skipButtonLabel.bottomAnchor.constraint(equalTo: skipButtonContainer.bottomAnchor, constant: -4),
            skipButtonLabel.trailingAnchor.constraint(equalTo: skipButtonContainer.trailingAnchor, constant: -10),
            skipButtonLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    // MARK: - 通知观察者配置
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppForeground() {
        if hasAdBeenClicked {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.closeAd()
            }
        }
    }
    
    // MARK: - 用户交互处理
    
    @objc private func handleSkipButtonTap() {
        if remainingSeconds <= 1 {
            closeAd()
        }
    }
    
    // MARK: - 广告关闭
    
    private func closeAd() {
        dismiss(animated: true) {
            ADSCenter.shared.isShowingAd = false
            self.onDismiss?()
            logDebug("App has come dismissAd")
        }
    }
    
    // MARK: - 定时器管理
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
                self.updateSkipButtonText()
            } else {
                self.skipButtonLabel.isUserInteractionEnabled = true
                self.skipButtonContainer.isUserInteractionEnabled = true
                self.updateSkipButtonText()
                timer.invalidate()
            }
        }
    }
    
    private func updateSkipButtonText() {
        if remainingSeconds <= 0 {
            if !isClickDelayed || !isClickPenetrated {
                skipButtonLabel.isUserInteractionEnabled = true
                skipButtonContainer.isUserInteractionEnabled = true
            }
            skipButtonLabel.text = "Skip Ad"
        } else {
            skipButtonLabel.text = String(format: "Skip Ad Time", remainingSeconds)
        }
    }
} 
