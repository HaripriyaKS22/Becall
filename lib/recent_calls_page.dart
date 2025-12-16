import 'dart:convert';

import 'package:becall2/add_contact.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import 'customer_details_view.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:becall2/api.dart';


class RecentCallsPage extends StatefulWidget {
  const RecentCallsPage({super.key});

  @override
  State<RecentCallsPage> createState() => _RecentCallsPageState();
}

class _RecentCallsPageState extends State<RecentCallsPage> {
  List<_GroupedCall> _allCalls = [];
  List<_GroupedCall> _filteredCalls = [];
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _submittedCalls = {};
String? _selectedCustomer;
String phoneNumber = '';
final TextEditingController _durationCtrl = TextEditingController();
File? _selectedImage;
bool _pageLoading = true;

 @override
void initState() {
  super.initState();
  _initializePage();
  _searchCtrl.addListener(_onSearch);
}
Future<void> _initializePage() async {
  setState(() => _pageLoading = true);

 await _loadCalls();
  await fetchCallReportsData();
  await _fetchCustomers();

  setState(() => _pageLoading = false);
}


  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
Future<void> _pickImage() async {
  final ImagePicker picker = ImagePicker();
  final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked != null) {
    setState(() {
      _selectedImage = File(picked.path);
    });
  }
}
void _openAddCallDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        contentPadding: EdgeInsets.zero, // Important for full-width border

        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(20),

              // BORDER ADDED HERE
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Color.fromARGB(255, 95, 94, 94),
                  width: 2,
                ),
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Title
                  const Text(
                    "Add Call Details",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),),

                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 26, 164, 143),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Customer Dropdown
                 SizedBox(
  width: double.infinity,
  child: DropdownButtonFormField<String>(
    dropdownColor: Colors.grey[900],
    decoration: InputDecoration(
      labelText: "Select Customer",
      labelStyle: TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Color.fromARGB(255, 26, 164, 143)),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    style: TextStyle(color: Colors.white),
    items: _customers.map((c) {
      return DropdownMenuItem<String>(
        value: c['id'].toString(),
        child: Text(
          c['first_name'] ?? "Unknown",
          style: TextStyle(color: Colors.white),
        ),
      );
    }).toList(),
    value: _selectedCustomer,
    onChanged: (val) {
      setStateDialog(() {
        _selectedCustomer = val;
        final data =
            _customers.firstWhere((c) => c['id'].toString() == val);
        phoneNumber = data['phone'] ?? '';
      });
    },
  ),
)
,
                  const SizedBox(height: 16),

                  // Duration TextField
                  TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Duration (in seconds)",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Color.fromARGB(255, 26, 164, 143),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Image Picker Row
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? picked =
                              await picker.pickImage(source: ImageSource.gallery);

                          if (picked != null) {
                            setStateDialog(() {
                              _selectedImage = File(picked.path);
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Color.fromARGB(255, 26, 164, 143),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.image),
                        label: const Text("Select Image"),
                      ),

                      const SizedBox(width: 12),

                      _selectedImage != null
                          ? Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Color.fromARGB(255, 26, 164, 143),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : const Text(
                              "No image",
                              style: TextStyle(color: Colors.white70),
                            ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.white70),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),

                      const SizedBox(width: 10),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Color.fromARGB(255, 26, 164, 143),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Submit"),
                        onPressed: () async {
                          if (_selectedCustomer == null ||
                              _durationCtrl.text.trim().isEmpty || _selectedImage== null) {
                            // Show error
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Please select a customer and enter duration and image"),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          await sendCallReport(
                            customerName: _selectedCustomer ?? "Unknown",
                            duration: _durationCtrl.text,
                            phone: phoneNumber,
                            callDateTime: DateTime.now(),
                            customerId: _selectedCustomer != null
                                ? int.tryParse(_selectedCustomer!)
                                : null,
                          );

                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

  Future<int?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var idValue = prefs.get('id');
    if (idValue is int) return idValue;
    if (idValue is String) return int.tryParse(idValue);
    return null;
  }

  Future<int?> getid() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('id');
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isKnownCustomer(String phone) {
    return _phoneToCustomerId.containsKey(_normalize(phone));
  }

  List<dynamic> _customers = [];
  bool _loading = true;

  Future<void> _fetchCustomers() async {
    final token = await getToken();
    final id = await getid();

    setState(() => _loading = true);

    try {
      final response = await http.get(
        Uri.parse("$api/api/contact/info/staff/$id/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = List<dynamic>.from(jsonDecode(response.body));

        _phoneToCustomerId.clear();
        for (final c in items) {
          final dynamic rawId = c['id'] ?? c['customer_id'];
          if (rawId == null) continue;

          final int? cid = rawId is int ? rawId : int.tryParse('$rawId');
          if (cid == null) continue;

          for (final p in _extractPhones(c)) {
            final norm = _normalize(p);
            if (norm.isNotEmpty) _phoneToCustomerId.putIfAbsent(norm, () => cid);
          }
        }

        setState(() {
          _customers = items;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<List<dynamic>> fetchCallReportsData() async {
    final token = await getToken();
    final userId = await getUserId();

    if (token == null || userId == null) return [];

    final url = Uri.parse("$api/api/call/report/staff/$userId/");

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        _submittedCalls.clear();
        for (final item in data) {
          final phone = item['phone'];
          final dtString = item['call_datetime'];

          if (phone is String && dtString is String) {
            final dt = DateTime.tryParse(dtString);
            if (dt != null) {
              final key = "${_normalize(phone)}_${dt.millisecondsSinceEpoch}";
              _submittedCalls.add(key);
            }
          }
        }
        setState(() {});
        return data;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

 Future<void> sendCallReport({
  required String customerName,
  required String duration,
  required String phone,
  required DateTime callDateTime,
  int? customerId,
}) async {
  final token = await getToken();
  if (token == null) return;

  final url = Uri.parse("$api/api/call/report/");
  final request = http.MultipartRequest("POST", url);

  request.headers["Authorization"] = "Bearer $token";

  request.fields["customer_name"] = customerName;
  request.fields["duration"] = duration;
  request.fields["status"] = "Active";
  request.fields["phone"] = phone;
  request.fields["call_datetime"] = callDateTime.toIso8601String();

  if (customerId != null) request.fields["Customer"] = customerId.toString();

  // Attach image file
  if (_selectedImage != null) {
    request.files.add(
      await http.MultipartFile.fromPath("images", _selectedImage!.path),
    );
  }

  try {
    final res = await request.send();
    final resBody = await res.stream.bytesToString();

    if (res.statusCode == 201) {
      customerName="";
      duration="";
      phone="";
      _durationCtrl.clear();
      _selectedCustomer=null;

      _selectedImage=null;

      
    } else {
    }
  } catch (e) {
  }
}


  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredCalls = q.isEmpty
          ? _allCalls
          : _allCalls
              .where((c) =>
                  (c.name ?? '').toLowerCase().contains(q) ||
                  c.number.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _loadCalls() async {
    if (await Permission.phone.request().isGranted &&
        await Permission.contacts.request().isGranted) {
      final entries = await CallLog.get();

      if (entries.isEmpty) return;

      final list = entries
          .map(
            (e) => _GroupedCall(
              number: e.number ?? '',
              name: e.name ?? e.number ?? 'Unknown',
              date: DateTime.fromMillisecondsSinceEpoch(e.timestamp ?? 0),
              lastTime: DateTime.fromMillisecondsSinceEpoch(e.timestamp ?? 0),
              callType: e.callType ?? CallType.incoming,
              duration: e.duration ?? 0,
            ),
          )
          .toList();

      setState(() {
        _allCalls = list;
        _filteredCalls = list;
      });
    }
  }

  final Map<String, int> _phoneToCustomerId = {};

  String _normalize(String n) {
    final digits = n.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  List<String> _extractPhones(dynamic c) {
    final phones = <String>[];

    for (final k in ['phone', 'phone_number', 'mobile', 'mobile1', 'mobile2']) {
      final v = c[k];
      if (v is String && v.trim().isNotEmpty) phones.add(v.trim());
    }

    final arr = c['phones'];
    if (arr is List) {
      for (final p in arr) {
        if (p is String && p.trim().isNotEmpty) phones.add(p.trim());
      }
    }

    return phones.toSet().toList();
  }

  String _dateLabel(DateTime d) {
    final today = DateTime.now();
    final yest = today.subtract(const Duration(days: 1));

    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Today';
    } else if (d.year == yest.year &&
        d.month == yest.month &&
        d.day == yest.day) {
      return 'Yesterday';
    }
    return DateFormat('dd MMM yyyy').format(d);
  }

  String _timeLabel(DateTime dt) =>
      DateFormat('h:mm a').format(dt);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
  backgroundColor: Colors.black,
  title: const Text(
    'Recents',
    style: TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.add, color: Colors.white),
      onPressed: _openAddCallDialog,
    ),
  ],
),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                hintText: 'Search',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadCalls();
                await fetchCallReportsData();
              },
              color: Colors.orange,
              backgroundColor: Colors.black,
              child: _submittedCalls.isEmpty
                  ? Expanded(
  child: _pageLoading
      ? ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 10,
          itemBuilder: (_, __) => _callSkeletonTile(),
        )
      : RefreshIndicator(
          onRefresh: () async {
            await _initializePage();
          },
          color: Colors.orange,
          backgroundColor: Colors.black,
          child: _filteredCalls.isEmpty
              ? const Center(
                  child: Text(
                    "No calls found",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _filteredCalls.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey[800], height: 1),
                  itemBuilder: _buildCallItem,
                ),
        ),
)

                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredCalls.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: Colors.grey[800], height: 1),
                      itemBuilder: (context, i) {
                        final c = _filteredCalls[i];

                        final callKey =
                            "${_normalize(c.number)}_${c.lastTime.millisecondsSinceEpoch}";
                        //final isSubmitted = _submittedCalls.contains(callKey);
                        final isKnown = _isKnownCustomer(c.number);

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (c.name != null &&
                                          c.name!.trim().isNotEmpty)
                                      ? c.name!
                                      : c.number,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _callTypeIcon(c.callType),
                            ],
                          ),
                          subtitle: const Text(
                            'Phone',
                            style: TextStyle(color: Colors.white54),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _dateLabel(c.date),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _timeLabel(c.lastTime),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),

                              if (_isToday(c.date))
  isKnown
      ? IconButton(
          icon: Icon(
            _isActuallySubmitted(c)
                ? Icons.check_circle
                : Icons.add_circle_outline,
            color: _isActuallySubmitted(c)
                ? Colors.grey
                : Colors.tealAccent,
            size: 24,
          ),
          tooltip: _isActuallySubmitted(c)
              ? "Submitted"
              : "Add Call Report",
          onPressed: _isActuallySubmitted(c)
              ? null
              : () async {
                  final normPhone = _normalize(c.number);
                  final customerId =
                      _phoneToCustomerId[normPhone];
                  final customerName =
                      c.name ?? c.number;

                  await sendCallReport(
                    customerName: customerName,
                    duration: "${c.duration} sec",
                    phone: c.number,
                    callDateTime: c.lastTime,
                    customerId: customerId,
                  );

                  setState(() {
                    final key =
                        "${_normalize(c.number)}_${c.lastTime.millisecondsSinceEpoch}";
                    _submittedCalls.add(key);
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("Call report added successfully"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
        )
      : TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.yellowAccent,
          ),
          child: const Text("Add"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddContactFormPage(
                  phoneNumber: c.number,
                ),
              ),
            );
          },
        ),

                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailsView(
                                id: 0,
                                customerName: c.name ?? c.number,
                                phoneNumber: c.number,
                                date: c.lastTime,
                                stateName: null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isActuallySubmitted(_GroupedCall c) {
  final callKey =
      "${_normalize(c.number)}_${c.lastTime.millisecondsSinceEpoch}";
  return _submittedCalls.contains(callKey);
}
bool _shouldShowAsSubmitted(_GroupedCall c) {
  if (!_isToday(c.date)) return false;

  final callKey =
      "${_normalize(c.number)}_${c.lastTime.millisecondsSinceEpoch}";

  // If API says it's submitted → true
  if (_submittedCalls.contains(callKey)) return true;

  // Otherwise, TODAY calls default to submitted (check icon)
  return true;
}
Widget _callSkeletonTile() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 18,
          width: 18,
          decoration: BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  );
}

Widget _buildCallItem(BuildContext context, int i) {
  final c = _filteredCalls[i];
  final isKnown = _isKnownCustomer(c.number);

  return ListTile(
    leading: const CircleAvatar(
      backgroundColor: Colors.white10,
      child: Icon(Icons.person, color: Colors.white),
    ),
    title: Row(
      children: [
        Expanded(
          child: Text(
            (c.name != null && c.name!.trim().isNotEmpty)
                ? c.name!
                : c.number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _callTypeIcon(c.callType),
      ],
    ),
    subtitle: const Text(
      'Phone',
      style: TextStyle(color: Colors.white54),
    ),
    trailing: _buildTrailingIcon(c, isKnown),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailsView(
          id: 0,
          customerName: c.name ?? c.number,
          phoneNumber: c.number,
          date: c.lastTime,
          stateName: null,
        ),
      ),
    ),
  );
}
Widget _buildTrailingIcon(_GroupedCall c, bool isKnown) {
  if (!_isToday(c.date)) {
    return const SizedBox.shrink();
  }

  if (!isKnown) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.yellowAccent,
      ),
      child: const Text("Add"),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddContactFormPage(
              phoneNumber: c.number,
            ),
          ),
        );
      },
    );
  }

  final isSubmitted = _isActuallySubmitted(c);

  return IconButton(
    icon: Icon(
      isSubmitted ? Icons.check_circle : Icons.add_circle_outline,
      color: isSubmitted ? Colors.grey : Colors.tealAccent,
      size: 24,
    ),
    tooltip: isSubmitted ? "Submitted" : "Add Call Report",
    onPressed: isSubmitted
        ? null
        : () async {
            final normPhone = _normalize(c.number);
            final customerId = _phoneToCustomerId[normPhone];
            final customerName = c.name ?? c.number;

            await sendCallReport(
              customerName: customerName,
              duration: "${c.duration} sec",
              phone: c.number,
              callDateTime: c.lastTime,
              customerId: customerId,
            );

            setState(() {
              final key =
                  "${_normalize(c.number)}_${c.lastTime.millisecondsSinceEpoch}";
              _submittedCalls.add(key);
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Call report added successfully"),
                duration: Duration(seconds: 2),
              ),
            );
          },
  );
}


}

class _GroupedCall {
  final String number;
  String? name;
  final DateTime date;
  DateTime lastTime;
  CallType callType;
  int duration;

  _GroupedCall({
    required this.number,
    required this.name,
    required this.date,
    required this.lastTime,
    required this.callType,
    required this.duration,
  });
}

Icon _callTypeIcon(CallType type) {
  const double iconSize = 13;

  switch (type) {
    case CallType.outgoing:
      return const Icon(Icons.call_made, color: Colors.green, size: iconSize);
    case CallType.incoming:
      return const Icon(Icons.call_received, color: Colors.blue, size: iconSize);
    case CallType.missed:
      return const Icon(Icons.call_missed, color: Colors.red, size: iconSize);
    default:
      return const Icon(Icons.call, color: Colors.grey, size: iconSize);
  }
}