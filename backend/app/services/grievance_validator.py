import re
from typing import NamedTuple, Optional, Tuple

class GrievanceValidationResult(NamedTuple):
    is_valid: bool
    is_chitchat: bool
    is_too_short: bool
    is_unreadable: bool = False
    reason: Optional[str] = None
    suggestion: Optional[str] = None


CIVIC_KEYWORDS = {
    # Malayalam Civic & Complaint Keywords
    "പവർ കട്ട്", "പവർകട്ട്", "വൈദ്യുതി", "കറണ്ട്", "വോൾട്ടേജ്", "പോസ്റ്റ്", "കമ്പി", "ലൈൻ", "ട്രാൻസ്ഫോർമർ",
    "വെള്ളം", "കുടിവെള്ളം", "പൈപ്പ്", "ചോർച്ച", "പൊട്ടി", "കിട്ടുന്നില്ല", "വിതരണം", "ജല അതോറിറ്റി",
    "റോഡ്", "കുഴി", "കുഴികൾ", "ടാർ", "ടാറിങ്", "പാലം", "കലുങ്ക്", "ഗതാഗതം", "നടപ്പാത",
    "ഓട", "അഴുക്കുചാൽ", "മാലിന്യം", "പ്ലാസ്റ്റിക്", "ദുർഗന്ധം", "ശുചീകരണം", "കൊതുക്", "മാലിന്യ",
    "പഞ്ചായത്ത്", "മുനിസിപ്പാലിറ്റി", "കോർപ്പറേഷൻ", "വില്ലേജ്", "താലൂക്ക്", "റവന്യൂ", "തഹസിൽദാർ",
    "ഭൂമി", "പട്ടയം", "കയ്യേറ്റം", "അളന്നു", "സർവേ", "തോട്", "കനാൽ", "നീരൊഴുക്ക്", "പുറമ്പോക്ക്",
    "റേഷൻ", "സപ്ലൈകോ", "ആശുപത്രി", "പി.എച്ച്.സി", "ഡോക്ടർ", "മരുന്ന്",
    "തെരുവ് നായ", "നായ്ക്കൾ", "വന്യജീവി", "പന്നി", "ആന", "മൃഗശല്യം", "വിളക്ക്", "സ്ട്രീറ്റ് ലൈറ്റ്", "തെരുവ് വിളക്ക്",
    "പെൻഷൻ", "ക്ഷേമനിധി", "സർട്ടിഫിക്കറ്റ്", "അനധികൃത", "മലിനീകരണം", "ശബ്ദം",
    "പരാതി", "അപേക്ഷ", "പരിഹാരം", "പരിഹരിക്കണം", "ശരിയാക്കണം", "റിപ്പയർ", "നടപടി", "ബുദ്ധിമുട്ട്",
    "അടിയന്തര", "നഷ്ടപരിഹാരം", "തടസ്സം", "കേടുപാടുകൾ", "അറ്റകുറ്റപ്പണി", "കുറയ്ക്കണം", "മാറ്റണം",
    # English Civic & Complaint Keywords
    "water", "pipe", "pipeline", "leak", "leakage", "burst", "supply", "drinking water",
    "road", "roads", "pothole", "potholes", "repair", "tarring", "bridge", "culvert", "traffic",
    "drain", "drainage", "gutter", "waste", "garbage", "trash", "dump", "sanitation", "sewage",
    "electricity", "power", "power cut", "powercut", "outage", "blackout", "voltage", "transformer", "pole", "wire", "kseb",
    "panchayat", "municipality", "corporation", "village", "taluk", "revenue", "tahsildar", "collector",
    "land", "encroachment", "survey", "resurvey", "canal", "stream", "poramboke",
    "ration", "hospital", "phc", "clinic", "medicine", "doctor", "treatment",
    "dog", "stray dog", "animal", "wildlife", "street light", "streetlight", "lamp",
    "pension", "certificate", "license", "permit", "pollution", "noise",
    "complaint", "grievance", "petition", "request", "issue", "problem", "solve", "resolve",
    "fix", "action", "damage", "broken", "danger", "hazard", "overflow", "stagnant",
}

CHITCHAT_PATTERNS = [
    # Malayalam Chitchat / Greetings / Small-talk
    r"ഹാലോ|ഹലോ|ഹായ്|നമസ്കാരം|ഗുഡ്\s*മോർണിംഗ്|ഗുഡ്\s*ഈവനിംഗ്|സുപ്രഭാതം",
    r"സുഖമാണോ|സുഖമാണ്|സുഖമായിരിക്കുന്നു|എങ്ങനെയിരിക്കുന്നു",
    r"എന്റെ\s*പേര്|ഞാൻ\s*[a-zA-Z\u0d00-\u0d7f]+\s*ആണ്",
    r"വിശ്വസിക്കുന്നു|പ്രതീക്ഷിക്കുന്നു",
    r"ശരി\s*എന്നാൽ\s*ബൈ|ശരി\s*ബൈ|എന്നാൽ\s*ബൈ|ബൈ\s*ബൈ|ബൈ|ടാറ്റ",
    r"താങ്ക്\s*യു|നന്ദി|നന്ദിയുണ്ട്",
    r"ടെസ്റ്റ്|ടെസ്റ്റിംഗ്|ടെസ്റ്റിങ്",
    # English Chitchat / Greetings / Small-talk
    r"\b(hello|hi|hey|hai|good\s*morning|good\s*evening|good\s*afternoon)\b",
    r"\b(how\s*are\s*you|i\s*am\s*fine|hope\s*you\s*are\s*(well|fine)|doing\s*well)\b",
    r"\b(my\s*name\s*is|this\s*is|i\s*am)\b",
    r"\b(okay\s*then\s*bye|ok\s*bye|bye\s*bye|bye|goodbye|see\s*you)\b",
    r"\b(thank\s*you|thanks|cheers)\b",
    r"\b(test|testing|sample|demo)\b",
]

COMPILED_CHITCHAT = [re.compile(p, re.IGNORECASE) for p in CHITCHAT_PATTERNS]

UNREADABLE_PATTERNS = [
    r"\[\s*unreadable\s*\]",
    r"\bunreadable\b",
    r"\bcannot\s*read\b",
    r"\bblurry\b",
    r"\bno\s*text\s*found\b",
    r"\bno\s*text\s*visible\b",
    r"\bunable\s*to\s*transcribe\b",
    r"\bnot\s*readable\b",
]

COMPILED_UNREADABLE = [re.compile(p, re.IGNORECASE) for p in UNREADABLE_PATTERNS]


def validate_grievance_text(text: Optional[str]) -> GrievanceValidationResult:
    """Validates whether petition text contains a genuine civic grievance or is casual small-talk/unreadable/gibberish."""
    if not text or not text.strip():
        return GrievanceValidationResult(
            is_valid=False,
            is_chitchat=False,
            is_too_short=True,
            reason="Petition text cannot be empty.",
            suggestion="Please describe your grievance or civic issue.",
        )

    clean_text = text.strip()

    # Length check: grievances need sufficient detail
    if len(clean_text) < 10:
        return GrievanceValidationResult(
            is_valid=False,
            is_chitchat=False,
            is_too_short=True,
            reason="Petition text is too short to explain an administrative issue.",
            suggestion="Please provide a clear description of the civic problem or service required.",
        )

    text_lower = clean_text.lower()

    # Check for civic issue presence
    has_civic_issue = any(k in text_lower for k in CIVIC_KEYWORDS)

    # Check for unreadable / non-document OCR output
    core_body = re.split(r"---\s*EXTRACTED KEYWORDS", clean_text, flags=re.IGNORECASE)[0].strip()
    cleaned_core = re.sub(r"\[\s*unreadable\s*\]|\bunreadable\b|\bblurry\b|\bcannot\s*read\b", "", core_body, flags=re.IGNORECASE)
    cleaned_core = re.sub(r"[\s\W_]+", "", cleaned_core)

    has_unreadable_signal = any(p.search(clean_text) for p in COMPILED_UNREADABLE)
    has_unreadable_title = bool(re.search(r"Subject Title:\s*\[?Unreadable\]?", clean_text, re.IGNORECASE))

    if (has_unreadable_signal and not has_civic_issue) or (has_unreadable_title and len(cleaned_core) < 20):
        return GrievanceValidationResult(
            is_valid=False,
            is_chitchat=False,
            is_too_short=False,
            is_unreadable=True,
            reason="The captured document image could not be read or does not contain a recognizable grievance petition.",
            suggestion="Please take a clear, well-lit photo of the physical petition or handwritten complaint.",
        )

    # Count how many chitchat signals match
    matched_chitchat = [p.pattern for p in COMPILED_CHITCHAT if p.search(text_lower)]

    # If it contains civic signals (e.g. power cut, road, water) it's valid, even if it starts with "Hello"
    if has_civic_issue:
        return GrievanceValidationResult(
            is_valid=True,
            is_chitchat=False,
            is_too_short=False,
        )

    # If NO civic issue is mentioned and chitchat matches, it's strictly non-grievance
    if matched_chitchat:
        preview = clean_text[:60] + ("..." if len(clean_text) > 60 else "")
        return GrievanceValidationResult(
            is_valid=False,
            is_chitchat=True,
            is_too_short=False,
            reason=(
                f"The submitted text ('{preview}') appears to be a casual greeting or personal conversation "
                "rather than a valid public grievance."
            ),
            suggestion=(
                "Government grievances must describe an actual civic issue (e.g. road damage, water supply, "
                "electricity outages, garbage disposal, land survey). Please describe your issue to submit."
            ),
        )

    # If text is relatively long (>35 chars) with diverse words, treat as valid custom complaint
    words = clean_text.split()
    if len(words) >= 6 and len(clean_text) >= 30:
        return GrievanceValidationResult(
            is_valid=True,
            is_chitchat=False,
            is_too_short=False,
        )

    # Fallback: very short unclassified text without any civic keywords
    return GrievanceValidationResult(
        is_valid=False,
        is_chitchat=False,
        is_too_short=True,
        reason="The petition does not clearly describe a civic complaint or public service issue.",
        suggestion="Please describe the specific issue (e.g. what is broken, where, and what action is requested).",
    )
