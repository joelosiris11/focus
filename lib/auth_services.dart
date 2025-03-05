import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signInWithGoogle() async {
    try {
      print('Iniciando el proceso de inicio de sesión con Google...');
      
      // Intentar signInSilently primero
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      
      // Si no hay una sesión silenciosa activa, entonces usar signIn
      if (googleUser == null) {
        googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          print('El usuario canceló el inicio de sesión.');
          return null; // El usuario canceló el inicio de sesión
        }
      }
      
      print('Usuario autenticado con Google: ${googleUser.email}');

      final GoogleSignInAuthentication? googleAuth = await googleUser.authentication;
      print('Autenticación de Google obtenida.');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        print('Inicio de sesión exitoso: ${user.email}');
        // Verificar si el usuario existe en la base de datos
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        print('Verificando si el usuario existe en Firestore...');

        if (!userDoc.exists) {
          print('El usuario no existe en Firestore, creando nuevo usuario...');
          await _createNewUser(user);
        } else {
          print('El usuario ya existe en Firestore.');
          // Actualizar última fecha de inicio de sesión
          await _firestore.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }

        return user;
      } else {
        print('Error: No se pudo obtener el usuario después de la autenticación.');
        return null;
      }
    } catch (e) {
      print('Error en signInWithGoogle: $e');
      return null;
    }
  }

  Future<void> _createNewUser(User user) async {
    try {
      // Asegurarse de que tenemos una URL de foto válida
      String? photoURL = user.photoURL;
      if (photoURL == null || photoURL.isEmpty) {
        photoURL = 'https://ui-avatars.com/api/?name=${user.displayName}&background=0D8ABC&color=fff';
      }

      print('Creando nuevo usuario en Firestore...');
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Inicializar documentos adicionales para el nuevo usuario
      await _firestore.collection('userProjects').doc(user.uid).set({
        'projects': [],
      });

      await _firestore.collection('userTasks').doc(user.uid).set({
        'tasks': [],
      });

      await _firestore.collection('taskSummaries').doc(user.uid).set({
        'totalTasks': 0,
        'pendingTasks': 0,
        'myTasks': 0,
        'assignedTasks': 0,
        'inProgressTasks': 0,
        'completedTasks': 0,
        'overdueTasks': 0,
      });
      print('Nuevo usuario creado exitosamente en Firestore.');
    } catch (e) {
      print('Error al crear nuevo usuario: $e');
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        print('Usuario actual encontrado: ${user.email}');
        // Verificar si el token de Google aún es válido
        final googleSignInAccount = await _googleSignIn.signInSilently();
        if (googleSignInAccount != null) {
          print('Token de Google válido, verificando usuario en Firestore...');
          // Verificar si el usuario existe en Firestore
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            print('El usuario existe en Firestore.');
            if (user.photoURL != userDoc.data()?['photoURL']) {
              print('Actualizando URL de foto del usuario en Firestore...');
              await _firestore.collection('users').doc(user.uid).update({
                'photoURL': user.photoURL,
                'lastLogin': FieldValue.serverTimestamp(),
              });
            }
          } else {
            print('El usuario no existe en Firestore, creando nuevo usuario...');
            await _createNewUser(user);
          }
          return user;
        } else {
          print('Token expirado, cerrando sesión...');
          await signOut();
          return null;
        }
      }
      print('No hay usuario actual.');
      return null;
    } catch (e) {
      print('Error en getCurrentUser: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    print('Cerrando sesión...');
    await _auth.signOut();
    await _googleSignIn.signOut();
    print('Sesión cerrada.');
  }
}
