import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:social/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/custom_text_field.dart' show CustomTextFormField;

class SignUpPage extends StatefulWidget {
  const new({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _passwordObscure = true;
  bool _isLoading = false;
  @override
  void dispose() {
    super.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: .symmetric(horizontal: 16),
          child: Form(
            autovalidateMode: .onUserInteractionIfError,
            key: _formKey,
            child: Column(
              mainAxisAlignment: .center,
              spacing: 12,
              children: [
                Text(
                  "Create a new account",
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                CustomTextFormField(
                  controller: _fullNameController,
                  validator: (value) {
                    if (value!.length <= 3) {
                      return "Most be greater than 3 letters";
                    }
                    return null;
                  },

                  prefixIcon: Icons.person,
                  hintText: "Enter your full name",
                  labelText: "Full name",
                ),

                CustomTextFormField(
                  controller: _emailController,
                  prefixIcon: Icons.email,
                  validator: (value) {
                    if (!EmailValidator.validate(value!)) {
                      return "Please enter a valid email";
                    }
                    return null;
                  },
                  hintText: "Enter your email",
                  labelText: "Full name",
                ),

                CustomTextFormField(
                  controller: _passwordController,
                  prefixIcon: Icons.lock,
                  obscureText: _passwordObscure,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _passwordObscure = !_passwordObscure;
                      });
                    },
                    icon: Icon(
                      _passwordObscure
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                  validator: (value) {
                    if (value!.length <= 5) {
                      return "Length most be greater or equal to six lettter";
                    }
                    return null;
                  },
                  hintText: "Enter your password",
                  labelText: "Password",
                ),

                SizedBox(
                  width: double.maxFinite,
                  child: FilledButton(
                    onPressed: _isLoading
                        ? () {}
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                              });
                              try {
                                final client = Supabase.instance.client;
                                await client.auth.signUp(
                                  email: _emailController.text,
                                  password: _passwordController.text,
                                  data: {"full_name": _fullNameController.text},
                                );
                                Fluttertoast.showToast(
                                  msg: "Your account is created successfully",
                                );

                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => HomePage(),
                                  ),
                                );
                              } on AuthException catch (e) {
                                Fluttertoast.showToast(
                                  msg: e.message,
                                  backgroundColor: Colors.red,
                                );
                              } finally {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : Text("Sign up"),
                  ),
                ),

                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      TextSpan(text: "Already have an account? "),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("Sign in"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
