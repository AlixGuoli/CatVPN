//
//  SystemInfoView.swift
//  CatVPN
//
//  Created by Assistant on 2025/8/20.
//

import SwiftUI
import UIKit

struct SystemInfoView: View {
	// MARK: - Computed Info
	private var userUUID: String { CatKey.getUserUUID() }
	private var deviceType: String { UIDevice.current.model }
	private var iosVersion: String { UIDevice.current.systemVersion }
    private var languageCode: String { CatKey.getLanguageCode() }
    private var regionCode: String { CatKey.getCountryCode().uppercased() }
	private var appVersion: String { CatKey.getAppVersion() }

	var body: some View {
		ZStack {
			// 背景与其他页面保持一致的淡雅风格
			LinearGradient(
				gradient: Gradient(colors: [
					Color(.systemBackground),
					Color.green.opacity(0.08),
					Color.mint.opacity(0.06)
				]),
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()

			ScrollView {
				VStack(spacing: 20) {
					header
					infoCard(title: "UUID".localstr(), value: userUUID, icon: "person.text.rectangle", tint: .green)
					infoCard(title: "Device".localstr(), value: deviceType, icon: "iphone", tint: .blue)
					infoCard(title: "iOS".localstr(), value: iosVersion, icon: "gearshape.fill", tint: .teal)
					infoCard(title: "Language".localstr(), value: languageCode, icon: "character.book.closed.fill", tint: .orange)
					infoCard(title: "Region".localstr(), value: regionCode, icon: "globe", tint: .purple)
					infoCard(title: "App Version".localstr(), value: appVersion, icon: "app.badge.fill", tint: .pink)
					Spacer(minLength: 40)
				}
				.padding(.horizontal, 20)
				.padding(.top, 24)
			}
		}
	}

	// MARK: - Header
	private var header: some View {
		VStack(spacing: 6) {
			Text("System Info".localstr())
				.font(.title2)
				.fontWeight(.bold)
				.foregroundColor(.primary)
			Text("Basic device and app information".localstr())
				.font(.footnote)
				.foregroundColor(.secondary)
		}
	}

	// MARK: - Components
	private func infoCard(title: String, value: String, icon: String, tint: Color) -> some View {
		HStack(alignment: .center, spacing: 16) {
			ZStack {
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.fill(.thinMaterial)
					.frame(width: 44, height: 44)
				Image(systemName: icon)
					.font(.headline)
					.foregroundColor(tint)
			}
			VStack(alignment: .leading, spacing: 6) {
				Text(title)
					.font(.caption)
					.foregroundColor(.secondary)
				Text(value)
					.font(.callout)
					.fontWeight(.semibold)
					.foregroundColor(.primary)
					.lineLimit(2)
					.minimumScaleFactor(0.8)
			}
			Spacer()
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 14)
		.background(.regularMaterial)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(
					LinearGradient(
						gradient: Gradient(colors: [
							Color.white.opacity(0.4),
							Color.white.opacity(0.2)
						]),
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.blur(radius: 0.3)
		)
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(
					LinearGradient(
						colors: [Color.white.opacity(0.35), tint.opacity(0.25)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					), lineWidth: 1
				)
		)
		.shadow(color: tint.opacity(0.06), radius: 12, x: 0, y: 6)
	}
}

#Preview {
	SystemInfoView()
}


