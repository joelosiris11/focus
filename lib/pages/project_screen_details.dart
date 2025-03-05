import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:html' as html;
import 'main_dashboard.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../widgets/kanban_board_widget.dart';
import '../widgets/comments_widget.dart';

class ProjectScreenDetails extends StatefulWidget {
  final String projectId;

  const ProjectScreenDetails({Key? key, required this.projectId}) : super(key: key);

  @override
  _ProjectScreenDetailsState createState() => _ProjectScreenDetailsState();
}

class _ProjectScreenDetailsState extends State<ProjectScreenDetails> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<int> calculateTotalHours(String projectId) async {
    try {
      final QuerySnapshot taskSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('projectId', isEqualTo: projectId)
          .get();

      int totalHours = 0;
      for (var doc in taskSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalHours += (data['hours'] as num? ?? 0).toInt();
      }

      return totalHours;
    } catch (e) {
      print('Error calculando horas totales: $e');
      return 0;
    }
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

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completado':
        return Icons.check_circle_outline;
      case 'en progreso':
        return Icons.trending_up;
      case 'retrasado':
        return Icons.warning_outlined;
      case 'pausado':
        return Icons.pause_circle_outline;
      default:
        return Icons.trending_up;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No definida';
    if (timestamp is! Timestamp) return 'Fecha inválida';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF5F7FA),
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF263238)),
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Cargando proyecto...',
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final projectData = snapshot.data!.data() as Map<String, dynamic>?;
        if (projectData == null) {
          return const Center(
            child: Text('No se encontró el proyecto'),
          );
        }

        final projectName = projectData['title'] as String? ?? 'Proyecto sin nombre';
        final projectStatus = projectData['status'] as String? ?? 'EN PROGRESO';
        final projectDescription = projectData['description'] as String? ?? 'Sin descripción';
        final projectColor = projectData['color'] is int 
            ? Color(projectData['color'] as int)
            : _hexToColor(projectData['color'] as String? ?? '#1976D2');

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  projectName,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(projectStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(projectStatus),
                        color: _getStatusColor(projectStatus),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        projectStatus.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(projectStatus),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: FutureBuilder<int>(
                  future: calculateTotalHours(widget.projectId),
                  builder: (context, snapshot) {
                    final totalHours = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_rounded, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text(
                            '$totalHours horas',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: projectColor,
                      unselectedLabelColor: Colors.grey[500],
                      indicatorColor: projectColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.dashboard_rounded, size: 22),
                          text: 'Kanban',
                        ),
                        Tab(
                          icon: Icon(Icons.info_rounded, size: 22),
                          text: 'Detalles',
                        ),
                        Tab(
                          icon: Icon(Icons.chat_rounded, size: 22),
                          text: 'Conversación',
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_rounded,
                              color: _tabController.index > 0 ? projectColor : Colors.grey[300],
                              size: 20,
                            ),
                            onPressed: _tabController.index > 0
                                ? () {
                                    _tabController.animateTo(_tabController.index - 1);
                                    setState(() {});
                                  }
                                : null,
                            tooltip: 'Pestaña anterior',
                            splashRadius: 24,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              3,
                              (index) => Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _tabController.index == index
                                      ? projectColor
                                      : Colors.grey[300],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: _tabController.index < 2 ? projectColor : Colors.grey[300],
                              size: 20,
                            ),
                            onPressed: _tabController.index < 2
                                ? () {
                                    _tabController.animateTo(_tabController.index + 1);
                                    setState(() {});
                                  }
                                : null,
                            tooltip: 'Siguiente pestaña',
                            splashRadius: 24,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F7FA),
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      KanbanBoard(
                        projectId: widget.projectId,
                        projectColor: projectColor,
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCardContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(projectStatus).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(
                                            color: _getStatusColor(projectStatus).withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getStatusIcon(projectStatus),
                                              size: 18,
                                              color: _getStatusColor(projectStatus),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              projectStatus.toUpperCase(),
                                              style: TextStyle(
                                                color: _getStatusColor(projectStatus),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildStatusChangeButton(projectStatus),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                  const SizedBox(height: 24),
                                  
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDateCard(
                                          'Fecha de inicio',
                                          _formatDate(projectData['startDate']),
                                          Icons.calendar_today_outlined,
                                          const Color(0xFF4CAF50),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildDateCard(
                                          'Fecha límite',
                                          _formatDate(projectData['dueDate']),
                                          Icons.event_outlined,
                                          const Color(0xFFFFA726),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('tasks')
                                        .where('projectId', isEqualTo: widget.projectId)
                                        .snapshots(),
                                    builder: (context, taskSnapshot) {
                                      if (!taskSnapshot.hasData) {
                                        return const Center(
                                          child: LinearProgressIndicator(
                                            backgroundColor: Color(0xFFE0E0E0),
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                                          ),
                                        );
                                      }
                                      
                                      final tasks = taskSnapshot.data!.docs;
                                      final totalTasks = tasks.length;
                                      
                                      if (totalTasks == 0) {
                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                          ),
                                          child: Center(
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.assignment_outlined,
                                                  size: 36,
                                                  color: Colors.grey[300],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'No hay tareas en este proyecto',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      final completedTasks = tasks
                                          .where((task) => (task.data() as Map<String, dynamic>)['status'] == 'completada')
                                          .length;
                                      
                                      final inProcessTasks = tasks
                                          .where((task) => (task.data() as Map<String, dynamic>)['status'] == 'en proceso')
                                          .length;
                                      
                                      final pendingTasks = tasks
                                          .where((task) => (task.data() as Map<String, dynamic>)['status'] == 'por hacer')
                                          .length;
                                      
                                      final progressPercentage = totalTasks > 0
                                          ? (completedTasks / totalTasks * 100).round()
                                          : 0;
                                      
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Progreso del Proyecto',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              Text(
                                                '$progressPercentage%',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: progressPercentage > 66
                                                      ? const Color(0xFF4CAF50)
                                                      : progressPercentage > 33
                                                          ? const Color(0xFFFFA726)
                                                          : const Color(0xFFF44336),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: progressPercentage / 100,
                                              backgroundColor: Colors.grey[200],
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                progressPercentage > 66
                                                    ? const Color(0xFF4CAF50)
                                                    : progressPercentage > 33
                                                        ? const Color(0xFFFFA726)
                                                        : const Color(0xFFF44336),
                                              ),
                                              minHeight: 8,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              _buildTaskCountChip(
                                                '$pendingTasks',
                                                'Por hacer',
                                                Colors.grey[700]!,
                                              ),
                                              const SizedBox(width: 8),
                                              _buildTaskCountChip(
                                                '$inProcessTasks',
                                                'En proceso',
                                                Colors.blue,
                                              ),
                                              const SizedBox(width: 8),
                                              _buildTaskCountChip(
                                                '$completedTasks',
                                                'Completadas',
                                                Colors.green,
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            _buildCardContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: projectColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.description_outlined,
                                          color: projectColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Descripción del Proyecto',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Detalles y objetivo',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                    ),
                                    child: Text(
                                      projectDescription,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            _buildCardContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: projectColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.people_outline,
                                          color: projectColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Equipo del Proyecto',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Miembros y responsabilidades',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildTeamList(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            _buildCardContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: projectColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.folder_outlined,
                                              color: projectColor,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Archivos del Proyecto',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Documentos adjuntos',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _showUploadFileDialog(context),
                                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                                        label: const Text('Subir Archivo'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: projectColor,
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shadowColor: projectColor.withOpacity(0.4),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildFilesList(),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                      CommentsSection(projectId: widget.projectId),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildDateCard(String label, String date, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            date,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('projectId', isEqualTo: widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
            ),
          );
        }

        final tasks = snapshot.data!.docs;
        final userIds = tasks
            .map((task) => (task.data() as Map<String, dynamic>)['assignedTo'] as String?)
            .where((id) => id != null)
            .toSet();

        if (userIds.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.group_off_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay miembros asignados',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Asigna tareas a los miembros del equipo',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: userIds.toList())
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                ),
              );
            }

            final users = userSnapshot.data!.docs;
            
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userData = users[index].data() as Map<String, dynamic>;
                final userId = users[index].id;
                final userName = userData['displayName'] ?? userData['email'] ?? 'Usuario';
                final userEmail = userData['email'] ?? '';
                final userPhotoURL = userData['photoURL'];
                
                final userTasks = tasks.where((task) =>
                    (task.data() as Map<String, dynamic>)['assignedTo'] == userId).toList();
                
                // Contar tareas por estado
                final completedTasks = userTasks.where((task) =>
                    (task.data() as Map<String, dynamic>)['status'] == 'completada').length;
                
                final inProgressTasks = userTasks.where((task) =>
                    (task.data() as Map<String, dynamic>)['status'] == 'en proceso').length;
                
                final pendingTasks = userTasks.where((task) =>
                    (task.data() as Map<String, dynamic>)['status'] == 'por hacer').length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Foto o iniciales del usuario
                            userPhotoURL != null && userPhotoURL.isNotEmpty
                                ? CircleAvatar(
                                    radius: 24,
                                    backgroundImage: NetworkImage(userPhotoURL),
                                  )
                                : CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF1976D2).withOpacity(0.2),
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Color(0xFF1976D2),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                            const SizedBox(width: 16),
                            
                            // Información del usuario
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF263238),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userEmail,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Contador de tareas
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${userTasks.length} ${userTasks.length == 1 ? 'tarea' : 'tareas'}',
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Separador
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      
                      // Estadísticas de tareas
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTaskTypeChip(pendingTasks, 'Por hacer', Colors.grey[700]!),
                            _buildTaskTypeChip(inProgressTasks, 'En proceso', Colors.blue),
                            _buildTaskTypeChip(completedTasks, 'Completadas', Colors.green),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTaskTypeChip(int count, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('files')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
            ),
          );
        }

        final files = snapshot.data!.docs;
        if (files.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay archivos en este proyecto',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sube archivos para compartir con el equipo',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final fileData = files[index].data() as Map<String, dynamic>;
            return _buildFileCard(fileData, files[index].id);
          },
        );
      },
    );
  }

  Widget _buildFileCard(Map<String, dynamic> fileData, String fileId) {
    final fileName = fileData['name'] as String;
    final fileType = fileData['type'] as String?;
    final fileSize = fileData['size'] as int;
    final uploadDate = (fileData['uploadedAt'] as Timestamp).toDate();
    final uploaderId = fileData['uploadedBy'] as String;

    IconData iconData;
    Color iconColor;
    Color bgColor;
    
    switch (fileType?.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf_outlined;
        iconColor = const Color(0xFFF44336);
        bgColor = const Color(0xFFF44336).withOpacity(0.1);
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description_outlined;
        iconColor = const Color(0xFF2196F3);
        bgColor = const Color(0xFF2196F3).withOpacity(0.1);
        break;
      case 'xls':
      case 'xlsx':
        iconData = Icons.table_chart_outlined;
        iconColor = const Color(0xFF4CAF50);
        bgColor = const Color(0xFF4CAF50).withOpacity(0.1);
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconData = Icons.image_outlined;
        iconColor = const Color(0xFF9C27B0);
        bgColor = const Color(0xFF9C27B0).withOpacity(0.1);
        break;
      default:
        iconData = Icons.insert_drive_file_outlined;
        iconColor = const Color(0xFF607D8B);
        bgColor = const Color(0xFF607D8B).withOpacity(0.1);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _downloadFile(fileData['url'] as String, fileName),
            splashColor: bgColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícono del archivo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconData,
                      size: 36,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Nombre del archivo
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF263238),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  
                  // Tamaño del archivo
                  Text(
                    _formatFileSize(fileSize),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Fecha de subida
                  Text(
                    DateFormat('dd MMM yyyy').format(uploadDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download_rounded),
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
                          foregroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(0, 0),
                        ),
                        onPressed: () => _downloadFile(fileData['url'] as String, fileName),
                      ),
                      if (uploaderId == FirebaseAuth.instance.currentUser?.uid)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            iconSize: 20,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF44336).withOpacity(0.1),
                              foregroundColor: const Color(0xFFF44336),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(0, 0),
                            ),
                            onPressed: () => _showDeleteFileConfirmation(fileId, fileName),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteFileConfirmation(String fileId, String fileName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
            ),
            children: [
              const TextSpan(text: '¿Estás seguro de que quieres eliminar '),
              TextSpan(
                text: fileName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // Mostrar indicador de carga
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
          ),
        ),
      );

      final fileRef = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('files')
          .doc(fileId)
          .get();

      final fileData = fileRef.data();
      if (fileData != null) {
        final storageRef = FirebaseStorage.instance.refFromURL(fileData['url'] as String);
        await storageRef.delete();
      }

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('files')
          .doc(fileId)
          .delete();

      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('El archivo "$fileName" ha sido eliminado'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      print('Error al eliminar archivo: $e');
      if (!mounted) return;
      
      // Cerrar diálogo de carga si está abierto
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Error al eliminar el archivo: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _showUploadFileDialog(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('El archivo es demasiado grande. El tamaño máximo es 10MB'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFF44336),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
          ),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para subir archivos'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
        return;
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects/${widget.projectId}/files/${file.name}');

      late UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(
          file.bytes!,
          SettableMetadata(contentType: _getContentType(file.extension)),
        );
      } else {
        final filePath = file.path!;
        final fileIO = File(filePath);
        uploadTask = storageRef.putFile(fileIO);
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('files')
          .add({
        'name': file.name,
        'type': file.extension,
        'size': file.size,
        'url': downloadUrl,
        'uploadedBy': user.uid,
        'uploadedAt': Timestamp.now(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('El archivo "${file.name}" se ha subido correctamente'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      print('Error al subir archivo: $e');
      if (!mounted) return;
      
      // Cerrar diálogo de carga si está abierto
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Error al subir el archivo: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF44336),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      if (kIsWeb) {
        html.window.open(url, '_blank');
      } else {
        final response = await http.get(Uri.parse(url));
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      print('Error al descargar archivo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al descargar el archivo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Color _hexToColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Widget _buildTaskCountChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChangeButton(String currentStatus) {
    return PopupMenuButton<String>(
      tooltip: 'Cambiar estado',
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.edit_outlined,
          size: 18,
          color: Colors.grey[700],
        ),
      ),
      onSelected: (String newStatus) {
        _updateProjectStatus(newStatus);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'En progreso',
          child: Row(
            children: [
              Icon(Icons.trending_up, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text('En progreso'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'Completado',
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text('Completado'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'Pausado',
          child: Row(
            children: [
              Icon(Icons.pause_circle_outline, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Pausado'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'Retrasado',
          child: Row(
            children: [
              Icon(Icons.warning_outlined, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text('Retrasado'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _updateProjectStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'status': newStatus});

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado del proyecto actualizado a "$newStatus"'),
          backgroundColor: _getStatusColor(newStatus),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      print('Error al actualizar el estado del proyecto: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar el estado: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
} 