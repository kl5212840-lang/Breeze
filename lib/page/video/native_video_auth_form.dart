import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

class NativeVideoAuthForm extends StatefulWidget {
  const NativeVideoAuthForm({
    super.key,
    required this.registration,
    required this.hasRemember,
    required this.submit,
    required this.onChangeMode,
    required this.onWebsite,
    this.onForgotPassword,
    this.onExternalAuthentication,
    this.siteRejected = false,
    this.revision = 0,
  });
  final bool registration, hasRemember, siteRejected;
  final int revision;
  final Future<String> Function(
    String email,
    String password,
    String name,
    bool remember,
  )
  submit;
  final VoidCallback onChangeMode, onWebsite;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onExternalAuthentication;

  @override
  State<NativeVideoAuthForm> createState() => _NativeVideoAuthFormState();
}

class _NativeVideoAuthFormState extends State<NativeVideoAuthForm> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false, _busy = false, _visible = false;
  bool _unconfirmed = false;
  int _submissionRevision = 0;
  Timer? _deadline;
  String? _error;

  @override
  void didUpdateWidget(covariant NativeVideoAuthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _submissionRevision++;
      _deadline?.cancel();
      _busy = false;
      _unconfirmed = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _password.clear();
    _deadline?.cancel();
    _password.dispose();
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _unconfirmed || _key.currentState?.validate() != true) return;
    final revision = _submissionRevision;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.submit(
        _email.text.trim(),
        _password.text,
        _name.text.trim(),
        _remember,
      );
      if (!mounted || revision != _submissionRevision) return;
      if (result == 'website') {
        _password.clear();
        widget.onWebsite();
      } else if (result != 'submitted') {
        setState(
          () => _error = result == 'unsupported'
              ? t.videoCommunity.unsupported
              : t.videoCommunity.authFailed,
        );
      } else {
        _deadline = Timer(const Duration(seconds: 25), () {
          if (mounted && revision == _submissionRevision) {
            setState(() {
              _busy = false;
              _unconfirmed = true;
              _error = t.videoCommunity.authUnconfirmed;
            });
          }
        });
        return;
      }
      // A successful submission is not proof of login. Site navigation or
      // validation will replace/update this form; the host checks identity.
    } catch (_) {
      if (mounted && revision == _submissionRevision) {
        setState(() {
          _error = t.videoCommunity.authUnconfirmed;
          _unconfirmed = true;
        });
      }
    } finally {
      if (mounted && revision == _submissionRevision && _error != null) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Form(
        key: _key,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.registration
                    ? t.videoCommunity.register
                    : t.videoCommunity.login,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                t.videoCommunity.authNote,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: InputDecoration(labelText: t.videoCommunity.email),
                validator: (v) =>
                    v == null ||
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v.trim())
                    ? t.videoCommunity.invalidEmail
                    : null,
              ),
              if (widget.registration) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 80,
                  autofillHints: const [AutofillHints.newUsername],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t.videoCommunity.displayName,
                  ),
                  validator: (v) => v?.trim().isNotEmpty != true
                      ? t.videoCommunity.required
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: !_visible,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: [
                  widget.registration
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: t.videoCommunity.password,
                  suffixIcon: IconButton(
                    tooltip: t.videoCommunity.passwordVisibility,
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (v) =>
                    v?.isNotEmpty != true ? t.videoCommunity.required : null,
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
              if (widget.hasRemember)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _remember,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(t.videoCommunity.remember),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _remember = v == true),
                ),
              if (_error != null || widget.siteRejected) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error ?? t.videoCommunity.authFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy || _unconfirmed ? null : _submit,
                child: Text(
                  _busy
                      ? t.videoCommunity.submitting
                      : widget.registration
                      ? t.videoCommunity.register
                      : t.videoCommunity.login,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : widget.onChangeMode,
                child: Text(
                  widget.registration
                      ? t.videoCommunity.haveAccount
                      : t.videoCommunity.createAccount,
                ),
              ),
              if (!widget.registration && widget.onForgotPassword != null)
                TextButton(
                  onPressed: _busy ? null : widget.onForgotPassword,
                  child: Text(t.videoSiteAccount.forgetPassword),
                ),
              if (widget.onExternalAuthentication != null)
                TextButton(
                  onPressed: _busy || _unconfirmed
                      ? null
                      : widget.onExternalAuthentication,
                  child: Text(t.videoSiteAccount.googleInBrowser),
                ),
              TextButton(
                onPressed: _busy ? null : widget.onWebsite,
                child: Text(t.videoPlayback.backToWeb),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
