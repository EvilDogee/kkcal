import SwiftUI
import Vision
import UIKit

@main
struct CalorieLensApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct FoodItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let calories: Int
    let symbol: String
    let tint: Color
}

struct ContentView: View {
    @State private var showingCamera = false
    @State private var photo: UIImage?
    @State private var isAnalyzing = false
    @State private var detectedFood: FoodItem?
    @State private var showCameraError = false
    @State private var eaten = 1240

    private let goal = 2100
    private let foods = [
        FoodItem(name: "Овсяная каша", detail: "Завтрак · 250 г", calories: 320, symbol: "takeoutbag.and.cup.and.straw.fill", tint: Color(red: 0.97, green: 0.77, blue: 0.48)),
        FoodItem(name: "Лосось с овощами", detail: "Обед · 320 г", calories: 540, symbol: "fish.fill", tint: Color(red: 0.99, green: 0.62, blue: 0.53)),
        FoodItem(name: "Яблоко", detail: "Перекус · 1 шт.", calories: 95, symbol: "apple.logo", tint: Color(red: 0.91, green: 0.43, blue: 0.39))
    ]

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    header
                    calorieCard
                    cameraCard
                    mealsSection
                    tipCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $photo, onCancel: { showingCamera = false }, onCapture: {
                showingCamera = false
                if let photo { analyze(photo) }
            })
            .ignoresSafeArea()
        }
        .sheet(item: $detectedFood) { item in
            AnalysisResultView(item: item, image: photo, onAdd: {
                eaten += item.calories
                detectedFood = nil
                photo = nil
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Камера недоступна", isPresented: $showCameraError) {
            Button("Понятно", role: .cancel) { }
        } message: {
            Text("Разрешите приложению доступ к камере в настройках устройства.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("СУББОТА, 24 ОКТЯБРЯ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1).foregroundStyle(.secondary)
                Text("Мой рацион")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.17, blue: 0.14))
            }
            Spacer()
            ZStack {
                Circle().fill(Color.white).frame(width: 48, height: 48)
                Image(systemName: "leaf.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color(red: 0.20, green: 0.54, blue: 0.37))
            }
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
    }

    private var calorieCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("КАЛОРИИ СЕГОДНЯ", systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Image(systemName: "ellipsis").foregroundStyle(.white.opacity(0.72))
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(eaten.formatted()).font(.system(size: 47, weight: .bold, design: .rounded)).contentTransition(.numericText())
                Text("ккал").font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.76))
                Spacer()
                Text("из \(goal.formatted())").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.72))
            }
            VStack(spacing: 9) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.20))
                        Capsule().fill(Color(red: 0.78, green: 0.91, blue: 0.68)).frame(width: proxy.size.width * min(CGFloat(eaten) / CGFloat(goal), 1))
                    }
                }.frame(height: 9)
                HStack {
                    Text("Осталось \(max(goal - eaten, 0)) ккал")
                    Spacer()
                    Text("\(Int(Double(eaten) / Double(goal) * 100))%")
                }.font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.78))
            }
            HStack(spacing: 0) {
                macro("Белки", value: "68 г", progress: 0.62)
                Spacer()
                macro("Жиры", value: "42 г", progress: 0.47)
                Spacer()
                macro("Углеводы", value: "130 г", progress: 0.71)
            }.padding(.top, 2)
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [Color(red: 0.16, green: 0.48, blue: 0.34), Color(red: 0.10, green: 0.34, blue: 0.27)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(red: 0.13, green: 0.39, blue: 0.30).opacity(0.22), radius: 18, y: 9)
    }

    private func macro(_ title: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundStyle(.white.opacity(0.58))
            Text(value).font(.system(size: 14, weight: .semibold, design: .rounded))
            Capsule().fill(.white.opacity(0.18)).frame(width: 64, height: 3).overlay(alignment: .leading) {
                Capsule().fill(Color(red: 0.78, green: 0.91, blue: 0.68)).frame(width: 64 * progress, height: 3)
            }
        }
    }

    private var cameraCard: some View {
        Button {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { showCameraError = true; return }
            showingCamera = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(red: 0.88, green: 0.95, blue: 0.87)).frame(width: 58, height: 58)
                    if isAnalyzing {
                        ProgressView().tint(Color(red: 0.15, green: 0.45, blue: 0.31))
                    } else {
                        Image(systemName: "camera.fill").font(.system(size: 23, weight: .semibold)).foregroundStyle(Color(red: 0.15, green: 0.45, blue: 0.31))
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(isAnalyzing ? "Анализируем фото…" : "Сфотографировать еду")
                        .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
                    Text("ИИ определит блюдо и оценит калории")
                        .font(.system(size: 12, weight: .regular)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .bold)).foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzing)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Сегодня в меню").font(.system(size: 21, weight: .bold, design: .rounded))
                Spacer()
                Button("Все") { }.font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(red: 0.17, green: 0.49, blue: 0.34))
            }
            VStack(spacing: 0) {
                ForEach(Array(foods.enumerated()), id: \.element.id) { index, food in
                    HStack(spacing: 13) {
                        RoundedRectangle(cornerRadius: 15, style: .continuous).fill(food.tint.opacity(0.18)).frame(width: 48, height: 48)
                            .overlay { Image(systemName: food.symbol).font(.system(size: 19, weight: .medium)).foregroundStyle(food.tint) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(food.name).font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(food.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(food.calories) ккал").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
                    }.padding(.vertical, 12)
                    if index != foods.count - 1 { Divider().padding(.leading, 61) }
                }
            }
            .padding(.horizontal, 14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(red: 0.82, green: 0.57, blue: 0.20)).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Подсказка дня").font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("Добавьте больше овощей — клетчатка помогает дольше сохранять сытость.").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1.0, green: 0.96, blue: 0.86))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func analyze(_ image: UIImage) {
        isAnalyzing = true
        photo = image
        Task.detached(priority: .userInitiated) {
            let result = await FoodVisionAnalyzer.analyze(image)
            await MainActor.run {
                isAnalyzing = false
                detectedFood = result
            }
        }
    }
}

struct AnalysisResultView: View {
    let item: FoodItem
    let image: UIImage?
    let onAdd: () -> Void
    @State private var serving = 1.0

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.secondary.opacity(0.25)).frame(width: 38, height: 5).padding(.top, 10)
            HStack(spacing: 15) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 18))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Label("РАСПОЗНАНО ИИ", systemImage: "sparkles").font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Color(red: 0.18, green: 0.52, blue: 0.36))
                    Text(item.name).font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(item.detail).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Оценка калорий").font(.system(size: 13)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Int(Double(item.calories) * serving).formatted()).font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("ккал").font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Stepper("Порция \(serving, specifier: "%.1f")×", value: $serving, in: 0.5...3, step: 0.5).labelsHidden()
                Text("\(serving, specifier: "%.1f")×").font(.system(size: 14, weight: .semibold)).frame(width: 35)
            }.padding(16).background(Color(uiColor: .tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 20))
            Button(action: onAdd) {
                Text("Добавить в дневник").font(.system(size: 16, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .foregroundStyle(.white).background(Color(red: 0.15, green: 0.45, blue: 0.31)).clipShape(RoundedRectangle(cornerRadius: 17))
            }
            Text("Калорийность приблизительная. Проверьте состав и размер порции.").font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }.padding(.horizontal, 22).padding(.bottom, 20).background(Color(uiColor: .systemBackground))
    }
}

@MainActor
private enum FoodVisionAnalyzer {
    static func analyze(_ image: UIImage) async -> FoodItem {
        guard let cgImage = image.cgImage else { return fallback }
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let observations = request.results as? [VNClassificationObservation] ?? []
                let best = observations.first(where: { $0.confidence > 0.12 })
                continuation.resume(returning: best.map(makeFood) ?? fallback)
            }
            DispatchQueue.global(qos: .userInitiated).async {
                try? VNImageRequestHandler(cgImage: cgImage).perform([request])
            }
        }
    }

    private static func makeFood(_ observation: VNClassificationObservation) -> FoodItem {
        let label = observation.identifier.lowercased()
        let map: [(String, String, Int, String, Color)] = [
            ("pizza", "Пицца", 285, "fork.knife", .orange), ("salad", "Овощной салат", 180, "leaf.fill", .green),
            ("burger", "Бургер", 520, "takeoutbag.and.cup.and.straw.fill", .orange), ("sandwich", "Сэндвич", 350, "takeoutbag.and.cup.and.straw.fill", .brown),
            ("sushi", "Суши", 310, "fish.fill", .pink), ("soup", "Суп", 220, "cup.and.saucer.fill", .orange),
            ("pasta", "Паста", 430, "fork.knife", .yellow), ("cake", "Десерт", 390, "birthday.cake.fill", .pink),
            ("apple", "Яблоко", 95, "apple.logo", .red), ("banana", "Банан", 105, "carrot.fill", .yellow),
            ("bread", "Хлеб", 250, "birthday.cake.fill", .brown), ("chicken", "Курица", 330, "fork.knife", .orange),
            ("fish", "Рыба", 290, "fish.fill", .cyan), ("rice", "Рис", 210, "takeoutbag.and.cup.and.straw.fill", .brown),
            ("egg", "Яйцо", 155, "oval.fill", .yellow), ("coffee", "Кофе", 45, "cup.and.saucer.fill", .brown)
        ]
        if let match = map.first(where: { label.contains($0.0) }) {
            return FoodItem(name: match.1, detail: "Порция · оценка ИИ", calories: match.2, symbol: match.3, tint: match.4)
        }
        let title = observation.identifier.replacingOccurrences(of: "_", with: " ").capitalized
        return FoodItem(name: title, detail: "Порция · оценка ИИ", calories: 280, symbol: "fork.knife", tint: .green)
    }
    private static let fallback = FoodItem(name: "Блюдо", detail: "Порция · оценка ИИ", calories: 300, symbol: "fork.knife", tint: .green)
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onCancel: () -> Void
    let onCapture: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.onCapture()
        }
    }
}
