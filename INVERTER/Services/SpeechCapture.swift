import AVFoundation
import Speech
import Observation

@MainActor @Observable
final class SpeechCapture {
    var isRecording = false
    var transcript = ""
    var error: String?
    private let engine = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var hasTap = false
    private var generation = UUID()

    func start() async {
        let permissionAttempt = UUID()
        generation = permissionAttempt
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == permissionAttempt else { return }
        guard speech == .authorized else { error = L("请在系统设置中允许语音识别，也可以直接输入文字。"); return }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard generation == permissionAttempt else { return }
        guard microphone else { error = L("麦克风权限未开启，你仍可使用文字输入。"); return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: AppPreferences.shared.language == "zh" ? "zh-CN" : "en-US")), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            error = L("当前语言的离线识别暂不可用，请使用键盘听写或文字输入。"); return
        }
        do {
            stop()
            let recognitionID = UUID()
            generation = recognitionID
            transcript = ""
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }
            hasTap = true
            engine.prepare()
            try engine.start()
            isRecording = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, recognitionError in
                Task { @MainActor in
                    guard let self, self.generation == recognitionID else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if result?.isFinal == true || recognitionError != nil { self.stop() }
                }
            }
        } catch { self.error = L("无法开始录音：\(error.localizedDescription)"); stop() }
    }
    func stop() {
        generation = UUID()
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
