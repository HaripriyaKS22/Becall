import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:becall2/api.dart';

class Survay extends StatefulWidget {
  const Survay({super.key});

  @override
  State<Survay> createState() => _SurvayState();
}

class _SurvayState extends State<Survay> {
  List<Map<String, dynamic>> questions = [];
  Map<int, String> answers = {};
  bool isLoading = true;

  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> customers = [];
  String? selectedCustomerId;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _fetchUser();
    await getCustomers();
    await fetchQuestions();
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchUser() async {
    var token = await getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse("$api/api/profile/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        setState(() => _user = jsonBody['data']);
        print("👤 User profile loaded: ${_user?['name']}");
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching user: $e");
    }
  }

  Future<void> getCustomers() async {
    print("🔍 Fetching customers...");
    try {
      final token = await getToken();

      var response = await http.get(
        Uri.parse('$api/api/staff/customers/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
print(response.body);
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var data = parsed['data'] as List;

        setState(() {
          customers = data
              .map((c) => {
                    'id': c['id'],
                    'name': c['name'],
                    'phone': c['phone'] ?? '',
                  })
              .toList();
        });

        print("✅ Loaded ${customers.length} customers");
      } else {
        debugPrint("❌ Failed to load customers");
      }
    } catch (error) {
      debugPrint("⚠️ Error fetching customers: $error");
    }
  }

 Future<void> fetchQuestions() async {
  print("🔍 Fetching questions...");
  try {
    final token = await getToken();
    if (token == null) return;

    final userFamilyId = _user?['family'];
    final userFamilyName = _user?['family_name'];

    final response = await http.get(
      Uri.parse('$api/api/questionnaires/family/$userFamilyId/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print(response.body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;  // FIXED

      final filteredQuestions = data.where((q) {
        return q['family'] == userFamilyId ||
            q['family_name'] == userFamilyName;
      }).toList();

      setState(() {
        questions = filteredQuestions
            .map((q) => {
                  'id': q['id'],
                  'question': q['questions'],
                  'family': q['family_name'],
                })
            .toList();
        isLoading = false;
      });
    } else {
      debugPrint("❌ Failed to load questions");
      setState(() => isLoading = false);
    }
  } catch (e) {
    debugPrint("⚠️ Error fetching questions: $e");
    setState(() => isLoading = false);
  }
}

  Future<void> submitAnswers() async {
    if (answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer at least one question.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer before submitting.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final token = await getToken();
    final userFamilyId = _user?['family'];

    setState(() => isLoading = true);

    try {
      for (var entry in answers.entries) {
        final payload = {
          "question": entry.key,
          "family": userFamilyId,
          "customer": selectedCustomerId,
          "answer": entry.value,
        };

        print("📤 Sending payload: $payload");

        final response = await http.post(
          Uri.parse('$api/api/answers/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );
print(response.body);
        if (response.statusCode != 200 && response.statusCode != 201) {
          debugPrint("❌ Failed for question ${entry.key}: ${response.body}");
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All answers submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => answers.clear());
    } catch (e) {
      debugPrint("⚠️ Error submitting answers: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error submitting answers.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Filter customers for search
  List<Map<String, dynamic>> get filteredCustomers {
    if (searchQuery.isEmpty) return customers;
    return customers
        .where((c) => c['name']
            .toString()
            .toLowerCase()
            .contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1AA48F),
        title: const Text(
          'Survey',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 🔹 Customer Dropdown with search
                  // 🔹 Customer Dropdown with Search (Fixed Overflow)
Container(
  width: double.infinity, // ✅ Prevent overflow
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.grey[900],
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: const Color(0xFF1AA48F),
      width: 1.2,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Select Customer",
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
      const SizedBox(height: 8),
      // 🔍 Search Bar
      TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search customer...",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.search, color: Colors.teal),
          filled: true,
          fillColor: Colors.black,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          enabledBorder: OutlineInputBorder(
            borderSide:
                const BorderSide(color: Color(0xFF1AA48F), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide:
                const BorderSide(color: Color(0xFF1AA48F), width: 1.2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (value) {
          setState(() => searchQuery = value);
        },
      ),
      const SizedBox(height: 10),
      // ⬇️ Dropdown
      SizedBox(
        width: double.infinity, // ✅ Prevent overflow
        child: DropdownButtonFormField<String>(
          isExpanded: true, // ✅ Fix overflow in small screens
          dropdownColor: Colors.grey[900],
          value: selectedCustomerId,
          items: filteredCustomers
              .map((c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(
                      "${c['name']} (${c['phone']})",
                      overflow: TextOverflow.ellipsis, // ✅ Truncate long names
                      style: const TextStyle(color: Colors.white),
                    ),
                  ))
              .toList(),
          onChanged: (val) {
            setState(() => selectedCustomerId = val);
            debugPrint("✅ Selected Customer: $val");
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  const BorderSide(color: Color(0xFF1AA48F), width: 1.2),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide:
                  const BorderSide(color: Color(0xFF1AA48F), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ],
  ),
),


                  const SizedBox(height: 20),

                  // 🔹 Questions List
                  Expanded(
                    child: ListView.builder(
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        final q = questions[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Q${index + 1}. ${q['question']}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              onChanged: (value) {
                                answers[q['id']] = value;
                              },
                              style:
                                  const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Type your answer...",
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5)),
                                filled: true,
                                fillColor: Colors.black,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1AA48F),
                                      width: 1.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1AA48F),
                                      width: 1.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: submitAnswers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1AA48F),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      "SUBMIT ANSWERS",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
