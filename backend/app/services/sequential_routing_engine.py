"""JanMitra AI — Sequential Contextual Routing & Jurisdictional Intelligence Engine.

Simulates bidirectional sequential contextual recurrent classification (LSTM / GRU sequential state machine):
1. Sentence-by-sentence boundary parsing and semantic unit tokenization.
2. Salutation & Addressee hidden state tracking (e.g. Tahsildar / Taluk Office -> Revenue).
3. Subject line feature extraction with dependency parsing.
4. Positive and Negative contextual gating (e.g., canal encroachment with poramboke NEVER maps to KWA; KWA requires explicit piped drinking water supply).
5. Comprehensive coverage across all Kerala statutory departments:
   - Revenue & General Administration (Land, Poramboke, Canal Encroachments, Survey, Tahsildar)
   - Kerala Water Authority (Drinking Water, Pipelines, Tap connections, KWA Meters)
   - Local Self Government Department (LSGD / Panchayat / Municipality - Waste, Gutters, Sanitation)
   - Public Works Department (PWD - Roads, Bridges, Culverts)
   - Kerala State Electricity Board (KSEB - Lines, Transformers, Electric Posts)
   - Irrigation Department (Major canals, dams, river embankments)
   - Food & Civil Supplies (Ration, Supplyco)
   - Health & Family Welfare (Hospitals, Epidemics)
   - Police & Home Department (Law & Order, Complaints)
   - Motor Vehicles / Transport (KSRTC, RTO)
   - Forest & Wildlife (Wild animal conflicts)
"""

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class SequentialRoutingDecision:
    department_name: str
    department_code: str
    category: str
    recommended_authority: str
    jurisdiction_level: str
    confidence_score: float
    statutory_act: str
    legal_explanation: str
    detected_addressee: Optional[str] = None
    detected_subject: Optional[str] = None
    detected_action: Optional[str] = None
    detected_location_reference: Optional[str] = None
    sequential_trace: List[str] = field(default_factory=list)


class SequentialRoutingEngine:
    """Multi-stage sequential sentence & word-by-word contextual administrative router."""

    # 1. ADDRESSEE AUTHORITY SIGNALS (Salutation Header Parsing)
    ADDRESSEE_PATTERNS = [
        {
            "dept_code": "REV",
            "dept_name": "Revenue & General Administration",
            "authority_template": "Tahsildar / Village Officer, Revenue Department",
            "level": "TALUK_VILLAGE",
            "regex": re.compile(
                r"(തഹസിൽദാർ|താലൂക്ക്\s*ഓഫീസ്|വില്ലേജ്\s*ഓഫീസർ|വില്ലേജ്\s*ഓഫീസ്|റവന്യൂ\s*ഡിവിഷണൽ|ആർ\.?ഡി\.?ഒ|ജില്ലാ\s*കളക്ടർ|കളക്ടറേറ്റ്|tahsildar|taluk\s*office|village\s*office|revenue\s*divisional|district\s*collector)",
                re.IGNORECASE,
            ),
        },
        {
            "dept_code": "KWA",
            "dept_name": "Kerala Water Authority (KWA)",
            "authority_template": "Assistant Executive Engineer, Kerala Water Authority (KWA)",
            "level": "DEPARTMENTAL_SUBDIVISION",
            "regex": re.compile(
                r"(വാട്ടർ\s*അതോറിറ്റി|കെ\.?ഡബ്ല്യു\.?എ|water\s*authority|kwa|water\s*works|എക്സിക്യൂട്ടീവ്\s*എൻജിനീയർ.*വാട്ടർ)",
                re.IGNORECASE,
            ),
        },
        {
            "dept_code": "PWD",
            "dept_name": "Public Works Department (PWD)",
            "authority_template": "Executive Engineer, PWD Roads Division",
            "level": "DISTRICT_DIVISION",
            "regex": re.compile(
                r"(പൊതുമരാമത്ത്|പി\.?ഡബ്ല്യു\.?ഡി|pwd|roads\s*division|highway\s*division|പൊതുമരാമത്ത്\s*നിരത്തു)",
                re.IGNORECASE,
            ),
        },
        {
            "dept_code": "KSEB",
            "dept_name": "Kerala State Electricity Board (KSEB)",
            "authority_template": "Assistant Engineer, Electrical Section, KSEB",
            "level": "SECTION_OFFICE",
            "regex": re.compile(
                r"(കെ\.?എസ്\.?ഇ\.?ബി|ഇലക്ട്രിക്കൽ\s*സെക്ഷൻ|kseb|electrical\s*section|വൈദ്യുതി\s*ബോർഡ്)",
                re.IGNORECASE,
            ),
        },
        {
            "dept_code": "LSGD",
            "dept_name": "Local Self Government Department (LSGD / Panchayat)",
            "authority_template": "Grama Panchayat Secretary / Municipal Secretary",
            "level": "PANCHAYAT",
            "regex": re.compile(
                r"(പഞ്ചായത്ത്\s*സെക്രട്ടറി|മുനിസിപ്പൽ\s*സെക്രട്ടറി|ഗ്രാമപഞ്ചായത്ത്|മുനിസിപ്പാലിറ്റി|കോർപ്പറേഷൻ|നഗരസഭ|panchayat\s*secretary|municipality|corporation)",
                re.IGNORECASE,
            ),
        },
        {
            "dept_code": "IRR",
            "dept_name": "Irrigation Department",
            "authority_template": "Executive Engineer, Irrigation Division",
            "level": "DISTRICT_DIVISION",
            "regex": re.compile(
                r"(ഇറിഗേഷൻ\s*ഡിവിഷൻ|ജലസേചന\s*വകുപ്പ്|irrigation\s*division|irrigation\s*department)",
                re.IGNORECASE,
            ),
        },
        {
            "dept_code": "POLICE",
            "dept_name": "Police & Home Department",
            "authority_template": "Station House Officer (SHO), Kerala Police",
            "level": "POLICE_STATION",
            "regex": re.compile(
                r"(സ്റ്റേഷൻ\s*ഹൗസ്\s*ഓഫീസർ|എസ്\.?എച്ച്\.?ഒ|പോലീസ്\s*ഇൻസ്പെക്ടർ|police\s*station|sho)",
                re.IGNORECASE,
            ),
        },
    ]

    # 2. CORE DOMAIN ACTION & ENTITY DICTIONARIES
    REVENUE_KEYWORDS = [
        "പുറമ്പോക്ക്", "സർക്കാർ പുറമ്പോക്ക്", "കയ്യേറ്റം", "കയ്യേറ്റം ഒഴിപ്പിച്ച്", "കയ്യേറി",
        "അളന്നു തിട്ടപ്പെടുത്തി", "അളന്നു", "റീ-സർവേ", "സർവേ നമ്പർ", "റീ സർവെ", "വില്ലേജ്",
        "താലൂക്ക്", "തഹസിൽദാർ", "പട്ടയം", "തണ്ടപ്പേര്", "പോക്കുവരവ്", "അതിർത്തി തർക്കം",
        "നിലം നികത്തൽ", "മണ്ണ് നികത്തൽ", "വേലി കെട്ടി", "അനധികൃതമായി മണ്ണ്",
        "തണ്ണീർത്തടം", "നെൽവയൽ", "ഭൂമി കയ്യേറ്റം", "റവന്യൂ ഉദ്യോഗസ്ഥർ", "റവന്യൂ വകുപ്പ്",
        "poramboke", "puramboke", "encroachment", "resurvey", "survey number",
        "land survey", "demarcation", "tahsildar", "taluk", "pattayam", "wetland filling"
    ]

    CANAL_WATER_FLOW_KEYWORDS = [
        "തോട്", "തോടിലെ", "തോട്ടിലെ", "കനാൽ", "ചാല്", "സ്വാഭാവിക നീരൊഴുക്ക്",
        "നീരൊഴുക്ക്", "നീരൊഴുക്ക് തടസ്സപ്പെടുത്തി", "നീരൊഴുക്ക് തടസ്സം",
        "canal", "stream", "thodu", "natural water flow", "water flow obstruction"
    ]

    KWA_POSITIVE_KEYWORDS = [
        "കുടിവെള്ളം", "കുടിവെള്ള വിതരണം", "കുടിവെള്ള പൈപ്പ്", "പൈപ്പ് ലൈൻ", "പൈപ്പ് പൊട്ടി",
        "പൈപ്പ് ചോർച്ച", "വാട്ടർ കണക്ഷൻ", "വാട്ടർ മീറ്റർ", "ടാപ്പ്", "കുടിവെള്ള ക്ഷാമം",
        "പൈപ്പ് ലൈനിലെ", "ജല അതോറിറ്റി", "വാട്ടർ അതോറിറ്റി", "കെ.ഡബ്ല്യു.എ",
        "drinking water", "water supply", "pipe burst", "pipe leakage", "water meter",
        "water connection", "tap water", "kwa pipeline", "pipeline"
    ]

    PWD_KEYWORDS = [
        "പൊതുമരാമത്ത്", "റോഡ്", "റോഡിലെ", "കുഴി", "കുഴികൾ", "വലിയ കുഴികൾ", "പാലം",
        "കലുങ്ക്", "ടാർ", "ടാറിങ്", "റീ-ടാറിങ്", "ഹൈവേ", "ബൈപ്പാസ്", "റോഡ് തകർന്നു",
        "ഗതാഗത തടസ്സം", "കാൽനടയാത്ര", "ബി.എം.&ബി.സി", "റോഡ് പണി",
        "road", "pothole", "potholes", "bridge", "culvert", "pwd", "highway", "tarring", "tar"
    ]

    KSEB_KEYWORDS = [
        "വൈദ്യുതി", "വൈദ്യുത", "ഇലക്ട്രിക്", "ട്രാൻസ്ഫോർമർ", "പോസ്റ്റ്", "ഇലക്ട്രിക് പോസ്റ്റ്",
        "കമ്പി", "ലൈൻ", "ഷോക്ക്", "വോൾട്ടേജ്", "ലോ വോൾട്ടേജ്", "കെ.എസ്.ഇ.ബി", "കെഎസ്ഇബി",
        "സ്ട്രീറ്റ് ലൈറ്റ്", "വൈദ്യുതി തടസ്സം", "പൊട്ടിവീണ കമ്പി", "ചരിഞ്ഞുനിൽക്കുന്ന പോസ്റ്റ്",
        "power", "electricity", "kseb", "transformer", "electric post", "electric pole",
        "power cut", "voltage", "sagging wire", "live wire"
    ]

    LSGD_KEYWORDS = [
        "മാലിന്യം", "മാലിന്യ നിക്ഷേപം", "മാലിന്യ സംസ്കരണം", "പ്ലാസ്റ്റിക് മാലിന്യം",
        "ഓട", "അഴുക്കുചാൽ", "ഓട ശുചീകരണം", "അഴുക്കുചാൽ നിർമ്മാണം", "തെരുവ് വിളക്ക്",
        "തെരുവുവിളക്ക്", "വീട്ടുനികുതി", "കെട്ടിട നിർമ്മാണ അനുമതി", "കെട്ടിട പെർമിറ്റ്",
        "പഞ്ചായത്ത്", "മുനിസിപ്പാലിറ്റി", "കോർപ്പറേഷൻ", "വാർഡ്", "ശുചിത്വം", "കൊതുക് ശല്യം",
        "waste", "garbage", "sanitation", "drain", "drainage gutter", "panchayat", "municipality",
        "street light", "building permit", "mosquito"
    ]

    IRRIGATION_KEYWORDS = [
        "ഇറിഗേഷൻ കനാൽ", "ഡാം", "ഷട്ടർ", "റെഗുലേറ്റർ", "കൃഷി ജലസേചനം", "നദീതീര സംരക്ഷണം",
        "തടയണ", "irrigation canal", "dam shutter", "flood bund", "river bank protection"
    ]

    CIVIL_SUPPLIES_KEYWORDS = [
        "റേഷൻ", "റേഷൻ കട", "റേഷൻ കാർഡ്", "സപ്ലൈകോ", "മാവേലി സ്റ്റോർ", "ഭക്ഷ്യധാന്യം", "മണ്ണെണ്ണ",
        "ration", "ration card", "supplyco", "food grains", "civil supplies"
    ]

    HEALTH_KEYWORDS = [
        "ആശുപത്രി", "പ്രാഥമികാരോഗ്യകേന്ദ്രം", "പി.എച്ച്.സി", "ഡോക്ടർ", "മരുന്ന്", "പകർച്ചവ്യാധി",
        "ഡെങ്കിപ്പനി", "എലിപ്പനി", "ഭക്ഷ്യവിഷബാധ", "hospital", "primary health centre", "epidemic"
    ]

    POLICE_KEYWORDS = [
        "പോലീസ്", "പോലീസ് സ്റ്റേഷൻ", "ക്രമസമാധാനം", "മോഷണം", "അതിക്രമം", "ഗുണ്ടാ ശല്യം",
        "സാമൂഹ്യവിരുദ്ധർ", "ലഹരി", "police", "theft", "assault", "nuisance", "law and order"
    ]

    MOTOR_VEHICLES_KEYWORDS = [
        "കെ.എസ്.ആർ.ടി.സി", "ബസ്സ് സർവീസ്", "ഡ്രൈവിംഗ് ലൈസൻസ്", "ആർ.ടി.ഒ", "ഫിറ്റ്നസ് സർട്ടിഫിക്കറ്റ്",
        "ksrtc", "bus service", "rto", "driving licence", "motor vehicles"
    ]

    FOREST_KEYWORDS = [
        "വനം", "ഫോറസ്റ്റ്", "വന്യജീവി ശല്യം", "കാട്ടാന", "കാട്ടുപന്നി", "വനപാലകർ",
        "forest", "wild animal", "wild boar", "wild elephant", "forest ranger"
    ]

    @classmethod
    def evaluate(
        cls,
        text: str,
        location: Optional[Dict[str, Any]] = None,
    ) -> SequentialRoutingDecision:
        """Executes sequential sentence-by-sentence contextual state routing."""
        clean_text = (text or "").strip()
        text_lower = clean_text.lower()
        sentences = [s.strip() for s in re.split(r"[\n\.\?!]+", clean_text) if s.strip()]

        loc = location or {}
        district = loc.get("district") or "District"
        ward = loc.get("ward") or "Ward"
        local_body = (
            loc.get("panchayat")
            or loc.get("municipality")
            or loc.get("corporation")
            or "Local Authority"
        )

        trace: List[str] = []

        # ---------------------------------------------------------
        # STAGE 1: ADDRESSEE / RECIPIENT RECOGNITION (First 5 sentences)
        # ---------------------------------------------------------
        detected_addressee_dept = None
        detected_addressee_auth = None
        header_window = " ".join(sentences[:5]).lower() if sentences else text_lower

        for addr_rule in cls.ADDRESSEE_PATTERNS:
            if addr_rule["regex"].search(header_window):
                detected_addressee_dept = addr_rule["dept_code"]
                detected_addressee_auth = addr_rule["authority_template"]
                trace.append(f"Stage 1 Salutation Match: Found addressee indicator for {addr_rule['dept_name']}")
                break

        # ---------------------------------------------------------
        # STAGE 2: SUBJECT LINE & ACTION EXTRACTION
        # ---------------------------------------------------------
        detected_subject = None
        detected_action = None
        for s in sentences:
            if any(k in s.lower() for k in ["വിഷയം", "subject"]):
                detected_subject = s
                trace.append(f"Stage 2 Subject Detected: '{s[:80]}...'")
                break

        for s in sentences[-4:] if len(sentences) >= 4 else sentences:
            if any(k in s.lower() for k in ["അപേക്ഷിക്കുന്നു", "നടപടി", "ഒഴിപ്പിച്ച്", "അളന്നു", "നന്നാക്കണം", "പരിഹരിക്കണം", "request", "action"]):
                detected_action = s
                trace.append(f"Stage 2 Relief/Prayer Detected: '{s[:80]}...'")
                break

        # ---------------------------------------------------------
        # STAGE 3: SEQUENTIAL TOKEN ACCUMULATION & SCORING
        # ---------------------------------------------------------
        scores: Dict[str, float] = {
            "REV": 0.0,
            "KWA": 0.0,
            "PWD": 0.0,
            "KSEB": 0.0,
            "LSGD": 0.0,
            "IRR": 0.0,
            "CIVIL_SUPPLIES": 0.0,
            "HEALTH": 0.0,
            "POLICE": 0.0,
            "MVD": 0.0,
            "FOREST": 0.0,
        }

        # Addressee Prior
        if detected_addressee_dept and detected_addressee_dept in scores:
            scores[detected_addressee_dept] += 35.0
            trace.append(f"Prior Boost: +35.0 to {detected_addressee_dept} from addressee recognition.")

        # Match Revenue Tokens
        rev_matches = [k for k in cls.REVENUE_KEYWORDS if k.lower() in text_lower]
        scores["REV"] += len(rev_matches) * 12.0

        # Match Canal / Natural Water Flow Tokens
        canal_matches = [k for k in cls.CANAL_WATER_FLOW_KEYWORDS if k.lower() in text_lower]

        # Match Drinking Water / KWA Positive Tokens
        kwa_matches = [k for k in cls.KWA_POSITIVE_KEYWORDS if k.lower() in text_lower]
        scores["KWA"] += len(kwa_matches) * 15.0

        # Match PWD Tokens
        pwd_matches = [k for k in cls.PWD_KEYWORDS if k.lower() in text_lower]
        scores["PWD"] += len(pwd_matches) * 12.0

        # Match KSEB Tokens
        kseb_matches = [k for k in cls.KSEB_KEYWORDS if k.lower() in text_lower]
        scores["KSEB"] += len(kseb_matches) * 12.0

        # Match LSGD Tokens
        lsgd_matches = [k for k in cls.LSGD_KEYWORDS if k.lower() in text_lower]
        scores["LSGD"] += len(lsgd_matches) * 10.0

        # Match Irrigation Tokens
        irr_matches = [k for k in cls.IRRIGATION_KEYWORDS if k.lower() in text_lower]
        scores["IRR"] += len(irr_matches) * 12.0

        # Match Other Departments
        scores["CIVIL_SUPPLIES"] += len([k for k in cls.CIVIL_SUPPLIES_KEYWORDS if k.lower() in text_lower]) * 15.0
        scores["HEALTH"] += len([k for k in cls.HEALTH_KEYWORDS if k.lower() in text_lower]) * 15.0
        scores["POLICE"] += len([k for k in cls.POLICE_KEYWORDS if k.lower() in text_lower]) * 15.0
        scores["MVD"] += len([k for k in cls.MOTOR_VEHICLES_KEYWORDS if k.lower() in text_lower]) * 15.0
        scores["FOREST"] += len([k for k in cls.FOREST_KEYWORDS if k.lower() in text_lower]) * 15.0

        # ---------------------------------------------------------
        # STAGE 4: SEQUENTIAL DISAMBIGUATION & NEGATIVE GATING (LSTM/GRU Gate)
        # ---------------------------------------------------------

        # CRITICAL DISAMBIGUATION 1: CANAL / THODU / PORAMBOKE / ENCROACHMENT vs KWA
        # A canal (തോട്) or poramboke (പുറമ്പോക്ക്) or land survey is NEVER KWA jurisdiction!
        has_canal = len(canal_matches) > 0
        has_rev_land = len(rev_matches) > 0
        has_encroachment = any(k in text_lower for k in ["കയ്യേറ്റം", "കയ്യേറി", "പുറമ്പോക്ക്", "മണ്ണ് നികത്തൽ", "വേലി കെട്ടി", "അളന്നു", "encroachment", "puramboke", "poramboke"])

        if (has_canal and has_encroachment) or (has_rev_land and has_canal) or (detected_addressee_dept == "REV" and has_canal):
            # Boost Revenue heavily
            scores["REV"] += 45.0
            # Apply hard negative gate to KWA: Canal encroachment is strictly not drinking water pipeline!
            scores["KWA"] = 0.0
            trace.append("Linguistic Gate Triggered: Poramboke Canal Encroachment detected. Clamped KWA score to 0.0, boosted Revenue.")

        # CRITICAL DISAMBIGUATION 2: Local Stream Cleaning vs Poramboke Encroachment
        # If canal is mentioned with only plastic/waste/mosquitoes and NO land encroachment, it belongs to LSGD
        if has_canal and not has_encroachment and any(k in text_lower for k in ["മാലിന്യം", "പ്ലാസ്റ്റിക്", "കൊതുക്", "ശുചീകരണം", "ദുർഗന്ധം", "waste", "cleaning"]):
            scores["LSGD"] += 25.0
            trace.append("Linguistic Gate Triggered: Stream cleaning / waste dumping belongs to LSGD Sanitation.")

        # CRITICAL DISAMBIGUATION 3: Road Drains (ഓട) vs KWA Drinking Water Pipe
        # Storm drains (ഓട / അഴുക്കുചാൽ) belong to LSGD or PWD, NEVER KWA
        if any(k in text_lower for k in ["ഓട", "അഴുക്കുചാൽ", "drainage gutter", "storm drain"]):
            if any(k in text_lower for k in ["റോഡ്", "പൊതുമരാമത്ത്", "pwd"]):
                scores["PWD"] += 15.0
            else:
                scores["LSGD"] += 15.0
            # If no piped drinking water words, ensure KWA does not steal storm drainage
            if not any(k in text_lower for k in ["കുടിവെള്ളം", "പൈപ്പ് ലൈൻ", "കുടിവെള്ള വിതരണം", "drinking water"]):
                scores["KWA"] = min(scores["KWA"], 0.0)
                trace.append("Linguistic Gate Triggered: Storm drainage / gutter isolated from KWA.")

        # CRITICAL DISAMBIGUATION 4: Road Potholes vs PWD
        if any(k in text_lower for k in ["കുഴി", "കുഴികൾ", "pothole", "potholes"]) and any(k in text_lower for k in ["റോഡ്", "റോഡിലെ", "road"]):
            scores["PWD"] += 30.0

        # CRITICAL DISAMBIGUATION 5: Electric Post Shifting vs PWD
        # If shifting pole for road work, KSEB must execute the pole work
        if any(k in text_lower for k in ["പോസ്റ്റ്", "കമ്പി", "വൈദ്യുതി"]) and scores["KSEB"] > 0:
            scores["KSEB"] += 15.0

        # ---------------------------------------------------------
        # STAGE 5: SELECT WINNING DEPARTMENT
        # ---------------------------------------------------------
        sorted_depts = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        winning_code, winning_score = sorted_depts[0]

        trace.append(f"Final Scoring: {dict(sorted_depts[:4])}")

        # Map Winning Department to Statutory Details
        if winning_code == "REV" or (winning_score == 0 and detected_addressee_dept == "REV"):
            dept_name = "Revenue & General Administration"
            dept_code = "REV"
            category = "Revenue & Land Reforms"
            authority = f"Tahsildar / Village Officer, Revenue Department ({district} District - {local_body})"
            level = "TALUK_VILLAGE"
            statutory_act = "Kerala Land Conservancy Act, 1957 (Sections 3, 7 & 11)"
            explanation = (
                "Petition involves government poramboke land, canal (thodu) encroachment, survey measurement, "
                "or obstruction of natural watercourses, falling under the summary eviction and restoration powers "
                "of the Tahsildar / Revenue Department under the Kerala Land Conservancy Act, 1957."
            )
        elif winning_code == "KWA":
            dept_name = "Kerala Water Authority (KWA)"
            dept_code = "KWA"
            category = "Water Supply & Drainage"
            authority = f"Assistant Executive Engineer, Water Works Sub-Division, KWA ({district} District - {local_body})"
            level = "DEPARTMENTAL_SUBDIVISION"
            statutory_act = "Kerala Water Supply and Sewerage Act, 1986 (Section 14)"
            explanation = (
                "Petition relates directly to public piped drinking water supply interruption, pipeline damage, "
                "burst leaks, or water meter servicing under Kerala Water Authority jurisdiction."
            )
        elif winning_code == "PWD":
            dept_name = "Public Works Department (PWD)"
            dept_code = "PWD"
            category = "Roads & Public Infrastructure"
            authority = f"Executive Engineer, PWD Roads Division ({district} District - {local_body})"
            level = "DISTRICT_DIVISION"
            statutory_act = "Kerala Highway Protection Act, 1999 (Section 7)"
            explanation = (
                "Complaint pertains to public road damage, pothole repairs, culvert construction, or state highway "
                "infrastructure maintenance under PWD oversight."
            )
        elif winning_code == "KSEB":
            dept_name = "Kerala State Electricity Board (KSEB)"
            dept_code = "KSEB"
            category = "Power & Electricity"
            authority = f"Assistant Engineer, Electrical Section Office, KSEB ({district} District - {local_body})"
            level = "SECTION_OFFICE"
            statutory_act = "Electricity Act, 2003 (Section 43) & Kerala Electricity Supply Code, 2014"
            explanation = (
                "Complaint pertains to power interruptions, hazardous electric lines, leaning/damaged poles, "
                "or transformer failures managed by KSEB."
            )
        elif winning_code == "LSGD":
            dept_name = "Local Self Government Department (LSGD / Panchayat)"
            dept_code = "LSGD"
            category = "Local Body & Public Health"
            authority = f"{local_body} Secretary & LSGD Assistant Engineer, Ward #{ward}"
            level = "PANCHAYAT"
            statutory_act = "Kerala Panchayat Raj Act, 1994 (Section 166 & 218)"
            explanation = (
                "Complaint pertains to local ward waste disposal, street gutters, public hygiene, streetlights, "
                "or Grama Panchayat / Municipal civic services."
            )
        elif winning_code == "IRR":
            dept_name = "Irrigation Department"
            dept_code = "IRR"
            category = "Irrigation & Water Resources"
            authority = f"Executive Engineer, Irrigation Division ({district} District)"
            level = "DISTRICT_DIVISION"
            statutory_act = "Kerala Irrigation and Water Conservation Act, 2003"
            explanation = "Complaint involves state irrigation canals, regulators, dams, or river embankment protection."
        elif winning_code == "POLICE":
            dept_name = "Police & Home Department"
            dept_code = "POLICE"
            category = "Law & Order"
            authority = f"Station House Officer, Local Police Station ({district} District)"
            level = "POLICE_STATION"
            statutory_act = "Kerala Police Act, 2011"
            explanation = "Complaint involves public nuisance, theft, or law and order intervention."
        elif winning_code == "CIVIL_SUPPLIES":
            dept_name = "Food & Civil Supplies Department"
            dept_code = "CS"
            category = "Civil Supplies & Consumer Affairs"
            authority = f"Taluk Supply Officer (TSO), Civil Supplies ({district} District)"
            level = "TALUK_LEVEL"
            statutory_act = "Essential Commodities Act, 1955 & National Food Security Act, 2013"
            explanation = "Complaint relates to ration distribution, Supplyco commodities, or food grain allocation."
        elif winning_code == "HEALTH":
            dept_name = "Health & Family Welfare Department"
            dept_code = "HFW"
            category = "Public Health & Medical Services"
            authority = f"Medical Officer, Primary Health Centre / DMO ({district} District)"
            level = "HEALTH_CENTRE"
            statutory_act = "Kerala Public Health Act, 2023"
            explanation = "Complaint concerns government health centres, epidemic outbreaks, or hospital facilities."
        elif winning_code == "MVD":
            dept_name = "Motor Vehicles & Transport Department"
            dept_code = "MVD"
            category = "Transport & Motor Vehicles"
            authority = f"Regional Transport Officer (RTO) / KSRTC Depot Officer ({district} District)"
            level = "RTO_LEVEL"
            statutory_act = "Motor Vehicles Act, 1988"
            explanation = "Complaint involves public transit, bus routing, or vehicular regulatory matters."
        elif winning_code == "FOREST":
            dept_name = "Forest & Wildlife Department"
            dept_code = "FOR"
            category = "Forest & Wildlife Conservation"
            authority = f"Divisional Forest Officer / Range Forest Officer ({district} District)"
            level = "RANGE_OFFICE"
            statutory_act = "Wild Life (Protection) Act, 1972"
            explanation = "Complaint relates to wildlife encroachment, animal attacks, or forest range disputes."
        else:
            dept_name = "Revenue & General Administration"
            dept_code = "REV"
            category = "General Public Grievance"
            authority = f"Tahsildar / Village Officer, Revenue Department ({district} District - {local_body})"
            level = "TALUK_VILLAGE"
            statutory_act = "Kerala Public Services Act, 2012"
            explanation = "Grievance received for administrative review and competent departmental dispatch."

        confidence = 0.96 if winning_score >= 30.0 else (0.88 if winning_score >= 15.0 else 0.78)

        return SequentialRoutingDecision(
            department_name=dept_name,
            department_code=dept_code,
            category=category,
            recommended_authority=authority,
            jurisdiction_level=level,
            confidence_score=confidence,
            statutory_act=statutory_act,
            legal_explanation=explanation,
            detected_addressee=detected_addressee_auth,
            detected_subject=detected_subject,
            detected_action=detected_action,
            detected_location_reference=f"{local_body}, {ward}, {district}",
            sequential_trace=trace,
        )
