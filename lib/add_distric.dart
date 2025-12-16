import 'dart:convert';

import 'package:becall2/update_district.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:becall2/api.dart';

class AddDistric extends StatefulWidget {
  
   AddDistric({super.key});

  @override
  State<AddDistric> createState() => _AddDistricState();
}

class _AddDistricState extends State<AddDistric> {
  List<Map<String, dynamic>> fam = [];
  String? selectedFamily;
  final TextEditingController questionController = TextEditingController();
  bool isLoading = false;
  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();
    _fetchStates();
    getDistrict();
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  List<dynamic> _states = [];
      bool _stateLoading = true;
  String? _selectedState;

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
Future<void> _fetchStates() async {
  try {
    final token = await getToken();
    final url = Uri.parse("$api/api/states/");
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token",
      "Content-Type": "application/json",},
    );

    if (!mounted) return; // ✅ Prevent calling setState after dispose

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
    if (mounted) setState(() => _stateLoading = false);
  }
}


  Future<void> getDistrict() async {
    try {
      final token = await getToken();
      final response = await http.get(
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
          questions = dataList
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
 
  Future<void> submitdistrict() async {
    if (_selectedState == null || questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a family and enter a question.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
 
    setState(() => isLoading = true);

    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$api/api/districts/add/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          
          'state': _selectedState,
          'name': questionController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('District added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        questionController.clear();
        setState(() => selectedFamily = null);
        await getDistrict();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add Distrrict.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1AA48F),
        title: const Text(
          'Add District',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          reverse: true,
          padding: const EdgeInsets.all(16.0),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------ MAIN FORM ------------------
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1AA48F),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1AA48F).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Select State",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
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
                      const Text(
                        "Enter District",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: questionController,
                  
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Enter district name",
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.6)),
                          filled: true,
                          fillColor: Colors.black,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Color(0xFF1AA48F), width: 1.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Color(0xFF1AA48F), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: ElevatedButton(
                          onPressed: isLoading ? null : submitdistrict,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1AA48F),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  "SUBMIT",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ------------------ EXISTING QUESTIONS ------------------
                const SizedBox(height: 30),
                const Divider(color: Colors.tealAccent, thickness: 1),
                const SizedBox(height: 10),
                const Text(
                  "Existing Districts",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                questions.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            "No questions available.",
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          final q = questions[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      UpdateDistrict(id: q['id']),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF1AA48F),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q['question'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "District: ${q['name']}",
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                  Text(
                                    "State: ${q['state_name']}",
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                 
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
