import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProjectCreationPage extends StatefulWidget {
  final User user;

  const ProjectCreationPage({Key? key, required this.user}) : super(key: key);

  @override
  _ProjectCreationPageState createState() => _ProjectCreationPageState();
}

class _ProjectCreationPageState extends State<ProjectCreationPage> {
  final _formKey = GlobalKey<FormState>();
  String _projectName = '';
  String _projectDescription = '';
  DateTime _projectDueDate = DateTime.now().add(Duration(days: 7));
  List<Map<String, dynamic>> _tasks = [];
  Color _selectedColor = Colors.blue.shade200;
  final ValueNotifier<bool> _formValidNotifier = ValueNotifier<bool>(false);

  bool get _isFormValid {
    return _projectName.isNotEmpty && 
           _projectDescription.isNotEmpty &&
           _projectDueDate.isAfter(DateTime.now()) &&
           _tasks.length >= 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Reutilizar el NavigationSidebar aquí si es necesario
          Expanded(
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 24),
                          _buildMainForm(),
                          const SizedBox(height: 24),
                          _buildTasksSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: Colors.grey[800]),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Container(
          margin: EdgeInsets.all(8),
          child: ValueListenableBuilder<bool>(
            valueListenable: _formValidNotifier,
            builder: (context, isValid, child) {
              return ElevatedButton.icon(
                onPressed: isValid ? _submitForm : null,
                icon: Icon(Icons.rocket_launch),
                label: Text('Crear Proyecto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? Colors.blue[600] : Colors.grey[400],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch, color: Colors.white, size: 32),
              SizedBox(width: 16),
              Text(
                'Nuevo Proyecto',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Crea un nuevo proyecto y comienza a colaborar con tu equipo',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainForm() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Información del Proyecto', Icons.info_outline),
          SizedBox(height: 24),
          _buildTextField(
            'Nombre del Proyecto',
            Icons.title,
            onChanged: (value) {
              _projectName = value;
              _updateFormValidation();
            },
            isRequired: true,
          ),
          SizedBox(height: 24),
          _buildTextField(
            'Descripción',
            Icons.description_outlined,
            maxLines: 3,
            onChanged: (value) {
              _projectDescription = value;
              _updateFormValidation();
            },
            isRequired: true,
          ),
          SizedBox(height: 32),
          _buildSectionTitle('Personalización', Icons.palette_outlined),
          SizedBox(height: 24),
          _buildColorPicker(),
          SizedBox(height: 24),
          _buildDatePicker(),
        ],
      ),
    );
  }

  Widget _buildTasksSection() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Tareas', Icons.task_alt),
              _buildAddTaskButton(),
            ],
          ),
          SizedBox(height: 24),
          _buildTasksList(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[700], size: 24),
        SizedBox(width: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, IconData icon, {
    int maxLines = 1,
    Function(String)? onChanged,
    bool isRequired = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        maxLines: maxLines,
        onChanged: onChanged,
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return 'Este campo es requerido';
          }
          return null;
        } : null,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          prefixIcon: Icon(icon, color: Colors.blue[400]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    List<Color> colors = [
      Colors.blue.shade200,
      Colors.green.shade200,
      Colors.purple.shade200,
      Colors.orange.shade200,
      Colors.pink.shade200,
      Colors.teal.shade200,
    ];

    return Wrap(
      spacing: 12,
      children: colors.map((color) {
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedColor == color ? Colors.blue : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _projectDueDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => _projectDueDate = picked);
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue[400]),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fecha de entrega',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(_projectDueDate),
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    print('📋 Renderizando lista de tareas en memoria: ${_tasks.length} tareas');
    for (var task in _tasks) {
      print('📌 Tarea en memoria: ${task['name']}');
    }
    
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No hay tareas creadas',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            Text(
              'Necesitas al menos 2 tareas para crear el proyecto',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Las tareas se guardarán cuando crees el proyecto',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 300,
          child: ListView.builder(
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              print('🔄 Renderizando tarea $index: ${task['name']}');
              
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () => _showTaskDialog(task: task, index: index),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header con prioridad y acciones
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(task['priority']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: _getPriorityColor(task['priority']).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flag_rounded,
                                    size: 16,
                                    color: _getPriorityColor(task['priority']),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    task['priority'],
                                    style: TextStyle(
                                      color: _getPriorityColor(task['priority']),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: Colors.blue[400]),
                              onPressed: () => _showTaskDialog(task: task, index: index),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                              onPressed: () => _showDeleteTaskConfirmation(task, index),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        // Título de la tarea
                        Text(
                          task['name'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (task['description']?.isNotEmpty ?? false) ...[
                          SizedBox(height: 8),
                          Text(
                            task['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        SizedBox(height: 16),
                        // Footer con asignación y fecha
                        Row(
                          children: [
                            // Avatar y nombre del asignado
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.blue[100],
                                    child: Text(
                                      task['assignedToName'][0].toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    task['assignedToName'],
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            // Fecha de vencimiento
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: Colors.grey[700],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    DateFormat('dd MMM').format(task['dueDate']),
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddTaskButton() {
    return ElevatedButton.icon(
      onPressed: _showAddTaskDialog,
      icon: Icon(Icons.add),
      label: Text('Añadir Tarea'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddTaskDialog(
          onTaskCreated: (newTask) {
            setState(() {
              _tasks.add({
                ...newTask,
                'hours': newTask['hours'] ?? 0,
              });
              print('✅ Tarea agregada a la lista temporal: ${newTask['name']}');
              print('📋 Total de tareas en memoria: ${_tasks.length}');
              _updateFormValidation();
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Tarea agregada a la lista (aún no guardada)'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogTextField(
    String label, 
    IconData icon, 
    {
      required Function(String) onChanged,
      String? initialValue,
    }
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        initialValue: initialValue,
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

  Widget _buildDialogDropdown(
    String label,
    IconData icon,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
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

  Widget _buildDateSelector(BuildContext context, DateTime selectedDate, Function(DateTime) onDateChanged) {
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
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                if (picked != null) {
                  onDateChanged(picked);
                }
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue),
                    SizedBox(width: 12),
                    Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
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

  Future<Map<String, dynamic>?> _showUserSelectionDialog() async {
    final users = await _getUsers();
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
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
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getUsers() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('users').get();
    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  void _submitForm() async {
    print('🚀 Iniciando creación de proyecto');
    print('📝 Nombre: $_projectName');
    print('📋 Descripción: $_projectDescription');
    print('📅 Fecha límite: $_projectDueDate');
    print('✅ Tareas pendientes de crear: ${_tasks.length}');

    if (!_isFormValid) {
      print('❌ Formulario inválido');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa todos los campos y agrega al menos 2 tareas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Recolectar todos los usuarios asignados
      Set<String> assignedUsers = {widget.user.uid};
      for (var task in _tasks) {
        assignedUsers.add(task['assignedTo']);
      }

      // 1. Crear el proyecto
      final projectRef = await FirebaseFirestore.instance.collection('projects').add({
        'title': _projectName,
        'status': 'planning',
        'description': _projectDescription,
        'dueDate': Timestamp.fromDate(_projectDueDate),
        'createdAt': Timestamp.now(),
        'progress': 0,
        'ownerId': widget.user.uid,
        'members': assignedUsers.toList(),
        'color': '#${_selectedColor.value.toRadixString(16).substring(2)}',
      });
      print('✅ Proyecto creado con ID: ${projectRef.id}');

      // 2. Crear las tareas
      for (var task in _tasks) {
        print('➕ Creando tarea en Firestore: ${task['name']}');
        final taskRef = await FirebaseFirestore.instance.collection('tasks').add({
          'title': task['name'],
          'status': 'por hacer',
          'description': task['description'],
          'dueDate': Timestamp.fromDate(task['dueDate']),
          'assignedTo': task['assignedTo'],
          'projectId': projectRef.id,
          'priority': task['priority'],
          'createdAt': task['createdAt'],
          'hours': task['hours'] ?? 0,
        });
        print('✅ Tarea creada con ID: ${taskRef.id}');

        // Actualizar userTasks
        await FirebaseFirestore.instance
            .collection('userTasks')
            .doc(task['assignedTo'])
            .set({
          'tasks': FieldValue.arrayUnion([taskRef.id]),
        }, SetOptions(merge: true));
      }

      // 3. Actualizar userProjects para todos los usuarios involucrados
      for (String userId in assignedUsers) {
        await FirebaseFirestore.instance.collection('userProjects').doc(userId).set({
          'projects': FieldValue.arrayUnion([projectRef.id]),
        }, SetOptions(merge: true));
      }

      // 4. Actualizar taskSummaries para todos los usuarios involucrados
      final batch = FirebaseFirestore.instance.batch();
      for (String userId in assignedUsers) {
        final taskSummaryRef = FirebaseFirestore.instance.collection('taskSummaries').doc(userId);
        batch.set(taskSummaryRef, {
          'totalTasks': FieldValue.increment(_tasks.where((task) => task['assignedTo'] == userId).length),
          'pendingTasks': FieldValue.increment(_tasks.where((task) => task['assignedTo'] == userId).length),
          'myTasks': FieldValue.increment(_tasks.where((task) => task['assignedTo'] == userId).length),
          'assignedTasks': FieldValue.increment(_tasks.where((task) => task['assignedTo'] == userId).length),
          'inProgressTasks': FieldValue.increment(0),
          'completedTasks': FieldValue.increment(0),
          'overdueTasks': FieldValue.increment(0),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      print('🎉 Proyecto y tareas creados exitosamente');
      Navigator.pop(context);
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear el proyecto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Escuchar cambios en los campos del formulario
    _formValidNotifier.value = _isFormValid;
  }

  void _updateFormValidation() {
    _formValidNotifier.value = _isFormValid;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'alta':
        return Colors.red[700]!;
      case 'media':
        return Colors.orange[700]!;
      case 'baja':
        return Colors.green[700]!;
      default:
        return Colors.blue[700]!;
    }
  }

  void _showTaskDialog({Map<String, dynamic>? task, int? index}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddTaskDialog(
          task: task, // Pasar la tarea si es edición
          onTaskCreated: (newTask) {
            setState(() {
              if (index != null) {
                // Editar tarea existente
                _tasks[index] = newTask;
                print('✏️ Tarea editada: ${newTask['name']}');
              } else {
                // Crear nueva tarea
                _tasks.add(newTask);
                print('✅ Tarea agregada: ${newTask['name']}');
              }
              print('📋 Total de tareas: ${_tasks.length}');
              _updateFormValidation();
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text(index != null ? 'Tarea actualizada' : 'Tarea agregada'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteTaskConfirmation(Map<String, dynamic> task, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            SizedBox(width: 8),
            Text('Eliminar Tarea'),
          ],
        ),
        content: Text('¿Estás seguro de que quieres eliminar la tarea "${task['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _tasks.removeAt(index);
                _updateFormValidation();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tarea eliminada'),
                  backgroundColor: Colors.red[400],
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text('Eliminar'),
          ),
        ],
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
    final isEditing = widget.task != null;
    final headerTitle = isEditing ? 'Editar Tarea' : 'Nueva Tarea';
    final buttonText = isEditing ? 'Guardar Cambios' : 'Crear Tarea';
    final headerGradient = isEditing 
      ? [Colors.orange.shade400, Colors.orange.shade600]
      : [Colors.blue.shade400, Colors.blue.shade600];

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
                  colors: headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note : Icons.add_task,
                    color: Colors.white,
                    size: 28
                  ),
                  SizedBox(width: 16),
                  Text(
                    headerTitle,
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
                      backgroundColor: isEditing ? Colors.orange : Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(buttonText),
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