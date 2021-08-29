import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseApi {
  static UploadTask uploadFile(String destination, File file) {
    try {
      final ref = FirebaseStorage.instance.ref(destination);

      return ref.putFile(file);
    } on FirebaseException catch (e) {
      return null;
    }
  }

  List id = [];
  uploadUrlToFireBase(Map data) async {
    var uploadUrl =
        await FirebaseFirestore.instance.collection('Url Links').add(data);
    id.add(uploadUrl.id);
  }

  getFirebaseUrl() async {
    return  FirebaseFirestore.instance.collection('Url Links').snapshots();
  }

  delete(var index) async {
    var id = await FirebaseFirestore.instance
        .collection('Url Links')
        .doc(index)
        .delete();
  }
}
