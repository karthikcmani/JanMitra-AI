import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/grievance_provider.dart';
import '../../theme/app_theme.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final TextEditingController _queryController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>>? _results;
  String? _errorMessage;

  static const List<String> _suggestedQueries = [
    'Panchayat Raj Act road maintenance & culvert repair',
    'Kerala Water Authority (KWA) supply connection & pipeline leakage',
    'Kerala State Electricity Board (KSEB) power outage & transformer',
    'Municipality Act waste management & public sanitation',
    'Disaster Management Act relief compensation & emergency repair',
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(grievanceRepositoryProvider);
      final list = await repo.searchKnowledgeBase(query.trim());
      if (mounted) {
        setState(() {
          _results = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Search failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('JanMitra AI — Legal & Policy Intelligence'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F4C81), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.balance_rounded, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Statutory Knowledge & RAG Intelligence',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Search official Kerala state government Acts, Municipal Codes, Electricity & Water regulations for statutory provisions, citizen rights, and required petition documents.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search Bar Input
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _queryController,
                            decoration: const InputDecoration(
                              hintText: 'Search laws, citizen rights, rules (e.g. KWA pipeline, PWD road)...',
                              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
                              border: InputBorder.none,
                            ),
                            onSubmitted: _performSearch,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _performSearch(_queryController.text),
                          icon: _isLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text('Sample Statutory Queries:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _suggestedQueries.map((q) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ActionChip(
                              label: Text(q, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.blue.shade50,
                              onPressed: () {
                                _queryController.text = q;
                                _performSearch(q);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Error Message Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.danger),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            // Search Results Section
            if (_results != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Retrieved Statutory Results (${_results!.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _queryController.clear();
                        _results = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_results!.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('No matching statutory provisions found for your search term.'),
                    ),
                  ),
                )
              else
                ..._results!.map((item) {
                  final title = item['title'] ?? item['act_name'] ?? 'Government Act / Code';
                  final section = item['section_number'] ?? item['section'] ?? '';
                  final content = item['content'] ?? item['text'] ?? '';
                  final category = item['category'] ?? item['domain'] ?? 'General Admin';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$title ${section.isNotEmpty ? "— Section $section" : ""}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            content,
                            style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}
