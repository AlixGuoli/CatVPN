//
//  VPNConnectionButton.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI
import AVKit
import CoreMedia
import NetworkExtension

private func debugVideoLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let message = items.map { "\($0)" }.joined(separator: separator)
    print(message, terminator: terminator)
#endif
}

// 使用AVPlayerLayer播放带Alpha通道的透明视频
struct AlphaVideoPlayerView: UIViewRepresentable {
    let videoName: String
    let videoExtension: String
    let delayLoop: Bool
    let onVideoReady: (() -> Void)?
    
    init(videoName: String, videoExtension: String, delayLoop: Bool = false, onVideoReady: (() -> Void)? = nil) {
        self.videoName = videoName
        self.videoExtension = videoExtension
        self.delayLoop = delayLoop
        self.onVideoReady = onVideoReady
        debugVideoLog("🎬 初始化视频播放器: \(videoName).\(videoExtension), delayLoop: \(delayLoop)")
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.isOpaque = false
        
        debugVideoLog("🎬 开始创建UIView，查找视频文件: \(videoName).\(videoExtension)")
        
        // 检查Bundle中的所有资源
        if let bundlePath = Bundle.main.path(forResource: videoName, ofType: videoExtension) {
            debugVideoLog("✅ 通过path方式找到视频文件: \(bundlePath)")
        } else {
            debugVideoLog("❌ 通过path方式未找到视频文件")
        }
        
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            debugVideoLog("❌ 视频文件未找到: \(videoName).\(videoExtension)")
            
            // 列出Bundle中的所有.mov文件用于调试
            let bundlePath = Bundle.main.bundlePath
            debugVideoLog("📁 Bundle路径: \(bundlePath)")
            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: bundlePath)
                let movFiles = contents.filter { $0.hasSuffix(".mov") }
                debugVideoLog("📹 Bundle中的.mov文件: \(movFiles)")
            } catch {
                debugVideoLog("❌ 无法读取Bundle内容: \(error)")
            }
            
            return containerView
        }
        
        debugVideoLog("✅ 视频文件找到: \(url)")
        debugVideoLog("📄 视频文件信息:")
        debugVideoLog("   - 路径: \(url.path)")
        debugVideoLog("   - 是否存在: \(FileManager.default.fileExists(atPath: url.path))")
        
        // 检查文件大小
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int {
                debugVideoLog("   - 文件大小: \(fileSize) bytes")
            }
        } catch {
            debugVideoLog("❌ 无法获取文件属性: \(error)")
        }
        
        // 创建播放器前先检查视频轨道
        let asset = AVAsset(url: url)
        debugVideoLog("🎥 检查视频资源:")
        debugVideoLog("   - 资源时长: \(asset.duration)")
        debugVideoLog("   - 是否可播放: \(asset.isPlayable)")
        debugVideoLog("   - 是否可读取: \(asset.isReadable)")
        
        // 检查视频轨道
        let videoTracks = asset.tracks(withMediaType: .video)
        debugVideoLog("   - 视频轨道数量: \(videoTracks.count)")
        
        for (index, track) in videoTracks.enumerated() {
            debugVideoLog("   - 视频轨道 \(index):")
            debugVideoLog("     - 尺寸: \(track.naturalSize)")
            debugVideoLog("     - 是否启用: \(track.isEnabled)")
            debugVideoLog("     - 媒体类型: \(track.mediaType)")
            debugVideoLog("     - 格式描述: \(track.formatDescriptions)")
            
            // 检查编解码器
            if let formatDescription = track.formatDescriptions.first {
                let codecType = CMFormatDescriptionGetMediaSubType(formatDescription as! CMFormatDescription)
                let codecString = String(describing: codecType)
                debugVideoLog("     - 编解码器: \(codecString)")
            }
        }
        
        // 检查音频轨道
        let audioTracks = asset.tracks(withMediaType: .audio)
        debugVideoLog("   - 音频轨道数量: \(audioTracks.count)")
        
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        
        // 设置播放器层属性
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.isOpaque = false
        playerLayer.videoGravity = .resizeAspect
        
        debugVideoLog("🎨 播放器层设置:")
        debugVideoLog("   - backgroundColor: \(playerLayer.backgroundColor.debugDescription)")
        debugVideoLog("   - isOpaque: \(playerLayer.isOpaque)")
        debugVideoLog("   - videoGravity: \(playerLayer.videoGravity)")
        
        // 初始时隐藏
        playerLayer.opacity = 0.0
        debugVideoLog("   - 初始opacity: \(playerLayer.opacity)")
        
        // 添加到容器视图
        containerView.layer.addSublayer(playerLayer)
        debugVideoLog("✅ 播放器层已添加到容器视图")
        
        // 存储引用
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        context.coordinator.delayLoop = delayLoop
        context.coordinator.containerView = containerView
        context.coordinator.videoName = videoName
        context.coordinator.onVideoReady = onVideoReady
        
        // 设置观察者
        setupPlayerObservers(player: player, coordinator: context.coordinator)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新播放器层的frame
        if let playerLayer = context.coordinator.playerLayer {
            playerLayer.frame = uiView.bounds
        }
        
        // 检查delayLoop是否需要更新
        if context.coordinator.delayLoop != delayLoop {
            debugVideoLog("🔄 更新delayLoop: \(context.coordinator.delayLoop) -> \(delayLoop)")
            context.coordinator.delayLoop = delayLoop
        }
    }
    
    private func setupPlayerObservers(player: AVPlayer, coordinator: Coordinator) {
        debugVideoLog("🔍 开始设置播放器观察者: \(coordinator.videoName)")
        
        // 监听播放器状态
        player.addObserver(coordinator, forKeyPath: "status", options: [.new, .initial], context: nil)
        debugVideoLog("   ✅ 添加播放器状态观察者")
        
        // 监听播放项目状态
        if let currentItem = player.currentItem {
            currentItem.addObserver(coordinator, forKeyPath: "status", options: [.new, .initial], context: nil)
            debugVideoLog("   ✅ 添加播放项目状态观察者")
            debugVideoLog("   📹 当前播放项目: \(currentItem)")
            
            // 添加更多播放项目状态观察
            currentItem.addObserver(coordinator, forKeyPath: "loadedTimeRanges", options: [.new], context: nil)
            currentItem.addObserver(coordinator, forKeyPath: "playbackBufferEmpty", options: [.new], context: nil)
            currentItem.addObserver(coordinator, forKeyPath: "playbackLikelyToKeepUp", options: [.new], context: nil)
            debugVideoLog("   ✅ 添加额外的播放项目观察者")
        } else {
            debugVideoLog("   ❌ 没有当前播放项目")
        }
        
        // 监听播放结束
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(coordinator.playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        debugVideoLog("   ✅ 添加播放结束通知观察者")
        
        // 监听播放失败
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(coordinator.playerDidFailToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem
        )
        debugVideoLog("   ✅ 添加播放失败通知观察者")
        
        // 静音预加载
        player.volume = 0
        player.automaticallyWaitsToMinimizeStalling = false
        
        debugVideoLog("🔊 播放器配置:")
        debugVideoLog("   - volume: \(player.volume)")
        debugVideoLog("   - automaticallyWaitsToMinimizeStalling: \(player.automaticallyWaitsToMinimizeStalling)")
        debugVideoLog("   - 当前播放器状态: \(player.status.rawValue)")
        
        player.play()
        debugVideoLog("🔊 开始预加载视频: \(coordinator.videoName)")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var containerView: UIView?
        var delayLoop: Bool = false
        var videoName: String = ""
        var onVideoReady: (() -> Void)?
        private var hasShownVideo = false
        
        @objc func playerDidFinishPlaying() {
            guard let player = self.player else { return }
            
            debugVideoLog("🔁 视频播放结束: \(videoName), 准备循环播放, delayLoop: \(delayLoop)")
            
            if delayLoop {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    player.seek(to: CMTime.zero)
                    player.play()
                    debugVideoLog("⏰ 延迟后重新开始播放: \(self.videoName)")
                }
            } else {
                player.seek(to: CMTime.zero)
                player.play()
                debugVideoLog("🔄 立即重新开始播放: \(self.videoName)")
            }
        }
        
        @objc func playerDidFailToPlay(_ notification: Notification) {
            debugVideoLog("❌ 视频播放失败: \(videoName)")
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                debugVideoLog("   错误详情: \(error.localizedDescription)")
            }
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            debugVideoLog("🔍 观察到状态变化: keyPath=\(keyPath ?? "nil"), videoName=\(videoName)")
            
            if let keyPath = keyPath {
                switch keyPath {
                case "status":
                    if let player = object as? AVPlayer {
                        debugVideoLog("   🎬 播放器状态变化: \(player.status.rawValue)")
                        switch player.status {
                        case .unknown:
                            debugVideoLog("      - AVPlayer状态: unknown")
                        case .readyToPlay:
                            debugVideoLog("      - AVPlayer状态: readyToPlay ✅")
                        case .failed:
                            debugVideoLog("      - AVPlayer状态: failed ❌")
                            if let error = player.error {
                                debugVideoLog("      - 错误: \(error.localizedDescription)")
                            }
                        @unknown default:
                            debugVideoLog("      - AVPlayer状态: 未知状态")
                        }
                    } else if let item = object as? AVPlayerItem {
                        debugVideoLog("   📹 播放项目状态变化: \(item.status.rawValue)")
                        switch item.status {
                        case .unknown:
                            debugVideoLog("      - AVPlayerItem状态: unknown")
                        case .readyToPlay:
                            debugVideoLog("      - AVPlayerItem状态: readyToPlay ✅")
                            debugVideoLog("      - 视频大小: \(item.presentationSize)")
                            debugVideoLog("      - 持续时间: \(item.duration)")
                        case .failed:
                            debugVideoLog("      - AVPlayerItem状态: failed ❌")
                            if let error = item.error {
                                debugVideoLog("      - 错误: \(error.localizedDescription)")
                            }
                        @unknown default:
                            debugVideoLog("      - AVPlayerItem状态: 未知状态")
                        }
                    }
                case "loadedTimeRanges":
                    if let item = object as? AVPlayerItem {
                        debugVideoLog("   📊 加载时间范围变化: \(item.loadedTimeRanges)")
                    }
                case "playbackBufferEmpty":
                    if let item = object as? AVPlayerItem {
                        debugVideoLog("   🔄 缓冲区空状态: \(item.isPlaybackBufferEmpty)")
                    }
                case "playbackLikelyToKeepUp":
                    if let item = object as? AVPlayerItem {
                        debugVideoLog("   ⚡ 播放准备就绪: \(item.isPlaybackLikelyToKeepUp)")
                    }
                default:
                    debugVideoLog("   ❓ 未处理的keyPath: \(keyPath)")
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.handleStatusChange()
            }
        }
        
        private func handleStatusChange() {
            debugVideoLog("🎯 进入handleStatusChange: \(videoName)")
            
            guard let player = self.player else {
                debugVideoLog("❌ player为nil")
                return
            }
            
            guard let playerLayer = self.playerLayer else {
                debugVideoLog("❌ playerLayer为nil")
                return
            }
            
            if hasShownVideo {
                debugVideoLog("⏭️ 视频已经显示过，跳过: \(videoName)")
                return
            }
            
            let playerReady = player.status == .readyToPlay
            let itemReady = player.currentItem?.status == .readyToPlay
            let itemExists = player.currentItem != nil
            
            debugVideoLog("📺 详细状态检查: \(videoName)")
            debugVideoLog("   - player存在: \(player)")
            debugVideoLog("   - playerLayer存在: \(playerLayer)")
            debugVideoLog("   - hasShownVideo: \(hasShownVideo)")
            debugVideoLog("   - playerReady: \(playerReady) (状态: \(player.status.rawValue))")
            debugVideoLog("   - itemExists: \(itemExists)")
            debugVideoLog("   - itemReady: \(itemReady) (状态: \(player.currentItem?.status.rawValue ?? -999))")
            
            if let currentItem = player.currentItem {
                debugVideoLog("   - 当前播放项目详情:")
                debugVideoLog("     - 视频大小: \(currentItem.presentationSize)")
                debugVideoLog("     - 持续时间: \(currentItem.duration)")
                debugVideoLog("     - 缓冲区空: \(currentItem.isPlaybackBufferEmpty)")
                debugVideoLog("     - 准备播放: \(currentItem.isPlaybackLikelyToKeepUp)")
                debugVideoLog("     - 加载时间范围: \(currentItem.loadedTimeRanges.count)")
                
                if let error = currentItem.error {
                    debugVideoLog("     - 播放项目错误: \(error.localizedDescription)")
                }
            }
            
            if let playerError = player.error {
                debugVideoLog("   - 播放器错误: \(playerError.localizedDescription)")
            }
            
            debugVideoLog("   - 当前playerLayer opacity: \(playerLayer.opacity)")
            debugVideoLog("   - playerLayer frame: \(playerLayer.frame)")
            
            if playerReady && itemReady {
                hasShownVideo = true
                debugVideoLog("🎉 视频准备就绪，开始显示: \(videoName)")
                
                // 调用回调通知视频准备就绪
                debugVideoLog("📞 调用onVideoReady回调")
                onVideoReady?()
                
                // 使用CATransaction确保平滑过渡
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.3)
                CATransaction.setCompletionBlock {
                    debugVideoLog("🎬 CATransaction完成，开始播放: \(self.videoName)")
                    player.play()
                    debugVideoLog("▶️ 播放器play()调用完成")
                    
                    // 检查播放状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        debugVideoLog("🔍 播放状态检查:")
                        debugVideoLog("   - 播放器rate: \(player.rate)")
                        debugVideoLog("   - 播放器timeControlStatus: \(player.timeControlStatus.rawValue)")
                        if let currentTime = player.currentItem?.currentTime() {
                            debugVideoLog("   - 当前播放时间: \(CMTimeGetSeconds(currentTime))")
                        }
                    }
                }
                
                debugVideoLog("🌟 设置playerLayer opacity为1.0")
                playerLayer.opacity = 1.0
                CATransaction.commit()
                debugVideoLog("✅ CATransaction提交完成")
            } else {
                debugVideoLog("⏳ 视频还未准备好: playerReady=\(playerReady), itemReady=\(itemReady)")
            }
        }
        
        deinit {
            debugVideoLog("🧹 清理视频播放器: \(videoName)")
            
            // 移除播放器观察者
            if let player = player {
                player.removeObserver(self, forKeyPath: "status")
                debugVideoLog("   ✅ 移除播放器状态观察者")
            }
            
            // 移除播放项目观察者
            if let currentItem = player?.currentItem {
                currentItem.removeObserver(self, forKeyPath: "status")
                currentItem.removeObserver(self, forKeyPath: "loadedTimeRanges")
                currentItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
                currentItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
                debugVideoLog("   ✅ 移除播放项目观察者")
            }
            
            // 移除通知观察者
            NotificationCenter.default.removeObserver(self)
            debugVideoLog("   ✅ 移除通知观察者")
            
            // 停止播放器
            player?.pause()
            player = nil
            playerLayer = nil
            debugVideoLog("   ✅ 播放器清理完成")
        }
    }
}

struct VPNConnectionButton: View {
    
    @EnvironmentObject var adsManager: AdsUtils
    
    @EnvironmentObject var vm: MainViewmodel
    
    @State private var animationScale: CGFloat = 1.0
    @State private var rippleAnimation: Bool = false
    @State private var waterRippleAnimation: Bool = false
    @State private var pulseAnimation: Bool = false
    @State private var liquidAnimation: Bool = false
    @State private var isVideoReady: Bool = false
    @State private var frogBounceAnimation: Bool = false
    
    // 青蛙主题颜色
    private var frogThemeColor: Color {
        switch vm.connectionStatus {
        case .disconnected, .failed:
            return Color.green
        case .connecting:
            return Color.mint
        case .connected:
            return Color.green
        }
    }
    
    var body: some View {
        ZStack {
            // 水波纹效果背景层 - 青蛙主题
            if vm.connectionStatus == .connecting || vm.connectionStatus == .connected {
                // 连续的水波纹
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.6),
                                    Color.mint.opacity(0.4),
                                    Color.green.opacity(0.2),
                                    Color.clear
                                ]),
                                startPoint: .center,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .scaleEffect(waterRippleAnimation ? 2.2 : 0.8)
                        .opacity(waterRippleAnimation ? 0 : 0.8)
                        .animation(
                            Animation.easeOut(duration: 2.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.6),
                            value: waterRippleAnimation
                        )
                }
                
                // 外围的液体波纹
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.3),
                                    Color.mint.opacity(0.15),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 50,
                                endRadius: 120
                            ),
                            lineWidth: 1.5
                        )
                        .scaleEffect(liquidAnimation ? 1.8 : 1.2)
                        .opacity(liquidAnimation ? 0.2 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 4.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 2.0),
                            value: liquidAnimation
                        )
                }
            }
            
            // 主按钮容器
            ZStack {
                // 外圈毛玻璃装饰 - 青蛙主题
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.green.opacity(0.15),
                                        Color.mint.opacity(0.1),
                                        Color.green.opacity(0.05),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 100
                                )
                            )
                    )
                    .frame(width: 200, height: 200)
                    .overlay(
                        Circle()
                            .stroke(.linearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.green.opacity(0.4),
                                    Color.mint.opacity(0.3),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                
                // 主按钮
                Button(action: {
                    // 添加触感反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        animationScale = 0.95
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            animationScale = 1.0
                        }
                    }
                    
                    // 重置视频状态
                    if vm.connectionStatus == .disconnected || vm.connectionStatus == .failed {
                        isVideoReady = false
                    }
                    
                    // 使用MainViewmodel的真实VPN连接方法
                    vm.handleButtonAction()
                    
                }) {
                    ZStack {
                        // 主按钮背景 - 青蛙主题毛玻璃效果
                        Circle()
                            .fill(.regularMaterial)
                            .background(
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                frogThemeColor.opacity(0.25),
                                                frogThemeColor.opacity(0.15),
                                                frogThemeColor.opacity(0.05)
                                            ]),
                                            center: .center,
                                            startRadius: 10,
                                            endRadius: 90
                                        )
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(.linearGradient(
                                        colors: [
                                            Color.white.opacity(0.5),
                                            frogThemeColor.opacity(0.6),
                                            frogThemeColor.opacity(0.4),
                                            Color.white.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ), lineWidth: 2)
                            )
                        
                        // 内部装饰环 - 青蛙主题
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        frogThemeColor.opacity(0.4),
                                        Color.green.opacity(0.3),
                                        Color.mint.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .padding(0)
                            .opacity(0.1)
                        
                        // 中心内容 - 青蛙图片/视频
                        ZStack {
                            // 青蛙背景圆圈
                            Circle()
                                .fill(.thinMaterial)
                                .background(
                                    Circle()
                                        .fill(frogThemeColor.opacity(0.1))
                                )
                                .frame(width: 180, height:  180)
                            
                            // 根据连接状态显示青蛙内容
                            Group {
                                if vm.connectionStatus == .connecting || vm.connectionStatus == .connected {
                                    // 连接中和连接成功显示视频
                                    ZStack {
                                        // Loading提示 - 只在视频未准备好时显示
                                        if !isVideoReady {
                                            VStack(spacing: 8) {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                                    .scaleEffect(1.2)
                                                
                                                Text("🐸")
                                                    .font(.system(size: 40))
                                                    .scaleEffect(frogBounceAnimation ? 1.1 : 0.9)
                                                    .animation(
                                                        Animation.easeInOut(duration: 0.8)
                                                            .repeatForever(autoreverses: true),
                                                        value: frogBounceAnimation
                                                    )
                                            }
                                            .frame(width:  200, height:  200)
                                            .transition(.opacity)
                                        }
                                        
                                        // 透明视频播放器
                                        AlphaVideoPlayerView(
                                            videoName: "frog",
                                            videoExtension: "mov",
                                            delayLoop: vm.connectionStatus == .connecting,
                                            onVideoReady: {
                                                debugVideoLog("🐸 按钮中的视频准备就绪")
                                                withAnimation(.easeOut(duration: 0.3)) {
                                                    isVideoReady = true
                                                }
                                            }
                                        )
                                        .frame(width: 200, height: 200)
                                        .clipShape(Circle())
                                    }
                                } else {
                                    // 未连接或连接失败显示静态图片
                                    Image("frog")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 200, height: 200)
                                        .clipShape(Circle())
                                        .offset(y: frogBounceAnimation ? -3 : 3)
                                        .animation(
                                            Animation.easeInOut(duration: 1.5)
                                                .repeatForever(autoreverses: true),
                                            value: frogBounceAnimation
                                        )
                                }
                            }
                        }
                        
                        // 状态文本
                        VStack {
                            Spacer()
                            Text(statusText)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            frogThemeColor,
                                            Color.green.opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.bottom, 8)
                        }
                        .frame(width: 160, height: 160)
                    }
                }
                .frame(width: 160, height: 160)
                .scaleEffect(animationScale)
                .disabled(vm.connectionStatus == .connecting)
                
                // 连接成功时的额外光晕效果 - 青蛙主题
                if vm.connectionStatus == .connected {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.2),
                                    Color.mint.opacity(0.1),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 80,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                        .opacity(pulseAnimation ? 0.6 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 3.0)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 300, height: 300)
        .onAppear {
            startAnimations()
        }
        .onChange(of: vm.connectionStatus) { status in
            updateAnimations(for: status)
        }
    }
    
    private func startAnimations() {
        // 启动基础脉冲动画
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseAnimation = true
            frogBounceAnimation = true
        }
        
        // 根据连接状态启动相应动画
        updateAnimations(for: vm.connectionStatus)
    }
    
    private func updateAnimations(for status: VPNConnectionStatus) {
        switch status {
        case .connecting, .connected:
            // 启动水波纹动画
            withAnimation(.easeOut(duration: 2.5).repeatForever()) {
                waterRippleAnimation = true
            }
            
            // 启动液体动画
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                liquidAnimation = true
            }
            
            // 重置视频状态
            if status == .connecting {
                isVideoReady = false
            }
            
        case .disconnected, .failed:
            // 停止动画
            waterRippleAnimation = false
            liquidAnimation = false
            isVideoReady = false
        }
    }
    
    private var statusText: String {
        switch vm.connectionStatus {
        case .disconnected:
            return "VPN_Button_Click_Connect".localstr() + " 🐸"
        case .connecting:
            return "VPN_Button_Connecting".localstr() + " 🐸💫"
        case .connected:
            return "VPN_Button_Connected".localstr() + " 🐸✨"
        case .failed:
            return "VPN_Button_Connection_Failed".localstr() + " 🐸😔"
        }
    }
    
    
}

#Preview {
    VStack {
        VPNConnectionButton()
            .environmentObject(MainViewmodel())
            //.environmentObject(AdsUtils())
    }
    .padding()
    .background(
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemBackground),
                Color.green.opacity(0.1),
                Color.mint.opacity(0.08)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
