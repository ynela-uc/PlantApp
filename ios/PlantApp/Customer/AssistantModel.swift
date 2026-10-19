import SwiftUI

/// One bubble in the chat. A user bubble may carry the photo that was sent; an assistant bubble carries the reply.
struct ChatMessage: Identifiable {
    let id: Int
    let fromUser: Bool
    let text: String
    var photo: Data?
    var reply: AssistantReply?
}

/// The plant-help chat. Lives as long as the customer app, so the conversation survives tab switches.
@MainActor
final class AssistantModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var busy = false
    @Published var error: AssistantError?
    private var nextId = 1

    /// A photo was taken or picked: send it straight away (the assistant identifies the plant).
    func sendPhoto(_ raw: Data, language: String) { send("", raw, language) }

    func sendText(_ text: String, language: String) { send(text, nil, language) }

    private func send(_ text: String, _ rawPhoto: Data?, _ language: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if busy || (clean.isEmpty && rawPhoto == nil) { return }
        busy = true
        error = nil
        Task {
            var jpeg: Data?
            if let rawPhoto {
                jpeg = await Task.detached { ImageUtils.prepareJpeg(rawPhoto) }.value
            }
            let userMessage = ChatMessage(id: nextId, fromUser: true, text: clean, photo: jpeg)
            nextId += 1
            messages.append(userMessage)
            do {
                let turns = messages.map { message in
                    ChatTurn(fromUser: message.fromUser, text: message.fromUser ? message.text : (message.reply?.answer ?? message.text))
                }
                let reply = try await AssistantService.ask(turns: turns, jpeg: jpeg, language: language)
                messages.append(ChatMessage(id: nextId, fromUser: false, text: reply.answer, photo: nil, reply: reply))
                nextId += 1
                busy = false
            } catch let failure as AssistantError {
                busy = false
                error = failure
            } catch {
                busy = false
                self.error = .failed
            }
        }
    }

    func newChat() {
        if busy { return }
        messages = []
        error = nil
    }
}
