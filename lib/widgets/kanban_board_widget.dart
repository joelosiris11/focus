import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class KanbanBoard extends StatefulWidget {
  final String projectId;
  final Color projectColor;

  const KanbanBoard({
    Key? key, 
    required this.projectId,
    required this.projectColor,
  }) : super(key: key);

  @override
  _KanbanBoardState createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  String? _filterUser;
  String? _filterPriority;
  bool _showOverdue = false;
  bool _isFiltering = false;
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .update({'status': newStatus});
    } catch (e) {
      print('Error al actualizar el estado de la tarea: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isFiltering) _buildFilterBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isFiltering = !_isFiltering;
                    if (!_isFiltering) {
                      // Resetear filtros al cerrar
                      _filterUser = null;
                      _filterPriority = null;
                      _showOverdue = false;
                    }
                  });
                },
                icon: Icon(
                  _isFiltering ? Icons.filter_list_off : Icons.filter_list,
                  size: 18,
                ),
                label: Text(_isFiltering ? "Ocultar filtros" : "Filtrar tareas"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.projectColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .where('projectId', isEqualTo: widget.projectId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }

                var tasks = snapshot.data!.docs;
                
                // Aplicar filtros si están activos
                if (_filterUser != null) {
                  tasks = tasks.where((task) {
                    final data = task.data() as Map<String, dynamic>;
                    return data['assignedTo'] == _filterUser;
                  }).toList();
                }
                
                if (_filterPriority != null) {
                  tasks = tasks.where((task) {
                    final data = task.data() as Map<String, dynamic>;
                    return data['priority'] == _filterPriority;
                  }).toList();
                }
                
                if (_showOverdue) {
                  final now = DateTime.now();
                  tasks = tasks.where((task) {
                    final data = task.data() as Map<String, dynamic>;
                    final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
                    final status = data['status']?.toString().toLowerCase();
                    return dueDate != null && 
                           dueDate.isBefore(now) && 
                           status != 'completada';
                  }).toList();
                }
                
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columnWidth = 320.0;
                    final totalWidth = columnWidth * 4 + 48.0; // 4 columnas + espaciado
                    
                    return SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        width: math.max(constraints.maxWidth, totalWidth),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildKanbanColumn('por hacer', '🎯 Por hacer', tasks, Colors.amber, Icons.assignment_outlined),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKanbanColumn('en proceso', '⚡ En proceso', tasks, Colors.blue, Icons.trending_up_outlined),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKanbanColumn('en revision', '👀 En revisión', tasks, Colors.purple, Icons.remove_red_eye_outlined),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKanbanColumn('completada', '✨ Completado', tasks, Colors.green, Icons.check_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filtros de tareas",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUserFilter(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriorityFilter(),
              ),
              const SizedBox(width: 12),
              _buildOverdueFilter(),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final users = snapshot.data!.docs;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filterUser,
              isExpanded: true,
              hint: const Text("Filtrar por usuario"),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("Todos los usuarios"),
                ),
                ...users.map((user) {
                  final userData = user.data() as Map<String, dynamic>;
                  final displayName = userData['displayName'] ?? userData['email'] ?? 'Usuario';
                  return DropdownMenuItem<String?>(
                    value: user.id,
                    child: Text(displayName, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _filterUser = value;
                });
              },
            ),
          ),
        );
      }
    );
  }
  
  Widget _buildPriorityFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _filterPriority,
          isExpanded: true,
          hint: const Text("Filtrar por prioridad"),
          items: const [
            DropdownMenuItem<String?>(
              value: null,
              child: Text("Todas las prioridades"),
            ),
            DropdownMenuItem<String?>(
              value: "Alta",
              child: Text("Alta"),
            ),
            DropdownMenuItem<String?>(
              value: "Media",
              child: Text("Media"),
            ),
            DropdownMenuItem<String?>(
              value: "Baja",
              child: Text("Baja"),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _filterPriority = value;
            });
          },
        ),
      ),
    );
  }
  
  Widget _buildOverdueFilter() {
    return FilterChip(
      selected: _showOverdue,
      label: const Text("Vencidas"),
      avatar: Icon(
        Icons.warning_amber_rounded,
        color: _showOverdue ? Colors.white : Colors.red,
        size: 18,
      ),
      selectedColor: Colors.red,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: _showOverdue ? Colors.white : Colors.black87,
        fontWeight: _showOverdue ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        setState(() {
          _showOverdue = selected;
        });
      },
    );
  }

  Widget _buildKanbanColumn(String status, String title, List<QueryDocumentSnapshot> allTasks, Color color, IconData icon) {
    final columnTasks = allTasks.where((task) {
      final data = task.data() as Map<String, dynamic>;
      return data['status']?.toString().toLowerCase() == status.toLowerCase();
    }).toList();

    // Calcular tareas vencidas
    final now = DateTime.now();
    final overdueTasks = columnTasks.where((task) {
      final data = task.data() as Map<String, dynamic>;
      final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
      return dueDate != null && dueDate.isBefore(now) && status != 'completada';
    }).length;

    return DragTarget<String>(
      onWillAccept: (data) => true,
      onAccept: (taskId) {
        _updateTaskStatus(taskId, status);
      },
      builder: (context, candidateData, rejectedData) {
        // Destacar la columna cuando se esté arrastrando una tarea sobre ella
        final isTargeted = candidateData.isNotEmpty;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isTargeted 
                ? color.withOpacity(0.05) 
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTargeted 
                  ? color 
                  : Colors.grey.withOpacity(0.2),
              width: isTargeted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabecera de la columna
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                  border: Border(
                    bottom: BorderSide(color: color.withOpacity(0.2)),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(icon, color: color),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${columnTasks.length}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    if (status == 'por hacer') // Solo mostrar el botón en la columna "Por hacer"
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.add, size: 18, color: color),
                            label: const Text("Nueva tarea", style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: color,
                              side: BorderSide(color: color),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AddTaskDialog(
                                  onTaskCreated: (taskData) async {
                                    try {
                                      // Crear la tarea en Firestore
                                      final taskRef = await FirebaseFirestore.instance.collection('tasks').add({
                                        ...taskData,
                                        'projectId': widget.projectId,
                                        'status': 'por hacer',
                                        'createdAt': Timestamp.now(),
                                      });

                                      // Actualizar userTasks
                                      await FirebaseFirestore.instance
                                          .collection('userTasks')
                                          .doc(taskData['assignedTo'])
                                          .set({
                                        'tasks': FieldValue.arrayUnion([taskRef.id]),
                                      }, SetOptions(merge: true));

                                      // Actualizar taskSummaries
                                      await FirebaseFirestore.instance
                                          .collection('taskSummaries')
                                          .doc(taskData['assignedTo'])
                                          .set({
                                        'totalTasks': FieldValue.increment(1),
                                        'pendingTasks': FieldValue.increment(1),
                                        'myTasks': FieldValue.increment(1),
                                      }, SetOptions(merge: true));

                                    } catch (e) {
                                      print('Error al crear la tarea: $e');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Error al crear la tarea')),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    
                    // Mostrar indicador de tareas vencidas si hay alguna
                    if (overdueTasks > 0 && status != 'completada')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$overdueTasks ${overdueTasks == 1 ? 'tarea vencida' : 'tareas vencidas'}",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Lista de tareas
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: Scrollbar(
                    thickness: 4,
                    radius: const Radius.circular(2),
                    child: columnTasks.isEmpty 
                      ? _buildEmptyColumn(status, color)
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          shrinkWrap: true,
                          itemCount: columnTasks.length,
                          itemBuilder: (context, index) {
                            return _buildDraggableTask(
                              context, 
                              columnTasks[index], 
                              color, 
                              index == columnTasks.length - 1
                            );
                          },
                        ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyColumn(String status, Color color) {
    String message;
    IconData iconData;
    
    switch(status) {
      case 'por hacer':
        message = "Agrega nuevas tareas para comenzar";
        iconData = Icons.post_add_outlined;
        break;
      case 'en proceso':
        message = "Mueve tareas aquí cuando estén en desarrollo";
        iconData = Icons.engineering_outlined;
        break;
      case 'en revision':
        message = "Las tareas que necesitan revisión irán aquí";
        iconData = Icons.preview_outlined;
        break;
      case 'completada':
        message = "Las tareas terminadas aparecerán aquí";
        iconData = Icons.task_alt_outlined;
        break;
      default:
        message = "No hay tareas en esta columna";
        iconData = Icons.inbox_outlined;
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconData,
            size: 48,
            color: color.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
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

  Widget _buildDraggableTask(BuildContext context, QueryDocumentSnapshot task, Color columnColor, bool isLastItem) {
    final data = task.data() as Map<String, dynamic>;
    
    // Verificar si la tarea está vencida
    final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
    final isOverdue = dueDate != null && 
                     dueDate.isBefore(DateTime.now()) && 
                     data['status']?.toString().toLowerCase() != 'completada';
    
    // Definir el color de la prioridad
    Color priorityColor;
    switch((data['priority'] ?? 'Media').toString()) {
      case 'Alta':
        priorityColor = Colors.red;
        break;
      case 'Media':
        priorityColor = Colors.orange;
        break;
      case 'Baja':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.blue;
    }

    return Draggable<String>(
      data: task.id,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 300,
          child: _buildTaskCard(
            context, 
            task, 
            columnColor, 
            priorityColor, 
            isOverdue,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.2,
        child: _buildTaskCard(
          context, 
          task, 
          columnColor, 
          priorityColor, 
          isOverdue,
        ),
      ),
      child: _buildTaskCard(
        context, 
        task, 
        columnColor, 
        priorityColor, 
        isOverdue,
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context, 
    QueryDocumentSnapshot task, 
    Color columnColor,
    Color priorityColor,
    bool isOverdue,
  ) {
    final data = task.data() as Map<String, dynamic>;
    final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
    
    // Calcular días restantes
    String dueText = 'Sin fecha';
    if (dueDate != null) {
      final difference = dueDate.difference(DateTime.now()).inDays;
      if (difference < 0) {
        dueText = 'Vencido hace ${-difference} ${-difference == 1 ? 'día' : 'días'}';
      } else if (difference == 0) {
        dueText = 'Vence hoy';
      } else {
        dueText = 'En $difference ${difference == 1 ? 'día' : 'días'}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue 
            ? Border.all(color: Colors.red, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isOverdue
                ? Colors.red.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => TaskDetailsDialog(task: task, color: widget.projectColor),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior con prioridad y horas
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Indicador de prioridad
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: priorityColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                color: priorityColor,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data['priority']?.toString().toUpperCase() ?? 'MEDIA',
                                style: TextStyle(
                                  color: priorityColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Horas estimadas
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 12,
                                color: Colors.grey[600]
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${data['hours'] ?? 0}h',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Título de la tarea
                  Text(
                    data['title'] ?? 'Sin título',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: data['status']?.toString().toLowerCase() == 'completada'
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Descripción
                  if (data['description'] != null && data['description'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data['description'] ?? 'Sin descripción',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Información de usuario y fecha
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Usuario asignado
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(data['assignedTo'])
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.person, size: 14, color: Colors.white),
                              );
                            }

                            final userData = snapshot.data!.data() as Map<String, dynamic>?;
                            final userName = userData?['displayName'] ?? userData?['email'] ?? 'Sin asignar';
                            final photoURL = userData?['photoURL'];
                            
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                photoURL != null && photoURL.toString().isNotEmpty
                                  ? CircleAvatar(
                                      radius: 14,
                                      backgroundImage: NetworkImage(photoURL),
                                    )
                                  : CircleAvatar(
                                      radius: 14,
                                      backgroundColor: columnColor.withOpacity(0.2),
                                      child: Text(
                                        userName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: columnColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 100),
                                  child: Text(
                                    userName,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Fecha de vencimiento con indicador visual
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOverdue 
                                ? Colors.red.withOpacity(0.1) 
                                : dueDate != null && dueDate.difference(DateTime.now()).inDays < 2
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOverdue 
                                    ? Icons.warning_amber_rounded 
                                    : Icons.event_outlined,
                                size: 12,
                                color: isOverdue 
                                    ? Colors.red 
                                    : dueDate != null && dueDate.difference(DateTime.now()).inDays < 2
                                        ? Colors.orange
                                        : Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dueText,
                                style: TextStyle(
                                  color: isOverdue 
                                      ? Colors.red 
                                      : dueDate != null && dueDate.difference(DateTime.now()).inDays < 2
                                          ? Colors.orange
                                          : Colors.blue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class TaskDetailsDialog extends StatefulWidget {
  final QueryDocumentSnapshot task;
  final Color color;

  const TaskDetailsDialog({
    Key? key,
    required this.task,
    required this.color,
  }) : super(key: key);

  @override
  _TaskDetailsDialogState createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends State<TaskDetailsDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _priority;
  late DateTime _dueDate;
  late int _hours;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final data = widget.task.data() as Map<String, dynamic>;
    _titleController = TextEditingController(text: data['title']);
    _descriptionController = TextEditingController(text: data['description']);
    _priority = data['priority'] ?? 'Media';
    _dueDate = (data['dueDate'] as Timestamp).toDate();
    _hours = data['hours'] ?? 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateTask() async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'priority': _priority,
        'dueDate': Timestamp.fromDate(_dueDate),
        'hours': _hours,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarea actualizada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al actualizar tarea: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al actualizar la tarea'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTask() async {
    try {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            '¿Eliminar tarea?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '¿Estás seguro de que quieres eliminar esta tarea? Esta acción no se puede deshacer.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (shouldDelete != true) return;

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .delete();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarea eliminada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al eliminar tarea: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al eliminar la tarea'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.task.data() as Map<String, dynamic>;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data['status']?.toString().toUpperCase() ?? 'SIN ESTADO',
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.save_rounded : Icons.edit_rounded,
                    color: Colors.blue,
                  ),
                  onPressed: () {
                    if (_isEditing) {
                      _updateTask();
                    } else {
                      setState(() {
                        _isEditing = true;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: _deleteTask,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isEditing) ...[
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: InputDecoration(
                        labelText: 'Prioridad',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: ['Baja', 'Media', 'Alta'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _priority = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Horas estimadas',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _hours = int.tryParse(value) ?? _hours;
                        });
                      },
                      controller: TextEditingController(text: _hours.toString()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: widget.color,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                          dialogBackgroundColor: Colors.white,
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _dueDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha de vencimiento',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_dueDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(
                data['title'] ?? 'Sin título',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data['description'] ?? 'Sin descripción',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(data['assignedTo'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text('Cargando...');
                      }

                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      return Text(
                        userData?['displayName'] ?? userData?['email'] ?? 'Sin asignar',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    'Creado el ${DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate())}',
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              if (data['dueDate'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event_outlined, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(
                      'Vence el ${DateFormat('dd/MM/yyyy').format((data['dueDate'] as Timestamp).toDate())}',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer_rounded, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    '${data['hours'] ?? 0} horas estimadas',
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AddTaskDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onTaskCreated;
  final Map<String, dynamic>? task;

  const AddTaskDialog({
    Key? key,
    required this.onTaskCreated,
    this.task,
  }) : super(key: key);

  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  late String taskName;
  late String priority;
  late String assignedTo;
  late String assignedToName;
  late DateTime dueDate;
  late String description;
  late int hours;

  @override
  void initState() {
    super.initState();
    taskName = widget.task?['name'] ?? '';
    priority = widget.task?['priority'] ?? 'Media';
    assignedTo = widget.task?['assignedTo'] ?? '';
    assignedToName = widget.task?['assignedToName'] ?? '';
    dueDate = widget.task?['dueDate'] ?? DateTime.now().add(Duration(days: 1));
    description = widget.task?['description'] ?? '';
    hours = widget.task?['hours'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_task, color: Colors.white, size: 28),
                  SizedBox(width: 16),
                  Text(
                    'Nueva Tarea',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      'Nombre de la Tarea',
                      Icons.task_alt,
                      onChanged: (value) => taskName = value,
                    ),
                    SizedBox(height: 20),
                    _buildDropdown(
                      'Prioridad',
                      Icons.flag_outlined,
                      priority,
                      ['Baja', 'Media', 'Alta'],
                      (value) => setState(() => priority = value!),
                    ),
                    SizedBox(height: 20),
                    _buildUserSelector(),
                    SizedBox(height: 20),
                    _buildDateSelector(),
                    SizedBox(height: 20),
                    _buildHoursField(),
                    SizedBox(height: 20),
                    _buildDescriptionField(),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (taskName.isNotEmpty && assignedTo.isNotEmpty) {
                        widget.onTaskCreated({
                          'name': taskName,
                          'title': taskName,
                          'description': description,
                          'priority': priority,
                          'assignedTo': assignedTo,
                          'assignedToName': assignedToName,
                          'dueDate': dueDate,
                          'status': 'por hacer',
                          'createdAt': Timestamp.now(),
                          'hours': hours,
                        });
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Crear Tarea'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, {required Function(String) onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, IconData icon, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildUserSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asignar a',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final users = await _getUsers();
                final selectedUser = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (context) => _buildUserSelectionDialog(users),
                );
                if (selectedUser != null) {
                  setState(() {
                    assignedTo = selectedUser['id'];
                    assignedToName = selectedUser['displayName'] ?? selectedUser['email'] ?? 'Usuario';
                  });
                }
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      assignedTo.isEmpty ? Icons.person_add : Icons.person,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 12),
                    Text(
                      assignedTo.isEmpty ? 'Seleccionar Usuario' : assignedToName,
                      style: TextStyle(
                        color: assignedTo.isEmpty ? Colors.grey[600] : Colors.grey[800],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha de Vencimiento',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => dueDate = picked);
                }
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue),
                    SizedBox(width: 12),
                    Text(
                      DateFormat('dd/MM/yyyy').format(dueDate),
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHoursField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horas Estimadas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              hours = int.tryParse(value) ?? 0;
            },
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.timer, color: Colors.blue),
              hintText: 'Ingrese las horas estimadas',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            controller: TextEditingController(text: hours.toString()),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Descripción',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      maxLines: 3,
      onChanged: (value) => description = value,
    );
  }

  Widget _buildUserSelectionDialog(List<Map<String, dynamic>> users) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Seleccionar Usuario',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        (user['displayName'] ?? user['email'] ?? 'U')[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(user['displayName'] ?? user['email'] ?? 'Usuario'),
                    subtitle: Text(user['email'] ?? ''),
                    onTap: () => Navigator.pop(context, user),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getUsers() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('users').get();
    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }
} 