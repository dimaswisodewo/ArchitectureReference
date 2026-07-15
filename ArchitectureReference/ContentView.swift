//
//  ContentView.swift
//  ArchitectureReference
//
//  Created by Meynabel Dimas Wisodewo on 15/07/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Architecture Reference Sandbox")
                .font(.headline)
            
            Text("This app is bootstrapped using UIKit's Coordinator pattern. The main flow starts in ArchitectureReferenceApp.swift and displays the Profile feature.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
