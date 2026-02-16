import SwiftUI

struct RootTabView: View {
	@State private var selectedTab: Int = 1
	@State private var showTrollStoreDetectedAlert = false
	@State private var didCheckTrollStoreOnLaunch = false

    init() {
        _selectedTab = State(initialValue: 1)
        
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

	var body: some View {
		TabView(selection: $selectedTab) {
			NavigationView {
				ServerManagerView()
			}
			.navigationViewStyle(StackNavigationViewStyle())
			.tag(0)
			.tabItem {
				Label("Servers", systemImage: "folder")
			}

			NavigationView {
				LaunchView()
			}
			.navigationViewStyle(StackNavigationViewStyle())
			.tag(1)
			.tabItem {
				Label("Launch", systemImage: "play")
			}

			NavigationView {
				SettingsView()
			}
			.navigationViewStyle(StackNavigationViewStyle())
			.tag(2)
			.tabItem {
				Label("Settings", systemImage: "gear")
			}
		}
		.accentColor(.green)
		.onAppear {
			if !didCheckTrollStoreOnLaunch {
				didCheckTrollStoreOnLaunch = true
				showTrollStoreDetectedAlert = jessi_is_trollstore_installed()
			}

			TunnelingModel.autoInstallPlayitIfNeeded()
		}
		.alert(isPresented: $showTrollStoreDetectedAlert) {
			Alert(
				title: Text("TrollStore Detected"),
				message: Text("JESSI detected a TrollStore installation on this device. This is a test popup for TrollStore detection."),
				dismissButton: .default(Text("OK"))
			)
		}
	}
}
