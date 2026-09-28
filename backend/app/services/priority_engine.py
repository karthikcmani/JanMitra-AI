"""JanMitra AI — Public Grievance Multi-Factor Priority Intelligence Engine.

Based on Public Administration Decision Support Standards (e.g. CPGRAMS, Kerala Public Services Delivery Act):
Calculates an objective, transparent, multi-dimensional Priority Score (0-100) and SLA timeline:
1. Public Safety & Life Hazard Risk (Weight: 35%)
2. Community Scope & Affected Population (Weight: 25%)
3. Duration & Institutional Delay / SLA Aging (Weight: 20%)
4. Vulnerability of Aggrieved Citizens (Weight: 10%)
5. Essential Public Utility Classification (Weight: 10%)

Priority Levels:
- CRITICAL (80 - 100): Immediate life hazard, structural collapse risk, or massive utility failure. SLA: 24-48 hours.
- HIGH     (60 - 79) : Significant public safety risk, school/transit route, or chronic disruption. SLA: 3-5 days.
- MEDIUM   (40 - 59) : Standard public utility maintenance, localized disruption, normal flow. SLA: 7-14 days.
- LOW      (0 - 39)  : Routine administrative matters, cosmetic repairs, minor individual queries. SLA: 15-30 days.
"""

import re
from typing import Any, Dict, List, Optional
from dataclasses import dataclass, field


@dataclass
class PriorityFactorResult:
    score: int
    max_score: int
    level: str
    description: str
    matched_signals: List[str] = field(default_factory=list)


@dataclass
class PriorityEvaluationResult:
    priority: str  # "CRITICAL", "HIGH", "MEDIUM", "LOW"
    priority_score: int  # 0 to 100
    sla_target_days: int
    sla_target_hours: int
    factors: Dict[str, Dict[str, Any]]
    rationale: str
    rationale_ml: str


class PriorityIntelligenceEngine:
    """Evaluates citizen petitions across 5 governance criteria."""

    # 1. Safety & Hazard Signals
    HAZARD_SIGNALS_CRITICAL = [
        # English
        "11kv", "high tension", "electrocution", "live wire", "sparking wire", "falling post",
        "fallen post", "sinkhole", "road collapse", "bridge collapse", "water contamination",
        "burst pipeline", "flooding", "gas leak", "poisonous", "life threatening", "fatal accident",
        # Malayalam
        "വൈദ്യുതി പോസ്റ്റ്", "11 കെ.വി", "ഷോക്കേൽക്കുക", "പൊട്ടിവീണ", "ചരിഞ്ഞുനിൽക്കുന്ന",
        "റോഡ് തകർന്നു", "കുഴി", "പൈപ്പ് പൊട്ടി", "വെള്ളപ്പൊക്കം", "അപകടാവസ്ഥ", "ജീവൻ", "മരണം",
        "അപകടഭീഷണി", "തീപിടിത്തം"
    ]

    HAZARD_SIGNALS_HIGH = [
        # English
        "deep pothole", "potholes", "accident prone", "sewage overflow", "transformer fault",
        "drainage block", "road damage", "water stagnation", "dengue", "disease outbreak",
        # Malayalam
        "വലിയ കുഴികൾ", "അപകടങ്ങൾ", "മലിനജലം", "ഡെങ്കിപ്പനി", "പകർച്ചവ്യാധി", "റോഡ് പൊട്ടിപ്പൊളിഞ്ഞു",
        "ഡ്രെയിനേജ്", "മഴവെള്ളം", "കാൽനടയാത്രക്കാർ"
    ]

    HAZARD_SIGNALS_MODERATE = [
        # English
        "low voltage", "streetlight not working", "street light", "water leakage", "garbage",
        "waste dumping", "bad smell", "overgrowth", "bus stop",
        # Malayalam
        "വോൾട്ടേജ് ക്ഷാമം", "തെരുവുവിളക്ക്", "കുടിവെള്ള ക്ഷാമം", "മാലിന്യം", "ദുർഗന്ധം"
    ]

    # 2. Community & Scope Signals
    COMMUNITY_SIGNALS_BROAD = [
        # English
        "bus route", "main road", "highway", "school", "hospital", "market", "entire ward",
        "entire village", "junction", "hundreds of families", "many people", "public transport",
        "commuters", "village", "panchayat", "road", "public road", "general public",
        # Malayalam
        "ബസ് റൂട്ട്", "പ്രധാന റോഡ്", "സ്കൂൾ", "ആശുപത്രി", "മാർക്കറ്റ്", "കവല", "ജംഗ്ഷൻ",
        "നാട്ടുകാർ", "നൂറുകണക്കിന് കുടുംബങ്ങൾ", "യാത്രക്കാർ", "ഗ്രാമം", "പഞ്ചായത്ത്", "വാർഡ്",
        "റോഡ്", "റോഡിൽ", "റോഡിലേക്ക്", "പൊതുവഴി", "പൊതുജനം", "ജനങ്ങൾക്ക്", "യാത്ര"
    ]

    COMMUNITY_SIGNALS_NEIGHBORHOOD = [
        # English
        "colony", "street", "residential area", "lane", "residents", "neighbors", "community", "locality",
        # Malayalam
        "കോളനി", "തെരുവ്", "താമസക്കാർ", "റെസിഡന്റ്സ്", "വീടുകൾ", "അയൽവാസികൾ", "പ്രദേശം", "പ്രദേശവാസികൾ", "സ്ഥലം"
    ]

    # 3. Duration & Aging Signals
    DURATION_SIGNALS_CHRONIC = [
        # English
        "months", "several months", "last 2 months", "last 3 months", "year", "years",
        "repeated complaints", "no action taken", "despite multiple requests", "long time",
        # Malayalam
        "മാസങ്ങളായി", "വർഷങ്ങളായി", "പലതവണ പരാതി നൽകി", "നടപടി ഉണ്ടായില്ല", "നീണ്ട നാളുകളായി",
        "ആഴ്ചകളായി"
    ]

    DURATION_SIGNALS_PROTRACTED = [
        # English
        "weeks", "two weeks", "many days", "several days", "since last week",
        # Malayalam
        "ആഴ്ചകൾ", "കുറേ ദിവസങ്ങളായി", "കഴിഞ്ഞ ആഴ്ച"
    ]

    # 4. Vulnerable Groups
    VULNERABILITY_SIGNALS = [
        # English
        "children", "school children", "students", "elderly", "senior citizen", "patients",
        "hospital patients", "pregnant", "differently abled", "handicapped", "poor families", "pedestrians",
        # Malayalam
        "കുട്ടികൾ", "വിദ്യാർത്ഥികൾ", "മുതിർന്ന പൗരന്മാർ", "വൃദ്ധർ", "രോഗികൾ", "ഗർഭിണികൾ",
        "ഭിന്നശേഷിക്കാർ", "നിർദ്ധനർ", "കാൽനടക്കാർ"
    ]

    @classmethod
    def evaluate(
        cls,
        text: str,
        department: Optional[str] = None,
        extracted_facts: Optional[Dict[str, Any]] = None,
        citizen_role: Optional[str] = None,
    ) -> PriorityEvaluationResult:
        clean_text = (text or "").lower()
        facts = extracted_facts or {}

        # -------------------------------------------------------------
        # Factor 1: Public Safety & Hazard Risk (Max 35)
        # -------------------------------------------------------------
        safety_score = 5
        safety_level = "LOW_HAZARD"
        safety_matches = []
        safety_desc = "Minor routine matter without acute physical hazard."

        # Check Critical Hazard
        crit_matches = [s for s in cls.HAZARD_SIGNALS_CRITICAL if s in clean_text]
        if crit_matches:
            safety_score = 35 if any(k in clean_text for k in ["11kv", "electrocution", "വൈദ്യുതി പോസ്റ്റ്", "ഷോക്കേൽക്കുക", "collapse"]) else 30
            safety_level = "CRITICAL_HAZARD"
            safety_matches = crit_matches[:4]
            safety_desc = f"Severe threat to life/safety detected ({', '.join(safety_matches)})."
        else:
            high_matches = [s for s in cls.HAZARD_SIGNALS_HIGH if s in clean_text]
            if high_matches:
                safety_score = 24
                safety_level = "HIGH_HAZARD"
                safety_matches = high_matches[:4]
                safety_desc = f"Significant risk of accidents or health hazards ({', '.join(safety_matches)})."
            else:
                mod_matches = [s for s in cls.HAZARD_SIGNALS_MODERATE if s in clean_text]
                if mod_matches:
                    safety_score = 14
                    safety_level = "MODERATE_HAZARD"
                    safety_matches = mod_matches[:3]
                    safety_desc = f"Moderate public inconvenience or utility defect ({', '.join(safety_matches)})."

        # Check explicit extracted facts
        if facts.get("safety_hazard"):
            safety_score = min(35, safety_score + 5)
            safety_desc += f" Verified hazard: {facts['safety_hazard']}."

        # -------------------------------------------------------------
        # Factor 2: Community Scope & Affected Population (Max 25)
        # -------------------------------------------------------------
        comm_score = 8
        comm_level = "INDIVIDUAL_OR_DOMESTIC"
        comm_matches = []
        comm_desc = "Localized or single-household concern."

        broad_matches = [s for s in cls.COMMUNITY_SIGNALS_BROAD if s in clean_text]
        if broad_matches:
            comm_score = 24
            comm_level = "COMMUNITY_WIDE"
            comm_matches = broad_matches[:4]
            comm_desc = f"Broad public impact across transit routes or civic institutions ({', '.join(comm_matches)})."
        else:
            neigh_matches = [s for s in cls.COMMUNITY_SIGNALS_NEIGHBORHOOD if s in clean_text]
            if neigh_matches:
                comm_score = 16
                comm_level = "NEIGHBORHOOD_CLUSTER"
                comm_matches = neigh_matches[:3]
                comm_desc = f"Localized community impact affecting multiple families or street ({', '.join(comm_matches)})."

        # -------------------------------------------------------------
        # Factor 3: Duration & Administrative Aging (Max 20)
        # -------------------------------------------------------------
        dur_score = 5
        dur_level = "RECENT"
        dur_matches = []
        dur_desc = "Recent occurrence (< 7 days)."

        chronic_matches = [s for s in cls.DURATION_SIGNALS_CHRONIC if s in clean_text]
        if chronic_matches:
            dur_score = 19
            dur_level = "CHRONIC_DELAY"
            dur_matches = chronic_matches[:3]
            dur_desc = f"Chronic delay with repeated petitions or persisting for months ({', '.join(dur_matches)})."
        else:
            prot_matches = [s for s in cls.DURATION_SIGNALS_PROTRACTED if s in clean_text]
            if prot_matches:
                dur_score = 12
                dur_level = "PROTRACTED"
                dur_matches = prot_matches[:3]
                dur_desc = f"Persisting unaddressed for multiple days/weeks ({', '.join(dur_matches)})."

        # -------------------------------------------------------------
        # Factor 4: Vulnerability Assessment (Max 10)
        # -------------------------------------------------------------
        vuln_score = 3
        vuln_level = "GENERAL_PUBLIC"
        vuln_matches = [s for s in cls.VULNERABILITY_SIGNALS if s in clean_text]
        if vuln_matches:
            vuln_score = 9
            vuln_level = "VULNERABLE_GROUP_EXPOSED"
            vuln_desc = f"Direct risk to vulnerable groups ({', '.join(vuln_matches[:3])})."
        else:
            vuln_desc = "Affects general civic populace."

        # -------------------------------------------------------------
        # Factor 5: Essential Utility Classification (Max 10)
        # -------------------------------------------------------------
        dept_str = (department or "").upper()
        if "KSEB" in dept_str or "POWER" in dept_str or "ELECTRIC" in dept_str:
            util_score = 10
            util_level = "HIGH_TENSION_POWER"
            util_desc = "Lifeline power & electricity network."
        elif "KWA" in dept_str or "WATER" in dept_str:
            util_score = 9
            util_level = "POTABLE_WATER_SUPPLY"
            util_desc = "Essential public drinking water supply."
        elif "PWD" in dept_str or "ROAD" in dept_str:
            util_score = 8
            util_level = "ARTERIAL_TRANSIT_INFRA"
            util_desc = "Public works & arterial transit infrastructure."
        elif "LSGD" in dept_str or "LOCAL" in dept_str or "PANCHAYAT" in dept_str:
            util_score = 7
            util_level = "CIVIC_SANITATION"
            util_desc = "Local self-government public sanitation."
        else:
            util_score = 5
            util_level = "GENERAL_ADMIN"
            util_desc = "General administrative & revenue service."

        # -------------------------------------------------------------
        # Aggregate Composite Score (0 - 100)
        # -------------------------------------------------------------
        total_score = safety_score + comm_score + dur_score + vuln_score + util_score
        total_score = max(5, min(100, total_score))

        # Assign Tier & SLA
        if total_score >= 80:
            priority = "CRITICAL"
            sla_days = 2
            sla_hours = 48
        elif total_score >= 60:
            priority = "HIGH"
            sla_days = 5
            sla_hours = 120
        elif total_score >= 40:
            priority = "MEDIUM"
            sla_days = 10
            sla_hours = 240
        else:
            priority = "LOW"
            sla_days = 21
            sla_hours = 504

        # Human-readable Rationales
        rationale_en = (
            f"Assigned {priority} priority (Score: {total_score}/100, SLA: {sla_days} days). "
            f"Key drivers: {safety_desc} {comm_desc} {dur_desc}"
        )

        priority_ml_map = {
            "CRITICAL": "അടിയന്തിര മുൻഗണന (CRITICAL)",
            "HIGH": "ഉയർന്ന മുൻഗണന (HIGH)",
            "MEDIUM": "ഇടത്തരം മുൻഗണന (MEDIUM)",
            "LOW": "സാധാരണ മുൻഗണന (LOW)",
        }
        rationale_ml = (
            f"{priority_ml_map[priority]} നൽകിയിരിക്കുന്നു (സ്കോർ: {total_score}/100, പരിഹാര കാലാവധി: {sla_days} ദിവസം). "
            f"സുരക്ഷാ ഭീഷണി: {safety_level}, ബാധിക്കുന്ന ജനസംഖ്യ: {comm_level}."
        )

        factors_dict = {
            "safety_hazard": {
                "score": safety_score,
                "max": 35,
                "level": safety_level,
                "description": safety_desc,
                "signals": safety_matches,
            },
            "community_impact": {
                "score": comm_score,
                "max": 25,
                "level": comm_level,
                "description": comm_desc,
                "signals": comm_matches,
            },
            "duration_aging": {
                "score": dur_score,
                "max": 20,
                "level": dur_level,
                "description": dur_desc,
                "signals": dur_matches,
            },
            "vulnerability": {
                "score": vuln_score,
                "max": 10,
                "level": vuln_level,
                "description": vuln_desc,
                "signals": vuln_matches,
            },
            "essential_utility": {
                "score": util_score,
                "max": 10,
                "level": util_level,
                "description": util_desc,
            },
        }

        return PriorityEvaluationResult(
            priority=priority,
            priority_score=total_score,
            sla_target_days=sla_days,
            sla_target_hours=sla_hours,
            factors=factors_dict,
            rationale=rationale_en,
            rationale_ml=rationale_ml,
        )
