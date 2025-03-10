import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'project_screen_details.dart';
import 'package:intl/intl.dart';

class AllProjectsPage extends StatefulWidget {
  const AllProjectsPage({super.key});

  @override
  _AllProjectsPageState createState() => _AllProjectsPageState();
}

class _AllProjectsPageState extends State<AllProjectsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newCommentController = TextEditingController();
  String _searchQuery = '';
  String _currentFilter = 'Todos';
  final List<String> _statusFilters = ['Todos', 'En proceso', 'En riesgo', 'Atrasado', 'Completado'];

  @override
  void dispose() {
    _searchController.dispose();
    _newCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildSearchAndFilters(),
                      const SizedBox(height: 24),
                      _buildProjectsGrid(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
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
                  border: Border.all(color: Colors.grey.shade200),
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
                  Icons.dashboard_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Todos los Proyectos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E4B5F),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (currentUser != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
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
                        currentUser.email?.substring(0, 1).toUpperCase() ?? 'U',
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
                        currentUser.email?.split('@')[0] ?? 'Usuario',
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        final projectCount = snapshot.data?.docs.length ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚀 Panel de Proyectos',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$projectCount proyectos en total',
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

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Barra de búsqueda
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF78909C)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: 'Buscar proyectos...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Color(0xFF78909C)),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF78909C)),
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Filtros de estado
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statusFilters.map((filter) {
              final isSelected = _currentFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _currentFilter = filter),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF1E4B5F).withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF1E4B5F) : const Color(0xFF78909C),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF1E4B5F) : const Color(0xFFCFD8DC),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .orderBy('dueDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var projects = snapshot.data?.docs ?? [];

        // Aplicar filtros
        if (_currentFilter != 'Todos') {
          projects = projects.where((project) {
            final data = project.data() as Map<String, dynamic>;
            return _getStatusText(data['status']) == _currentFilter;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          projects = projects.where((project) {
            final data = project.data() as Map<String, dynamic>;
            return data['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (projects.isEmpty) {
          return _buildEmptyState();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.2,
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header del proyecto
              _buildProjectHeader(data),
              
              // Contenido principal
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progreso y fecha límite
                        Row(
                          children: [
                            Expanded(child: _buildProgressIndicator(projectId)),
                            const SizedBox(width: 16),
                            _buildDueDate(data['dueDate'] as Timestamp),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Estadísticas de tareas
                        _buildTaskStats(projectId),
                        const SizedBox(height: 20),
                        
                        // Sección de comentarios
                        _buildCommentsSection(projectId),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectHeader(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getProjectColor(data['status']).withOpacity(0.15),
            _getProjectColor(data['status']).withOpacity(0.05),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono del estado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getProjectColor(data['status']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getProjectIcon(data['status']),
                  color: _getProjectColor(data['status']),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Título y estado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? 'Sin título',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E4B5F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getProjectColor(data['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(data['status']),
                        style: TextStyle(
                          color: _getProjectColor(data['status']),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Información del propietario
          _buildOwnerInfo(data['ownerId']),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(String projectId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data!.docs;

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de comentarios
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.forum_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Discusión del proyecto',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Badge(
                      label: Text(
                        comments.length.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                  ],
                ),
              ),

              // Lista de comentarios
              if (comments.isEmpty)
                _buildEmptyComments()
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    reverse: true,
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final data = comment.data() as Map<String, dynamic>;
                      return _buildCommentItem(projectId, comment.id, data);
                    },
                  ),
                ),

              // Input de comentarios
              _buildCommentInput(projectId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(String projectId, String commentId, Map<String, dynamic> data) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == data['userId'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar del usuario
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(
              data['userName']?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Contenido del comentario
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del usuario y tiempo
                  Row(
                    children: [
                      Text(
                        data['userName'] ?? 'Usuario',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1E4B5F),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(data['createdAt'] as Timestamp),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      if (isOwner) ...[
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red[300],
                          onPressed: () => _showDeleteCommentDialog(
                            context,
                            projectId,
                            commentId,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Contenido
                  Text(
                    data['content'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(String projectId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _newCommentController,
              decoration: InputDecoration(
                hintText: 'Añade un comentario...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                final comment = _newCommentController.text.trim();
                if (comment.isNotEmpty) {
                  _addComment(projectId, comment);
                  _newCommentController.clear();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String projectId) {
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
                    color: Colors.grey[800],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getProgressColor(progress).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: _getProgressColor(progress),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 8,
                  width: MediaQuery.of(context).size.width * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getProgressColor(progress),
                        _getProgressColor(progress).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: _getProgressColor(progress).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDueDate(Timestamp dueDate) {
    final date = dueDate.toDate();
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    final isLate = difference < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLate ? Colors.red.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLate ? Colors.red.withOpacity(0.2) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLate ? Icons.warning_rounded : Icons.calendar_today_rounded,
            size: 14,
            color: isLate ? Colors.red : Colors.grey[700],
          ),
          const SizedBox(width: 6),
          Text(
            isLate ? 'Vencido' : 'Faltan $difference días',
            style: TextStyle(
              color: isLate ? Colors.red : Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStats(String projectId) {
    return StreamBuilder<QuerySnapshot>(
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

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBadge(
                tasksByStatus['por hacer'] ?? 0,
                'Por hacer',
                Colors.grey[700]!,
                Icons.assignment_outlined,
              ),
              _buildStatBadge(
                tasksByStatus['en proceso'] ?? 0,
                'En proceso',
                Colors.blue[600]!,
                Icons.trending_up_rounded,
              ),
              _buildStatBadge(
                tasksByStatus['completada'] ?? 0,
                'Completadas',
                Colors.green[600]!,
                Icons.check_circle_outline,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBadge(int count, String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyComments() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 24,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 8),
          Text(
            'Sin comentarios aún',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
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
              Icons.search_off_rounded,
              size: 48,
              color: Colors.blue[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No se encontraron proyectos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No hay resultados para "$_searchQuery"'
                : _currentFilter != 'Todos'
                    ? 'No hay proyectos con estado "$_currentFilter"'
                    : 'Aún no se han creado proyectos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      final formatter = DateFormat('dd/MM/yy');
      return formatter.format(date);
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green;
    if (progress >= 0.5) return Colors.blue;
    if (progress >= 0.3) return Colors.orange;
    return Colors.red;
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

  Widget _buildOwnerInfo(String? ownerId) {
    if (ownerId == null) return const SizedBox();
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
      builder: (context, snapshot) {
        String displayName = 'Cargando...';
        if (snapshot.hasData) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          displayName = userData?['displayName'] ?? 
                       userData?['email']?.toString().split('@')[0] ?? 
                       'Usuario';
        }
        return Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 12,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              displayName,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteCommentDialog(BuildContext context, String projectId, String commentId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '¿Eliminar comentario?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E4B5F),
          ),
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este comentario? Esta acción no se puede deshacer.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF455A64),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteComment(projectId, commentId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addComment(String projectId, String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('comments')
          .add({
            'content': comment,
            'userId': user.uid,
            'userName': user.displayName ?? user.email?.split('@')[0] ?? 'Usuario',
            'createdAt': Timestamp.now(),
          });
      
      _newCommentController.clear();
    } catch (e) {
      print('Error al guardar comentario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el comentario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(String projectId, String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      print('Error al eliminar comentario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar el comentario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 