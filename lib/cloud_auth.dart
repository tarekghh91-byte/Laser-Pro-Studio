import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One email/password account is used on both Windows and Android.
class CloudAuthScreen extends StatefulWidget {
  const CloudAuthScreen({super.key});
  @override
  State<CloudAuthScreen> createState() => _CloudAuthScreenState();
}

class _CloudAuthScreenState extends State<CloudAuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 6) {
      setState(() => _message = 'اكتب إيميل صحيح وكلمة سر من 6 أحرف على الأقل');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        final reply = await auth.signUp(email: email, password: password);
        if (mounted && reply.session == null) {
          setState(() => _message = 'الحساب انعمل. افتح بريدك واضغط تأكيد الإيميل، بعدها سجّل دخول.');
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = 'تعذّر تسجيل الدخول: ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _message = 'تأكد من الإنترنت وحاول من جديد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
          child: Card(child: Padding(padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('LASER PRO STUDIO', textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 23, color: Color(0xFFDAAF69))),
              const SizedBox(height: 12),
              Text(_register ? 'إنشاء حساب للمزامنة' : 'دخول إلى حسابك المشترك',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
              const SizedBox(height: 22),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'الإيميل')),
              const SizedBox(height: 10),
              TextField(controller: _password, obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة السر')),
              const SizedBox(height: 14),
              if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Text(_message!, style: const TextStyle(color: Colors.amber))),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'لحظة...' : _register ? 'إنشاء حساب' : 'دخول')),
              TextButton(
                onPressed: _busy ? null : () => setState(() { _register = !_register; _message = null; }),
                child: Text(_register ? 'عندك حساب؟ سجّل دخول' : 'ما عندك حساب؟ أنشئ حساب')),
              const SizedBox(height: 8),
              const Text('استعمل نفس الإيميل وكلمة السر على التلفون واللابتوب.\n'
                'النسخة الحالية للمزامنة التجريبية فقط، مش للطلبات الحقيقية.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white70)),
            ])))),
      ))),
    ),
  );
}
