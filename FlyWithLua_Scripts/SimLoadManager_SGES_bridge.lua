-- ============================================================
-- SimLoad Manager -> SGES : pont FlyWithLua
-- ============================================================
-- A placer dans FlyWithLua/Scripts avec SGES (Simple Ground
-- Equipment and Services), uniquement si vous utilisez SLM 5.
--
-- SLM 5 publie ses demandes de vehicules en datarefs
-- (SimLoadManager/SGES/...). Ce script les relit et recree les
-- variables globales que SGES attend, exactement comme le faisait
-- SimLoadManager.lua sous FlyWithLua (show_Bus = true ; Bus_chg = true).
-- Sans SLM 5 actif, il ne fait rien.
-- ============================================================

local VEHICLES = {
    "Bus", "Pax", "FUEL", "Catering", "Cleaning", "Cones", "Chocks",
    "StairsXPJ", "StairsXPJ2", "BeltLoader", "RearBeltLoader", "Cart",
    "People1", "People2", "People3", "People4", "GPU",
}
-- Variables d'etat de SGES -> dataref publie par SLM 5
local STATE = {
    option_StairsXPJ_override       = "StairsXPJ_override",
    walking_direction               = "walking_direction",
    walking_direction_changed_armed = "walking_direction_changed_armed",
    boarding_from_the_terminal      = "boarding_from_the_terminal",
}
local PREFIX = "SimLoadManager/SGES/"

local refs = nil          -- datarefs de SLM 5, une fois trouves
local last_seq = {}
local next_probe = 0

local function attach()
    if not XPLMFindDataRef(PREFIX .. "Bus_seq") then return false end
    refs = {}
    for _, v in ipairs(VEHICLES) do
        refs[v] = {
            show = dataref_table(PREFIX .. v .. "_show"),
            seq  = dataref_table(PREFIX .. v .. "_seq"),
        }
        last_seq[v] = refs[v].seq[0]
    end
    refs.state = {}
    for key, name in pairs(STATE) do
        if XPLMFindDataRef(PREFIX .. name .. "_seq") then
            refs.state[key] = {
                value = dataref_table(PREFIX .. name),
                seq   = dataref_table(PREFIX .. name .. "_seq"),
            }
            last_seq[key] = refs.state[key].seq[0]
        end
    end
    logMsg("[SLM SGES bridge] SimLoad Manager detected, SGES bridge active")
    return true
end

function slm5_sges_bridge_frame()
    if not refs then
        -- SLM 5 peut demarrer apres FlyWithLua (ou etre en veille) : on re-sonde.
        if os.clock() < next_probe then return end
        next_probe = os.clock() + 2
        if not attach() then return end
    end
    -- Etat d'abord : le sens doit etre en place quand SGES traite Pax_chg / Cart_chg
    for key, r in pairs(refs.state) do
        local seq = r.seq[0]
        if seq ~= last_seq[key] then
            last_seq[key] = seq
            if key == "walking_direction" then
                walking_direction = (r.value[0] == 1) and "deboarding" or "boarding"
            else
                _G[key] = (r.value[0] == 1)
            end
        end
    end
    for _, v in ipairs(VEHICLES) do
        local seq = refs[v].seq[0]
        if seq ~= last_seq[v] then
            last_seq[v] = seq
            _G["show_" .. v] = (refs[v].show[0] == 1)
            _G[v .. "_chg"] = true
        end
    end
end

do_every_frame("slm5_sges_bridge_frame()")
