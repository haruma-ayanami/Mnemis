import Foundation

/// Состояние экрана, общее для всех ViewModel.
enum ScreenState: Equatable {
    case loading
    case loaded
    case failed(String)
}
