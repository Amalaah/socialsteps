import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';

class ParentalGuard extends StatefulWidget {
  final Widget child;
  final bool isCompleted;

  const ParentalGuard({
    super.key,
    required this.child,
    required this.isCompleted,
  });

  @override
  State<ParentalGuard> createState() => _ParentalGuardState();
}

class _ParentalGuardState extends State<ParentalGuard> {
  bool _isPopping = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isCompleted || _isPopping,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        
        if (didPop) return;
        
        if (widget.isCompleted) {
          setState(() => _isPopping = true);
          Navigator.of(context).pop(result);
          return;
        }

        final bool? canExit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PasswordDialog(),
        );


        if (canExit == true && context.mounted) {
          setState(() => _isPopping = true);
          Navigator.of(context).pop(result);
        } else {
        }
      },
      child: widget.child,
    );
  }
}

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );

        await user.reauthenticateWithCredential(credential);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = "User session error";
          _loading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = "Incorrect password";
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Something went wrong";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Parent Access Required',
        textAlign: TextAlign.center,
        style: AppTheme.subheading,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Activity not finished. Please enter your login password to exit.',
            textAlign: TextAlign.center,
            style: AppTheme.body,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Password',
              errorText: _errorMessage,
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryLt),
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(
          onPressed: _loading ? null : () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textHint)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Submit'),
        ),
      ],
    );
  }
}
