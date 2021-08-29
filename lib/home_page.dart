import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_viewer/firebase_file.dart';
import 'package:pdf_viewer/pdf_viewer.dart';
import 'package:pdf_viewer/services.dart';
import 'package:path/path.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:cool_alert/cool_alert.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var result;
  String fileName;
  Stream streamData;
  File file;

  // var snapshots;
  FirebaseApi _firebaseApi = FirebaseApi();
  Future<List<FirebaseFile>> futureFiles;
  double value = 0;
  ReceivePort _receivePort = ReceivePort();
  static downloadingCallback(id, status, progress) {
    SendPort sendPort = IsolateNameServer.lookupPortByName('downloading');
    sendPort.send({id, status, progress});
  }

  @override
  void initState() {
    super.initState();
    IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, 'downloading');
    _firebaseApi.getFirebaseUrl().then((result) {
      setState(() {
        streamData = result;
      });
    });

    _receivePort.listen((message) {
      setState(() {
        value = message;
      });
    });
    print(value);
    FlutterDownloader.registerCallback(downloadingCallback);
  }

  UploadTask task;
  @override
  Widget build(BuildContext context) {
    final fileName = file != null ? basename(file.path) : "No file Selected";

    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: Colors.transparent,
      //   elevation: 0.0,
      // ),
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          //getPdf();
          selectFile(context);
        },
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder(
        stream: streamData,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            //  final pdfFiles = snapshot.data.docs.reversed;
            return ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: snapshot.data.docs.reversed.length,
              itemBuilder: (context, index) {
                var rev = snapshot.data.docs.reversed.toList();
                return Card(
                  elevation: 2.0,
                  shadowColor: Colors.black,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_rounded),
                                onPressed: () async {
                                  var idGet = rev[index].id;
                                  await _firebaseApi.delete(idGet);
                                  await _delete(
                                    rev[index].get('fileName'),
                                  );
                                },
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return PDFVIEWER(
                                  fileName: rev[index].get('fileName'),
                                  link: rev[index].get('downloadUrl'),
                                );
                              }));
                            },
                            child: Center(
                              child: Text(
                                'Click here to view ${rev[index].get('fileName')}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Center(
                            child: RaisedButton(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0)),
                              color: Colors.orange,
                              //  minWidth: 100.0,
                              onPressed: () async {
                                final status =
                                    await Permission.storage.request();
                                if (status.isGranted) {
                                  final externalDir =
                                      await getExternalStorageDirectory();
                                  final id = await FlutterDownloader.enqueue(
                                    url: rev[index].get('downloadUrl'),
                                    savedDir: externalDir.path,
                                    fileName: rev[index].get('fileName'),
                                    showNotification: true,
                                    openFileFromNotification: true,
                                  );
                                } else
                                  print('permission denied');
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.download_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Center(
                                      child: Text('download file ',
                                          style:
                                              TextStyle(color: Colors.white))),
                                ],
                              ),
                            ),
                          ),
                        ]),
                  ),
                );
              },
            );
          } else {
            return Container();
          }
        },
      ),
    );
  }

  Future selectFile(context) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null) return;
    final path = result.files.single.path;
    setState(() {
      file = File(path);
    });
    CoolAlert.show(
        context: context,
        type: CoolAlertType.confirm,
        text: "Are you sure you want to upload ${basename(file.path)}?",
        confirmBtnText: 'Upload',
        cancelBtnText: 'No',
        onConfirmBtnTap: () {
          uploadFile();
          Navigator.pop(context);
        },
        onCancelBtnTap: () {
          Navigator.pop(context);
        });
  }

  Future uploadFile() async {
    if (file == null) return;
    final fileName = basename(file.path);
    final destination = 'files/$fileName';
    task = FirebaseApi.uploadFile(destination, file);
    setState(() {});
    if (task == null) return;

    final snapshots = await task.whenComplete(() {});

    final urlDownload = await snapshots.ref.getDownloadURL();
    final name = snapshots.ref;
    //final delete = await snapshots.ref.delete();
    // print('download url is $urlDownload');
    var url = {
      'downloadUrl': urlDownload,
      'fileName': fileName,
      'reference': name.toString(),
    };
    _firebaseApi.uploadUrlToFireBase(url);
  }

  Future _delete(String url) async {
    // await FirebaseStorage.instance.
    Reference photoRef = FirebaseStorage.instance.ref('files/').child(url);
    await photoRef.delete();

    // await photoRef.delete();
    // Rebuild the UI
    setState(() {});
  }

  Widget buildUploadStatus(UploadTask task) => StreamBuilder<TaskSnapshot>(
        stream: task.snapshotEvents,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final snap = snapshot.data;
            final progress = snap.bytesTransferred / snap.totalBytes;
            final percentage = (progress * 100).toStringAsFixed(2);
            return Text('$percentage %');
          } else {
            return Container();
          }
        },
      );
}
