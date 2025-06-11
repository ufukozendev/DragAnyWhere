//
//  ContentView.swift
//  AnyDrag
//
//  Created by luckymac on 11.06.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var windowDragManager = WindowDragManager()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cursor.rays")
                .imageScale(.large)
                .foregroundStyle(.blue)
                .font(.system(size: 48))

            Text("AnyDrag")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Cmd tuşunu basılı tutup mouse'u hareket ettirerek herhangi bir pencereyi sürükleyin")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 15) {
                HStack {
                    Image(systemName: windowDragManager.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(windowDragManager.hasAccessibilityPermission ? .green : .red)
                    Text("Accessibility İzni")
                    Spacer()
                }

                if !windowDragManager.hasAccessibilityPermission {
                    Button("İzin Ver") {
                        windowDragManager.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack {
                    Image(systemName: windowDragManager.isEnabled ? "play.circle.fill" : "pause.circle.fill")
                        .foregroundColor(windowDragManager.isEnabled ? .green : .orange)
                    Text("Pencere Sürükleme")
                    Spacer()
                }

                HStack {
                    Button(windowDragManager.isEnabled ? "Durdur" : "Başlat") {
                        if windowDragManager.isEnabled {
                            windowDragManager.stopMonitoring()
                        } else {
                            windowDragManager.startMonitoring()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!windowDragManager.hasAccessibilityPermission)

                    Button("İzinleri Kontrol Et") {
                        windowDragManager.checkAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Nasıl Kullanılır:")
                    .font(.headline)

                Text("1. Accessibility izni verin")
                Text("2. 'Başlat' butonuna tıklayın")
                Text("3. Cmd tuşunu basılı tutun")
                Text("4. Mouse'u hareket ettirin - pencere otomatik takip eder")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            windowDragManager.checkAccessibilityPermission()
        }
    }
}

#Preview {
    ContentView()
}
