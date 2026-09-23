import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'bulk_upload_service.dart';
import 'student_controller.dart';

class BulkUploadDialog extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final StudentController studentController;

  const BulkUploadDialog({
    Key? key,
    required this.schoolId,
    required this.schoolName,
    required this.studentController,
  }) : super(key: key);

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  final BulkUploadService _uploadService = BulkUploadService();
  late final StudentController _studentController;

  List<StudentRow>? _students;
  bool _isLoading = false;
  bool _isValidating = false;
  bool _isImporting = false;
  String? _errorMessage;
  Map<String, dynamic>? _importResult;

  @override
  void initState() {
    super.initState();
    _studentController = widget.studentController;
  }

  Future<void> _pickAndParseFile() async {
    try {
      // Pick Excel file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() {
          _errorMessage = 'Failed to read file';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _students = null;
        _importResult = null;
      });

      // Parse Excel file
      final students = await _uploadService.parseExcelFile(file.bytes!);

      setState(() {
        _isLoading = false;
        _isValidating = true;
      });

      // Validate against database
      await _uploadService.validateStudents(students, widget.schoolId);

      setState(() {
        _students = students;
        _isValidating = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isValidating = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _importStudents() async {
    if (_students == null) return;

    final validStudents = _students!.where((s) => s.isValid).toList();
    
    if (validStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid students to import'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm import
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Text(
          'Import ${validStudents.length} valid student(s)?\n'
          '${_students!.length - validStudents.length} student(s) will be skipped due to validation errors.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final result = await _uploadService.bulkCreateStudents(
        validStudents,
        widget.schoolId,
        widget.schoolName,
      );

      setState(() {
        _importResult = result;
        _isImporting = false;
      });

      // Show result dialog
      final hasSuccess = result['success'] > 0;
      final hasFailed = result['failed'] > 0;
      final errors = result['errors'] as List<String>? ?? [];
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                hasSuccess ? Icons.check_circle : Icons.error,
                color: hasSuccess ? Colors.green : Colors.red,
                size: 32,
              ),
              SizedBox(width: 12),
              Text(hasSuccess ? 'Import Complete' : 'Import Failed'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSuccess) ...[
                  Text(
                    'Successfully imported ${result['success']} student(s)!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Students can now log in to the mobile app with their email and password from the Excel file.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8),
                ],
                if (hasFailed) ...[
                  Text(
                    '${result['failed']} student(s) failed:',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  // Use SizedBox + SingleChildScrollView instead of ListView to avoid intrinsic size crash
                  SizedBox(
                    height: errors.length > 4 ? 200 : null,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: errors.map((e) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• $e',
                            style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close result dialog
                if (hasSuccess) {
                  Navigator.of(context).pop(); // Close bulk upload dialog
                }
              },
              child: Text('OK'),
            ),
          ],
        ),
      );

      // Refresh student list (admin is still logged in)
      if (hasSuccess) {
        _studentController.fetchStudents();
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _errorMessage = 'Import failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bulk Student Upload',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Excel Format Required (8 columns):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Name | 2. Roll Number | 3. Class | 4. Password (DOB) | '
                    '5. Bus Number | 6. Route Name | 7. Stopping | 8. Email',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Auto-populated fields: Notification Type (Voice), Language (English), '
                    'Notification Preference (Time), Notification Time (10 minutes)',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // File picker button
            ElevatedButton.icon(
              onPressed: _isLoading || _isValidating || _isImporting ? null : _pickAndParseFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select Excel File'),
            ),
            const SizedBox(height: 16),

            // Loading/Error states
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_isValidating)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Validating students...'),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!)),
                  ],
                ),
              ),

            // Import result
            if (_importResult != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Complete: ${_importResult!['success']} successful, '
                      '${_importResult!['failed']} failed',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if ((_importResult!['errors'] as List).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...(_importResult!['errors'] as List).map((error) => Text(
                            '• $error',
                            style: const TextStyle(fontSize: 12),
                          )),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Student table
            if (_students != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parsed Students: ${_students!.length} '
                    '(${_students!.where((s) => s.isValid).length} valid, '
                    '${_students!.where((s) => !s.isValid).length} invalid)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isImporting ? null : _importStudents,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isImporting ? 'Importing...' : 'Import Valid Students'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                      columns: const [
                        DataColumn(label: Text('Row', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Class', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Bus', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Route', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Stop', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Password', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _students!.map((student) {
                        return DataRow(
                          color: MaterialStateProperty.all(
                            student.isValid ? null : Colors.red.shade50,
                          ),
                          cells: [
                            DataCell(Text(student.rowNumber.toString())),
                            DataCell(Text(student.name)),
                            DataCell(Text(student.rollNumber)),
                            DataCell(Text(student.studentClass)),
                            DataCell(Text(student.busNumber)),
                            DataCell(Text(student.routeName)),
                            DataCell(Text(student.stopping)),
                            DataCell(Text(student.email)),
                            DataCell(Text(student.password, style: const TextStyle(fontFamily: 'monospace'))),
                            DataCell(
                              student.isValid
                                  ? const Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                                        SizedBox(width: 4),
                                        Text('Valid'),
                                      ],
                                    )
                                  : Tooltip(
                                      message: student.errors.join('\n'),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error, color: Colors.red, size: 20),
                                          const SizedBox(width: 4),
                                          Text('${student.errors.length} error(s)'),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
