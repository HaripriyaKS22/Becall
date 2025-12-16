import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------- Model ----------
class SurveyAnswer {
  final int id;
  final String questionName;
  final String familyName;
  final String staff;         // added_by_name
  final String customer;      // can be "— No Customer —"
  final String answer;
  final String? note;
  final DateTime createdAt;

  SurveyAnswer({
    required this.id,
    required this.questionName,
    required this.familyName,
    required this.staff,
    required this.customer,
    required this.answer,
    required this.note,
    required this.createdAt,
  });

  factory SurveyAnswer.fromJson(Map<String, dynamic> j) {
    return SurveyAnswer(
      id: j['id'],
      questionName: j['question_name'] ?? '',
      familyName: j['family_name'] ?? '',
      staff: j['added_by_name'] ?? 'Unknown',
      customer: (j['customer_name'] == null || (j['customer_name'] as String).trim().isEmpty)
          ? '— No Customer —'
          : j['customer_name'],
      answer: j['answer'] ?? '-', 
      note: j['note'],
      createdAt: DateTime.parse(j['created_at']).toLocal(),
    );
  }
}

// ---------- Screen ----------
class SurveyReportPage extends StatefulWidget {
  const SurveyReportPage({super.key});

  @override
  State<SurveyReportPage> createState() => _SurveyReportPageState();
}

class _SurveyReportPageState extends State<SurveyReportPage> {
  bool loading = true;
  String? error;
  List<SurveyAnswer> items = [];

  // staff -> (customer -> List<SurveyAnswer>)
  Map<String, Map<String, List<SurveyAnswer>>> grouped = {};

  String staffSearch = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final token = await _getToken();

      // TODO: adjust endpoint to your actual one
      // I used `survay` to match your route naming.
      final uri = Uri.parse('$api/api/answers/');
      final res = await http.get(uri, headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      });

      if (res.statusCode != 200) {
        throw Exception('Server ${res.statusCode}');
      }

      final decoded = jsonDecode(res.body);
      final List<dynamic> raw = decoded['data'] ?? [];

      items = raw.map((e) => SurveyAnswer.fromJson(e)).toList();
      _group();

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }
  

  void _group() {
   
    final Map<String, Map<String, List<SurveyAnswer>>> g = {};
    for (final a in items) {
      g.putIfAbsent(a.staff, () => {});
      g[a.staff]!.putIfAbsent(a.customer, () => []);
      g[a.staff]![a.customer]!.add(a);
    }
    // sort newest first inside each customer
    for (final s in g.values)
    {
      for (final list in s.values) {
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    }
    grouped = g;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 26, 164, 143),
        title: const Text('Survey Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Reload',
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Failed to load: $error',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // search staff
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: TextField(
                        onChanged: (v) => setState(() => staffSearch = v),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search staff...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF121212),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.tealAccent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemCount: _filteredStaff().length,
                        itemBuilder: (_, i) {
                          final staff = _filteredStaff()[i];
                          final customerMap = grouped[staff]!;
                          final customers =
                              customerMap.keys.toList()..sort();

                          return _Card(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.white24,
                                listTileTheme: const ListTileThemeData(
                                    iconColor: Colors.white),
                              ),
                              child: ExpansionTile(
                                collapsedIconColor: Colors.white,
                                iconColor: Colors.tealAccent,
                                textColor: Colors.white,
                                collapsedTextColor: Colors.white,
                                title: Row(
                                  children: [
                                    const Icon(Icons.person,
                                        color: Colors.tealAccent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(staff,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    _Pill('${customers.length} customers'),
                                  ],
                                ),
                                children: customers.map((cust) {
                                  final qa = customerMap[cust]!;
                                  return Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                          top: BorderSide(
                                              color: Colors.white10)),
                                    ),
                                    child: ExpansionTile(
                                      title: Row(
                                        children: [
                                          const Icon(Icons.store,
                                              color: Colors.white70, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(cust,
                                                style: const TextStyle(
                                                    color: Colors.white70)),
                                          ),
                                          _Pill('${qa.length} Q&A'),
                                        ],
                                      ),
                                      collapsedIconColor: Colors.white70,
                                      iconColor: Colors.tealAccent,
                                      textColor: Colors.white,
                                      childrenPadding: const EdgeInsets.only(
                                          left: 12, right: 12, bottom: 12),
                                      children: [
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: qa.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(
                                                  color: Colors.white12),
                                          itemBuilder: (_, k) {
                                            final q = qa[k];
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(q.questionName,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    q.answer.isEmpty
                                                        ? '-'
                                                        : q.answer,
                                                    style: const TextStyle(
                                                        color:
                                                            Colors.white70),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.calendar_today,
                                                          size: 14,
                                                          color:
                                                              Colors.white38),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        df.format(q.createdAt),
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white38),
                                                      ),
                                                    ],
                                                  ),
                                                  if (q.note != null &&
                                                      q.note!
                                                          .trim()
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .sticky_note_2,
                                                            size: 14,
                                                            color:
                                                                Colors.tealAccent),
                                                        const SizedBox(
                                                            width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            q.note!,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .tealAccent),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  List<String> _filteredStaff() {
    final keys = grouped.keys
        .where((s) => s.toLowerCase().contains(staffSearch.toLowerCase()))
        .toList();
    keys.sort();
    return keys;
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 26, 164, 143).withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color.fromARGB(255, 26, 164, 143)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color.fromARGB(255, 26, 164, 143),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
