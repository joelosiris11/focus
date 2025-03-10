import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:intl/intl.dart';

class CommentsSection extends StatefulWidget {
  final String projectId;
  final ScrollController? scrollController;

  const CommentsSection({
    Key? key,
    required this.projectId,
    this.scrollController,
  }) : super(key: key);

  @override
  _CommentsSectionState createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  late ScrollController _scrollController;
  bool _isScrollControllerAttached = false;

  @override
  void initState() {
    super.initState();
    print('📜 CommentsSection - initState');
    _initScrollController();
  }

  void _initScrollController() {
    print('📜 CommentsSection - Inicializando ScrollController');
    _scrollController = widget.scrollController ?? ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isScrollControllerAttached = true;
        });
        print('📜 CommentsSection - ScrollController inicializado y attached');
      }
    });
  }

  @override
  void dispose() {
    print('📜 CommentsSection - dispose');
    if (widget.scrollController == null && _scrollController.hasClients) {
      _scrollController.dispose();
    }
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    print('🔍 Iniciando selección de archivo para comentario');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
        allowMultiple: false,
      );

      if (result != null) {
        print('📎 Archivo seleccionado: ${result.files.first.name} (${_formatFileSize(result.files.first.size)})');
        setState(() {
          _selectedFile = result.files.first;
        });
      } else {
        print('❌ No se seleccionó ningún archivo');
      }
    } catch (e) {
      print('❌ Error al seleccionar archivo: $e');
    }
  }

  Future<void> _addComment(BuildContext context) async {
    if (_commentController.text.trim().isEmpty && _selectedFile == null) return;

    print('📝 Iniciando publicación de comentario');
    if (_selectedFile != null) {
      print('📎 Archivo adjunto detectado: ${_selectedFile!.name}');
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparando...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Usuario no autenticado');
        return;
      }

      String? fileUrl;
      String? fileName;
      int? fileSize;
      String? fileType;

      if (_selectedFile != null) {
        print('📤 Iniciando subida de archivo adjunto');
        setState(() {
          _uploadStatus = 'Subiendo archivo...';
        });

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${timestamp}_${_selectedFile!.name}';
        print('📋 Nombre único generado: $uniqueFileName');
        
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('projects')
            .child(widget.projectId)
            .child('comments')
            .child(uniqueFileName);

        late UploadTask uploadTask;
        if (kIsWeb) {
          print('🌐 Subiendo archivo en entorno web');
          uploadTask = storageRef.putData(
            _selectedFile!.bytes!,
            SettableMetadata(
              contentType: _selectedFile!.extension == 'pdf' ? 'application/pdf' :
                          _selectedFile!.extension == 'doc' || _selectedFile!.extension == 'docx' ? 'application/msword' :
                          _selectedFile!.extension == 'xls' || _selectedFile!.extension == 'xlsx' ? 'application/vnd.ms-excel' :
                          'image/${_selectedFile!.extension}',
            ),
          );
        } else {
          print('📱 Subiendo archivo en entorno móvil/desktop');
          final filePath = _selectedFile!.path!;
          final file = File(filePath);
          uploadTask = storageRef.putFile(file);
        }

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('📊 Progreso de subida: ${(progress * 100).toStringAsFixed(2)}%');
          setState(() {
            _uploadProgress = progress;
          });
        });

        try {
          print('⏳ Esperando finalización de subida...');
          final snapshot = await uploadTask;
          fileUrl = await snapshot.ref.getDownloadURL();
          fileName = _selectedFile!.name;
          fileSize = _selectedFile!.size;
          fileType = _selectedFile!.extension;
          print('✅ Archivo subido exitosamente. URL: $fileUrl');
        } catch (e) {
          print('❌ Error durante la subida del archivo: $e');
          setState(() {
            _isUploading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir el archivo: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      print('💾 Guardando comentario en Firestore');
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'userId': user.uid,
        'createdAt': Timestamp.now(),
        'attachment': fileUrl != null ? {
          'url': fileUrl,
          'name': fileName,
          'size': fileSize,
          'type': fileType,
        } : null,
      });

      print('✅ Comentario publicado exitosamente');
      _commentController.clear();
      setState(() {
        _selectedFile = null;
        _isUploading = false;
        _uploadProgress = 0.0;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comentario publicado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error general al publicar comentario: $e');
      setState(() {
        _isUploading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al publicar el comentario: ${e.toString()}'),
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

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      if (kIsWeb) {
        html.window.open(url, '_blank');
      } else {
        final response = await http.get(Uri.parse(url));
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/$fileName';
        final fileIO = File(filePath);
        await fileIO.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      print('Error al descargar archivo: $e');
    }
  }

  Widget _buildAttachmentPreview(Map<String, dynamic> attachment) {
    IconData iconData;
    Color iconColor;
    Color bgColor;
    
    switch (attachment['type']?.toString().toLowerCase()) {
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

    return Container(
      margin: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _downloadFile(
            attachment['url'],
            attachment['name'],
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatFileSize(attachment['size']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: iconColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment, Map<String, dynamic>? attachment, String commentId) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(comment['userId'])
                .get(),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final userName = userData?['displayName'] ?? userData?['email'] ?? 'Usuario';
              
              return Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Text(
                          userName[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy, HH:mm').format(
                              (comment['createdAt'] as Timestamp).toDate(),
                            ),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (FirebaseAuth.instance.currentUser?.uid == comment['userId'])
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                        onPressed: () => _showDeleteConfirmation(commentId, attachment),
                      ),
                  ],
                ),
              );
            },
          ),

          if (comment['text']?.isNotEmpty ?? false)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                comment['text'],
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.grey[800],
                ),
              ),
            ),

          if (attachment != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildAttachmentPreview(attachment),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          Expanded(
            child: !_isScrollControllerAttached
              ? const Center(child: CircularProgressIndicator())
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('❌ Error en StreamBuilder: ${snapshot.error}');
                        return Center(
                          child: Text('Error al cargar los comentarios: ${snapshot.error}'),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final comments = snapshot.data!.docs;
                      print('📜 Número de comentarios cargados: ${comments.length}');

                      if (comments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay comentarios aún',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sé el primero en comentar',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          print('📜 Construyendo comentario $index');
                          final comment = comments[index].data() as Map<String, dynamic>;
                          final attachment = comment['attachment'] as Map<String, dynamic>?;
                          return _buildCommentCard(comment, attachment, comments[index].id);
                        },
                      );
                    },
                  ),
                ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                if (_isUploading) ...[
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _uploadStatus,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_selectedFile != null && !_isUploading)
                  Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _selectedFile!.name,
                            style: TextStyle(color: Colors.blue),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        InkWell(
                          onTap: () => setState(() => _selectedFile = null),
                          child: Icon(Icons.close, size: 16, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.attach_file),
                              color: Colors.grey[600],
                              onPressed: !_isUploading ? _pickFile : null,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                enabled: !_isUploading,
                                maxLines: null,
                                decoration: InputDecoration(
                                  hintText: 'Escribe un comentario...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _isUploading ? Colors.grey : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(_isUploading ? Icons.hourglass_empty : Icons.send),
                        color: Colors.white,
                        onPressed: !_isUploading ? () => _addComment(context) : null,
                      ),
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

  Future<void> _deleteComment(String commentId, Map<String, dynamic>? attachment) async {
    print('🗑️ Iniciando eliminación de comentario: $commentId');
    try {
      if (attachment != null && attachment['url'] != null) {
        print('🗑️ Eliminando archivo adjunto: ${attachment['name']}');
        final fileUrl = attachment['url'] as String;
        final ref = FirebaseStorage.instance.refFromURL(fileUrl);
        await ref.delete();
        print('✅ Archivo adjunto eliminado correctamente');
      }

      print('🗑️ Eliminando comentario de Firestore');
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('comments')
          .doc(commentId)
          .delete();

      print('✅ Comentario eliminado completamente');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comentario eliminado')),
      );
    } catch (e) {
      print('❌ Error al eliminar comentario: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar el comentario'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(String commentId, Map<String, dynamic>? attachment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Eliminar comentario'),
          ],
        ),
        content: Text('¿Estás seguro de que quieres eliminar este comentario?${attachment != null ? '\nSe eliminará también el archivo adjunto.' : ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteComment(commentId, attachment);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
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