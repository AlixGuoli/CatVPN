//
//  RatingCenter.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/13.
//

import Foundation

class RatingCenter {
    static let shared = RatingCenter()
    private init() {
        printAllData()
    }
    
    // MARK: - 默认参数
    private enum DefaultParams {
        static let coolDays = 3           // 默认冷却天数
        static let maxPopups = 3          // 每日默认最大弹窗数
        static let maxGood = 3            // 默认最大评分次数（不管几星）
        static let triggerMin = 10        // 出发时机（分钟）
        static let highScore = 5          // 最高评分
    }
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let coolEnd = "RC_End"        // 冷却期结束时间
        static let todayCount = "RC_Count"   // 今日弹窗次数
        static let lastScore = "RC_Score"    // 最后一次评分
        static let fiveCount = "RC_Five"     // 评分次数（不管几星）
        static let todayDate = "RC_Date"     // 今日日期
    }
    
    // MARK: - 当前配置
    private var coolDays: Int = DefaultParams.coolDays
    private var maxPopups: Int = DefaultParams.maxPopups
    private var maxGood: Int = DefaultParams.maxGood
    
    // MARK: - 连接开始时间
    var connectedTime: Date?

    // MARK: - 更新配置
    func updateConfig() {
        let config = BaseCFHelper.shared.getRateusConfig()
        if let maxDaily = config.0 {
            maxPopups = maxDaily
        }
        if let cooldown = config.1 {
            coolDays = cooldown
        }
    }
    
    // MARK: - 判断是否超过触发时间
    func isOverTriggerTime() -> Bool {
        printAllData()
        guard let connectedTime = connectedTime else { return false }
        
        let passed = Date().timeIntervalSince(connectedTime)
        let result = passed >= TimeInterval(DefaultParams.triggerMin * 60)
        if result {
            logDebug("RatingCenter: 超过触发时间 connectedTime: \(connectedTime)")
        } else {
            logDebug("RatingCenter: 未到触发时间 connectedTime: \(connectedTime)")
        }
        
        return result && canShow()
        /// 测试服
        //return canShow()
    }
    
    // MARK: - 重置每日指标
    private func resetDaily() {
        let defaults = UserDefaults.standard
        let today = Date()
        let calendar = Calendar.current
        
        if let lastDate = defaults.object(forKey: Keys.todayDate) as? Date,
           !calendar.isDate(today, inSameDayAs: lastDate) {
            logDebug("RatingCenter: 新的一天，重置计数")
            defaults.set(0, forKey: Keys.todayCount)
            defaults.set(today, forKey: Keys.todayDate)
        } else if defaults.object(forKey: Keys.todayDate) == nil {
            logDebug("RatingCenter: 首次使用，初始化计数")
            defaults.set(today, forKey: Keys.todayDate)
            defaults.set(0, forKey: Keys.todayCount)
        }
        
        defaults.synchronize()
    }
    
    // MARK: - 检查是否满足评分条件
    func canShow() -> Bool {
        logDebug("RatingCenter: 开始检查评分条件")
        resetDaily()
        updateConfig()
        
        // 检查各种限制条件
        let isInCooldown = checkCooldown()
        let isOverDailyLimit = checkDailyLimit()
        let isOverHighScoreLimit = checkHighScoreLimit()
        
        let canShow = !isInCooldown && !isOverDailyLimit && !isOverHighScoreLimit
        logDebug("RatingCenter: 评分条件检查结果 - 冷却期: \(isInCooldown), 每日限制: \(isOverDailyLimit), 高分限制: \(isOverHighScoreLimit), 最终结果: \(canShow)")
        
        return canShow
    }
    
    // MARK: - 检查冷却期
    private func checkCooldown() -> Bool {
        guard let endTime = UserDefaults.standard.object(forKey: Keys.coolEnd) as? Date else {
            logDebug("RatingCenter: 无冷却期限制")
            return false
        }
        let isInCooldown = Date() < endTime
        logDebug("RatingCenter: 冷却期检查 - 结束时间: \(endTime), 是否在冷却期: \(isInCooldown)")
        return isInCooldown
    }
    
    // MARK: - 检查每日限制
    private func checkDailyLimit() -> Bool {
        let currentCount = UserDefaults.standard.integer(forKey: Keys.todayCount)
        let isOverLimit = currentCount >= maxPopups
        logDebug("RatingCenter: 每日限制检查 - 当前次数: \(currentCount), 最大次数: \(maxPopups), 是否超限: \(isOverLimit)")
        return isOverLimit
    }
    
    // MARK: - 检查评分次数限制
    private func checkHighScoreLimit() -> Bool {
        let ratingCount = UserDefaults.standard.integer(forKey: Keys.fiveCount)
        let isOverLimit = ratingCount >= maxGood
        logDebug("RatingCenter: 评分次数限制检查 - 评分次数: \(ratingCount), 最大评分次数: \(maxGood), 是否超限: \(isOverLimit)")
        return isOverLimit
    }
    
    // MARK: - 处理评分提交
    func submit(star: Int) {
        logDebug("RatingCenter: 处理评分提交 - 评分: \(star)")
        
        // 保存评分数据
        saveScore(star)
        
        // 设置冷却期
        setCooldown()
        
        // 处理高分情况
        handleHighScore(star)
        
        UserDefaults.standard.synchronize()
        logDebug("RatingCenter: 评分提交处理完成")
    }
    
    // MARK: - 保存评分
    private func saveScore(_ score: Int) {
        UserDefaults.standard.set(score, forKey: Keys.lastScore)
        logDebug("RatingCenter: 记录评分: \(score)")
    }
    
    // MARK: - 设置冷却期
    private func setCooldown() {
        let now = Date()
        if let nextTime = Calendar.current.date(byAdding: .day, value: coolDays, to: now) {
            UserDefaults.standard.set(nextTime, forKey: Keys.coolEnd)
            logDebug("RatingCenter: 设置冷却期 - 下次可用时间: \(nextTime)")
        }
    }
    
    // MARK: - 处理评分次数
    private func handleHighScore(_ score: Int) {
        let currentCount = UserDefaults.standard.integer(forKey: Keys.fiveCount)
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: Keys.fiveCount)
        logDebug("RatingCenter: 处理评分次数 - 当前评分次数: \(currentCount) -> \(newCount)")
    }
    
    // MARK: - 注册交互
    func register() {
        let defaults = UserDefaults.standard
        let current = defaults.integer(forKey: Keys.todayCount)
        let new = current + 1
        defaults.set(new, forKey: Keys.todayCount)
        defaults.synchronize()
        logDebug("RatingCenter: 注册交互 - 当前次数: \(current) -> \(new)")
    }
    
    // MARK: - 检查版本和地区
    func checkVersionAndRu() -> Bool {
        let versionList = BaseCFHelper.shared.getIosProfessionalVersions()
        let appVersion = CatKey.getAppVersion()
        
        if let versions = versionList, versions.contains(appVersion) {
            logDebug("RatingCenter: 版本检查通过 - 当前版本: \(appVersion)")
            return true
        }
        
        let isNotRussia = !(CatKey.getCountryCode() == "ru" || CatKey.getLanguageCode() == "ru")
        logDebug("RatingCenter: 地区检查 - 地区: \(CatKey.getCountryCode()), 语言: \(CatKey.getLanguageCode()), 结果: \(isNotRussia)")
        
        return isNotRussia
    }
    
    // MARK: - 重置所有字段（测试用）
    func resetAllData() {
        logDebug("RatingCenter: 开始重置所有数据")
        
        let defaults = UserDefaults.standard
        
        // 清除所有相关字段
        defaults.removeObject(forKey: Keys.coolEnd)
        defaults.removeObject(forKey: Keys.todayCount)
        defaults.removeObject(forKey: Keys.lastScore)
        defaults.removeObject(forKey: Keys.fiveCount)
        defaults.removeObject(forKey: Keys.todayDate)
        
        // 重置连接时间
        connectedTime = nil
        
        // 重置配置为默认值
        coolDays = DefaultParams.coolDays
        maxPopups = DefaultParams.maxPopups
        maxGood = DefaultParams.maxGood
        
        defaults.synchronize()
        
        logDebug("RatingCenter: 所有数据重置完成")
        logDebug("RatingCenter: 重置后状态 - 冷却期: 无, 今日次数: 0, 评分: 无, 评分次数: 0")
    }
    
    // MARK: - 打印所有数据（调试用）
    func printAllData() {
        let defaults = UserDefaults.standard
        
        let coolEnd = defaults.object(forKey: Keys.coolEnd) as? Date
        let todayCount = defaults.integer(forKey: Keys.todayCount)
        let lastScore = defaults.object(forKey: Keys.lastScore) as? Int
        let fiveCount = defaults.integer(forKey: Keys.fiveCount)
        let todayDate = defaults.object(forKey: Keys.todayDate) as? Date
        
        logDebug("RatingCenter: ===== 初始化数据 =====")
        logDebug("RatingCenter: 冷却期结束时间: \(coolEnd?.description ?? "无")")
        logDebug("RatingCenter: 今日弹窗次数: \(todayCount)")
        logDebug("RatingCenter: 最后一次评分: \(lastScore?.description ?? "无")")
        logDebug("RatingCenter: 评分次数: \(fiveCount)")
        logDebug("RatingCenter: 今日日期: \(todayDate?.description ?? "无")")
        logDebug("RatingCenter: 连接开始时间: \(connectedTime?.description ?? "无")")
        logDebug("RatingCenter: 当前配置 - 冷却天数: \(coolDays), 每日最大弹窗: \(maxPopups), 最大好评数: \(maxGood)")
        logDebug("RatingCenter: =========================")
    }
}
