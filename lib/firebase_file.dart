import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseFile {
  final Reference ref;
  final String name;
  final String url;
  FirebaseFile({@required this.name, @required this.ref, @required this.url});
}
