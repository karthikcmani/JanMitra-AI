import 'package:flutter/material.dart';

class OfficialDashboardScreen extends StatefulWidget {
  const OfficialDashboardScreen({super.key});

  @override
  State<OfficialDashboardScreen> createState() => _OfficialDashboardScreenState();
}

class _OfficialDashboardScreenState extends State<OfficialDashboardScreen> {
  final List<Map<String, dynamic>> _mockOfficialGrievances = [
    {
      'id': 'grv-001',
      'number': 'JM-2026-84920194',
      'citizen': 'Karthik C Mani',
      'phone': '9876543210',
      'title': 'വാർഡ് 5 കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു',
      'ocr_text': 'വാർഡ് 5 ൽ കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു. KWA പൈപ്പ് ലൈൻ ഉടൻ ശരിയാക്കണം.',
      'predicted_dept': 'Kerala Water Authority (KWA)',
      'status': 'UNDER_ANALYSIS',
      'act': 'Kerala Water Supply and Sewerage Act, 1986 (Sec 14)',
      'priority': 'HIGH',
    },
    {
      'id': 'grv-002',
      'number': 'JM-2026-91029381',
      'citizen': 'Ananya Nair',
      'phone': '9123456789',
      'title': 'റോഡിലെ കുഴികളും കലുങ്ക് നിർമ്മാണവും',
      'ocr_text': 'മെയിൻ റോഡിൽ കുഴികൾ രൂപപ്പെട്ടിരിക്കുന്നു. മഴപെയ്യുമ്പോൾ അപകടസാധ്യതയുണ്ട്.',
      'predicted_dept': 'Public Works Department (PWD)',
      'status': 'INTAKE_RECEIVED',
      'act': 'Kerala Highway Protection Act, 1999 (Sec 7)',
      'priority': 'MEDIUM',
    },
  ];

  void _showActionDialog(Map<String, dynamic> item) {
    final remarksController = TextEditingController();
    String selectedStatus = 'FORWARDED';
    String selectedDept = item['predicted_dept'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Official Action — ${item['number']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Citizen: ${item['citizen']} (${item['phone']})', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Extracted OCR Text:', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[100],
                child: Text(item['ocr_text'], style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 12),
              const Text('Target Department:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: selectedDept,
                isExpanded: true,
                items: [
                  'Kerala Water Authority (KWA)',
                  'Public Works Department (PWD)',
                  'Kerala State Electricity Board (KSEB)',
                  'Local Self Government Department (LSGD / Panchayat)',
                  'Revenue & General Administration',
                ]
                    .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedDept = val);
                },
              ),
              const SizedBox(height: 12),
              const Text('Official Action / Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: selectedStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'FORWARDED', child: Text('Approve & Forward to Department')),
                  DropdownMenuItem(value: 'CLARIFICATION_REQUIRED', child: Text('Request Citizen Clarification')),
                  DropdownMenuItem(value: 'RESOLVED', child: Text('Mark Resolved & Closed')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => selectedStatus = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Official Decision Remarks',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D)),
            onPressed: () {
              setState(() {
                item['status'] = selectedStatus;
                item['predicted_dept'] = selectedDept;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Action submitted for ${item['number']}')),
              );
            },
            child: const Text('Submit Action', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Official Copilot Dashboard'),
        backgroundColor: const Color(0xFF1B365D),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00A896).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00A896)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Color(0xFF00A896)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Welcome Official. Review document OCR extractions, statutory legal grounding, and approve department routing.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Grievances Awaiting Administrative Action',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _mockOfficialGrievances.length,
                itemBuilder: (context, idx) {
                  final item = _mockOfficialGrievances[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Chip(
                                label: Text(item['status'], style: const TextStyle(color: Colors.white, fontSize: 10)),
                                backgroundColor: item['status'] == 'FORWARDED'
                                    ? Colors.green
                                    : (item['status'] == 'CLARIFICATION_REQUIRED' ? Colors.orange : Colors.blue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Title: ${item['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Predicted Dept: ${item['predicted_dept']}', style: const TextStyle(color: Color(0xFF00A896), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Legal Grounding: ${item['act']}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B365D)),
                              onPressed: () => _showActionDialog(item),
                              icon: const Icon(Icons.gavel, size: 16, color: Colors.white),
                              label: const Text('Take Action', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
