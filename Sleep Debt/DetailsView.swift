import SwiftUI

struct DetailsView: View {
    @Environment(AppState.self) private var appState
    @State private var range: Int = 14

    var body: some View {
        VStack {
            Picker("Range", selection: $range) {
                Text("7").tag(7)
                Text("14").tag(14)
                Text("30").tag(30)
                Text("60").tag(60)
                Text("90").tag(90)
            }
            .pickerStyle(.segmented)
            List {
                ForEach(appState.chartPoints, id: \.date) { point in
                    HStack {
                        Text(point.date, style: .date)
                        Spacer()
                        Text("\(point.debtMinutes) min")
                    }
                }
            }
        }
        .padding()
        .onAppear { appState.refresh() }
    }
}

#Preview {
    DetailsView()
        .environment(AppState(container: try! ModelContainer(for: SleepDebtSchemaV1.self)))
}
