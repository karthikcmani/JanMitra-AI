class GrievanceValidationResult {
  final bool isValid;
  final bool isChitChat;
  final bool isTooShort;
  final bool isUnreadable;
  final String? reason;
  final String? suggestion;

  const GrievanceValidationResult({
    required this.isValid,
    required this.isChitChat,
    required this.isTooShort,
    this.isUnreadable = false,
    this.reason,
    this.suggestion,
  });
}

class GrievanceValidator {
  static const Set<String> _civicKeywords = {
    // Malayalam Civic & Complaint Keywords
    'പവർ കട്ട്', 'പവർകട്ട്', 'വൈദ്യുതി', 'കറണ്ട്', 'വോൾട്ടേജ്', 'പോസ്റ്റ്', 'കമ്പി', 'ലൈൻ', 'ട്രാൻസ്ഫോർമർ',
    'വെള്ളം', 'കുടിവെള്ളം', 'പൈപ്പ്', 'ചോർച്ച', 'പൊട്ടി', 'കിട്ടുന്നില്ല', 'വിതരണം', 'ജല അതോറിറ്റി',
    'റോഡ്', 'കുഴി', 'കുഴികൾ', 'ടാർ', 'ടാറിങ്', 'പാലം', 'കലുങ്ക്', 'ഗതാഗതം', 'നടപ്പാത',
    'ഓട', 'അഴുക്കുചാൽ', 'മാലിന്യം', 'പ്ലാസ്റ്റിക്', 'ദുർഗന്ധം', 'ശുചീകരണം', 'കൊതുക്', 'മാലിന്യ',
    'പഞ്ചായത്ത്', 'മുനിസിപ്പാലിറ്റി', 'കോർപ്പറേഷൻ', 'വില്ലേജ്', 'താലൂക്ക്', 'റവന്യൂ', 'തഹസിൽദാർ',
    'ഭൂമി', 'പട്ടയം', 'കയ്യേറ്റം', 'അളന്നു', 'സർവേ', 'തോട്', 'കനാൽ', 'നീരൊഴുക്ക്', 'പുറമ്പോക്ക്',
    'റേഷൻ', 'സപ്ലൈകോ', 'ആശുപത്രി', 'പി.എച്ച്.സി', 'ഡോക്ടർ', 'മരുന്ന്',
    'തെരുവ് നായ', 'നായ്ക്കൾ', 'വന്യജീവി', 'പന്നി', 'ആന', 'മൃഗശല്യം', 'വിളക്ക്', 'സ്ട്രീറ്റ് ലൈറ്റ്', 'തെരുവ് വിളക്ക്',
    'പെൻഷൻ', 'ക്ഷേമനിധി', 'സർട്ടിഫിക്കറ്റ്', 'അനധികൃത', 'മലിനീകരണം', 'ശബ്ദം',
    'പരാതി', 'അപേക്ഷ', 'പരിഹാരം', 'പരിഹരിക്കണം', 'ശരിയാക്കണം', 'റിപ്പയർ', 'നടപടി', 'ബുദ്ധിമുട്ട്',
    'അടിയന്തര', 'നഷ്ടപരിഹാരം', 'തടസ്സം', 'കേടുപാടുകൾ', 'അറ്റകുറ്റപ്പണി', 'കുറയ്ക്കണം', 'മാറ്റണം',
    // English Civic & Complaint Keywords
    'water', 'pipe', 'pipeline', 'leak', 'leakage', 'burst', 'supply', 'drinking water',
    'road', 'roads', 'pothole', 'potholes', 'repair', 'tarring', 'bridge', 'culvert', 'traffic',
    'drain', 'drainage', 'gutter', 'waste', 'garbage', 'trash', 'dump', 'sanitation', 'sewage',
    'electricity', 'power', 'power cut', 'powercut', 'outage', 'blackout', 'voltage', 'transformer', 'pole', 'wire', 'kseb',
    'panchayat', 'municipality', 'corporation', 'village', 'taluk', 'revenue', 'tahsildar', 'collector',
    'land', 'encroachment', 'survey', 'resurvey', 'canal', 'stream', 'poramboke',
    'ration', 'hospital', 'phc', 'clinic', 'medicine', 'doctor', 'treatment',
    'dog', 'stray dog', 'animal', 'wildlife', 'street light', 'streetlight', 'lamp',
    'pension', 'certificate', 'license', 'permit', 'pollution', 'noise',
    'complaint', 'grievance', 'petition', 'request', 'issue', 'problem', 'solve', 'resolve',
    'fix', 'action', 'damage', 'broken', 'danger', 'hazard', 'overflow', 'stagnant',
  };

  static final List<RegExp> _chitchatRegexes = [
    // Malayalam Chitchat / Greetings / Small-talk
    RegExp(r'ഹാലോ|ഹലോ|ഹായ്|നമസ്കാരം|ഗുഡ്\s*മോർണിംഗ്|ഗുഡ്\s*ഈവനിംഗ്|സുപ്രഭാതം', caseSensitive: false),
    RegExp(r'സുഖമാണോ|സുഖമാണ്|സുഖമായിരിക്കുന്നു|എങ്ങനെയിരിക്കുന്നു', caseSensitive: false),
    RegExp(r'എന്റെ\s*പേര്|ഞാൻ\s*[a-zA-Z\u0d00-\u0d7f]+\s*ആണ്', caseSensitive: false),
    RegExp(r'വിശ്വസിക്കുന്നു|പ്രതീക്ഷിക്കുന്നു', caseSensitive: false),
    RegExp(r'ശരി\s*എന്നാൽ\s*ബൈ|ശരി\s*ബൈ|എന്നാൽ\s*ബൈ|ബൈ\s*ബൈ|ബൈ|ടാറ്റ', caseSensitive: false),
    RegExp(r'താങ്ക്\s*യു|നന്ദി|നന്ദിയുണ്ട്', caseSensitive: false),
    RegExp(r'ടെസ്റ്റ്|ടെസ്റ്റിംഗ്|ടെസ്റ്റിങ്', caseSensitive: false),
    // English Chitchat / Greetings / Small-talk
    RegExp(r'\b(hello|hi|hey|hai|good\s*morning|good\s*evening|good\s*afternoon)\b', caseSensitive: false),
    RegExp(r'\b(how\s*are\s*you|i\s*am\s*fine|hope\s*you\s*are\s*(well|fine)|doing\s*well)\b', caseSensitive: false),
    RegExp(r'\b(my\s*name\s*is|this\s*is|i\s*am)\b', caseSensitive: false),
    RegExp(r'\b(okay\s*then\s*bye|ok\s*bye|bye\s*bye|bye|goodbye|see\s*you)\b', caseSensitive: false),
    RegExp(r'\b(thank\s*you|thanks|cheers)\b', caseSensitive: false),
    RegExp(r'\b(test|testing|sample|demo)\b', caseSensitive: false),
  ];

  static final List<RegExp> _unreadableRegexes = [
    RegExp(r'\[\s*unreadable\s*\]', caseSensitive: false),
    RegExp(r'\bunreadable\b', caseSensitive: false),
    RegExp(r'\bcannot\s*read\b', caseSensitive: false),
    RegExp(r'\bblurry\b', caseSensitive: false),
    RegExp(r'\bno\s*text\s*(found|visible)\b', caseSensitive: false),
    RegExp(r'\bunable\s*to\s*transcribe\b', caseSensitive: false),
    RegExp(r'\bnot\s*readable\b', caseSensitive: false),
  ];

  static GrievanceValidationResult validateGrievanceText(String? text) {
    if (text == null || text.trim().isEmpty) {
      return const GrievanceValidationResult(
        isValid: false,
        isChitChat: false,
        isTooShort: true,
        reason: 'Petition text cannot be empty.',
        suggestion: 'Please describe your grievance or civic issue.',
      );
    }

    final cleanText = text.trim();

    if (cleanText.length < 8) {
      return const GrievanceValidationResult(
        isValid: false,
        isChitChat: false,
        isTooShort: true,
        reason: 'Petition text is too short to explain an administrative issue.',
        suggestion: 'Please provide a clear description of the civic problem or service required.',
      );
    }

    final textLower = cleanText.toLowerCase();

    // Check if any civic issue keyword is present
    final hasCivicIssue = _civicKeywords.any((k) => textLower.contains(k.toLowerCase()));

    // Check for unreadable / non-document OCR output
    final coreBody = cleanText.split(RegExp(r'---\s*EXTRACTED KEYWORDS', caseSensitive: false)).first.trim();
    final cleanedCore = coreBody
        .replaceAll(RegExp(r'\[\s*unreadable\s*\]|\bunreadable\b|\bblurry\b|\bcannot\s*read\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\s\W_]+', unicode: true), '');

    final bool hasUnreadableSignal = _unreadableRegexes.any((r) => r.hasMatch(textLower));
    final bool hasUnreadableTitle = RegExp(r'Subject Title:\s*\[?Unreadable\]?', caseSensitive: false).hasMatch(cleanText);

    if ((hasUnreadableSignal && !hasCivicIssue) || (hasUnreadableTitle && cleanedCore.length < 20)) {
      return const GrievanceValidationResult(
        isValid: false,
        isChitChat: false,
        isTooShort: false,
        isUnreadable: true,
        reason: 'The captured document image could not be read or does not contain a recognizable grievance petition.',
        suggestion: 'Please take a clear, well-lit photo of the physical petition or handwritten complaint.',
      );
    }

    // Count how many chitchat signals match
    final hasChitChat = _chitchatRegexes.any((r) => r.hasMatch(textLower));

    // If civic issue is present, it's valid regardless of friendly greetings
    if (hasCivicIssue) {
      return const GrievanceValidationResult(
        isValid: true,
        isChitChat: false,
        isTooShort: false,
      );
    }

    // If NO civic issue is mentioned and chitchat matches, it's strictly non-grievance
    if (hasChitChat) {
      final preview = cleanText.length > 50 ? '${cleanText.substring(0, 50)}...' : cleanText;
      return GrievanceValidationResult(
        isValid: false,
        isChitChat: true,
        isTooShort: false,
        reason:
            "The entered text ('$preview') appears to be a casual greeting or personal conversation rather than a valid public grievance.",
        suggestion:
            'Government grievances must describe an actual civic issue (such as road damage, water supply, electricity cut, garbage, or land survey). Please describe your issue before submitting.',
      );
    }

    // If text is relatively long (>35 chars) with multiple words, treat as custom complaint
    final words = cleanText.split(RegExp(r'\s+'));
    if (words.length >= 6 && cleanText.length >= 30) {
      return const GrievanceValidationResult(
        isValid: true,
        isChitChat: false,
        isTooShort: false,
      );
    }

    return const GrievanceValidationResult(
      isValid: false,
      isChitChat: false,
      isTooShort: true,
      reason: 'The petition does not clearly describe a civic complaint or public service issue.',
      suggestion: 'Please describe the specific issue (e.g. what is broken, where, and what action is requested).',
    );
  }
}
