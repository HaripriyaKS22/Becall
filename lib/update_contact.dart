import 'dart:convert';
import 'package:becall2/add_contact.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as https;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:becall2/api.dart';

class UpdateContactPage extends StatefulWidget {
  final int id;
  const UpdateContactPage({super.key, required this.id});

  @override
  State<UpdateContactPage> createState() => _UpdateContactPageState();
}

class _UpdateContactPageState extends State<UpdateContactPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  final Color accent = const Color.fromARGB(255, 26, 164, 143);

  List<dynamic> _states = [];
  String? _selectedState;
  bool _loading = true;
  bool _stateLoading = true;
  String ?_selectedDistrict;

  @override
  void initState() {
    super.initState();
    _fetchStates();
    _fetchContactDetails();
    getDistrict();
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchStates() async {
    try {
      final token = await getToken();
      final response = await https.get(
        Uri.parse('$api/api/states/'),
        headers: {'Authorization': 'Bearer $token',"Content-Type": "application/json",},
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
 

  Future<void> _fetchContactDetails() async {
    try {
      final token = await getToken();
      final response = await https.get(
        Uri.parse('$api/api/contact/info/${widget.id}/'),
        headers: {'Authorization': 'Bearer $token',"Content-Type": "application/json",},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _firstNameCtrl.text = data['first_name'] ?? '';
          _lastNameCtrl.text = data['last_name'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _emailCtrl.text = data['email'] ?? '';
          _selectedState = data['state']?.toString();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateContact() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final token = await getToken();
      final response = await https.put(
        Uri.parse('$api/api/contact/info/${widget.id}/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'state': _selectedState,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contact updated successfully!'),
            backgroundColor: accent,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    AddContactFormPage(phoneNumber: _phoneCtrl.text.trim()),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update contact. Code: ${response.statusCode}',
            ),
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
        title: const Text('Update Contact'),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _firstNameCtrl,
                        decoration: _inputDecoration('First Name'),
                        style: const TextStyle(color: Colors.white),
                        validator:
                            (v) => v!.isEmpty ? 'Enter first name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameCtrl,
                        decoration: _inputDecoration('Last Name'),
                        style: const TextStyle(color: Colors.white),
                        validator: (v) => v!.isEmpty ? 'Enter last name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: _inputDecoration('Phone Number'),
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        validator:
                            (v) => v!.isEmpty ? 'Enter phone number' : null,
                      ),
                      const SizedBox(height: 16),
                      _stateLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedState = value);
                            },
                            validator:
                                (v) => v == null ? "Select a state" : null,
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
                          onPressed: _updateContact,
                          child: const Text(
                            'Update Contact',
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
              ),
    );
  }
}
