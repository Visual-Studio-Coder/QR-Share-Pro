import SwiftUI

struct SettingsBoxView: View {
	var icon: String
	var style: Color = .white
	var color: Color
	
	var body: some View {
		Image(systemName: icon)
			.resizable()
			.scaledToFit()
			.frame(width: 20, height: 20)
			.padding()
			.background(color)
			.foregroundStyle(style)
			.frame(width: 30, height: 30)
			.clipShape(RoundedRectangle(cornerRadius: 6))
	}
}

#Preview {
	SettingsBoxView(icon: "cpu", color: .pink)
}
