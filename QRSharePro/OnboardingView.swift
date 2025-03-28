import ColorfulX
import SwiftUI

struct OnboardingView: View {
	@EnvironmentObject var qrCodeStore: QRCodeStore
	
	@Environment(\.colorScheme) var colorScheme
	@Environment(\.scenePhase) var scenePhase
	
	@AppStorage("isOnboardingDone") private var isOnboardingDone = false
	@AppStorage("playHaptics") private var playHaptics = AppSettings.playHaptics
	@AppStorage("launchTab") private var launchTab = AppSettings.launchTab
	
	@State private var showingPrivacySheet = false
	@State private var showingTabView = true
	@State private var completedStep1 = false
	@State private var isQuickAction = false
	@State private var selection: Tab = .NewQRCode
	@State private var colors: [Color] = [.purple, .indigo, .blue, .brown, .orange, .red]
	@State private var currentPage = 0
	@State private var isDragging = false
	@State private var noise = 50.00
    // New state variables for GitHub stars
	@State private var hasVisitedGitHub = false
	@State private var repoStarCount: Int? = nil
	
	let features = [
		Feature(title: "Share QR Codes from the Share Menu", description: "When you tap the share icon, we easily generate a beautiful QR code that anyone nearby can scan!", image: "square.and.arrow.up"),
		Feature(title: "Scan Securely & Privately", description: "Sus short link? We unshorten it automatically, with trackers removed.", image: "qrcode.viewfinder"),
		Feature(title: "History", description: "See what you’ve scanned, created, and shared.", image: "clock.arrow.circlepath"),
		Feature(title: "Privacy Included", description: "QR Share Pro can operate 100% offline, with all data stored on-device.", image: "checkmark.shield"),
	]
	
	func getImage(tab: Tab) -> String {
		switch tab {
		case .Scanner:
			return "qrcode.viewfinder"
		case .NewQRCode:
			return "plus"
		case .History:
			return "clock.arrow.circlepath"
		}
	}
	
	@EnvironmentObject var sharedData: SharedData
	
	func openURL(_ url: URL) {
		isQuickAction = true
		
		if url.absoluteString.contains("new") {
			selection = .NewQRCode
			sharedData.text = url.queryParameters?["q"] ?? ""
		} else if url.absoluteString.contains("scan") {
			selection = .Scanner
		} else {
			selection = .History
		}
	}
    
    // Function to fetch repo stars count
    private func fetchRepoStars() {
        guard repoStarCount == nil else { return } // Fetch only once
        
        let url = URL(string: "https://api.github.com/repos/Visual-Studio-Coder/QR-Share-Pro")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let starCount = json["stargazers_count"] as? Int {
                        DispatchQueue.main.async {
                            self.repoStarCount = starCount
                        }
                    }
                } catch {
                    print("Error parsing GitHub API response:", error)
                }
            }
        }.resume()
    }
	
	var body: some View {
		VStack {
			ZStack {
				VStack {
					VStack {
						VStack {
							if selection == .Scanner {
								NavigationStack {
									Scanner()
								}
							} else if selection == .NewQRCode {
								Home()
							} else {
								History()
							}
						}
						.onChange(of: selection) { _ in
							if playHaptics {
								let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
								hapticGenerator.impactOccurred()
							}
						}
						.onAppear {
							Task {
								if !isQuickAction {
									selection = launchTab
								}
								
								qrCodeStore.load()
							}
						}
						
						if showingTabView {
							HStack(spacing: 0) {
								ForEach(Tab.allCases, id: \.self) { tab in
									Button {
										withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
											selection = tab
										}
									} label: {
										Image(systemName: getImage(tab: tab))
											.renderingMode(.template)
											.aspectRatio(contentMode: .fit)
											.frame(maxWidth: .infinity)
											.animation(Animation.spring(response: 0.5, dampingFraction: 0.3, blendDuration: 0).delay(0.01), value: selection)
											.foregroundStyle(selection == tab ? Color.accentColor : .gray)
											.scaleEffect(selection == tab ? 2 : 1)
											.bold(selection == tab)
									}
								}
							}
							.frame(maxWidth: .infinity)
							.frame(height: 15)
							.padding(.bottom, 10)
							.padding([.horizontal, .top])
						}
					}
				}
			}
			.transition(.opacity)
			.animation(.easeInOut, value: isOnboardingDone)
			.ignoresSafeArea(.keyboard, edges: .bottom)
			.fullScreenCover(isPresented: .constant(!isOnboardingDone)) {
				ZStack {
					ColorfulView(color: $colors, noise: $noise)
						.ignoresSafeArea()
					VStack {
						TabView(selection: $currentPage) {
							VStack(spacing: 20) {
								ScrollView {
									VStack(spacing: 20) {
                                        Image("QRSharePro-Icon")
											.resizable()
											.frame(width: 150, height: 150)
											.clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
											.accessibilityHidden(true)
											.shadow(color: .accentColor, radius: 15)
											.padding(.top, 20)
										
										VStack {
											Text("QR Share Pro")
												.font(.largeTitle)
												.foregroundStyle(.cyan)
											
											Text("QR codes, done *right*.")
												.font(.headline)
												.foregroundStyle(.white)
										}
										.multilineTextAlignment(.center)
										.font(.largeTitle)
										.bold()
										
										ForEach(features) { feature in
											HStack {
												Image(systemName: feature.image)
													.frame(width: 44)
													.font(.title)
													.foregroundStyle(Color.accentColor)
													.accessibilityHidden(true)
												
												VStack(alignment: .leading) {
													Text("\(feature.title)")
														.foregroundStyle(.white)
														.font(.headline)
														.bold()
													
													if feature.title == "Privacy Included" {
														Button {
															showingPrivacySheet = true
														} label: {
															VStack(alignment: .leading) {
																Text("\(feature.description)")
																	.foregroundStyle(.white.opacity(0.7))
																
																Text("Learn more...")
																	.foregroundStyle(Color.accentColor)
																	.bold()
															}
														}
														.buttonStyle(PlainButtonStyle())
													} else {
														Text("\(feature.description)")
															.foregroundStyle(.white.opacity(0.7))
													}
												}
												.accessibilityElement(children: .combine)
											}
											.frame(maxWidth: .infinity, alignment: .leading)
										}
									}
								}
								.padding(.horizontal)
								
								VStack {
									Button {
										withAnimation {
											currentPage = 1
										}
										let generator = UIImpactFeedbackGenerator(style: .light)
										generator.impactOccurred()
										completedStep1 = true
									} label: {
										Text("Continue")
											.frame(maxWidth: .infinity, minHeight: 44)
											.background(Color.accentColor)
											.foregroundStyle(.white)
											.clipShape(RoundedRectangle(cornerRadius: 10))
											.bold()
											.padding(.horizontal)
									}
									.onLongPressGesture(minimumDuration: 0, pressing: { inProgress in
										if inProgress {
											let generator = UIImpactFeedbackGenerator(style: .soft)
											generator.impactOccurred()
										}
									}, perform: {})
								}
								.sheet(isPresented: $showingPrivacySheet) {
									NavigationStack {
										List {
											Section("Last updated: April 17, 2024") {
												Label("We don't collect anything.", systemImage: "1.circle")
												Label("QR Share Pro stores all data on-device.", systemImage: "2.circle")
												Label("Website favicons are queried through DuckDuckGo.", systemImage: "3.circle")
												Label("Scanned QR code locations are stored on-device. Apple Maps displays the saved coordinates onto a map.", systemImage: "4.circle")
											}
										}
										.navigationTitle("We ❤️ Privacy")
										.toolbar {
											Button("Done") {
												showingPrivacySheet = false
											}
										}
									}
								}
							}
							.tag(0)
                            
                            // New GitHub Star slide
                            VStack(spacing: 25) {
                                Spacer(minLength: 20)
                                
                                Image(systemName: "star.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.yellow)
                                    .padding(.top, 20)
                                
                                Text("Support Open Source")
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("Help me earn the Starstruck badge on GitHub!")
                                    .font(.headline)
                                    .foregroundColor(.yellow)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Your star helps in many ways:")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.bottom, 4)
                                    
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.yellow)
                                            .frame(width: 20, height: 20)
                                        
                                        Text("Makes the app more discoverable")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.yellow)
                                            .frame(width: 20, height: 20)
                                        
                                        Text("Motivates me to add more features")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .padding(.horizontal, 20)
                                
                                Spacer()
                                
                                // Star button with star count bubble
                                Button {
                                    if let url = URL(string: "https://github.com/Visual-Studio-Coder/QR-Share-Pro") {
                                        UIApplication.shared.open(url)
                                        hasVisitedGitHub = true
                                    }
                                } label: {
                                    HStack {
                                        HStack(spacing: 8) {
                                            Image(systemName: "star")
                                                .font(.system(size: 18))
                                                .foregroundColor(.yellow)
                                            
                                            Text("Star Repository")
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Spacer()
                                        
                                        // Star count bubble
                                        if let starCount = repoStarCount {
                                            Text("\(starCount) Stars")
                                                .font(.footnote.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.gray.opacity(0.4))
                                                )
                                        }

                                        // External link indicator
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.black.opacity(0.3))
                                    )
                                }
                                .padding(.horizontal, 20)
                                
                                if hasVisitedGitHub {
                                    // Continue button
                                    Button {
                                        withAnimation {
                                            currentPage = 2
                                        }
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    } label: {
                                        Text("Continue")
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .background(Color.accentColor)
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .bold()
                                            .padding(.horizontal)
                                    }
                                    .onLongPressGesture(minimumDuration: 0, pressing: { inProgress in
                                        if inProgress {
                                            let generator = UIImpactFeedbackGenerator(style: .soft)
                                            generator.impactOccurred()
                                        }
                                    }, perform: {})
                                    .padding(.vertical)
                                } else {
                                    // Skip button
                                    Button {
                                        withAnimation {
                                            currentPage = 2
                                        }
                                    } label: {
                                        Text("Skip for now")
                                            .font(.footnote)
                                            .foregroundColor(.white.opacity(0.6))
                                            .underline()
                                    }
                                    .padding(.bottom, 20)
                                    .padding(.top, 5)
                                }
                            }
                            .onAppear {
                                fetchRepoStars()
                            }
                            .tag(1)
							
							VStack {
								Spacer()
								ScrollView {
									Text("Add QR Share Pro to the Share Menu")
										.foregroundStyle(.white)
										.font(.title)
										.bold()
										.multilineTextAlignment(.center)
									
									Text("Quickly share text & URLs with QR codes by accessing it directly from the share menu!")
										.font(.subheadline)
										.multilineTextAlignment(.center)
										.foregroundStyle(.white)
										.padding(.horizontal, 50)
										.padding(.bottom, 10)
									
									Image("QR-share-sheet")
										.resizable()
										.clipShape(RoundedRectangle(cornerRadius: 16))
										.scaledToFit()
										.padding(.horizontal, 50)
										.shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
									
									ShareLink(item: "https://apps.apple.com/us/app/qr-share-pro/id6479589995/") {
										HStack {
											Spacer()
											Label("Show Share Menu", systemImage: "square.and.arrow.up")
												.bold()
												.padding()
											Spacer()
										}
									}
										.background(Color.white)
										.clipShape(RoundedRectangle(cornerRadius: 18))
										.padding(.horizontal, 50)
										.padding(.vertical, 10)
										.shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
									
									VStack(spacing: 16) {
										// Step 1
										HStack(alignment: .top, spacing: 16) {
											Text("1")
												.font(.system(size: 18, weight: .bold))
												.foregroundStyle(.white)
												.frame(width: 28, height: 28)
												.background(
													Circle()
														.fill(Color.white.opacity(0.15))
														.overlay(
															Circle()
																.stroke(Color.white.opacity(0.5), lineWidth: 1)
														)
												)
											
											VStack(alignment: .leading) {
                                                Text("Tap **Show Share Menu**")
													.font(.headline)
													.foregroundStyle(.white)
												
                                                Text("Scroll right and tap on **More** \(Image(systemName: "ellipsis.circle"))")
													.font(.subheadline)
													.foregroundStyle(.white.opacity(0.8))
											}
											
											Spacer()
										}
											.padding(.vertical, 8)
											.padding(.horizontal, 16)
											.background(
												RoundedRectangle(cornerRadius: 16)
													.fill(Color.white.opacity(0.1))
													.overlay(
														RoundedRectangle(cornerRadius: 16)
															.stroke(Color.white.opacity(0.2), lineWidth: 1)
													)
											)
										
										// Step 2
										HStack(alignment: .top, spacing: 16) {
											Text("2")
												.font(.system(size: 18, weight: .bold))
												.foregroundStyle(.white)
												.frame(width: 28, height: 28)
												.background(
													Circle()
														.fill(Color.white.opacity(0.15))
														.overlay(
															Circle()
																.stroke(Color.white.opacity(0.5), lineWidth: 1)
														)
												)
											
											VStack(alignment: .leading) {
												Text("Edit your share menu")
													.font(.headline)
													.foregroundStyle(.white)
												
												Text("Tap on **Edit** in the top right corner")
													.font(.subheadline)
													.foregroundStyle(.white.opacity(0.8))
											}
											
											Spacer()
										}
											.padding(.vertical, 8)
											.padding(.horizontal, 16)
											.background(
												RoundedRectangle(cornerRadius: 16)
													.fill(Color.white.opacity(0.1))
													.overlay(
														RoundedRectangle(cornerRadius: 16)
															.stroke(Color.white.opacity(0.2), lineWidth: 1)
													)
											)
										
										// Step 3
										HStack(alignment: .top, spacing: 16) {
											Text("3")
												.font(.system(size: 18, weight: .bold))
												.foregroundStyle(.white)
												.frame(width: 28, height: 28)
												.background(
													Circle()
														.fill(Color.white.opacity(0.15))
														.overlay(
															Circle()
																.stroke(Color.white.opacity(0.5), lineWidth: 1)
														)
												)
											
											VStack(alignment: .leading) {
												Text("Add QR Share Pro")
													.font(.headline)
													.foregroundStyle(.white)
												
												Text("Add and re-order it to the top for easy access")
													.font(.subheadline)
													.foregroundStyle(.white.opacity(0.8))
											}
											
											Spacer()
										}
											.padding(.vertical, 8)
											.padding(.horizontal, 16)
											.background(
												RoundedRectangle(cornerRadius: 16)
													.fill(Color.white.opacity(0.1))
													.overlay(
														RoundedRectangle(cornerRadius: 16)
															.stroke(Color.white.opacity(0.2), lineWidth: 1)
													)
											)
									}
										.padding(.horizontal, 20)
										.padding(.vertical, 10)
									
									Spacer()
								}
								Button {
									withAnimation(.easeInOut) {
										isOnboardingDone = true
									}
									currentPage = 0
									
									completedStep1 = false
									let generator = UIImpactFeedbackGenerator(style: .light)
									generator.impactOccurred()
								} label: {
									Text("Get Started")
										.frame(maxWidth: .infinity, minHeight: 44)
										.background(Color.accentColor)
										.foregroundStyle(.white)
										.clipShape(RoundedRectangle(cornerRadius: 10))
										.bold()
										.padding(.horizontal)
								}
									.shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
									.padding(.vertical, 20)
									.onLongPressGesture(minimumDuration: 0, pressing: { inProgress in
										if inProgress {
											let generator = UIImpactFeedbackGenerator(style: .soft)
											generator.impactOccurred()
										}
									}, perform: {})
							}
								.tag(2)
						}
							.tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // hide the built-in page indicator
					}
				}
					.transition(.opacity)
					.animation(.easeInOut, value: !isOnboardingDone)
			}
		}
			.onOpenURL(perform: openURL)
	}
}
