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
    return Scaffold(
      body: Row(
        children: [
          const NavigationSidebar(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardHeader(),
                    const SizedBox(height: 24),
                    StatusCardsRow(),
                    const SizedBox(height: 24),
                    Row(
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
                    const SizedBox(height: 24),
                    ProjectsOverviewTable(),
                  ],
                ),
              ),
            ),
          ),
        ],
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
            children: [
              Icon(Icons.circle, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            number,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Esta semana $percentage',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectsList extends StatelessWidget {
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

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.folder_special_rounded,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lista de Proyectos',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${projects.length} proyectos activos',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 50,
                    dataRowHeight: 65,
                    horizontalMargin: 20,
                    columnSpacing: 30,
                    headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                    headingTextStyle: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    columns: const [
                      DataColumn(
                        label: Text('Nombre'),
                        tooltip: 'Nombre del proyecto',
                      ),
                      DataColumn(
                        label: Text('Estado'),
                        tooltip: 'Estado actual del proyecto',
                      ),
                      DataColumn(
                        label: Text('Por hacer'),
                        tooltip: 'Tareas pendientes',
                      ),
                      DataColumn(
                        label: Text('En proceso'),
                        tooltip: 'Tareas en desarrollo',
                      ),
                      DataColumn(
                        label: Text('En revisión'),
                        tooltip: 'Tareas en revisión',
                      ),
                      DataColumn(
                        label: Text('Completadas'),
                        tooltip: 'Tareas finalizadas',
                      ),
                      DataColumn(
                        label: Text('Avance'),
                        tooltip: 'Porcentaje de avance',
                      ),
                      DataColumn(
                        label: Text('Fecha límite'),
                        tooltip: 'Fecha de entrega',
                      ),
                    ],
                    rows: projects.map((project) {
                      final data = project.data() as Map<String, dynamic>;
                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProjectScreenDetails(projectId: project.id),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.folder_outlined, 
                                      color: Colors.blue[700], 
                                      size: 20
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    data['title'] ?? 'Sin nombre',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(_buildModernStatusChip(data['status'] ?? 'En proceso')),
                          ...buildTaskStatusCells(project.id),
                          DataCell(
                            Container(
                              width: 120,
                              child: FutureBuilder<double>(
                                future: calculateProjectProgress(project.id),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return const CircularProgressIndicator();
                                  final progress = snapshot.data!;
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _getProgressColor(progress),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _getProgressColor(progress),
                                          ),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          DataCell(_buildDateCell((data['dueDate'] as Timestamp).toDate())),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<DataCell> buildTaskStatusCells(String projectId) {
    return [
      'por hacer',
      'en proceso',
      'en revision',
      'completada',
    ].map((status) {
      return DataCell(
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tasks')
              .where('projectId', isEqualTo: projectId)
              .where('status', isEqualTo: status)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Text('...');
            return Text(snapshot.data!.docs.length.toString());
          },
        ),
      );
    }).toList();
  }

  Future<double> calculateProjectProgress(String projectId) async {
    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .where('projectId', isEqualTo: projectId)
        .get();

    if (tasksSnapshot.docs.isEmpty) return 0.0;

    int totalTasks = tasksSnapshot.docs.length;
    int completedTasks = tasksSnapshot.docs
        .where((doc) => doc['status'] == 'completada')
        .length;
    int inReviewTasks = tasksSnapshot.docs
        .where((doc) => doc['status'] == 'en revision')
        .length;
    int inProgressTasks = tasksSnapshot.docs
        .where((doc) => doc['status'] == 'en proceso')
        .length;

    // Calcular progreso ponderado
    double progress = (
      (completedTasks * 1.0) + 
      (inReviewTasks * 0.8) + 
      (inProgressTasks * 0.4)
    ) / totalTasks;

    return progress;
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green;
    if (progress >= 0.5) return Colors.blue;
    if (progress >= 0.3) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildModernStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'completado':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'en riesgo':
        color = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case 'atrasado':
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      default:
        color = Colors.blue;
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

  Widget _buildDateCell(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    final isLate = difference < 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLate ? Colors.red.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLate ? Icons.warning_rounded : Icons.calendar_today_rounded,
            size: 16,
            color: isLate ? Colors.red : Colors.grey[700],
          ),
          const SizedBox(width: 8),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: TextStyle(
              color: isLate ? Colors.red : Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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

    for (var section in sections) {
      final sweepAngle = section.percentage * 2 * pi;
      final paint = Paint()
        ..color = section.color
        ..style = PaintingStyle.fill
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      // Dibujar sección con un pequeño espacio
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 5),
        startAngle,
        sweepAngle - (pi / 180 * 2), // Pequeño espacio entre secciones
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
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
              final userName = userDoc.data()?['name'] ?? 'Usuario';
              
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
              final userName = userDoc.data()?['name'] ?? 'Usuario';

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
          const SizedBox(height: 24),
          StreamBuilder<List<ActivityItem>>(
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

              return Container(
                height: 400, // Altura fija para el contenedor scrolleable
                child: ListView.separated(
                  physics: BouncingScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final activity = snapshot.data![index];
                    print('Construyendo item $index: ${activity.type} - ${activity.title}');
                    return _buildActivityItem(activity);
                  },
                ),
              );
            },
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
      width: 72,
      color: const Color(0xFF1E4B5F),
      child: Column(
        children: [
          // Logo LTM
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset(
              'assets/ltm.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
          // Botones de navegación esenciales
          _buildNavButton(Icons.home, isSelected: true),
          _buildNavButton(
            Icons.folder_special_outlined,
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
          _buildNavButton(Icons.add_circle_outline, isAction: true, onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectCreationPage(
                  user: FirebaseAuth.instance.currentUser!,
                ),
              ),
            );
          }),
          const Spacer(),
          if (isAdmin)
            _buildNavButton(Icons.settings, onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConfigurationPage(),
                ),
              );
            }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, {
    bool isSelected = false, 
    bool isAction = false, 
    VoidCallback? onPressed
  }) {
    return Container(
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
      child: IconButton(
        icon: Icon(icon),
        color: isAction ? Colors.greenAccent : (isSelected ? Colors.white : Colors.white54),
        onPressed: onPressed ?? () {},
      ),
    );
  }
} 