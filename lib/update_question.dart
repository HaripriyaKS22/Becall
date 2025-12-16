import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:becall2/api.dart';

class UpdateQuestion extends StatefulWidget {
  final int id;
  const UpdateQuestion({super.key, required this.id});

  @override
  State<UpdateQuestion> createState() => _UpdateQuestionState();
}

class _UpdateQuestionState extends State<UpdateQuestion> {
  List<Map<String, dynamic>> fam = [];
  String? selectedFamily;
  final TextEditingController questionController = TextEditingController();
  bool isLoading = false;
  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();
    getFamily();
    getquestions();
    getquestionsid();
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> getFamily() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$api/api/familys/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final productsData = parsed['data'] as List;
        setState(() {
          fam = productsData
              .map((p) => {'id': p['id'], 'name': p['name']})
              .toList();
        });
      }
    } catch (error) {
    }
  }

  Future<void> getquestions() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$api/api/questionnaires/'),
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
                    'family_name': q['family_name'],
                    'question': q['questions'],
                    'created_by': q['created_by_name'],
                    'date': q['created_at'],
                  })
              .toList();
        });
      }
    } catch (error) {
    }
  }

  Future<void> getquestionsid() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$api/api/questionnaires/${widget.id}/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final data = parsed['data'] as Map<String, dynamic>;

        setState(() {
          selectedFamily = data['family'].toString();
          questionController.text = data['questions'] ?? '';
        });
      }
    } catch (error) {
    }
  }

  Future<void> submitQuestion() async {
    if (selectedFamily == null || questionController.text.trim().isEmpty) {
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
      final response = await http.put(
        Uri.parse('$api/api/questionnaires/${widget.id}/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'family': selectedFamily,
          'questions': questionController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        questionController.clear();
        setState(() => selectedFamily = null);
        getquestions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update question.'),
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
          'Update Questions',
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
                // ------------- UPDATE FORM BOX -------------
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
                        "Select Family",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        dropdownColor: Colors.grey[900],
                        value: selectedFamily,
                        items: fam
                            .map((f) => DropdownMenuItem(
                                  value: f['id'].toString(),
                                  child: Text(
                                    f['name'],
                                    style:
                                        const TextStyle(color: Colors.white),
                                  ),
                                ))
                            .toList(),
                        decoration: InputDecoration(
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
                        onChanged: (val) =>
                            setState(() => selectedFamily = val),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Enter Question",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: questionController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Type your question here...",
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
                          onPressed: isLoading ? null : submitQuestion,
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

                // ------------- EXISTING QUESTIONS -------------
                const SizedBox(height: 30),
                const Divider(color: Colors.tealAccent, thickness: 1),
                const SizedBox(height: 10),
                const Text(
                  "Existing Questions",
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
                          return Container(
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
                                  "Family: ${q['family_name']}",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                                Text(
                                  "By: ${q['created_by']}",
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                                Text(
                                  "Date: ${q['date'].toString().substring(0, 10)}",
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12),
                                ),
                              ],
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
