import 'package:flutter_test/flutter_test.dart';
import 'package:janmitra_ai/models/grievance_model.dart';
import 'package:janmitra_ai/providers/grievance_provider.dart';

void main() {
  group('Grievance Intake & Multimodal Models Test', () {
    test('GrievanceModel parses FastAPI json response correctly', () {
      final json = {
        'id': 'grv-12345',
        'grievance_number': 'JM-2026-00001234',
        'citizen_id': 'user-999',
        'title': 'Handwritten Petition Intake: petition_page1.jpg',
        'intake_mode': 'ocr_handwritten',
        'original_language': 'ml',
        'original_text': 'വാർഡ് 5 ൽ കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു.',
        'status': 'intake_received',
        'priority': 'medium',
        'created_at': '2026-08-15T00:00:00.000Z',
        'updated_at': '2026-08-15T00:00:00.000Z',
      };

      final model = GrievanceModel.fromJson(json);
      expect(model.id, 'grv-12345');
      expect(model.grievanceNumber, 'JM-2026-00001234');
      expect(model.intakeMode, 'ocr_handwritten');
      expect(model.originalLanguage, 'ml');
      expect(model.originalText, 'വാർഡ് 5 ൽ കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു.');
    });

    test('NormalizedExtractionResultModel parses backend OCR response', () {
      final json = {
        'source_type': 'handwritten_petition',
        'source_attachment_id': 'att-888',
        'original_language': 'ml',
        'extracted_text': 'റോഡ് പണി ഉടൻ പൂർത്തിയാക്കണം.',
        'extraction_status': 'completed',
        'confidence_score': 0.92,
        'engine_name': 'google_cloud_vision_v1',
        'processed_at': '2026-08-15T00:00:00.000Z',
      };

      final result = NormalizedExtractionResultModel.fromJson(json);
      expect(result.sourceType, 'handwritten_petition');
      expect(result.extractedText, 'റോഡ് പണി ഉടൻ പൂർത്തിയാക്കണം.');
      expect(result.extractionStatus, 'completed');
      expect(result.confidenceScore, 0.92);
      expect(result.engineName, 'google_cloud_vision_v1');
    });

    test('GrievanceIntakeState initial state defaults correctly', () {
      const state = GrievanceIntakeState();
      expect(state.intakeMode, 'ocr_handwritten');
      expect(state.extractionStep, IntakeExtractionStep.idle);
      expect(state.isConfirmed, false);
      expect(state.rawExtractedText, null);
    });
  });
}
