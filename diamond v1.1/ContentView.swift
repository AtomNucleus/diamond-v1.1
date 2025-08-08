import SwiftUI
import Combine
import SafariServices

struct ContentView: View {
    @State private var selectedPeriod: TimePeriod = .day
    @StateObject private var spendVM = SpendViewModel()
    
    // New state for settings menu and drag gesture
    @State private var dragOffset: CGFloat = 0
    @State private var showSettings: Bool = false
    @State private var isDarkMode: Bool = true
    
    // Backend endpoints
    private let backendURL = URL(string: "https://diamond-v1-1.onrender.com")!
    private var authURL_Endpoint: URL { backendURL.appendingPathComponent("/teller/auth_url") }

    // Exchange authorization code for access token
    private func exchangeCode(_ code: String) {
        let exchangeEndpoint = backendURL.appendingPathComponent("/teller/exchange_code")
        var request = URLRequest(url: exchangeEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["code": code]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Exchange error: \(error)")
                return
            }
            guard let http = response as? HTTPURLResponse else {
                print("Exchange: no HTTP response")
                return
            }
            print("Exchange status: \(http.statusCode)")
            let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            print("Exchange body: \(bodyString)")
        }.resume()
    }

    var body: some View {
        ZStack {
            adaptiveBackground
                .edgesIgnoringSafeArea(.all)
                .preferredColorScheme(isDarkMode ? .dark : .light)

            // Settings icon (revealed by drag)
            if dragOffset < -30 && !showSettings {
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        NeumorphicSettingsIcon(isDarkMode: isDarkMode)
                            .opacity(min(Double((-dragOffset - 30)/70), 1.0))
                            .scaleEffect(0.9 + min(CGFloat((-dragOffset - 30)/120), 0.2))
                            .padding(.trailing, 28)
                            .padding(.top, 60)
                        Spacer()
                    }
                }
                .transition(.move(edge: .trailing))
            }

            // Main neumorphic card (restored original layout)
            HStack {
                VStack(spacing: 38) {
                    // Title
                    Text(titleText)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(adaptiveTitleColor)
                        .shadow(color: adaptiveTitleShadow, radius: 8, x: 0, y: 6)
                        .padding(.top, 12)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    // NEUMORPHIC GLOWING CIRCLE
                    NeumorphicCircle(isDarkMode: isDarkMode)
                        .padding(.bottom, 8)
                    // PERIOD BUTTONS (vertical)
                    VStack(spacing: 18) {
                        NeumorphicPeriodButton(title: "Month", amount: spendVM.monthly, isSelected: selectedPeriod == .month, isDarkMode: isDarkMode)
                            .onTapGesture { selectedPeriod = .month }
                        NeumorphicPeriodButton(title: "Week", amount: spendVM.weekly, isSelected: selectedPeriod == .week, isDarkMode: isDarkMode)
                            .onTapGesture { selectedPeriod = .week }
                        NeumorphicPeriodButton(title: "Day", amount: spendVM.daily, isSelected: selectedPeriod == .day, isDarkMode: isDarkMode)
                            .onTapGesture { selectedPeriod = .day }
                    }
                    .padding(.bottom, 8)
                    Button(action: { openTellerConnect() }) {
                        Text("Connect Bank with Teller")
                            .fontWeight(.bold)
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(14)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 2)
                    }
                }
                .padding(36)
                .background(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(adaptiveCardColor)
                        .shadow(color: adaptiveCardShadow1, radius: 36, x: 0, y: 18)
                        .shadow(color: adaptiveCardShadow2, radius: 22, x: 0, y: 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(adaptiveCardBorder, lineWidth: 1.5)
                )
                .padding(24)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !showSettings {
                                dragOffset = min(0, value.translation.width)
                            }
                        }
                        .onEnded { value in
                            if dragOffset < -100 {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    showSettings = true
                                    dragOffset = 0
                                }
                            } else {
                                withAnimation(.easeOut) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .blur(radius: showSettings ? 10 : 0)
                .animation(.easeInOut, value: showSettings)
                Spacer(minLength: 0)
            }
            .animation(.easeInOut, value: dragOffset)

            // Settings Menu Overlay
            if showSettings {
                Color.black.opacity(0.45)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeInOut) { showSettings = false }
                    }
                SettingsMenuCard(isDarkMode: $isDarkMode, onClose: {
                    withAnimation(.easeInOut) { showSettings = false }
                })
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }
        }
        .onAppear { Task { await spendVM.refresh() } }
        .onOpenURL(perform: { url in
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let queryItems = components.queryItems,
                  let code = queryItems.first(where: { $0.name == "code" })?.value else {
                return
            }
            exchangeCode(code)
        })
    }

    private func openTellerConnect() {
        var request = URLRequest(url: authURL_Endpoint)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let authURLString = json["authURL"] as? String,
               let authURL = URL(string: authURLString) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(authURL)
                }
            }
        }.resume()
    }

    // MARK: - Adaptive Colors & Shadows
    private var adaptiveBackground: Color {
        isDarkMode ? Color(red: 0.07, green: 0.09, blue: 0.11) : Color(red: 0.97, green: 0.98, blue: 1.0)
    }
    private var adaptiveCardColor: Color {
        isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.13) : Color.white.opacity(0.72)
    }
    private var adaptiveCardShadow1: Color {
        isDarkMode ? Color.black.opacity(0.75) : Color.white.opacity(0.8)
    }
    private var adaptiveCardShadow2: Color {
        isDarkMode ? Color.blue.opacity(0.13) : Color(red: 0.62, green: 0.86, blue: 1.0, opacity: 0.18)
    }
    private var adaptiveCardBorder: Color {
        isDarkMode ? Color.white.opacity(0.04) : Color(red: 0.82, green: 0.88, blue: 0.95, opacity: 0.45)
    }
    private var adaptiveTitleColor: Color {
        isDarkMode ? Color.gray.opacity(0.93) : Color(red: 0.38, green: 0.44, blue: 0.53)
    }
    private var adaptiveTitleShadow: Color {
        isDarkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.9)
    }

    private var titleText: String {
        switch selectedPeriod {
        case .month:
            return "Monthly Spending"
        case .week:
            return "Weekly Spending"
        case .day:
            return "Daily Spending"
        }
    }
}

// MARK: - Neumorphic Subcomponents

struct NeumorphicCircle: View {
    let isDarkMode: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.13) : Color.white.opacity(0.82))
                .frame(width: 162, height: 162)
                .shadow(color: isDarkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.95), radius: 28, x: 12, y: 12)
                .shadow(color: isDarkMode ? Color.white.opacity(0.13) : Color(red: 0.62, green: 0.86, blue: 1.0, opacity: 0.19), radius: 18, x: -10, y: -10)
            Circle()
                .stroke(
                    isDarkMode
                        ? LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                        : LinearGradient(gradient: Gradient(colors: [Color(red: 0.72, green: 0.86, blue: 1.0), Color(red: 0.83, green: 0.84, blue: 1.0)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    , lineWidth: 5)
                .frame(width: 152, height: 152)
                .blur(radius: isDarkMode ? 0 : 2)
                .shadow(color: isDarkMode ? Color.blue.opacity(0.5) : Color(red: 0.72, green: 0.86, blue: 1.0, opacity: 0.33), radius: 14, x: 0, y: 0)
            Circle()
                .stroke(
                    isDarkMode
                        ? LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.33), Color.blue.opacity(0.33)]), startPoint: .top, endPoint: .bottom)
                        : LinearGradient(gradient: Gradient(colors: [Color(red: 0.72, green: 0.86, blue: 1.0), Color(red: 0.83, green: 0.84, blue: 1.0)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    , lineWidth: 6)
                .frame(width: 144, height: 144)
                .rotationEffect(.degrees(30))
                .blur(radius: isDarkMode ? 0.5 : 1.5)
        }
    }
}

struct NeumorphicPeriodButton: View {
    let title: String
    let amount: Double
    let isSelected: Bool
    let isDarkMode: Bool
    var body: some View {
        let background: some View = RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isDarkMode
                ? LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.13, blue: 0.16), Color(red: 0.11, green: 0.13, blue: 0.16)]), startPoint: .top, endPoint: .bottom)
                : LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.72), Color.white.opacity(0.72)]), startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: isDarkMode ? Color.black.opacity(0.38) : Color.white.opacity(0.8), radius: isSelected ? 16 : 10, x: 6, y: 8)
            .shadow(color: isDarkMode ? Color.white.opacity(0.07) : Color(red: 0.62, green: 0.86, blue: 1.0, opacity: 0.17), radius: isSelected ? 8 : 5, x: -4, y: -4)
        let selectedOverlay: some View =
            isSelected ? RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDarkMode
                    ? LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.22), Color.blue.opacity(0.09)]), startPoint: .top, endPoint: .bottom)
                    : LinearGradient(gradient: Gradient(colors: [Color(red: 0.62, green: 0.86, blue: 1.0), Color(red: 0.83, green: 0.84, blue: 1.0)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: isDarkMode ? Color.blue.opacity(0.22) : Color(red: 0.72, green: 0.86, blue: 1.0, opacity: 0.23), radius: 18, x: 0, y: 0)
            : nil
        let border: some View = RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(isSelected ? (isDarkMode ? Color.blue.opacity(0.6) : Color(red: 0.62, green: 0.86, blue: 1.0, opacity: 0.7)) : (isDarkMode ? Color.white.opacity(0.04) : Color(red: 0.82, green: 0.88, blue: 0.95, opacity: 0.45)), lineWidth: isSelected ? 2 : 1)
        return HStack {
            Text(title)
                .font(.system(size: 23, weight: .semibold))
                .foregroundColor(isDarkMode ? Color.gray.opacity(0.85) : Color(red: 0.38, green: 0.44, blue: 0.53))
                .shadow(color: isDarkMode ? Color.black.opacity(0.13) : Color.white.opacity(0.7), radius: 1, x: 1, y: 1)
            Spacer()
            Text("$\(Int(amount))")
                .font(.system(size: 27, weight: .bold))
                .foregroundColor(isSelected ? (isDarkMode ? Color(red: 0.42, green: 0.92, blue: 1.0) : Color(red: 0.38, green: 0.44, blue: 0.93)) : (isDarkMode ? Color(red: 0.72, green: 0.92, blue: 1) : Color(red: 0.38, green: 0.44, blue: 0.53)))
                .shadow(color: isSelected ? (isDarkMode ? Color.blue.opacity(0.7) : Color(red: 0.72, green: 0.86, blue: 1.0, opacity: 0.33)) : Color.clear, radius: 10, x: 0, y: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 13)
        .background(
            ZStack {
                background
                if isSelected { selectedOverlay }
            }
        )
        .overlay(border)
        .padding(.horizontal, 2)
    }
}

struct NeumorphicSettingsIcon: View {
    var isDarkMode: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.13) : Color.white.opacity(0.97))
                .frame(width: 56, height: 56)
                .shadow(color: isDarkMode ? Color.black.opacity(0.7) : Color.white.opacity(0.8), radius: 10, x: 6, y: 6)
                .shadow(color: isDarkMode ? Color.white.opacity(0.13) : Color(red: 0.62, green: 0.86, blue: 1.0, opacity: 0.17), radius: 4, x: -3, y: -3)
            Image(systemName: "gearshape.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color.blue.opacity(0.78))
                .shadow(color: Color.blue.opacity(0.7), radius: 12, x: 0, y: 0)
        }
    }
}

// MARK: - Settings Menu Card
struct SettingsMenuCard: View {
    @Binding var isDarkMode: Bool
    var onClose: () -> Void
    var body: some View {
        let darkModeRow = HStack {
            Text("Dark Mode")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isDarkMode ? Color.gray.opacity(0.93) : Color(red: 0.38, green: 0.44, blue: 0.53))
            Spacer()
            NeumorphicToggle(isOn: $isDarkMode, isDarkMode: isDarkMode)
        }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(isDarkMode ? Color.gray.opacity(0.95) : Color(red: 0.38, green: 0.44, blue: 0.53))
                    .shadow(color: isDarkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.9), radius: 8, x: 0, y: 6)
                    .padding(.top, 8)
                Spacer()
                Button(action: onClose) {
                    ZStack {
                        Circle()
                            .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.13) : Color.white.opacity(0.92))
                            .frame(width: 38, height: 38)
                            .shadow(color: isDarkMode ? Color.blue.opacity(0.7) : Color.white.opacity(0.7), radius: 8, x: 0, y: 0)
                            .shadow(color: isDarkMode ? Color.white.opacity(0.15) : Color(red: 0.62, green: 0.86, blue: 1.0, opacity: 0.17), radius: 4, x: -2, y: -2)
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isDarkMode ? Color.blue.opacity(0.95) : Color(red: 0.38, green: 0.44, blue: 0.93))
                            .shadow(color: isDarkMode ? Color.blue.opacity(0.7) : Color.white.opacity(0.7), radius: 8, x: 0, y: 0)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.82, green: 0.88, blue: 0.95, opacity: 0.45))
                .padding(.horizontal, 18)
                .padding(.top, 10)
            darkModeRow
                .padding(.horizontal, 28)
                .padding(.vertical, 30)
            Spacer(minLength: 0)
        }
        .frame(width: 330, height: 230)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.13) : Color.white.opacity(0.72))
                .shadow(color: isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.85), radius: 32, x: 10, y: 18)
                .shadow(color: isDarkMode ? Color.blue.opacity(0.13) : Color(red: 0.62, green: 0.86, blue: 1.0, opacity: 0.18), radius: 18, x: 0, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(isDarkMode ? Color.white.opacity(0.06) : Color(red: 0.82, green: 0.88, blue: 0.95, opacity: 0.45), lineWidth: 1.5)
        )
        .padding(.top, 90)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .transition(.move(edge: .trailing))
        .animation(.spring(response: 0.44, dampingFraction: 0.84), value: isDarkMode)
    }
}

struct NeumorphicToggle: View {
    @Binding var isOn: Bool
    var isDarkMode: Bool
    var body: some View {
        let toggleBackground: some View = Capsule()
            .fill(isDarkMode ? Color(red: 0.11, green: 0.13, blue: 0.16) : Color.white.opacity(0.97))
            .frame(width: 64, height: 34)
            .shadow(color: isDarkMode ? Color.white.opacity(0.11) : Color.white.opacity(0.8), radius: 4, x: -2, y: -2)
            .shadow(color: isDarkMode ? Color.black.opacity(0.42) : Color(red: 0.62, green: 0.86, blue: 1.0, opacity: 0.17), radius: 8, x: 4, y: 6)
            .overlay(
                Capsule()
                    .strokeBorder(isOn ? Color.blue.opacity(0.7) : Color(red: 0.82, green: 0.88, blue: 0.95, opacity: 0.45), lineWidth: 2)
                    .shadow(color: isOn ? Color.blue.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 0)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    .blur(radius: 0.6)
            )
        
        // Break down the complex fill into separate variables
        let activeGradient = LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Convert solid colors to consistent gradients for type matching
        let inactiveDarkModeFill = LinearGradient(
            gradient: Gradient(colors: [Color(red: 0.19, green: 0.21, blue: 0.25), Color(red: 0.19, green: 0.21, blue: 0.25).opacity(0.92)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        let inactiveLightModeFill = LinearGradient(
            gradient: Gradient(colors: [Color.white, Color.white.opacity(0.95)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Extract shadows into separate variables
        let primaryShadow = isOn ? Color.blue.opacity(0.7) : Color.black.opacity(0.23)
        let secondaryShadow = isOn ? Color.blue.opacity(0.5) : Color.clear
        
        // Extract overlays into separate variables
        let borderOverlay: some View = Circle()
            .stroke(isOn ? Color.blue.opacity(0.8) : Color(red: 0.82, green: 0.88, blue: 0.95, opacity: 0.45), lineWidth: 2)
        
        let highlightOverlay: some View = Circle()
            .stroke(Color.white.opacity(0.13), lineWidth: 1)
            .blur(radius: 0.7)
        
        let innerShadowColor = Color.black.opacity(isOn ? 0.13 : 0.23)
        let innerShadowMask = LinearGradient(
            gradient: Gradient(colors: [Color.black, Color.clear]), 
            startPoint: .bottom, 
            endPoint: .top
        )
        
        let innerShadowOverlay: some View = Circle()
            .stroke(innerShadowColor, lineWidth: 3)
            .blur(radius: 2)
            .offset(y: 1.5)
            .mask(Circle().fill(innerShadowMask))
        
        // Build the knob with extracted variables
        let knob: some View = Circle()
            .fill(isOn ? activeGradient : (isDarkMode ? inactiveDarkModeFill : inactiveLightModeFill))
            .frame(width: 28, height: 28)
            .shadow(color: primaryShadow, radius: 12, x: 0, y: 0)
            .shadow(color: secondaryShadow, radius: 18, x: 0, y: 0)
            .overlay(borderOverlay)
            .overlay(highlightOverlay)
            .overlay(innerShadowOverlay)
            .offset(x: isOn ? 15 : -15)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isOn)
        
        return ZStack {
            toggleBackground
            knob
        }
        .frame(width: 64, height: 34)
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isOn.toggle()
            }
        }
    }
}

enum TimePeriod {
    case month, week, day
}

// Model for spend summary JSON
struct SpendSummary: Codable {
    struct Daily: Codable { let date: String; let total: Double }
    struct Weekly: Codable { let start: String; let end: String; let total: Double }
    struct Monthly: Codable { let year: Int; let month: Int; let total: Double }
    let daily: Daily
    let weekly: Weekly
    let monthly: Monthly
}

// ViewModel to fetch spend summary
class SpendViewModel: ObservableObject {
    @Published var daily: Double = 0.0
    @Published var weekly: Double = 0.0
    @Published var monthly: Double = 0.0

    private let backendURL = URL(string: "https://diamond-v1-1.onrender.com")!
    private var summaryEndpoint: URL { backendURL.appendingPathComponent("spend_summary") }

    func refresh() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: summaryEndpoint)
            if let http = response as? HTTPURLResponse {
                print("🚀 spend_summary status: \(http.statusCode)")
            }
            if let raw = String(data: data, encoding: .utf8) {
                print("📡 spend_summary raw: \(raw)")
            }
            let summary = try JSONDecoder().decode(SpendSummary.self, from: data)
            await MainActor.run {
                self.daily = summary.daily.total
                self.weekly = summary.weekly.total
                self.monthly = summary.monthly.total
            }
        } catch {
            print("⚠️ spend fetch failed", error)
        }
    }
}

#Preview {
    ContentView()
}
