//
//  SpeedTestView.swift
//  V5
//
//  Created by  玉城 on 2025/7/2.
//

import SwiftUI

struct SpeedTestView: View {
    @StateObject private var speedTester = NetworkSpeedTester()
    @State private var showHistory = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // 顶部测速卡片
                    speedTestCard
                    
                    // 测速结果显示
                    if speedTester.status != .idle {
                        speedResultsView
                    }
                    
                    // 最近测试结果
                    if let lastResult = speedTester.lastResult {
                        lastTestResultView(result: lastResult)
                    }
                    
                    // 测试说明
                    testInstructionsView
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("Speed Test".localstr())
            .navigationBarTitleDisplayMode(.large)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    // 测速卡片
    private var speedTestCard: some View {
        VStack(spacing: 24) {
            // 测速仪表盘样式的圆形进度
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: speedTester.progress)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: speedTester.progress)
                
                // 中心内容
                VStack(spacing: 8) {
                    if speedTester.status == .testing {
                        VStack(spacing: 4) {
                            Text(speedTester.testPhase)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(speedTester.progress * 100))%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Speed Test".localstr())
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            
            // 开始测试按钮
            Button(action: {
                if speedTester.status == .testing {
                    speedTester.stopTest()
                } else {
                    speedTester.startSpeedTest()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: speedTester.status == .testing ? "stop.fill" : "play.fill")
                        .font(.headline)
                    
                    Text(speedTester.status == .testing ? "Stop Test".localstr() : "Start Test".localstr())
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: speedTester.status == .testing ? [.red, .pink] : [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(speedTester.status == .testing && speedTester.progress < 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
    }
    
    // 测速结果视图
    private var speedResultsView: some View {
        VStack(spacing: 16) {
            Text("Test Results".localstr())
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                // 下载速度
                speedMetricCard(
                    title: "Download".localstr(),
                    value: String(format: "%.2f", speedTester.currentDownloadSpeed),
                    unit: "Mbps",
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
                
                // 上传速度
                speedMetricCard(
                    title: "Upload".localstr(),
                    value: String(format: "%.2f", speedTester.currentUploadSpeed),
                    unit: "Mbps",
                    icon: "arrow.up.circle.fill",
                    color: .green
                )
            }
            
            // Ping单独显示
            speedMetricCard(
                title: "Ping".localstr(),
                value: "\(speedTester.ping)",
                unit: "ms",
                icon: "timer",
                color: .orange,
                isWide: true
            )
        }
    }
    
    // 速度指标卡片
    private func speedMetricCard(title: String, value: String, unit: String, icon: String, color: Color, isWide: Bool = false) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: isWide ? .infinity : nil)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
    
    // 最近测试结果
    private func lastTestResultView(result: SpeedTestResult) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Last Test Result".localstr())
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(result.testDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Label("Download".localstr() + ": \(result.downloadSpeedString)", systemImage: "arrow.down.circle")
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Label("Upload".localstr() + ": \(result.uploadSpeedString)", systemImage: "arrow.up.circle")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Label("Ping".localstr() + ": \(result.pingString)", systemImage: "timer")
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }
    
    // 测试说明
    private var testInstructionsView: some View {
        VStack(spacing: 16) {
                                    Text("How it works".localstr())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ping Test".localstr())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Measures network latency to determine response time".localstr())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Download Test".localstr())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Downloads test data to measure your connection speed".localstr())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upload Test".localstr())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Uploads test data to measure your upload speed".localstr())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
}

#Preview {
    SpeedTestView()
}
