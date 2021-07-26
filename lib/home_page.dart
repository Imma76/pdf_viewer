import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:path_provider/path_provider.dart';
import 'package:pdf_viewer/pdf_viewer.dart';
import 'package:pdf_viewer/services.dart';
import 'package:path/path.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var result;
  String fileName;
  Stream streamData;
  File file;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  // var snapshots;
  FirebaseApi _firebaseApi = FirebaseApi();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _firebaseApi.getFirebaseUrl().then((result) {
      setState(() {
        streamData = result;
      });
    });
  }

  UploadTask task;
  @override
  Widget build(BuildContext context) {
    final fileName = file != null ? basename(file.path) : "No file Selected";

    return Scaffold(
      appBar: AppBar(),
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          //getPdf();
        },
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StreamBuilder(
              stream: streamData,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final pdfFiles = snapshot.data.docs.reversed;
                  for (var files in pdfFiles) {}
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data.docs.reversed.length,
                    itemBuilder: (context, index) {
                      var rev = snapshot.data.docs.reversed.toList();
                      return Column(
                        children: [
                          Container(
                            height: 70.0,
                            color: Colors.grey,
                            width: double.infinity,
                            child: Center(
                              child: ListTile(
                                subtitle: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.download_rounded,
                                      ),
                                      onPressed: () {
                                        downloadFiles(
                                            rev[index].get('downloadUrl'));
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove_red_eye,
                                      ),
                                      onPressed: () {
                                        Navigator.push(context,
                                            MaterialPageRoute(
                                                builder: (context) {
                                          return PDFVIEWER(
                                            link: rev[index].get('downloadUrl'),
                                          );
                                        }));
                                      },
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                    ),
                                    onPressed: () async {
                                      var idGet = rev[index].id;
                                      await _firebaseApi.delete(idGet);
                                      await _delete(
                                          rev[index].get('downloadUrl'));
                                      // _firebaseApi.id.removeAt(index);
                                      //  print(rev[index].id);
                                    }),
                                title: Text(rev[index].get('fileName')),
                              ),
                            ),
                          ),
                          Divider(
                            height: 1.0,
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  return Container();
                }
              },
            ),
            FlatButton(
              color: Colors.green,
              onPressed: () {
                selectFile();
              },
              child: Text('Select File'),
            ),
            Text(fileName),
            SizedBox(
              height: 20.0,
            ),
            FlatButton(
              color: Colors.green,
              onPressed: () {
                uploadFile();
              },
              child: Text('Upload File'),
            ),
            task != null ? buildUploadStatus(task) : Container(),
          ],
        ),
      ),
    );
  }

  Future selectFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null) return;
    final path = result.files.single.path;
    setState(() {
      file = File(path);
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
    //final delete = await snapshots.ref.delete();
    // print('download url is $urlDownload');
    var url = {
      'downloadUrl': urlDownload,
      'fileName': fileName,
    };
    _firebaseApi.uploadUrlToFireBase(url);
  }

  Future<void> _delete(String url) async {
    // await FirebaseStorage.instance.
    Reference photoRef = await FirebaseStorage.instance.refFromURL(url);
    await photoRef.delete();

    await photoRef.delete();
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

  // Future<void> downloadFile(StorageReference ref) async {
  //   final String url = await ref.getDownloadURL();
  //   final http.Response downloadData = await http.get(url);
  //   final Directory systemTempDir = Directory.systemTemp;
  //   final File tempFile = File('${systemTempDir.path}/tmp.jpg');
  //   if (tempFile.existsSync()) {
  //     await tempFile.delete();
  //   }
  //   await tempFile.create();
  //   final StorageFileDownloadTask task = ref.writeToFile(tempFile);
  //   final int byteCount = (await task.future).totalByteCount;
  //   var bodyBytes = downloadData.bodyBytes;
  //   final String name = await ref.getName();
  //   final String path = await ref.getPath();
  //   print(
  //     'Success!\nDownloaded $name \nUrl: $url'
  //         '\npath: $path \nBytes Count :: $byteCount',
  //   );
  //   _scaffoldKey.currentState.showSnackBar(
  //     SnackBar(
  //       backgroundColor: Colors.white,
  //       content: Image.memory(
  //         bodyBytes,
  //         fit: BoxFit.fill,
  //       ),
  //     ),
  //   );
  // }
  static Future downloadFiles(var ref) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${ref.name}');

    await ref.writeToFile(file);
  }
}
