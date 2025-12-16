import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:becall2/update_contact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as https;
import 'package:shared_preferences/shared_preferences.dart';

class AddContactFormPage extends StatefulWidget {
  final String phoneNumber;
  const AddContactFormPage({super.key, required this.phoneNumber});

  @override
  State<AddContactFormPage> createState() => _AddContactFormPageState();
}

class _AddContactFormPageState extends State<AddContactFormPage> {
  final GlobalKey<FormState> _addFormKey = GlobalKey<FormState>();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  final Color accent = const Color.fromARGB(255, 26, 164, 143);

  List<dynamic> _states = [];
  String? _selectedState;
  String ?_selectedDistrict;
  List<dynamic> _customers = [];
  bool _loading = true;
      bool _stateLoading = true;

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getid() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('id');
  }

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = widget.phoneNumber;
    _fetchCustomers();
    _fetchStates();
    getDistrict();
  }
  List<Map<String, dynamic>> district = [];


  Future<void> getDistrict() async {
    try {
      final token = await getToken();
      final response = await https.get(
        Uri.parse('$api/api/districts/add/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final dataList = parsed['data'] as List;

        setState(() {
          district = dataList
              .map((q) => {
                    'id': q['id'],
                    'state_name': q['state_name'],
                    'name': q['name'],
                  
                  })
              .toList();
        });
      }
    } catch (error) {
    }
  }
  Future<void> _fetchStates() async {
    try {
      final token = await getToken();
      final url = Uri.parse("$api/api/states/");
      final response = await https.get(
        url,
        headers: {"Authorization": "Bearer $token",
        "Content-Type": "application/json",
        
        },
      );


      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data =
            decoded is List ? decoded : (decoded['data'] ?? []);
        setState(() {
          _states = data;
          _stateLoading = false;
        });
      } else {
        setState(() => _stateLoading = false);
      }
    } catch (e) {
      setState(() => _stateLoading = false);
    }
  }

  Future<void> _fetchCustomers() async {
    var token = await getToken();
    var id = await getid();

    setState(() => _loading = true);
    try {
      var response = await https.get(
        Uri.parse("$api/api/contact/info/staff/$id/"),
        headers: {"Authorization": "Bearer $token"},
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
      setState(() {
        _customers = [];
        _loading = false;
      });
    }
  }

  Future<void> _saveContact() async {
    if (!_addFormKey.currentState!.validate()) return;

    if (_selectedState == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a state')));
      return;
    }

    if (!await FlutterContacts.requestPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied')),
      );
      return;
    }

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    final contact =
        Contact()
          ..name.first = firstName
          ..name.last = lastName
          ..phones = [Phone(phone)]
          ..emails = email.isNotEmpty ? [Email(email)] : [];

    await FlutterContacts.insertContact(contact);
    var token = await getToken();

    try {
      var response = await https.post(
        Uri.parse("$api/api/contact/info/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "first_name": firstName,
          "last_name": lastName,
          "phone": phone,
          "email": email,
          "state": _selectedState,
          "district": _selectedDistrict,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contact saved successfully!'),
            backgroundColor: accent,
          ),
        );
        _addFormKey.currentState?.reset();
        _firstNameCtrl.clear();
        _lastNameCtrl.clear();
        _phoneCtrl.clear();
        _emailCtrl.clear();
        setState(() => _selectedState = null);
        _fetchCustomers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save. Code: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.white, width: 1.5),
      borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
    fillColor: Colors.grey[900],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Add New Contact'),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _addFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstNameCtrl,
                    decoration: _inputDecoration('First Name'),
                    validator: (v) => v!.isEmpty ? 'Enter first name' : null,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameCtrl,
                    decoration: _inputDecoration('Last Name'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: _inputDecoration('Phone Number'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Enter phone number' : null,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  _stateLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                      : DropdownButtonFormField<String>(
                        value: _selectedState,
                        decoration: _inputDecoration("Select State"),
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        items:
                            _states.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem<String>(
                                value: s['id'].toString(),
                                child: Text(
                                  s['name'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedState = value);
                        },
                        validator: (v) => v == null ? "Select a state" : null,
                      ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                        value: _selectedDistrict,
                        decoration: _inputDecoration("Select district"),
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        items:
                            district.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem<String>(
                                value: s['id'].toString(),
                                child: Text(
                                  s['name'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedDistrict = value);
                        },
                        validator: (v) => v == null ? "Select a district" : null,
                      ),
                  const SizedBox(height: 16),

                  
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                      onPressed: _saveContact,
                      child: const Text(
                        'Save Contact',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Saved Contacts",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_customers.isEmpty)
              const Center(
                child: Text(
                  "No contacts found",
                  style: TextStyle(color: Colors.white),
                ),
              )
            else
              Column(
                children:
                    _customers.map((c) {
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                          title: Text(
                            "${c['first_name']} ${c['last_name']}",
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Phone: ${c['phone']}",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (c['email'] != null &&
                                  c['email'].toString().isNotEmpty)
                                Text(
                                  "Email: ${c['email']}",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              if (c['state_name'] != null &&
                                  c['state_name'].toString().isNotEmpty)
                                Text(
                                  "State: ${c['state_name']}",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => UpdateContactPage(id: c['id']),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
