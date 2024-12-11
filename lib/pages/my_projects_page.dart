import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'project_screen_details.dart';

class MyProjectsPage extends StatelessWidget {
  final User user;

  const MyProjectsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // Color de fondo más suave
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildProjectsGrid(), // Cambiamos a grid en lugar de lista
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: Color(0xFF1E4B5F),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_special_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Proyectos Asignados',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E4B5F),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      user.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.email?.split('@')[0] ?? 'Usuario',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1E4B5F),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'En línea',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, taskSnapshot) {
        if (taskSnapshot.hasError) {
          return Center(child: Text('Error: ${taskSnapshot.error}'));
        }

        if (taskSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final projectIds = taskSnapshot.data?.docs
            .map((task) => (task.data() as Map<String, dynamic>)['projectId'] as String)
            .toSet()
            .toList() ?? [];

        if (projectIds.isEmpty) {
          return _buildEmptyState();
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where(FieldPath.documentId, whereIn: projectIds)
              .snapshots(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.hasError) {
              return Center(child: Text('Error: ${projectSnapshot.error}'));
            }

            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final projects = projectSnapshot.data?.docs ?? [];

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final data = project.data() as Map<String, dynamic>;
                return _buildProjectCard(context, project.id, data);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 48,
              color: Colors.blue[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Sin tareas asignadas! 🎉',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cuando te asignen tareas en un proyecto,\naparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, String projectId, Map<String, dynamic> data) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectScreenDetails(projectId: projectId),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con título y estado
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getProjectColor(data['status']).withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['title'] ?? 'Sin título',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getProjectColor(data['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getProjectIcon(data['status']),
                            size: 12,
                            color: _getProjectColor(data['status']),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(data['status']),
                            style: TextStyle(
                              color: _getProjectColor(data['status']),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Contenido
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Estado de tareas
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('tasks')
                            .where('projectId', isEqualTo: projectId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();

                          final tasks = snapshot.data!.docs;
                          final tasksByStatus = {
                            'por hacer': 0,
                            'en proceso': 0,
                            'en revision': 0,
                            'completada': 0,
                          };

                          for (var task in tasks) {
                            final status = (task.data() as Map<String, dynamic>)['status'] as String;
                            tasksByStatus[status] = (tasksByStatus[status] ?? 0) + 1;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estado de tareas',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildTaskCounter(
                                          '📋',
                                          tasksByStatus['por hacer'] ?? 0,
                                          Colors.grey,
                                          'Por hacer',
                                        ),
                                        const SizedBox(height: 6),
                                        _buildTaskCounter(
                                          '⚡',
                                          tasksByStatus['en proceso'] ?? 0,
                                          Colors.blue,
                                          'En proceso',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildTaskCounter(
                                          '👀',
                                          tasksByStatus['en revision'] ?? 0,
                                          Colors.orange,
                                          'En revisión',
                                        ),
                                        const SizedBox(height: 6),
                                        _buildTaskCounter(
                                          '✅',
                                          tasksByStatus['completada'] ?? 0,
                                          Colors.green,
                                          'Completadas',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Barra de progreso y fecha
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCompactProgressIndicator(projectId),
                          const SizedBox(height: 8),
                          _buildCompactDueDate(data['dueDate'] as Timestamp),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCounter(String emoji, int count, Color color, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $count',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final tasks = snapshot.data?.docs ?? [];
        final projectIds = tasks
            .map((task) => (task.data() as Map<String, dynamic>)['projectId'] as String)
            .toSet();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✨ Mis Proyectos',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${projectIds.length} proyectos con tareas asignadas',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactProgressIndicator(String projectId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('projectId', isEqualTo: projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final tasks = snapshot.data!.docs;
        final totalTasks = tasks.length;
        final completedTasks = tasks.where((task) {
          final data = task.data() as Map<String, dynamic>;
          return data['status'] == 'completada';
        }).length;

        final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[300]!, Colors.blue],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactDueDate(Timestamp dueDate) {
    final date = dueDate.toDate();
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    final isLate = difference < 0;

    return Row(
      children: [
        Icon(
          isLate ? Icons.warning_rounded : Icons.calendar_today_rounded,
          size: 12,
          color: isLate ? Colors.red : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          isLate ? 'Vencido' : 'Vence en $difference días',
          style: TextStyle(
            color: isLate ? Colors.red : Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'completado':
        return 'Completado';
      case 'en riesgo':
        return 'En riesgo';
      case 'atrasado':
        return 'Atrasado';
      default:
        return 'En proceso';
    }
  }

  Color _getProjectColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completado':
        return Colors.green;
      case 'en riesgo':
        return Colors.orange;
      case 'atrasado':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getProjectIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completado':
        return Icons.check_circle_outline;
      case 'en riesgo':
        return Icons.warning_amber_rounded;
      case 'atrasado':
        return Icons.error_outline;
      default:
        return Icons.play_circle_outline;
    }
  }
} 