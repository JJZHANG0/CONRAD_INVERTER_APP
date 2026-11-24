import SwiftUI
import AVFoundation

struct VoiceCallView: View {
    @Environment(CompanionConversation.self) private var conversation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    let api: CloudService
    @State private var voice = VoiceCallSession()
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("INVERTER").font(.system(size: 12, design: .monospaced)).tracking(3)
                Spacer()
                Button(L("结束并整理")) { voice.end(); conversation.finish(api: api); dismiss() }
                    .disabled(conversation.userCount == 0 || conversation.sending || conversation.report != nil).font(.caption)
            }.padding(.horizontal, 26).padding(.top, 16)
            Spacer(minLength: 12)
            BotAvatar(state: voice.speaking ? "speaking" : voice.listening ? "listening" : voice.waiting ? "working" : "idle", tint: conversation.mode.color)
                .frame(width: 280, height: 280)
            Text(conversation.mode.title).font(.caption).foregroundStyle(Color.muted).accessibilityIdentifier("voice.mode")
            Text(voice.status).font(.system(size: 23, weight: .medium)).accessibilityIdentifier("voice.status")
            ScrollView {
                Text(voice.error ?? voice.caption).font(.system(size: 16)).foregroundStyle(Color.muted).lineSpacing(6).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }.frame(maxHeight: 160).padding(.horizontal, 32)
            if conversation.report != nil { Button(L("查看对话回顾")) { voice.end(); dismiss() }.font(.subheadline) }
            else if let _ = voice.error {
                Button(L("继续聆听")) {
                    if conversation.failure != nil { conversation.retry(api: api); voice.waiting = true; voice.error = nil }
                    else { voice.muted = false; voice.beginListening() }
                }.accessibilityIdentifier("voice.retry")
            } else if voice.speaking {
                Button(L("打断，我想说")) { voice.interrupt() }.font(.subheadline).accessibilityIdentifier("voice.interrupt")
            } else if voice.listening {
                Button(L("说完了")) { voice.submit() }.font(.subheadline).accessibilityIdentifier("voice.submit")
            }
            Spacer(minLength: 12)
            HStack(spacing: 44) {
                Button { voice.toggleMute() } label: { Image(systemName: voice.muted ? "mic.slash.fill" : "mic.fill").font(.system(size: 24)).frame(width: 68, height: 68).background(Color.surface, in: Circle()) }
                    .accessibilityLabel(voice.muted ? L("取消静音") : L("静音")).accessibilityIdentifier("voice.mute")
                Button { voice.end(); dismiss() } label: { Image(systemName: "phone.down.fill").font(.system(size: 26)).foregroundStyle(Color.paper).frame(width: 78, height: 78).background(Color.ink, in: Circle()) }
                    .accessibilityLabel(L("挂断")).accessibilityIdentifier("voice.end")
            }.padding(.bottom, 24)
        }.frame(maxWidth: .infinity).background(Color.paper.ignoresSafeArea()).foregroundStyle(Color.ink)
            .task {
                voice.start(opening: !conversation.sending && conversation.messages.last?.role == "assistant" ? conversation.messages.last?.content : nil, waiting: conversation.sending || conversation.needsReply || conversation.messages.isEmpty) { text in conversation.draft = text; conversation.send(api: api) }
                if conversation.messages.isEmpty { conversation.begin(api: api); voice.waiting = true }
                if let failure = conversation.failure { voice.requestFailed(failure) }
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let last = conversation.messages.last, last.role == "assistant" { voice.receive(last.content, complete: conversation.report != nil) }
            }
            .onChange(of: conversation.failure) { _, value in if let value { voice.requestFailed(value) } }
            .onChange(of: phase) { _, value in if value == .background { voice.end(); dismiss() } }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in voice.pause() }
             .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
                if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt, reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { voice.pause() }
            }
            .onDisappear { voice.end() }
    }
}
