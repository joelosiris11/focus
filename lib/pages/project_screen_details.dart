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
          return const Center(child: CircularProgressIndicator());
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
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: Colors.grey[800],
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              projectName,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: projectColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        projectStatus.toUpperCase(),
                        style: TextStyle(
                          color: projectColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FutureBuilder<int>(
                      future: calculateTotalHours(widget.projectId),
                      builder: (context, snapshot) {
                        final totalHours = snapshot.data ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.timer_rounded, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '$totalHours horas',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: projectColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: projectColor,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.dashboard_rounded),
                      text: 'Kanban',
                    ),
                    Tab(
                      icon: Icon(Icons.info_rounded),
                      text: 'Detalles',
                    ),
                    Tab(
                      icon: Icon(Icons.chat_rounded),
                      text: 'Conversación',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Kanban Tab
                      KanbanBoard(
                        projectId: widget.projectId,
                        projectColor: projectColor,
                      ),
                      // Detalles Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade50, Colors.white],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
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
                                            color: _getStatusColor(projectStatus).withOpacity(0.5),
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
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDateCard(
                                          'Fecha de inicio',
                                          _formatDate(projectData['startDate']),
                                          Icons.calendar_today_outlined,
                                          Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildDateCard(
                                          'Fecha límite',
                                          _formatDate(projectData['dueDate']),
                                          Icons.event_outlined,
                                          Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.description_outlined, color: projectColor),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Descripción del Proyecto',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    projectDescription,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.group_outlined, color: projectColor),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Equipo del Proyecto',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildTeamList(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.folder_outlined, color: projectColor),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Archivos del Proyecto',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _showUploadFileDialog(context),
                                        icon: const Icon(Icons.upload_file, size: 20),
                                        label: const Text('Subir Archivo'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: projectColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
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
                          ],
                        ),
                      ),
                      // Conversación Tab
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
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data!.docs;
        final userIds = tasks
            .map((task) => (task.data() as Map<String, dynamic>)['assignedTo'] as String?)
            .where((id) => id != null)
            .toSet();

        if (userIds.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.group_off_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No hay miembros asignados',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: userIds.length,
          itemBuilder: (context, index) {
            final userId = userIds.elementAt(index);
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final userName = userData['displayName'] ?? userData['email'] ?? 'Usuario';
                final userTasks = tasks.where((task) =>
                    (task.data() as Map<String, dynamic>)['assignedTo'] == userId).toList();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          userName[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              userData['email'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${userTasks.length} ${userTasks.length == 1 ? 'tarea' : 'tareas'}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
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
          return const Center(child: CircularProgressIndicator());
        }

        final files = snapshot.data!.docs;
        if (files.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No hay archivos en este proyecto',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
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
        iconColor = Colors.red[400]!;
        bgColor = Colors.red[50]!;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description_outlined;
        iconColor = Colors.blue[400]!;
        bgColor = Colors.blue[50]!;
        break;
      case 'xls':
      case 'xlsx':
        iconData = Icons.table_chart_outlined;
        iconColor = Colors.green[400]!;
        bgColor = Colors.green[50]!;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconData = Icons.image_outlined;
        iconColor = Colors.purple[400]!;
        bgColor = Colors.purple[50]!;
        break;
      default:
        iconData = Icons.insert_drive_file_outlined;
        iconColor = Colors.grey[400]!;
        bgColor = Colors.grey[50]!;
    }

    return InkWell(
      onTap: () => _downloadFile(fileData['url'] as String, fileName),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconData,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              fileName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _formatFileSize(fileSize),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uploaderId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final uploaderName = userData['displayName'] ?? userData['email'] ?? 'Usuario';

                return Column(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(uploadDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download_rounded),
                          iconSize: 20,
                          padding: const EdgeInsets.all(8),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                          ),
                          onPressed: () => _downloadFile(fileData['url'] as String, fileName),
                        ),
                        if (uploaderId == FirebaseAuth.instance.currentUser?.uid)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              iconSize: 20,
                              padding: const EdgeInsets.all(8),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                              ),
                              onPressed: () => _showDeleteFileConfirmation(fileId, fileName),
                            ),
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
    );
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
          const SnackBar(
            content: Text('El archivo es demasiado grande. El tamaño máximo es 10MB'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión para subir archivos')),
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
        const SnackBar(
          content: Text('Archivo subido correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al subir archivo: $e');
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir el archivo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteFileConfirmation(String fileId, String fileName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text('¿Estás seguro de que quieres eliminar "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archivo eliminado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al eliminar archivo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al eliminar el archivo'),
          backgroundColor: Colors.red,
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
} 