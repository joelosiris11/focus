import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../project_details_page.dart';

class AllProjectsPage extends StatefulWidget {
  final User user;

  const AllProjectsPage({Key? key, required this.user}) : super(key: key);

  @override
  _AllProjectsPageState createState() => _AllProjectsPageState();
}

class _AllProjectsPageState extends State<AllProjectsPage> {
  late Future<List<Map<String, dynamic>>> _projectsFuture;
  Map<String, Map<String, dynamic>> _userStats = {};

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
  }

  Future<List<Map<String, dynamic>>> _loadProjects() async {
    final projectsSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .get();

    List<Map<String, dynamic>> projects = [];
    
    for (var doc in projectsSnapshot.docs) {
      Map<String, dynamic> project = doc.data();
      project['id'] = doc.id;

      // Cargar estadísticas de usuarios para este proyecto
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('projectId', isEqualTo: doc.id)
          .get();

      Map<String, Map<String, int>> userTaskCounts = {};

      for (var taskDoc in tasksSnapshot.docs) {
        final taskData = taskDoc.data();
        final assignedTo = taskData['assignedTo'] as String?;
        if (assignedTo != null) {
          if (!userTaskCounts.containsKey(assignedTo)) {
            userTaskCounts[assignedTo] = {
              'total': 0,
              'completed': 0,
              'inProgress': 0,
              'pending': 0
            };
          }
          userTaskCounts[assignedTo]!['total'] = (userTaskCounts[assignedTo]!['total']! + 1);
          
          switch (taskData['status']) {
            case 'completada':
              userTaskCounts[assignedTo]!['completed'] = (userTaskCounts[assignedTo]!['completed']! + 1);
              break;
            case 'en proceso':
              userTaskCounts[assignedTo]!['inProgress'] = (userTaskCounts[assignedTo]!['inProgress']! + 1);
              break;
            default:
              userTaskCounts[assignedTo]!['pending'] = (userTaskCounts[assignedTo]!['pending']! + 1);
          }
        }
      }

      // Cargar información de usuarios
      for (String userId in userTaskCounts.keys) {
        if (!_userStats.containsKey(userId)) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            _userStats[userId] = {
              'displayName': userDoc.data()!['displayName'],
              'photoURL': userDoc.data()!['photoURL'],
            };
          }
        }
      }

      project['userStats'] = userTaskCounts;
      projects.add(project);
    }

    return projects;
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
                      'Todos los Proyectos',
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
          ),

          // Lista de proyectos
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _projectsFuture,
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
                          'Error al cargar los proyectos',
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

                final projects = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.all(20),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    return _buildProjectCard(projects[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    // Calcular el progreso real basado en las tareas
    final userStats = project['userStats'] as Map<String, Map<String, int>>;
    int totalTasks = 0;
    int completedTasks = 0;
    int inProgressTasks = 0;

    userStats.forEach((userId, stats) {
      totalTasks += stats['total'] ?? 0;
      completedTasks += stats['completed'] ?? 0;
      inProgressTasks += stats['inProgress'] ?? 0;
    });

    // Calcular progreso considerando tareas completadas y en progreso
    final calculatedProgress = totalTasks > 0 
        ? ((completedTasks + (inProgressTasks * 0.5)) / totalTasks * 100).clamp(0.0, 100.0)
        : 0.0;

    final dueDate = project['dueDate'] as Timestamp;
    final createdAt = (project['createdAt'] as Timestamp?) ?? Timestamp.now();
    final now = DateTime.now();
    
    // Calcular progreso del tiempo
    final totalDuration = dueDate.toDate().difference(createdAt.toDate());
    final elapsedDuration = now.difference(createdAt.toDate());
    final timeProgress = totalDuration.inSeconds > 0 
        ? (elapsedDuration.inSeconds / totalDuration.inSeconds * 100).clamp(0.0, 100.0)
        : 100.0;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailsPage(
                user: widget.user,
                projectId: project['id'],
                projectTitle: project['title'],
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(project['status'] ?? 'En progreso').withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: _getStatusColor(project['status'] ?? 'En progreso'),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project['title'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDate(project['dueDate']),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(project['status'] ?? 'En progreso').withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        project['status'] ?? 'En progreso',
                        style: TextStyle(
                          color: _getStatusColor(project['status'] ?? 'En progreso'),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Barras de progreso con diseño mejorado
                _buildProgressSection(
                  'Progreso del proyecto',
                  calculatedProgress,
                  _getProgressColor(calculatedProgress),
                ),
                SizedBox(height: 12),
                _buildProgressSection(
                  'Tiempo transcurrido',
                  timeProgress,
                  Colors.orange[400]!,
                ),
                // Contribuidores
                if (userStats.isNotEmpty) ...[
                  SizedBox(height: 20),
                  _buildContributorsSection(userStats),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(String title, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${progress.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 8.0,
          percent: (progress / 100).clamp(0.0, 1.0),
          barRadius: Radius.circular(4),
          progressColor: color,
          backgroundColor: color.withOpacity(0.15),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildContributorsSection(Map<String, Map<String, int>> userStats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contribuidores',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: userStats.entries.take(5).map((entry) {
              final user = _userStats[entry.key];
              if (user == null) return SizedBox.shrink();
              return Container(
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: user['photoURL'] != null 
                      ? NetworkImage(user['photoURL'])
                      : null,
                  backgroundColor: Colors.blue[100],
                  child: user['photoURL'] == null 
                      ? Text(
                          user['displayName'][0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completado':
        return Colors.green[700]!;
      case 'en progreso':
        return Colors.blue[700]!;
      case 'retrasado':
        return Colors.orange[700]!;
      case 'en riesgo':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 75.0) return Colors.green[400]!;
    if (progress >= 50.0) return Colors.blue[400]!;
    if (progress >= 25.0) return Colors.orange[400]!;
    return Colors.red[400]!;
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _UserTasksSheet extends StatelessWidget {
  final String userId;
  final String projectId;
  final String userName;

  const _UserTasksSheet({
    required this.userId,
    required this.projectId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tareas de $userName',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tasks')
                      .where('projectId', isEqualTo: projectId)
                      .where('assignedTo', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No hay tareas asignadas'));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final task = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            leading: _getStatusIcon(task['status']),
                            title: Text(task['title']),
                            subtitle: Text(task['description'] ?? 'Sin descripción'),
                            trailing: Text(_getFormattedDate(task['dueDate'])),
                          ),
                        );
                      },
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

  Widget _getStatusIcon(String status) {
    IconData iconData;
    Color color;
    
    switch (status) {
      case 'completada':
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      case 'en proceso':
        iconData = Icons.pending;
        color = Colors.blue;
        break;
      default:
        iconData = Icons.circle_outlined;
        color = Colors.grey;
    }

    return Icon(iconData, color: color);
  }

  String _getFormattedDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
