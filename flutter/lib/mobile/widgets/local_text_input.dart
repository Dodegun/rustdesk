import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The draft belongs to this dialog and is never persisted.
class LocalTextInput extends StatefulWidget {
  const LocalTextInput({
    super.key,
    required this.canSend,
    required this.send,
    required this.close,
  });

  final bool Function() canSend;
  final Future<void> Function(String) send;
  final VoidCallback close;

  @override
  State<LocalTextInput> createState() => _LocalTextInputState();
}

class _LocalTextInputState extends State<LocalTextInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  String? _status;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _controller.text.isEmpty) return;
    if (!widget.canSend()) {
      setState(() => _status = '연결 상태와 키보드 제어 권한을 확인하세요.');
      return;
    }
    setState(() {
      _sending = true;
      _status = null;
    });
    // The current text already contains the IME's composing syllable.
    // End local composition before taking the snapshot; never send key diffs.
    _focus.unfocus();
    _controller.clearComposing();
    final text = _controller.text;
    try {
      if (!widget.canSend()) {
        setState(() => _status = '연결 상태와 키보드 제어 권한을 확인하세요.');
        return;
      }
      await widget.send(text);
      if (!mounted) return;
      _controller.clear();
      widget.close();
    } catch (_) {
      if (mounted) {
        setState(() => _status = '전송 결과를 확인할 수 없습니다. PC를 확인한 뒤 다시 시도하세요.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _controller.text));
      if (mounted) setState(() => _status = '휴대폰 클립보드에 복사했습니다.');
    } catch (_) {
      if (mounted) setState(() => _status = '복사하지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // The session overlay shares its route with the remote keyboard. Give this
    // dialog its own scope so autofocus does not keep the remote field focused.
    return FocusScope(
      autofocus: true,
      onKeyEvent: (_, __) => KeyEventResult.skipRemainingHandlers,
      child: AlertDialog(
        title: const Text('한글 입력'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('PC에서 입력할 곳을 선택한 뒤 작성하세요. 닫으면 내용이 삭제됩니다.'),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('local-text-draft'),
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  readOnly: _sending,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 10000,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '여기에 한글을 입력하세요',
                  ),
                  onChanged: (_) => setState(() => _status = null),
                ),
                if (_status != null) Text(_status!),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _sending || _controller.text.isEmpty ? null : _copy,
                      child: const Text('복사'),
                    ),
                    TextButton(
                      onPressed: _sending || _controller.text.isEmpty
                          ? null
                          : () => setState(() {
                                _controller.clear();
                                _status = null;
                              }),
                      child: const Text('지우기'),
                    ),
                    TextButton(onPressed: widget.close, child: const Text('닫기')),
                    ElevatedButton(
                      key: const ValueKey('local-text-send'),
                      onPressed: _sending || _controller.text.isEmpty || !widget.canSend()
                          ? null
                          : _send,
                      child: Text(_sending ? '전송 중…' : 'PC로 보내기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
