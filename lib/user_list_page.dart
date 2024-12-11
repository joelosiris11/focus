import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserListPage extends StatefulWidget {
  final User currentUser;

  const UserListPage({Key? key, required this.currentUser}) : super(key: key);

  @override
  _UserListPageState createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final firestore = FirebaseFirestore.instance;
    final usersSnapshot = await firestore.collection('users').get();
    
    List<Map<String, dynamic>> users = [];
    
    for (var doc in usersSnapshot.docs) {
      final userData = doc.data();
      final userId = doc.id;
      
      final projectsSnapshot = await firestore.collection('userProjects').doc(userId).get();
      final projects = projectsSnapshot.data()?['projects'] as List<dynamic>? ?? [];
      
      final tasksSnapshot = await firestore.collection('tasks').where('assignedTo', isEqualTo: userId).get();
      final tasks = tasksSnapshot.docs.map((doc) => doc.data()).toList();
      
      users.add({
        'id': userId,
        'displayName': userData['displayName'],
        'email': userData['email'] ?? 'Sin correo',
        'photoURL': userData['photoURL'],
        'projectCount': projects.length,
        'taskCount': tasks.length,
      });
    }
    
    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header con gradiente
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2196F3),
                  Color(0xFF1976D2),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 32,
              left: 24,
              right: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Usuarios',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de usuarios
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Error al cargar usuarios',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.all(20),
                  itemCount: users.length,
                  itemBuilder: (context, index) => _buildUserCard(users[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showUserProjects(user['id'], user['displayName'] ?? user['email'].toString().split('@')[0]),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar del usuario con foto de perfil o ícono por defecto
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage(user['photoURL'] ?? 
                        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user['displayName'] ?? user['email'])}&background=0D8ABC&color=fff'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['displayName'] ?? user['email'].toString().split('@')[0],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (user['displayName'] != null)
                        Text(
                          user['email'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildInfoChip(Icons.rocket_launch_rounded, user['projectCount'].toString(), Colors.orange[700]!),
                    SizedBox(height: 8),
                    _buildInfoChip(Icons.assignment_rounded, user['taskCount'].toString(), Colors.green[600]!),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitial(String name) {
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    } else {
      return '?';
    }
  }

  Future<void> _showUserProjects(String userId, String userName) async {
    try {
      final userProjectsDoc = await FirebaseFirestore.instance
          .collection('userProjects')
          .doc(userId)
          .get();

      final userTasksDoc = await FirebaseFirestore.instance
          .collection('userTasks')
          .doc(userId)
          .get();

      Set<String> projectIds = {};

      if (userProjectsDoc.exists) {
        projectIds.addAll(List<String>.from(userProjectsDoc.data()?['projects'] ?? []));
      }

      if (userTasksDoc.exists) {
        final taskIds = List<String>.from(userTasksDoc.data()?['tasks'] ?? []);
        for (String taskId in taskIds) {
          final taskDoc = await FirebaseFirestore.instance
              .collection('tasks')
              .doc(taskId)
              .get();
          
          if (taskDoc.exists) {
            final projectId = taskDoc.data()?['projectId'];
            if (projectId != null) {
              projectIds.add(projectId);
            }
          }
        }
      }

      List<Map<String, dynamic>> projects = [];
      for (String projectId in projectIds) {
        final projectDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .get();
        
        if (projectDoc.exists) {
          final data = projectDoc.data()!;
          final isOwner = data['ownerId'] == userId;
          final isMember = data['members']?.contains(userId) ?? false;

          final projectTasks = await FirebaseFirestore.instance
              .collection('tasks')
              .where('projectId', isEqualTo: projectId)
              .where('assignedTo', isEqualTo: userId)
              .get();

          projects.add({
            'id': projectId,
            'title': data['title'],
            'status': data['status'],
            'color': data['color'],
            'description': data['description'],
            'progress': data['progress'],
            'isOwner': isOwner,
            'isMember': isMember,
            'taskCount': projectTasks.docs.length,
          });
        }
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Proyectos de $userName',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: projects.isEmpty
                    ? Center(
                        child: Text('No hay proyectos asignados'),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _parseColor(project['color']).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  project['isOwner'] 
                                      ? Icons.folder_special_rounded
                                      : project['isMember']
                                          ? Icons.folder_shared_rounded
                                          : Icons.folder_outlined,
                                  color: _parseColor(project['color']),
                                ),
                              ),
                              title: Text(
                                project['title'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(project['description'] ?? ''),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Urgente',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${project['taskCount']} tareas',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _showProjectTasks(project['id'], project['title']),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error loading user projects: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar los proyectos')),
      );
    }
  }

  Color _parseColor(String color) {
    if (color.startsWith('#')) {
      return Color(int.parse(color.substring(1), radix: 16));
    } else if (color.startsWith('0x')) {
      return Color(int.parse(color.substring(2), radix: 16));
    } else {
      throw Exception('Invalid color format');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'por hacer':
        return Colors.orange;
      case 'en proceso':
        return Colors.blue;
      case 'en revision':
        return Colors.purple;
      case 'completado':
      case 'completada':
        return Colors.green;
      case 'archivado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showProjectTasks(String projectId, String projectTitle) async {
    try {
      // Obtener las tareas
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('projectId', isEqualTo: projectId)
          .get();

      // Obtener información de usuarios para mostrar quién tiene asignada cada tarea
      Map<String, Map<String, dynamic>> usersInfo = {};
      for (var doc in tasksSnapshot.docs) {
        final assignedTo = doc.data()['assignedTo'] as String?;
        if (assignedTo != null && !usersInfo.containsKey(assignedTo)) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(assignedTo)
              .get();
          if (userDoc.exists) {
            usersInfo[assignedTo] = {
              'displayName': userDoc.data()?['displayName'],
              'email': userDoc.data()?['email'],
              'photoURL': userDoc.data()?['photoURL'],
            };
          }
        }
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Tareas de $projectTitle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tasksSnapshot.docs.isEmpty
                    ? Center(
                        child: Text('No hay tareas en este proyecto'),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: tasksSnapshot.docs.length,
                        itemBuilder: (context, index) {
                          final task = tasksSnapshot.docs[index].data();
                          final assignedTo = task['assignedTo'] as String?;
                          final assignedUser = usersInfo[assignedTo];

                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.assignment_outlined,
                                color: _getStatusColor(task['status']),
                              ),
                              title: Text(
                                task['title'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (task['description'] != null && task['description'].toString().isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: Text(task['description']),
                                    ),
                                  if (assignedUser != null)
                                    Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: DecorationImage(
                                              image: NetworkImage(assignedUser['photoURL'] ?? 
                                                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(assignedUser['displayName'] ?? assignedUser['email'])}&background=0D8ABC&color=fff'),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          assignedUser['displayName'] ?? assignedUser['email'].toString().split('@')[0],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(task['status']).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  task['status'],
                                  style: TextStyle(
                                    color: _getStatusColor(task['status']),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error loading project tasks: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las tareas')),
      );
    }
  }
}
