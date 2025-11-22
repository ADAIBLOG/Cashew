import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/accountAndBackup.dart';

// 条件导入Firebase和Google登录相关包
import 'package:firebase_auth/firebase_auth.dart' if (dart.library.io) 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' if (dart.library.io) 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction if (dart.library.io) 'package:cloud_firestore/cloud_firestore.dart';

// 导入云服务禁用配置
import '../../../disable_cloud_services.dart';

OAuthCredential? _credential;

Future<FirebaseFirestore?> firebaseGetDBInstanceAnonymous() async {
  // 如果云服务被禁用，直接返回null
  if (disableAllCloudServices) {
    print("Firebase anonymous login skipped due to cloud services being disabled");
    return null;
  }
  
  try {
    await FirebaseAuth.instance.signInAnonymously();
    return FirebaseFirestore.instance;
  } catch (e) {
    print("There was an error with firebase login");
    print(e.toString());
    return null;
  }
}

// returns null if authentication unsuccessful
Future<FirebaseFirestore?> firebaseGetDBInstance() async {
  // 如果云服务被禁用，直接返回null
  if (disableAllCloudServices) {
    print("Firebase authentication skipped due to cloud services being disabled");
    return null;
  }
  
  if (_credential != null) {
    try {
      await FirebaseAuth.instance.signInWithCredential(_credential!);
      updateSettings(
        "currentUserEmail",
        FirebaseAuth.instance.currentUser!.email,
        pagesNeedingRefresh: [],
        updateGlobalState: false,
      );
      return FirebaseFirestore.instance;
    } catch (e) {
      print("There was an error with firebase login");
      print(e.toString());
      print("will retry with a new credential");
      _credential = null;
      googleUser = null;
      return await firebaseGetDBInstance();
    }
  } else {
    try {
      if (googleUser == null) {
        await signInGoogle(silentSignIn: true);
      }
      // GoogleSignInAccount? googleUser = googleUser;

      GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      _credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(_credential!);
      updateSettings(
          "currentUserEmail", FirebaseAuth.instance.currentUser!.email,
          updateGlobalState: true);
      return FirebaseFirestore.instance;
    } catch (e) {
      print("There was an error with firebase login and possibly google");
      print(e.toString());
      return null;
    }
  }
}
