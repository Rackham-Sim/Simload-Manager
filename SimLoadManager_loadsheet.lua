-- ==========================================================
-- SimLoadManager Loadsheet - Display Module (v1.1)
-- ==========================================================

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("[SLM LOADSHEET] ImGui not supported by your FlyWithLua version.")
    return
end

local loadsheet_wnd = nil
------------------------------------------------------------
-- # Window management
------------------------------------------------------------

local LOADSHEET_POS_X = 575
local LOADSHEET_POS_Y = 250

function open_loadsheet_window()
    if loadsheet_wnd == nil then
        loadsheet_wnd = float_wnd_create(540, 750, 1, true)
        float_wnd_set_title(loadsheet_wnd, "SLM Loadsheet")
        float_wnd_set_imgui_builder(loadsheet_wnd, "draw_loadsheet_window")
        float_wnd_set_onclose(loadsheet_wnd, "on_close_loadsheet_window")

        -- Fixed position (no dependency on embark_wnd)
        float_wnd_set_position(loadsheet_wnd, LOADSHEET_POS_X, LOADSHEET_POS_Y)
    end
end

function close_loadsheet_window()
    if loadsheet_wnd ~= nil then
        float_wnd_destroy(loadsheet_wnd)
        loadsheet_wnd = nil
        logMsg("[SLM LOADSHEET] Window closed by script.")
    end
end

function on_close_loadsheet_window(wnd)
    loadsheet_wnd = nil
    logMsg("[SLM LOADSHEET] Window closed by user.")
end

--------------------------------------------------------
-- RANDOM LOAD CONTROLLER SELECTION (KO-FI SUPPORTERS)
--------------------------------------------------------

local load_controllers = {
    "Xavier24",
    "james.C",
    "Furax84",
    "Dudley.B",
    "Jugac64",
	"Mark",
	"Othmar",
	"Pea",
	"Sydney.M"
}

math.randomseed(os.time())
local selected_controller = load_controllers[math.random(1, #load_controllers)]

------------------------------------------------------------
-- # Main UI
------------------------------------------------------------
function draw_loadsheet_window(wnd, x, y)
    if not loadsheet_ready or SLM_Loadsheet_Data == nil then
        imgui.TextUnformatted("Loadsheet not ready.")
        imgui.Separator()
        imgui.TextUnformatted("Please load SimBrief data first from the main SLM window.")
        return
    end

    local d = SLM_Loadsheet_Data
    local unit = (unit_system == "lbs") and "lbs" or "kg"

    local c_title = 0xFFFFA500
    local c_text  = 0xFFFFFFFF
	
	local function diff_color(pct)
	if math.abs(pct) <= 5 then return 0xFF00FF00 end
	return 0xFF00A5FF
    end


    --------------------------------------------------------
    -- Header
    --------------------------------------------------------
    imgui.PushStyleColor(imgui.constant.Col.Text, c_title)
    imgui.TextUnformatted("FLIGHT INFORMATION")
    imgui.PopStyleColor()
    imgui.PushStyleColor(imgui.constant.Col.Text, c_text)
    imgui.TextUnformatted(string.format("%s%s   %s", d.airline or "", d.fltnum or "", d.date or ""))
    imgui.TextUnformatted(string.format("Aircraft: %s (%s)  Reg: %s", d.aircraft_name or "?", d.aircraft_icao or "?", d.reg or "?"))
    imgui.TextUnformatted(string.format("Route: %s -> %s (ALT: %s)", d.orig or "?", d.dest or "?", d.altn or "?"))
    imgui.TextUnformatted(string.format("Dispatcher: %s   Captain: %s", d.dispatcher or "?", d.captain or "?"))
    imgui.PopStyleColor()
    imgui.NewLine()
    imgui.Separator()

    --------------------------------------------------------
    -- Passengers
    --------------------------------------------------------
    local pax_planned = tonumber(d.pax_total) or 0
    local pax_actual  = tonumber(_G["SLM_real_pax"]) or pax_planned

    local pax_w = tonumber(d.pax_weight) or 0
    local body_planned = pax_planned * pax_w
    local body_actual  = pax_actual * pax_w

    local pax_diff = pax_actual - pax_planned
    local pax_pct  = (pax_planned > 0) and ((pax_diff / pax_planned) * 100) or 0

    local body_diff = body_actual - body_planned
    local body_pct  = (body_planned > 0) and ((body_diff / body_planned) * 100) or 0

    local function diff_color(pct)
        if math.abs(pct) <= 5 then return 0xFF00FF00 end
        return 0xFF00A5FF
    end

    local pax_c  = diff_color(pax_pct)
    local body_c = diff_color(body_pct)

    imgui.PushStyleColor(imgui.constant.Col.Text, c_title)
    imgui.TextUnformatted("PASSENGERS")
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.constant.Col.Text, c_text)
    imgui.BeginTable("SLM_PAX_TABLE", 4)
    imgui.TableNextRow()
    imgui.TableSetColumnIndex(0); imgui.TextUnformatted("")
    imgui.TableSetColumnIndex(1); imgui.TextUnformatted("Planned")
    imgui.TableSetColumnIndex(2); imgui.TextUnformatted("Actual")
    imgui.TableSetColumnIndex(3); imgui.TextUnformatted("Diff")

    imgui.TableNextRow()
    imgui.TableSetColumnIndex(0); imgui.TextUnformatted("PAX")
    imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%d", pax_planned))
    imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%d", pax_actual))
    imgui.TableSetColumnIndex(3)
    imgui.PushStyleColor(imgui.constant.Col.Text, pax_c)
    imgui.TextUnformatted(string.format("%+d (%.1f%%)", pax_diff, pax_pct))
    imgui.PopStyleColor()

    imgui.TableNextRow()
    imgui.TableSetColumnIndex(0); imgui.TextUnformatted("Body")
    imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", body_planned, unit))
    imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", body_actual, unit))
    imgui.TableSetColumnIndex(3)
    imgui.PushStyleColor(imgui.constant.Col.Text, body_c)
    imgui.TextUnformatted(string.format("%+.0f %s (%.1f%%)", body_diff, unit, body_pct))
    imgui.PopStyleColor()

    imgui.EndTable()
    imgui.PopStyleColor()

    imgui.NewLine()
    imgui.Separator()
	
	--------------------------------------------------------
	-- CARGO
	--------------------------------------------------------

	local function round_kg(x)
		return math.floor((x or 0) + 0.5)
	end

	-- Planned sources (SimBrief)
	local pax_planned       = tonumber(d.pax_total) or 0
	local bag_count_planned = tonumber(d.bag_count_sb) or 0
	local bag_w             = tonumber(d.bag_weight) or 0

	local cargo_total_planned = tonumber(d.cargo_total) or 0          -- SB <cargo>
	local freight_planned     = tonumber(d.freight_added) or 0        -- SB <freight_added>

	-- Planned baggage = BAG_COUNT(SB) * bag_weight(SB), rounded on result
	local bag_planned = round_kg(bag_count_planned * bag_w)

	-- Actual sources (SLM)
	local pax_actual         = tonumber(_G["SLM_real_pax"]) or pax_planned
	local cargo_total_actual = tonumber(_G["SLM_real_cargo"]) or cargo_total_planned

	-- Actual bag count (scaled from planned, because SLM has no bag_count actual)
	local bag_count_actual = bag_count_planned
	if pax_planned > 0 then
		bag_count_actual = bag_count_planned * (pax_actual / pax_planned)
	end

	-- Actual baggage = BAG_COUNT(actual est.) * bag_weight(SB), rounded on result
	local bag_actual = round_kg(bag_count_actual * bag_w)

	-- Actual freight from difference (SLM total - computed bags)
	local freight_actual = cargo_total_actual - bag_actual
	if freight_actual < 0 then freight_actual = 0 end

	-- Totals: planned from SB, actual from SLM (never recalculated)
	local total_planned = cargo_total_planned
	local total_actual  = cargo_total_actual

	-- Diffs & %
	local bag_diff = bag_actual - bag_planned
	local frt_diff = freight_actual - freight_planned
	local tot_diff = total_actual - total_planned

	local bag_pct = (bag_planned > 0) and ((bag_diff / bag_planned) * 100) or 0
	local frt_pct = (freight_planned > 0) and ((frt_diff / freight_planned) * 100) or 0
	local tot_pct = (total_planned > 0) and ((tot_diff / total_planned) * 100) or 0

	imgui.PushStyleColor(imgui.constant.Col.Text, c_title)
	imgui.TextUnformatted("CARGO")
	imgui.PopStyleColor()

	imgui.BeginTable("SLM_CARGO_TABLE", 4)
	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted("Planned")
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted("Actual")
	imgui.TableSetColumnIndex(3); imgui.TextUnformatted("Diff")

	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("Baggage")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", bag_planned, unit))
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", bag_actual, unit))
	imgui.TableSetColumnIndex(3)
	imgui.PushStyleColor(imgui.constant.Col.Text, diff_color(bag_pct))
	imgui.TextUnformatted(string.format("%+.0f %s (%.1f%%)", bag_diff, unit, bag_pct))
	imgui.PopStyleColor()

	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("Freight")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", freight_planned, unit))
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", freight_actual, unit))
	imgui.TableSetColumnIndex(3)
	imgui.PushStyleColor(imgui.constant.Col.Text, diff_color(frt_pct))
	imgui.TextUnformatted(string.format("%+.0f %s (%.1f%%)", frt_diff, unit, frt_pct))
	imgui.PopStyleColor()

	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("TOTAL")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", total_planned, unit))
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", total_actual, unit))
	imgui.TableSetColumnIndex(3)
	imgui.PushStyleColor(imgui.constant.Col.Text, diff_color(tot_pct))
	imgui.TextUnformatted(string.format("%+.0f %s (%.1f%%)", tot_diff, unit, tot_pct))
	imgui.PopStyleColor()

	imgui.EndTable()
	imgui.NewLine()
	imgui.Separator()


	--------------------------------------------------------
	-- SHARED VARS (Payload / Weights)
	--------------------------------------------------------
	local oew = tonumber(d.oew) or 0

	local payload_planned = tonumber(d.payload_planned) or 0
	local payload_actual  = tonumber(_G["SLM_real_payload"]) or 0  -- no fallback to planned

	local fuel_block_planned = tonumber(d.fuel_block) or 0
	local fuel_block_actual  = tonumber(_G["SLM_real_fuel_block"]) or 0  -- no fallback to planned

	local fuel_taxi = tonumber(d.fuel_taxi) or 0
	local fuel_land = tonumber(d.fuel_land) or 0

	local est_zfw = tonumber(d.est_zfw) or 0
	local est_tow = tonumber(d.est_tow) or 0
	local est_ldw = tonumber(d.est_ldw) or 0

	local max_zfw = tonumber(d.max_zfw) or 0
	local max_tow = tonumber(d.max_tow) or 0
	local max_ldw = tonumber(d.max_ldw) or 0

	--------------------------------------------------------
	-- PAYLOAD
	--------------------------------------------------------
	local payload_diff = payload_actual - payload_planned
	local payload_pct  = (payload_planned > 0) and ((payload_diff / payload_planned) * 100) or 0

	imgui.PushStyleColor(imgui.constant.Col.Text, c_title)
	imgui.TextUnformatted("PAYLOAD")
	imgui.PopStyleColor()

	imgui.BeginTable("SLM_PAYLOAD_TABLE", 4)
	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted("Planned")
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted("Actual")
	imgui.TableSetColumnIndex(3); imgui.TextUnformatted("Diff")

	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("Payload")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", payload_planned, unit))
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", payload_actual, unit))
	imgui.TableSetColumnIndex(3)
	imgui.PushStyleColor(imgui.constant.Col.Text, diff_color(payload_pct))
	imgui.TextUnformatted(string.format("%+.0f %s (%.1f%%)", payload_diff, unit, payload_pct))
	imgui.PopStyleColor()

	imgui.EndTable()
	imgui.NewLine()
	imgui.Separator()

	---------------------------------------------------------
	local function weight_color(actual, max)
		if not max or max <= 0 then return c_text end
		if actual > max then return 0xFF0000FF end
		if actual >= (max * 0.98) then return 0xFFFFA500 end
		return 0xFF00FF00
	end

	--------------------------------------------------------
	-- WEIGHTS
	--------------------------------------------------------
	-- Planned values: prefer SB-provided estimates, otherwise derive from planned components
	local zfw_planned = (est_zfw > 0) and est_zfw or (oew + payload_planned)
	local tow_planned = (est_tow > 0) and est_tow or (zfw_planned + (fuel_block_planned - fuel_taxi))
	local ldw_planned = (est_ldw > 0) and est_ldw or (zfw_planned + fuel_land)

	-- Actual values: always computed from actual components (no fallback to planned)
	local zfw_actual = oew + payload_actual
	local tow_actual = zfw_actual + (fuel_block_actual - fuel_taxi)
	local ldw_actual = zfw_actual + fuel_land

	local zfw_margin = max_zfw - zfw_actual
	local tow_margin = max_tow - tow_actual
	local ldw_margin = max_ldw - ldw_actual

	local zfw_c = weight_color(zfw_actual, max_zfw)
	local tow_c = weight_color(tow_actual, max_tow)
	local ldw_c = weight_color(ldw_actual, max_ldw)

	imgui.PushStyleColor(imgui.constant.Col.Text, c_title)
	imgui.TextUnformatted("WEIGHTS")
	imgui.PopStyleColor()

	imgui.PushStyleColor(imgui.constant.Col.Text, c_text)
	imgui.TextUnformatted(string.format("OEW: %.0f %s", oew, unit))
	imgui.PopStyleColor()

	imgui.BeginTable("SLM_WEIGHTS_TABLE", 4)
	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted("Planned")
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted("Actual")
	imgui.TableSetColumnIndex(3); imgui.TextUnformatted("MARGIN")

	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("ZFW")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", zfw_planned, unit))
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", zfw_actual, unit))
	imgui.TableSetColumnIndex(3)
	imgui.PushStyleColor(imgui.constant.Col.Text, zfw_c)
	imgui.TextUnformatted(string.format("%+.0f %s", zfw_margin, unit))
	imgui.PopStyleColor()

	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("TOW")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", tow_planned, unit))
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", tow_actual, unit))
	imgui.TableSetColumnIndex(3)
	imgui.PushStyleColor(imgui.constant.Col.Text, tow_c)
	imgui.TextUnformatted(string.format("%+.0f %s", tow_margin, unit))
	imgui.PopStyleColor()

	imgui.TableNextRow()
	imgui.TableSetColumnIndex(0); imgui.TextUnformatted("LDW")
	imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", ldw_planned, unit))
	imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", ldw_actual, unit))
	imgui.TableSetColumnIndex(3)
	imgui.PushStyleColor(imgui.constant.Col.Text, ldw_c)
	imgui.TextUnformatted(string.format("%+.0f %s", ldw_margin, unit))
	imgui.PopStyleColor()

	imgui.EndTable()

	imgui.NewLine()
	imgui.Separator()


    --------------------------------------------------------
    -- FUEL
    --------------------------------------------------------
    local fuel_planned = tonumber(d.fuel_block) or 0
    local fuel_actual  = tonumber(_G["SLM_real_fuel_block"]) or fuel_planned
    local fuel_diff    = fuel_actual - fuel_planned
    local fuel_pct     = (fuel_planned > 0) and ((fuel_diff / fuel_planned) * 100) or 0

    imgui.PushStyleColor(imgui.constant.Col.Text, c_title)
    imgui.TextUnformatted("FUEL")
    imgui.PopStyleColor()

    imgui.BeginTable("SLM_FUEL_TABLE", 4)
    imgui.TableNextRow()
    imgui.TableSetColumnIndex(0); imgui.TextUnformatted("")
    imgui.TableSetColumnIndex(1); imgui.TextUnformatted("Planned")
    imgui.TableSetColumnIndex(2); imgui.TextUnformatted("Actual")
    imgui.TableSetColumnIndex(3); imgui.TextUnformatted("Diff")

    imgui.TableNextRow()
    imgui.TableSetColumnIndex(0); imgui.TextUnformatted("Block")
    imgui.TableSetColumnIndex(1); imgui.TextUnformatted(string.format("%.0f %s", fuel_planned, unit))
    imgui.TableSetColumnIndex(2); imgui.TextUnformatted(string.format("%.0f %s", fuel_actual, unit))
    imgui.TableSetColumnIndex(3)
    imgui.PushStyleColor(imgui.constant.Col.Text, diff_color(fuel_pct))
    imgui.TextUnformatted(string.format("%+.0f %s (%.1f%%)", fuel_diff, unit, fuel_pct))
    imgui.PopStyleColor()

    imgui.EndTable()
    imgui.NewLine()
    imgui.Separator()

    --------------------------------------------------------
    -- Footer
    --------------------------------------------------------
    imgui.PushStyleColor(imgui.constant.Col.Text, c_title)
    imgui.TextUnformatted("SUMMARY")
    imgui.PopStyleColor()
    imgui.PushStyleColor(imgui.constant.Col.Text, c_text)
	imgui.TextUnformatted("Prepared by: ")
	imgui.SameLine(nil, 0)
	imgui.TextUnformatted(selected_controller)
	imgui.SameLine(nil, 4)
	imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFB0B0B0)
	imgui.TextUnformatted("(Ko-Fi Donator)")
	imgui.PopStyleColor()
    imgui.TextUnformatted(string.format("Approved by: %s", d.captain or "?"))
    imgui.NewLine()
    imgui.PushStyleColor(imgui.constant.Col.Text, c_title)
    imgui.TextUnformatted(string.format("The %s team wishes you a pleasant flight.", d.orig or "airport"))
    imgui.PopStyleColor()
    imgui.PopStyleColor()
	imgui.NewLine()
	imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFB0B0B0)
	imgui.TextUnformatted("					---- END OF LOADSHEET ----")
	imgui.PopStyleColor()
end