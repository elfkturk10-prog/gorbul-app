import 'package:flutter/widgets.dart';
import 'package:gorbul/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dir = await getApplicationDocumentsDirectory();
  
  final filesToDel = [
    'prefs.json',
    'users.json',
    'listings.json',
    'favorites.json',
    'chats.json',
    'vaults.json'
  ];

  for(var f in filesToDel) {
    var file = File('${dir.path}/$f');
    if (await file.exists()) {
      await file.delete();
      print("Deleted $f");
    }
  }

  print("Tüm lokal veriler (JSON simülasyonları) temizlendi!");
  exit(0);
}
