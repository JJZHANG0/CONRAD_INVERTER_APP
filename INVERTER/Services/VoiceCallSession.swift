import AVFoundation
import Observation

/// Alternating on-device speech recognition and speech synthesis. Audio is never uploaded.
@MainActor @Observable final class VoiceCallSession: NSObject, AVSpeechSynthesizerDelegate {
    let capture = SpeechCapture()
    var active = false
    var muted = false
    var speaking = false
    var listening = false
    var waiting = false
    var error: String?
    var caption = ""
    private let speaker = AVSpeechSynthesizer()
    private var listenTask: Task<Void, Never>?
    private var sendText: ((String) -> Void)?
    private var mayListen = true
    private var generation = UUID()
    override init() { super.init(); speaker.delegate = self }
    var status: String {
        if error != nil { return L("语音暂时停下了") }
        if speaking { return L("正在回应你") }
        if muted { return L("麦克风已静音") }
        if waiting { return L("正在听，也在想…") }
        if !mayListen { return L("这次理解，已为你留好。") }
        return L("我在听，你慢慢说")
    }
    func start(opening: String?, waiting: Bool, send: @escaping (String) -> Void) {
        active = true; self.waiting = waiting; sendText = send
        if let opening { receive(opening, complete: false) }
        else if !waiting { beginListening() }
    }
    func receive(_ text: String, complete: Bool) {
        guard active else { return }
        stopListening(); waiting = false; error = nil; caption = text; mayListen = !complete
        speaker.stopSpeaking(at: .immediate)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: AppPreferences.shared.language == "zh" ? "zh-CN" : "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
            speaking = true; speaker.speak(utterance)
        } catch { speaking = false; self.error = L("声音暂时不可用，可以返回文字继续。") }
    }
    func beginListening() {
        guard active, !muted, !waiting, mayListen else { return }
        stopListening(); error = nil; caption = ""
        let id = UUID(); generation = id
        listenTask = Task { [weak self] in
            guard let self else { return }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--voice-fixture") { self.listening = true; return }
            #endif
            self.capture.error = nil
            await self.capture.start()
            guard !Task.isCancelled, self.active, self.generation == id else { self.capture.stop(); return }
            guard self.capture.isRecording else { self.error = self.capture.error ?? L("声音暂时不可用，可以返回文字继续。"); return }
            self.listening = true
            var lastText = ""; var changed = Date()
            while !Task.isCancelled && self.active && self.listening {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                let text = self.capture.transcript
                self.caption = text
                if text != lastText { lastText = text; changed = Date() }
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (Date().timeIntervalSince(changed) > 2.0 || !self.capture.isRecording) {
                    self.submit(); return
                }
                if !self.capture.isRecording { self.listening = false; self.error = self.capture.error ?? L("这次没有听清，点一下继续聆听。"); return }
            }
        }
    }
    func submit() {
        guard active, listening else { return }
        let text = capture.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stopListening()
        guard text.count <= 4000 else { error = L("这一条有点长，请缩短到 4000 字以内。"); return }
        caption = text; waiting = true; sendText?(text)
    }
    func toggleMute() {
        muted.toggle()
        if muted { stopListening() }
        else if !speaking { beginListening() }
    }
    func interrupt() {
        speaking = false; speaker.stopSpeaking(at: .immediate)
        beginListening()
    }
    func requestFailed(_ message: String) { waiting = false; error = message; stopListening() }
    func pause() { muted = true; speaking = false; speaker.stopSpeaking(at: .immediate); stopListening() }
    func end() {
        active = false; speaking = false; waiting = false; sendText = nil
        speaker.stopSpeaking(at: .immediate); stopListening()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func stopListening() {
        generation = UUID(); listenTask?.cancel(); listenTask = nil; listening = false
        if capture.isRecording || !speaking { capture.stop() }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.active, self.speaking, !self.speaker.isSpeaking else { return }
            self.speaking = false; self.beginListening()
        }
    }
}
