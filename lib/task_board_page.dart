import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_project_page.dart';
import 'task_list_page.dart';
import 'project_details_page.dart';
import 'notifications_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'user_list_page.dart';
import 'projects/all_projects_page.dart';
import 'package:flutter/services.dart';

class TaskBoardPage extends StatefulWidget {
  final User user;

  const TaskBoardPage({Key? key, required this.user}) : super(key: key);

  @override
  _TaskBoardPageState createState() => _TaskBoardPageState();
}

class _TaskBoardPageState extends State<TaskBoardPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  int _selectedIndex = 0;
  int totalProjects = 0;
  int totalTasks = 0;
  int pendingTasks = 0;
  int myTasks = 0;
  int assignedTasks = 0;
  int inProgressTasks = 0;
  int completedTasks = 0;
  int overdueTasks = 0;
  int totalUsers = 0;  // Nueva variable para almacenar el número de usuarios
  List<Map<String, dynamic>> projects = [];

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _loadUserCount();  // Asegúrate de que esta línea esté presente
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    // Configura el estilo de la barra de estado
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final userId = widget.user.uid;
    final firestore = FirebaseFirestore.instance;

    // Obtener total de proyectos
    final projectsSnapshot = await firestore.collection('userProjects').doc(userId).get();
    if (projectsSnapshot.exists) {
      final projects = projectsSnapshot.data()?['projects'] as List<dynamic>?;
      totalProjects = projects?.length ?? 0;
    }

    // Obtener todas las tareas del usuario
    final tasksQuery = await firestore.collection('tasks').where('assignedTo', isEqualTo: userId).get();
    final tasks = tasksQuery.docs;

    // Reiniciar contadores
    totalTasks = tasks.length;
    pendingTasks = 0;
    myTasks = totalTasks;
    inProgressTasks = 0;
    completedTasks = 0;
    overdueTasks = 0;

    // Calcular contadores basados en las tareas
    final now = DateTime.now();
    for (var task in tasks) {
      final data = task.data();
      final status = data['status'];
      final dueDate = (data['dueDate'] as Timestamp).toDate();
      final daysUntilDue = dueDate.difference(now).inDays;

      if (status == 'por hacer') pendingTasks++;
      if (status == 'en proceso') inProgressTasks++;
      if (status == 'en revision') completedTasks++;
      if (daysUntilDue < 2 && status != 'en revision') overdueTasks++;
    }

    // Cargar proyectos del usuario
    projects.clear();
    final userProjectsSnapshot = await firestore.collection('userProjects').doc(userId).get();
    if (userProjectsSnapshot.exists) {
      final userProjects = userProjectsSnapshot.data()?['projects'] as List<dynamic>?;
      if (userProjects != null) {
        for (String projectId in userProjects) {
          final projectSnapshot = await firestore.collection('projects').doc(projectId).get();
          if (projectSnapshot.exists) {
            final projectData = projectSnapshot.data()!;
            print('Color del proyecto: ${projectData['color']}'); // Cambiado a 'color' en minúsculas
            projects.add({
              'id': projectId,
              'title': projectData['title'],
              'status': projectData['status'],
              'dueDate': projectData['dueDate'],
              'color': projectData['color'] ?? '#000000', // Cambiado a 'color' en minúsculas
            });
          }
        }
      }
    }

    // Actualizar taskSummaries con los nuevos valores calculados
    await firestore.collection('taskSummaries').doc(userId).set({
      'totalTasks': totalTasks,
      'pendingTasks': pendingTasks,
      'myTasks': myTasks,
      'inProgressTasks': inProgressTasks,
      'completedTasks': completedTasks,
      'overdueTasks': overdueTasks,
    }, SetOptions(merge: true));

    setState(() {
      // Asegúrate de que todos los contadores se actualicen aquí
      totalTasks = tasks.length;
      myTasks = totalTasks;
      pendingTasks = tasks.where((task) => task.data()['status'] == 'por hacer').length;
      inProgressTasks = tasks.where((task) => task.data()['status'] == 'en proceso').length;
      completedTasks = tasks.where((task) => task.data()['status'] == 'en revision').length;
      overdueTasks = tasks.where((task) {
        final data = task.data();
        final status = data['status'];
        final dueDate = (data['dueDate'] as Timestamp).toDate();
        final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
        return daysUntilDue < 2 && status != 'en revision';
      }).length;
    });
  }

  Future<void> _loadUserCount() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final usersSnapshot = await firestore.collection('users').get();
      print('Número de usuarios encontrados: ${usersSnapshot.docs.length}');
      for (var doc in usersSnapshot.docs) {
        print('Usuario ID: ${doc.id}, Datos: ${doc.data()}');
      }
      setState(() {
        totalUsers = usersSnapshot.docs.length;
      });
      print('totalUsers actualizado a: $totalUsers');
    } catch (e) {
      print('Error al cargar el número de usuarios: $e');
    }
  }

  IconData _getRandomIcon() {
    List<IconData> icons = [
      Icons.work,
      Icons.computer,
      Icons.build,
      Icons.brush,
      Icons.camera,
      Icons.music_note,
      Icons.sports_soccer,
      Icons.science,
    ];
    return icons[Random().nextInt(icons.length)];
  }

  Widget _getGreeting() {
    var hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Buenos días';
    } else if (hour < 18) {
      greeting = 'Buenas tardes';
    } else {
      greeting = 'Buenas noches';
    }

    return Row(
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(width: 8),
        Image.asset(
          'assets/ltm.png',
          height: 16,
          width: 16,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  void _navigateToProjectDetails(String projectId, String projectTitle) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsPage(
          user: widget.user,
          projectId: projectId,
          projectTitle: projectTitle,
        ),
      ),
    );

    if (result == true) {
      // Si el resultado es true, actualiza los datos
      _loadData();
    }
  }

  void _showStatistics() {
    _animationController.forward(from: 0.0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estadísticas de Tareas',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Column(
                            children: [
                              _buildAnimatedBar('Por Hacer', pendingTasks, Colors.black),
                              SizedBox(height: 20),
                              _buildAnimatedBar('En Progreso', inProgressTasks, Colors.blue),
                              SizedBox(height: 20),
                              _buildAnimatedBar('Atrasadas', overdueTasks, Colors.red),
                              SizedBox(height: 20),
                              _buildAnimatedBar('Completadas', completedTasks, Colors.green),
                            ],
                          );
                        },
                      ),
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

  Widget _buildAnimatedBar(String label, int value, Color color) {
    final percentage = totalTasks > 0 ? value / totalTasks : 0.0;
    final animation = Tween(begin: 0.0, end: percentage).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $value',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Container(
          height: 20,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: constraints.maxWidth * animation.value,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Text(
                          '${(percentage * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header con gradiente que cubre toda la parte superior
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
              top: MediaQuery.of(context).padding.top + 20, // Ajusta el padding superior
              bottom: 32,
              left: 24,
              right: 24,
            ),
            child: Column(
              children: [
                // Fila superior con logo y avatar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Image.asset(
                            'assets/ltm.png',
                            height: 35,
                            width: 35,
                          ),
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buenas noches',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${widget.user.displayName?.split(' ')[0] ?? 'Usuario'}!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.network(
                            widget.user.photoURL ?? 'https://via.placeholder.com/150',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Tabs modernizados con efecto glassmorphism
                Container(
                  margin: EdgeInsets.only(top: 32),
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabButton('Dashboard', 0),
                      SizedBox(width: 8),
                      _buildTabButton('Mis Proyectos', 1),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                // Tarjetas de resumen
                Row(
                  children: [
                    Expanded(
                      child: _buildTaskSummary(
                        'Total Proyectos',
                        totalProjects.toString(),
                        Colors.purple[600]!,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildTaskSummary(
                        'Total tareas',
                        totalTasks.toString(),
                        Colors.blue[600]!,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Contenido condicional según la pestaña seleccionada
                if (_selectedIndex == 1) ...[
                  _buildSectionTitle('Proyectos en curso'),
                  ...projects.map((project) => Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: _buildProjectCard(
                      project['title'],
                      'Due ${_formatDate(project['dueDate'])}',
                      project['status'],
                      _getColorForStatus(project['status']),
                      projectId: project['id'],
                      projectColor: project['color'],
                    ),
                  )).toList(),
                ] else ...[
                  _buildSectionTitle('Resumen de Tareas'),
                  _buildTaskCard('Mis tareas', myTasks.toString(), Icons.person_outline, Colors.green[600]!, 'myTasks'),
                  _buildTaskCard('En progreso', inProgressTasks.toString(), Icons.timelapse, Colors.orange[600]!, 'inProgressTasks'),
                  _buildTaskCard('Completadas', completedTasks.toString(), Icons.check_circle_outline, Colors.blue[600]!, 'completedTasks'),
                  _buildTaskCard('Atrasadas', overdueTasks.toString(), Icons.warning_amber_rounded, Colors.red[600]!, 'overdueTasks'),
                  _buildTaskCard('Usuarios', totalUsers.toString(), Icons.people, Colors.purple[600]!, 'users'),
                ],
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple,
              Colors.blue,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateProjectPage(user: widget.user)),
              );
              // Recargar los datos después de volver de la página de creación de proyectos
              _loadData();
            },
            customBorder: CircleBorder(),
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 2) {
              _showStatistics();
            }
          },
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder),
              label: 'Proyectos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Estadísticas',
            ),
          ],
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(
            colors: [
              Colors.white.withOpacity(0.3),
              Colors.white.withOpacity(0.1),
            ],
          ) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskSummary(String title, String count, Color color, {String? subtitle}) {
    return InkWell(
      onTap: () {
        if (title.toLowerCase() == 'total proyectos') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllProjectsPage(user: widget.user),
            ),
          );
        } else if (title.toLowerCase() == 'total tareas') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskListPage(
                user: widget.user,
                title: 'Todas las Tareas',
                taskType: 'allTasks',
              ),
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      count,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (title.toLowerCase() == 'total proyectos') ...[
                  SizedBox(width: 12),
                  Image.asset(
                    'assets/ltm.png',
                    height: 42,
                    width: 42,
                    fit: BoxFit.contain,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(String title, String count, IconData icon, Color color, String taskType) {
    return InkWell(
      onTap: () async {
        if (taskType == 'users') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserListPage(currentUser: widget.user),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskListPage(
                user: widget.user,
                title: title,
                taskType: taskType,
                status: taskType == 'inProgressTasks' ? 'en proceso' : 
                        (taskType == 'completedTasks' ? 'en revision' : null),
              ),
            ),
          );
        }
        _loadData(); // Recargar los datos después de regresar
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Text(
                taskType == 'users' ? '$count Usuarios' : '$count Tareas',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(String title, String dueDate, String status, Color statusColor, {required String projectId, required String projectColor}) {
    // Convertir el código de color hexadecimal a un objeto Color
    Color color;
    try {
      // Eliminar el símbolo '#' si está presente y añadir el prefijo 'FF' para la opacidad
      String colorString = projectColor.replaceAll('#', '');
      colorString = 'FF' + colorString;
      color = Color(int.parse(colorString, radix: 16));
    } catch (e) {
      print('Error al parsear el color: $e'); // Para depuración
      // Si hay un error al parsear el color, usa un color por defecto
      color = Colors.grey;
    }

    return InkWell(
      onTap: () => _navigateToProjectDetails(projectId, title),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      dueDate,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Icons.timelapse;
      case 'planning':
        return Icons.event_note;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.work_outline;
    }
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
    return '${date.day} ${_getMonthAbbreviation(date.month)}';
  }

  String _getMonthAbbreviation(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }
}
