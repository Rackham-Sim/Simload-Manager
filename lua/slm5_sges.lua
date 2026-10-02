-- ============================================================
-- SimLoad Manager - pont SGES, cote SLM 5
-- ============================================================
-- Sous FlyWithLua, SLM demande les vehicules SGES en ecrivant des
-- variables globales partagees (show_Bus = true ; Bus_chg = true).
-- SLM 5 tourne dans son propre etat Lua : SGES ne les voit plus.
--
-- Ce script, charge par le plugin AVANT SimLoadManager.lua,
-- intercepte ces affectations et publie chaque demande en datarefs :
--   SimLoadManager/SGES/<Vehicule>_show  (0/1)
--   SimLoadManager/SGES/<Vehicule>_seq   (compteur de demandes)
--   SimLoadManager/SGES/StairsXPJ_override (+ _seq)
-- Le script FlyWithLua SimLoadManager_SGES_bridge.lua les relit et
-- recree les variables globales attendues par SGES.
-- SimLoadManager.lua n'est pas modifie : il lit et ecrit ces variables
-- comme avant (valeurs conservees dans une table fantome).
-- ============================================================

local VEHICLES = {
    "Bus", "Pax", "FUEL", "Catering", "Cleaning", "Cones", "Chocks",
    "StairsXPJ", "StairsXPJ2", "BeltLoader", "RearBeltLoader", "Cart",
    "People1", "People2", "People3", "People4",
}
local OVERRIDE = "option_StairsXPJ_override"
local PREFIX = "SimLoadManager/SGES/"

local show_dr, seq_dr = {}, {}
for _, v in ipairs(VEHICLES) do
    show_dr[v] = create_dataref_table(PREFIX .. v .. "_show", "Int")
    seq_dr[v]  = create_dataref_table(PREFIX .. v .. "_seq", "Int")
end
local override_dr     = create_dataref_table(PREFIX .. "StairsXPJ_override", "Int")
local override_seq_dr = create_dataref_table(PREFIX .. "StairsXPJ_override_seq", "Int")

-- Nom de variable globale -> vehicule concerne
local watched = { [OVERRIDE] = true }
for _, v in ipairs(VEHICLES) do
    watched["show_" .. v] = v
    watched[v .. "_chg"]  = v
end

local shadow  = {}   -- valeurs courantes des variables surveillees
local pending = {}   -- vehicules avec une demande a publier

setmetatable(_G, {
    __index = function(_, key)
        if watched[key] then return shadow[key] end
        return nil
    end,
    __newindex = function(t, key, value)
        local vehicle = watched[key]
        if not vehicle then
            rawset(t, key, value)
            return
        end
        shadow[key] = value
        if key == OVERRIDE then
            override_dr[0] = value and 1 or 0
            override_seq_dr[0] = override_seq_dr[0] + 1
        elseif key == vehicle .. "_chg" and value then
            pending[vehicle] = true
        end
    end,
})

-- Appele par le plugin a la fin de chaque frame : publie les demandes.
-- La valeur de show_X est lue ici, apres toutes les affectations de la frame.
function slm5_sges_flush()
    for vehicle in pairs(pending) do
        show_dr[vehicle][0] = shadow["show_" .. vehicle] and 1 or 0
        seq_dr[vehicle][0] = seq_dr[vehicle][0] + 1
        pending[vehicle] = nil
    end
end
