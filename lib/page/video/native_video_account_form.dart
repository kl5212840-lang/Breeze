import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mime/mime.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';

typedef VideoAccountFormSubmit =
    Future<String> Function(String operation, Map<String, String> values);

/// Private fields live only here. The catalog owns document navigation but
/// never receives this form's metadata, validation values or field snapshots.
class NativeVideoAccountForm extends StatefulWidget {
  const NativeVideoAccountForm({
    super.key,
    required this.page,
    required this.read,
    required this.submit,
    required this.onRefresh,
    required this.onWebsite,
    this.revision = 0,
    this.readback = false,
    this.submitting = false,
    this.unconfirmed = false,
    this.result,
  });

  final Uri page;
  final Future<Map<String, dynamic>> Function() read;
  final VideoAccountFormSubmit submit;
  final VoidCallback onRefresh, onWebsite;
  final int revision;

  /// True only after the host made an independent GET after a real submission.
  /// The widget then compares expected values without exporting them.
  final bool readback;
  final bool submitting, unconfirmed;
  final String? result;

  @override
  NativeVideoAccountFormState createState() => NativeVideoAccountFormState();
}

class NativeVideoAccountFormState extends State<NativeVideoAccountForm>
    with WidgetsBindingObserver {
  final _profileForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  final _otp = TextEditingController();
  Map<String, dynamic> _metadata = const {};
  Map<String, String>? _expectedProfile;
  Uint8List? _photo;
  String? _photoMime;
  String? _pending, _notice;
  String _originalName = '', _originalEmail = '';
  bool _loading = true, _working = false, _dirty = false;
  bool _unconfirmed = false;
  int _readGeneration = 0, _seconds = 0;
  Timer? _deadline, _otpTimer;

  bool get _busy => _working || widget.submitting;
  bool get _hasSecrets =>
      _oldPassword.text.isNotEmpty ||
      _newPassword.text.isNotEmpty ||
      _confirmation.text.isNotEmpty ||
      _otp.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _name.addListener(_profileChanged);
    _email.addListener(_profileChanged);
    _read();
  }

  @override
  void didUpdateWidget(covariant NativeVideoAccountForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _clearPrivate();
      _metadata = const {};
      _pending = null;
      _expectedProfile = null;
      _dirty = false;
      _notice = null;
      _deadline?.cancel();
      _otpTimer?.cancel();
      _working = false;
      _unconfirmed = false;
      _loading = true;
      _read();
    } else if (oldWidget.revision != widget.revision) {
      _read();
    }
  }

  void _profileChanged() {
    if (!mounted) return;
    final dirty = _name.text != _originalName || _email.text != _originalEmail;
    if (_dirty != dirty) setState(() => _dirty = dirty);
  }

  void _clearPasswords() {
    _oldPassword.clear();
    _newPassword.clear();
    _confirmation.clear();
  }

  void _clearPrivate() {
    _name.clear();
    _email.clear();
    _clearPasswords();
    _otp.clear();
    _photo = null;
    _photoMime = null;
    _originalName = '';
    _originalEmail = '';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readGeneration++;
    _deadline?.cancel();
    _otpTimer?.cancel();
    _name.removeListener(_profileChanged);
    _email.removeListener(_profileChanged);
    _clearPrivate();
    _metadata = const {};
    _expectedProfile = null;
    for (final controller in [
      _name,
      _email,
      _oldPassword,
      _newPassword,
      _confirmation,
      _otp,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) clearSensitiveInputs();
  }

  /// May also be used before showing the site's verification UI. Clearing
  /// secrets never clears the pending operation or its no-repeat guard.
  void clearSensitiveInputs() {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _clearPasswords();
      _otp.clear();
      _photo = null;
      _photoMime = null;
    });
  }

  Future<void> _read() async {
    final generation = ++_readGeneration;
    try {
      final metadata = await widget.read();
      if (!mounted || generation != _readGeneration) return;
      final expected = _expectedProfile;
      final matched =
          widget.readback &&
          _pending == 'profile' &&
          expected != null &&
          metadata['profileReady'] == true &&
          metadata['failed'] != true &&
          metadata['name'] == expected['name'] &&
          metadata['email'] == expected['email'];
      final nextName = metadata['name']?.toString() ?? '';
      final nextEmail = metadata['email']?.toString() ?? '';
      final updateFields = !_dirty || matched;
      setState(() {
        _metadata = metadata;
        _loading = false;
        if (metadata['supported'] != true) {
          _notice = t.videoSiteAccount.unsupportedAccount;
        } else if (metadata['failed'] == true) {
          _notice = t.videoSiteAccount.failed;
          _unconfirmed = false;
        } else if (matched) {
          _notice = t.videoSiteAccount.readbackMatched;
          _unconfirmed = false;
          _expectedProfile = null;
        } else if (_pending == 'password') {
          _notice = t.videoSiteAccount.passwordUnconfirmed;
          _unconfirmed = true;
        } else if (_pending == 'avatar') {
          _notice = t.videoSiteAccount.avatarUnconfirmed;
          _unconfirmed = true;
        } else if (_pending == 'verifyOtp') {
          _notice = t.videoSiteAccount.otpUnconfirmed;
          _unconfirmed = true;
        } else if (_pending != null) {
          _notice = t.videoSiteAccount.unconfirmed;
          _unconfirmed = true;
        }
        if (_pending != null) {
          _working = false;
          _deadline?.cancel();
          if (matched || metadata['failed'] == true) _pending = null;
        }
        _originalName = nextName;
        _originalEmail = nextEmail;
      });
      if (updateFields) {
        _name.text = nextName;
        _email.text = nextEmail;
      }
      _profileChanged();
    } catch (_) {
      if (!mounted || generation != _readGeneration) return;
      setState(() {
        _loading = false;
        _working = false;
        _notice = t.videoSiteAccount.unsupportedAccount;
      });
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.common.confirm),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _leaveForWebsite() async {
    if (!await requestClose()) return;
    if (!mounted) return;
    _clearPasswords();
    _otp.clear();
    widget.onWebsite();
  }

  /// The catalog has internal navigation instead of a nested Navigator route.
  /// Its back/tab/mode actions use this boolean guard without reading inputs.
  Future<bool> requestClose() async {
    if (_busy) return false;
    FocusScope.of(context).unfocus();
    if (_pending != null || _unconfirmed) {
      return _confirm(
        t.videoSiteAccount.unconfirmed,
        t.videoSiteAccount.leavePending,
      );
    }
    if (!_dirty && _photo == null && !_hasSecrets) return true;
    return _confirm(
      t.videoSiteAccount.discardTitle,
      t.videoSiteAccount.discardBody,
    );
  }

  Future<void> _submit(String operation, Map<String, String> values) async {
    if (_busy || _unconfirmed || widget.unconfirmed) return;
    if (operation == 'profile' &&
        _profileForm.currentState?.validate() != true) {
      return;
    }
    if (operation == 'password' &&
        _passwordForm.currentState?.validate() != true) {
      return;
    }
    if (operation == 'logout' &&
        !await _confirm(
          t.videoSiteAccount.logout,
          t.videoSiteAccount.logoutPrompt,
        )) {
      return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final revision = widget.revision;
    setState(() {
      _working = true;
      _notice = t.videoSiteAccount.submitted;
      _pending = operation;
      if (operation == 'profile') _expectedProfile = Map.of(values);
    });
    try {
      final result = await widget.submit(operation, values);
      if (!mounted) return;
      if (result == 'website') {
        setState(() {
          _working = false;
          _pending = null;
          _notice = t.videoSiteAccount.unavailable;
        });
        return;
      }
      if (result != 'submitted') {
        setState(() {
          _working = false;
          _pending = null;
          _expectedProfile = null;
          _notice = result == 'unsupported' || result == 'changed'
              ? t.videoSiteAccount.unavailable
              : t.videoSiteAccount.failed;
        });
        return;
      }
      // A fast redirect may already have advanced the document while the JS
      // reply was in transit. Its read owns the result; do not re-arm a timer.
      if (widget.revision != revision) return;
      _deadline?.cancel();
      _deadline = Timer(const Duration(seconds: 25), () {
        if (!mounted) return;
        setState(() {
          _working = false;
          _unconfirmed = true;
          _notice = t.videoSiteAccount.unconfirmed;
        });
      });
      if (operation == 'requestOtp') _observeOtpRequest();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _unconfirmed = true;
        _notice = t.videoSiteAccount.unconfirmed;
      });
    } finally {
      // A login redirect can dispose the entire task before JS replies.
      // dispose already clears these controllers; never touch them afterwards.
      if (mounted && operation == 'password') _clearPasswords();
      if (mounted && operation == 'verifyOtp') _otp.clear();
      if (operation == 'avatar' && mounted) {
        setState(() {
          _photo = null;
          _photoMime = null;
        });
      }
    }
  }

  Future<void> _observeOtpRequest() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _pending != 'requestOtp' || !_working) return;
      try {
        final state = await widget.read();
        if (!mounted || _pending != 'requestOtp') return;
        final seconds = state['otpWaitSeconds'];
        if (seconds is int && seconds > 0) {
          _deadline?.cancel();
          setState(() {
            _seconds = seconds;
            _working = false;
            _pending = null;
            _notice = t.videoSiteAccount.codeSent;
          });
          _otpTimer?.cancel();
          _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted || _seconds <= 1) {
              timer.cancel();
              if (mounted) setState(() => _seconds = 0);
            } else {
              setState(() => _seconds--);
            }
          });
          return;
        }
        if (state['otpStatusVisible'] == true && state['otpPending'] != true) {
          _deadline?.cancel();
          setState(() {
            _working = false;
            _pending = null;
            _notice = t.videoSiteAccount.failed;
          });
          return;
        }
      } catch (_) {
        // A redirect/reload may replace the document; the navigation lifecycle
        // will perform the next read. Never retry sending a code here.
        return;
      }
    }
  }

  Future<void> _choosePhoto() async {
    if (_busy || _unconfirmed) return;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final mime = lookupMimeType(file.name, headerBytes: bytes);
      if (!const [
        'image/png',
        'image/gif',
        'image/jpeg',
        'image/webp',
      ].contains(mime)) {
        setState(() => _notice = t.videoSiteAccount.invalidPhoto);
        return;
      }
      setState(() {
        _photo = bytes;
        _photoMime = mime;
        _notice = null;
      });
    } catch (_) {
      if (mounted) setState(() => _notice = t.videoSiteAccount.invalidPhoto);
    }
  }

  void _refresh() {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    widget.onRefresh();
  }

  Widget _heading(String title, {bool first = false}) => Padding(
    padding: EdgeInsets.only(top: first ? 12 : 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _unavailable() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t.videoSiteAccount.unavailable,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      TextButton(
        onPressed: _busy ? null : _leaveForWebsite,
        child: Text(t.videoSiteAccount.website),
      ),
    ],
  );

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    bool confirm = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: label,
        errorText:
            (_metadata['errorFields'] as List?)?.contains(
                  controller == _oldPassword
                      ? 'password_old'
                      : controller == _newPassword
                      ? 'password_new'
                      : 'password_new_confirm',
                ) ==
                true
            ? t.videoSiteAccount.failed
            : null,
      ),
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: [
        controller == _oldPassword
            ? AutofillHints.password
            : AutofillHints.newPassword,
      ],
      textInputAction: confirm ? TextInputAction.done : TextInputAction.next,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onChanged: (_) => setState(() {}),
      validator: (value) => value?.isEmpty != false
          ? t.videoSiteAccount.required
          : confirm && value != _newPassword.text
          ? t.videoSiteAccount.passwordMismatch
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => _AccountTouchTargets(
    // The catalog owns navigation and calls requestClose. A second PopScope
    // on the same ModalRoute could pop the entire source or show two dialogs.
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            key: const ValueKey('native-account-form'),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                t.videoSiteAccount.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 2,
                child: _busy ? const LinearProgressIndicator() : null,
              ),
              if (_notice != null || widget.unconfirmed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_notice ?? t.videoSiteAccount.unconfirmed),
                  ),
                ),
              if (_metadata['supported'] != true) ...[
                const SizedBox(height: 12),
                _unavailable(),
              ] else ...[
                _heading(t.videoSiteAccount.photo, first: true),
                Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _photo != null
                            ? Image.memory(
                                _photo!,
                                fit: BoxFit.cover,
                                cacheWidth: 192,
                              )
                            : (_metadata['avatarUrl']?.toString().isNotEmpty ??
                                  false)
                            ? VideoThumbnail(
                                url: _metadata['avatarUrl'].toString(),
                                referrer: widget.page,
                              )
                            : const Icon(Icons.person_outline, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _busy || _unconfirmed
                              ? null
                              : _metadata['avatarReady'] == true
                              ? _choosePhoto
                              : _leaveForWebsite,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(t.videoSiteAccount.choosePhoto),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_photo != null)
                  Wrap(
                    spacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _busy || _unconfirmed
                            ? null
                            : () => _submit('avatar', {
                                'mime': _photoMime!,
                                'base64': base64Encode(_photo!),
                              }),
                        child: Text(t.videoSiteAccount.uploadPhoto),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _photo = null;
                                _photoMime = null;
                              }),
                        child: Text(t.videoSiteAccount.cancelPhoto),
                      ),
                    ],
                  ),
                _heading(t.videoSiteAccount.profile),
                if (_metadata['profileReady'] == true)
                  AutofillGroup(
                    child: Form(
                      key: _profileForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _name,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: t.videoSiteAccount.name,
                              errorText:
                                  (_metadata['errorFields'] as List?)?.contains(
                                        'name',
                                      ) ==
                                      true
                                  ? t.videoSiteAccount.failed
                                  : null,
                            ),
                            textInputAction: TextInputAction.next,
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            autofillHints: const [AutofillHints.username],
                            validator: (value) =>
                                value?.trim().isNotEmpty == true
                                ? null
                                : t.videoSiteAccount.required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: t.videoSiteAccount.email,
                              errorText:
                                  (_metadata['errorFields'] as List?)?.contains(
                                        'email',
                                      ) ==
                                      true
                                  ? t.videoSiteAccount.failed
                                  : null,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            enableSuggestions: false,
                            validator: (value) =>
                                value?.trim().isNotEmpty != true
                                ? t.videoSiteAccount.required
                                : !RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(value!.trim())
                                ? t.videoSiteAccount.emailInvalid
                                : null,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy || _unconfirmed || !_dirty
                                ? null
                                : () => _submit('profile', {
                                    'name': _name.text.trim(),
                                    'email': _email.text.trim(),
                                  }),
                            child: Text(t.videoSiteAccount.saveProfile),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _unavailable(),
                _heading(t.videoSiteAccount.password),
                if (_metadata['passwordReady'] == true)
                  AutofillGroup(
                    child: Form(
                      key: _passwordForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _passwordField(
                            _oldPassword,
                            t.videoSiteAccount.oldPassword,
                          ),
                          _passwordField(
                            _newPassword,
                            t.videoSiteAccount.newPassword,
                          ),
                          _passwordField(
                            _confirmation,
                            t.videoSiteAccount.confirmPassword,
                            confirm: true,
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton(
                            onPressed: _busy || _unconfirmed
                                ? null
                                : () => _submit('password', {
                                    'password_old': _oldPassword.text,
                                    'password_new': _newPassword.text,
                                    'password_new_confirm': _confirmation.text,
                                  }),
                            child: Text(t.videoSiteAccount.changePassword),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _unavailable(),
                if (_metadata['otpReady'] == true) ...[
                  _heading(t.videoSiteAccount.verification),
                  TextField(
                    controller: _otp,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: t.videoSiteAccount.code,
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: _busy || _unconfirmed || _seconds > 0
                            ? null
                            : () => _submit('requestOtp', const {}),
                        child: Text(
                          _seconds > 0
                              ? t.videoSiteAccount.resendIn(seconds: _seconds)
                              : t.videoSiteAccount.requestCode,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _busy || _unconfirmed
                            ? null
                            : () => _submit('verifyOtp', {
                                'otp': _otp.text.trim(),
                              }),
                        child: Text(t.videoSiteAccount.verifyCode),
                      ),
                    ],
                  ),
                ],
                if (_metadata['logoutReady'] == true) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  TextButton.icon(
                    onPressed: _busy || _unconfirmed
                        ? null
                        : () => _submit('logout', const {}),
                    icon: const Icon(Icons.logout),
                    label: Text(t.videoSiteAccount.logout),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(t.videoSiteAccount.refresh),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _leaveForWebsite,
                    child: Text(t.videoSiteAccount.website),
                  ),
                ],
              ),
            ],
          ),
  );
}

/// Only the observed email-link stage is native. No reset token or returned
/// secret-link URL is read into Dart; later password steps stay on the website.
class NativeVideoPasswordRecoveryForm extends StatefulWidget {
  const NativeVideoPasswordRecoveryForm({
    super.key,
    required this.read,
    required this.submit,
    required this.onLogin,
    required this.onWebsite,
    this.revision = 0,
  });
  final Future<Map<String, dynamic>> Function() read;
  final Future<String> Function(String email) submit;
  final VoidCallback onLogin, onWebsite;
  final int revision;

  @override
  State<NativeVideoPasswordRecoveryForm> createState() =>
      _NativeVideoPasswordRecoveryFormState();
}

class _NativeVideoPasswordRecoveryFormState
    extends State<NativeVideoPasswordRecoveryForm> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  Map<String, dynamic> _state = const {};
  bool _loading = true, _busy = false, _unconfirmed = false;
  String? _notice;
  Timer? _deadline;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(covariant NativeVideoPasswordRecoveryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) _read();
  }

  @override
  void dispose() {
    _generation++;
    _deadline?.cancel();
    _email.clear();
    _email.dispose();
    _state = const {};
    super.dispose();
  }

  Future<void> _read() async {
    final generation = ++_generation;
    try {
      final state = await widget.read();
      if (!mounted || generation != _generation) return;
      _deadline?.cancel();
      setState(() {
        _state = state;
        _loading = false;
        _busy = false;
        if (state['sent'] == true) {
          _notice = t.videoSiteAccount.recoverySent;
          _unconfirmed = false;
          _email.clear();
        } else if (state['failed'] == true) {
          _notice = t.videoSiteAccount.failed;
          _unconfirmed = false;
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _busy = false;
        _notice = t.videoSiteAccount.unavailable;
      });
    }
  }

  Future<void> _submit() async {
    if (_busy || _unconfirmed || _form.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    final revision = widget.revision;
    setState(() {
      _busy = true;
      _notice = t.videoSiteAccount.submitted;
    });
    try {
      final result = await widget.submit(_email.text.trim());
      if (!mounted || revision != widget.revision) return;
      if (result != 'submitted') {
        setState(() {
          _busy = false;
          _notice = t.videoSiteAccount.unavailable;
        });
        return;
      }
      _unconfirmed = true;
      _deadline = Timer(const Duration(seconds: 25), () {
        if (mounted) {
          setState(() {
            _busy = false;
            _notice = t.videoSiteAccount.unconfirmed;
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _unconfirmed = true;
          _notice = t.videoSiteAccount.unconfirmed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _AccountTouchTargets(
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                t.videoSiteAccount.recoveryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(t.videoSiteAccount.recoveryDescription),
              const SizedBox(height: 16),
              if (_state['supported'] == true)
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: t.videoSiteAccount.email,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: (value) => value?.trim().isNotEmpty != true
                            ? t.videoSiteAccount.required
                            : !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value!.trim())
                            ? t.videoSiteAccount.emailInvalid
                            : null,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            _busy || _unconfirmed || _state['sent'] == true
                            ? null
                            : _submit,
                        child: Text(t.videoSiteAccount.sendRecovery),
                      ),
                    ],
                  ),
                )
              else if (_state['sent'] != true)
                Text(t.videoSiteAccount.unavailable),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: _busy ? null : widget.onLogin,
                    child: Text(t.videoSiteAccount.backLogin),
                  ),
                  TextButton(
                    onPressed: _busy ? null : widget.onWebsite,
                    child: Text(t.videoSiteAccount.website),
                  ),
                ],
              ),
            ],
          ),
  );
}

/// Preserve the current theme's shapes and feedback while giving every account
/// action the iOS minimum hit height, including text-only recovery controls.
class _AccountTouchTargets extends StatelessWidget {
  const _AccountTouchTargets({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const minimum = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(44, 44)),
    );
    return Theme(
      data: theme.copyWith(
        textButtonTheme: TextButtonThemeData(
          style: (theme.textButtonTheme.style ?? const ButtonStyle()).merge(
            minimum,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: (theme.filledButtonTheme.style ?? const ButtonStyle()).merge(
            minimum,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (theme.outlinedButtonTheme.style ?? const ButtonStyle()).merge(
            minimum,
          ),
        ),
      ),
      child: child,
    );
  }
}
