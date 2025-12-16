import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:becall2/homepage.dart';
import 'package:becall2/registeration_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  const OtpPage({super.key, required this.phoneNumber});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  final _rawFocusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    for (final r in _rawFocusNodes) r.dispose();
    super.dispose();
  }

  Future<void> postOtp() async {
    final enteredOtp = _controllers.map((c) => c.text).join();
    try {
      final response = await http.post(
        Uri.parse('$api/api/otp/verify/'),
              headers: {"Content-Type": "application/json"},

        body: {"otp": enteredOtp, "phone": widget.phoneNumber},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        await prefs.setString('id', data['user']['id'].toString());


        final bool firstTime = data['first_time'] == true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color.fromARGB(255, 26, 164, 143),
            content: Text('OTP verified successfully'),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => firstTime ? const RegisterationPage() : const Homepage(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('OTP verification failed'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('An error occurred. Please try again later.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // ===== Centered main content =====
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    // Allows scrolling if keyboard covers fields
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset("lib/assets/logo.png", height: 100),
                        const SizedBox(height: 10),

                        const Text(
                          'Enter OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter otp sent to your mobile number',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color.fromARGB(88, 255, 255, 255),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // OTP input fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) {
                            return SizedBox(
                              width: 55,
                              child: RawKeyboardListener(
                                focusNode: _rawFocusNodes[index],
                                onKey: (event) {
                                  if (event is RawKeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.backspace) {
                                    if (_controllers[index].text.isEmpty &&
                                        index > 0) {
                                      _controllers[index - 1].clear();
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  }
                                },
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0', // 👈 placeholder
                                    hintStyle: const TextStyle(
                                      color: Colors.grey, // 👈 ash/grey color
                                      fontSize: 20,
                                      
                                    ),
                                    counterText: '',
                                    filled: true,
                                    fillColor: Colors.grey[900],
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color.fromARGB(
                                          255,
                                          26,
                                          164,
                                          143,
                                        ),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (value.length == 1 && index < 3) {
                                      _focusNodes[index + 1].requestFocus();
                                    }
                                  },
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 30),

                        // Verify Button
                        // Verify Button
                        Center(
                          child: SizedBox(
                            width:
                                280, // 👈 set the width you want (e.g. 150–200)
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  26,
                                  164,
                                  143,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: postOtp,
                              child: const Text(
                                'Verify OTP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Resend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Didn't get the OTP? ",
                              style: TextStyle(color: Colors.white70),
                            ),
                            GestureDetector(
                              onTap: () {
                                // TODO: resend OTP
                              },
                              child: const Text(
                                'Resend',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 26, 164, 143),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ===== Change number fixed at bottom =====
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GestureDetector(
                  onTap: () {
                    // TODO: change number
                  },
                  child: const Text(
                    'Change number',
                    style: TextStyle(color: Color.fromARGB(97, 192, 191, 191), fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
