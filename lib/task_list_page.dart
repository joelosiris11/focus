import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'dart:math';

class TaskListPage extends StatefulWidget {
  final User user;
  final String title;
  final String taskType;
  final String? status;

  const TaskListPage({
    Key? key,
    required this.user,
    required this.title,
    required this.taskType,
    this.status,
  }) : super(key: key);

  @override
  _TaskListPageState createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;

  final List<IconData> _projectIcons = [
    Icons.settings_suggest_rounded,
    Icons.architecture_rounded,
    Icons.rocket_launch_rounded,
    Icons.construction_rounded,
    Icons.auto_awesome_rounded,
    Icons.precision_manufacturing_rounded,
    Icons.build_circle_rounded,
    Icons.engineering_rounded,
    Icons.hub_rounded,
    Icons.settings_input_component_rounded,
    Icons.account_tree_rounded,
    Icons.memory_rounded,
  ];

  IconData _getRandomProjectIcon(String projectId) {
    final random = Random(projectId.hashCode);
    return _projectIcons[random.nextInt(_projectIcons.length)];
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      isLoading = true;
    });

    final userId = widget.user.uid;
    Query query = FirebaseFirestore.instance.collection('tasks').where('assignedTo', isEqualTo: userId);

    if (widget.status != null) {
      query = query.where('status', isEqualTo: widget.status);
    } else {
      switch (widget.taskType) {
        case 'myTasks':
          // No es necesario un filtro adicional, ya que todas son "mis tareas"
          break;
        case 'inProgressTasks':
          query = query.where('status', isEqualTo: 'en proceso');
          break;
        case 'completedTasks':
          query = query.where('status', isEqualTo: 'en revision');
          break;
        case 'overdueTasks':
          // No aplicamos filtro aquí, lo haremos después de obtener los datos
          break;
      }
    }

    final querySnapshot = await query.get();
    final now = DateTime.now();
    
    setState(() {
      tasks = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        // Cargar el nombre del proyecto
        _loadProjectName(data);
        return data;
      }).where((task) {
        if (widget.taskType == 'overdueTasks') {
          final dueDate = (task['dueDate'] as Timestamp).toDate();
          final daysUntilDue = dueDate.difference(now).inDays;
          return daysUntilDue < 2 && task['status'] != 'en revision';
        }
        return true;
      }).toList();
      isLoading = false;
    });
  }

  Future<void> _loadProjectName(Map<String, dynamic> task) async {
    if (task['projectId'] != null) {
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(task['projectId']).get();
      if (projectDoc.exists) {
        setState(() {
          task['projectName'] = projectDoc.data()?['title'] ?? 'Proyecto sin nombre';
        });
      }
    }
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
                // Botón de regreso y título
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
                      widget.title,
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

          // Lista de tareas
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    ),
                  )
                : tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No hay tareas para mostrar',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskCard(task);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final now = DateTime.now();
    final dueDate = (task['dueDate'] as Timestamp).toDate();
    final createdAt = (task['createdAt'] as Timestamp).toDate();
    final daysUntilDue = dueDate.difference(now).inDays;
    final isOverdue = daysUntilDue < 2 && task['status'] != 'en revision';
    final progressPercentage = now.difference(createdAt).inSeconds / dueDate.difference(createdAt).inSeconds;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue ? Colors.red[100]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOverdue 
                ? Colors.red.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Nuevo widget para el ícono del proyecto
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('projects')
                      .doc(task['projectId'])
                      .get(),
                  builder: (context, snapshot) {
                    Color projectColor = Colors.grey; // Color por defecto
                    if (snapshot.hasData && snapshot.data!.exists) {
                      // Convertir el código de color hexadecimal a Color
                      final colorString = snapshot.data!.get('color') as String;
                      projectColor = Color(int.parse(colorString.replaceAll('#', 'FF'), radix: 16));
                    }
                    
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: projectColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: projectColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.rocket_launch_rounded, // Ícono más moderno para proyectos
                        color: projectColor,
                        size: 24,
                      ),
                    );
                  },
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (task['projectName'] != null) ...[
                        SizedBox(height: 4),
                        Text(
                          task['projectName'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusDropdown(task),
              ],
            ),
            SizedBox(height: 16),
            LinearPercentIndicator(
              lineHeight: 8.0,
              percent: progressPercentage.clamp(0.0, 1.0),
              progressColor: _getColorForProgress(progressPercentage),
              backgroundColor: Colors.grey[100],
              padding: EdgeInsets.zero,
              barRadius: Radius.circular(4),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  Icons.calendar_today,
                  _formatDate(task['dueDate']),
                  isOverdue ? Colors.red : Colors.blue,
                ),
                _buildInfoChip(
                  Icons.folder_outlined,
                  task['projectName'] ?? 'Cargando...',
                  Colors.orange,
                  projectId: task['projectId'],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color, {String? projectId}) {
    final IconData displayIcon = icon == Icons.folder_outlined && projectId != null
        ? _getRandomProjectIcon(projectId)
        : icon;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            displayIcon, 
            size: 18,
            color: color,
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(Map<String, dynamic> task) {
    final List<Map<String, dynamic>> statusOptions = [
      {
        'value': 'por hacer',
        'icon': Icons.radio_button_unchecked,
        'label': 'Por hacer',
      },
      {
        'value': 'en proceso',
        'icon': Icons.engineering,
        'label': 'En proceso',
      },
      {
        'value': 'en revision',
        'icon': Icons.rate_review,
        'label': 'En revisión',
      },
      {
        'value': 'completada',
        'icon': Icons.task_alt,
        'label': 'Completada',
      },
    ];

    String currentStatus = task['status'];
    if (!statusOptions.any((status) => status['value'] == currentStatus)) {
      currentStatus = 'por hacer';
      _updateTaskStatus(task['id'], currentStatus);
    }

    return PopupMenuButton<String>(
      initialValue: currentStatus,
      onSelected: (String newValue) {
        setState(() {
          task['status'] = newValue;
        });
        _updateTaskStatus(task['id'], newValue);
      },
      offset: Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getColorForStatus(currentStatus).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getColorForStatus(currentStatus).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              statusOptions.firstWhere((status) => status['value'] == currentStatus)['icon'] as IconData,
              size: 18,
              color: _getColorForStatus(currentStatus),
            ),
            SizedBox(width: 8),
            Text(
              statusOptions.firstWhere((status) => status['value'] == currentStatus)['label'] as String,
              style: TextStyle(
                color: _getColorForStatus(currentStatus),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: _getColorForStatus(currentStatus),
              size: 20,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => statusOptions.map((status) => PopupMenuItem<String>(
        value: status['value'] as String,
        child: Row(
          children: [
            Icon(
              status['icon'] as IconData,
              color: _getColorForStatus(status['value'] as String),
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              status['label'] as String,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
        'status': newStatus,
      });
      print('Task status updated successfully: $taskId -> $newStatus');
      await _loadTasks(); // Recargar las tareas después de la actualización
    } catch (e) {
      print('Error updating task status: $e');
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'en proceso':
        return Colors.blue;
      case 'en revision':
        return Colors.orange;
      case 'completada':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getColorForProgress(double progress) {
    if (progress < 0.5) return Colors.green;
    if (progress < 0.75) return Colors.orange;
    return Colors.red;
  }
}
