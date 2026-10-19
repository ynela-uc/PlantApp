package com.plantapp.ui.customer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.plantapp.data.AssistantException
import com.plantapp.data.AssistantRepository
import com.plantapp.data.AssistantReply
import com.plantapp.data.ChatTurn
import com.plantapp.ui.ImageUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** One bubble in the chat. A user bubble may carry the photo that was sent; an assistant bubble carries the reply. */
class ChatMessage(
    val id: Long,
    val fromUser: Boolean,
    val text: String,
    val photo: ByteArray? = null,
    val reply: AssistantReply? = null,
)

enum class AssistantError { NotConfigured, DailyLimit, PhotoLimit, Network, Failed }

data class AssistantState(
    val messages: List<ChatMessage> = emptyList(),
    val busy: Boolean = false,
    val error: AssistantError? = null,
)

/** The plant-help chat. Lives as long as the customer app, so the conversation survives tab switches. */
class AssistantViewModel : ViewModel() {
    private val repo = AssistantRepository()
    private val _state = MutableStateFlow(AssistantState())
    val state: StateFlow<AssistantState> = _state.asStateFlow()
    private var nextId = 1L

    /** A photo was taken or picked: send it straight away (the assistant identifies the plant). */
    fun sendPhoto(raw: ByteArray, language: String) = send("", raw, language)

    fun sendText(text: String, language: String) = send(text, null, language)

    private fun send(text: String, rawPhoto: ByteArray?, language: String) {
        val clean = text.trim()
        if (_state.value.busy || (clean.isEmpty() && rawPhoto == null)) return
        _state.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            val jpeg = rawPhoto?.let { withContext(Dispatchers.Default) { ImageUtils.prepareJpeg(it) } }
            val userMessage = ChatMessage(nextId++, fromUser = true, text = clean, photo = jpeg)
            val history = _state.value.messages + userMessage
            _state.update { it.copy(messages = history) }
            try {
                val turns = history.map { message ->
                    ChatTurn(message.fromUser, if (message.fromUser) message.text else message.reply?.answer ?: message.text)
                }
                val reply = repo.ask(turns, jpeg, language)
                val answer = ChatMessage(nextId++, fromUser = false, text = reply.answer, reply = reply)
                _state.update { it.copy(messages = it.messages + answer, busy = false) }
            } catch (e: AssistantException) {
                val error = when (e.kind) {
                    AssistantException.Kind.NotConfigured -> AssistantError.NotConfigured
                    AssistantException.Kind.DailyLimit -> AssistantError.DailyLimit
                    AssistantException.Kind.PhotoLimit -> AssistantError.PhotoLimit
                    AssistantException.Kind.Network -> AssistantError.Network
                    AssistantException.Kind.Failed -> AssistantError.Failed
                }
                _state.update { it.copy(busy = false, error = error) }
            } catch (_: Exception) {
                _state.update { it.copy(busy = false, error = AssistantError.Failed) }
            }
        }
    }

    fun newChat() {
        if (_state.value.busy) return
        _state.value = AssistantState()
    }

    fun clearError() = _state.update { it.copy(error = null) }
}
