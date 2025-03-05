import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'project_screen_details.dart';
import 'project_creation_page.dart';
import 'dart:math' show pi;
import 'package:rxdart/rxdart.dart';
import 'configuration_page.dart';
import 'activities_page.dart';
import 'my_projects_page.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart' as ui;
import 'package:flutter/rendering.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  _MainDashboardState createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      // Forzar una actualización de los datos
      await FirebaseFirestore.instance
          .collection('projects')
          .get();
      
      if (mounted) {
        setState(() {
          // Esto forzará que los StreamBuilder se reconstruyan
        });
      }
    } catch (e) {
      print('Error al cargar los datos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Return false to prevent the back gesture
        return false;
      },
      child: Scaffold(
        body: Row(
          children: [
            const NavigationSidebar(),
            Expanded(
              child: Container(
                height: MediaQuery.of(context).size.height,
                child: SingleChildScrollView(
                  // Disable bounce physics that could trigger navigation gestures
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardHeader(),
                        const SizedBox(height: 24),
                        StatusCardsRow(),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 620, // Altura fija para la fila
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: ProjectsList(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: ProjectStatistics(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 500, // Volvemos a usar altura fija para esta sección
                          child: ProjectsOverviewTable(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Panel de Proyectos',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
   
          ],
        ),
      ],
    );
  }
}

class StatusCardsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        
        // Calcular estadísticas
        int onTrack = 0;
        int atRisk = 0;
        int late = 0;
        int notStarted = 0;
        int lastWeekTotal = 0;

        for (var project in projects) {
          final data = project.data() as Map<String, dynamic>;
          final dueDate = (data['dueDate'] as Timestamp).toDate();
          final startDate = (data['startDate'] as Timestamp?)?.toDate() ?? now;
          final totalDuration = dueDate.difference(startDate).inDays;
          final remainingDays = dueDate.difference(now).inDays;
          
          // Calcular el progreso esperado vs real
          final expectedProgress = 1 - (remainingDays / totalDuration);
          final actualProgress = _calculateProgress(data);
          
          // Verificar si el proyecto se creó en la última semana
          if (now.difference(startDate).inDays <= 7) {
            lastWeekTotal++;
          }

          if (data['status'] == 'not_started') {
            notStarted++;
          } else if (remainingDays < 0) {
            late++;
          } else if (actualProgress < expectedProgress - 0.2) {
            // Si está más del 20% por debajo del progreso esperado
            atRisk++;
          } else {
            onTrack++;
          }
        }

        // Calcular porcentajes de cambio semanal
        final weeklyChange = projects.isEmpty ? 0 : (lastWeekTotal / projects.length) * 100;

        return Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'En Curso',
                onTrack.toString(),
                'Proyectos',
                Colors.green,
                '+${weeklyChange.toStringAsFixed(0)}%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                'En Riesgo',
                atRisk.toString(),
                'Proyectos',
                Colors.orange,
                '${atRisk > 0 ? "+" : ""}${((atRisk / (projects.length == 0 ? 1 : projects.length)) * 100).toStringAsFixed(0)}%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                'Atrasados',
                late.toString(),
                'Proyectos',
                Colors.red,
                '${late > 0 ? "+" : ""}${((late / (projects.length == 0 ? 1 : projects.length)) * 100).toStringAsFixed(0)}%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                'Sin Iniciar',
                notStarted.toString(),
                'Proyectos',
                Colors.grey,
                '${notStarted > 0 ? "+" : ""}${((notStarted / (projects.length == 0 ? 1 : projects.length)) * 100).toStringAsFixed(0)}%',
              ),
            ),
          ],
        );
      },
    );
  }

  double _calculateProgress(Map<String, dynamic> projectData) {
    final totalTasks = projectData['totalTasks'] ?? 0;
    final completedTasks = projectData['completedTasks'] ?? 0;
    if (totalTasks == 0) return 0.0;
    return completedTasks / totalTasks;
  }

  Widget _buildStatusCard(
    String title,
    String number,
    String subtitle,
    Color color,
    String percentage,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  title == 'En Curso' ? Icons.play_circle_outline :
                  title == 'En Riesgo' ? Icons.warning_amber_rounded :
                  title == 'Atrasados' ? Icons.error_outline :
                  Icons.hourglass_empty_outlined,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            number,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  percentage.contains('+') ? Icons.trending_up : Icons.trending_down,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  'Esta semana $percentage',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectsList extends StatefulWidget {
  @override
  _ProjectsListState createState() => _ProjectsListState();
}

class _ProjectsListState extends State<ProjectsList> {
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
          ));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var projects = snapshot.data?.docs ?? [];
        
        // Filtrar proyectos basados en la búsqueda
        if (_searchQuery.isNotEmpty) {
          projects = projects.where((project) {
            final data = project.data() as Map<String, dynamic>;
            final title = (data['title'] ?? '').toString().toLowerCase();
            return title.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado de la lista
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D32).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.folder_special_rounded,
                          color: Color(0xFF2E7D32),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lista de Proyectos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF263238),
                            ),
                          ),
                          Text(
                            '${projects.length} proyectos',
                            style: const TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: const Color(0xFF546E7A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Buscar...',
                              hintStyle: TextStyle(
                                color: Color(0xFF90A4AE),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF455A64),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                            child: Icon(Icons.close, color: const Color(0xFF546E7A), size: 16),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Lista de proyectos - ahora con Flexible en lugar de Expanded
              Flexible(
                child: projects.isEmpty 
                  ? _buildEmptyState()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final data = project.data() as Map<String, dynamic>;
                        return _buildProjectCard(context, project, data);
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectCard(BuildContext context, QueryDocumentSnapshot project, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectScreenDetails(projectId: project.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Icono y título
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_outlined, 
                      color: Color(0xFF1565C0), 
                      size: 24
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF263238),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fecha límite: ${_formatDate((data['dueDate'] as Timestamp).toDate())}',
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildModernStatusChip(data['status'] ?? 'En proceso'),
                ],
              ),
              const SizedBox(height: 16),
              // Estadísticas y progreso
              Row(
                children: [
                  _buildStatsItem('Por hacer', buildTaskCount(project.id, 'por hacer')),
                  _buildStatsItem('En proceso', buildTaskCount(project.id, 'en proceso')),
                  _buildStatsItem('Revisión', buildTaskCount(project.id, 'en revision')),
                  _buildStatsItem('Completadas', buildTaskCount(project.id, 'completada')),
                  const Spacer(),
                  Container(
                    width: 120,
                    child: FutureBuilder<double>(
                      future: calculateProjectProgress(project.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                          ),
                        );
                        final progress = snapshot.data!;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Progreso',
                                  style: TextStyle(
                                    color: Color(0xFF607D8B),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _getProgressColor(progress),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEEEEE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Container(
                                  height: 8,
                                  width: 120 * progress,
                                  decoration: BoxDecoration(
                                    color: _getProgressColor(progress),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getProgressColor(progress).withOpacity(0.4),
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsItem(String label, Widget count) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF607D8B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          count,
        ],
      ),
    );
  }

  Widget buildTaskCount(String projectId, String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('tasks')
        .where('projectId', isEqualTo: projectId)
        .where('status', isEqualTo: status)
        .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('...');
        }
        
        if (snapshot.hasError) {
          print('Error al obtener tareas ($status): ${snapshot.error}');
          return const Text('0');
        }
        
        if (!snapshot.hasData) {
          return const Text('0');
        }
        
        final count = snapshot.data!.docs.length;
        return Text(
          count.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF37474F),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open,
              size: 48,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay proyectos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF263238),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea tu primer proyecto para empezar a trabajar',
            style: TextStyle(
              color: Color(0xFF78909C),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navegar a la página de creación de proyectos
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear proyecto'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'completado':
        color = const Color(0xFF4CAF50);
        icon = Icons.check_circle_outline;
        break;
      case 'en riesgo':
        color = const Color(0xFFFFA000);
        icon = Icons.warning_amber_rounded;
        break;
      case 'atrasado':
        color = const Color(0xFFF44336);
        icon = Icons.error_outline;
        break;
      default:
        color = const Color(0xFF2196F3);
        icon = Icons.play_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return const Color(0xFF43A047);  // Verde más oscuro
    if (progress >= 0.5) return const Color(0xFF1E88E5);  // Azul más oscuro
    if (progress >= 0.3) return const Color(0xFFFB8C00);  // Naranja más oscuro
    return const Color(0xFFE53935);  // Rojo más oscuro
  }
  
  Future<double> calculateProjectProgress(String projectId) async {
    try {
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('projectId', isEqualTo: projectId)
          .get();

      if (tasksSnapshot.docs.isEmpty) return 0.0;

      int totalTasks = tasksSnapshot.docs.length;
      int completedTasks = tasksSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'completada')
          .length;
      int inReviewTasks = tasksSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'en revision')
          .length;
      int inProgressTasks = tasksSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'en proceso')
          .length;

      // Calcular progreso ponderado
      double progress = (
        (completedTasks * 1.0) + 
        (inReviewTasks * 0.8) + 
        (inProgressTasks * 0.4)
      ) / totalTasks;

      return progress;
    } catch (e) {
      print('Error al calcular el progreso del proyecto: $e');
      return 0.0;
    }
  }
}

class PieSection {
  final double percentage;
  final Color color;

  PieSection(this.percentage, this.color);
}

class ProjectStatistics extends StatelessWidget {
  Map<String, int> _countProjectsByStatus(List<QueryDocumentSnapshot> projects) {
    final counts = {
      'completado': 0,
      'en proceso': 0,
      'en riesgo': 0,
      'atrasado': 0,
    };

    for (var project in projects) {
      final data = project.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'en proceso').toString().toLowerCase();
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = snapshot.data?.docs ?? [];
        final statusCount = _countProjectsByStatus(projects);
        final total = projects.length;

        return Container(
          height: 630,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart, size: 20, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Text(
                      'Número de proyectos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'por estado',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: ModernPieChartPainter(
                              sections: [
                                PieSection((statusCount['completado'] ?? 0) / total, Colors.green.shade400),
                                PieSection((statusCount['en proceso'] ?? 0) / total, Colors.blue.shade400),
                                PieSection((statusCount['en riesgo'] ?? 0) / total, Colors.orange.shade400),
                                PieSection((statusCount['atrasado'] ?? 0) / total, Colors.red.shade400),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                total.toString(),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'Proyectos',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModernLegendItem('Completado', Colors.green.shade400, statusCount['completado'] ?? 0, total),
                    _buildModernLegendItem('En proceso', Colors.blue.shade400, statusCount['en proceso'] ?? 0, total),
                    _buildModernLegendItem('En riesgo', Colors.orange.shade400, statusCount['en riesgo'] ?? 0, total),
                    _buildModernLegendItem('Atrasado', Colors.red.shade400, statusCount['atrasado'] ?? 0, total),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernLegendItem(String label, Color color, int count, int total) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count ($percentage%)',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pintor moderno para el gráfico circular
class ModernPieChartPainter extends CustomPainter {
  final List<PieSection> sections;

  ModernPieChartPainter({required this.sections});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    var startAngle = -90 * (pi / 180);

    // Dibujar un círculo de fondo semi-transparente
    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Dibujar un círculo exterior como borde
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, borderPaint);

    // Calcular el ángulo total disponible (excluyendo pequeños espacios entre secciones)
    final spaceAngle = 2 * pi / 180; // 2 grados entre secciones
    final totalSpace = spaceAngle * sections.length;
    final availableAngle = 2 * pi - totalSpace;

    for (var section in sections) {
      final sweepAngle = section.percentage * availableAngle;
      
      final paint = Paint()
        ..color = section.color
        ..style = PaintingStyle.fill
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // Dibujar sección con un pequeño espacio y borde redondeado
      final rect = Rect.fromCircle(center: center, radius: radius - 5);
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Añadir un brillo/resplandor en la parte superior de cada sección para dar efecto 3D
      if (section.percentage > 0.1) {  // Solo para secciones suficientemente grandes
        final highlightPaint = Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        
        canvas.drawArc(
          rect,
          startAngle,
          sweepAngle / 3,  // El resaltado solo cubre parte de la sección
          false,
          highlightPaint,
        );
      }

      // Moverse al siguiente ángulo, añadiendo un pequeño espacio
      startAngle += sweepAngle + spaceAngle;
    }

    // Dibujar un círculo interior para crear el efecto de dona
    final innerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.6, innerCirclePaint);
    
    // Borde interior con sombra suave
    final innerBorderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawCircle(center, radius * 0.6, innerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ProjectsOverviewTable extends StatefulWidget {
  @override
  _ProjectsOverviewTableState createState() => _ProjectsOverviewTableState();
}

class _ProjectsOverviewTableState extends State<ProjectsOverviewTable> {
  late Stream<List<ActivityItem>> _activityStream;

  @override
  void initState() {
    super.initState();
    _initializeActivityStream();
  }

  void _initializeActivityStream() {
    _activityStream = _getRecentActivity();
  }

  Stream<List<ActivityItem>> _getRecentActivity() {
    print('Iniciando _getRecentActivity()');
    final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    final oneWeekAgoTimestamp = Timestamp.fromDate(oneWeekAgo);

    return Rx.combineLatest3(
      // Stream de proyectos
      FirebaseFirestore.instance
          .collection('projects')
          .where('createdAt', isGreaterThan: oneWeekAgoTimestamp)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            List<ActivityItem> projectItems = [];
            for (var doc in snapshot.docs) {
              final data = doc.data();
              // Obtener información del usuario
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(data['ownerId'])
                  .get();
              final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['email']?.toString().split('@')[0] ?? 'Usuario';
              
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
            }
            return projectItems;
          }),
      // Stream de tareas
      FirebaseFirestore.instance
          .collection('tasks')
          .where('createdAt', isGreaterThan: oneWeekAgoTimestamp)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            List<ActivityItem> taskItems = [];
            for (var doc in snapshot.docs) {
              final data = doc.data();
              // Obtener información del proyecto y usuario
              final projectDoc = await FirebaseFirestore.instance
                  .collection('projects')
                  .doc(data['projectId'])
                  .get();
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(data['assignedTo'])
                  .get();
              
              final projectTitle = projectDoc.data()?['title'] ?? 'proyecto';
              final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['email']?.toString().split('@')[0] ?? 'Usuario';

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
                  .where('createdAt', isGreaterThan: oneWeekAgoTimestamp)
                  .orderBy('createdAt', descending: true)
                  .get();

              for (var commentDoc in commentsSnapshot.docs) {
                final data = commentDoc.data();
                // Obtener información del usuario
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['userId'])
                    .get();
                final userName = userDoc.data()?['displayName'] ?? userDoc.data()?['email']?.toString().split('@')[0] ?? 'Usuario';

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
        return allActivities.take(15).toList(); // Limitamos a 15 items
      },
    ).handleError((error) {
      print('Error en el stream: $error');
      return [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Actividad Reciente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.blue),
                    onPressed: () {
                      print('Botón de actualizar presionado');
                      setState(() {
                        _initializeActivityStream();
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActivitiesPage(
                            user: FirebaseAuth.instance.currentUser!,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Ver todas',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<ActivityItem>>(
              stream: _activityStream,
              builder: (context, snapshot) {
                print('Estado del StreamBuilder: ${snapshot.connectionState}');
                print('Tiene error: ${snapshot.hasError}');
                if (snapshot.hasError) print('Error: ${snapshot.error}');
                print('Tiene datos: ${snapshot.hasData}');
                if (snapshot.hasData) print('Número de items: ${snapshot.data!.length}');

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, 
                          size: 48, 
                          color: Colors.grey[400]
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay actividad reciente',
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
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final activity = snapshot.data![index];
                    print('Construyendo item $index: ${activity.type} - ${activity.title}');
                    return _buildActivityItem(activity);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
}

class ActivityItem {
  final String type;
  final String title;
  final String message;
  final Timestamp timestamp;
  final String id;
  final String userId;    // ID del usuario que realizó la actividad
  final String userName;  // Nombre del usuario que realizó la actividad
  final String projectId; // ID del proyecto relacionado

  ActivityItem({
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.id,
    required this.userId,
    required this.userName,
    required this.projectId,
  });
}

class NavigationSidebar extends StatelessWidget {
  static const List<String> adminEmails = [
    'joelosiris11@gmail.com',
    'josejoaquinsosa2@gmail.com'
  ];

  const NavigationSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAdmin = currentUser != null && adminEmails.contains(currentUser.email);

    return Container(
      width: 80, // Ligeramente más ancho
      decoration: BoxDecoration(
        color: const Color(0xFF1E4B5F),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo LTM con efecto de elevación
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E4B5F).withOpacity(0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/ltm.png',
              width: 42,
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          // Botones de navegación mejorados
          _buildNavButton(
            Icons.home_rounded, 
            'Inicio',
            isSelected: true,
          ),
          _buildNavButton(
            Icons.folder_special_rounded,
            'Proyectos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyProjectsPage(
                    user: FirebaseAuth.instance.currentUser!,
                  ),
                ),
              );
            },
          ),
          _buildNavButton(
            Icons.add_circle_outlined,
            'Crear',
            isAction: true, 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectCreationPage(
                    user: FirebaseAuth.instance.currentUser!,
                  ),
                ),
              );
            }
          ),
          const Spacer(),
          if (isAdmin)
            _buildNavButton(
              Icons.settings_rounded, 
              'Config',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfigurationPage(),
                  ),
                );
              }
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    IconData icon, 
    String label, {
      bool isSelected = false, 
      bool isAction = false, 
      VoidCallback? onPressed
    }
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(
                    left: BorderSide(
                      color: Colors.white,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Tooltip(
            message: label,
            preferBelow: false,
            verticalOffset: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                hoverColor: isAction ? Colors.greenAccent.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                splashColor: isAction ? Colors.greenAccent.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    icon,
                    color: isAction 
                        ? Colors.greenAccent 
                        : (isSelected ? Colors.white : Colors.white70),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isAction 
                ? Colors.greenAccent.withOpacity(0.9) 
                : (isSelected ? Colors.white : Colors.white60),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
} 