import 'dart:convert';

import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as https;
import 'package:shared_preferences/shared_preferences.dart';

class AddContryFormPage extends StatefulWidget {
  const AddContryFormPage({super.key});

  @override
  State<AddContryFormPage> createState() => _AddContryFormPageState();
}

class _AddContryFormPageState extends State<AddContryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _NameCtrl = TextEditingController();
  final TextEditingController _codeCtrl  = TextEditingController();
  

  final Color accent = const Color.fromARGB(255, 26, 164, 143);
Future <String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

@override
void initState() {
  super.initState();
  _fetchCountries();
}

  List<dynamic> _countries = [];
bool _loading = true;

Future<void> _fetchCountries() async {
  var token = await getToken();
  setState(() => _loading = true);
  try {
    var response = await https.get(
      Uri.parse("$api/api/country/codes/"),
      headers: {"Authorization": "Bearer $token","Content-Type": "application/json",},
    );



    if (response.statusCode == 200) {
      var decoded = jsonDecode(response.body);

      // ✅ Extract the list under "data"
      setState(() {
        _countries = List<dynamic>.from(decoded['data']);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  } catch (e) {
    setState(() => _loading = false);
  }
}



  Future<void> _saveCountry() async {
    var token = await getToken();
    try{
      var response= await https.post(Uri.parse("$api/api/country/codes/"),
      headers: {
         
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      body:{
        // "name":_NameCtrl.text,
        // "code":_codeCtrl.text
                    'country_code': _NameCtrl.text,

      }
      );
 
      if(response.statusCode==201 || response.statusCode==200){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Country saved successfully!'), backgroundColor: accent),
        );
        _formKey.currentState?.reset();
        _NameCtrl.clear();
        _codeCtrl.clear();
          _fetchCountries(); // refresh list
      }
      else{
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save. Code: ${response.statusCode}"), backgroundColor: Colors.red),
        );
      }



    }
    catch(e){
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
          borderSide: BorderSide(color: Colors.white, width: 1.5),
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
        title: const Text('Add New Contry'),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _NameCtrl,
                decoration: _inputDecoration('Contry'),
                validator: (v) => v!.isEmpty ? 'Enter country name' : null,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              //  TextFormField(
              //   controller: _codeCtrl,
              //   decoration: _inputDecoration('country code'),
              //   validator: (v) => v!.isEmpty ? 'Enter country code' : null,
              //   style: const TextStyle(color: Colors.white),
              // ),
              // const SizedBox(height: 16),
           
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
                onPressed: _saveCountry,
                child: const Text(
                  'Save Contact',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),
Text(
  "Countries:",
  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
),
const SizedBox(height: 8),

_loading
    ? const Center(child: CircularProgressIndicator())
    : _countries.isEmpty
        ? const Text("No countries found", style: TextStyle(color: Colors.white))
        : Column(
            children: _countries.map((c) {
              return Card(
                color: Colors.grey[900],
                child: ListTile(
  title: Text(c['country_code'] ?? '', style: const TextStyle(color: Colors.white)),
 
)

              );
            }).toList(),
          ),

            ],
          ),
        ),
      ),
    );
  }
}
