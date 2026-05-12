//
//  ContentView.swift
//  TrueCaddieHost
//
//  Created by user273008 on 5/12/26.
//

import SwiftUI

struct ContentView: View {
    private let bundleResult = Result {
        try HostCourseBundleStore.loadKungsbackaNya()
    }

    var body: some View {
        switch bundleResult {
        case .success(let bundle):
            BundleInspectorView(bundle: bundle)
        case .failure(let error):
            ContentUnavailableView(
                "Course Bundle Missing",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        }
    }
}

#Preview {
    ContentView()
}
