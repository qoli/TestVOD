//
//  TestVODApp.swift
//  TestVOD
//
//  Created by 黃佁媛 on 2023/2/1.
//

import SwiftUI

@main
struct TestVODApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withHostingWindow { window in
                    #if targetEnvironment(macCatalyst)
                        if let titlebar = window?.windowScene?.titlebar {
                            titlebar.titleVisibility = .hidden
                            titlebar.toolbar = nil
                        }
                    #endif
                }
        }
    }
}

extension View {
    fileprivate func withHostingWindow(_ callback: @escaping (UIWindow?) -> Void) -> some View {
        background(HostingWindowFinder(callback: callback))
    }
}

fileprivate struct HostingWindowFinder: UIViewRepresentable {
    var callback: (UIWindow?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}
