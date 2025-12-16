import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as https;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProductWiseManualReport extends StatefulWidget {
  const ProductWiseManualReport({super.key});

  @override
  State<ProductWiseManualReport> createState() =>
      _ProductWiseManualReportState();
}

class _ProductWiseManualReportState extends State<ProductWiseManualReport> {
  List<Map<String, dynamic>> categoryList = [];
  List<Map<String, dynamic>> customer = [];
  String searchQuery = '';
  List<Map<String, dynamic>> productRows = [
    {"category": null, "qty": ""},
  ];
  DateTime? selectedDate;

  String? selectedCustomer;
  String? selectedCategory;
  String billsCount = "";


  final TextEditingController qtyCtrl = TextEditingController();

  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  @override
  void initState() {
    super.initState();
    getcustomer();
    getProductCategories();
  }

  void addProductRow() {
    setState(() {
      productRows.add({"category": null, "qty": ""});
    });
  }

  void removeProductRow(int index) {
    setState(() {
      productRows.removeAt(index);
    });
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1AA48F),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> getProductCategories() async {
    try {
      final token = await getTokenFromPrefs();
      if (token == null) return;

      final response = await https.get(
        Uri.parse('$api/api/product/category/add/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        List<Map<String, dynamic>> tempList = [];

        for (var item in parsed) {
          tempList.add({'id': item['id'], 'name': item['category_name']});
        }

        setState(() {
          categoryList = tempList;
        });
      }
    } catch (error) {}
  }

  Future<void> getcustomer() async {
    try {
      final token = await getTokenFromPrefs();
      var response = await https.get(
        Uri.parse('$api/api/staff/customers/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        var productsData = parsed['data'];
        List<Map<String, dynamic>> managerlist = [];

        for (var productData in productsData) {
          managerlist.add({
            'id': productData['id'],
            'name': productData['name'],
            'created_at': productData['created_at'],
          });
        }

        setState(() {
          customer = managerlist;
        });
      }
    } catch (error) {
    }
  }

  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> submitReport() async {
  try {
    final token = await getTokenFromPrefs();
    if (token == null || selectedCustomer == null) return;

    List<Map<String, dynamic>> products =
        productRows
            .where((row) => row['category'] != null && row['qty']!.isNotEmpty)
            .map(
              (row) => {
                'category': row['category'],
                'quantity': int.parse(row['qty']),
              },
            )
            .toList();


    final body = jsonEncode({
      'customer': selectedCustomer,
      'items': products,
      'date': formatDate(DateTime.now()), // ✅ Always send today's date
    });

    final response = await https.post(
      Uri.parse('$api/api/staff/custom/order/update/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

   

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text('Product added successfully.'),
        ),
      );
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text('Product added successfully.'),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProductWiseManualReport()),
      );
    } else {
      // Handle error
    }
  } }catch (error) {
  }
}


  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1AA48F);

    // Filter customer list
    List<Map<String, dynamic>> filteredCustomers =
        customer
            .where(
              (c) => c['name'].toString().toLowerCase().contains(
                searchQuery.toLowerCase(),
              ),
            )
            .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Product Manual Report",
          style: TextStyle(fontSize: 16,color: Colors.white),
        ),
        backgroundColor: green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SMALL LABEL
              Text(
                "Search Customer",
                style: TextStyle(color: green, fontSize: 13),
              ),
              const SizedBox(height: 4),

              // SMALL SEARCH TEXTFIELD
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Search...",
                  hintStyle: TextStyle(color: Colors.white60, fontSize: 12),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.teal,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: Colors.black,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: green, width: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: green, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onChanged: (value) {
                  setState(() => searchQuery = value);
                },
              ),

              const SizedBox(height: 10),

              // SMALL CUSTOMER LIST BOX
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: green, width: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[900],
                ),
                child:
                    filteredCustomers.isEmpty
                        ? const Center(
                          child: Text(
                            "No customers",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        )
                        : ListView.builder(
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final cust = filteredCustomers[index];

                            final isSelected =
                                selectedCustomer == cust['id'].toString();

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedCustomer = cust['id'].toString();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 10,
                                ),

                                color:
                                    isSelected
                                        ? green.withOpacity(0.15)
                                        : Colors.transparent,

                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      cust['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),

              const SizedBox(height: 20),

              // MULTIPLE CATEGORY ROWS (COMPACT)
              Column(
                children: List.generate(productRows.length, (index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      border: Border.all(color: green, width: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Category",
                          style: TextStyle(color: green, fontSize: 13),
                        ),
                        const SizedBox(height: 4),

                        // SMALL DROPDOWN
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: green, width: 0.7),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              dropdownColor: Colors.black,
                              value: productRows[index]["category"],
                              hint: const Text(
                                "Select",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                                size: 18,
                              ),
                              items:
                                  categoryList.map((e) {
                                    return DropdownMenuItem<int>(
                                      value: e['id'], // ✅ SEND ID
                                      child: Text(
                                        e['name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  productRows[index]["category"] =
                                      value; // store ID
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          "Qty",
                          style: TextStyle(color: green, fontSize: 13),
                        ),
                        const SizedBox(height: 4),

                        // SMALL TEXTFIELD
                        TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black,
                            hintText: "0",
                            hintStyle: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onChanged: (value) {
                            productRows[index]["qty"] = value;
                          },
                        ),

                        // SMALL DELETE BUTTON
                        if (index != 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => removeProductRow(index),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
              // DATE PICKER
              // Column(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   children: [
              //     Text(
              //       "Select Date",
              //       style: TextStyle(color: green, fontSize: 13),
              //     ),
              //     const SizedBox(height: 4),
              //     InkWell(
              //       onTap: pickDate,
              //       child: Container(
              //         padding: const EdgeInsets.symmetric(
              //           vertical: 10,
              //           horizontal: 12,
              //         ),
              //         decoration: BoxDecoration(
              //           color: Colors.black,
              //           border: Border.all(color: green, width: 0.7),
              //           borderRadius: BorderRadius.circular(8),
              //         ),
              //         child: Row(
              //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //           children: [
              //             Text(
              //               selectedDate == null
              //                   ? "Select date"
              //                   : "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}",
              //               style: const TextStyle(
              //                 color: Colors.white,
              //                 fontSize: 13,
              //               ),
              //             ),
              //             const Icon(
              //               Icons.calendar_today,
              //               color: Colors.white,
              //               size: 16,
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
              // const SizedBox(height: 15),

              // SMALL ADD BUTTON
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  minimumSize: const Size(double.infinity, 40),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  "Add Product",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                onPressed: addProductRow,
              ),

              const SizedBox(height: 10),

              // SMALL SUBMIT
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  minimumSize: const Size(double.infinity, 40),
                ),
                onPressed: () {
                 
                  submitReport();
                },
                child: const Text(
                  "Submit",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
