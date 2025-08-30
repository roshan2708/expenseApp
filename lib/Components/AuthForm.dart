import 'package:flutter/material.dart';

class AuthForm extends StatefulWidget {
  final Function(String, String) onSubmit;
  final String buttonText;
  final String alternateActionText;
  final VoidCallback alternateAction;

  const AuthForm({
    Key? key,
    required this.onSubmit,
    required this.buttonText,
    required this.alternateActionText,
    required this.alternateAction,
  }) : super(key: key);

  @override
  _AuthFormState createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
            onChanged: (value) => _email = value,
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
            onChanged: (value) => _password = value,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                widget.onSubmit(_email, _password);
              }
            },
            child: Text(widget.buttonText),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.alternateAction,
            child: Text(widget.alternateActionText),
          ),
        ],
      ),
    );
  }
}