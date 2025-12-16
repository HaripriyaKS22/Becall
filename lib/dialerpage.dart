import 'dart:convert';
import 'package:becall2/add_contact.dart';
import 'package:becall2/api.dart';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:http/http.dart' as https;
import 'package:shared_preferences/shared_preferences.dart';

class DialerPage extends StatefulWidget {
  const DialerPage({super.key});

  @override
  State<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends State<DialerPage> {
  String enteredNumber = '';
  List<dynamic> _customers = [];
  bool _loading = true;

  Map<String, dynamic>? matchedCustomer;
  bool numberSelected = false; // only enable call after tap

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getid() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('id');
  }

  Future<void> _fetchCustomers() async {
    var token = await getToken();
    var id = await getid();

    setState(() => _loading = true);
    try {
      var response = await https.get(
        Uri.parse("$api/api/contact/info/staff/$id/"),
        headers: {"Authorization": "Bearer $token","Content-Type": "application/json",},
      );

      if (response.statusCode == 200) {
        setState(() {
          _customers = List<dynamic>.from(jsonDecode(response.body));
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _appendDigit(String digit) {
    // Only allow up to 10 digits (excluding non-digit characters)
    final digitsOnly = enteredNumber.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 10 && RegExp(r'\d').hasMatch(digit)) {
      return;
    }
    setState(() {
      enteredNumber += digit;
      _searchCustomer(enteredNumber);
    });
  }

  void _deleteDigit() {
    if (enteredNumber.isNotEmpty) {
      setState(() {
        enteredNumber = enteredNumber.substring(0, enteredNumber.length - 1);
        _searchCustomer(enteredNumber);
      });
    }
  }

  void _searchCustomer(String number) {
    if (number.isEmpty) {
      matchedCustomer = null;
      numberSelected = false;
      return;
    }

    final match = _customers.firstWhere((cust) {
      final phone = cust['phone']?.toString() ?? '';
      return phone.contains(number);
    }, orElse: () => {});

    setState(() {
      matchedCustomer = match.isNotEmpty ? match : null;
      numberSelected = false;
    });
  }

  Future<bool> _ensureCallPermission() async {
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
    }
    return status.isGranted;
  }

  Future<void> _makeDirectCall(String number) async {
    if (await _ensureCallPermission()) {
      await FlutterPhoneDirectCaller.callNumber(number);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call permissions denied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canCall = matchedCustomer != null && numberSelected;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 80),

                  // 👇 Show customer or add contact button
                  if (enteredNumber.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          if (matchedCustomer != null)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  enteredNumber =
                                      matchedCustomer!['phone'] ??
                                      enteredNumber;
                                  numberSelected = true;
                                });
                              },
                              child: Column(
                                children: [
                                  Text(
                                    '${(matchedCustomer!['first_name'] ?? '').toString()} ${(matchedCustomer!['last_name'] ?? '').toString()}'
                                        .trim()
                                        .replaceAll(RegExp(r'\s+'), ' '),
                                    style: TextStyle(
                                      color:
                                          numberSelected
                                              ? const Color.fromARGB(
                                                255,
                                                26,
                                                164,
                                                143,
                                              )
                                              : Colors.grey,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    matchedCustomer!['phone'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 18,
                                    ),
                                  ),
                                  if (!numberSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        "Tap to select this number",
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () {
                                // 👇 Navigate to AddContactFormPage with entered number
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => AddContactFormPage(
                                          phoneNumber: enteredNumber,
                                        ),
                                  ),
                                ).then((_) {
                                  // Optionally refresh customer list after returning
                                  _fetchCustomers();
                                });
                              },
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text("Add Contact"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  26,
                                  164,
                                  143,
                                ),
                                foregroundColor: Colors.black,
                              ),
                            ),
                        ],
                      ),
                    ),
                  // 🔢 Number display
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            enteredNumber,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        if (enteredNumber.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.backspace,
                              color: Colors.white,
                            ),
                            onPressed: _deleteDigit,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔢 Keypad & Call
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var row in [
                          ['1', '2', '3'],
                          ['4', '5', '6'],
                          ['7', '8', '9'],
                          ['*', '0', '#'],
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children:
                                  row
                                      .map(
                                        (label) => GestureDetector(
                                          onTap: () => _appendDigit(label),
                                          child: CircleAvatar(
                                            radius: 35,
                                            backgroundColor: Colors.grey[850],
                                            child: Text(
                                              label,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // 🟢 CALL ICON — only active after selectionxcv
                        GestureDetector(
                          onTap:
                              canCall
                                  ? () {
                                    if (enteredNumber.isNotEmpty) {
                                      _makeDirectCall(enteredNumber);
                                    }
                                  }
                                  : null,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor:
                                canCall
                                    ? const Color.fromARGB(255, 26, 164, 143)
                                    : Colors.grey[800],
                            child: Icon(
                              Icons.call,
                              color: canCall ? Colors.black : Colors.grey,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
