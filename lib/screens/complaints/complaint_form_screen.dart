import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/complaint_model.dart';
import '../../providers/complaint_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ComplaintFormScreen extends ConsumerStatefulWidget {
  final String? complaintId;

  const ComplaintFormScreen({super.key, this.complaintId});

  @override
  ConsumerState<ComplaintFormScreen> createState() =>
      _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends ConsumerState<ComplaintFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'Water Supply';
  String _department = 'Municipal Water Board';
  String _district = 'Central District';
  String _priority = 'Medium';
  bool _isLoading = false;

  final categories = const [
    'Water Supply',
    'Road Maintenance',
    'Electricity & Power',
    'Sanitation & Garbage',
    'Healthcare Services',
    'Public Transport',
  ];

  final departments = const [
    'Municipal Water Board',
    'Public Works Department',
    'State Power Distribution Corp',
    'Urban Sanitation & Waste Mgmt',
    'Department of Health',
    'Transport Authority',
  ];

  final districts = const [
    'Central District',
    'North District',
    'South District',
    'East District',
    'West District',
  ];

  final priorities = const ['Low', 'Medium', 'High', 'Urgent'];

  ComplaintModel? _existingComplaint;

  @override
  void initState() {
    super.initState();
    if (widget.complaintId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingData();
      });
    }
  }

  void _loadExistingData() {
    final list = ref.read(complaintProvider).complaints;
    final match = list.where((c) => c.id == widget.complaintId).firstOrNull;
    if (match != null) {
      setState(() {
        _existingComplaint = match;
        _titleController.text = match.title;
        _descriptionController.text = match.description;
        _category = match.category;
        _department = match.department;
        _district = match.district;
        _priority = match.priority;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the validation errors above.'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final notifier = ref.read(complaintProvider.notifier);

    if (_existingComplaint != null) {
      // Update
      final updated = _existingComplaint!.copyWith(
        title: _titleController.text.trim(),
        category: _category,
        department: _department,
        district: _district,
        description: _descriptionController.text.trim(),
        priority: _priority,
      );
      await notifier.updateComplaint(updated);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complaint ${updated.id} updated successfully.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } else {
      // Create new
      final created = await notifier.createComplaint(
        title: _titleController.text.trim(),
        category: _category,
        department: _department,
        district: _district,
        description: _descriptionController.text.trim(),
        priority: _priority,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (created != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Grievance registered under ID: ${created.id}'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to save grievance. Please check login session.',
              ),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.complaintId != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isEdit
              ? 'Edit Grievance ${widget.complaintId}'
              : 'File New Grievance',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title Field
                    CustomTextField(
                      controller: _titleController,
                      label: 'Complaint Title',
                      hint: 'e.g., Water Pipe Leakage in Main Market',
                      prefixIcon: Icons.title_rounded,
                      validator: (v) =>
                          Validators.validateRequired(v, 'Complaint Title'),
                    ),
                    const SizedBox(height: 18),

                    // Category Dropdown
                    _buildDropdown(
                      label: 'Category',
                      value: _category,
                      items: categories,
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                    const SizedBox(height: 18),

                    // Department Dropdown
                    _buildDropdown(
                      label: 'Department',
                      value: _department,
                      items: departments,
                      onChanged: (val) => setState(() => _department = val!),
                    ),
                    const SizedBox(height: 18),

                    // District Dropdown
                    _buildDropdown(
                      label: 'District',
                      value: _district,
                      items: districts,
                      onChanged: (val) => setState(() => _district = val!),
                    ),
                    const SizedBox(height: 18),

                    // Priority Segmented/Dropdown
                    _buildDropdown(
                      label: 'Priority Level',
                      value: _priority,
                      items: priorities,
                      onChanged: (val) => setState(() => _priority = val!),
                    ),
                    const SizedBox(height: 18),

                    // Description Field
                    const Text(
                      'Detailed Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      validator: (v) =>
                          Validators.validateRequired(v, 'Description'),
                      decoration: const InputDecoration(
                        hintText:
                            'Describe the issue clearly, including location details and impact...',
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    CustomButton(
                      text: isEdit ? 'Update Grievance' : 'Submit Grievance',
                      onPressed: _handleSubmit,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}
