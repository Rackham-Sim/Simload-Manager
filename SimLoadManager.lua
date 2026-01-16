--SIMLOAD MANAGER V2.1.2

--------------------------------------------------------------------------------
-- IMGUi Check
--------------------------------------------------------------------------------
if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("imgui not supported by your FlyWithLua version")
    return
end


--------------------------------------------------------------------------------
-- UPDATE CHECK
--------------------------------------------------------------------------------
SLM_VERSION = "2.1.2"

local SLM_UPDATE_URL =
    "http://raw.githack.com/Rackham-Sim/Simload-Manager/main/version.txt"

local slm_update_checked = false
local slm_update_status  = "Unable to verify update at this time"
local slm_latest_version = nil

local function version_to_table(v)
    local t = {}
    for num in string.gmatch(v or "", "%d+") do
        t[#t + 1] = tonumber(num)
    end
    return t
end

local function is_version_newer(remote, localv)
    local r = version_to_table(remote)
    local l = version_to_table(localv)

    local max_len = math.max(#r, #l)
    for i = 1, max_len do
        local rv = r[i] or 0
        local lv = l[i] or 0
        if rv > lv then return true end
        if rv < lv then return false end
    end
    return false
end

local function slm_extract_remote_version(body)
    if not body or body == "" then return nil end

    local lines = {}
    for line in tostring(body):gmatch("([^\r\n]+)") do
        line = line:gsub("\r", "")
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end

    if #lines < 2 then return nil end

    local remote_version = (lines[2] or ""):match("[Vv]%s*(%d+[%d%.]*)")
    return remote_version
end

function slm_check_update()
    if slm_update_checked then return end
    slm_update_checked = true
    slm_update_available = false

    slm_update_status = "Unable to verify update at this time"
    logMsg("[SLM] Update check started...")

    local ok_http, http = pcall(require, "socket.http")
    if not ok_http or not http or not http.request then
        logMsg("[SLM] Unable to verify update (socket.http not available)")
        return
    end

    if http.TIMEOUT ~= nil then
        http.TIMEOUT = 5
    end

    local body, code = http.request(SLM_UPDATE_URL)
    if not body or code ~= 200 then
        logMsg("[SLM] Unable to verify update (HTTP " .. tostring(code) .. ")")
        return
    end

    local remote_version = slm_extract_remote_version(body)
    if not remote_version then
        logMsg("[SLM] Unable to verify update (parse failed)")
        return
    end

    slm_latest_version = remote_version

    if is_version_newer(remote_version, SLM_VERSION) then
        slm_update_available = true
        slm_update_status = "New update available: " .. remote_version
        logMsg("[SLM] New update available: " .. remote_version)
    else
        slm_update_available = false
        slm_update_status = "Latest version installed"
        logMsg("[SLM] Latest version installed (Local " .. SLM_VERSION .. " / Remote " .. remote_version .. ")")
    end
end

local slm_update_init_done = false
function slm_update_init_once()
    if slm_update_init_done then return end
    slm_update_init_done = true
    slm_check_update()
end


--------------------------------------------------------------------------------
-- VARIABLES
--------------------------------------------------------------------------------
local IMGUI_COL_TEXT = 0
local IMGUI_COL_PLOT_HISTOGRAM = 40

embark_wnd = nil
unit_system = "kg"
simbrief_id = "REPLACE_WITH_YOUR_SIMBRIEF_ID"
settings_file = "Resources/plugins/FlyWithLua/Modules/simload_settings.txt"
local simbrief_data_loaded = false

local passengers_total = 0
local cargo_total = 0

local embark_started = false
local embark_done = false
local disembark_started = false
local disembark_done = false

local selected_location_group = "remote"
local aircraft_has_own_stairs = false
local cargo_loaded = 0
local passengers_loaded = 0
local cargo_unloaded = 0
local passengers_unloaded = 0

local start_time = 0
local last_update_time = 0
local pax_load_started = false
local pax_start_time = 0

local disembark_start_time = 0
local disembark_last_update_time = 0
local pax_unload_started = false
local pax_unload_start_time = 0

local temp_manual_passengers = 0
local temp_manual_cargo = 0
local estimated_time_cargo = nil
local estimated_time_pax = nil
local cargo_start_reference_time = nil

local cargo_loop_playing = false
local pax_loop_playing   = false
local fuel_loop_playing = false
local is_muted = false


local sound_dir = SCRIPT_DIRECTORY .. "SimLoad-Manager-Sounds/"
local Volume = 1.0

local fuel_total = 0
local fuel_loaded = 0
local fuel_unit = "kg"
local fuel_loading = false
local fuel_done = false
local fuel_ready_time = nil
local estimated_time_fuel = nil
local fuel_first = false
local fuel_wait_finished = false
local fuel_done_time = nil
local fuel_post_delay = 60


local end_time = nil
local FINISHED_ALL_DELAY = 5

local sched_out = 0
local sched_off = 0
local sched_on  = 0
local sched_in  = 0

local block_off_time = "--:--Z"
local beacon_prev = 0
local takeoff_time = "--:--Z"
local onground_prev = 1
local landing_time = "--:--Z"
local block_on_time = "--:--Z"
local passed_1000ft = false
slm_loadsheet_shown = false

SB_pax_weight = 0
SB_bag_weight = 0
SB_pax_count  = 0
SB_bag_count  = 0
SB_pax_mass_planned = 0
SB_bag_mass_planned = 0

dataref("view_is_external", "sim/graphics/view/view_is_external", "readonly")
dataref("beacon", "sim/cockpit/electrical/beacon_lights_on", "readonly")
dataref("onground", "sim/flightmodel/failures/onground_any", "readonly")
dataref("zulu_hours", "sim/cockpit2/clock_timer/zulu_time_hours", "readonly")
dataref("zulu_minutes", "sim/cockpit2/clock_timer/zulu_time_minutes", "readonly")
dataref("altitude_ft", "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "readonly")

autodgs_on_ground = 0
autodgs_available = false

local ok_find, dr = pcall(function()
    return find_dataref("AutoDGS/on_ground")
end)

if ok_find and dr then
    autodgs_available = true
    dataref("autodgs_on_ground", "AutoDGS/on_ground", "readonly")
end


sound_played = {
    start_loading_cargo         = false,
    start_boarding_passengers   = false,
    finished_loading_cargo      = false,
    finished_loading_pax        = false,
    finished_loading_all        = false,
    start_unloading_cargo       = false,
    start_unboarding_passengers = false,
    finished_unloading_cargo    = false,
    finished_unboarding_passengers = false,
	start_fuel_loading = false,
	finished_fuel_loading = false
}

--------------------------------------------------------------------------------
-- SLM DATAREFS (API v1.1)
--------------------------------------------------------------------------------

SLM_state                 = create_dataref_table("FlyWithLua/SimLoadManager/state", "Int")
SLM_is_busy               = create_dataref_table("FlyWithLua/SimLoadManager/is_busy", "Int")

SLM_location_mode         = create_dataref_table("FlyWithLua/SimLoadManager/location_mode", "Int")
SLM_aircraft_own_stairs   = create_dataref_table("FlyWithLua/SimLoadManager/aircraft_has_own_stairs", "Int")

SLM_pax_total             = create_dataref_table("FlyWithLua/SimLoadManager/pax_total", "Int")
SLM_cargo_total           = create_dataref_table("FlyWithLua/SimLoadManager/cargo_total", "Float")
SLM_fuel_total            = create_dataref_table("FlyWithLua/SimLoadManager/fuel_total", "Float")

SLM_pax_done              = create_dataref_table("FlyWithLua/SimLoadManager/pax_done", "Int")
SLM_cargo_done            = create_dataref_table("FlyWithLua/SimLoadManager/cargo_done", "Float")
SLM_fuel_done             = create_dataref_table("FlyWithLua/SimLoadManager/fuel_done", "Float")

SLM_pax_fraction          = create_dataref_table("FlyWithLua/SimLoadManager/pax_fraction", "Float")
SLM_cargo_fraction        = create_dataref_table("FlyWithLua/SimLoadManager/cargo_fraction", "Float")
SLM_fuel_fraction         = create_dataref_table("FlyWithLua/SimLoadManager/fuel_fraction", "Float")

SLM_eta_pax               = create_dataref_table("FlyWithLua/SimLoadManager/eta_pax_sec", "Float")
SLM_eta_cargo             = create_dataref_table("FlyWithLua/SimLoadManager/eta_cargo_sec", "Float")
SLM_eta_fuel              = create_dataref_table("FlyWithLua/SimLoadManager/eta_fuel_sec", "Float")
SLM_eta_total             = create_dataref_table("FlyWithLua/SimLoadManager/eta_total_sec", "Float")

SLM_pax_state             = create_dataref_table("FlyWithLua/SimLoadManager/pax_state", "Int")
SLM_cargo_state           = create_dataref_table("FlyWithLua/SimLoadManager/cargo_state", "Int")
SLM_fuel_state            = create_dataref_table("FlyWithLua/SimLoadManager/fuel_state", "Int")
SLM_loadsheet_ready		  = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet_ready", "Int")

SLM_ls_diff_pax          = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet/diff_pax", "Int")
SLM_ls_diff_cargo        = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet/diff_cargo", "Float")
SLM_ls_diff_fuel_block   = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet/diff_fuel_block", "Float")
SLM_ls_diff_payload      = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet/diff_payload", "Float")

SLM_ls_actual_pax        = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet/actual_pax", "Int")
SLM_ls_actual_cargo      = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet/actual_cargo", "Float")
SLM_ls_actual_fuel_block = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet/actual_fuel_block", "Float")
SLM_ls_actual_payload    = create_dataref_table("FlyWithLua/SimLoadManager/loadsheet/actual_payload", "Float")


--------------------------------------------------------------------------------
-- DEFAULT TIMING
--------------------------------------------------------------------------------
local timing_preset = "realistic"
local pax_time_per_passenger = 6
local pax_time_variation = 9
local cargo_time_per_kg_min = 0.3
local cargo_time_per_kg_max = 0.5
local pax_delay_before_start = 300

local disembark_pax_time_per_passenger = 3
local disembark_pax_time_variation = 5
local disembark_cargo_time_per_kg_min = 0.2
local disembark_cargo_time_per_kg_max = 0.4

-- Default custom values (same as Realistic preset)
custom_pax_time_per_passenger = 5
custom_pax_time_variation = 3
custom_disembark_pax_time_per_passenger = 4
custom_disembark_pax_time_variation = 3
custom_cargo_time_per_kg_min = 0.3
custom_cargo_time_per_kg_max = 0.6
custom_disembark_cargo_time_per_kg_min = 0.2
custom_disembark_cargo_time_per_kg_max = 0.6
custom_fuel_time_per_kg = 0.053

local fuel_time_per_kg = 10
fuel_time_per_unit = fuel_time_per_kg

function random_range(min, max)
    return min + math.random() * (max - min)
end

local fuel_start_ratio = math.random(5, 25) / 100

--------------------------------------------------------------------------------
-- SOUND
--------------------------------------------------------------------------------
local flywithlua_play_sound = play_sound

sounds = {
    start_loading_cargo            = { path = sound_dir .. "start_loading_cargo.wav", id = nil },
    start_boarding_passengers      = { path = sound_dir .. "start_boarding_passengers.wav", id = nil },
    finished_loading_cargo         = { path = sound_dir .. "finished_loading_cargo.wav", id = nil },
    finished_loading_pax           = { path = sound_dir .. "finished_loading_pax.wav", id = nil },
    finished_loading_all           = { path = sound_dir .. "finished_loading_all.wav", id = nil },
    start_unloading_cargo          = { path = sound_dir .. "start_unloading_cargo.wav", id = nil },
    start_unboarding_passengers    = { path = sound_dir .. "start_unboarding_passengers.wav", id = nil },
    finished_unloading_cargo       = { path = sound_dir .. "finished_unloading_cargo.wav", id = nil },
    finished_unboarding_passengers = { path = sound_dir .. "finished_unboarding_passengers.wav", id = nil },
	finished_fuel_loading = { path = sound_dir .. "finished_fuel_loading.wav", id = nil },
    cargo_loop                     = { path = sound_dir .. "Exterior-Sound.wav", id = nil },
    passengers_loop                = { path = sound_dir .. "Cabin-Pax.wav", id = nil },
	start_fuel_loading			   = { path = sound_dir .. "Start-fuel.wav", id = nil },
	fuel_loop 					   = { path = sound_dir .. "fuel-Loop.wav", id = nil }
}

function init_sounds()
    for name, sound in pairs(sounds) do
        local full_path = sound.path
        sound.id = load_WAV_file(full_path)
        if sound.id ~= 0 then
            set_sound_gain(sound.id, Volume)
        end
    end
end

function play_sound_by_key(sound_key)
    if sounds[sound_key] then
        local this_id = sounds[sound_key].id
        if this_id and this_id ~= 0 then
            flywithlua_play_sound(this_id)
        end
    end
end

function set_all_sounds_gain(gain)
    local new_gain = (gain > 0) and gain or 0.0001

    for name, snd in pairs(sounds) do
        if snd.id ~= 0 then
            set_sound_gain(snd.id, new_gain)
        end
    end
end

init_sounds()

function update_loop_volumes()
    if is_muted then
        set_sound_gain(sounds.cargo_loop.id, 0.0001)
        set_sound_gain(sounds.fuel_loop.id, 0.0001)
        set_sound_gain(sounds.passengers_loop.id, 0.0001)
    else
        if cargo_loop_playing then
            set_sound_gain(sounds.cargo_loop.id, view_is_external == 1 and 1.0 or 0.3)
        end
        if fuel_loop_playing then
            set_sound_gain(sounds.fuel_loop.id, view_is_external == 1 and 1.0 or 0.3)
        end
        if pax_loop_playing then
            set_sound_gain(sounds.passengers_loop.id, view_is_external == 1 and 0.0001 or 0.9)
        end
    end
end


--------------------------------------------------------------------------------
-- SETTINGS
--------------------------------------------------------------------------------


function load_user_settings()
    local file_exists = false
    local file = io.open(settings_file, "r")
    if file then
        file_exists = true
        for line in file:lines() do
            local key, value = string.match(line, "([^=]+)=([^=]+)")
            if key == "simbrief_id" then
                simbrief_id = value
            elseif key == "unit_system" then
                if value == "kg" or value == "lbs" then
                    unit_system = value
                end
            elseif key == "timing_preset" then
                if value == "realistic" or value == "fast" or value == "veryfast" or value == "custom" then
                    timing_preset = value
                end
            elseif key == "fuel_first" then
                fuel_first = (value == "true")

            elseif key == "custom_pax_time_per_passenger" then
                custom_pax_time_per_passenger = tonumber(value)
            elseif key == "custom_pax_time_variation" then
                custom_pax_time_variation = tonumber(value)
            elseif key == "custom_disembark_pax_time_per_passenger" then
                custom_disembark_pax_time_per_passenger = tonumber(value)
            elseif key == "custom_disembark_pax_time_variation" then
                custom_disembark_pax_time_variation = tonumber(value)
            elseif key == "custom_cargo_time_per_kg_min" then
                custom_cargo_time_per_kg_min = tonumber(value)
            elseif key == "custom_cargo_time_per_kg_max" then
                custom_cargo_time_per_kg_max = tonumber(value)
            elseif key == "custom_disembark_cargo_time_per_kg_min" then
                custom_disembark_cargo_time_per_kg_min = tonumber(value)
            elseif key == "custom_disembark_cargo_time_per_kg_max" then
                custom_disembark_cargo_time_per_kg_max = tonumber(value)
            elseif key == "custom_fuel_time_per_kg" then
                custom_fuel_time_per_kg = tonumber(value)
            end
        end
        file:close()
    end
	
	if not file_exists then
		save_user_settings()
    end
end



function save_user_settings()
    local file = io.open(settings_file, "w")
    if file then
        file:write("simbrief_id=" .. simbrief_id .. "\n")
        file:write("unit_system=" .. unit_system .. "\n")
        file:write("timing_preset=" .. timing_preset .. "\n")
        file:write("fuel_first=" .. tostring(fuel_first) .. "\n")
        file:write("custom_pax_time_per_passenger=" .. tostring(custom_pax_time_per_passenger or 5) .. "\n")
        file:write("custom_pax_time_variation=" .. tostring(custom_pax_time_variation or 3) .. "\n")
        file:write("custom_disembark_pax_time_per_passenger=" .. tostring(custom_disembark_pax_time_per_passenger or 4) .. "\n")
        file:write("custom_disembark_pax_time_variation=" .. tostring(custom_disembark_pax_time_variation or 3) .. "\n")
        file:write("custom_cargo_time_per_kg_min=" .. tostring(custom_cargo_time_per_kg_min or 0.3) .. "\n")
        file:write("custom_cargo_time_per_kg_max=" .. tostring(custom_cargo_time_per_kg_max or 0.6) .. "\n")
        file:write("custom_disembark_cargo_time_per_kg_min=" .. tostring(custom_disembark_cargo_time_per_kg_min or 0.2) .. "\n")
        file:write("custom_disembark_cargo_time_per_kg_max=" .. tostring(custom_disembark_cargo_time_per_kg_max or 0.6) .. "\n")
        file:write("custom_fuel_time_per_kg=" .. tostring(custom_fuel_time_per_kg or 0.053) .. "\n")

        file:close()
    end
end



function fetch_simbrief_data(id)
    simbrief_data_loaded = true
    local http = require("socket.http")
    local body, code = http.request("https://www.simbrief.com/api/xml.fetcher.php?userid=" .. id)
    if not body or code ~= 200 then
        logMsg("[SLM] SimBrief request failed or invalid response")
        return
    end

    -- SECTION: Helpers
    local function val(tag)
        return string.match(body, "<" .. tag .. ">(.-)</" .. tag .. ">") or ""
    end
    local function num(tag)
        return tonumber(val(tag)) or 0
    end
    local function nv(parent, child)
        return string.match(body, "<" .. parent .. ">.-<" .. child .. ">(.-)</" .. child .. ">.-</" .. parent .. ">") or ""
    end
    local function nnum(parent, child)
        return tonumber(nv(parent, child)) or 0
    end
    local function nonempty(s, fallback)
        return (s ~= nil and s ~= "") and s or fallback
    end
    local function fnum(tag)
        return tonumber(string.match(body, "<fuel>.-<" .. tag .. ">([%d%.]+)</" .. tag .. ">")) or 0
    end

    -- SECTION: Units
    local sb_unit = val("units")
    if sb_unit == "kgs" then
        unit_system = "kg"
    elseif sb_unit == "lbs" then
        unit_system = "lbs"
    end

    -- SECTION: Weights (STRICT)
    local pax_count   = nnum("weights", "pax_count")
    local bag_count   = nnum("weights", "bag_count")
    local pax_weight  = nnum("weights", "pax_weight")
    local bag_weight  = nnum("weights", "bag_weight")
	local bag_count = nnum("weights", "bag_count")

    local freight     = nnum("weights", "freight_added")
    local cargo_plan  = nnum("weights", "cargo")
    local payload_plan= nnum("weights", "payload")
    local oew_plan    = nnum("weights", "oew")

    local est_zfw = nnum("weights", "est_zfw")
    local max_zfw = nnum("weights", "max_zfw")
    local est_tow = nnum("weights", "est_tow")
    local max_tow = nnum("weights", "max_tow")
    local est_ldw = nnum("weights", "est_ldw")
    local max_ldw = nnum("weights", "max_ldw")

    -- Derived planned masses (BAGS are not given as a mass tag)
    local pax_mass_planned = pax_count * pax_weight
    local bag_mass_planned = bag_count * bag_weight

    -- SECTION: Core totals used by SLM (STRICT)
    passengers_total = pax_count
    cargo_total      = cargo_plan

    fuel_total       = fnum("plan_ramp")
    fuel_loaded      = math.floor(fuel_total * fuel_start_ratio)

    sched_out = tonumber(val("sched_out")) or 0
    sched_off = tonumber(val("sched_off")) or 0
    sched_on  = tonumber(val("sched_on"))  or 0
    sched_in  = tonumber(val("sched_in"))  or 0

    temp_manual_passengers = passengers_total
    temp_manual_cargo      = cargo_total
    temp_manual_fuel       = fuel_total

    -- SECTION: SimBrief fields (keep existing behavior)
    local airline    = nonempty(nv("general",    "airline"),    val("airline"))
    local fltnum     = nonempty(nv("general",    "fltnum"),     val("fltnum"))
    local orig       = nonempty(nv("origin",     "icao_code"),  val("orig"))
    local dest       = nonempty(nv("destination","icao_code"),  val("dest"))
    local altn       = nonempty(nv("alternate",  "icao_code"),  val("altn"))

    local ac_icao    = nonempty(nv("aircraft",   "icao_code"),  val("type"))
    local ac_name    = nonempty(nv("aircraft",   "name"),       val("aircraft_name"))
    local ac_reg     = nonempty(nv("aircraft",   "reg"),        nonempty(val("reg"), val("registration")))

    local captain    = nonempty(nv("crew", "cpt"), nonempty(val("cpt"), val("pilot_name")))
    local dispatcher = nonempty(nv("crew", "dx"),  nonempty(val("dx"),  val("dispatcher")))

    -- SECTION: Fuel (STRICT source is <fuel>)
    local fuel_taxi  = fnum("taxi")
    local fuel_trip  = fnum("enroute_burn")
    local fuel_cont  = fnum("contingency")
    local fuel_altn  = fnum("alternate_burn")
    local fuel_res   = fnum("reserve")
    local fuel_block = fnum("plan_ramp")
    local fuel_land  = fnum("plan_landing")

    -- SECTION: Export to globals used elsewhere
    SB_pax_weight = pax_weight
    SB_bag_weight = bag_weight
    SB_pax_count  = pax_count
    SB_bag_count  = bag_count
    SB_pax_mass_planned = pax_mass_planned
    SB_bag_mass_planned = bag_mass_planned

    -- SECTION: Loadsheet data
    SLM_Loadsheet_Data = {
        airline = nonempty(airline, "N/A"),
        fltnum  = nonempty(fltnum,  "N/A"),
        date    = os.date("%d%b%y"):upper(),

        aircraft_icao = nonempty(ac_icao, "?"),
        aircraft_name = nonempty(ac_name, "?"),
        reg           = nonempty(ac_reg,  "?"),

        orig = nonempty(orig, "?"),
        dest = nonempty(dest, "?"),
        altn = nonempty(altn, "?"),

        dispatcher = nonempty(dispatcher, "N/A"),
        captain    = nonempty(captain,    "N/A"),

        pax_total   = passengers_total or 0,
        cargo_total = cargo_total or 0,

        payload_planned = payload_plan,
        oew = oew_plan,

        pax_weight = pax_weight,
        bag_weight = bag_weight,
        pax_mass_planned = pax_mass_planned,
        bag_mass_planned = bag_mass_planned,
        pax_count_sb = pax_count,
        bag_count_sb = bag_count,

        freight_added = freight,

        est_zfw = est_zfw,
        max_zfw = max_zfw,
        est_tow = est_tow,
        max_tow = max_tow,
        est_ldw = est_ldw,
        max_ldw = max_ldw,

        fuel_taxi    = fuel_taxi,
        fuel_trip    = fuel_trip,
        fuel_cont    = fuel_cont,
        fuel_altn    = fuel_altn,
        fuel_reserve = fuel_res,
        fuel_block   = fuel_block,
        fuel_land    = fuel_land
    }
end


function apply_realistic_timings()
    pax_time_per_passenger = 5
    pax_time_variation = 3
    disembark_pax_time_per_passenger = 4
    disembark_pax_time_variation = 3
    cargo_time_per_kg_min = 0.3
    cargo_time_per_kg_max = 0.6
    disembark_cargo_time_per_kg_min = 0.2
    disembark_cargo_time_per_kg_max = 0.6
    fuel_time_per_kg = 0.053
	fuel_time_per_unit = fuel_time_per_kg
    timing_preset = "realistic"
end


function apply_fast_timings()
    pax_time_per_passenger = 3
    pax_time_variation = 2
    disembark_pax_time_per_passenger = 2
    disembark_pax_time_variation = 2
    cargo_time_per_kg_min = 0.09
    cargo_time_per_kg_max = 0.11
    disembark_cargo_time_per_kg_min = 0.05
    disembark_cargo_time_per_kg_max = 0.07
    fuel_time_per_kg = 0.043
	fuel_time_per_unit = fuel_time_per_kg
    timing_preset = "fast"
end

function apply_veryfast_timings()

    pax_time_per_passenger = 1.5
    pax_time_variation = 0.5
    disembark_pax_time_per_passenger = 1
    disembark_pax_time_variation = 0.5
    cargo_time_per_kg_min = 0.03
    cargo_time_per_kg_max = 0.05
    disembark_cargo_time_per_kg_min = 0.02
    disembark_cargo_time_per_kg_max = 0.04
    fuel_time_per_kg = 0.020
    fuel_time_per_unit = fuel_time_per_kg

    timing_preset = "veryfast"
end

function apply_custom_timings()
    timing_preset = "custom"
    pax_time_per_passenger = custom_pax_time_per_passenger or 4
    pax_time_variation = custom_pax_time_variation or 2
    disembark_pax_time_per_passenger = custom_disembark_pax_time_per_passenger or 3
    disembark_pax_time_variation = custom_disembark_pax_time_variation or 2
    cargo_time_per_kg_min = custom_cargo_time_per_kg_min or 0.3
    cargo_time_per_kg_max = custom_cargo_time_per_kg_max or 0.6
    disembark_cargo_time_per_kg_min = custom_disembark_cargo_time_per_kg_min or 0.25
    disembark_cargo_time_per_kg_max = custom_disembark_cargo_time_per_kg_max or 0.5
    fuel_time_per_kg = custom_fuel_time_per_kg or 0.05
end


load_user_settings()

if timing_preset == "veryfast" then
    apply_veryfast_timings()
elseif timing_preset == "fast" then
    apply_fast_timings()
elseif timing_preset == "custom" then
    apply_custom_timings()
else
    apply_realistic_timings()
end



--------------------------------------------------------------------------------
-- EMBARKATION
--------------------------------------------------------------------------------

function start_embarkation()
    walking_direction = "boarding"
    walking_direction_changed_armed = false
    embark_started = true
    embark_done = false
    disembark_started = false
    disembark_done = false
	pax_load_started = false
	pax_start_time = 0
    cargo_loaded = 0
    passengers_loaded = 0
    cargo_unloaded = 0
    passengers_unloaded = 0
	bus_triggered = false
    pax_trigger_time = nil
    if unit_system == "lbs" then
        cargo_time_per_unit_min = cargo_time_per_kg_min / 2.20462
        cargo_time_per_unit_max = cargo_time_per_kg_max / 2.20462
    else
        cargo_time_per_unit_min = cargo_time_per_kg_min
        cargo_time_per_unit_max = cargo_time_per_kg_max
    end
    cargo_time_per_unit = random_range(cargo_time_per_unit_min, cargo_time_per_unit_max)
    passengers_total = temp_manual_passengers
    cargo_total = temp_manual_cargo
    fuel_total = temp_manual_fuel or 0
    fuel_loaded = math.floor(fuel_total * fuel_start_ratio)
    start_time = os.clock()
    last_update_time = start_time
    pax_load_started = false
    cargo_start_reference_time = os.clock()
    init_sounds()
end



function manage_embark()
    if not embark_started then return end

    if fuel_first and not fuel_done then
        if not fuel_loading then
            start_fuel_loading()
        end
        manage_fuel_loading()
        return
    end

    if fuel_first and fuel_done and not fuel_wait_finished then
        if not fuel_done_time then
            fuel_done_time = os.clock()
            return
        elseif os.clock() - fuel_done_time < fuel_post_delay then
            return
        else
            fuel_wait_finished = true
			last_update_time = os.clock()
			cargo_start_reference_time = os.clock()
        end
    end

    local now = os.clock()
    local elapsed = now - last_update_time


    -- Case A: Neither cargo nor passengers
    ----------------------------------------------------------------------------
if cargo_total == 0 and passengers_total == 0 then
    if not fuel_loading and not fuel_done then
        start_fuel_loading()
    end
    manage_fuel_loading()
	check_if_all_done()
    return
end

    -- Case B: No cargo (but passengers exist)
    ----------------------------------------------------------------------------
if cargo_total == 0 then
if fuel_first and not fuel_done then return end
    local pax_load_delay = 20
    if selected_location_group == "terminal" then
        pax_load_delay = 2
    end

    if not bus_triggered then
        if selected_location_group == "remote" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
            show_Bus = true
            Bus_chg = true
        elseif selected_location_group == "jetway" and not fuel_first then
            command_once("sim/ground_ops/jetway")
        elseif selected_location_group == "terminal" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
            boarding_from_the_terminal = true
            show_Pax = true
            show_Pax = true
            Pax_chg = true
        end
        bus_triggered = true
        pax_trigger_time = os.clock() + pax_load_delay
    end

    if os.clock() >= pax_trigger_time then
        if not sound_played.start_boarding_passengers then
            play_sound_by_key("start_boarding_passengers")
            sound_played.start_boarding_passengers = true
        end

        if not pax_load_started then
            pax_load_started = true
            pax_start_time = os.clock()
        end

        if pax_load_started and (passengers_loaded < passengers_total) then
            local pax_elapsed = os.clock() - pax_start_time
            local pax_time = pax_time_per_passenger + math.random(0, pax_time_variation)
            if pax_elapsed >= pax_time then
                local inc = math.floor(pax_elapsed / pax_time)
                passengers_loaded = math.min(passengers_loaded + inc, passengers_total)
                pax_start_time = os.clock()
            end
			
			if passengers_loaded >= math.floor(passengers_total * 0.15)
               and not fuel_loading
               and not fuel_done
            then
                start_fuel_loading()
            end
			
            if not pax_loop_playing then
                pax_loop_playing = true
                let_sound_loop(sounds.passengers_loop.id, true)
                play_sound(sounds.passengers_loop.id)
            end
        else
            if pax_loop_playing then
                pax_loop_playing = false
                let_sound_loop(sounds.passengers_loop.id, false)
                stop_sound(sounds.passengers_loop.id)
            end
            if passengers_loaded >= passengers_total then
                if not sound_played.finished_loading_pax then
                    play_sound_by_key("finished_loading_pax")
                    sound_played.finished_loading_pax = true
                    show_Bus = false
                    Bus_chg = true
                    boarding_from_the_terminal = false
                    show_Pax = false
                    Pax_chg = true
                end
            end
        end
    end
    manage_fuel_loading()
	check_if_all_done()
    return
end

    -- Case C: No passengers (but cargo exists)
    ----------------------------------------------------------------------------
   if passengers_total == 0 then
   if fuel_first and not fuel_done then return end
    if cargo_loaded < cargo_total and elapsed >= cargo_time_per_unit then
        local inc = math.floor(elapsed / cargo_time_per_unit)
        cargo_loaded = math.min(cargo_loaded + inc, cargo_total)
        last_update_time = now
    end

    if cargo_loaded == 0 and not sound_played.start_loading_cargo then
        play_sound_by_key("start_loading_cargo")
        sound_played.start_loading_cargo = true

        show_BeltLoader = true
        BeltLoader_chg = true
        show_RearBeltLoader = true
        RearBeltLoader_chg = true
        show_Cart = true
        Cart_chg = true
        show_People4 = true
        People4_chg = true
        show_People3 = true
        People3_chg = true
        show_People2 = true
        People2_chg = true
        show_People1 = true
        People1_chg = true
        show_Chocks = true
        Chocks_chg = true

        if selected_location_group == "remote" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
        elseif selected_location_group == "jetway" and not fuel_first then
            command_once("sim/ground_ops/jetway")
        elseif selected_location_group == "terminal"  then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
        end
    end

    if cargo_loaded < cargo_total then
        if not cargo_loop_playing then
            cargo_loop_playing = true
            let_sound_loop(sounds.cargo_loop.id, true)
            play_sound(sounds.cargo_loop.id)
        end
    else
        if cargo_loop_playing then
            cargo_loop_playing = false
            let_sound_loop(sounds.cargo_loop.id, false)
            stop_sound(sounds.cargo_loop.id)
        end
        if not sound_played.finished_loading_cargo then
            play_sound_by_key("finished_loading_cargo")
            sound_played.finished_loading_cargo = true
            show_BeltLoader = false
            BeltLoader_chg = true
            show_RearBeltLoader = false
            RearBeltLoader_chg = true
            show_Cart = false
            Cart_chg = true
        end

        if not fuel_loading and not fuel_done then
            start_fuel_loading()
        end
    end
    manage_fuel_loading()
	check_if_all_done()
    return
end


-- Case D: Both cargo and passengers present (mixed)
----------------------------------------------------------------------------
if fuel_first and not fuel_done then
    start_fuel_loading()
    manage_fuel_loading()
    return
end

if not cargo_start_reference_time then
    cargo_start_reference_time = os.clock()
end

if cargo_loaded < cargo_total and elapsed >= cargo_time_per_unit then
    local inc = math.floor(elapsed / cargo_time_per_unit)
    cargo_loaded = math.min(cargo_loaded + inc, cargo_total)
    last_update_time = now
end

if cargo_loaded == 0 and not sound_played.start_loading_cargo then
    play_sound_by_key("start_loading_cargo")
    sound_played.start_loading_cargo = true
    show_BeltLoader = true
    BeltLoader_chg = true
    show_RearBeltLoader = true
    RearBeltLoader_chg = true
    show_Cart = true
    Cart_chg = true
    show_People4 = true
    People4_chg = true
    show_People3 = true
    People3_chg = true
    show_People2 = true
    People2_chg = true
    show_People1 = true
    People1_chg = true
    show_Chocks = true
    Chocks_chg = true

    if selected_location_group == "remote" then
		if not aircraft_has_own_stairs then
			show_StairsXPJ = true
			StairsXPJ_chg = true
			option_StairsXPJ_override = true
		else
			show_StairsXPJ = false
			StairsXPJ_chg = true
			option_StairsXPJ_override = false
		end
    elseif selected_location_group == "jetway" and not fuel_first then
        command_once("sim/ground_ops/jetway")
    elseif selected_location_group == "terminal" then
		if not aircraft_has_own_stairs then
			show_StairsXPJ = true
			StairsXPJ_chg = true
			option_StairsXPJ_override = true
		else
			show_StairsXPJ = false
			StairsXPJ_chg = true
			option_StairsXPJ_override = false
		end
    end
end

if cargo_loaded < cargo_total then
    if not cargo_loop_playing then
        cargo_loop_playing = true
        let_sound_loop(sounds.cargo_loop.id, true)
        play_sound(sounds.cargo_loop.id)
    end
else
    if cargo_loop_playing then
        cargo_loop_playing = false
        let_sound_loop(sounds.cargo_loop.id, false)
        stop_sound(sounds.cargo_loop.id)
    end
    if not sound_played.finished_loading_cargo then
        play_sound_by_key("finished_loading_cargo")
        sound_played.finished_loading_cargo = true
        show_BeltLoader = false
        BeltLoader_chg = true
        show_RearBeltLoader = false
        RearBeltLoader_chg = true
        show_Cart = false
        Cart_chg = true
    end
end

local est_cargo = estimated_time_cargo or 0
local est_pax   = estimated_time_pax or 0

	if not pax_load_started then
		if not bus_triggered then
			if est_cargo > 0
			   and est_pax > 0
			   and ((est_cargo - est_pax) <= 120)
			   and (os.clock() - start_time > 3)
			then
				if selected_location_group == "remote" then
					show_Bus = true
					Bus_chg = true
				elseif selected_location_group == "terminal" then
					show_Pax = true
					Pax_chg = true
					boarding_from_the_terminal = true
				end

				bus_triggered = true

				local delay_pax = 0
				if selected_location_group == "remote" then
					delay_pax = 20
				elseif selected_location_group == "terminal" then
					delay_pax = 4
				elseif selected_location_group == "jetway" then
					delay_pax = 4
				end

				pax_trigger_time = os.clock() + delay_pax
			end
		end

		if bus_triggered and pax_trigger_time and os.clock() >= pax_trigger_time then
			pax_load_started = true
			pax_start_time = os.clock()
			if not sound_played.start_boarding_passengers then
				play_sound_by_key("start_boarding_passengers")
				sound_played.start_boarding_passengers = true
			end
		end
	end

	if pax_load_started and (passengers_loaded < passengers_total) then
		local now_clock = os.clock()
		local pax_elapsed = now_clock - pax_start_time
		local pax_time = pax_time_per_passenger + math.random(0, pax_time_variation)

		if pax_elapsed >= pax_time then
			local inc = math.floor(pax_elapsed / pax_time)
			passengers_loaded = math.min(passengers_loaded + inc, passengers_total)
			pax_start_time = now_clock
		end

		if not pax_loop_playing then
			pax_loop_playing = true
			let_sound_loop(sounds.passengers_loop.id, true)
			play_sound(sounds.passengers_loop.id)
		end
	else
		if pax_loop_playing then
			pax_loop_playing = false
			let_sound_loop(sounds.passengers_loop.id, false)
			stop_sound(sounds.passengers_loop.id)
		end
		if passengers_loaded >= passengers_total and not sound_played.finished_loading_pax then
			play_sound_by_key("finished_loading_pax")
			sound_played.finished_loading_pax = true
			show_Bus = false
			Bus_chg = true
			boarding_from_the_terminal = false
			show_Pax = false
			Pax_chg = true
		end
	end

		if passengers_loaded >= math.floor(passengers_total * 0.15)
		   and not fuel_loading
		   and not fuel_done
		then
			start_fuel_loading()
		end
	manage_fuel_loading()
	check_if_all_done()
end


--------------------------------------------------------------------------------
-- DISEMBARKATION
--------------------------------------------------------------------------------
function start_disembarkation()
    disembark_started = true
    disembark_done = false
    embark_started = false
    embark_done = false
	walking_direction = "deboarding"
	walking_direction_changed_armed = false
    cargo_unloaded = 0
    passengers_unloaded = 0
	
	if unit_system == "lbs" then
		cargo_time_per_unit_min = disembark_cargo_time_per_kg_min / 2.20462
		cargo_time_per_unit_max = disembark_cargo_time_per_kg_max / 2.20462
	else
		cargo_time_per_unit_min = disembark_cargo_time_per_kg_min
		cargo_time_per_unit_max = disembark_cargo_time_per_kg_max
	end

	cargo_time_per_unit = random_range(cargo_time_per_unit_min, cargo_time_per_unit_max)

    passengers_total = temp_manual_passengers
    cargo_total = temp_manual_cargo

    disembark_start_time = os.clock()
    disembark_last_update_time = disembark_start_time
    pax_unload_started = false
    pax_unload_start_time = 0
    estimated_time_pax = 0

    init_sounds()

    if cargo_total > 0 and passengers_total > 0 then
        play_sound_by_key("start_unloading_cargo")
        sound_played.start_unloading_cargo = true
		show_BeltLoader = true
		BeltLoader_chg = true
		show_RearBeltLoader = true
		RearBeltLoader_chg = true
		show_Cart = true
		Cart_chg = true
		show_People4 = true
		People4_chg = true
		show_People3 = true
		People3_chg = true
		show_People2 = true
		People2_chg = true
		show_People1 = true
		People1_chg = true
		show_Chocks = true
		Chocks_chg = true
		if selected_location_group == "remote" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
			show_Bus = true
			Bus_chg = true
			start_disembarkation_pax_delay = os.clock() + 15
		elseif selected_location_group == "jetway" then
			if (not autodgs_available) or (autodgs_on_ground ~= 1) then
				command_once("sim/ground_ops/jetway")
			end
			start_disembarkation_pax_delay = os.clock() + 25
        elseif selected_location_group == "terminal" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
			start_disembarkation_pax_delay = os.clock() + 8
        end
    elseif cargo_total > 0 then
        play_sound_by_key("start_unloading_cargo")
        sound_played.start_unloading_cargo = true
		show_BeltLoader = true
		BeltLoader_chg = true
		show_RearBeltLoader = true
		RearBeltLoader_chg = true
		show_Cart = true
		Cart_chg = true
		show_People4 = true
		People4_chg = true
		show_People3 = true
		People3_chg = true
		show_People2 = true
		People2_chg = true
		show_People1 = true
		People1_chg = true
		show_Chocks = true
		Chocks_chg = true
		if selected_location_group == "remote" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
        elseif selected_location_group == "jetway" then
			if (not autodgs_available) or (autodgs_on_ground ~= 1) then
				command_once("sim/ground_ops/jetway")
			end
        elseif selected_location_group == "terminal" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
        end
    elseif passengers_total > 0 then
        play_sound_by_key("start_unboarding_passengers")
		show_People4 = true
		People4_chg = true
		show_People3 = true
		People3_chg = true
		show_People2 = true
		People2_chg = true
		show_People1 = true
		People1_chg = true
		show_Chocks = true
		Chocks_chg = true
        sound_played.start_unboarding_passengers = true
		if selected_location_group == "remote" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
			show_Bus = true
			Bus_chg = true
        elseif selected_location_group == "jetway" then
			if (not autodgs_available) or (autodgs_on_ground ~= 1) then
				command_once("sim/ground_ops/jetway")
			end
        elseif selected_location_group == "terminal" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
			boarding_from_the_terminal = true
        end
    end
end

function manage_disembark()
    if not disembark_started then return end

    local now = os.clock()
    local elapsed = now - disembark_last_update_time
	--local cargo_time_per_unit = random_range(cargo_time_per_unit_min, cargo_time_per_unit_max)

    -- Cargo management
    ----------------------------------------------------------------------------
    if cargo_total > 0 then
        if cargo_unloaded < cargo_total then
            if elapsed >= cargo_time_per_unit then
				local increment = math.floor(elapsed / cargo_time_per_unit)
                cargo_unloaded = math.min(cargo_unloaded + increment, cargo_total)
                disembark_last_update_time = now
            end
        end

        if cargo_unloaded < cargo_total then
            if not cargo_loop_playing then
                cargo_loop_playing = true
                let_sound_loop(sounds.cargo_loop.id, true)
                play_sound(sounds.cargo_loop.id)
            end
        else
            if cargo_loop_playing then
                cargo_loop_playing = false
                let_sound_loop(sounds.cargo_loop.id, false)
                stop_sound(sounds.cargo_loop.id)
            end
            if not sound_played.finished_unloading_cargo then
                play_sound_by_key("finished_unloading_cargo")
                sound_played.finished_unloading_cargo = true
				show_BeltLoader = false
				BeltLoader_chg = true
				show_RearBeltLoader = false
				RearBeltLoader_chg = true
				show_Cart = false
				Cart_chg = true
            end
        end
    else
        cargo_unloaded = 0
    end

    -- Passenger management with a delay
    ----------------------------------------------------------------------------
    if passengers_total > 0 then
        if cargo_total > 0 and now < start_disembarkation_pax_delay then
        else
			 if not sound_played.start_unboarding_passengers then
				play_sound_by_key("start_unboarding_passengers")
				sound_played.start_unboarding_passengers = true

				if selected_location_group == "terminal" then
					boarding_from_the_terminal = true
					show_Pax = true
					Pax_chg = true
				elseif selected_location_group == "remote" then
					show_Pax = true
					Pax_chg = true
				end
			end

            if not pax_unload_started then
                pax_unload_started = true
                pax_unload_start_time = now
            end

            if passengers_unloaded < passengers_total then
                local pax_elapsed = now - pax_unload_start_time
                local pax_time = disembark_pax_time_per_passenger + math.random(0, disembark_pax_time_variation)
                if pax_elapsed >= pax_time then
                    local increment = math.floor(pax_elapsed / pax_time)
                    passengers_unloaded = math.min(passengers_unloaded + increment, passengers_total)
                    pax_unload_start_time = now
                end
            end

            if passengers_unloaded < passengers_total then
                if not pax_loop_playing then
                    pax_loop_playing = true
                    let_sound_loop(sounds.passengers_loop.id, true)
                    play_sound(sounds.passengers_loop.id)
                end
            else
                if pax_loop_playing then
                    pax_loop_playing = false
                    let_sound_loop(sounds.passengers_loop.id, false)
                    stop_sound(sounds.passengers_loop.id)
                end
                if not sound_played.finished_unboarding_passengers then
                    play_sound_by_key("finished_unboarding_passengers")
                    sound_played.finished_unboarding_passengers = true
					show_Bus = false
					Bus_chg = true
					boarding_from_the_terminal = false
					show_Pax = false
					Pax_chg = true
                end
            end
        end
    else
        passengers_unloaded = 0
    end
	
    -- End of disembark management: if for each category the total is 0 or fully unloaded, finish phase
    ----------------------------------------------------------------------------
    if (cargo_total == 0 or cargo_unloaded >= cargo_total) and 
       (passengers_total == 0 or passengers_unloaded >= passengers_total) then
        disembark_started = false
        disembark_done = true
		show_BeltLoader = false
		BeltLoader_chg = true
		show_RearBeltLoader = false
		RearBeltLoader_chg = true
		show_Cart = false
		Cart_chg = true
		show_People4 = false
		People4_chg = true
		show_People3 = false
		People3_chg = true
		show_People2 = false
		People2_chg = true
		show_People1 = false
		People1_chg = true
		show_Chocks = false
		Chocks_chg = true
		show_StairsXPJ = false
		StairsXPJ_chg = true
    end
end

--------------------------------------------------------------------------------
-- FUEL MANAGEMENT & END OF OPERATIONS
--------------------------------------------------------------------------------

function start_fuel_loading()
    fuel_loading = true
    fuel_done = false
    show_FUEL = true
    FUEL_chg = true
    fuel_ready_time = os.clock() + 30

    if fuel_first then
        show_People1 = true
        People1_chg = true
        show_People2 = true
        People2_chg = true
        show_People3 = true
        People3_chg = true
        show_People4 = true
        People4_chg = true
        show_Chocks = true
        Chocks_chg = true

        if selected_location_group == "remote" or selected_location_group == "terminal" then
			if not aircraft_has_own_stairs then
				show_StairsXPJ = true
				StairsXPJ_chg = true
				option_StairsXPJ_override = true
			else
				show_StairsXPJ = false
				StairsXPJ_chg = true
				option_StairsXPJ_override = false
			end
        elseif selected_location_group == "jetway" then
            command_once("sim/ground_ops/jetway")
        end
    end
end


function manage_fuel_loading()
    if fuel_loading and not fuel_done then
        if not fuel_time_per_unit then
            if unit_system == "lbs" then
                fuel_time_per_unit = fuel_time_per_kg / 2.20462
            else
                fuel_time_per_unit = fuel_time_per_kg
            end
        end

        if fuel_ready_time and os.clock() < fuel_ready_time then
            return
        end

        if not sound_played.start_fuel_loading then
            play_sound_by_key("start_fuel_loading")
            sound_played.start_fuel_loading = true
        end

        if not fuel_loop_playing then
            fuel_loop_playing = true
            let_sound_loop(sounds.fuel_loop.id, true)
            play_sound(sounds.fuel_loop.id)
        end

        local now = os.clock()
        if not fuel_last_update_time then fuel_last_update_time = now end
        local elapsed = now - fuel_last_update_time

        local increment = math.floor(elapsed / fuel_time_per_unit)
        if increment > 0 then
            fuel_loaded = math.min(fuel_loaded + increment, fuel_total)
            fuel_last_update_time = now
        end

        if fuel_loaded >= fuel_total then
            show_FUEL = false
            FUEL_chg = true

            if fuel_loop_playing then
                fuel_loop_playing = false
                let_sound_loop(sounds.fuel_loop.id, false)
                stop_sound(sounds.fuel_loop.id)
            end

            fuel_loading = false
            fuel_done = true

            if not sound_played.finished_fuel_loading then
                play_sound_by_key("finished_fuel_loading")
                sound_played.finished_fuel_loading = true
            end
        end
    end
end

function check_if_all_done()
    if embark_started
       and (cargo_total == 0 or cargo_loaded >= cargo_total)
       and (passengers_total == 0 or passengers_loaded >= passengers_total)
       and (fuel_total == 0 or fuel_loaded >= fuel_total)
    then
        if end_time == nil then
            end_time = os.clock() + FINISHED_ALL_DELAY
        elseif os.clock() >= end_time then
            embark_started = false
            embark_done = true

            if not sound_played.finished_loading_all then
                play_sound_by_key("finished_loading_all")
                sound_played.finished_loading_all = true

                local pax_actual   = passengers_loaded or 0
                local cargo_actual = cargo_loaded or 0
                local fuel_actual  = fuel_loaded or 0

                -- Weights-first: use SimBrief weights-derived pax weight (no loadsheet fallback to avoid mismatches)
                local pax_w = SB_pax_weight or 0

                local pax_mass = pax_actual * pax_w

                SLM_real_pax        = pax_actual
                SLM_real_cargo      = cargo_actual
                SLM_real_fuel_block = fuel_actual

                -- Payload actual = Pax mass (already calculated) + Cargo actual (bags + freight already included in cargo)
                SLM_real_payload    = pax_mass + cargo_actual

                loadsheet_ready = true
                logMsg("[SLM] Loadsheet is now available (loading completed).")

                show_Cones     = false; Cones_chg     = true
                show_People4   = false; People4_chg   = true
                show_People3   = false; People3_chg   = true
                show_People2   = false; People2_chg   = true
                show_People1   = false; People1_chg   = true
                show_Chocks    = false; Chocks_chg    = true
                show_StairsXPJ = false; StairsXPJ_chg = true

                if selected_location_group == "jetway" then
                    command_once("sim/ground_ops/jetway")
                end
            end

            end_time = nil
        end
    end
end

--------------------------------------------------------------------------------
-- RESET
--------------------------------------------------------------------------------
function reset_loads()
    cargo_loaded          = 0
    passengers_loaded     = 0
    cargo_unloaded        = 0
    passengers_unloaded   = 0
	cargo_total = 0
	passengers_total = 0
    embark_started        = false
    embark_done           = false
    disembark_started     = false
    disembark_done        = false
    temp_manual_passengers = 0
    temp_manual_cargo     = 0
	temp_manual_fuel     = 0
	fuel_loaded = 0
	fuel_done = false
	fuel_loading = false
	fuel_ready_time = nil
	fuel_time_per_unit = nil
	fuel_last_update_time = nil
	fuel_total = 0
	show_People4 = false
	People4_chg = true
	show_People3 = false
	People3_chg = true
	show_People2 = false
	People2_chg = true
	show_People1 = false
	People1_chg = true
	show_Chocks = false
	Chocks_chg = true
	show_BeltLoader = false
	BeltLoader_chg = true
	show_RearBeltLoader = false
	RearBeltLoader_chg = true
	show_Cart = false
	Cart_chg = true
	boarding_from_the_terminal = false
	show_Pax = false
	Pax_chg = true
	show_Bus = false
	Bus_chg = true
	show_StairsXPJ = false
	StairsXPJ_chg = true
	option_StairsXPJ_override = false
	bus_triggered = false
	show_FUEL = false
	FUEL_chg = true
	simbrief_data_loaded = false
	loadsheet_ready = false
	
	estimated_time_cargo = nil
    estimated_time_pax   = nil
    estimated_time_fuel  = nil
    cargo_start_reference_time = nil
    disembark_start_time = nil
    disembark_last_update_time = nil
	
	start_time = 0
	last_update_time = 0
	pax_start_time = 0
	pax_trigger_time = nil
	fuel_done_time = nil
	fuel_wait_finished = false
	end_time = nil
	
	sched_out = 0
	sched_off = 0
	sched_on  = 0
	sched_in  = 0

	block_off_time = "--:--Z"
	beacon_prev = 0
	takeoff_time = "--:--Z"
	onground_prev = 1
	landing_time = "--:--Z"
	block_on_time = "--:--Z"
	passed_1000ft = false
	SLM_real_pax        = 0
	SLM_real_cargo      = 0
	SLM_real_fuel_block = 0
	SLM_real_payload    = 0
	SB_pax_weight = 0
	SB_bag_weight = 0
	SB_pax_count  = 0
	SB_bag_count  = 0
	SB_pax_mass_planned = 0
	SB_bag_mass_planned = 0
	SLM_Loadsheet_Data = nil
	SLM_state[0]           = 0
	SLM_is_busy[0]         = 0
	SLM_loadsheet_ready[0] = 0
	SLM_pax_total[0]   = 0
	SLM_cargo_total[0] = 0
	SLM_fuel_total[0]  = 0
	SLM_pax_done[0]   = 0
	SLM_cargo_done[0] = 0
	SLM_fuel_done[0]  = 0
	SLM_pax_fraction[0]   = 0
	SLM_cargo_fraction[0] = 0
	SLM_fuel_fraction[0]  = 0
	SLM_eta_pax[0]   = 0
	SLM_eta_cargo[0] = 0
	SLM_eta_fuel[0]  = 0
	SLM_eta_total[0] = 0
	SLM_pax_state[0]   = 0
	SLM_cargo_state[0] = 0
	SLM_fuel_state[0]  = 0
	SLM_ls_diff_pax[0]        = 0
	SLM_ls_diff_cargo[0]      = 0
	SLM_ls_diff_fuel_block[0] = 0
	SLM_ls_diff_payload[0]    = 0

	update_slm_datarefs()

    sound_played = {
        start_loading_cargo = false,
        start_boarding_passengers = false,
        finished_loading_cargo = false,
        finished_loading_pax = false,
        finished_loading_all = false,
        start_unboarding_passengers = false,
        finished_unboarding_all = false,
		start_fuel_loading = false,
		finished_fuel_loading = false
		}
	
    if cargo_loop_playing then
        cargo_loop_playing = false
        let_sound_loop(sounds.cargo_loop.id, false)
        stop_sound(sounds.cargo_loop.id)
    end

    if pax_loop_playing then
        pax_loop_playing = false
        let_sound_loop(sounds.passengers_loop.id, false)
        stop_sound(sounds.passengers_loop.id)
    end
	
	if fuel_loop_playing then
		fuel_loop_playing = false
		let_sound_loop(sounds.fuel_loop.id, false)
		stop_sound(sounds.fuel_loop.id)
    end
end

--------------------------------------------------------------------------------
-- TIME ESTIMATION
--------------------------------------------------------------------------------
local last_time_update = os.clock()

function update_remaining_time()
    if os.clock() - last_time_update > 1 then
        if embark_started then
            local avg_cargo_time_local = (cargo_time_per_kg_min + cargo_time_per_kg_max) / 2
            if unit_system == "lbs" then
                avg_cargo_time_local = avg_cargo_time_local / 2.20462
            end

			local avg_pax_time_local = (pax_time_per_passenger + pax_time_variation) / 2
			local time_cargo = (cargo_total - cargo_loaded) * avg_cargo_time_local
			local time_pax = 0
			if pax_load_started then
				time_pax = (passengers_total - passengers_loaded) * avg_pax_time_local
			else
				time_pax = passengers_total * avg_pax_time_local
			end
			estimated_time_cargo = time_cargo
			estimated_time_pax   = time_pax

            -- Fuel
            if fuel_total > 0 and fuel_time_per_unit then
                local fuel_remaining = fuel_total - fuel_loaded
                estimated_time_fuel = fuel_remaining * fuel_time_per_unit
            else
                estimated_time_fuel = nil
            end
        end

        if disembark_started then
            local avg_dis_cargo = (disembark_cargo_time_per_kg_min + disembark_cargo_time_per_kg_max) / 2
            local avg_dis_pax   = (disembark_pax_time_per_passenger + disembark_pax_time_variation) / 2
            if unit_system == "lbs" then
                avg_dis_cargo = avg_dis_cargo / 2.20462
            end

            estimated_time_cargo = (cargo_total - cargo_unloaded) * avg_dis_cargo
            estimated_time_pax   = (passengers_total - passengers_unloaded) * avg_dis_pax
        end

        last_time_update = os.clock()
    end
end

--------------------------------------------------------------------------------
-- UPDATE SLM DATAREFS
--------------------------------------------------------------------------------
function update_slm_datarefs()

    -- GLOBAL STATE
    if embark_started then
        SLM_state[0] = 1
    elseif disembark_started then
        SLM_state[0] = 2
    elseif embark_done then
        SLM_state[0] = 3
    elseif disembark_done then
        SLM_state[0] = 4
    else
        SLM_state[0] = 0
    end

    SLM_is_busy[0] = (embark_started or disembark_started) and 1 or 0
    SLM_loadsheet_ready[0] = loadsheet_ready and 1 or 0

    -- LOCATION / OPTIONS
    if selected_location_group == "remote" then
        SLM_location_mode[0] = 0
    elseif selected_location_group == "terminal" then
        SLM_location_mode[0] = 1
    elseif selected_location_group == "jetway" then
        SLM_location_mode[0] = 2
    end

    SLM_aircraft_own_stairs[0] = aircraft_has_own_stairs and 1 or 0

    -- TOTALS
    SLM_pax_total[0]   = passengers_total or 0
    SLM_cargo_total[0] = cargo_total or 0
    SLM_fuel_total[0]  = fuel_total or 0

    -- DONE
	if embark_started then
		SLM_pax_done[0] = passengers_loaded or 0
	elseif disembark_started then
		SLM_pax_done[0] = (passengers_total - passengers_unloaded) or 0
	elseif embark_done then
		SLM_pax_done[0] = passengers_total or 0
	elseif disembark_done then
		SLM_pax_done[0] = 0
	else
		SLM_pax_done[0] = 0
	end
	
	   if embark_started then
        SLM_fuel_done[0] = fuel_loaded or 0
    elseif embark_done then
        SLM_fuel_done[0] = fuel_total or 0
    else
        SLM_fuel_done[0] = 0
    end

	if embark_started then
		SLM_cargo_done[0] = cargo_loaded or 0
	elseif disembark_started then
		SLM_cargo_done[0] = (cargo_total - cargo_unloaded) or 0
	elseif embark_done then
		SLM_cargo_done[0] = cargo_total or 0
	elseif disembark_done then
		SLM_cargo_done[0] = 0
	else
		SLM_cargo_done[0] = 0
	end

    -- FRACTIONS
    SLM_pax_fraction[0] =
        (passengers_total > 0) and (SLM_pax_done[0] / passengers_total) or 0

    SLM_cargo_fraction[0] =
        (cargo_total > 0) and (SLM_cargo_done[0] / cargo_total) or 0

    SLM_fuel_fraction[0] =
        (fuel_total > 0) and (fuel_loaded / fuel_total) or 0

    -- ETA
    SLM_eta_pax[0]   = estimated_time_pax   or 0
    SLM_eta_cargo[0] = estimated_time_cargo or 0
    SLM_eta_fuel[0]  = estimated_time_fuel  or 0

    local eta_total = 0
    if estimated_time_pax   then eta_total = eta_total + estimated_time_pax end
    if estimated_time_cargo then eta_total = eta_total + estimated_time_cargo end
    if estimated_time_fuel  then eta_total = eta_total + estimated_time_fuel end
    SLM_eta_total[0] = eta_total

    -- STATES
    if passengers_total == 0 or not pax_load_started then
        SLM_pax_state[0] = 0
    elseif SLM_pax_done[0] >= passengers_total then
        SLM_pax_state[0] = 2
    else
        SLM_pax_state[0] = 1
    end

    if cargo_total == 0 then
        SLM_cargo_state[0] = 0
    elseif SLM_cargo_done[0] >= cargo_total then
        SLM_cargo_state[0] = 2
    else
        SLM_cargo_state[0] = 1
    end

    if fuel_total == 0 or (not fuel_loading and not fuel_done) then
        SLM_fuel_state[0] = 0
    elseif fuel_done then
        SLM_fuel_state[0] = 2
    else
        SLM_fuel_state[0] = 1
    end

    -- LOADSHEET ACTUAL
    if loadsheet_ready then
        SLM_ls_actual_pax[0]        = SLM_real_pax or 0
        SLM_ls_actual_cargo[0]      = SLM_real_cargo or 0
        SLM_ls_actual_fuel_block[0] = SLM_real_fuel_block or 0
        SLM_ls_actual_payload[0]    = SLM_real_payload or 0
    else
        SLM_ls_actual_pax[0]        = 0
        SLM_ls_actual_cargo[0]      = 0
        SLM_ls_actual_fuel_block[0] = 0
        SLM_ls_actual_payload[0]    = 0
    end

    -- LOADSHEET DIFF (Actual - SimBrief)
    if loadsheet_ready and simbrief_data_loaded and SLM_Loadsheet_Data then
        SLM_ls_diff_pax[0] =
            (SLM_real_pax or 0) - (SB_pax_count or 0)

        SLM_ls_diff_cargo[0] =
            (SLM_real_cargo or 0) - (SLM_Loadsheet_Data.cargo_total or 0)

        SLM_ls_diff_fuel_block[0] =
            (SLM_real_fuel_block or 0) - (SLM_Loadsheet_Data.fuel_block or 0)

        SLM_ls_diff_payload[0] =
            (SLM_real_payload or 0) - (SLM_Loadsheet_Data.payload_planned or 0)
    else
        SLM_ls_diff_pax[0]        = 0
        SLM_ls_diff_cargo[0]      = 0
        SLM_ls_diff_fuel_block[0] = 0
        SLM_ls_diff_payload[0]    = 0
    end
end

--------------------------------------------------------------------------------
-- Flight Times (UTC)
--------------------------------------------------------------------------------
function timestamp_to_utc_hhmmz(epoch)
    if epoch == 0 then return "--:--Z" end
    return os.date("!%H:%MZ", epoch)
end

function current_zulu_hhmm()
    return string.format("%02d:%02dZ", zulu_hours, zulu_minutes)
end


function detect_block_times()
    if beacon_prev == 0 and beacon == 1 and block_off_time == "--:--Z" then
        block_off_time = current_zulu_hhmm()
    elseif beacon_prev == 1 and beacon == 0 and block_on_time == "--:--Z" and takeoff_time ~= "--:--Z" then
        block_on_time = current_zulu_hhmm()
    end
    beacon_prev = beacon
end


function detect_takeoff_and_landing()
     if onground_prev == 1 and onground == 0 and takeoff_time == "--:--Z" then
        takeoff_time = current_zulu_hhmm()
        passed_1000ft = false
    end

    if not passed_1000ft and altitude_ft > 1000 then
        passed_1000ft = true
    end

    if onground_prev == 0 and onground == 1 and landing_time == "--:--Z" then
        if passed_1000ft then
            landing_time = current_zulu_hhmm()
        end
    end

    onground_prev = onground
end

--------------------------------------------------------------------------------
-- PRESET VALUES auto-filled from apply_*_timings()
--------------------------------------------------------------------------------
local preset_values = {}

local function capture_preset(func)
    local snapshot = {
        pax_time_per_passenger = pax_time_per_passenger,
        pax_time_variation = pax_time_variation,
        disembark_pax_time_per_passenger = disembark_pax_time_per_passenger,
        disembark_pax_time_variation = disembark_pax_time_variation,
        cargo_time_per_kg_min = cargo_time_per_kg_min,
        cargo_time_per_kg_max = cargo_time_per_kg_max,
        disembark_cargo_time_per_kg_min = disembark_cargo_time_per_kg_min,
        disembark_cargo_time_per_kg_max = disembark_cargo_time_per_kg_max,
        fuel_time_per_kg = fuel_time_per_kg
    }

    func()

    local result = {
        pax_time_per_passenger = pax_time_per_passenger,
        pax_time_variation = pax_time_variation,
        disembark_pax_time_per_passenger = disembark_pax_time_per_passenger,
        disembark_pax_time_variation = disembark_pax_time_variation,
        cargo_time_per_kg_min = cargo_time_per_kg_min,
        cargo_time_per_kg_max = cargo_time_per_kg_max,
        disembark_cargo_time_per_kg_min = disembark_cargo_time_per_kg_min,
        disembark_cargo_time_per_kg_max = disembark_cargo_time_per_kg_max,
        fuel_time_per_kg = fuel_time_per_kg
    }


    pax_time_per_passenger = snapshot.pax_time_per_passenger
    pax_time_variation = snapshot.pax_time_variation
    disembark_pax_time_per_passenger = snapshot.disembark_pax_time_per_passenger
    disembark_pax_time_variation = snapshot.disembark_pax_time_variation
    cargo_time_per_kg_min = snapshot.cargo_time_per_kg_min
    cargo_time_per_kg_max = snapshot.cargo_time_per_kg_max
    disembark_cargo_time_per_kg_min = snapshot.disembark_cargo_time_per_kg_min
    disembark_cargo_time_per_kg_max = snapshot.disembark_cargo_time_per_kg_max
    fuel_time_per_kg = snapshot.fuel_time_per_kg

    return result
end

preset_values.realistic = capture_preset(apply_realistic_timings)
preset_values.fast      = capture_preset(apply_fast_timings)
preset_values.veryfast  = capture_preset(apply_veryfast_timings)

--------------------------------------------------------------------------------
-- WINDOW MANAGEMENT
--------------------------------------------------------------------------------
function create_embark_window()
    if embark_wnd == nil then
        embark_wnd = float_wnd_create(425, 775, 1, true)
        float_wnd_set_title(embark_wnd, "Simload Manager 2.1.2")
        float_wnd_set_imgui_builder(embark_wnd, "build_embark_window")
        float_wnd_set_onclose(embark_wnd, "on_close_embark_window")
        logMsg("[SLM] Embark window created.")
    end
end

function on_close_embark_window(wnd)
    close_embark_window()
end

function close_embark_window()
    if embark_wnd ~= nil then
        float_wnd_destroy(embark_wnd)
        embark_wnd = nil
        logMsg("[SLM] Embark window closed by script.")
    end
end

function toggle_embark_window()
    if embark_wnd == nil then
        create_embark_window()
    else
        close_embark_window()
    end
end

local slm_open_loadsheet_flag = false

local function ensure_loadsheet_loaded()
    if not _G["open_loadsheet_window"] then
        dofile(SCRIPT_DIRECTORY .. "SimLoadManager_loadsheet.lua")
    end
end

function slm_deferred_open_loadsheet()
    if slm_open_loadsheet_flag then
        slm_open_loadsheet_flag = false
        ensure_loadsheet_loaded()
        if _G["open_loadsheet_window"] then
            open_loadsheet_window()
            logMsg("[SLM] Loadsheet window opened.")
        else
            logMsg("[SLM] open_loadsheet_window() not found after load.")
        end
    end
end

do_every_frame("slm_deferred_open_loadsheet()")


--------------------------------------------------------------------------------
-- OPEN URL
--------------------------------------------------------------------------------
function open_simchecklist()
    local url = "https://Simchecklist.eu"
    if package.config:sub(1, 1) == "\\" then
        os.execute("start " .. url)
    else
        os.execute("open " .. url)
    end
end

function Ko_fi()
    local url = "https://ko-fi.com/simchecklist"
    if package.config:sub(1, 1) == "\\" then
        os.execute("start " .. url)
    else
        os.execute("open " .. url)
    end
end

--------------------------------------------------------------------------------
-- IMGUi
--------------------------------------------------------------------------------
function build_embark_window(wnd, x, y)
    if imgui.CollapsingHeader("Settings") then
        imgui.Spacing()

        -- SimBrief ID
        local changed, new_id = imgui.InputText("SimBrief ID", simbrief_id or "", 100)
        if changed then
            simbrief_id = new_id
            save_user_settings()
        end

        imgui.Spacing()
        imgui.TextUnformatted("Cargo Unit System:")

        if simbrief_data_loaded or embark_started or disembark_started then
            imgui.BeginDisabled()
        end

        local changed_unit_kg = imgui.RadioButton("Kilograms (kg)", unit_system == "kg")
        imgui.SameLine()
        local changed_unit_lbs = imgui.RadioButton("Pounds (lbs)", unit_system == "lbs")

       if simbrief_data_loaded or embark_started or disembark_started then
            imgui.EndDisabled()
        end

        if changed_unit_kg then
            unit_system = "kg"
            save_user_settings()
        elseif changed_unit_lbs then
            unit_system = "lbs"
            save_user_settings()
        end

        imgui.NewLine()
	if embark_started or disembark_started then imgui.BeginDisabled() end
		local changed_fuel_first, new_fuel_first = imgui.Checkbox("Fuel First", fuel_first)
		if changed_fuel_first then
			fuel_first = new_fuel_first
			save_user_settings()
		end
	if embark_started or disembark_started then imgui.EndDisabled() end	
		imgui.NewLine()
		
       imgui.TextUnformatted("Timing preset:")

    if embark_started or disembark_started then
        imgui.BeginDisabled()
    end

    local selected_realistic = timing_preset == "realistic"
    local selected_fast = timing_preset == "fast"
	local selected_veryfast  = timing_preset == "veryfast"

    if imgui.RadioButton("Realistic", selected_realistic) then
    apply_realistic_timings()
    save_user_settings()
	end
	imgui.SameLine()
	if imgui.RadioButton("Fast", selected_fast) then
		apply_fast_timings()
		save_user_settings()
	end
	imgui.SameLine()
	if imgui.RadioButton("Very Fast", selected_veryfast) then
		apply_veryfast_timings()
		save_user_settings()
	end
	imgui.SameLine()
if imgui.RadioButton("Custom", timing_preset == "custom") then
    timing_preset = "custom"
    apply_custom_timings()
    save_user_settings()
end

if timing_preset == "custom" then
    imgui.Separator()
    imgui.TextUnformatted("Custom timing parameters:")
    imgui.PushItemWidth(120)

    local changed = false
    local c, v

    -- Pax load
    c, v = imgui.InputFloat("Pax load time (s/pax)", custom_pax_time_per_passenger, 0, 0, "%0.2f")
    if c then custom_pax_time_per_passenger = v changed = true end
    imgui.SameLine()
    imgui.TextUnformatted(string.format(
    "-> Realistic: %.1f | Fast: %.1f | Very Fast: %.1f",
    preset_values.realistic.pax_time_per_passenger,
    preset_values.fast.pax_time_per_passenger,
    preset_values.veryfast.pax_time_per_passenger
	))

    -- Pax variation
    c, v = imgui.InputFloat("Pax time variation (s)", custom_pax_time_variation, 0, 0, "%0.2f")
    if c then custom_pax_time_variation = v changed = true end
    imgui.SameLine()
	imgui.TextUnformatted(string.format(
		"-> Realistic: ±%.1f | Fast: ±%.1f | Very Fast: ±%.1f",
		preset_values.realistic.pax_time_variation,
		preset_values.fast.pax_time_variation,
		preset_values.veryfast.pax_time_variation
	))

    -- Disembark pax
    c, v = imgui.InputFloat("Disembark pax time (s/pax)", custom_disembark_pax_time_per_passenger, 0, 0, "%0.2f")
    if c then custom_disembark_pax_time_per_passenger = v changed = true end
    imgui.SameLine()
	imgui.TextUnformatted(string.format(
		"-> Realistic: %.1f | Fast: %.1f | Very Fast: %.1f",
		preset_values.realistic.disembark_pax_time_per_passenger,
		preset_values.fast.disembark_pax_time_per_passenger,
		preset_values.veryfast.disembark_pax_time_per_passenger
	))

    -- Disembark variation
    c, v = imgui.InputFloat("Disembark pax var. (s)", custom_disembark_pax_time_variation, 0, 0, "%0.2f")
    if c then custom_disembark_pax_time_variation = v changed = true end
    imgui.SameLine()
	imgui.TextUnformatted(string.format(
		"-> Realistic: ±%.1f | Fast: ±%.1f | Very Fast: ±%.1f",
		preset_values.realistic.disembark_pax_time_variation,
		preset_values.fast.disembark_pax_time_variation,
		preset_values.veryfast.disembark_pax_time_variation
	))

    -- Cargo load min
    c, v = imgui.InputFloat("Cargo load min (s/kg)", custom_cargo_time_per_kg_min, 0, 0, "%0.3f")
    if c then custom_cargo_time_per_kg_min = v changed = true end
    imgui.SameLine()
	imgui.TextUnformatted(string.format(
		"-> Realistic: %.3f | Fast: %.3f | Very Fast: %.3f",
		preset_values.realistic.cargo_time_per_kg_min,
		preset_values.fast.cargo_time_per_kg_min,
		preset_values.veryfast.cargo_time_per_kg_min
	))

    -- Cargo load max
    c, v = imgui.InputFloat("Cargo load max (s/kg)", custom_cargo_time_per_kg_max, 0, 0, "%0.3f")
    if c then custom_cargo_time_per_kg_max = v changed = true end
    imgui.SameLine()
	imgui.TextUnformatted(string.format(
		"-> Realistic: %.3f | Fast: %.3f | Very Fast: %.3f",
		preset_values.realistic.cargo_time_per_kg_max,
		preset_values.fast.cargo_time_per_kg_max,
		preset_values.veryfast.cargo_time_per_kg_max
	))

    -- Cargo unload min
    c, v = imgui.InputFloat("Cargo unload min (s/kg)", custom_disembark_cargo_time_per_kg_min, 0, 0, "%0.3f")
    if c then custom_disembark_cargo_time_per_kg_min = v changed = true end
    imgui.SameLine()
	imgui.TextUnformatted(string.format(
		"-> Realistic: %.3f | Fast: %.3f | Very Fast: %.3f",
		preset_values.realistic.disembark_cargo_time_per_kg_min,
		preset_values.fast.disembark_cargo_time_per_kg_min,
		preset_values.veryfast.disembark_cargo_time_per_kg_min
	))

    -- Cargo unload max
    c, v = imgui.InputFloat("Cargo unload max (s/kg)", custom_disembark_cargo_time_per_kg_max, 0, 0, "%0.3f")
    if c then custom_disembark_cargo_time_per_kg_max = v changed = true end
    imgui.SameLine()
	imgui.TextUnformatted(string.format(
		"-> Realistic: %.3f | Fast: %.3f | Very Fast: %.3f",
		preset_values.realistic.disembark_cargo_time_per_kg_max,
		preset_values.fast.disembark_cargo_time_per_kg_max,
		preset_values.veryfast.disembark_cargo_time_per_kg_max
	))

    -- Fuel
    c, v = imgui.InputFloat("Fuel time per kg", custom_fuel_time_per_kg, 0, 0, "%0.3f")
    if c then custom_fuel_time_per_kg = v changed = true end
    imgui.SameLine()
	imgui.TextUnformatted(string.format(
		"-> Realistic: %.3f | Fast: %.3f | Very Fast: %.3f",
		preset_values.realistic.fuel_time_per_kg,
		preset_values.fast.fuel_time_per_kg,
		preset_values.veryfast.fuel_time_per_kg
	))

    imgui.PopItemWidth()

    if changed then
        apply_custom_timings()
        save_user_settings()
    end
end

    if embark_started or disembark_started then
        imgui.EndDisabled()
    end
	
	imgui.NewLine()
	
	local changed_mute, new_mute = imgui.Checkbox("Mute sound", is_muted)
    if changed_mute then
        is_muted = new_mute
		update_loop_volumes()
        if is_muted then
            set_all_sounds_gain(0.0001)
        else
            set_all_sounds_gain(Volume)
        end
    end
end	

	if not slm_update_checked or slm_update_status == "Unable to verify update at this time" then
		imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFAAAAAA) -- grey
	elseif slm_update_available then
		imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00A5FF) -- orange
	else
		imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00) -- green
	end

	imgui.TextUnformatted(slm_update_status)
	imgui.PopStyleColor()


   
    imgui.Separator()
	imgui.NewLine()
	if embark_started or disembark_started then
		imgui.BeginDisabled()
	end

	if imgui.Button("Load Simbrief data") then
		fetch_simbrief_data(simbrief_id)
	end

	if embark_started or disembark_started then
		imgui.EndDisabled()
	end

	if embark_started or disembark_started then imgui.BeginDisabled() end
	imgui.PushItemWidth(130)

    _, temp_manual_cargo = imgui.InputInt("Cargo (" .. unit_system .. ")", temp_manual_cargo)
    _, temp_manual_passengers = imgui.InputInt("Passengers", temp_manual_passengers)
	_, temp_manual_fuel = imgui.InputInt("Fuel (" .. unit_system .. ")", temp_manual_fuel or 0)
	if embark_started or disembark_started then imgui.EndDisabled() end
	
	imgui.NewLine()

	local slm_actions_running = (embark_started or disembark_started)

	if slm_actions_running then imgui.BeginDisabled() end

	if imgui.Button("Start Loading") then
		start_embarkation()
	end
	imgui.SameLine()
	if imgui.Button("Start Unloading") then
		start_disembarkation()
	end
	if slm_actions_running then imgui.EndDisabled() end
	
	imgui.SameLine()
	if imgui.Button("Reset") then
		reset_loads()
	end

    imgui.Spacing()
	if slm_actions_running then imgui.BeginDisabled() end
	
    imgui.TextUnformatted("Select your location :")

    if imgui.RadioButton("Remote Stand", selected_location_group == "remote") then
        slm_set_location_remote()
    end
    imgui.SameLine()
    if imgui.RadioButton("Gate W/O Jetway", selected_location_group == "terminal") then
        slm_set_location_terminal()
    end
    imgui.SameLine()
    if imgui.RadioButton("Gate Jetway", selected_location_group == "jetway") then
        slm_set_location_jetway()
    end
	
	if slm_actions_running then imgui.EndDisabled() end
	
		imgui.Spacing()
	local slm_actions_running = (embark_started or disembark_started)

	if slm_actions_running then imgui.BeginDisabled() end

	local chg_own, new_own = imgui.Checkbox("Do not call stairs", aircraft_has_own_stairs)
	if chg_own then
		aircraft_has_own_stairs = new_own
	end

	if slm_actions_running then imgui.EndDisabled() end

	imgui.Spacing()
    imgui.Separator()
	imgui.NewLine()

    local cargo_current = 0
    if embark_started then
        cargo_current = cargo_loaded
    elseif disembark_started then
        cargo_current = cargo_total - cargo_unloaded
    elseif embark_done and not disembark_started then
        cargo_current = cargo_total
    elseif disembark_done then
        cargo_current = 0
    else
        cargo_current = 0
    end

    cargo_current = math.max(0, math.min(cargo_current, cargo_total))
    local fraction_cargo = (cargo_total > 0) and (cargo_current / cargo_total) or 0

    imgui.TextUnformatted("Cargo:")
    imgui.ProgressBar(fraction_cargo, 200, 20, "")
    imgui.SameLine()
    imgui.TextUnformatted(string.format("%.0f / %.0f %s", cargo_current, cargo_total, unit_system))

	local display_text = ""
		if (embark_started or disembark_started or embark_done or disembark_done) then
		if cargo_total == 0 then
			imgui.TextUnformatted("No Cargo")

		elseif disembark_done or (cargo_current >= cargo_total and cargo_total > 0) then
			imgui.TextUnformatted("Estimated: ")
			imgui.SameLine(nil, 0)
			imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00)
			imgui.TextUnformatted("Completed")
			imgui.PopStyleColor()

		else
		if embark_started and cargo_loaded == 0 then
			imgui.TextUnformatted("Estimated: Waiting")

		elseif estimated_time_cargo and estimated_time_cargo > 0 then
			if estimated_time_cargo < 60 then
				imgui.TextUnformatted("Estimated: < 1 minute")
			else
				local cargo_minutes = math.ceil(estimated_time_cargo / 60)
				imgui.TextUnformatted(string.format("Estimated: %d minute%s", cargo_minutes, cargo_minutes > 1 and "s" or ""))
			end
		else
			imgui.TextUnformatted("Estimated: --")
		end
	end
	else
		imgui.TextUnformatted("Estimated: Not started")
	end
	
    imgui.TextUnformatted(display_text)
    local pax_current = 0
    if embark_started then
        pax_current = passengers_loaded
    elseif disembark_started then
        pax_current = passengers_total - passengers_unloaded
    elseif embark_done and not disembark_done then
        pax_current = passengers_total
    elseif disembark_done then
        pax_current = 0
    else
        pax_current = 0
    end

	pax_current = math.max(0, math.min(pax_current, passengers_total))
	local fraction_pax = (passengers_total > 0) and (pax_current / passengers_total) or 0

	imgui.TextUnformatted("Passengers:")
	imgui.ProgressBar(fraction_pax, 200, 20, "")
	imgui.SameLine()
	imgui.TextUnformatted(string.format("%d / %d PAX", pax_current, passengers_total))

	if (embark_started or disembark_started or embark_done or disembark_done) then
    if passengers_total == 0 then
        imgui.TextUnformatted("No Pax")

    elseif (embark_done and not disembark_started) or disembark_done then
        imgui.TextUnformatted("Estimated: ")
        imgui.SameLine(nil, 0)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00)
        imgui.TextUnformatted("Completed")
        imgui.PopStyleColor()

    elseif disembark_started and (passengers_unloaded < passengers_total) then
        if estimated_time_pax and estimated_time_pax > 0 then
            local pax_minutes = math.ceil(estimated_time_pax / 60)
            imgui.TextUnformatted(string.format("Estimated: %d minutes", pax_minutes))
        else
            imgui.TextUnformatted("Estimated: --")
        end

    elseif embark_started and not pax_load_started then
        if bus_triggered and pax_trigger_time then
            local t = pax_trigger_time - os.clock()

            imgui.TextUnformatted("Estimated: ")
            imgui.SameLine(nil, 0)

            if t > 60 then
                imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFA500)
                imgui.TextUnformatted("Boarding soon")
                imgui.PopStyleColor()
            else
                imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFA500)
                imgui.TextUnformatted("Boarding any moment")
                imgui.PopStyleColor()
            end
        else
            imgui.TextUnformatted("Estimated: ")
            imgui.SameLine(nil, 0)
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFFFFF)
            imgui.TextUnformatted("Boarding later")
            imgui.PopStyleColor()
        end

    elseif pax_current >= passengers_total then
        imgui.TextUnformatted("Estimated: ")
        imgui.SameLine(nil, 0)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00)
        imgui.TextUnformatted("Completed")
        imgui.PopStyleColor()

    else
        if estimated_time_pax and passengers_loaded < passengers_total then
            if estimated_time_pax < 60 then
                imgui.TextUnformatted("Estimated: < 1 minute")
            else
                local pax_minutes = math.ceil(estimated_time_pax / 60)
                imgui.TextUnformatted(string.format("Estimated: %d minutes", pax_minutes))
            end
        else
            imgui.TextUnformatted("Estimated: --")
        end
    end
else
    imgui.TextUnformatted("Estimated: Not started")
end

	imgui.NewLine()
	
	imgui.TextUnformatted("Fuel:")
	local fuel_fraction = (fuel_total > 0) and (fuel_loaded / fuel_total) or 0
	imgui.ProgressBar(fuel_fraction, 200, 20, "")
	imgui.SameLine()
	imgui.TextUnformatted(string.format("%.0f / %.0f %s", fuel_loaded, fuel_total, unit_system))
	
	if (embark_started or embark_done) then
		if fuel_done then
			imgui.TextUnformatted("Estimated: ")
			imgui.SameLine(nil, 0)
			imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00)
			imgui.TextUnformatted("Completed")
			imgui.PopStyleColor()

		elseif fuel_loading then
			if fuel_ready_time and os.clock() < fuel_ready_time then
				imgui.TextUnformatted("Waiting for fuel truck...")
			elseif estimated_time_fuel then
				local fuel_remaining = fuel_total - fuel_loaded
				local time_remaining = fuel_remaining * fuel_time_per_unit

				if time_remaining < 60 then
					imgui.TextUnformatted("Estimated: < 1 minute")
				else
					local fuel_minutes = math.ceil(time_remaining / 60)
					imgui.TextUnformatted(string.format("Estimated: %d minute%s", fuel_minutes, fuel_minutes > 1 and "s" or ""))
				end
			else
				imgui.TextUnformatted("Estimated: --")
			end

		else
			imgui.TextUnformatted("Estimated: Waiting")
		end
	else
		imgui.TextUnformatted("Estimated: Not started")
	end


	imgui.NewLine()

	if loadsheet_ready then
		if imgui.Button("View Loadsheet") then
			slm_open_loadsheet_flag = true
		end
	else
		imgui.BeginDisabled()
		imgui.Button("View Loadsheet")
		imgui.EndDisabled()
	end

	
	imgui.Separator()
	imgui.NewLine()
	imgui.TextUnformatted("Current Zulu: " .. current_zulu_hhmm())
	imgui.TextUnformatted("Flight Times (UTC) - Imported via Simbrief ")
	imgui.NewLine()

	imgui.TextUnformatted("              | Sched. | Act.")

	local function colored_time_line(label, sched_timestamp, actual_time)
    local sched_str = timestamp_to_utc_hhmmz(sched_timestamp) or "--:--Z"
    local act_str = actual_time or "--:--Z"

    if act_str == "--:--Z" then
        imgui.TextUnformatted(string.format("%-15s | %s | %s", label, sched_str, act_str))
        return
    end

    local sh, sm = string.match(sched_str, "(%d+):(%d+)")
    local ah, am = string.match(act_str, "(%d+):(%d+)")
    sh, sm, ah, am = tonumber(sh) or 0, tonumber(sm) or 0, tonumber(ah) or 0, tonumber(am) or 0

    local sched_total = sh * 60 + sm
    local act_total   = ah * 60 + am
    local diff = math.abs(act_total - sched_total)

    local color = 0xFF00FF00
    if diff > 10 then
        color = 0xFF0000FF
    elseif diff > 3 then
        color = 0xFFFFA500
    end

    imgui.PushStyleColor(imgui.constant.Col.Text, color)
    imgui.TextUnformatted(string.format("%-15s | %s | %s", label, sched_str, act_str))
    imgui.PopStyleColor()
	end

	colored_time_line("Block-Off (OUT)", sched_out, block_off_time)
	colored_time_line("Takeoff (OFF)",   sched_off, takeoff_time)
	colored_time_line("Landing (ON)",    sched_on,  landing_time)
	colored_time_line("Block-In (IN)",   sched_in,  block_on_time)

    imgui.NewLine()
    imgui.Separator()

	if imgui.Button("Visit Simchecklist.eu") then
		open_simchecklist()
	end
	
	imgui.SameLine()
	
	if imgui.Button("Buy me a Ko-Fi") then
		Ko_fi()
	end
	
	imgui.SameLine()
	
	if imgui.Button("Toggle SGES") then
    simload_toggle_SGES()
	end
end

	--------------------------------------------------------------------------------
	-- LOCATION SWITCH COMMANDS
	--------------------------------------------------------------------------------
	local function set_location_group(loc)
		-- Block switching locations while loading/unloading is running
		if embark_started or disembark_started then
			return
		end

		if loc ~= "remote" and loc ~= "terminal" and loc ~= "jetway" then
			return
		end

		selected_location_group = loc
	end


	function slm_set_location_remote()
		set_location_group("remote")
	end

	function slm_set_location_terminal()
		set_location_group("terminal")
	end

	function slm_set_location_jetway()
		set_location_group("jetway")
	end
	
	function slm_toggle_own_stairs()
    if embark_started or disembark_started then
        return
    end
    aircraft_has_own_stairs = not aircraft_has_own_stairs
	end


--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------
add_macro("Open SimLoad Manager",
          "if embark_wnd == nil then create_embark_window() else close_embark_window() end")
do_every_frame("manage_embark()")
do_every_frame("manage_disembark()")
do_every_frame("update_remaining_time()")


create_command("FlyWithLua/SimloadManager/SimloadManagerToggle",
               "Toggle Simload Manager window",
               "toggle_embark_window()",
               "",
               "")
			   
create_command("FlyWithLua/SimloadManager/StartLoading",
               "Start embarkation",
               "start_embarkation()",
               "",
               "")

create_command("FlyWithLua/SimloadManager/StartUnloading",
               "Start disembarkation",
               "start_disembarkation()",
               "",
               "")

create_command("FlyWithLua/SimloadManager/Reset",
               "Reset SimLoad Manager",
               "reset_loads()",
               "",
               "")
			   
trigger_simbrief_import = false

create_command("FlyWithLua/SimloadManager/ImportSimbrief",
               "Import SimBrief data",
               "trigger_simbrief_import = true",
               "",
               "")
			   
create_command("FlyWithLua/SimloadManager/LocationRemote",
               "Set location: Remote stand",
               "slm_set_location_remote()",
               "",
               "")

create_command("FlyWithLua/SimloadManager/LocationGateNoJetway",
               "Set location: Gate without jetway",
               "slm_set_location_terminal()",
               "",
               "")

create_command("FlyWithLua/SimloadManager/LocationJetway",
               "Set location: Gate with jetway",
               "slm_set_location_jetway()",
               "",
               "")
			   
create_command(
    "FlyWithLua/SimloadManager/ToggleOwnStairs",
    "Toggle: Aircraft has own stairs (do not call external stairs)",
    "slm_toggle_own_stairs()",
    "",
    ""
)
			   


function check_simbrief_trigger()
    if trigger_simbrief_import then
        trigger_simbrief_import = false
        save_user_settings()
        fetch_simbrief_data(simbrief_id)
        logMsg("[SimLoad Manager] SimBrief data imported")
    end
end

do_every_frame("check_simbrief_trigger()")


toggle_SGES_flag = false

function simload_toggle_SGES()
    toggle_SGES_flag = true
end

function flightloop_check_SGES_toggle()
    if toggle_SGES_flag then
        toggle_SGES_flag = false
        command_once("Simple_Ground_Equipment_and_Services/Window/Toggle")
    end
end

local slm_update_init_done = false
function slm_update_init_once()
    if slm_update_init_done then return end
    slm_update_init_done = true
    slm_check_update()
end

do_every_frame("flightloop_check_SGES_toggle()")
do_every_frame("update_loop_volumes()")
do_every_frame("detect_block_times()")
do_every_frame("detect_takeoff_and_landing()")
do_every_frame("slm_update_init_once()")
do_every_frame("update_slm_datarefs()")



load_user_settings()
