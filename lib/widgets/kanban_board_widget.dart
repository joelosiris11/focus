import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class KanbanBoard extends StatelessWidget {
  final String projectId;
  final Color projectColor;

  const KanbanBoard({
    Key? key, 
    required this.projectId,
    required this.projectColor,
  }) : super(key: key);

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
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('projectId', isEqualTo: projectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            );
          }

          final tasks = snapshot.data!.docs;
          
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDraggableColumn(context, '🎯 Por hacer', tasks, 'por hacer', projectColor),
                _buildDraggableColumn(context, '⚡ En proceso', tasks, 'en proceso', projectColor),
                _buildDraggableColumn(context, '👀 En revisión', tasks, 'en revision', projectColor),
                _buildDraggableColumn(context, '✨ Completado', tasks, 'completada', projectColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraggableColumn(BuildContext context, String title, List<QueryDocumentSnapshot> tasks, String status, Color color) {
    final columnTasks = tasks.where((task) {
      final data = task.data() as Map<String, dynamic>;
      return data['status']?.toString().toLowerCase() == status.toLowerCase();
    }).toList();

    return DragTarget<String>(
      onWillAccept: (data) => true,
      onAccept: (taskId) {
        _updateTaskStatus(taskId, status);
      },
      builder: (context, candidateData, rejectedData) => Container(
        width: 320,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  Row(
                    children: [
                      if (status == 'por hacer') // Solo mostrar el botón en la columna "Por hacer"
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: color),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AddTaskDialog(
                                onTaskCreated: (taskData) async {
                                  try {
                                    // Crear la tarea en Firestore
                                    final taskRef = await FirebaseFirestore.instance.collection('tasks').add({
                                      ...taskData,
                                      'projectId': projectId,
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
                                      SnackBar(content: Text('Error al crear la tarea')),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
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
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: columnTasks.map((task) => _buildDraggableTask(context, task, color)).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableTask(BuildContext context, QueryDocumentSnapshot task, Color color) {
    return Draggable<String>(
      data: task.id,
      feedback: Material(
        elevation: 4,
        child: Container(
          width: 300,
          child: _buildTaskCard(context, task, color),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildTaskCard(context, task, color),
      ),
      child: _buildTaskCard(context, task, color),
    );
  }

  Widget _buildTaskCard(BuildContext context, QueryDocumentSnapshot task, Color color) {
    final data = task.data() as Map<String, dynamic>;
    final createdAt = data['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null 
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
        : 'Fecha no disponible';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
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
                builder: (context) => TaskDetailsDialog(task: task, color: projectColor),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['priority']?.toString().toUpperCase() ?? 'MEDIA',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer, size: 12, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text(
                              '${data['hours'] ?? 0}h',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.more_vert, color: Colors.grey[400]),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    data['title'] ?? 'Sin título',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    data['description'] ?? 'Sin descripción',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: color.withOpacity(0.2),
                        child: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: color,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(data['assignedTo'])
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Text(
                                'Cargando...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            }

                            final userData = snapshot.data!.data() as Map<String, dynamic>?;
                            final userName = userData?['displayName'] ?? userData?['email'] ?? 'Sin asignar';

                            return Text(
                              userName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
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