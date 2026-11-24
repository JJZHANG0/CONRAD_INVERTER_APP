#if DEBUG
import Foundation

/// Only enabled by explicit UI test arguments. No provider key or production fallback.
nonisolated enum UITestCloudTransport {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--ai-fixture") }
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestModelProtocol.self]
        return URLSession(configuration: configuration)
    }
}
private final class UITestModelProtocol: URLProtocol, @unchecked Sendable {
    nonisolated private static let lock = NSLock()
    nonisolated(unsafe) private static var failed = false
    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    nonisolated(unsafe) private var delivery: DispatchWorkItem?
    nonisolated override func startLoading() {
        var requestData = request.httpBody ?? Data()
        if requestData.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }; requestData.append(contentsOf: buffer.prefix(count))
            }
        }
        let payload = (try? JSONSerialization.jsonObject(with: requestData)) as? [String: Any] ?? [:]
        let action = payload["action"] as? String ?? "reply"

        Self.lock.lock()
        let fail = ProcessInfo.processInfo.arguments.contains("--ai-fail-once") && !Self.failed && action != "start"
        if fail { Self.failed = true }
        Self.lock.unlock()
        var status = fail ? 502 : 200
        let body: String
        switch request.url?.path {
        case "/api/v1/inverter/first-look":
            body = #"{"title":"你也可以，被认真听见。","paragraph":"你选择了被陪伴，也希望自己的努力能被看见。也许你需要的不是马上解决所有事情，而是先有一点空间，把还没说完的话慢慢说完。你在关系里看重具体的小事，也希望自己能有休息的余地。这些需要可以同时存在，不必为了其中一个而放弃另一个。","invitation":"今天，留一点时间给自己。","evidenceQuestionIDs":["arrival","seen","unseen"]}"#
        case "/api/v1/inverter/reflections/next":
            body = #"{"question":"回到你刚刚提到的那个片刻，你最希望被理解的是什么？"}"#
        case "/api/v1/inverter/chat":
            let chinese = payload["language"] as? String == "zh"
            let mode = payload["mode"] as? String ?? "understanding"
            let messages = payload["messages"] as? [[String: String]] ?? []
            let users = messages.filter { $0["role"] == "user" }
            let complete = action == "finish" || users.count >= 5
            let reply = chinese ? (complete ? "我们先在这里停一停。我把你说过的感受，以及一个可以尝试的小改变，留在这份回顾里。" : "如果从最近一个让你在意的片刻开始，你最希望我们一起理解什么？") : (complete ? "Let’s pause here. I’ve gathered what you shared, and one small possibility, into a reflection you can keep." : "Thinking of one recent moment that stayed with you, what would you most like us to understand together?")
            let openings: [String: String] = chinese ? ["emotions": "最近哪个片刻让你的情绪停留了很久？", "relationships": "最近哪一次相处，让你想更清楚自己的边界？", "understanding": "最近你对自己的哪一次反应感到困惑？", "action": "有什么你很想尝试，却一直停在原地的小事？"] : ["emotions": "Which recent moment left a feeling you would like to understand?", "relationships": "Which recent interaction made you wonder about your boundaries?", "understanding": "Which recent reaction of your own would you like to understand?", "action": "What meaningful small step have you been hesitating to take?"]
            var value: [String: Any] = ["mode": mode, "reply": action == "start" ? (openings[mode] ?? reply) : reply, "stage": complete ? "closing" : action == "start" ? "connecting" : "meaning", "complete": complete, "safety": false]
            if complete {
                value["report"] = [
                    "title": chinese ? "你也可以，为自己留一点位置。" : "There is room for you, too.",
                    "summary": chinese ? "你想让自己的想法被认真听见，又不希望关系因此变得紧张。这两种在意可以同时存在。你开始把原本藏起来的话说出口，也在试着给自己的需要一个位置。" : "You want your thoughts to be heard, while also caring about the relationship. Both wishes can coexist. Beginning to put your experience into words makes a little more room for your own needs.",
                    "pattern": chinese ? "也许你有时会先照顾别人的感受，再问自己想要什么。这只是从这段对话里看见的一条线索，还需要更多真实的片刻来确认。" : "You may sometimes attend to other people’s feelings before asking what you need. This is a possibility from a brief exchange, not a conclusion about who you are.",
                    "strengths": chinese ? "你愿意停下来辨认自己的感受，也尝试表达不同的想法。这份觉察和行动，都是已经发生的改变。" : "You have paused to notice your experience and put it into words. That willingness to reflect is a resource you can return to.",
                    "nextStep": chinese ? "下一次想把话收回去时，可以先写下：此刻，我希望被听见的是哪一句？再决定是否向对方说出这一句。" : "Before holding a thought back, write down one sentence you wish could be heard. Then decide whether, and when, you want to share it.",
                    "invitation": chinese ? "不必一次说完，先让自己被自己听见。" : "You do not have to say everything at once.",
                    "evidence": [String((users.last?["content"] ?? "").prefix(80))]
                ] as [String: Any]
            }
            body = String(data: try! JSONSerialization.data(withJSONObject: value), encoding: .utf8)!
        case "/api/v1/inverter/analysis":
            body = #"{"title":"给这次表达一点空间","reason":"你记录了自己的感受，也保留了仍不确定的部分。","brief_advice":"先说清一件你希望对方知道的小事。","detailed_advice":"可以从具体发生的片段开始，再表达自己的需要，给对方回应的余地。"}"#
        default: status = 404; body = "{}"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data(body.utf8))
            self.client?.urlProtocolDidFinishLoading(self)
        }
        delivery = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (action == "finish" ? 5 : request.url?.path.hasSuffix("first-look") == true ? 2 : 0.15), execute: item)
    }
    nonisolated override func stopLoading() { delivery?.cancel(); delivery = nil }
}
#endif
