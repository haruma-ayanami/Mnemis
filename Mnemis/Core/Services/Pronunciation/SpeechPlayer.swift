    import AVFoundation

/// Произношение слова системным синтезатором речи. Работает без сети и без аудиофайлов.
/// Аудио из источников (`Word.audioURL`) можно добавить позже без изменения экранов.
@MainActor
final class SpeechPlayer {
    static let shared = SpeechPlayer()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, language: String = "en-US") {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}
