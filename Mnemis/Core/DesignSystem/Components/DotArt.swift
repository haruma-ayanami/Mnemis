import SwiftUI

/// Сфера из точек по формуле холста (`.sphere`): сетка точек шагом 6 pt, цвет — вертикальный градиент
/// от зелёного сверху к серому снизу, яркость затухает к центру и к краю. Тема меняет оттенки.
struct DotSphere: View {
    /// Раньше задавало число точек; сетка теперь строится по размеру. Параметр оставлен для вызовов.
    var dotCount: Int = 0
    @Environment(\.colorScheme) private var scheme

    private static let step: CGFloat = 6
    private static let dotRadius: CGFloat = 1.35

    var body: some View {
        Canvas { context, size in
            let stops = scheme == .dark ? DotSphere.darkStops : DotSphere.lightStops
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Расстояние до дальнего угла: от него холст считает проценты радиального градиента.
            let far = hypot(size.width / 2, size.height / 2)
            var y = DotSphere.step / 2
            while y < size.height {
                var x = DotSphere.step / 2
                while x < size.width {
                    let fade = DotSphere.edgeAlpha(hypot(x - center.x, y - center.y) / far)
                    if fade > 0.01 {
                        let color = DotSphere.color(at: y / size.height, stops: stops)
                        let r = DotSphere.dotRadius
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                            with: .color(color.opacity(fade))
                        )
                    }
                    x += DotSphere.step
                }
                y += DotSphere.step
            }
        }
        .accessibilityHidden(true)
    }

    /// Вторая маска холста: 0.22 в центре, 0.45 при 45 %, 1 при 64 %, 0 при 71 % от дальнего угла.
    static func edgeAlpha(_ t: CGFloat) -> CGFloat {
        if t < 0.45 { return 0.22 + 0.23 * t / 0.45 }
        if t < 0.64 { return 0.45 + 0.55 * (t - 0.45) / 0.19 }
        if t < 0.71 { return 1 - (t - 0.64) / 0.07 }
        return 0
    }

    typealias Stop = (position: CGFloat, r: Double, g: Double, b: Double)

    static let darkStops: [Stop] = [
        (0, 0x2F, 0xD0, 0x6E), (0.24, 0x7B, 0xEF, 0xA6), (0.44, 0xD6, 0xF7, 0xE1), (0.62, 0xEC, 0xEC, 0xE8), (1, 0x8E, 0x8E, 0x8B),
    ].map { Stop(position: $0.0, r: Double($0.1) / 255, g: Double($0.2) / 255, b: Double($0.3) / 255) }

    static let lightStops: [Stop] = [
        (0, 0x0F, 0x8A, 0x45), (0.26, 0x27, 0xB8, 0x64), (0.44, 0x7F, 0xD6, 0xA2), (0.64, 0x8C, 0x8C, 0x86), (1, 0xC8, 0xC8, 0xC2),
    ].map { Stop(position: $0.0, r: Double($0.1) / 255, g: Double($0.2) / 255, b: Double($0.3) / 255) }

    static func color(at t: CGFloat, stops: [Stop]) -> Color {
        let t = min(max(t, 0), 1)
        guard let upper = stops.firstIndex(where: { $0.position >= t }), upper > 0 else {
            let s = stops[0]
            return Color(red: s.r, green: s.g, blue: s.b)
        }
        let a = stops[upper - 1], b = stops[upper]
        let k = Double((t - a.position) / (b.position - a.position))
        return Color(red: a.r + (b.r - a.r) * k, green: a.g + (b.g - a.g) * k, blue: a.b + (b.b - a.b) * k)
    }
}

/// Ореол за сферой и фигурами: радиальный градиент до 65 % дальнего угла, как `.halo`.
struct GlowHalo: View {
    var body: some View {
        GeometryReader { geo in
            let far = hypot(geo.size.width / 2, geo.size.height / 2)
            RadialGradient(colors: [AppColor.halo, .clear], center: .center, startRadius: 0, endRadius: far * 0.65)
        }
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
                context.stroke(line, with: .color(AppColor.mesh), lineWidth: 0.7)
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
