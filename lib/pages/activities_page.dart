import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'project_screen_details.dart';
import 'package:rxdart/rxdart.dart';
import 'main_dashboard.dart'; // Para usar ActivityItem
import 'package:percent_indicator/percent_indicator.dart';

class ActivitiesPage extends StatefulWidget {
  final User user;

  const ActivitiesPage({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  _ActivitiesPageState createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  late Stream<List<ActivityItem>> _activityStream;
  bool _isLoading = true;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeActivityStream();
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _initializeActivityStream() {
    _activityStream = _getMonthlyActivity();
  }

  Stream<List<ActivityItem>> _getMonthlyActivity() {
    final oneMonthAgo = DateTime.now().subtract(Duration(days: 30));
    final oneMonthAgoTimestamp = Timestamp.fromDate(oneMonthAgo);
    
    int totalSteps = 0;
    int completedSteps = 0;

    void updateProgress() {
      if (mounted) {
        setState(() {
          _loadingProgress = completedSteps / (totalSteps == 0 ? 1 : totalSteps);
        });
      }
    }

    return Rx.combineLatest3(
      // Stream de proyectos
      FirebaseFirestore.instance
          .collection('projects')
          .where('createdAt', isGreaterThan: oneMonthAgoTimestamp)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            List<ActivityItem> projectItems = [];
            totalSteps += snapshot.docs.length;
            updateProgress();
            
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(data['ownerId'])
                  .get();
              
              final userData = userDoc.data() ?? {};
              final userName = userData['displayName'] ?? 'Usuario';
              
              projectItems.add(ActivityItem(
                type: 'project',
                title: data['title'] ?? 'Nuevo proyecto',
                message: 'Proyecto creado',
                timestamp: data['createdAt'] as Timestamp,
                id: doc.id,
                userId: data['ownerId'],
                userName: userName,
                projectId: doc.id,
              ));
              
              completedSteps++;
              updateProgress();
            }
            return projectItems;
          }),
      // Stream de tareas
      FirebaseFirestore.instance
          .collection('tasks')
          .where('createdAt', isGreaterThan: oneMonthAgoTimestamp)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            List<ActivityItem> taskItems = [];
            totalSteps += snapshot.docs.length;
            updateProgress();
            
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final projectDoc = await FirebaseFirestore.instance
                  .collection('projects')
                  .doc(data['projectId'])
                  .get();
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(data['assignedTo'])
                  .get();
              
              final userData = userDoc.data() ?? {};
              final projectTitle = projectDoc.data()?['title'] ?? 'proyecto';
              final userName = userData['displayName'] ?? 'Usuario';

              taskItems.add(ActivityItem(
                type: 'task',
                title: data['title'] ?? 'Nueva tarea',
                message: 'Tarea creada en $projectTitle',
                timestamp: data['createdAt'] as Timestamp,
                id: doc.id,
                userId: data['assignedTo'],
                userName: userName,
                projectId: data['projectId'],
              ));
              
              completedSteps++;
              updateProgress();
            }
            return taskItems;
          }),
      // Stream de comentarios
      FirebaseFirestore.instance
          .collection('projects')
          .snapshots()
          .asyncMap((projectsSnapshot) async {
            List<ActivityItem> commentItems = [];
            for (var projectDoc in projectsSnapshot.docs) {
              final commentsSnapshot = await projectDoc
                  .reference
                  .collection('comments')
                  .where('createdAt', isGreaterThan: oneMonthAgoTimestamp)
                  .orderBy('createdAt', descending: true)
                  .get();

              for (var commentDoc in commentsSnapshot.docs) {
                final data = commentDoc.data();
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['userId'])
                    .get();
                final userName = userDoc.data()?['name'] ?? 'Usuario';

                commentItems.add(ActivityItem(
                  type: 'comment',
                  title: 'Nuevo comentario en ${projectDoc.data()['title']}',
                  message: data['content'] ?? '',
                  timestamp: data['createdAt'] as Timestamp,
                  id: commentDoc.id,
                  userId: data['userId'],
                  userName: userName,
                  projectId: projectDoc.id,
                ));
              }
            }
            commentItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            return commentItems;
          }),
      (projects, tasks, comments) {
        final allActivities = [...projects, ...tasks, ...comments];
        allActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return allActivities; // Sin límite de items
      },
    ).handleError((error) {
      print('Error en el stream: $error');
      return [];
    });
  }

  Widget _buildActivityItem(ActivityItem activity) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectScreenDetails(
              projectId: activity.projectId,
            ),
          ),
        );
      },
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getActivityColor(activity.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getActivityIcon(activity.type),
            color: _getActivityColor(activity.type),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                activity.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              _formatTimestamp(activity.timestamp),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              activity.message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'por ${activity.userName}',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'project':
        return Colors.blue;
      case 'task':
        return Colors.green;
      case 'comment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'project':
        return Icons.folder_outlined;
      case 'task':
        return Icons.assignment_outlined;
      case 'comment':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Hace ${difference.inMinutes} minutos';
      }
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Actividad del Último Mes',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<ActivityItem>>(
        stream: _activityStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Container(
                padding: EdgeInsets.all(24),
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
                    CircularPercentIndicator(
                      radius: 60.0,
                      lineWidth: 8.0,
                      animation: true,
                      animationDuration: 500,
                      percent: _loadingProgress,
                      center: Text(
                        "${(_loadingProgress * 100).toInt()}%",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20.0,
                          color: Color(0xFF3498DB),
                        ),
                      ),
                      circularStrokeCap: CircularStrokeCap.round,
                      progressColor: Color(0xFF3498DB),
                      backgroundColor: Color(0xFF3498DB).withOpacity(0.1),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Cargando actividades recientes...',
                      style: TextStyle(
                        color: Color(0xFF2C3E50),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Esto puede tomar unos segundos',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          final activities = snapshot.data!;
          
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No hay actividad en el último mes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(24),
            physics: BouncingScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('projects')
                    .doc(activity.projectId)
                    .get(),
                builder: (context, projectSnapshot) {
                  if (!projectSnapshot.hasData || !projectSnapshot.data!.exists) {
                    return SizedBox.shrink();
                  }
                  return _buildActivityItem(activity);
                },
              );
            },
          );
        },
      ),
    );
  }
} 