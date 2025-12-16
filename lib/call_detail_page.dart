import 'dart:convert';
import 'dart:io';
import 'package:becall2/api.dart';
import 'package:becall2/homepage.dart';
import 'package:http/http.dart' as https;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class CallDetailPage extends StatefulWidget {
  final Map<String, dynamic> call;

  const CallDetailPage({super.key, required this.call});

  @override
  State<CallDetailPage> createState() => _CallDetailPageState();
}

class _CallDetailPageState extends State<CallDetailPage> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController durationController;
  late TextEditingController phoneController;
  late TextEditingController invoiceController;
  late TextEditingController amountController;
  late TextEditingController descriptionController;
  late TextEditingController noteController;

  int? _customerId;
  List<dynamic> _customers = [];
  List<dynamic> _states = [];
  String? _selectedState;
  bool _loadingStates = false;
  bool _loading = true;

  File? _selectedAudioFile;
  bool _uploadingAudio = false;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _fetchStates();
    print("CALL DETAILS FROM PREVIOUS SCREEN: ${widget.call}");


    dynamic customerData = widget.call['Customer'];
    Map<String, dynamic>? customer;

    if (customerData is Map<String, dynamic>) {
      customer = customerData;
    }

    final fullName =
        customer != null
            ? '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'
                .trim()
            : widget.call['customer_name'] ?? '';

    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    firstNameController = TextEditingController(text: firstName);
    lastNameController = TextEditingController(text: lastName);
    durationController = TextEditingController(
      text: widget.call['duration'] ?? '',
    );
    phoneController = TextEditingController(text: widget.call['phone'] ?? '');
    invoiceController = TextEditingController(
      text: widget.call['invoice'] ?? '',
    );
    amountController = TextEditingController(
      text: widget.call['amount']?.toString() ?? '',
    );
    descriptionController = TextEditingController(
      text: widget.call['description'] ?? '',
    );
    noteController = TextEditingController(text: widget.call['note'] ?? '');

    phoneController.addListener(() {
      if (phoneController.text.trim().length >= 6) {
        _checkExistingCustomerByPhone();
      }
    });
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
  print("---- RUNNING _fetchCustomers ----");

  var token = await getToken();
  var id = await getid();

  print("Fetching customers from: $api/api/contact/info/staff/$id/");

  setState(() => _loading = true);

  try {
    var response = await https.get(
      Uri.parse("$api/api/contact/info/staff/$id/"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    print("Customer fetch response status: ${response.statusCode}");
    print("Customer fetch body: ${response.body}");

    if (response.statusCode == 200) {
      final List<dynamic> customerList = List<dynamic>.from(jsonDecode(response.body));
      print("Total customers fetched: ${customerList.length}");

      setState(() {
        _customers = customerList;
        _loading = false;
      });

      print("---- CALL DETAILS FROM PREVIOUS SCREEN ----");
      print(widget.call);

      print("Attempting to extract state from widget.call...");

      // PRIORITY 1: widget.call['state']  (Correct INT ID)
      if (widget.call['state'] != null) {
        _selectedState = widget.call['state'].toString();
        print("Using widget.call['state']: $_selectedState");
        return;
      }

      // PRIORITY 2: widget.call['state_id'] (String ID)
      if (widget.call['state_id'] != null) {
        _selectedState = widget.call['state_id'].toString();
        print("Using widget.call['state_id']: $_selectedState");
        return;
      }

      // PRIORITY 3: widget.call['state_name'] → map via _states
      if (widget.call['state_name'] != null) {
        final stateName = widget.call['state_name'].toString();
        print("widget.call['state_name'] detected: $stateName");
        
        final match = _states.firstWhere(
          (s) => s['name'].toString().toLowerCase() == stateName.toLowerCase(),
          orElse: () => {},
        );

        if (match.isNotEmpty) {
          _selectedState = match['id'].toString();
          print("Mapped state_name → state_id: $_selectedState");
          return;
        } else {
          print("No match found for widget.call['state_name'] in _states.");
        }
      }

      print("WARNING: No state found in widget.call.");
    } else {
      print("Customer fetch failed with status ${response.statusCode}");
      setState(() => _loading = false);
    }
  } catch (e) {
    print("ERROR in _fetchCustomers(): $e");
    setState(() {
      _customers = [];
      _loading = false;
    });
  }
}


 void _checkExistingCustomerByPhone() async {
  print("---- RUNNING _checkExistingCustomerByPhone ----");

  final inputPhone = phoneController.text.trim();
  print("Input phone: $inputPhone");

  if (inputPhone.isEmpty) {
    print("Input empty. Returning.");
    return;
  }

  String normalizedInput = inputPhone.replaceAll(RegExp(r'\s+'), '');
  normalizedInput = normalizedInput.replaceAll('+91', '');
  print("Normalized input: $normalizedInput");

  for (var customer in _customers) {
    print("Checking customer: $customer");

    String customerPhone = (customer['phone'] ?? '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('+91', '');

    print("Customer phone normalized: $customerPhone");

    if (customerPhone.endsWith(normalizedInput) ||
        normalizedInput.endsWith(customerPhone)) {

      print("---- CUSTOMER MATCH FOUND ----");
      print("Matched Customer: $customer");

      setState(() {
        firstNameController.text = customer['first_name'] ?? '';
        lastNameController.text = customer['last_name'] ?? '';
        _customerId = customer['id'];

        // Priority 1: customer.state (INT)
        if (customer['state'] != null) {
          _selectedState = customer['state'].toString();
          print("Using customer['state']: $_selectedState");
        }

        // Priority 2: customer.state_id (STRING)
        else if (customer['state_id'] != null) {
          _selectedState = customer['state_id'].toString();
          print("Using customer['state_id']: $_selectedState");
        }

        // Priority 3: customer.state_name → map to ID via _states
        else if (customer['state_name'] != null) {
          print("customer['state_name'] detected: ${customer['state_name']}");

          final match = _states.firstWhere(
            (s) =>
                s['name'].toString().toLowerCase() ==
                customer['state_name'].toString().toLowerCase(),
            orElse: () => {},
          );

          if (match.isNotEmpty) {
            _selectedState = match['id'].toString();
            print("Mapped state_name -> state ID: $_selectedState");
          } else {
            print("No match found for state_name in _states.");
          }
        }

        // If still null — no state available
        else {
          print("WARNING: Customer has no state, state_id, or state_name.");
        }
      });

      print("FINAL selectedState AFTER MATCH: $_selectedState");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Existing customer found: ${customer['first_name']}")),
      );
      return;
    }
  }

  print("No customer matched this phone.");
}

Future<void> saveContact() async {
  print("---- RUNNING saveContact ----");

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) return;

    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Phone number is required")),
      );
      return;
    }

    print("Phone entered: $phone");
    print("Current selectedState BEFORE fallback: $_selectedState");

    // Ensure selectedState from call if customer matching did not set it
    if (_selectedState == null || _selectedState == '0') {
      if (widget.call['state'] != null) {
        _selectedState = widget.call['state'].toString();
      } else if (widget.call['state_id'] != null) {
        _selectedState = widget.call['state_id'].toString();
      } else if (widget.call['state_name'] != null && _states.isNotEmpty) {
        final match = _states.firstWhere(
          (s) => s['name'].toString().toLowerCase() ==
              widget.call['state_name'].toString().toLowerCase(),
          orElse: () => {},
        );
        if (match.isNotEmpty) _selectedState = match['id'].toString();
      }
    }

    print("FINAL selectedState BEFORE API CALL: $_selectedState");

    // Search API
    final checkUrl = Uri.parse('$api/api/contact/info/?search=$phone');
    final checkResponse = await https.get(
      checkUrl,
      headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
    );

    print("Search response: ${checkResponse.statusCode}");
    print("Search body: ${checkResponse.body}");

    if (checkResponse.statusCode == 200) {
      final List<dynamic> existingContacts = json.decode(checkResponse.body);

      // FIX: Always match by EXACT PHONE
      final existing = existingContacts.firstWhere(
        (c) =>
            c['phone'] != null &&
            c['phone']
                    .toString()
                    .replaceAll('+91', '')
                    .replaceAll(' ', '') ==
                phone.replaceAll('+91', '').replaceAll(' ', ''),
        orElse: () => null,
      );

      print("Matching correct contact by phone:");
      print(existing);

      if (existing != null) {
        final existingId = existing['id'];
        _customerId = existingId;

        print("---- UPDATING CONTACT ${existing['id']} ----");

        // Ensure state from contact record
        if (_selectedState == null || _selectedState == '0') {
          if (existing['state'] != null) {
            _selectedState = existing['state'].toString();
          } else if (existing['state_id'] != null) {
            _selectedState = existing['state_id'].toString();
          }
        }

        print("FINAL STATE for update: $_selectedState");

        final updateBody = {
          "first_name": firstNameController.text.trim(),
          "last_name": lastNameController.text.trim(),
          "phone": phone,
          "state": int.tryParse(_selectedState ?? '0'),
        };

        print("UPDATE BODY SENT:");
        print(updateBody);

        final updateUrl = Uri.parse('$api/api/contact/info/$existingId/');
        final updateResponse = await https.put(
          updateUrl,
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
          body: jsonEncode(updateBody),
        );

        print("Update response: ${updateResponse.statusCode}");
        print(updateResponse.body);

        if (updateResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Existing contact updated")),
          );
        }

        return;
      }
    }

    // ---- CREATE NEW CONTACT ----
    print("---- CREATING NEW CONTACT ----");

    final createUrl = Uri.parse('$api/api/contact/info/');
    final createBody = {
      "first_name": firstNameController.text.trim(),
      "last_name": lastNameController.text.trim(),
      "phone": phone,
      "state": int.tryParse(_selectedState ?? '0'),
    };

    print("CREATE BODY SENT:");
    print(createBody);

    final createResponse = await https.post(
      createUrl,
      headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
      body: jsonEncode(createBody),
    );

    print("Create response: ${createResponse.statusCode}");
    print(createResponse.body);

    if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
      final data = json.decode(createResponse.body);
      _customerId = data['id'];
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ New contact created successfully")),
      );
    }
  } catch (e) {
    print("ERROR IN saveContact: $e");
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Error saving contact: $e")));
  }
}

  Future<void> _fetchStates() async {
    setState(() => _loadingStates = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await https.get(
        Uri.parse('$api/api/states/'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("States fetch response: ${response.statusCode}");
      print("States response body: ${response.body}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> stateList = data['data'] ?? [];

        setState(() {
          _states = stateList;
          final existingName = widget.call['state_name'];
          if (existingName != null) {
            final match = _states.firstWhere(
              (s) =>
                  s['name'].toString().toLowerCase() ==
                  existingName.toString().toLowerCase(),
              orElse: () => {},
            );
            if (match.isNotEmpty) {
              _selectedState = match['id'].toString();
            }
          }
          _loadingStates = false;
        });

        print("Fetched ${_states.length} states");
        print("Selected State ID: $_selectedState");
      } else {
        setState(() => _loadingStates = false);
      }
    } catch (e) {
      setState(() => _loadingStates = false);
    }
  }

  Future<void> updateCallDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    final callId = widget.call['id'];

    if (token == null || callId == null) return;

    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    var request = https.MultipartRequest(
      'PUT',
      Uri.parse("$api/api/call/report/$callId/"),
    );
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['first_name'] = firstNameController.text;
    request.fields['last_name'] = lastNameController.text;
    request.fields['duration'] = durationController.text;
    request.fields['phone'] = phoneController.text;
    request.fields['invoice'] = invoiceController.text;
    request.fields['amount'] = amountController.text;
    request.fields['description'] = descriptionController.text;
    request.fields['note'] = noteController.text;
    request.fields['date'] = formattedDate;

    if (_customerId != null)
      request.fields['Customer'] = _customerId.toString();
    if (invoiceController.text.trim().isNotEmpty)
      request.fields['status'] = 'Productive';

    if (_selectedAudioFile != null) {
      request.files.add(
        await https.MultipartFile.fromPath(
          'audio_file',
          _selectedAudioFile!.path,
        ),
      );
    }
    try {
      var streamedResponse = await request.send();
      final response = await https.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Call updated successfully")));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const Homepage(initialIndex: 3),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Call Details',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Edit Call Information",
                style: TextStyle(
                  color: Color.fromARGB(255, 26, 164, 143),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildEditableRow("First Name", firstNameController),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildEditableRow("Last Name", lastNameController),
                  ),
                ],
              ),
              _buildEditableRow("Duration", durationController, readOnly: true),
              _buildEditableRow("Phone Number", phoneController),
              _buildEditableRow("Invoice Number", invoiceController),
              _buildEditableRow("Amount", amountController),
              _buildEditableRow("Description", descriptionController),
              _buildEditableRow("Note", noteController),

              const SizedBox(height: 10),
              // const Text("State",
              //     style: TextStyle(color: Colors.white70, fontSize: 14)),
              // const SizedBox(height: 4),
              // _loadingStates
              //     ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              //     : DropdownButtonFormField<String>(
              //         dropdownColor: const Color(0xFF2A2A2A),
              //         value: _selectedState,
              //         hint: const Text("Select State",
              //             style: TextStyle(color: Colors.white70)),
              //         items: _states
              //             .map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
              //                 value: s['id'].toString(),
              //                 child: Text(s['name'],
              //                     style: const TextStyle(color: Colors.white))))
              //             .toList(),
              //         onChanged: (v) => setState(() => _selectedState = v),
              //         decoration: InputDecoration(
              //           filled: true,
              //           fillColor: Colors.black26,
              //           border: OutlineInputBorder(
              //               borderRadius: BorderRadius.circular(8),
              //               borderSide: const BorderSide(color: Colors.white24)),
              //         )),

              // const SizedBox(height: 20),
              const Text(
                "Upload Call Recording",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedAudioFile != null
                          ? _selectedAudioFile!.path.split('/').last
                          : "No file selected",
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform
                          .pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['mp3', 'm4a', 'wav'],
                          );
                      if (result != null && result.files.single.path != null) {
                        setState(() {
                          _selectedAudioFile = File(result.files.single.path!);
                        });
                      }
                    },
                    icon: const Icon(Icons.audiotrack, color: Colors.white),
                    label: const Text(
                      "Select Audio",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(140, 45),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await saveContact();
                    await updateCallDetails();
                  },
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text(
                    "Update Call",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 26, 164, 143),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  Widget _buildEditableRow(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
