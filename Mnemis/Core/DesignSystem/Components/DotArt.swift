import SwiftUI

/// Сфера из точек: зелёный сверху переходит в белый и серый снизу. Символ словаря пользователя.
/// Рисуется один раз, детерминированно, без анимации (Reduce Motion не нужен).
/// Геометрия не зависит от размера view: считается один раз на количество точек.
/// Точки группируются по цвету и прозрачности, поэтому на кадр уходят десятки заливок, а не тысячи.
struct DotSphere: View {
    var dotCount = 2600

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            var groups: [Int: Path] = [:]
            for dot in DotSphereGeometry.dots(count: dotCount) {
                let x = center.x + dot.x * radius
                let y = center.y - dot.y * radius
                let d = dot.diameter
                groups[dot.group, default: Path()].addEllipse(in: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d))
            }
            for (group, path) in groups {
                let shade = DotSphereGeometry.shade(for: group)
                context.fill(path, with: .color(shade.color.opacity(shade.alpha)))
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

/// Геометрия сферы из точек: спираль Фибоначчи с наклоном оси ~20°. Кэшируется по количеству точек.
enum DotSphereGeometry {
    struct Dot {
        /// Координаты в долях радиуса, от -1 до 1. `y` растёт вверх.
        let x: Double
        let y: Double
        let diameter: Double
        /// Группа заливки: цвет и прозрачность. Одинаковые группы рисуются одним путём.
        let group: Int
    }

    private static let alphaSteps = 20
    private static var cache: [Int: [Dot]] = [:]

    static func dots(count: Int) -> [Dot] {
        if let cached = cache[count] { return cached }
        let built = build(count: count)
        cache[count] = built
        return built
    }

    /// Цвет и прозрачность группы. Цвет: зелёный сверху, смесь к серому внизу, серый у низа.
    static func shade(for group: Int) -> (color: Color, alpha: Double) {
        let colorKey = group / (alphaSteps + 1) - 1
        let alpha = Double(group % (alphaSteps + 1)) / Double(alphaSteps)
        switch colorKey {
        case -1: return (AppColor.fill, alpha)
        case 8: return (AppColor.ink, alpha)
        default: return (AppColor.fill.mix(with: AppColor.ink, by: Double(colorKey) / 7), alpha)
        }
    }

    private static func build(count: Int) -> [Dot] {
        let golden = Double.pi * (3 - 5.0.squareRoot())
        let tilt = 0.35
        return (0..<count).map { i in
            let y = 1 - 2 * (Double(i) + 0.5) / Double(count)
            let r = (1 - y * y).squareRoot()
            let theta = golden * Double(i)
            let x = cos(theta) * r
            let z0 = sin(theta) * r
            let yy = y * cos(tilt) - z0 * sin(tilt)
            let z = y * sin(tilt) + z0 * cos(tilt)

            // Заднюю полусферу прячем: виден только «передний» слой, как в референсе.
            let depth = (z + 1) / 2
            let rim = 1 - abs(z)
            let t = (yy + 1) / 2   // 1 — верх, 0 — низ
            let alpha = 0.18 + 0.82 * max(depth, rim * 0.8)
            let diameter = 1.2 + 1.4 * depth

            let colorKey: Int
            let alphaMultiplier: Double
            if t > 0.62 {
                colorKey = -1
                alphaMultiplier = 1
            } else if t > 0.45 {
                colorKey = Int(((0.62 - t) / 0.17 * 7).rounded())
                alphaMultiplier = 1
            } else {
                colorKey = 8
                alphaMultiplier = 0.55 + 0.45 * t
            }
            let alphaStep = Int((alpha * alphaMultiplier * Double(alphaSteps)).rounded())
            return Dot(x: x, y: yy, diameter: diameter, group: (colorKey + 1) * (alphaSteps + 1) + alphaStep)
        }
    }
}

/// Мягкое зелёное свечение за элементом.
struct GlowHalo: View {
    var body: some View {
        RadialGradient(
            colors: [AppColor.glow.opacity(0.22), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
        .accessibilityHidden(true)
    }
}

/// Концентрические кольца из точек: режим фокуса на экранах обучения.
struct DotRings: View {
    /// Число уровней прозрачности: точки группируются по уровню, а не рисуются каждая отдельно.
    private static let levels = 12

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2
            let step: CGFloat = 9

            var levels: [Int: Path] = [:]
            var gy: CGFloat = 0
            while gy < size.height {
                var gx: CGFloat = 0
                while gx < size.width {
                    let dx = gx - center.x, dy = gy - center.y
                    let dist = (dx * dx + dy * dy).squareRoot() / maxR
                    if dist < 1 {
                        let wave = 0.5 + 0.5 * cos(dist * 22)
                        let falloff = sin(min(dist, 1) * .pi)
                        let a = wave * falloff * 0.55
                        if a > 0.06 {
                            let level = min(Self.levels - 1, Int(a / 0.55 * Double(Self.levels)))
                            levels[level, default: Path()].addEllipse(in: CGRect(x: gx - 0.9, y: gy - 0.9, width: 1.8, height: 1.8))
                        }
                    }
                    gx += step
                }
                gy += step
            }
            for (level, path) in levels {
                let alpha = (Double(level) + 0.5) / Double(Self.levels) * 0.55
                context.fill(path, with: .color(AppColor.ink.opacity(alpha)))
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

/// Сетка-пол в перспективе: низ экрана Today.
struct MeshFloor: View {
    var body: some View {
        Canvas { context, size in
            let horizon = size.height * 0.05
            let rows = 9
            for i in 0...rows {
                let t = pow(Double(i) / Double(rows), 1.9)
                let y = horizon + (size.height - horizon) * t
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(AppColor.ink.opacity(0.10 + 0.12 * t)), lineWidth: 0.7)
            }
            let columns = 14
            for i in 0...columns {
                let fx = Double(i) / Double(columns) - 0.5
                var line = Path()
                line.move(to: CGPoint(x: size.width * (0.5 + fx * 0.25), y: horizon))
                line.addLine(to: CGPoint(x: size.width * (0.5 + fx * 2.2), y: size.height))
                context.stroke(line, with: .color(AppColor.ink.opacity(0.14)), lineWidth: 0.7)
            }
        }
        .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

/// Точки сессии: `●●●●●●◉○○○○`. Заполненные — зелёные, текущая — светлая.
struct DotProgress: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < done ? AppColor.fill : .clear)
                    .overlay(Circle().stroke(index == done ? AppColor.ink : AppColor.faint, lineWidth: index < done ? 0 : 1.2))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Card \(min(done + 1, total)) of \(total)"))
    }
}

/// Сила памяти: пять делений, заполненные зелёные. Рисуется фигурами: глифа ▯ нет в моноширинном шрифте.
struct MemoryBar: View {
    let level: Int
    var total = 5

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < level ? AppColor.accent : AppColor.faint.opacity(0.55))
                    .frame(width: 4.5, height: 11)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Memory strength \(level) of \(total)"))
    }
}

/// Точка статуса слова. Статусы различаются яркостью и формой, не оттенком.
struct StatusDot: View {
    let status: LearningStatus
    var size: CGFloat = 10

    var body: some View {
        Group {
            switch status {
            case .new:
                Circle().stroke(AppColor.smoke, lineWidth: 1.5)
            case .learning:
                Circle().fill(AppColor.statusLearning)
            case .reviewing:
                Circle().fill(AppColor.statusReviewing)
            case .remembered:
                Circle().fill(AppColor.statusRemembered)
            case .known:
                Circle().fill(AppColor.fill).shadow(color: AppColor.glow.opacity(0.8), radius: 5)
            case .suspended:
                Circle().stroke(AppColor.faint, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2]))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension LearningStatus {
    /// Количество делений на шкале памяти.
    var strength: Int {
        switch self {
        case .new: 0
        case .learning: 1
        case .reviewing: 3
        case .remembered: 5
        case .known, .suspended: 0
        }
    }
}

/// Тумблер со светящейся ручкой: свечение — единственный источник света в интерфейсе.
struct GlowToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { configuration.isOn.toggle() }
        } label: {
            HStack {
                configuration.label
                Spacer(minLength: 12)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(AppColor.hairline).frame(width: 56, height: 32)
                    Circle()
                        .fill(configuration.isOn
                              ? AnyShapeStyle(RadialGradient(colors: [Color(light: 0xE9FFE9, dark: 0xE9FFE9), AppColor.fill], center: .init(x: 0.4, y: 0.38), startRadius: 0, endRadius: 16))
                              : AnyShapeStyle(AppColor.toggleOff))
                        .frame(width: 26, height: 26)
                        .shadow(color: configuration.isOn ? AppColor.glow.opacity(0.8) : .clear, radius: 8)
                        .padding(.horizontal, 3)
                }
                .glassCapsule()
                .frame(width: 56, height: 32)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? Text("On") : Text("Off"))
    }
}
