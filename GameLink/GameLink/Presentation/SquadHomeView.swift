import SwiftUI

struct SquadHomeView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text("GameLink")
            .font(.largeTitle.bold())
            .accessibilityAddTraits(.isHeader)

          Text("League of Legends squad planning.")
            .font(.body)
        }

        Divider()

        VStack(alignment: .leading, spacing: 8) {
          Text("Local foundation")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)

          Text("Profile setup and teammate search are not implemented yet.")
            .font(.body)

          Text("No live matching or messaging.")
            .font(.body)
        }
      }
      .foregroundStyle(.primary)
      .frame(maxWidth: 600, alignment: .leading)
      .padding(24)
      .frame(maxWidth: .infinity)
    }
  }
}

#Preview("Light") {
  SquadHomeView()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  SquadHomeView()
    .preferredColorScheme(.dark)
}

#Preview("Large Text") {
  SquadHomeView()
    .environment(\.dynamicTypeSize, .accessibility5)
}
