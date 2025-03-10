import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:ui';

class ConfigurationPage extends StatefulWidget {
  @override
  _ConfigurationPageState createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  final List<String> adminEmails = [
    'joelosiris11@gmail.com',
    'josejoaquinsosa2@gmail.com'
  ];

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _checkAccess() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || !adminEmails.contains(currentUser.email)) {
      Future.microtask(() {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No tienes permisos para acceder a esta página'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteProject(String projectId) async {
    try {
      print('🔍 DEBUG: Iniciando eliminación de proyecto: $projectId');
      
      // Obtener referencia al proyecto
      final projectRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
      
      // Batch para operaciones atómicas
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. Eliminar todos los comentarios
      try {
        print('🔍 DEBUG: Obteniendo comentarios del proyecto');
        final commentsSnapshot = await projectRef.collection('comments').get();
        print('🔍 DEBUG: Encontrados ${commentsSnapshot.docs.length} comentarios para eliminar');
        
        for (var doc in commentsSnapshot.docs) {
          batch.delete(doc.reference);
        }
      } catch (e) {
        print('❌ DEBUG: Error eliminando comentarios: $e');
        throw e;
      }

      // 2. Eliminar todos los archivos de Storage
      try {
        print('🔍 DEBUG: Obteniendo archivos del proyecto');
        final filesSnapshot = await projectRef.collection('files').get();
        print('🔍 DEBUG: Encontrados ${filesSnapshot.docs.length} archivos para eliminar');
        
        for (var doc in filesSnapshot.docs) {
          final fileData = doc.data();
          if (fileData['storageUrl'] != null) {
            print('🔍 DEBUG: Eliminando archivo de Storage: ${fileData['storageUrl']}');
            await FirebaseStorage.instance.refFromURL(fileData['storageUrl']).delete();
          }
          batch.delete(doc.reference);
        }
      } catch (e) {
        print('❌ DEBUG: Error eliminando archivos: $e');
        throw e;
      }

      // 3. Eliminar todas las tareas asociadas
      try {
        print('🔍 DEBUG: Obteniendo tareas del proyecto');
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('tasks')
            .where('projectId', isEqualTo: projectId)
            .get();
        print('🔍 DEBUG: Encontradas ${tasksSnapshot.docs.length} tareas para eliminar');
        
        for (var doc in tasksSnapshot.docs) {
          batch.delete(doc.reference);
        }
      } catch (e) {
        print('❌ DEBUG: Error eliminando tareas: $e');
        throw e;
      }

      // 4. Eliminar el proyecto
      try {
        print('🔍 DEBUG: Agregando proyecto al batch para eliminar');
        batch.delete(projectRef);
        
        print('🔍 DEBUG: Ejecutando batch de eliminación del proyecto');
        await batch.commit();
        print('✅ DEBUG: Proyecto eliminado exitosamente');
      } catch (e) {
        print('❌ DEBUG: Error en eliminación final del proyecto: $e');
        throw e;
      }

    } catch (e) {
      print('❌ DEBUG: Error general en eliminación de proyecto: $e');
      throw e;
    }
  }

  Future<void> _deleteUser(String userId) async {
    setState(() => _isLoading = true);
    try {
        print('🔍 DEBUG: Iniciando eliminación de usuario: $userId');
        print('🔍 DEBUG: Usuario actual: ${FirebaseAuth.instance.currentUser?.email}');

        // 1. Eliminar proyectos donde el usuario es propietario
        final projectsSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .where('ownerId', isEqualTo: userId)
            .get();
        
        print('🔍 DEBUG: Encontrados ${projectsSnapshot.docs.length} proyectos para eliminar');

        for (var project in projectsSnapshot.docs) {
            try {
                print('🔍 DEBUG: Intentando eliminar proyecto: ${project.id}');
                await _deleteProject(project.id);
                print('✅ DEBUG: Proyecto eliminado exitosamente: ${project.id}');
            } catch (e) {
                print('❌ DEBUG: Error eliminando proyecto ${project.id}: $e');
                throw e;
            }
        }

        // 2. Eliminar tareas asignadas al usuario
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('tasks')
            .where('assignedTo', isEqualTo: userId)
            .get();
        
        print('🔍 DEBUG: Encontradas ${tasksSnapshot.docs.length} tareas para eliminar');

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in tasksSnapshot.docs) {
            try {
                print('🔍 DEBUG: Agregando tarea al batch para eliminar: ${doc.id}');
                batch.delete(doc.reference);
            } catch (e) {
                print('❌ DEBUG: Error agregando tarea al batch ${doc.id}: $e');
                throw e;
            }
        }

        // 3. Eliminar documento del usuario y taskSummary
        try {
            print('🔍 DEBUG: Agregando usuario al batch para eliminar: $userId');
            batch.delete(FirebaseFirestore.instance.collection('users').doc(userId));
            batch.delete(FirebaseFirestore.instance.collection('taskSummaries').doc(userId));
        } catch (e) {
            print('❌ DEBUG: Error agregando usuario/taskSummary al batch: $e');
            throw e;
        }

        // Ejecutar el batch
        try {
            print('🔍 DEBUG: Ejecutando batch de eliminación');
            await batch.commit();
            print('✅ DEBUG: Batch ejecutado exitosamente');
        } catch (e) {
            print('❌ DEBUG: Error ejecutando batch: $e');
            throw e;
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Usuario eliminado correctamente')),
        );
    } catch (e) {
        print('❌ DEBUG: Error general en eliminación de usuario: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el usuario: $e')),
        );
    } finally {
        setState(() => _isLoading = false);
    }
  }

  Future<void> _createUser() async {
    final formKey = GlobalKey<FormState>();
    String email = '';
    String password = '';
    String displayName = '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header con gradiente
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.white, size: 28),
                      SizedBox(width: 16),
                      Text(
                        'Crear Nuevo Usuario',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido del formulario
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                        onSaved: (value) => displayName = value ?? '',
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (!value!.contains('@')) return 'Email inválido';
                          return null;
                        },
                        onSaved: (value) => email = value ?? '',
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (value!.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                        onSaved: (value) => password = value ?? '',
                      ),
                    ],
                  ),
                ),
                // Footer con botones
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancelar'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            formKey.currentState?.save();
                            try {
                              setState(() => _isLoading = true);
                              
                              // 1. Crear usuario en Authentication
                              final userCredential = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                email: email,
                                password: password,
                              );

                              // 2. Crear documento en Firestore
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userCredential.user!.uid)
                                  .set({
                                'displayName': displayName,
                                'email': email,
                                'createdAt': Timestamp.now(),
                                'lastLogin': null,
                                'isActive': true,
                                'photoURL': null,
                              });

                              // 3. Crear documentos relacionados
                              await FirebaseFirestore.instance
                                  .collection('taskSummaries')
                                  .doc(userCredential.user!.uid)
                                  .set({
                                'totalTasks': 0,
                                'completedTasks': 0,
                                'pendingTasks': 0,
                                'overdueTasks': 0,
                              });

                              await FirebaseFirestore.instance
                                  .collection('userProjects')
                                  .doc(userCredential.user!.uid)
                                  .set({
                                'projects': [],
                              });

                              await FirebaseFirestore.instance
                                  .collection('userTasks')
                                  .doc(userCredential.user!.uid)
                                  .set({
                                'tasks': [],
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Usuario creado exitosamente'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al crear usuario: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Crear Usuario'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Row(
        children: [
          // Barra lateral con gradiente
          Container(
            width: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2C3E50),
                  Color(0xFF3498DB),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Contenido principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con diseño moderno
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.settings, color: Colors.white, size: 28),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Configuración',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C3E50),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Spacer(),
                      ElevatedButton.icon(
                        icon: Icon(Icons.person_add),
                        label: Text('Crear Usuario'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ).copyWith(
                          overlayColor: MaterialStateProperty.all(
                            Colors.white.withOpacity(0.1),
                          ),
                        ),
                        onPressed: _createUser,
                      ),
                    ],
                  ),
                ),
                // Tabs con diseño moderno
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people),
                            SizedBox(width: 8),
                            Text('USUARIOS'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder),
                            SizedBox(width: 8),
                            Text('PROYECTOS'),
                          ],
                        ),
                      ),
                    ],
                    labelColor: Color(0xFF3498DB),
                    unselectedLabelColor: Colors.grey,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Color(0xFF3498DB).withOpacity(0.1),
                    ),
                    padding: EdgeInsets.all(8),
                  ),
                ),
                // Contenido de los tabs
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: LoadingIndicator(),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildUsersTab(),
                            _buildProjectsTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget personalizado para el indicador de carga
  Widget LoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando...',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: LoadingIndicator());

        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lista de Usuarios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = snapshot.data!.docs[index];
                    final data = user.data() as Map<String, dynamic>;

                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFF3498DB).withOpacity(0.1),
                          child: Text(
                            (data['name'] ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              color: Color(0xFF3498DB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['displayName'] ?? 'Sin nombre',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    data['email'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF3498DB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                data['role']?.toString().toUpperCase() ?? 'USER',
                                style: TextStyle(
                                  color: Color(0xFF3498DB),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline),
                          color: Colors.red[400],
                          onPressed: () => _showDeleteConfirmation(
                            context,
                            'usuario',
                            () => _deleteUser(user.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: LoadingIndicator());

        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lista de Proyectos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final project = snapshot.data!.docs[index];
                    final data = project.data() as Map<String, dynamic>;
                    final projectColor = Color(int.parse(data['color'].replaceAll('#', 'FF'), radix: 16));

                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: projectColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.folder_outlined,
                            color: projectColor,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'Sin título',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Creado el: ${_formatDate(data['createdAt'] as Timestamp)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(data['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                data['status']?.toString().toUpperCase() ?? 'EN PROGRESO',
                                style: TextStyle(
                                  color: _getStatusColor(data['status']),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline),
                          color: Colors.red[400],
                          onPressed: () => _showDeleteConfirmation(
                            context,
                            'proyecto',
                            () => _deleteProject(project.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completado':
        return Colors.green;
      case 'en progreso':
        return Colors.blue;
      case 'retrasado':
        return Colors.red;
      case 'pausado':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String itemType,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Eliminar $itemType'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar este $itemType? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
} 