import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/login/login_error_message.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';

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
    this.siteErrorKind = '',
    this.revision = 0,
    this.credentials,
    this.loginUsername,
    this.saveCredentials,
    this.clearCredentials,
    this.accountIsEmail = true,
    this.verification,
    this.allowRegistration = true,
    this.allowRetryAfterRejection = false,
    this.saveAccountLabel,
  });
  final bool accountIsEmail, allowRegistration, allowRetryAfterRejection;
  final Widget? verification;
  final String? saveAccountLabel;
  final String? loginUsername;
  final VideoAccountCredentials? credentials;
  final Future<void> Function(String, String)? saveCredentials;
  final Future<void> Function()? clearCredentials;
  final bool registration, hasRemember, siteRejected;
  final int revision;
  final String siteErrorKind;
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
  bool _unconfirmed = false, _rememberCredentials = false;
  int _submissionRevision = 0;
  Timer? _deadline;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unconfirmed =
        widget.siteRejected &&
        widget.siteErrorKind != LoginFailureKind.credentials.name &&
        !widget.allowRetryAfterRejection;
    final saved = widget.credentials;
    if (!widget.registration) {
      if (widget.loginUsername case final name?) {
        _email.text = name;
      } else if (saved != null) {
        _email.text = saved.account;
        _password.text = saved.password;
        _rememberCredentials = true;
      }
    }
  }

  @override
  void didUpdateWidget(covariant NativeVideoAuthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _submissionRevision++;
      _deadline?.cancel();
      _busy = false;
      _unconfirmed =
          widget.siteRejected &&
          widget.siteErrorKind != LoginFailureKind.credentials.name &&
          !widget.allowRetryAfterRejection;
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
    var sending = false;
    try {
      if (_rememberCredentials && widget.saveCredentials != null) {
        await widget.saveCredentials!(_email.text.trim(), _password.text);
      }
      if (!_rememberCredentials &&
          widget.credentials != null &&
          widget.clearCredentials != null) {
        await widget.clearCredentials!();
      }
      sending = true;
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
    } catch (error) {
      if (mounted && revision == _submissionRevision) {
        setState(() {
          final kind = classifyLoginFailure(error);
          _error = !sending
              ? t.error.saveFailed
              : kind == LoginFailureKind.unknown
              ? t.videoCommunity.authUnconfirmed
              : userFacingLoginFailureMessage(kind);
          _unconfirmed = sending && kind != LoginFailureKind.credentials;
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
                autofillHints: [
                  widget.accountIsEmail
                      ? AutofillHints.email
                      : AutofillHints.username,
                ],
                keyboardType: widget.accountIsEmail
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: widget.accountIsEmail
                      ? t.videoCommunity.email
                      : t.videoCommunity.displayName,
                ),
                validator: (v) => !widget.accountIsEmail
                    ? (v?.trim().isNotEmpty == true
                          ? null
                          : t.videoCommunity.required)
                    : v == null ||
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
              if (widget.verification != null) ...[
                const SizedBox(height: 16),
                widget.verification!,
              ],
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
              if (!widget.registration && widget.saveCredentials != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _rememberCredentials,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    widget.saveAccountLabel ??
                        t.videoCommunity.rememberCredentials,
                  ),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _rememberCredentials = v == true),
                ),
              if (_error != null || widget.siteRejected) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error ??
                        (loginFailureKindFromCode(widget.siteErrorKind) ==
                                LoginFailureKind.unknown
                            ? t.videoCommunity.authFailed
                            : userFacingLoginFailureMessage(
                                loginFailureKindFromCode(widget.siteErrorKind),
                              )),
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
              if (widget.allowRegistration)
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
