//  Jonathan Ritchey

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Simple", systemImage: "1.circle") {
                SimpleExampleView()
            }

            Tab("Advanced", systemImage: "2.circle") {
                AdvancedExampleView()
            }
        }
    }
}

#Preview {
    ContentView()
}
