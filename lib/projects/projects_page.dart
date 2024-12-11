import 'package:flutter/material.dart';
import 'project_card.dart';

class ProjectsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Proyectos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proyectos en curso',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ProjectCard(
              title: 'Landing page design',
              dueDate: '25 Apr',
              status: 'In Progress',
              statusColor: Colors.purple,
            ),
            SizedBox(height: 16),
            ProjectCard(
              title: 'Mobile App UI',
              dueDate: '1 May',
              status: 'Planning',
              statusColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
