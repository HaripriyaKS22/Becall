import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

class CallreportpersonWise extends StatefulWidget {
  final dynamic id;

  const CallreportpersonWise({super.key, required this.id});

  @override
  State<CallreportpersonWise> createState() => _CallreportpersonWiseState();
}

class _CallreportpersonWiseState extends State<CallreportpersonWise> {
  List<Map<String, dynamic>> groupedData = [];
  Map<String, List<Map<String, dynamic>>> customerGrouped = {};
  bool isLoading = true;

  DateTime? startDate;
  DateTime? endDate;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    DateTime today = DateTime.now();
    startDate = today;
    endDate = today;
    getDateWise(today, today);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  int parseDuration(String duration) {
    int totalSeconds = 0;
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(duration);
    final secMatch = RegExp(r'(\d+)\s*sec').firstMatch(duration);
    if (minMatch != null) totalSeconds += int.parse(minMatch.group(1)!) * 60;
    if (secMatch != null) totalSeconds += int.parse(secMatch.group(1)!);
    return totalSeconds;
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return "${minutes}m ${remainingSeconds}s";
    } else {
      return "${remainingSeconds}s";
    }
  }

  int safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double safeDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// ✅ Get total duration for each customer
  int getTotalDurationForCustomer(List<Map<String, dynamic>> calls) {
    int total = 0;
    for (var c in calls) {
      total += safeInt(c['duration']);
    }
    return total;
  }

  /// ✅ Total duration and amount for all
  int getTotalDurationAll() {
    return groupedData.fold<int>(
      0,
      (sum, row) => sum + safeInt(row['duration']),
    );
  }

  double getTotalAmountAll() {
    return groupedData.fold<double>(
      0.0,
      (sum, row) => sum + safeDouble(row['amount']),
    );
  }

  /// ✅ Group by customer
  Map<String, List<Map<String, dynamic>>> groupByCustomer(
    List<Map<String, dynamic>> data,
  ) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var call in data) {
      final customer = call['customer'] ?? 'Unknown';
      grouped.putIfAbsent(customer, () => []).add(call);
    }
    return grouped;
  }

  Map<String, int> getSessionTotals() {
    int morningTotal = 0;
    int afternoonTotal = 0;

    for (var call in groupedData) {
      if (call['time'] != null && call['time'].toString().isNotEmpty) {
        try {
          DateTime t = DateTime.parse(call['time']).toLocal();
          int hour = t.hour;
          int duration = safeInt(call['duration']);

          if (hour >= 9 && hour < 14) {
            morningTotal += duration; // 9 AM - 2 PM
          } else if (hour >= 14 && hour < 18) {
            afternoonTotal += duration; // 2 PM - 6 PM
          }
        } catch (_) {}
      }
    }

    return {'morning': morningTotal, 'afternoon': afternoonTotal};
  }

  Map<String, Map<String, int>> getHourlyStats(
    List<Map<String, dynamic>> data,
  ) {
    Map<String, Map<String, int>> hourly = {
      '9-10 AM': {'duration': 0, 'count': 0},
      '10-11 AM': {'duration': 0, 'count': 0},
      '11-12 PM': {'duration': 0, 'count': 0},
      '12-1 PM': {'duration': 0, 'count': 0},
      '1-2 PM': {'duration': 0, 'count': 0},
      '2-3 PM': {'duration': 0, 'count': 0},
      '3-4 PM': {'duration': 0, 'count': 0},
      '4-5 PM': {'duration': 0, 'count': 0},
      '5-6 PM': {'duration': 0, 'count': 0},
    };

    for (var call in data) {
      if (call['time'] != null && call['time'].toString().isNotEmpty) {
        try {
          DateTime t = DateTime.parse(call['time']).toLocal();
          int hour = t.hour;
          int duration = safeInt(call['duration']);

          String? key;
          if (hour >= 9 && hour < 10)
            key = '9-10 AM';
          else if (hour >= 10 && hour < 11)
            key = '10-11 AM';
          else if (hour >= 11 && hour < 12)
            key = '11-12 PM';
          else if (hour >= 12 && hour < 13)
            key = '12-1 PM';
          else if (hour >= 13 && hour < 14)
            key = '1-2 PM';
          else if (hour >= 14 && hour < 15)
            key = '2-3 PM';
          else if (hour >= 15 && hour < 16)
            key = '3-4 PM';
          else if (hour >= 16 && hour < 17)
            key = '4-5 PM';
          else if (hour >= 17 && hour < 18)
            key = '5-6 PM';

          if (key != null) {
            hourly[key]!['duration'] =
                (hourly[key]!['duration'] ?? 0) + duration;
            hourly[key]!['count'] = (hourly[key]!['count'] ?? 0) + 1;
          }
        } catch (_) {}
      }
    }

    return hourly;
  }

  Future<void> getDateWise(DateTime from, DateTime to) async {
    setState(() => isLoading = true);
    var token = await getToken();
    try {
      var res = await http.get(
        Uri.parse("$api/api/call/report/staff/${widget.id}/"),
        headers: {"Authorization": "Bearer $token","Content-Type": "application/json",},
      );

      if (res.statusCode == 200) {
        List<dynamic> data = jsonDecode(res.body);
        List<Map<String, dynamic>> filtered =
            data
                .where((call) {
                  DateTime? callDate;
                  if (call['date'] != null &&
                      call['date'].toString().isNotEmpty) {
                    callDate = DateTime.tryParse(call['date'].toString());
                  } else if (call['call_datetime'] != null &&
                      call['call_datetime'].toString().isNotEmpty) {
                    callDate = DateTime.tryParse(
                      call['call_datetime'].toString(),
                    );
                  }
                  if (callDate == null) return false;
                  return callDate.isAfter(
                        from.subtract(const Duration(days: 1)),
                      ) &&
                      callDate.isBefore(to.add(const Duration(days: 1)));
                })
                .map((call) {
                  final createdBy = (call['created_by_name'] ??
                          call['created_by_namme'] ??
                          'Unknown')
                      .toString()
                      .replaceAll('"', '');
                  return {
                    'name': createdBy,
                    'status':
                        call['status']?.toString().replaceAll('"', '') ?? '',
                    'duration': parseDuration(call['duration'] ?? '0 sec'),
                    'time': call['call_datetime'] ?? '',
                    'amount': (call['amount'] ?? 0).toDouble(),
                    'customer': call['customer_name']?.toString() ?? '',
                    'date': call['date']?.toString() ?? '',
                    'audio_file': call['audio_file']?.toString() ?? '',
                  };
                })
                .toList();

        setState(() {
          groupedData = filtered;
          customerGrouped = groupByCustomer(filtered);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Map<String, int> getHourlyBreakup(List<Map<String, dynamic>> data) {
    Map<String, int> hourly = {
      '9-10 AM': 0,
      '10-11 AM': 0,
      '11-12 PM': 0,
      '12-1 PM': 0,
      '1-2 PM': 0,
      '2-3 PM': 0,
      '3-4 PM': 0,
      '4-5 PM': 0,
      '5-6 PM': 0,
    };

    for (var call in data) {
      if (call['time'] != null && call['time'].toString().isNotEmpty) {
        try {
          DateTime t = DateTime.parse(call['time']).toLocal();
          int hour = t.hour;
          int duration = safeInt(call['duration']);
          if (hour >= 9 && hour < 10)
            hourly['9-10 AM'] = (hourly['9-10 AM'] ?? 0) + duration;
          if (hour >= 10 && hour < 11)
            hourly['10-11 AM'] = (hourly['10-11 AM'] ?? 0) + duration;
          if (hour >= 11 && hour < 12)
            hourly['11-12 PM'] = (hourly['11-12 PM'] ?? 0) + duration;
          if (hour >= 12 && hour < 13)
            hourly['12-1 PM'] = (hourly['12-1 PM'] ?? 0) + duration;
          if (hour >= 13 && hour < 14)
            hourly['1-2 PM'] = (hourly['1-2 PM'] ?? 0) + duration;
          if (hour >= 14 && hour < 15)
            hourly['2-3 PM'] = (hourly['2-3 PM'] ?? 0) + duration;
          if (hour >= 15 && hour < 16)
            hourly['3-4 PM'] = (hourly['3-4 PM'] ?? 0) + duration;
          if (hour >= 16 && hour < 17)
            hourly['4-5 PM'] = (hourly['4-5 PM'] ?? 0) + duration;
          if (hour >= 17 && hour < 18)
            hourly['5-6 PM'] = (hourly['5-6 PM'] ?? 0) + duration;
        } catch (_) {}
      }
    }

    return hourly;
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: startDate ?? DateTime.now(),
        end: endDate ?? DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      getDateWise(picked.start, picked.end);
    }
  }

  void _showAudioPopup(String url) async {
    final fullUrl = url.startsWith("http") ? url : "$api$url";
    _audioPlayer.stop();
    await _audioPlayer.setSourceUrl(fullUrl);

    _audioPlayer.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
      Navigator.pop(context);
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "Call Recording",
            style: TextStyle(color: Colors.tealAccent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                activeColor: Colors.tealAccent,
                inactiveColor: Colors.white24,
                min: 0,
                max: _duration.inSeconds.toDouble(),
                value:
                    _position.inSeconds
                        .clamp(0, _duration.inSeconds)
                        .toDouble(),
                onChanged: (value) {
                  setState(() {
                    _position = Duration(seconds: value.toInt());
                  });
                },
                onChangeEnd: (value) async {
                  final position = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(position);
                  if (_isPlaying) await _audioPlayer.resume();
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(_position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      _formatTime(_duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              IconButton(
                iconSize: 60,
                color: Colors.tealAccent,
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
                onPressed: () async {
                  if (_isPlaying) {
                    await _audioPlayer.pause();
                  } else {
                    await _audioPlayer.play(UrlSource(fullUrl));
                  }
                  setState(() => _isPlaying = !_isPlaying);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    String rangeText = "";
    if (startDate != null && endDate != null) {
      final fmt = DateFormat('dd MMM');
      rangeText =
          "${fmt.format(startDate!)} - ${fmt.format(endDate!)} (${DateFormat('yyyy').format(startDate!)})";
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1AA48F),
        title: const Text(
          "Productive Calls",
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: pickDateRange,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.grey[900],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        rangeText.isEmpty ? "Today" : rangeText,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // 🔝 Top Summary: Total CD & Total Invoice Amount
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                      child: Row(
                        children: [
                          // Total CD
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Call Duration",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatDuration(getTotalDurationAll()),
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Total Invoice Amount
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Invoice Amount",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "₹${getTotalAmountAll().toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      child: Card(
                        color: Colors.grey[900],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Builder(
                            builder: (_) {
                              final totals = getSessionTotals();
                              final hourlyStats = getHourlyStats(groupedData);

                              final morningKeys = [
                                "9-10 AM",
                                "10-11 AM",
                                "11-12 PM",
                                "12-1 PM",
                                "1-2 PM",
                              ];
                              final afternoonKeys = [
                                "2-3 PM",
                                "3-4 PM",
                                "4-5 PM",
                                "5-6 PM",
                              ];

                              TableRow buildHeaderRow() {
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.3),
                                  ),
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "Time",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "Duration",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "Calls",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              TableRow buildDataRow(String key) {
                                final stat =
                                    hourlyStats[key] ??
                                    {'duration': 0, 'count': 0};
                                return TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.white24),
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        key,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        formatDuration(stat['duration'] ?? 0),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.tealAccent,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        "${stat['count']} calls",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Staff Session Summary",
                                    style: TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // 🌅 Morning Session
                                  const Text(
                                    "Morning Session (9 AM - 2 PM)",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Table(
                                    border: TableBorder.all(
                                      color: Colors.white24,
                                      width: 0.5,
                                    ),
                                    columnWidths: const {
                                      0: FlexColumnWidth(2),
                                      1: FlexColumnWidth(2),
                                      2: FlexColumnWidth(2),
                                    },
                                    children: [
                                      buildHeaderRow(),
                                      ...morningKeys.map(buildDataRow),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        "Total Call Duration: ${formatDuration(totals['morning'] ?? 0)}",
                                        style: const TextStyle(
                                          color: Colors.tealAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // 🌇 Afternoon Session
                                  const Text(
                                    "Afternoon Session (2 PM - 6 PM)",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Table(
                                    border: TableBorder.all(
                                      color: Colors.white24,
                                      width: 0.5,
                                    ),
                                    columnWidths: const {
                                      0: FlexColumnWidth(2),
                                      1: FlexColumnWidth(2),
                                      2: FlexColumnWidth(2),
                                    },
                                    children: [
                                      buildHeaderRow(),
                                      ...afternoonKeys.map(buildDataRow),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        "Total Call Duration: ${formatDuration(totals['afternoon'] ?? 0)}",
                                        style: const TextStyle(
                                          color: Colors.tealAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // ✅ Customer-wise breakdown (now non-scrolling inner list so the whole page scrolls)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children:
                            customerGrouped.entries.map((entry) {
                              final customer = entry.key;
                              final calls = entry.value;
                              final hourly = getHourlyBreakup(calls);
                              final totalDuration = getTotalDurationForCustomer(
                                calls,
                              );
                              final totalAmount = calls.fold<num>(
                                0,
                                (sum, c) =>
                                    sum +
                                    ((c['amount'] is num)
                                        ? c['amount'] as num
                                        : 0),
                              );

                              return Card(
                                color: Colors.grey[900],
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: ExpansionTile(
                                  collapsedIconColor: Colors.tealAccent,
                                  iconColor: Colors.tealAccent,
                                  title: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          customer,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.tealAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        flex: 3,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            children: [
                                              Text(
                                                formatDuration(totalDuration),
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "₹${totalAmount.toStringAsFixed(2)}",
                                                style: const TextStyle(
                                                  color: Colors.tealAccent,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // ☀️ Morning session (9 AM – 2 PM)
                                          const Text(
                                            "Morning Session (9 AM - 2 PM)",
                                            style: TextStyle(
                                              color: Colors.tealAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          ...hourly.entries
                                              .where(
                                                (e) => [
                                                  "9-10 AM",
                                                  "10-11 AM",
                                                  "11-12 PM",
                                                  "12-1 PM",
                                                  "1-2 PM",
                                                ].contains(e.key),
                                              )
                                              .map(
                                                (entry) => Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      entry.key,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    Text(
                                                      formatDuration(
                                                        entry.value,
                                                      ),
                                                      style: const TextStyle(
                                                        color:
                                                            Colors.tealAccent,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .toList(),
                                          const Divider(
                                            color: Colors.white24,
                                            height: 12,
                                          ),

                                          // ✅ Morning total
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Morning Total CD:",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                formatDuration(
                                                  hourly.entries
                                                      .where(
                                                        (e) => [
                                                          "9-10 AM",
                                                          "10-11 AM",
                                                          "11-12 PM",
                                                          "12-1 PM",
                                                          "1-2 PM",
                                                        ].contains(e.key),
                                                      )
                                                      .fold<int>(
                                                        0,
                                                        (sum, e) =>
                                                            sum + e.value,
                                                      ),
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.tealAccent,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // 🌇 Afternoon session (2 PM – 6 PM)
                                          const Text(
                                            "Afternoon Session (2 PM - 6 PM)",
                                            style: TextStyle(
                                              color: Colors.tealAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          ...hourly.entries
                                              .where(
                                                (e) => [
                                                  "2-3 PM",
                                                  "3-4 PM",
                                                  "4-5 PM",
                                                  "5-6 PM",
                                                ].contains(e.key),
                                              )
                                              .map(
                                                (entry) => Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      entry.key,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    Text(
                                                      formatDuration(
                                                        entry.value,
                                                      ),
                                                      style: const TextStyle(
                                                        color:
                                                            Colors.tealAccent,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .toList(),
                                          const Divider(
                                            color: Colors.white24,
                                            height: 12,
                                          ),

                                          // ✅ Afternoon total
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Afternoon Total CD:",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                formatDuration(
                                                  hourly.entries
                                                      .where(
                                                        (e) => [
                                                          "2-3 PM",
                                                          "3-4 PM",
                                                          "4-5 PM",
                                                          "5-6 PM",
                                                        ].contains(e.key),
                                                      )
                                                      .fold<int>(
                                                        0,
                                                        (sum, e) =>
                                                            sum + e.value,
                                                      ),
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.tealAccent,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Divider(color: Colors.white24),
                                    Column(
                                      children:
                                          calls.map((row) {
                                            String formattedTime = '';
                                            if (row['time'] != null &&
                                                row['time']
                                                    .toString()
                                                    .isNotEmpty) {
                                              try {
                                                final parsed =
                                                    DateTime.parse(
                                                      row['time'],
                                                    ).toLocal();
                                                formattedTime = DateFormat(
                                                  'hh:mm a',
                                                ).format(parsed);
                                              } catch (_) {}
                                            }

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    formattedTime,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  Text(
                                                    formatDuration(
                                                      safeInt(row['duration']),
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  Text(
                                                    row['amount'] == 0
                                                        ? "Active"
                                                        : "₹${(row['amount'] ?? 0).toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      color:
                                                          row['amount'] == 0
                                                              ? Colors.redAccent
                                                              : Colors
                                                                  .tealAccent,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.play_circle_fill,
                                                      color: Colors.tealAccent,
                                                    ),
                                                    onPressed: () {
                                                      if (row['audio_file'] !=
                                                              null &&
                                                          row['audio_file']
                                                              .toString()
                                                              .isNotEmpty) {
                                                        _showAudioPopup(
                                                          row['audio_file'],
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              "No audio file found",
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
