//
//  AppLogoView.swift
//  Pong
//
//  Created by AI Assistant on 2026/1/4.
//

import SwiftUI

// MARK: - App Logo 视图
struct AppLogoView: View {
    var size: CGFloat = 80
    var showText: Bool = true
    var animated: Bool = true
    
    @State private var isAnimating = false
    @State private var starRotation: Double = 0
    @State private var glowOpacity: Double = 0.5
    
    // 渐变色
    private let gradientColors = [
        Color(red: 0.4, green: 0.6, blue: 1.0),   // 浅蓝
        Color(red: 0.6, green: 0.4, blue: 1.0),   // 紫色
        Color(red: 0.9, green: 0.5, blue: 0.8)    // 粉色
    ]
    
    var body: some View {
        VStack(spacing: size * 0.15) {
            ZStack {
                // 外发光效果
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                gradientColors[1].opacity(glowOpacity * 0.6),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: size * 0.2,
                            endRadius: size * 0.8
                        )
                    )
                    .frame(width: size * 1.6, height: size * 1.6)
                
                // 背景圆形
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: gradientColors[1].opacity(0.5), radius: 10, x: 0, y: 5)
                
                // 内部光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size * 0.9, height: size * 0.9)
                
                // 魔法棒图标
                Image(systemName: "wand.and.stars")
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .white.opacity(0.8), radius: 2, x: 0, y: 0)
                    .rotationEffect(.degrees(isAnimating ? -5 : 5))
                
                // 装饰性星星粒子
                ForEach(0..<6, id: \.self) { index in
                    StarParticle(
                        size: size * 0.08,
                        offset: size * 0.55,
                        angle: Double(index) * 60 + starRotation,
                        delay: Double(index) * 0.1
                    )
                }
            }
            .frame(width: size * 1.6, height: size * 1.6)
            
            // 应用名称
            if showText {
                Text(L10n.shared.appName)
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .onAppear {
            if animated {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        // 魔法棒轻微摇摆
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
        
        // 星星旋转
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            starRotation = 360
        }
        
        // 光晕呼吸效果
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowOpacity = 0.8
        }
    }
}

// MARK: - 星星粒子
struct StarParticle: View {
    let size: CGFloat
    let offset: CGFloat
    let angle: Double
    let delay: Double
    
    @State private var opacity: Double = 0.3
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundColor(.white)
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(
                x: offset * cos(angle * .pi / 180),
                y: offset * sin(angle * .pi / 180)
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    opacity = 1.0
                    scale = 1.2
                }
            }
    }
}

// MARK: - 简化版 Logo（用于小尺寸场景）
struct AppLogoSimple: View {
    var size: CGFloat = 40
    
    private let gradientColors = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.9, green: 0.5, blue: 0.8)
    ]
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Image(systemName: "wand.and.stars")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - 预览
#Preview("Logo - Large") {
    VStack(spacing: 40) {
        AppLogoView(size: 120)
        
        AppLogoView(size: 80, showText: false)
        
        HStack(spacing: 20) {
            AppLogoSimple(size: 60)
            AppLogoSimple(size: 40)
            AppLogoSimple(size: 30)
        }
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Logo - Dark") {
    VStack(spacing: 40) {
        AppLogoView(size: 100)
        AppLogoSimple(size: 50)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
