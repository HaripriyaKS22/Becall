import 'dart:convert';
import 'dart:io';

import 'package:becall2/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as https;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ProductReportView extends StatefulWidget {
  const ProductReportView({super.key});

  @override
  State<ProductReportView> createState() => _ProductReportViewState();
}

class _ProductReportViewState extends State<ProductReportView> {
  List<Map<String, dynamic>> categoryList = [];
  List<Map<String, dynamic>> report = [];

  List<dynamic> staffList = [];
  List<dynamic> filteredStaffList = [];
  String? selectedStaff;

  List<Map<String, dynamic>> customer = [];
  DateTime? startDate;
  DateTime? endDate;

  TextEditingController staffSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    getproductreport();
    getstaff();
    getProductCategories();
  }

  Future<String?> getTokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> getcustomer(var id) async {
    try {
      final token = await getTokenFromPrefs();
      var response = await https.get(
        Uri.parse('$api/api/customers/manager/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

     

      if (response.statusCode == 200) {
        final List<dynamic> parsed = jsonDecode(response.body);

        List<Map<String, dynamic>> managerlist = [];

        for (var productData in parsed) {
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
    } catch (error) {
    }
  }

  Future<void> getproductreport() async {
    try {
      final token = await getTokenFromPrefs();
      if (token == null) return;

      final response = await https.get(
        Uri.parse('$api/api/staff/custom/order/update/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        setState(() {
          report = List<Map<String, dynamic>>.from(parsed["data"]);
        });
      }
    } catch (e) {
    }
  }

  // Class-level styles (can be reused if needed)
  CellStyle yellowStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#FFFF00", // YELLOW
    horizontalAlign: HorizontalAlign.Center,
  );

  Future<void> getstaff() async {
    try {
      final token = await getTokenFromPrefs();

      var response = await https.get(
        Uri.parse('$api/api/staffs/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

    

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        staffList = parsed['data'];
        filteredStaffList = List.from(staffList);

        setState(() {});
      }
    } catch (error) {
    }
  }

 void filterStaff(String query) {
  setState(() {
    filteredStaffList = staffList
        .where((s) => s['name']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();

    // Reset selectedStaff if not in filtered list
    if (selectedStaff != null &&
        !filteredStaffList
            .any((s) => s['id'].toString() == selectedStaff)) {
      selectedStaff = null;
    }
  });
}

  CellStyle greenTotalStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#00FF00", // GREEN
    horizontalAlign: HorizontalAlign.Center,
  );

  // ==========================================================
  //            STATE PRODUCT EXCEL GENERATION
  // ==========================================================
Future<void> generateStateProductExcel() async {
  if (selectedStaff == null || startDate == null || endDate == null) return;

  var staff = staffList.firstWhere((s) => s['id'].toString() == selectedStaff);
  List<dynamic> allocatedStates = staff['allocated_states_names'];

  List<String> categories =
      categoryList.map((e) => e['name'].toString()).toList();

  var excel = Excel.createExcel();
  Sheet sheetObject = excel['State_Product_Report'];

  // ---------- STYLES ----------
  CellStyle titleStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#FF0000",
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    fontSize: 14,
  );

  CellStyle headerStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#ADD8E6",
    horizontalAlign: HorizontalAlign.Center,
  );

  CellStyle redBodyStyle = CellStyle(
    bold: false,
    fontColorHex: "#000000",
    backgroundColorHex: "#FF0000",
    horizontalAlign: HorizontalAlign.Center,
  );

  CellStyle yellowStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#FFFF00",
    horizontalAlign: HorizontalAlign.Center,
  );

  CellStyle greenTotalStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#00FF00",
    horizontalAlign: HorizontalAlign.Center,
  );

  CellStyle orangeStyle = CellStyle(
  bold: true,
  fontColorHex: "#000000",
  backgroundColorHex: "#FFA500", // ORANGE
  horizontalAlign: HorizontalAlign.Center,
);

CellStyle redStyle = CellStyle(
  bold: true,
  fontColorHex: "#FFFFFF",
  backgroundColorHex: "#FF0000", // RED
  horizontalAlign: HorizontalAlign.Center,
);


  int totalColumns = categories.length + 3;

  // ---------- TITLE ----------
  sheetObject.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    CellIndex.indexByColumnRow(columnIndex: totalColumns - 1, rowIndex: 0),
  );

  var titleCell =
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));

  titleCell.value =
      "State Product Report - ${staff['name']} (${startDate!.toString().substring(0, 10)} to ${endDate!.toString().substring(0, 10)})";
  titleCell.cellStyle = titleStyle;

  // ---------- HEADER ROW ----------
  int headerRow = 2;

  List<String> headerTitles = ["STATE", "TOTAL"];
  headerTitles.addAll(categories);

  for (int i = 0; i < headerTitles.length; i++) {
    var cell = sheetObject.cell(
      CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow),
    );
    cell.value = headerTitles[i];
    cell.cellStyle = headerStyle;
  }

  // ---------- BUILD TOTALS ----------
  Map<String, Map<int, num>> stateCategoryTotals = {};
  Map<int, num> categoryTotals = {};
  Map<String, num> stateBillTotals = {};

  for (var entry in report) {
    bool staffMatch = entry["staff"].toString() == selectedStaff;

    DateTime? entryDate = DateTime.tryParse(entry["date"] ?? "");
    if (entryDate == null) continue;

    bool dateMatch =
        entryDate.isAfter(startDate!.subtract(const Duration(days: 1))) &&
            entryDate.isBefore(endDate!.add(const Duration(days: 1)));

    if (!staffMatch || !dateMatch) continue;

    String state = entry["customer_state"] ?? "Unknown";

    stateCategoryTotals.putIfAbsent(state, () => {});
    stateBillTotals.putIfAbsent(state, () => 0);

    // Bill count
    num bills = num.tryParse(entry["note"] ?? "0") ?? 0;
    stateBillTotals[state] = (stateBillTotals[state] ?? 0) + bills;

    // Category qty
    if (entry["items"] != null) {
      for (var item in entry["items"]) {
        int categoryId = item["category"];
        num qty = item["quantity"];

        stateCategoryTotals[state]!.update(categoryId, (v) => v + qty,
            ifAbsent: () => qty);

        categoryTotals.update(categoryId, (v) => v + qty,
            ifAbsent: () => qty);
      }
    }
  }

  // ---------- COMPILE FINAL STATE LIST ----------
  List<String> excelStateList =
      allocatedStates.map((e) => e.toString()).toList();

  Set<String> reportStates = stateCategoryTotals.keys.toSet();
  for (var s in reportStates) {
    if (!excelStateList.contains(s)) {
      excelStateList.add(s);
    }
  }

  // ---------- WRITE STATE ROWS ----------
  int rowIndex = headerRow + 1;

  for (String state in excelStateList) {
    // STATE
    sheetObject
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
      ..value = state;

//     // TOTAL BILLS
//     num bills = stateBillTotals[state] ?? 0;
//   var billCell = sheetObject.cell(
//   CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
// );
// billCell.value = bills;

// // ORANGE if >0, RED if 0
// if (bills > 0) {
//   billCell.cellStyle = orangeStyle;
// } else {
//   billCell.cellStyle = redStyle;
// }

    // TOTAL QTY
    num totalQty = 0;

    for (int c = 0; c < categories.length; c++) {
      int categoryId = categoryList[c]['id'];
      num qty =
          stateCategoryTotals[state]?[categoryId] == null ? 0 : stateCategoryTotals[state]![categoryId]!;

      totalQty += qty;

      var cell = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: c + 2, rowIndex: rowIndex),
      );
      cell.value = qty;

      cell.cellStyle = qty > 0 ? yellowStyle : redBodyStyle;
    }

    // TOTAL COLUMN
    var totalCell = sheetObject.cell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
    );
    totalCell.value = totalQty;
    totalCell.cellStyle = totalQty > 0 ? greenTotalStyle : redBodyStyle;

    rowIndex++;
  }

  // ---------- GRAND TOTAL ----------
  rowIndex++;
  var grandCell =
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
  grandCell.value = "GRAND TOTAL";
  grandCell.cellStyle = yellowStyle;

//   num totalBillsGrand =
//       stateBillTotals.values.fold(0, (sum, value) => sum + value);

//   // GRAND TOTAL BILLS
//   var grandBillsCell =
//       sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
//   grandBillsCell.value = totalBillsGrand;
// grandBillsCell.cellStyle =
//     totalBillsGrand > 0 ? orangeStyle : redStyle;


  // CATEGORY GRAND TOTAL
  num grandTotal = 0;

  for (int c = 0; c < categories.length; c++) {
    int categoryId = categoryList[c]['id'];
    num qty = categoryTotals[categoryId] ?? 0;
    grandTotal += qty;

  var cell = sheetObject.cell(
  CellIndex.indexByColumnRow(columnIndex: c + 2, rowIndex: rowIndex),
);
cell.value = qty;
cell.cellStyle = yellowStyle;

  }

  // WRITE GRAND TOTAL QTY
// WRITE GRAND TOTAL (under TOTAL column → column 1)
var totalQtyCell = sheetObject.cell(
  CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
);

totalQtyCell.value = grandTotal;
totalQtyCell.cellStyle = grandTotal > 0 ? greenTotalStyle : redBodyStyle;


  // SAVE FILE
  final dir = await getTemporaryDirectory();
  final filePath =
      "${dir.path}/State_Product_Report_${staff['name']}.xlsx";

  File(filePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(excel.encode()!);

  await Share.shareXFiles([XFile(filePath)],
      text: "State Product Report - ${staff['name']}");
}


  // ==========================================================
  //          CUSTOMER PRODUCT EXCEL GENERATION
  // ==========================================================
  Future<void> generateCustomerProductExcel() async {
  if (selectedStaff == null) return;

  var staff = staffList.firstWhere(
    (s) => s['id'].toString() == selectedStaff,
  );

  List<Map<String, dynamic>> customerList = customer;

  List<String> categories =
      categoryList.map((e) => e['name'].toString()).toList();

  var excel = Excel.createExcel();
  Sheet sheetObject = excel['Customer_Product_Report'];

  // ---------- STYLES ----------
  CellStyle titleStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#FF0000",
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    fontSize: 14,
  );

  CellStyle headerStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#ADD8E6",
    horizontalAlign: HorizontalAlign.Center,
  );

  CellStyle redBodyStyle = CellStyle(
    bold: false,
    fontColorHex: "#000000",
    backgroundColorHex: "#FF0000",
    horizontalAlign: HorizontalAlign.Center,
  );

  CellStyle yellowStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#FFFF00",
    horizontalAlign: HorizontalAlign.Center,
  );

  CellStyle greenTotalStyle = CellStyle(
    bold: true,
    fontColorHex: "#000000",
    backgroundColorHex: "#00FF00",
    horizontalAlign: HorizontalAlign.Center,
  );

  int totalColumns = categories.length + 2; // CUSTOMER + TOTAL + CATEGORIES

  // ---------- TITLE ----------
  sheetObject.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    CellIndex.indexByColumnRow(columnIndex: totalColumns - 1, rowIndex: 0),
  );

  var titleCell =
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));

  titleCell.value =
      "Customer Product Report - ${staff['name']} ${startDate != null ? "(${startDate!.toString().substring(0, 10)} to ${endDate!.toString().substring(0, 10)})" : ""}";
  titleCell.cellStyle = titleStyle;

  // ---------- EMPTY ROW ----------
  for (int col = 0; col < totalColumns; col++) {
    sheetObject
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1))
        .value = "";
  }

  // ---------- HEADER ROW ----------
  int headerRow = 2;

  sheetObject
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow))
    ..value = "CUSTOMER"
    ..cellStyle = headerStyle;

  sheetObject
      .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow))
    ..value = "TOTAL"
    ..cellStyle = headerStyle;

  // Category headers start at column 2
  for (int c = 0; c < categories.length; c++) {
    sheetObject
        .cell(CellIndex.indexByColumnRow(columnIndex: c + 2, rowIndex: headerRow))
      ..value = categories[c]
      ..cellStyle = headerStyle;
  }

  // ---------- BUILD TOTALS ----------
  Map<String, Map<int, num>> customerTotals = {};
  Map<int, num> grandCategoryTotals = {};

  for (var cust in customerList) {
    String customerName = cust["name"];
    int customerId = cust["id"];

    customerTotals.putIfAbsent(customerName, () => {});

    for (var entry in report) {
      bool staffMatch = entry["staff"].toString() == selectedStaff;
      bool customerMatch = entry["customer"] == customerId;

      String? dateStr = entry["date"];
      if (dateStr == null || dateStr.isEmpty) continue;

      DateTime? entryDate = DateTime.tryParse(dateStr);
      if (entryDate == null) continue;

      bool dateMatch = (startDate == null || endDate == null)
          ? true
          : entryDate.isAfter(startDate!.subtract(const Duration(days: 1))) &&
              entryDate.isBefore(endDate!.add(const Duration(days: 1)));

      if (staffMatch && customerMatch && dateMatch && entry["items"] != null) {
        for (var item in entry["items"]) {
          int categoryId = item["category"];
          num qty = item["quantity"];

          customerTotals[customerName]!.update(
            categoryId,
            (v) => v + qty,
            ifAbsent: () => qty,
          );

          grandCategoryTotals.update(
            categoryId,
            (v) => v + qty,
            ifAbsent: () => qty,
          );
        }
      }
    }
  }

  // ---------- WRITE ROWS ----------
  int rowIndex = headerRow + 1;

  customerTotals.forEach((customerName, catData) {
    num totalQty = 0;

    // CUSTOMER NAME
    sheetObject
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
      ..value = customerName;

    // CATEGORY COLUMNS (start at column 2)
    for (int c = 0; c < categories.length; c++) {
      int categoryId = categoryList[c]['id'];
      num qty = catData[categoryId] ?? 0;

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: c + 2, rowIndex: rowIndex))
        ..value = qty
        ..cellStyle = qty > 0 ? yellowStyle : redBodyStyle;

      totalQty += qty;
    }

    // TOTAL COLUMN (col 1)
    sheetObject
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
      ..value = totalQty
      ..cellStyle = totalQty > 0 ? greenTotalStyle : redBodyStyle;

    rowIndex++;
  });

  // ---------- EMPTY ROW ----------
  for (int col = 0; col < totalColumns; col++) {
    sheetObject
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex))
        .value = "";
  }

  rowIndex++;

  // ---------- GRAND TOTAL ----------
  sheetObject
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
    ..value = "GRAND TOTAL"
    ..cellStyle = yellowStyle;

  num finalGrandTotal = 0;

  for (int c = 0; c < categories.length; c++) {
    int categoryId = categoryList[c]['id'];
    num qty = grandCategoryTotals[categoryId] ?? 0;

    finalGrandTotal += qty;

    sheetObject
        .cell(CellIndex.indexByColumnRow(columnIndex: c + 2, rowIndex: rowIndex))
      ..value = qty
      ..cellStyle = yellowStyle;
  }

  sheetObject
      .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
    ..value = finalGrandTotal
    ..cellStyle = finalGrandTotal > 0 ? greenTotalStyle : redBodyStyle;

  // ---------- SAVE ----------
  final dir = await getTemporaryDirectory();
  final filePath =
      "${dir.path}/Customer_Product_Report_${staff['name']}.xlsx";

  File(filePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(excel.encode()!);

  await Share.shareXFiles([XFile(filePath)],
      text: "Customer Product Report - ${staff['name']}");
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 70,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1AA48F), Color(0xFF1AA48F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Product Report",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Staff",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1AA48F),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFF1AA48F), width: 1.3),
              ),
              child: TextField(
                controller: staffSearchCtrl,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) => filterStaff(value),
                decoration: const InputDecoration(
                  hintText: "Search Staff",
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF1AA48F)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          Container(
  decoration: BoxDecoration(
    color: Colors.grey[900]!.withOpacity(0.5),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Color(0xFF1AA48F), width: 1.3),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1AA48F).withOpacity(0.4),
        blurRadius: 12,
        spreadRadius: 0.5,
      ),
    ],
  ),

  child: Builder(
    builder: (_) {
      // ⭐ FIX: Prevent crash if selectedStaff doesn't exist
      if (selectedStaff != null) {
        bool exists = filteredStaffList
            .any((s) => s['id'].toString() == selectedStaff);

        if (!exists) selectedStaff = null;
      }

      return DropdownButtonFormField<String>(
        dropdownColor: Colors.grey[900],
        isExpanded: true,
        value: selectedStaff,
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFF1AA48F),
        ),
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        items: filteredStaffList.map((s) {
          return DropdownMenuItem(
            value: s['id'].toString(),
            child: Text(
              s['name'],
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (value) async {
          setState(() {
            selectedStaff = value;
            startDate = null;
            endDate = null;
          });
          await getcustomer(value);
        },
      );
    },
  ),
),

            const SizedBox(height: 20),
            const Text(
              "Select Date Range",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1AA48F),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange:
                      startDate != null && endDate != null
                          ? DateTimeRange(start: startDate!, end: endDate!)
                          : null,
                );

                if (picked != null) {
                  setState(() {
                    startDate = picked.start;
                    endDate = picked.end;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[900]!.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF1AA48F),
                    width: 1.3,
                  ),
                ),
                child: Text(
                  startDate == null
                      ? "Select Date Range"
                      : "${startDate!.toString().substring(0, 10)}  to  ${endDate!.toString().substring(0, 10)}",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (selectedStaff != null)
              Column(
                children: [
                  const SizedBox(height: 30),
                  // ===== FIRST BUTTON =====
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF1AA48F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          (startDate != null && endDate != null)
                              ? () => generateStateProductExcel()
                              : null,
                      child: const Text(
                        "State Wise Report",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ===== SECOND BUTTON =====
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF1AA48F), // SAME COLOR
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: generateCustomerProductExcel,
                      child: const Text(
                        "Customer Wise Report",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
