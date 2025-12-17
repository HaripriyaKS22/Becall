import 'dart:convert';
import 'package:becall2/admin_personwise_report.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:becall2/api.dart';

class FamilyUserWisePage extends StatefulWidget {
  final int familyId;
  final String familyName;

  const FamilyUserWisePage({
    super.key,
    required this.familyId,
    required this.familyName,
  });

  @override
  State<FamilyUserWisePage> createState() => _FamilyUserWisePageState();
}

class _FamilyUserWisePageState extends State<FamilyUserWisePage> {
  List<dynamic> userWiseFamilyData = [];
  bool isLoading = true;
  int gtProductiveCalls = 0;
  int gtActiveCalls = 0;
  int gtTotalCalls = 0;

  int gtProductiveDuration = 0;
  int gtActiveDuration = 0;
  int gtTotalDuration = 0;

  double gtAmount = 0.0;

  @override
  void initState() {
    super.initState();
    fetchUserWiseCallReportByFamily(widget.familyId);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchUserWiseCallReportByFamily(int familyId) async {
    try {
      final token = await getToken();

      final url = Uri.parse(
        "$api/api/call/reports/family/$familyId/user-wise-call/report/",
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];

        setState(() {
          userWiseFamilyData = data;
          isLoading = false;
        });
        _computeTotals();
      } else {
        setState(() {
          userWiseFamilyData = [];
          isLoading = false;
        });
        _computeTotals();
      }
    } catch (e) {
      setState(() {
        userWiseFamilyData = [];
        isLoading = false;
      });
      _computeTotals();
    }
  }

  void _computeTotals() {
    int totalProductive = 0;
    int totalActive = 0;
    int totalCalls = 0;

    int totalProdDur = 0;
    int totalActiveDur = 0;
    int totalDur = 0;

    double totalAmt = 0.0;

    for (final item in userWiseFamilyData) {
      totalProductive += (item['productive_calls'] ?? 0) is int
          ? (item['productive_calls'] ?? 0) as int
          : int.tryParse((item['productive_calls'] ?? 0).toString()) ?? 0;
      totalActive += (item['active_calls'] ?? 0) is int
          ? (item['active_calls'] ?? 0) as int
          : int.tryParse((item['active_calls'] ?? 0).toString()) ?? 0;
      totalCalls += (item['total_calls'] ?? 0) is int
          ? (item['total_calls'] ?? 0) as int
          : int.tryParse((item['total_calls'] ?? 0).toString()) ?? 0;

      totalProdDur += (item['productive_duration'] ?? 0) is int
          ? (item['productive_duration'] ?? 0) as int
          : int.tryParse((item['productive_duration'] ?? 0).toString()) ?? 0;
      totalActiveDur += (item['active_duration'] ?? 0) is int
          ? (item['active_duration'] ?? 0) as int
          : int.tryParse((item['active_duration'] ?? 0).toString()) ?? 0;
      totalDur += (item['total_duration'] ?? 0) is int
          ? (item['total_duration'] ?? 0) as int
          : int.tryParse((item['total_duration'] ?? 0).toString()) ?? 0;

      final amt = item['productive_amount'] ?? 0;
      if (amt is num) {
        totalAmt += amt.toDouble();
      } else {
        final parsed = double.tryParse(amt.toString());
        if (parsed != null) totalAmt += parsed;
      }
    }

    setState(() {
      gtProductiveCalls = totalProductive;
      gtActiveCalls = totalActive;
      gtTotalCalls = totalCalls;

      gtProductiveDuration = totalProdDur;
      gtActiveDuration = totalActiveDur;
      gtTotalDuration = totalDur;

      gtAmount = totalAmt;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 26, 164, 143),
        title: Text(
          "${widget.familyName.toUpperCase()} SUMMARY",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userWiseFamilyData.isEmpty
          ? const Center(
              child: Text(
                "No data found",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101010),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        // ================= HEADER STRIP =================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 26, 164, 143),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                            ),
                          ),
                          child: Text(
                            "TOTAL AMOUNT   ₹ ${gtAmount}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),

                        // ================= GRID =================
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Table(
                            border: TableBorder.all(
                              color: Colors.white24,
                              width: 1,
                            ),
                            children: [
                              // ================= ROW 1 =================
                              TableRow(
                                children: [
                                  _summaryCell(
                                    "Productive Calls",
                                    gtProductiveCalls.toString(),
                                  ),
                                  _summaryCell(
                                    "Active Calls",
                                    gtActiveCalls.toString(),
                                  ),
                                  _summaryCell(
                                    "Total Calls",
                                    gtTotalCalls.toString(),
                                  ),
                                ],
                              ),

                              // ================= ROW 2 =================
                              TableRow(
                                children: [
                                  _summaryCell(
                                    "Prod Duration",
                                    formatDurationHuman(gtProductiveDuration),
                                  ),
                                  _summaryCell(
                                    "Active Duration",
                                    formatDurationHuman(gtActiveDuration),
                                  ),
                                  _summaryCell(
                                    "Total Duration",
                                    formatDurationHuman(gtTotalDuration),
                                  ),
                                ],
                              ),

                              // ================= ROW 3 =================
                              // TableRow(
                              //   children: [
                              //     _summaryCell("", ""),
                              //     _summaryCell(
                              //       "Total Amount",
                              //       "₹${gtAmount.toStringAsFixed(0)}",
                              //       highlight: true,
                              //     ),
                              //     _summaryCell("", ""),
                              //   ],
                              // ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width * 2,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF101010),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Table(
                          border: TableBorder.symmetric(
                            inside: const BorderSide(
                              color: Colors.white24,
                              width: 0.5,
                            ),
                            outside: const BorderSide(
                              color: Colors.white24,
                              width: 1,
                            ),
                          ),
                          columnWidths: const {
                            0: FixedColumnWidth(240), // Staff
                            1: FixedColumnWidth(140), // Designation
                            2: FixedColumnWidth(120), // Productive
                            3: FixedColumnWidth(120), // Active
                            4: FixedColumnWidth(120), // Total
                            5: FixedColumnWidth(160), // Prod Duration
                            6: FixedColumnWidth(160), // Active Duration
                            7: FixedColumnWidth(160), // Total Duration
                            8: FixedColumnWidth(140), // Amount
                          },
                          children: [
                            /// HEADER
                            const TableRow(
                              decoration: BoxDecoration(
                                color: Color.fromARGB(255, 26, 164, 143),
                              ),
                              children: [
                                _HeaderCell("Staff"),
                                _HeaderCell("Designation"),
                                _HeaderCell("Productive"),
                                _HeaderCell("Active"),
                                _HeaderCell("Total"),
                                _HeaderCell("Prod Duration"),
                                _HeaderCell("Active Duration"),
                                _HeaderCell("Total Duration"),
                                _HeaderCell("Amount"),
                              ],
                            ),

                            /// DATA ROWS
                            ...userWiseFamilyData.map((item) {
                              final int userId = item['created_by_id'];

                              final name = (item['created_by__name'] ?? "")
                                  .toString();
                              final designation =
                                  (item['created_by__designation'] ?? "")
                                      .toString();

                              final productiveCalls =
                                  item['productive_calls'] ?? 0;
                              final activeCalls = item['active_calls'] ?? 0;
                              final totalCalls = item['total_calls'] ?? 0;

                              final productiveDuration =
                                  item['productive_duration'] ?? 0;
                              final activeDuration =
                                  item['active_duration'] ?? 0;
                              final totalDuration = item['total_duration'] ?? 0;

                              final amount = (item['productive_amount'] ?? 0)
                                  .toDouble();

                              return TableRow(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF181818),
                                ),
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              Admin_PersonwiseReport(
                                                id: userId,
                                              ),
                                        ),
                                      );
                                    },
                                    child: _DataCell(
                                      name,
                                      isAmount:
                                          true, // highlight clickable text
                                    ),
                                  ),
                                  _DataCell(designation),
                                  _DataCell("$productiveCalls"),
                                  _DataCell("$activeCalls"),
                                  _DataCell("$totalCalls"),
                                  _DataCell(
                                    formatDurationHuman(productiveDuration),
                                    small: true,
                                  ),
                                  _DataCell(
                                    formatDurationHuman(activeDuration),
                                    small: true,
                                  ),
                                  _DataCell(
                                    formatDurationHuman(totalDuration),
                                    small: true,
                                  ),

                                  _DataCell(
                                    "₹${amount.toStringAsFixed(0)}",
                                    isAmount: true,
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }
}

/// HEADER CELL
class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// DATA CELL
class _DataCell extends StatelessWidget {
  final String text;
  final bool isAmount;
  final bool small; // 👈 for durations

  const _DataCell(this.text, {this.isAmount = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8), // slightly tighter
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: small ? 12 : 14, // 👈 duration smaller
          color: isAmount
              ? const Color.fromARGB(255, 26, 164, 143)
              : Colors.white70,
          fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isAmount;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isAmount
                ? const Color.fromARGB(255, 26, 164, 143)
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

String formatDurationHuman(int seconds) {
  if (seconds <= 0) return "0 sec";

  final int hrs = seconds ~/ 3600;
  final int mins = (seconds % 3600) ~/ 60;
  final int secs = seconds % 60;

  final List<String> parts = [];

  if (hrs > 0) {
    parts.add("$hrs h");
  }

  if (mins > 0) {
    parts.add("$mins m");
  }

  if (secs > 0 || parts.isEmpty) {
    parts.add("$secs s");
  }

  return parts.join(" ");
}

Widget _alignedRow({required String label, required List<Widget> values}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 80,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),

      /// VALUES WITH VERTICAL DIVIDERS
      Expanded(
        child: Row(
          children: List.generate(values.length * 2 - 1, (index) {
            if (index.isOdd) {
              // 🔹 Vertical divider
              return Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.white24,
              );
            }
            return Expanded(child: values[index ~/ 2]);
          }),
        ),
      ),
    ],
  );
}

Widget _alignedValue(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ],
  );
}

Widget _summaryCell(String label, String value, {bool highlight = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight
                ? const Color.fromARGB(255, 26, 164, 143)
                : Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.tealAccent, fontSize: 11),
        ),
      ],
    ),
  );
}
