import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/settings_controller.dart';
import '../../global_settings_animations.dart';
import '../../funcs.dart';
import '../../utils/totp.dart';

Future<void> copyTotpCode() async {
  try {
    final account = await Get.find<SettingsController>().getTotpAccount();
    if (account == null) {
      showWarningSnackbar('请先设置一次性验证码密钥', null);
      return;
    }
    await Clipboard.setData(ClipboardData(text: account.code()));
    showSuccessSnackbar('一次性验证码已复制', null);
  } catch (_) {
    showErrorSnackbar('无法复制一次性验证码，请检查密钥设置', null);
  }
}

Future<void> showTotpSettings(BuildContext context) async {
  final old = enable_inapp_hotkey;
  setInAppHotKeyEnable(false);
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => const _TotpDialog(),
    );
  } finally {
    setInAppHotKeyEnable(old);
  }
}

class _TotpDialog extends StatefulWidget {
  const _TotpDialog();
  @override
  State<_TotpDialog> createState() => _TotpDialogState();
}

class _TotpDialogState extends State<_TotpDialog> {
  final input = TextEditingController();
  String? error;
  bool busy = false;
  Future<void> save(String value) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final accounts = parseTotpInput(value);
      TotpAccount? selected = accounts.first;
      if (accounts.length > 1 && mounted) {
        selected = await showDialog<TotpAccount>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('选择用于复制的账户'),
            children: [
              for (var i = 0; i < accounts.length; i++)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, accounts[i]),
                  child: Text(
                    accounts[i].name.isEmpty ? '账户 ${i + 1}' : accounts[i].name,
                  ),
                ),
            ],
          ),
        );
      }
      if (selected == null || !mounted) return;
      await Get.find<SettingsController>().saveTotpAccount(selected);
      if (mounted) Navigator.pop(context);
      showSuccessSnackbar('一次性验证码密钥已保存', null);
    } catch (_) {
      if (mounted) setState(() => error = '无法导入，请检查密钥或二维码内容（仅支持 TOTP）');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('一次性验证码设置'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '密钥仅保存在本机，不参与设置导出或云端同步。支持 Base32、otpauth:// 和 otpauth-migration:// 二维码内容。',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: input,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: '输入密钥或二维码内容',
                errorText: error,
                errorMaxLines: 3,
              ),
            ),
            if (isAndroid || isIos || isMacOS)
              TextButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫码导入'),
                onPressed: busy
                    ? null
                    : () async {
                        final value = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => const _TotpScanner(),
                          ),
                        );
                        if (value != null && mounted) await save(value);
                      },
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy
            ? null
            : () async {
                await Get.find<SettingsController>().saveTotpAccount(null);
                if (context.mounted) Navigator.pop(context);
                showSuccessSnackbar('一次性验证码密钥已删除', null);
              },
        child: const Text('删除密钥'),
      ),
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: busy ? null : () => save(input.text),
        child: const Text('保存'),
      ),
    ],
  );
}

class _TotpScanner extends StatefulWidget {
  const _TotpScanner();
  @override
  State<_TotpScanner> createState() => _TotpScannerState();
}

class _TotpScannerState extends State<_TotpScanner> {
  final controller = MobileScannerController();
  bool detected = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('扫描一次性验证码二维码')),
    body: MobileScanner(
      controller: controller,
      onDetect: (capture) {
        if (detected) return;
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;
          if (value != null && value.isNotEmpty) {
            detected = true;
            Navigator.pop(context, value);
            break;
          }
        }
      },
    ),
  );
}
