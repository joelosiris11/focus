import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';

class ProjectDetailsPage extends StatefulWidget {
  final User user;
  final String projectId;
  final String projectTitle;

  const ProjectDetailsPage({
    Key? key,
    required this.user,
    required this.projectId,
    required this.projectTitle,
  }) : super(key: key);

  @override
  _ProjectDetailsPageState createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  late Future<Map<String, dynamic>> _projectDetailsFuture;
  late Future<List<Map<String, dynamic>>> _projectTasksFuture;

  @override
  void initState() {
    super.initState();
    _projectDetailsFuture = _loadProjectDetails();
    _projectTasksFuture = _loadProjectTasks();
  }

  Future<Map<String, dynamic>> _loadProjectDetails() async {
    final projectDoc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .get();

    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final projectData = projectDoc.data()!;

    // Cargar las tareas del proyecto
    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .where('projectId', isEqualTo: widget.projectId)
        .get();

    final tasks = tasksSnapshot.docs.map((doc) => doc.data()).toList();

    // Calcular el progreso basado en las tareas
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((task) => task['status'] == 'completada').length;
    final inReviewTasks = tasks.where((task) => task['status'] == 'en revision').length;
    final inProgressTasks = tasks.where((task) => task['status'] == 'en proceso').length;

    final progress = totalTasks > 0
        ? ((completedTasks * 1.0 + inReviewTasks * 0.9 + inProgressTasks * 0.5) / totalTasks) * 100
        : 0.0;

    projectData['calculatedProgress'] = progress;
    projectData['tasks'] = tasks;

    // Calcular el tiempo transcurrido y restante
    final now = DateTime.now();
    final createdAt = (projectData['createdAt'] as Timestamp).toDate();
    final dueDate = (projectData['dueDate'] as Timestamp).toDate();
    final totalDuration = dueDate.difference(createdAt);
    final elapsedDuration = now.difference(createdAt);
    final timeProgress = totalDuration.inSeconds > 0 
        ? (elapsedDuration.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0) 
        : 1.0;

    // Determinar el nuevo estado del proyecto
    String newStatus = _determineProjectStatus(progress.toDouble(), timeProgress.toDouble(), dueDate);

    // Actualizar el estado del proyecto si ha cambiado
    if (newStatus != projectData['status']) {
      await _updateProjectStatus(newStatus);
      projectData['status'] = newStatus;
    }

    return projectData;
  }

  String _determineProjectStatus(double progress, double timeProgress, DateTime dueDate) {
    final now = DateTime.now();
    final daysUntilDue = dueDate.difference(now).inDays;

    if (progress >= 100) {
      return 'Completado';
    } else if (daysUntilDue < 0) {
      return 'Atrasado';
    } else if (timeProgress > 0.75 && progress < 50) {
      return 'En riesgo';
    } else if (timeProgress > progress / 100 + 0.1) {
      return 'Retrasado';
    } else if (daysUntilDue <= 7 && progress < 90) {
      return 'Urgente';
    } else if (progress > 0 && progress < 100) {
      return 'En progreso';
    } else {
      return 'Planificación';
    }
  }

  Future<void> _updateProjectStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .update({'status': newStatus});
  }

  Future<List<Map<String, dynamic>>> _loadProjectTasks() async {
    final tasksQuery = await FirebaseFirestore.instance
        .collection('tasks')
        .where('projectId', isEqualTo: widget.projectId)
        .get();
    
    List<Map<String, dynamic>> tasks = [];
    for (var doc in tasksQuery.docs) {
      Map<String, dynamic> task = doc.data();
      task['id'] = doc.id;
      
      if (task['assignedTo'] != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(task['assignedTo'])
            .get();
        task['assignedToName'] = userDoc['displayName'] ?? 'Usuario desconocido';
      } else {
        task['assignedToName'] = 'No asignado';
      }
      
      tasks.add(task);
    }
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, true);
          return false;
        },
        child: Column(
          children: [
            // Header con gradiente mejorado
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    'Detalles del Proyecto',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildProjectMenu(),
                ],
              ),
            ),

            // Contenido principal
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, dynamic>>(
                      future: _projectDetailsFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return CircularProgressIndicator();
                        final projectDetails = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProjectDetails(projectDetails),
                            SizedBox(height: 24),
                            _buildProgressBar(projectDetails),
                            SizedBox(height: 24),
                            _buildWarningCard(projectDetails),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tareas del Proyecto',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        IconButton(
                          onPressed: _showAddTaskDialog,
                          icon: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildTasksList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDetails(Map<String, dynamic> projectDetails) {
    return Container(
      padding: EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectDetails['title'] ?? 'Sin título',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            projectDetails['description'] ?? 'Sin descripción',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(
                Icons.flag_rounded,
                projectDetails['status'] ?? 'Sin estado',
                _getStatusColor(projectDetails['status'] ?? ''),
              ),
              _buildInfoChip(
                Icons.calendar_today_rounded,
                _formatDate(projectDetails['dueDate']),
                Colors.blue[700]!,
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildProgressIndicator(projectDetails),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
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
            label,
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

  Widget _buildProgressIndicator(Map<String, dynamic> projectDetails) {
    final progress = projectDetails['calculatedProgress'] as double;
    final progressPercentage = (progress / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progreso',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${progress.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getProgressColor(progress),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 8.0,
          percent: progressPercentage,
          barRadius: Radius.circular(4),
          progressColor: _getProgressColor(progress),
          backgroundColor: Colors.grey[200],
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final dueDate = (task['dueDate'] as Timestamp).toDate();
    final isOverdue = dueDate.isBefore(DateTime.now());
    final status = task['status'] as String;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showTaskDetails(task),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildStatusIndicator(status),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title'] ?? 'Tarea sin título',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Vence: ${_formatDate(task['dueDate'])}',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                radius: 16,
                child: Text(
                  _getInitials(task['assignedToName']),
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'en proceso':
        color = Colors.blue;
        break;
      case 'completada':
        color = Colors.green;
        break;
      case 'en revision':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Colors.blue;
      case 'planning':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
      setState(() {
        _projectTasksFuture = _loadProjectTasks();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarea eliminada con éxito')),
      );
    } catch (e) {
      print('Error deleting task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la tarea')),
      );
    }
  }

  Future<void> _deleteProject() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Obtener el documento del proyecto
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (projectDoc.exists) {
        // Obtener la lista de miembros del proyecto
        final List<String> members = List<String>.from(projectDoc.data()?['members'] ?? []);

        // Eliminar el proyecto de userProjects para todos los miembros
        for (String userId in members) {
          final userProjectRef = FirebaseFirestore.instance
              .collection('userProjects')
              .doc(userId);
          batch.update(userProjectRef, {
            'projects': FieldValue.arrayRemove([widget.projectId])
          });
        }

        // Obtener y eliminar todas las tareas del proyecto
        final tasksQuery = await FirebaseFirestore.instance
            .collection('tasks')
            .where('projectId', isEqualTo: widget.projectId)
            .get();
        
        for (var doc in tasksQuery.docs) {
          // Eliminar la tarea
          batch.delete(doc.reference);
          
          // Eliminar la referencia de la tarea en userTasks
          final assignedTo = doc.data()['assignedTo'];
          if (assignedTo != null) {
            final userTaskRef = FirebaseFirestore.instance
                .collection('userTasks')
                .doc(assignedTo);
            batch.update(userTaskRef, {
              'tasks': FieldValue.arrayRemove([doc.id])
            });

            // Actualizar taskSummaries
            final taskSummaryRef = FirebaseFirestore.instance
                .collection('taskSummaries')
                .doc(assignedTo);
            batch.update(taskSummaryRef, {
              'totalTasks': FieldValue.increment(-1),
              'pendingTasks': FieldValue.increment(-1),
            });
          }
        }

        // Eliminar el proyecto
        batch.delete(projectDoc.reference);

        // Ejecutar todas las operaciones en batch
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proyecto eliminado con éxito')),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error deleting project: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el proyecto')),
      );
    }
  }

  void _showTaskDetails(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: contentBox(context, task),
        );
      },
    );
  }

  Widget contentBox(BuildContext context, Map<String, dynamic> task) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            offset: Offset(0, 10),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            task['title'] ?? 'Tarea sin título',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 15),
          Text(
            task['description'] ?? 'Sin descripción',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 22),
          _buildTaskInfoRow(
            'Estado',
            task['status'] ?? 'Desconocido',
            _getColorForStatus(task['status'] ?? ''),
          ),
          SizedBox(height: 8),
          _buildTaskInfoRow(
            'Fecha de finalización',
            _formatDate(task['dueDate']),
            Colors.blue,
          ),
          SizedBox(height: 8),
          _buildTaskInfoRow(
            'Asignado a',
            task['assignedToName'],
            Colors.purple,
          ),
          SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () async {
                  await _deleteTask(task['id']);
                  Navigator.of(context).pop();
                },
                child: Text('Borrar', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cerrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String taskName = '';
        String priority = 'Media';
        String assignedTo = '';
        String assignedToName = '';
        DateTime dueDate = DateTime.now().add(Duration(days: 1));
        String description = '';

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agregar Nueva Tarea',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Nombre de la Tarea',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          taskName = value;
                        });
                      },
                    ),
                    SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: InputDecoration(
                        labelText: 'Prioridad',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
                        ),
                      ),
                      items: ['Baja', 'Media', 'Alta'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => priority = value!),
                    ),
                    SizedBox(height: 15),
                    ElevatedButton(
                      child: Text(
                        'Seleccionar Usuario',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final selectedUser = await _showUserSelectionDialog(context);
                        if (selectedUser != null) {
                          setState(() {
                            assignedTo = selectedUser['uid'];
                            assignedToName = selectedUser['displayName'] ?? 'Usuario sin nombre';
                          });
                        }
                      },
                    ),
                    if (assignedTo.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                _getInitials(assignedToName),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(assignedToName),
                          ],
                        ),
                      ),
                    SizedBox(height: 15),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null && picked != dueDate) {
                          setState(() => dueDate = picked);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd/MM/yyyy').format(dueDate),
                              style: TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
                        ),
                      ),
                      maxLines: 3,
                      onChanged: (value) => description = value,
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Cancelar'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (taskName.isNotEmpty && assignedTo.isNotEmpty) {
                              _addTaskToProject(taskName, priority, assignedTo, assignedToName, dueDate, description);
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(
                            'Guardar',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addTaskToProject(String name, String priority, String assignedTo, String assignedToName, DateTime dueDate, String description) async {
    try {
      // Crear la nueva tarea en Firestore
      final taskRef = await FirebaseFirestore.instance.collection('tasks').add({
        'title': name,
        'status': 'pending',
        'description': description,
        'dueDate': Timestamp.fromDate(dueDate),
        'assignedTo': assignedTo,
        'projectId': widget.projectId,
        'priority': priority,
        'createdAt': Timestamp.now(), // Añadimos el campo createdAt
      });

      // Actualizar userTasks para el usuario asignado
      await FirebaseFirestore.instance.collection('userTasks').doc(assignedTo).set({
        'tasks': FieldValue.arrayUnion([taskRef.id]),
      }, SetOptions(merge: true));

      // Actualizar userProjects para el usuario asignado
      await FirebaseFirestore.instance.collection('userProjects').doc(assignedTo).set({
        'projects': FieldValue.arrayUnion([widget.projectId]),
      }, SetOptions(merge: true));

      // Actualizar taskSummaries
      final batch = FirebaseFirestore.instance.batch();
      final taskSummaryRef = FirebaseFirestore.instance.collection('taskSummaries').doc(assignedTo);
      batch.set(taskSummaryRef, {
        'totalTasks': FieldValue.increment(1),
        'pendingTasks': FieldValue.increment(1),
        'assignedTasks': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await batch.commit();

      // Actualizar la interfaz de usuario
      setState(() {
        _projectTasksFuture = _loadProjectTasks();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarea agregada con éxito')),
      );
    } catch (e) {
      print('Error al agregar la tarea: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar la tarea')),
      );
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    List<String> nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts[0].isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
    return '';
  }

  Future<Map<String, dynamic>?> _showUserSelectionDialog(BuildContext context) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .get(),
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                title: Text('Cargando usuarios...'),
                content: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return AlertDialog(
                title: Text('Error'),
                content: Text('Ocurrió un error al cargar los usuarios.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cerrar'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return AlertDialog(
                title: Text('No hay usuarios'),
                content: Text('No se encontraron usuarios.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cerrar'),
                  ),
                ],
              );
            }

            final users = snapshot.data!.docs
                .map((doc) => {'uid': doc.id, ...doc.data() as Map<String, dynamic>})
                .toList(); // Removimos el filtro para incluir todos los usuarios

            return AlertDialog(
              title: Text('Seleccionar Usuario'),
              content: Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (BuildContext context, int index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(_getInitials(user['displayName'] ?? '')),
                      ),
                      title: Text(user['displayName'] ?? 'Usuario sin nombre'),
                      subtitle: Text(user['email'] ?? ''),
                      onTap: () => Navigator.of(context).pop(user),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProgressBar(Map<String, dynamic> projectDetails) {
    final progress = projectDetails['calculatedProgress'] as double;
    final progressPercentage = (progress / 100).clamp(0.0, 1.0);

    final dueDate = (projectDetails['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final createdAt = (projectDetails['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final now = DateTime.now();
    
    final totalDuration = dueDate.difference(createdAt);
    final elapsedDuration = now.difference(createdAt);
    
    final timeProgress = totalDuration.inSeconds > 0 
        ? (elapsedDuration.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0) 
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progreso del Proyecto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 20.0,
          percent: progressPercentage,
          center: Text("${progress.toStringAsFixed(1)}%"),
          progressColor: Colors.blue,
          backgroundColor: Colors.blue.shade100,
        ),
        SizedBox(height: 8),
        Text(
          'Tiempo Transcurrido',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 20.0,
          percent: timeProgress,
          center: Text("${(timeProgress * 100).toStringAsFixed(1)}%"),
          progressColor: Colors.orange,
          backgroundColor: Colors.orange.shade100,
        ),
      ],
    );
  }

  Widget _buildWarningCard(Map<String, dynamic> projectDetails) {
    final progress = projectDetails['calculatedProgress'] as double;
    final progressPercentage = (progress / 100).clamp(0.0, 1.0);
    final dueDate = (projectDetails['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final createdAt = (projectDetails['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final now = DateTime.now();
    
    final totalDuration = dueDate.difference(createdAt);
    final elapsedDuration = now.difference(createdAt);
    
    final timeProgress = totalDuration.inSeconds > 0 
        ? (elapsedDuration.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0) 
        : 1.0;

    String warningMessage = '';
    IconData warningIcon = Icons.info_outline;

    if (timeProgress > progressPercentage + 0.1) {
      warningMessage = 'El proyecto está atrasado en relación al tiempo transcurrido.';
      warningIcon = Icons.warning_amber_rounded;
    } else if (dueDate.difference(now).inDays < 7 && progressPercentage < 0.9) {
      warningMessage = 'Quedan menos de 7 días y el proyecto no está cerca de completarse.';
      warningIcon = Icons.access_time;
    } else if (progressPercentage < 0.5 && timeProgress > 0.75) {
      warningMessage = 'El proyecto ha avanzado menos del 50% y queda poco tiempo.';
      warningIcon = Icons.trending_down;
    }

    if (warningMessage.isEmpty) {
      return SizedBox.shrink(); // Devuelve un widget vacío si no hay advertencia
    }

    return Card(
      color: Colors.red[700],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(warningIcon, color: Colors.white),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                warningMessage,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTasksList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _projectTasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  'No hay tareas asignadas',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) => _buildTaskCard(snapshot.data![index]),
        );
      },
    );
  }

  // Añadir este método para el color del progreso
  Color _getProgressColor(double progress) {
    if (progress >= 75) return Colors.green;
    if (progress >= 50) return Colors.orange;
    if (progress >= 25) return Colors.amber;
    return Colors.red;
  }

  // Añadir este método para el color del estado
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completado':
        return Colors.green;
      case 'en progreso':
        return Colors.blue;
      case 'en riesgo':
        return Colors.orange;
      case 'atrasado':
        return Colors.red;
      case 'urgente':
        return Colors.deepOrange;
      case 'planificación':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProjectMenu() {
    return PopupMenuButton<String>(
      icon: Container(
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
          Icons.more_vert,
          color: Colors.white,
          size: 20,
        ),
      ),
      offset: Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'archive',
          child: Row(
            children: [
              Icon(Icons.archive_outlined, color: Colors.blue),
              SizedBox(width: 12),
              Text('Archivar proyecto'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 12),
              Text('Eliminar proyecto'),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'archive':
            _showArchiveConfirmationDialog();
            break;
          case 'delete':
            _showDeleteConfirmationDialog();
            break;
        }
      },
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Eliminar Proyecto'),
          content: Text('¿Estás seguro de que deseas eliminar este proyecto? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteProject();
              },
              child: Text('Eliminar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showArchiveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Archivar Proyecto'),
          content: Text('¿Estás seguro de que deseas archivar este proyecto?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _archiveProject();
              },
              child: Text('Archivar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _archiveProject() async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'status': 'archived',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proyecto archivado con éxito')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('Error archiving project: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al archivar el proyecto')),
      );
    }
  }
}
