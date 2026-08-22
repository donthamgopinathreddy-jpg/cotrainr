import 'package:flutter/material.dart';

import '../../services/app_version_service.dart';
import 'optional_update_dialog.dart';
import 'required_update_screen.dart';

/// Startup/resume version gate. Server config is authoritative (not FCM).
class AppVersionGate extends StatefulWidget {
  final Widget child;

  const AppVersionGate({super.key, required this.child});

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate>
    with WidgetsBindingObserver {
  AppVersionCheckResult? _requiredBlock;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runCheck(showOptional: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runCheck(showOptional: true);
    }
  }

  Future<void> _runCheck({required bool showOptional}) async {
    final result = await AppVersionService.instance.evaluate();
    if (!mounted) return;
    if (result.isRequired) {
      setState(() {
        _requiredBlock = result;
        _checking = false;
      });
      return;
    }
    setState(() {
      _requiredBlock = null;
      _checking = false;
    });
    if (showOptional &&
        result.isOptional &&
        await AppVersionService.instance.shouldShowOptionalPrompt(result)) {
      if (!mounted) return;
      await showOptionalUpdateDialog(context, result);
    }
  }

  Future<void> _openStore() async {
    final config = _requiredBlock?.config;
    await AppVersionService.instance.openStore(storeUrl: config?.storeUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return widget.child;
    }
    if (_requiredBlock != null) {
      return RequiredUpdateScreen(
        result: _requiredBlock!,
        onUpdate: _openStore,
      );
    }
    return widget.child;
  }
}
