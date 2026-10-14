from app.services.grievance_validator import validate_grievance_text

def test_chitchat_rejection():
    # User's exact Malayalam chitchat string
    user_text = "ഹാലോ എന്റെ പേര് കാർത്തിക് എനിക്ക് സുഖമാണ് നിങ്ങൾക്ക് സുഖമാണെന്ന് വിശ്വസിക്കുന്നു ശരി എന്നാൽ ബൈ"
    res = validate_grievance_text(user_text)
    assert not res.is_valid
    assert res.is_chitchat

    # English chitchat
    res_en = validate_grievance_text("Hello my name is Alex I am fine hope you are fine okay then bye")
    assert not res_en.is_valid
    assert res_en.is_chitchat

    # Short test
    res_test = validate_grievance_text("hello testing 123")
    assert not res_test.is_valid

    # Empty
    res_empty = validate_grievance_text("")
    assert not res_empty.is_valid

def test_valid_grievance_acceptance():
    # User's actual complaint from screenshot 2:
    power_cut_text = "ഹാലോ, ഇപ്പോൾ കേരളത്തിൽ പവർ കട്ട് കൂടുതലാണ്. അത് കുറയ്ക്കണം"
    res = validate_grievance_text(power_cut_text)
    assert res.is_valid
    assert not res.is_chitchat

    # Malayalam drinking water pipe burst
    water_text = "ഞങ്ങളുടെ പ്രദേശത്ത് കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം പാഴാകുന്നു, പരിഹരിക്കണം"
    res_water = validate_grievance_text(water_text)
    assert res_water.is_valid

    # English road pothole complaint
    road_text = "There are severe potholes on the main road in Ward 4 causing accidents. Please repair."
    res_road = validate_grievance_text(road_text)
    assert res_road.is_valid
