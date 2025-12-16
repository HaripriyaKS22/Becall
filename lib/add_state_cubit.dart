import 'dart:convert';
import 'package:becall2/api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddStateCubit extends Cubit<AddStateState> {
  AddStateCubit() : super(AddStateInitial());
 Future<String?> gettokenFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
  Future<void> saveState(String name,var id) async {
    if (name.isEmpty) {
      emit(AddStateError("Please enter state name"));
      return;
    }

    emit(AddStateLoading());
var token = await gettokenFromPrefs();
    try {
      final url = Uri.parse("$api/api/states/"); // replace with your Django endpoint
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"name": name,
        "country":id}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        emit(AddStateSuccess("State saved successfully!"));
      } else {
        emit(AddStateError("Failed to save. Code: ${response.statusCode}"));
      }
    } catch (e) {
      emit(AddStateError("Error: $e"));
    }
  }

  void reset() => emit(AddStateInitial());
}

abstract class AddStateState {}

class AddStateInitial extends AddStateState {}
class AddStateLoading extends AddStateState {}
class AddStateSuccess extends AddStateState {
  final String message;
  AddStateSuccess(this.message);
}
class AddStateError extends AddStateState {
  final String error;
  AddStateError(this.error);
}
