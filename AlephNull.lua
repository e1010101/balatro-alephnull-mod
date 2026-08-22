--- STEAMODDED HEADER
--- MOD_NAME: Aleph-Null
--- MOD_ID: cx
--- MOD_AUTHOR: [complex]
--- MOD_DESCRIPTION: Add some stuff.
--- DEPENDENCIES: [Steamodded>=1.0.0~ALPHA-0812d]
--- PRIORITY: 999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999

----------------------------------------------
------------MOD CODE -------------------------

local conceptual = function(self, card, badges)
	local scaling = 1.25
	badges[#badges + 1] = {n=G.UIT.R, config={align = "cm"}, nodes={
		{n=G.UIT.R, config={align = "cm", colour = G.C.BLACK, r = 0.1, minw = 2, minh = 0.4*scaling, emboss = 0.05, padding = 0.03*scaling}, nodes={
			{n=G.UIT.B, config={h=0.1,w=0.03}},
			{n=G.UIT.O, config={object = DynaText({
				string = {'?????'},
				colours = {G.C.color_rgb},
				text_effect = 'cx_pop3d',
				float = true,
				rotate = true,
				bump = true,
				-- random positional jitter lives in cx_pop3d's draw_letter
				-- (engine quiver is rotation-based and just wags the ? tails);
				-- colour flicker comes from color_rgb re-rolling every frame
				shadow = true,
				offset_y = 0,
				silent = true,
				spacing = 2,
				pop_in_rate = 9,
				scale = 0.35*scaling
			})}},
			{n=G.UIT.B, config={h=0.1,w=0.03}},
		}}
	}}
end

local ALEPH_OPERATOR = 1e9
local ALEPH_SCORING_KEY = 'cx_aleph_null'

local function cx_to_big(value)
    if to_big then
        return to_big(value)
    end
    return value
end

local function cx_big_gte(left, right)
    if to_big then
        return to_big(left or 0) >= to_big(right or 0)
    end
    return (left or 0) >= (right or 0)
end

-- NaN/garbage detector for plain numbers and OmegaNum Bigs
local function cx_big_is_bad(value)
    if value == nil then return true end
    local ok, bad = pcall(function()
        local n = (Big and Big.is and Big.is(value)) and value.number or value
        return type(n) == 'number' and n ~= n
    end)
    return (not ok) or bad
end

-- Sign tripwire (temporary diagnostic): observe-only logging to pinpoint where
-- a score value first turns negative. Logs the first few events per tag with
-- operands and a stack trace to <save dir>/alephnull_tripwire.log, then counts
-- silently. Never alters values, never raises: every log path is pcall-guarded
-- and self-disables on filesystem failure. Remove once the root cause is known.
local CX_TRIP = {enabled = true, total = 0, TOTAL_MAX = 600, tags = {}, TAG_FULL = 6, busy = false}

local function cx_trip_repr(v)
    local ok, s = pcall(function()
        if type(v) == 'number' then return string.format('%.17g', v) end
        if Big and Big.is and Big.is(v) then
            return string.format('Big(sign=%s number=%s "%s")',
                tostring(v.sign), tostring(v.number), tostring(v))
        end
        return type(v) .. '(' .. tostring(v) .. ')'
    end)
    return ok and s or '<repr-error>'
end

local function cx_trip_is_negative(v)
    local ok, neg = pcall(function()
        if type(v) == 'number' then return v < 0 end
        if Big and Big.is and Big.is(v) then
            if v.sign and v.sign < 0 then return true end
            local n = v.number
            return type(n) == 'number' and n < 0
        end
        return false
    end)
    return ok and neg
end

local function cx_trip_log(tag, detail)
    if not CX_TRIP.enabled then return end
    local t = CX_TRIP.tags[tag]
    if not t then t = {n = 0}; CX_TRIP.tags[tag] = t end
    t.n = t.n + 1
    if CX_TRIP.total >= CX_TRIP.TOTAL_MAX then return end
    local full = t.n <= CX_TRIP.TAG_FULL
    if not full and t.n % 200 ~= 0 then return end
    CX_TRIP.total = CX_TRIP.total + 1
    local ok = pcall(function()
        local round = (G and G.GAME and G.GAME.round) and tostring(G.GAME.round) or '?'
        local blind = (G and G.GAME and G.GAME.blind and G.GAME.blind.name) and G.GAME.blind.name or '?'
        local body
        if full then
            local d = type(detail) == 'function' and detail() or tostring(detail)
            body = d .. '\n' .. debug.traceback('', 3) .. '\n----\n'
        else
            body = 'suppressed, seen x' .. t.n .. '\n'
        end
        love.filesystem.append('alephnull_tripwire.log', string.format(
            '[%s] round=%s blind=%s | %s | %s', os.date('%H:%M:%S'), round, blind, tag, body))
    end)
    if not ok then CX_TRIP.enabled = false end
end

pcall(function()
    love.filesystem.append('alephnull_tripwire.log', string.format(
        '\n==== AlephNull sign tripwire armed | %s ====\n', os.date('%Y-%m-%d %H:%M:%S')))
end)

-- Detects arithmetic that MANUFACTURES a negative from non-negative operands
-- (a legitimate `small - big` is not logged). Wraps the Big methods and the
-- operator metamethods, pass-through in all cases.
local function cx_trip_wrap_bigmath()
    if not (Big and Big.add and Big.sub and Big.mul and to_big) then return end
    if Big.cx_trip_mathwrapped then return end
    Big.cx_trip_mathwrapped = true

    local function made_negative(a, b, r)
        return cx_trip_is_negative(r) and not cx_trip_is_negative(a) and not cx_trip_is_negative(b)
    end
    local function sub_illegit(a, b, r)
        if not made_negative(a, b, r) then return false end
        local ok, b_bigger = pcall(function() return to_big(b) > to_big(a) end)
        return ok and not b_bigger
    end

    local function wrap2(tag, orig, check)
        return function(a, b)
            local r = orig(a, b)
            if CX_TRIP.enabled and not CX_TRIP.busy then
                CX_TRIP.busy = true
                pcall(function()
                    if check(a, b, r) then
                        cx_trip_log(tag, function()
                            return 'a=' .. cx_trip_repr(a) .. ' b=' .. cx_trip_repr(b) .. ' r=' .. cx_trip_repr(r)
                        end)
                    end
                end)
                CX_TRIP.busy = false
            end
            return r
        end
    end

    Big.add = wrap2('big_add_sign_bug', Big.add, made_negative)
    Big.sub = wrap2('big_sub_sign_bug', Big.sub, sub_illegit)
    Big.mul = wrap2('big_mul_sign_bug', Big.mul, made_negative)
    local mt = getmetatable(to_big(1))
    if mt then
        if mt.__add then mt.__add = wrap2('big_mm_add_sign_bug', mt.__add, made_negative) end
        if mt.__sub then mt.__sub = wrap2('big_mm_sub_sign_bug', mt.__sub, sub_illegit) end
        if mt.__mul then mt.__mul = wrap2('big_mm_mul_sign_bug', mt.__mul, made_negative) end
    end
end

-- Attribution layer: logs WHICH effect delivered a negative amount, with the
-- source card and full effect table. Wraps SMODS.calculate_individual_effect
-- outermost (installed lazily from Game:update, after every mod has chained
-- its own wrapper), so the untouched amount and effect are visible. Also logs
-- when the global `mult` and SMODS.Scoring_Parameters.mult.current disagree —
-- the x_mult delta branch silently assumes they are equal.
local function cx_trip_card_info(c)
    local ok, s = pcall(function()
        if not c then return 'nil' end
        if c.config and c.config.center then
            local bits = {tostring(c.config.center.key or c.config.center.name or '?')}
            if c.base and c.base.value then
                bits[#bits + 1] = tostring(c.base.value) .. ' of ' .. tostring(c.base.suit)
            end
            if c.edition and c.edition.key then bits[#bits + 1] = 'ed:' .. tostring(c.edition.key) end
            if c.seal then bits[#bits + 1] = 'seal:' .. tostring(c.seal) end
            return table.concat(bits, ' ')
        end
        return tostring(c)
    end)
    return ok and s or '<card-repr-error>'
end

local function cx_trip_effect_info(effect)
    local ok, s = pcall(function()
        local bits, n = {}, 0
        for k, v in pairs(effect) do
            n = n + 1
            if n > 15 then bits[#bits + 1] = '...'; break end
            if type(v) == 'table' and v.config then
                bits[#bits + 1] = tostring(k) .. '=<card ' .. cx_trip_card_info(v) .. '>'
            elseif type(v) == 'table' and not (Big and Big.is and Big.is(v)) then
                bits[#bits + 1] = tostring(k) .. '=<table>'
            else
                bits[#bits + 1] = tostring(k) .. '=' .. cx_trip_repr(v)
            end
        end
        return table.concat(bits, ' | ')
    end)
    return ok and s or '<effect-repr-error>'
end

local cx_trip_scie_wrapped = false
local function cx_trip_wrap_scie()
    if cx_trip_scie_wrapped then return end
    if not (SMODS and type(SMODS.calculate_individual_effect) == 'function') then return end
    cx_trip_scie_wrapped = true
    local scie_ref = SMODS.calculate_individual_effect
    SMODS.calculate_individual_effect = function(effect, scored_card, key, amount, from_edition, ...)
        if CX_TRIP.enabled then
            if cx_trip_is_negative(amount) then
                cx_trip_log('scie_negative_amount[' .. tostring(key) .. ']', function()
                    return 'amount=' .. cx_trip_repr(amount)
                        .. ' | scored_card=' .. cx_trip_card_info(scored_card)
                        .. ' | effect: ' .. cx_trip_effect_info(effect)
                end)
            end
            if SMODS.Scoring_Parameters and SMODS.Scoring_Parameters.mult then
                local cur = SMODS.Scoring_Parameters.mult.current
                local ok, differ = pcall(function() return to_big(mult or 0) ~= to_big(cur or 0) end)
                if ok and differ then
                    cx_trip_log('mult_desync[' .. tostring(key) .. ']', function()
                        return 'global_mult=' .. cx_trip_repr(mult) .. ' param_current=' .. cx_trip_repr(cur)
                            .. ' amount=' .. cx_trip_repr(amount)
                            .. ' | scored_card=' .. cx_trip_card_info(scored_card)
                    end)
                end
            end
        end
        return scie_ref(effect, scored_card, key, amount, from_edition, ...)
    end
end

-- Outermost wrap over mod_mult/mod_chips: sees the raw value before Cryptid's
-- Lemon Trophy cap (and any other mod's wrapper) touches it. Installed lazily
-- from the first Game:update so it lands after every mod has chained its own.
local cx_trip_mods_wrapped = false
local function cx_trip_wrap_mods()
    if cx_trip_mods_wrapped then return end
    if type(mod_mult) ~= 'function' or type(mod_chips) ~= 'function' then return end
    cx_trip_mods_wrapped = true
    local mm_ref, mc_ref = mod_mult, mod_chips
    function mod_mult(v)
        local neg_in = cx_trip_is_negative(v)
        if neg_in then
            cx_trip_log('mod_mult_negative_in', function() return cx_trip_repr(v) end)
        end
        local r = mm_ref(v)
        if not neg_in and cx_trip_is_negative(r) then
            cx_trip_log('mod_mult_made_negative', function()
                return 'in=' .. cx_trip_repr(v) .. ' out=' .. cx_trip_repr(r)
            end)
        end
        return r
    end
    function mod_chips(v)
        local neg_in = cx_trip_is_negative(v)
        if neg_in then
            cx_trip_log('mod_chips_negative_in', function() return cx_trip_repr(v) end)
        end
        local r = mc_ref(v)
        if not neg_in and cx_trip_is_negative(r) then
            cx_trip_log('mod_chips_made_negative', function()
                return 'in=' .. cx_trip_repr(v) .. ' out=' .. cx_trip_repr(r)
            end)
        end
        return r
    end
end

-- Root-cause fix for negative score corruption: SMODS's scoring-parameter
-- sync (scoring_calculation.toml patches mod_mult/mod_chips) applies the new
-- value as a DELTA through modify's skip path: current = mult + (_mult - mult).
-- With Amulet bigs past ~1e308 the double caches read inf and add/sub fall
-- into log-domain approximations, so the round-trip returns garbage —
-- including sign-flipped values — straight into Scoring_Parameters, bypassing
-- every guard hung on mod_mult. Wrapping outermost and re-syncing ABSOLUTELY
-- makes the delta arithmetic irrelevant: whatever the inner sync computed,
-- current ends up exactly the value mod_mult returned. Installed lazily from
-- Game:update so it wraps every other mod's chained mod_mult/mod_chips.
local cx_fix_param_sync_installed = false
local function cx_fix_scoring_param_sync()
    if cx_fix_param_sync_installed then return end
    if not (SMODS and SMODS.Scoring_Parameters
        and type(mod_mult) == 'function' and type(mod_chips) == 'function') then
        return
    end
    cx_fix_param_sync_installed = true
    local mm_ref, mc_ref = mod_mult, mod_chips
    function mod_mult(v)
        local r = mm_ref(v)
        local p = SMODS.Scoring_Parameters and SMODS.Scoring_Parameters.mult
        if p and p.current ~= r then
            p.current = r
            update_hand_text({delay = 0}, {mult = r})
        end
        return r
    end
    function mod_chips(v)
        local r = mc_ref(v)
        local p = SMODS.Scoring_Parameters and SMODS.Scoring_Parameters.chips
        if p and p.current ~= r then
            p.current = r
            update_hand_text({delay = 0}, {chips = r})
        end
        return r
    end
end

-- Amulet's OmegaNum intentionally returns NaN for negative-base fractional
-- powers and negative arrow operands (frostice482/amulet#19, closed
-- not_planned) — a NaN score reads as 0/unbeatable and ruins runs, which
-- Talisman never did. Repair locally: pow on a negative base yields |base|^exp
-- (negative scoring values are corrupt state here — see the scoring-param sync
-- fix above — so the sign is sanitized rather than preserved); arrow clamps
-- negative operands to 0; anything still NaN becomes 0 instead of poisoning
-- the run. Only fires when the original op produced NaN, so all normal math
-- is untouched.
local function cx_repair_nan_ops()
    if not (Big and Big.pow and Big.arrow and Big.abs and Big.neg and to_big) then
        return
    end
    if Big.cx_nan_repaired then return end
    Big.cx_nan_repaired = true

    local pow_ref = Big.pow
    function Big:pow(other)
        local result = pow_ref(self, other)
        if cx_big_is_bad(result) then
            cx_trip_log('big_pow_nan_repair', function()
                return 'self=' .. cx_trip_repr(self) .. ' other=' .. cx_trip_repr(other)
            end)
            local ok, repaired = pcall(function()
                return pow_ref(self:abs(), other)
            end)
            if ok and repaired and not cx_big_is_bad(repaired) then
                return repaired
            end
            return to_big(0)
        end
        return result
    end

    -- the ^ operator captured the original pow at load time; wrap it separately
    local mt = getmetatable(to_big(1))
    if mt and mt.__pow then
        local pow_mm_ref = mt.__pow
        mt.__pow = function(a, b)
            local result = pow_mm_ref(a, b)
            if cx_big_is_bad(result) then
                cx_trip_log('big_pow_mm_nan_repair', function()
                    return 'a=' .. cx_trip_repr(a) .. ' b=' .. cx_trip_repr(b)
                end)
                local ok, repaired = pcall(function()
                    return pow_mm_ref(to_big(a):abs(), b)
                end)
                if ok and repaired and not cx_big_is_bad(repaired) then
                    return repaired
                end
                return to_big(0)
            end
            return result
        end
    end

    local arrow_ref = Big.arrow
    function Big:arrow(arrows, other)
        local result = arrow_ref(self, arrows, other)
        if cx_big_is_bad(result) then
            cx_trip_log('big_arrow_nan_repair', function()
                return 'self=' .. cx_trip_repr(self) .. ' arrows=' .. tostring(arrows) .. ' other=' .. cx_trip_repr(other)
            end)
            local ok, repaired = pcall(function()
                return arrow_ref(self:max(to_big(0)), arrows, to_big(other):max(to_big(0)))
            end)
            if ok and repaired and not cx_big_is_bad(repaired) then
                return repaired
            end
            return to_big(0)
        end
        return result
    end

    -- Amulet's ee-tier effects call tetrate directly, bypassing arrow
    if Big.tetrate then
        local tetrate_ref = Big.tetrate
        function Big:tetrate(other, ...)
            local result = tetrate_ref(self, other, ...)
            if cx_big_is_bad(result) then
                cx_trip_log('big_tetrate_nan_repair', function()
                    return 'self=' .. cx_trip_repr(self) .. ' other=' .. cx_trip_repr(other)
                end)
                local ok, repaired = pcall(function()
                    return tetrate_ref(self:max(to_big(0)), to_big(other):max(to_big(0)))
                end)
                if ok and repaired and not cx_big_is_bad(repaired) then
                    return repaired
                end
                return to_big(0)
            end
            return result
        end
    end
end
cx_repair_nan_ops()
cx_trip_wrap_bigmath()

-- Deepest layer of NaN defence: Amulet applies X/^/^^/^^^ chips+mult effects
-- through Talisman.effects.list[*].set (talisman/effects.lua). The ^ tier uses
-- the raw `c ^ a` operator — with a plain Lua number that's native pow and no
-- metamethod wrap can see it (the Supercharged Card path). Wrapping set() at
-- this boundary catches every NaN regardless of which math produced it: the
-- effect is skipped and the previous value kept, instead of poisoning the hand.
local function cx_wrap_talisman_effects()
    if not (Talisman and Talisman.effects and Talisman.effects.list) then
        return
    end
    if Talisman.effects.cx_nan_wrapped then
        return
    end
    Talisman.effects.cx_nan_wrapped = true
    local seen = {}
    for fx_key, fx in pairs(Talisman.effects.list) do
        if type(fx) == 'table' and type(fx.set) == 'function' and not seen[fx] then
            seen[fx] = true
            local set_ref = fx.set
            local tier = tostring(fx.key or fx_key)
            fx.set = function(current, amount)
                local ok, result = pcall(set_ref, current, amount)
                if ok and result ~= nil and not cx_big_is_bad(result) then
                    if cx_trip_is_negative(result) and not cx_trip_is_negative(current) then
                        cx_trip_log('fx_set_sign_flip[' .. tier .. ']', function()
                            return 'current=' .. cx_trip_repr(current) .. ' amount=' .. cx_trip_repr(amount)
                                .. ' result=' .. cx_trip_repr(result)
                        end)
                    end
                    return result
                end
                if not ok then
                    cx_trip_log('fx_set_error[' .. tier .. ']', function()
                        return tostring(result) .. ' | current=' .. cx_trip_repr(current)
                            .. ' amount=' .. cx_trip_repr(amount)
                    end)
                else
                    cx_trip_log('fx_set_nan_skip[' .. tier .. ']', function()
                        return 'current=' .. cx_trip_repr(current) .. ' amount=' .. cx_trip_repr(amount)
                    end)
                end
                if not cx_big_is_bad(current) then
                    return current
                end
                return to_big and to_big(0) or 0
            end
        end
    end
end
cx_wrap_talisman_effects()

local function cx_njr(context)
    if jl and jl.njr then
        return jl.njr(context)
    end
    return not context.retrigger_joker_check and not context.retrigger_joker
end

local function cx_queue(func)
    if Q then
        Q(func)
    elseif G and G.E_MANAGER then
        G.E_MANAGER:add_event(Event({func = func}))
    else
        func()
    end
end

local function cx_card_speak(card, text, col)
    if card and card.speak then
        card:speak(text, col)
    elseif card then
        card_eval_status_text(card, 'extra', nil, nil, nil, {message = text, colour = col or G.C.FILTER})
    end
end

local function cx_center(card)
    return card and card.config and card.config.center
end

local function cx_is_entity_card(card)
    local center = cx_center(card)
    return center and (center.cx_entity or center.key == 'j_cx_entity')
end

local function cx_is_creator_card(card)
    local center = cx_center(card)
    return center and (center.cx_creator or center.key == 'j_cx_creator')
end

local function cx_has_entity()
    if not (G and G.jokers and G.jokers.cards) then
        return false
    end
    for _, joker in ipairs(G.jokers.cards) do
        if cx_is_entity_card(joker) then
            return true
        end
    end
    return false
end

local function cx_is_conceptual_deck()
    if not (G and G.GAME) then
        return false
    end
    local back = G.GAME.selected_back or {}
    local effect = back.effect or {}
    local config = effect.config or {}
    local center = effect.center or {}
    return config.cx_edition == 'cx_conceptual'
        or center.key == 'b_cx_conceptual'
        or ((G.GAME.modifiers or {}).cx_highlight_limit ~= nil)
end

local function cx_is_conceptual_edition(edition)
    if type(edition) == 'string' then
        return edition == 'e_cx_conceptual'
    end
    if type(edition) == 'table' then
        return edition.cx_conceptual == true
            or edition.type == 'cx_conceptual'
            or edition.key == 'e_cx_conceptual'
    end
    return false
end

local card_set_edition_ref = Card.set_edition
function Card:set_edition(edition, immediate, silent, delay)
    -- cx_creator_preview: wizard preview/grid cards may cycle freely through
    -- editions, including away from Conceptual — stickiness is for real cards
    if self.edition and self.edition.cx_conceptual and not cx_is_conceptual_edition(edition)
        and not self.cx_creator_preview then
        return
    end
    return card_set_edition_ref(self, edition, immediate, silent, delay)
end

-- Last line of NaN defence: per-frame janitor over persistent game numbers.
-- Whatever unwrapped math path mints a NaN, it gets repaired within a frame
-- instead of festering in the run (and its save). Only touches keys that
-- exist and are NaN — never invents values.
local function cx_heal_number(container, key)
    local v = container and container[key]
    if v ~= nil and cx_big_is_bad(v) then
        container[key] = to_big and to_big(0) or 0
    end
end

local function cx_heal_nan_state()
    if not (G and G.GAME) then return end
    -- A negative run score is corrupt state — no legitimate path produces one.
    -- Log for attribution, then clamp the score (and Jen's per-frame fallback
    -- copy, which would otherwise faithfully restore the corruption) to 0.
    if G.GAME.chips ~= nil and cx_trip_is_negative(G.GAME.chips) then
        cx_trip_log('game_chips_negative_healed', function() return cx_trip_repr(G.GAME.chips) end)
        G.GAME.chips = to_big and to_big(0) or 0
        if G.GAME.chips_fallback ~= nil then
            G.GAME.chips_fallback = G.GAME.chips
        end
    end
    if SMODS and SMODS.Scoring_Parameters then
        for _, pk in ipairs({'mult', 'chips'}) do
            local p = SMODS.Scoring_Parameters[pk]
            if p and p.current ~= nil and cx_trip_is_negative(p.current) then
                cx_trip_log('param_' .. pk .. '_negative_healed', function()
                    return cx_trip_repr(p.current)
                end)
                p.current = to_big and to_big(0) or 0
            end
        end
    end
    cx_heal_number(G.GAME, 'dollars')
    cx_heal_number(G.GAME, 'chips')
    cx_heal_number(G.GAME.blind, 'chips')
    cx_heal_number(G.GAME.current_round, 'dollars')
    if G.jokers and G.jokers.cards then
        for _, card in ipairs(G.jokers.cards) do
            local a = card.ability
            if a then
                cx_heal_number(a, 'mult')
                cx_heal_number(a, 'x_mult')
                cx_heal_number(a, 'x_chips')
                cx_heal_number(a, 't_mult')
                cx_heal_number(a, 't_chips')
                cx_heal_number(a, 'extra_value')
            end
        end
    end
end

local function cx_area_keeps_cards_hidden(area)
    local area_type = area and area.config and area.config.type
    return not area_type or area_type == 'deck' or area_type == 'discard'
end

local function cx_enforce_conceptual_editions()
    if not (G and G.STAGE == G.STAGES.RUN and G.playing_cards) then
        return
    end
    if not cx_is_conceptual_deck() then
        return
    end
    for i = 1, #G.playing_cards do
        local card = G.playing_cards[i]
        if card and not (card.edition and card.edition.cx_conceptual) then
            card:set_edition({cx_conceptual = true}, true, true)
        end
        if card and card.edition and card.edition.cx_conceptual and card.facing == 'back'
            and not cx_area_keeps_cards_hidden(card.area) then
            card.cry_flipped = nil
            card:flip()
        end
    end
end

-- Owned Entity/Creator upkeep: never eternal (they must stay sellable — the
-- selling IS the money printer), always Conceptual. Also heals saves written
-- before these rules existed and stickers/editions forced by other mods.
local function cx_heal_staple_jokers()
    if not (G and G.jokers and G.jokers.cards) then
        return
    end
    for _, joker in ipairs(G.jokers.cards) do
        if cx_is_entity_card(joker) or cx_is_creator_card(joker) then
            if joker.ability and joker.ability.eternal then
                joker.ability.eternal = nil
            end
            if not (joker.edition and joker.edition.cx_conceptual) then
                joker:set_edition({cx_conceptual = true}, true)
            end
            -- canonical values: anything that slips past the modification
            -- blocks (misprintize wraps) is healed within a frame. The type
            -- check keeps the guard convergent if a big-number lib converted
            -- the value (plain ~= Big compares true forever in Lua 5.1).
            if joker.ability and (type(joker.ability.extra_value) ~= 'number'
                or joker.ability.extra_value ~= 1e100) then
                joker.ability.extra_value = 1e100
                joker:set_cost()
            end
            joker.misprint_cost_fac = nil
        end
    end
end

-- Guaranteed shop stock: these jokers appear in every shop. Runs from the
-- per-frame watchdog: if the shop joker row is missing one (fresh shop, reroll,
-- or just bought), it materializes. create_card with a forced key skips the
-- normal shop pool entirely. Extras beyond the first of each are culled,
-- healing saves written before the resume-duplication fix.
local CX_SHOP_STAPLES = {
    {key = 'j_cx_entity', is = cx_is_entity_card, pending = 'cx_entity_pending', conceptual = true},
    {key = 'j_cx_creator', is = cx_is_creator_card, pending = 'cx_creator_pending', conceptual = true},
}

local function cx_is_staple_card(card)
    for _, staple in ipairs(CX_SHOP_STAPLES) do
        if staple.is(card) then return true end
    end
    return false
end

-- Staples never consume rollable shop slots: the lovely payloads in the three
-- shop fill loops (Game:update_shop, change_shop_size, reroll_shop) count
-- rollable jokers through this instead of #G.shop_jokers.cards, so the shop
-- always rolls its full joker_max of normal stock with the staples on top.
-- Global on purpose — lovely payloads can only reach globals.
function CX_SHOP_ROLLABLE_COUNT()
    if not (G and G.shop_jokers and G.shop_jokers.cards) then return 0 end
    local n = 0
    for _, card in ipairs(G.shop_jokers.cards) do
        if not cx_is_staple_card(card) then n = n + 1 end
    end
    return n
end

function CX_SHOP_STAPLE_COUNT()
    if not (G and G.shop_jokers and G.shop_jokers.cards) then return 0 end
    local n = 0
    for _, card in ipairs(G.shop_jokers.cards) do
        if cx_is_staple_card(card) then n = n + 1 end
    end
    return n
end

local function cx_shop_has_staple(staple)
    local found = false
    local extras = nil
    for _, card in ipairs(G.shop_jokers.cards) do
        if staple.is(card) then
            if found then
                extras = extras or {}
                extras[#extras + 1] = card
            else
                found = true
            end
        end
    end
    if extras then
        for _, card in ipairs(extras) do
            card:remove()
        end
    end
    return found
end

local function cx_ensure_staples_in_shop()
    if not (G and G.STATE == G.STATES.SHOP and G.shop_jokers and G.shop_jokers.cards) then
        return
    end
    -- resuming a save restores the shop via a queued event; while the saved cards
    -- (possibly including a staple) are still pending in G.load_shop_jokers, the
    -- area looks empty — judging it now is what duplicated the Entity on reload
    if G.load_shop_jokers then
        return
    end
    -- staples ride above the rollable slots; widen the area's card_limit so
    -- the row lays out joker_max normals + staples without extra squeezing
    if G.GAME.shop and G.GAME.shop.joker_max then
        G.shop_jokers.config.card_limit = G.GAME.shop.joker_max + #CX_SHOP_STAPLES
    end
    -- per-frame price heal: whatever repricing path some mod takes (direct
    -- set_cost_value calls, inflation ticks, ...), staples stay free
    for _, card in ipairs(G.shop_jokers.cards) do
        if cx_is_staple_card(card) and card.cost ~= 0 then
            card.cost = 0
        end
    end
    for _, staple in ipairs(CX_SHOP_STAPLES) do
        if not G.shop_jokers[staple.pending] and not cx_shop_has_staple(staple) then
            G.shop_jokers[staple.pending] = true
            G.E_MANAGER:add_event(Event({func = function()
                if G.STATE == G.STATES.SHOP and G.shop_jokers and not G.load_shop_jokers
                    and not cx_shop_has_staple(staple) then
                    local card = create_card('Joker', G.shop_jokers, nil, nil, nil, nil, staple.key)
                    if staple.conceptual then
                        card:set_edition({cx_conceptual = true}, true, true)
                    end
                    create_shop_card_ui(card, 'Joker', G.shop_jokers)
                    card:start_materialize()
                    G.shop_jokers:emplace(card)
                end
                if G.shop_jokers then G.shop_jokers[staple.pending] = nil end
                return true
            end}))
        end
    end
end

-- Conceptual cards can never be flipped face-down outside the deck/discard piles.
-- These are Lua wraps rather than lovely patches on purpose: Cryptid rewrites the
-- CardArea:emplace flip line (adding cry_flipped), which silently broke the old
-- pattern patch, and its stakes set card.facing directly through that path.
local card_flip_ref = Card.flip
function Card:flip()
    if self.facing == 'front' and self.edition and self.edition.cx_conceptual
        and self.area and not cx_area_keeps_cards_hidden(self.area) then
        return
    end
    return card_flip_ref(self)
end

local cardarea_emplace_ref = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
    if card and card.edition and card.edition.cx_conceptual
        and not cx_area_keeps_cards_hidden(self) then
        card.cry_flipped = nil
        stay_flipped = nil
    end
    return cardarea_emplace_ref(self, card, location, stay_flipped)
end

local blind_stay_flipped_ref = Blind.stay_flipped
function Blind:stay_flipped(to_area, card, from_area)
    if card and card.edition and card.edition.cx_conceptual then
        return false
    end
    return blind_stay_flipped_ref(self, to_area, card, from_area)
end

local function cx_mark_aleph_active(reason)
    if G and G.GAME then
        G.GAME.cx_aleph_takeover = true
        G.GAME.cx_aleph_takeover_reason = reason or G.GAME.cx_aleph_takeover_reason
    end
end

local function cx_aleph_active()
    if not (G and G.GAME) then
        return false
    end
    if G.GAME.cx_aleph_takeover or cx_is_conceptual_deck() or cx_has_entity() then
        cx_mark_aleph_active(G.GAME.cx_aleph_takeover_reason or 'detected')
        return true
    end
    return false
end

local function cx_try_force_omeganum()
    if Talisman and Talisman.forced_features and Talisman.forced_features.force_omeganum then
        pcall(Talisman.forced_features.force_omeganum)
    end
end

local function cx_set_aleph_scoring()
    if not (G and G.GAME and SMODS and SMODS.Scoring_Calculations) then
        return
    end
    if not (Big and Big.arrow) then
        cx_try_force_omeganum()
    end
    G.GAME.hyper_operator = ALEPH_OPERATOR
    G.GAME.cx_aleph_operator = ALEPH_OPERATOR
    if SMODS.Scoring_Calculations[ALEPH_SCORING_KEY] and SMODS.set_scoring_calculation then
        local current_key = G.GAME.current_scoring_calculation_key
        local current_object_key = (G.GAME.current_scoring_calculation or {}).key
        if current_key ~= ALEPH_SCORING_KEY or current_object_key ~= ALEPH_SCORING_KEY then
            if pcall(SMODS.set_scoring_calculation, ALEPH_SCORING_KEY) then
                G.GAME.current_scoring_calculation_key = ALEPH_SCORING_KEY
            end
        end
    end
end

local function cx_score_floor()
    if not (G and G.GAME and G.GAME.blind and G.GAME.blind.chips) then
        return false
    end
    local ok, overkill = pcall(function()
        local base = G.GAME.blind.chips
        if cx_big_gte(1, base) then
            base = 2
        end
        return cx_to_big(base):arrow(ALEPH_OPERATOR, 2)
    end)
    if ok and overkill and not cx_big_is_bad(overkill) then
        local overkill_ok, already_overkill = pcall(cx_big_gte, G.GAME.chips, overkill)
        if not overkill_ok or not already_overkill or cx_big_is_bad(G.GAME.chips) then
            G.GAME.chips = overkill
        end
    else
        local fallback_ok, fallback = pcall(function()
            return (cx_to_big(G.GAME.blind.chips) * 2) + 1
        end)
        if fallback_ok and fallback and not cx_big_gte(G.GAME.chips, fallback) then
            G.GAME.chips = fallback
        end
    end
    if not cx_big_gte(G.GAME.chips, G.GAME.blind.chips) then
        G.GAME.chips = cx_to_big(G.GAME.blind.chips)
    end
    return true
end

local function cx_blind_ready()
    if not (G and G.GAME and G.GAME.blind and G.GAME.blind.chips) then
        return false
    end
    if not G.GAME.blind.name or G.GAME.blind.name == '' then
        return false
    end
    local ok, positive = pcall(function()
        return not cx_big_gte(0, G.GAME.blind.chips)
    end)
    return ok and positive
end

local function cx_current_blind_id()
    if not (G and G.GAME and G.GAME.blind) then
        return nil
    end
    return table.concat({
        tostring(G.GAME.round or 0),
        tostring((G.GAME.round_resets or {}).ante or 0),
        tostring(G.GAME.blind.name or '')
    }, ':')
end

local function cx_round_is_resolving()
    return G.STATE == G.STATES.HAND_PLAYED
        or G.STATE == G.STATES.ROUND_EVAL
        or G.STATE == G.STATES.NEW_ROUND
end

local function cx_force_blind_win(reason, force_event)
    if not cx_aleph_active() then
        return false
    end
    if not cx_blind_ready() then
        return false
    end
    if G.STATE == G.STATES.MENU or G.STATE == G.STATES.SHOP then
        return false
    end

    cx_try_force_omeganum()
    cx_set_aleph_scoring()

    G.GAME.blind.triggered = true
    G.GAME.blind.disabled = true
    G.GAME.blind.cx_aleph_subsumed = true
    G.GAME.cx_aleph_last_force = reason
    cx_score_floor()

    local blind_id = cx_current_blind_id()
    if blind_id and G.GAME.cx_aleph_won_blind_id == blind_id and cx_round_is_resolving() then
        return true
    end

    local now = (G.TIMERS and G.TIMERS.REAL) or 0
    if G.GAME.cx_aleph_end_round_queued and not force_event and now - G.GAME.cx_aleph_end_round_queued < 0.15 then
        return true
    end
    G.GAME.cx_aleph_end_round_queued = now

    cx_queue(function()
        if cx_aleph_active() and G.GAME.blind and G.GAME.blind.chips then
            G.GAME.cx_aleph_won_blind_id = cx_current_blind_id()
            G.GAME.blind.triggered = true
            G.GAME.blind.disabled = true
            G.GAME.blind.cx_aleph_subsumed = true
            cx_score_floor()
            G.STATE = G.STATES.HAND_PLAYED
            G.STATE_COMPLETE = true
            if end_round then
                end_round()
            end
        end
        if G and G.GAME then
            G.GAME.cx_aleph_end_round_queued = nil
        end
        return true
    end)
    return true
end

CX_ALEPH_WATCHDOG = function(reason)
    cx_repair_nan_ops()
    cx_wrap_talisman_effects()
    cx_heal_nan_state()
    cx_enforce_conceptual_editions()
    cx_heal_staple_jokers()
    cx_ensure_staples_in_shop()
    if cx_aleph_active() then
        cx_set_aleph_scoring()
        if cx_blind_ready() and G.STATE ~= G.STATES.SHOP then
            cx_force_blind_win(reason or 'watchdog')
        end
    end
end

CX_ALEPH_PRE_END_ROUND = function(reason)
    if cx_aleph_active() then
        cx_set_aleph_scoring()
        if cx_blind_ready() then
            G.GAME.blind.disabled = true
            G.GAME.blind.triggered = true
            G.GAME.blind.cx_aleph_subsumed = true
            cx_score_floor()
        end
    end
end

CX_ALEPH_BLIND_SET = function(reason)
    if cx_aleph_active() then
        cx_force_blind_win(reason or 'blind_set', true)
    end
end

if SMODS and SMODS.Scoring_Calculation then
    SMODS.Scoring_Calculation {
        key = 'aleph_null',
        func = function(self, chips, mult, flames)
            -- OmegaNum's arrow() returns NaN for negative operands, and a NaN
            -- score reads as 0 and fails the hand — clamp degenerate inputs
            -- (negative/zero/NaN chips or mult from debuffs and other mods)
            -- so the hand always scores something sane
            local safe_chips = cx_to_big(chips)
            local safe_mult = cx_to_big(mult)
            local ok_c, bad_c = pcall(cx_big_gte, 0, safe_chips)
            if not ok_c or bad_c or cx_big_is_bad(safe_chips) then safe_chips = cx_to_big(2) end
            local ok_m, bad_m = pcall(cx_big_gte, 0, safe_mult)
            if not ok_m or bad_m or cx_big_is_bad(safe_mult) then safe_mult = cx_to_big(2) end
            local ok, value = pcall(function()
                return safe_chips:arrow(ALEPH_OPERATOR, safe_mult)
            end)
            if ok and value and not cx_big_is_bad(value) then
                return value
            end
            local exp_ok, exp_value = pcall(function()
                return safe_chips ^ safe_mult
            end)
            if exp_ok and exp_value and not cx_big_is_bad(exp_value) then
                return exp_value
            end
            return math.huge
        end,
        text = '{1e9}',
        order = 1e9,
        colour = function()
            return G.C.color_rgb or G.C.DARK_EDITION
        end
    }
end

local function change_blind_size(newsize)
	newsize = cx_to_big(newsize)
	G.GAME.blind.chips = newsize
	G.E_MANAGER:add_event(Event({func = function()
		G.GAME.blind.chip_text = number_format(newsize)
		local chips_UI = G.hand_text_area.blind_chips
		G.FUNCS.blind_chip_UI_scale(G.hand_text_area.blind_chips)
		G.HUD_blind:recalculate() 
		chips_UI:juice_up()

		play_sound('chips2')
	return true end }))
end

local function colorRGB(hue, sat, light, red, green, blue, contrast) 
    local r, g, b = 0;
    sat = sat or 0.5
    light = light or 0.75

    if hue < 60 then 
        r = 1; 
        g = sat + (1 - sat) * (hue / 60); 
        b = 1 - sat; 
    elseif hue < 120 then 
        r = sat + (1 - sat) * ((120 - hue) / 60); 
        g = 1; 
        b = 1 - sat;
    elseif hue < 180 then 
        r = 1 - sat; 
        g = 1; 
        b = sat + (1 - sat) * ((hue - 120) / 60);
    elseif hue < 240 then 
        r = 1 - sat; 
        g = sat + (1 - sat) * ((240 - hue) / 60); 
        b = 1;
    elseif hue < 300 then 
        r = sat + (1 - sat) * ((hue - 240) / 60); 
        g = 1 - sat; 
        b = 1;
    else 
        r = 1; 
        g = 1 - sat; 
        b = sat + (1 - sat) * ((360 - hue) / 60); end

    local gray = (0.2989 * r + 0.5870 * g + 0.1140 * b) * (1 - (contrast or 0))

    r = (1 - 0.5) * r + 0.5 * gray
    g = (1 - 0.5) * g + 0.5 * gray
    b = (1 - 0.5) * b + 0.5 * gray

    r = r * light * (red or 1)
    g = g * light * (green or 1)
    b = b * light * (blue or 1)

    return r, g, b
end

local dissolve_ref = Card.start_dissolve
function Card:start_dissolve(dissolve_colours, silent, dissolve_time_fac, no_juice)
	if cx_is_entity_card(self) then
        self.true_dissolve = nil
		card_status_text(self, 'Immune', nil, 0.05*self.T.h, G.C.RED, nil, 0.6, nil, nil, 'bm', 'cancel')
		if not self.added_to_deck then
			self:add_to_deck()
			if self.ability.set == 'Joker' then G.jokers:emplace(self) else G.consumeables:emplace(self) end
		end
		return
	elseif self.cx_sell_stay then
		-- sale payout landed; only the sell flow's dissolve is suppressed, so
		-- genuine destruction effects still work on this card
		self.cx_sell_stay = nil
		card_status_text(self, 'Immune', nil, 0.05*self.T.h, G.C.RED, nil, 0.6, nil, nil, 'bm', 'cancel')
		return
	elseif self.true_dissolve then
		dissolve_ref(self, dissolve_colours, silent, dissolve_time_fac, no_juice)
	else
        dissolve_ref(self, dissolve_colours, silent, dissolve_time_fac, no_juice)
	end
end

local shatter_ref = Card.shatter
function Card:shatter()
	if ((self.config or {}).center or {}).cx_entity then
		card_status_text(self, 'Immune', nil, 0.05*self.T.h, G.C.RED, nil, 0.6, nil, nil, 'bm', 'cancel')
        if not self.added_to_deck then
			self:add_to_deck()
			if self.ability.set == 'Joker' then G.jokers:emplace(self) else G.consumeables:emplace(self) end
		end
		return
	else
        shatter_ref(self)
	end
end

local csdr = Card.set_debuff
function Card:set_debuff(should_debuff)
	if ((self.config or {}).center or {}).cx_entity and should_debuff == true then
		card_status_text(self, 'Immune', nil, 0.05*self.T.h, G.C.RED, nil, 0.6, nil, nil, 'bm', 'cancel')
        return false
	else
		csdr(self, should_debuff)
	end
end

-- Conceptual cards cannot have their values modified. Enforced here at the
-- modifiers' own entry points rather than via their opt-out flags (Cryptid's
-- `immutable` can even be skipped by its own callers through
-- args.bypass_checks) — these wraps sit outermost, so they always win.
local function cx_card_is_unmodifiable(card)
    if not card then return false end
    if card.edition and card.edition.cx_conceptual then return true end
    return cx_is_entity_card(card) or cx_is_creator_card(card)
end

if Cryptid then
    for _, fname in ipairs({'misprintize', 'manipulate'}) do
        local modifier_ref = Cryptid[fname]
        if type(modifier_ref) == 'function' then
            Cryptid[fname] = function(card, ...)
                if cx_card_is_unmodifiable(card) then
                    if card and card.T then
                        card_status_text(card, 'Immune', nil, 0.05*card.T.h, G.C.RED, nil, 0.6, nil, nil, 'bm', 'cancel')
                    end
                    return
                end
                return modifier_ref(card, ...)
            end
        end
    end
end

local card_destroy_ref = Card.destroy
function Card:destroy(dissolve_colours, silent, dissolve_time_fac, no_juice)
    if cx_is_entity_card(self) then
        self.true_dissolve = nil
        self:set_edition({cx_conceptual = true}, true)
        card_status_text(self, 'Immune', nil, 0.05*self.T.h, G.C.RED, nil, 0.6, nil, nil, 'bm', 'cancel')
        if not self.added_to_deck then
            self:add_to_deck()
            if self.ability.set == 'Joker' then G.jokers:emplace(self) else G.consumeables:emplace(self) end
        end
        cx_mark_aleph_active('entity_destroy_blocked')
        CX_ALEPH_WATCHDOG('entity_destroy_blocked')
        return
    end
    if card_destroy_ref then
        return card_destroy_ref(self, dissolve_colours, silent, dissolve_time_fac, no_juice)
    end
    return self:start_dissolve(dissolve_colours, silent, dissolve_time_fac, no_juice)
end

local card_add_to_deck_ref = Card.add_to_deck
function Card:add_to_deck(...)
    local ret = card_add_to_deck_ref(self, ...)
    if cx_is_entity_card(self) then
        cx_mark_aleph_active('entity_added')
        self.ability.eternal = nil
        self:set_edition({cx_conceptual = true}, true)
        self.ability.extra_value = 1e100
        self:set_cost()
        cx_set_aleph_scoring()
        CX_ALEPH_WATCHDOG('entity_added')
    elseif cx_is_creator_card(self) then
        self.ability.eternal = nil
        self:set_edition({cx_conceptual = true}, true)
        self.ability.extra_value = 1e100
        self:set_cost()
    end
    return ret
end

-- the Entity is always free: enforced after every cost recalculation so edition
-- extra_cost, discounts' minimum clamp, or other mods' pricing can't move it
local card_set_cost_ref = Card.set_cost
function Card:set_cost(...)
    local ret = card_set_cost_ref(self, ...)
    if cx_is_entity_card(self) or cx_is_creator_card(self) then
        self.cost = 0
    end
    return ret
end

-- Cryptid splits pricing into Card:set_cost_value (min-$1 clamp lives there)
-- and callers can hit it directly, bypassing the set_cost wrapper above —
-- that's how the Creator showed $1 in the shop. Wrap it too when it exists.
local card_set_cost_value_ref = Card.set_cost_value
if card_set_cost_value_ref then
    function Card:set_cost_value(...)
        local ret = card_set_cost_value_ref(self, ...)
        if cx_is_entity_card(self) or cx_is_creator_card(self) then
            self.cost = 0
        end
        return ret
    end
end

local game_updateref = Game.update
function Game:update(dt)
    game_updateref(self, dt)
    cx_fix_scoring_param_sync()
    cx_trip_wrap_mods()
    cx_trip_wrap_scie()
    CX_ALEPH_WATCHDOG('game_update_hook')
    if G.ARGS.LOC_COLOURS then
        if not self.C.color_rgb then
            self.C.color_rgb = {0,0,0,1}
            self.C.color_rgb_HUE = 0
        end

        local r, g, b = colorRGB(self.C.color_rgb_HUE, 0.5, 1, 1.5, 1.5, 1.5, 1)

        self.C.color_rgb[1] = r
        self.C.color_rgb[3] = g
        self.C.color_rgb[2] = b

        self.C.color_rgb_HUE = (math.random(1, 360)) % 360
        G.ARGS.LOC_COLOURS.color_rgb = self.C.color_rgb
    end
end

local Backapply_to_runRef = Back.apply_to_run
function Back.apply_to_run(self)
    Backapply_to_runRef(self)
    if self.effect.config.cx_highlight_limit then
        cx_mark_aleph_active('conceptual_deck')
        cx_set_aleph_scoring()
        G.GAME.modifiers.cx_highlight_limit = self.effect.config.cx_highlight_limit
    end
end

local blind_set_blind_ref = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
    local ret = blind_set_blind_ref(self, blind, reset, silent)
    CX_ALEPH_BLIND_SET('blind_set_hook')
    return ret
end

local blind_disable_ref = Blind.disable
function Blind:disable()
    local ret = blind_disable_ref(self)
    if cx_aleph_active() then
        self.disabled = true
        CX_ALEPH_BLIND_SET('blind_disable_hook')
    end
    return ret
end

local blind_defeat_ref = Blind.defeat
function Blind:defeat(silent)
    CX_ALEPH_PRE_END_ROUND('blind_defeat_hook')
    return blind_defeat_ref(self, silent)
end

local end_round_ref = end_round
function end_round(...)
    CX_ALEPH_PRE_END_ROUND('end_round_hook')
    return end_round_ref(...)
end

if G and G.FUNCS and G.FUNCS.evaluate_round then
    local evaluate_round_ref = G.FUNCS.evaluate_round
    G.FUNCS.evaluate_round = function(...)
        CX_ALEPH_PRE_END_ROUND('evaluate_round_hook')
        return evaluate_round_ref(...)
    end
end

-- SHADERS
SMODS.Shader {
    key = 'conceptual',
    path = 'conceptual.fs'
}

SMODS.Shader {
    key = 'entity',
    path = 'entity.fs',
    send_vars = function(sprite, card)
        return { cx_time = G.TIMERS.REAL }
    end
}

SMODS.Shader {
    key = 'entity_fractal',
    path = 'entity_fractal.fs',
    send_vars = function(sprite, card)
        return { cx_time = G.TIMERS.REAL }
    end
}

SMODS.Shader {
    key = 'conceptual_back',
    path = 'conceptual_back.fs',
    send_vars = function(sprite, card)
        return { cx_time = G.TIMERS.REAL }
    end
}

SMODS.Shader {
    key = 'entity_text',
    path = 'entity_text.fs',
    send_vars = function(sprite, card)
        return { cx_time = G.TIMERS.REAL }
    end
}

-- 3-D pop-out text: each letter is an extruded stack. The extrusion layers step
-- along the letter's shadow-parallax direction (so depth follows screen position
-- like card shadows do) and breathe over time; the top face is drawn slightly
-- toward the viewer and runs the entity_text psychedelic shader.
SMODS.DynaTextEffect {
    key = 'pop3d',
    draw_shadow = function(dt, k, letter)
        -- the extrusion is the depth; skip the flat drop shadow
    end,
    draw_letter = function(dt, k, letter)
        -- SMODS' set_letter_shader sends letter.r to the shader unguarded, but the
        -- engine only assigns letter.r once rotation animation ticks — nil on the
        -- first draw, which crashes Shader:send. Seed it before any shader pass.
        letter.r = letter.r or 0
        local real_pop_in = dt.config.min_cycle_time == 0 and 1 or letter.pop_in
        local FS = dt.font.FONTSCALE/G.TILESIZE
        local norm = dt.ARGS.draw_shadow_norm or {x = 0.4*FS, y = 0.6*FS}
        local bx = 0.5*(letter.dims.x - letter.offset.x)*FS + norm.x
        local by = 0.5*(letter.dims.y - letter.offset.y)*FS + norm.y
        local sc = real_pop_in*letter.scale*dt.scale*FS
        local ox, oy = 0.5*letter.dims.x/dt.scale, 0.5*letter.dims.y/dt.scale
        local t = G.TIMERS.REAL

        -- per-frame random jitter: shifts the whole letter (extrusion stack
        -- and face together) so glyphs shake bodily instead of rotating
        local jmag = (G.SETTINGS.reduced_motion and 0 or 1)*0.9
        bx = bx + (math.random() - 0.5)*2*jmag*norm.x
        by = by + (math.random() - 0.5)*2*jmag*norm.y
        local alpha = (dt.colours[1] and dt.colours[1][4]) or 1
        local depth = 4
        local amp = 1.0 + 0.5*math.sin(2.1*t + k*0.65)

        for i = depth, 1, -1 do
            local f = 0.10 + 0.09*(depth - i)
            local hue = 6.28318*(0.65*t + k*0.11 + i*0.07)
            love.graphics.setColor(
                f*(0.5 + 0.5*math.cos(hue)),
                f*(0.5 + 0.5*math.cos(hue + 2.094)),
                f*(0.5 + 0.5*math.cos(hue + 4.188)),
                alpha)
            love.graphics.draw(letter.letter,
                bx + i*amp*norm.x*2.2, by + i*amp*norm.y*2.2,
                letter.r or 0, sc, sc, ox, oy)
        end

        love.graphics.setColor(1, 1, 1, alpha)
        dt:set_letter_shader('cx_entity_text', nil, false, letter)
        love.graphics.draw(letter.letter,
            bx - amp*norm.x*1.2, by - amp*norm.y*1.2,
            letter.r or 0, sc, sc, ox, oy)
        dt:set_letter_shader()
    end,
}

-- fractal shatter on the Entity's card base, layered above the edition shader (order 20)
-- and below the floating sprite (order 60), then the JOKER-lettering layer: one soft
-- engine shadow (identical to the soul sprite's) under a floating face pass running
-- the card back's psychedelic shader.
SMODS.draw_ignore_keys.cx_letters = true

SMODS.DrawStep {
    key = 'cx_entity_base',
    order = 25,
    func = function(self)
        if (self.config.center.cx_entity or self.config.center.cx_creator)
            and (self.config.center.discovered or self.bypass_discovery_center) then
            local t = G.TIMERS.REAL
            local sp = self.shadow_parrallax
            local mag = sp and math.sqrt(sp.x*sp.x + sp.y*sp.y) or 0
            local nx = (mag > 0.0001) and sp.x/mag or 0
            local ny = (mag > 0.0001) and sp.y/mag or -1
            local amp = 0.5 + 0.5*math.sin(2.0*t)
            local step = 0.02 + 0.018*amp
            local fx, fy = -1.2*step*nx, -1.2*step*ny

            -- entity: fractal shatter base; creator: hypnotic glitch base
            self.children.center:draw_shader(
                self.config.center.cx_creator and 'cx_creator_base' or 'cx_entity_fractal',
                nil, self.ARGS.send_to_shader)

            local letters = self.children.cx_letters
            if letters then
                -- no drop shadow (removed with the soul shadows — floating
                -- glyphs read cleaner unanchored)

                -- psychedelic face, floating toward the viewer
                letters:draw_shader('cx_conceptual_back', nil, self.ARGS.send_to_shader, nil, self.children.center, 0.03*amp, nil, fx, fy)
            end
        end
    end,
    conditions = { vortex = false, facing = 'front' },
}

-- animated Conceptual deck back: conceptual laminate + glitch overlay on face-down cards.
-- The old lovely patch on `self.children.back:draw(overlay)` was dead code — SMODS 1.0
-- replaces Card:draw with its DrawStep pipeline, so the back must be drawn here instead.
-- Detects what the back sprite is actually displaying (atlas + pos) instead of resolving
-- the selected/viewed back: Galdur's deck-select grid and CardSleeves' previews swap
-- children.back to arbitrary sprites (per-deck art, sleeve art), so param-based
-- resolution animates the wrong thing or nothing at all.
local function cx_sprite_shows_conceptual_back(sprite)
    local center = G.P_CENTERS and G.P_CENTERS.b_cx_conceptual
    if not (sprite and center and center.pos) then return false end
    return sprite.atlas == G.ASSET_ATLAS[center.atlas]
        and sprite.sprite_pos
        and sprite.sprite_pos.x == center.pos.x
        and sprite.sprite_pos.y == center.pos.y
end

SMODS.DrawStep {
    key = 'cx_conceptual_back',
    order = 5,
    func = function(self)
        if cx_sprite_shows_conceptual_back(self.children.back) then
            self.children.back:draw_shader('cx_conceptual_back', nil, self.ARGS.send_to_shader, true)
        end
    end,
    conditions = { vortex = false, facing = 'back' },
}

-- SOUNDS
SMODS.Sound {
    key = 'e_conceptual',
    path = 'e_conceptual.ogg'
}

-- JOKER ATLASES
SMODS.Atlas {
    key = "entity",
    path = "j_cx_entity.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "entity_float",
    path = "j_cx_entity_float.png",
    px = 71,
    py = 95
}

-- DECK ATLASES
SMODS.Atlas {
    key = "atlasdeck",
    path = "atlasdeck.png",
    px = 71,
    py = 95
}

-- FLOATING SPRITES
local set_spritesref = Card.set_sprites
function Card:set_sprites(_center, _front)
	set_spritesref(self, _center, _front)
	if _center and (_center.cx_entity or _center.cx_creator) then
		-- dedicated JOKER-lettering layer: frame {2,0} of the float atlas
		-- holds just the corner text, extracted from the base art
		if self.children.cx_letters then self.children.cx_letters:remove() end
		self.children.cx_letters = Sprite(
			self.T.x,
			self.T.y,
			self.T.w,
			self.T.h,
			G.ASSET_ATLAS[_center.atlas or _center.set],
			{x = 2, y = 0}
		)
		self.children.cx_letters.role.draw_major = self
		self.children.cx_letters.states.hover.can = false
		self.children.cx_letters.states.click.can = false
	end
	if _center and _center.soul_pos and _center.soul_pos.extra then
		self.children.floating_sprite2 = Sprite(
			self.T.x,
			self.T.y,
			self.T.w,
			self.T.h,
			G.ASSET_ATLAS[_center.atlas or _center.set],
			_center.soul_pos.extra
		)
		self.children.floating_sprite2.role.draw_major = self
		self.children.floating_sprite2.states.hover.can = false
		self.children.floating_sprite2.states.click.can = false
	end
end

-- JOKERS
local cx_entity_echo_colour = {1, 1, 1, 0.3}

local function cx_entity_soul_draw(card, scale_mod, rotate_mod)
    local fs = card.children.floating_sprite
    if not fs then return end
    local t = G.TIMERS.REAL * 10
    -- manic motion: fast layered oscillators instead of the sedate vanilla soul bob,
    -- plus high-frequency positional jitter so it never fully settles
    local s = 0.10 + 0.05*math.sin(6.2*t) + 0.025*math.sin(13.7*t + 0.9)
    local r = 0.11*math.sin(5.1*t) + 0.04*math.sin(11.3*t + 1.7)
    local jx = 0.012*math.sin(17.3*t) + 0.006*math.sin(29.1*t)
    local jy = 0.010*math.cos(19.7*t) + 0.005*math.sin(23.9*t + 2.2)
    local send = card.ARGS and card.ARGS.send_to_shader

    fs:draw_shader('dissolve', 0, nil, nil, card.children.center, s, r, nil, 0.1 + 0.03*math.sin(4.1*t), nil, 0.6)

    for i = 2, 1, -1 do
        local phase = 4.8*t + i*2.6
        cx_entity_echo_colour[4] = 0.42 - 0.14*i
        fs.drawing_colour = cx_entity_echo_colour
        fs:draw_shader('cx_entity', nil, send, nil, card.children.center,
            s + 0.025*i, r + 0.06*math.sin(2.1*phase),
            0.05*i*math.cos(phase) + jx, 0.035*i*math.sin(1.3*phase) + jy)
    end
    fs.drawing_colour = nil

    fs:draw_shader('cx_entity', nil, send, nil, card.children.center, s, r, jx, jy)
end

SMODS.Joker {
    key = 'entity',
    loc_txt = {
        name = 'Entity',
        text = {
            '{C:color_rgb}Win all rounds immediately{}',
            '{C:color_rgb}Forces {C:attention}1e9-arrow{} scoring{}',
            '{C:inactive}Overrides blinds, game over, and score checks{}'
        }
    },
    pos = { x = 0, y = 0 },
    set_card_type_badge = conceptual,
    no_doe = true,
    cost = 0,
    rarity = 1,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = false,
    perishable_compat = false,
    immune_to_vermillion = true,
    cx_entity = true,
    atlas = 'entity_float',
    soul_pos = { x = 1, y = 0, draw = cx_entity_soul_draw },
    calculate = function(self, card, context)
        -- only an OWNED Entity may trigger the takeover: a shop-resident Entity
        -- being evaluated by some mod context must not flip a normal run into
        -- Aleph mode
        if not card.added_to_deck then return end
        cx_mark_aleph_active('entity_calculate')
        cx_set_aleph_scoring()
        if G.GAME.blind and G.GAME.blind.name ~= '' then
            G.GAME.blind.triggered = true
            G.GAME.blind.disabled = true
            card:set_edition({cx_conceptual = true}, true)
            
            if not context.blueprint_card and cx_njr(context) and context.setting_blind then
                cx_card_speak(card, 'Instawin!', G.C.color_rgb)
                cx_force_blind_win('entity_setting_blind', true)
            end
        end
    end
}

-- EDITIONS
SMODS.Edition({
    key = "conceptual",
    loc_txt = {
        name = "Conceptual",
        label = "Conceptual",
        text = {
            '{C:color_rgb,E:1}Conceptual{} cards cannot be {C:attention}Debuffed{}, {C:attention}Flipped{}, {C:attention}Destroyed{} or {C:attention}Modified{}',
            '{C:color_rgb,E:1}Conceptual{} cannot be removed or replaced by other {C:attention}Editions{}',
            '{C:attention}Selection Status{} of {C:color_rgb,E:1}Conceptual{} cards can only be affected by the player'
        }
    },
    discovered = true,
    unlocked = true,
    disable_base_shader = true,
	no_shadow = true,
    shader = 'conceptual',
    -- Split rendering: the card body gets vanilla polychrome (smooth rainbow tint),
    -- while the front layer — rank/suit text and sprites — gets the plasma shader.
    -- The busy effect lives in the glyphs; the calm base keeps them readable.
    -- Jokers/consumables have no separate front layer, so their art (the center)
    -- keeps the full plasma treatment.
    draw = function(self, card, layer)
        if card.children.front and not card:should_hide_front() then
            card.children.center:draw_shader('polychrome', nil, card.ARGS.send_to_shader)
            card.children.front:draw_shader(self.shader, nil, card.ARGS.send_to_shader)
        else
            card.children.center:draw_shader(self.shader, nil, card.ARGS.send_to_shader)
        end
    end,
	sound = {
		sound = 'cx_e_conceptual',
		per = 1,
		vol = 0.5
	},
    -- never rolled randomly: not in shop polls, zero weight in edition pools
    -- (only granted deliberately — Conceptual Deck, Entity, or the enforcement hooks)
    in_shop = false,
    weight = 0,
    extra_cost = 1,
    apply_to_float = false
})

-- DECKS
SMODS.Back{
	name = "Conceptual Deck",
	key = "conceptual",
    atlas = "atlasdeck",
	pos = {x = 0, y = 0},
	config = {  
                cx_edition = "cx_conceptual",
                consumable_slot = 1e100, 
                joker_slot = 1e100, 
                dollars = 1e100, 
                hands = 1e100, 
                discards = 1e100, 
                hand_size = 20,
                cx_highlight_limit = 1e100
            },
	loc_txt = {
		name = "Conceptual Deck",
		text ={
			"Start with a Deck",
			"full of {C:color_rgb,s:1.5,E:1}Conceptual{} cards",
            "Start with {C:color_rgb}1e100{} of {X:dark_edition,C:red}everything{}",
            "Hand size set to {C:attention}20{}",
            "You may select any number of cards",
            "Only {C:red}1{} Ante required to win"
		},
	},
	apply = function()
        cx_mark_aleph_active('conceptual_deck_apply')
        cx_set_aleph_scoring()
        G.GAME.win_ante = 1
		G.E_MANAGER:add_event(Event({
			func = function()
				for i = #G.playing_cards, 1, -1 do
					G.playing_cards[i]:set_edition({cx_conceptual = true}, true)
				end

                if G.jokers then
                    local card = create_card("Joker", G.jokers, nil, nil, nil, nil, "j_cx_entity")
                    card:add_to_deck()
                    card:start_materialize()
                    card:set_edition({cx_conceptual = true}, true)
                    G.jokers:emplace(card)
                end

				return true
            end
		}))
	end
}

-- THE CREATOR ------------------------------------------------------------
-- A joker with an activated ability: a Create button on its highlight UI
-- opens an overlay wizard (type select -> per-type composer) that conjures
-- any card into the run, free and unlimited.

-- same frame layout as entity_float: {0,0} card base (identical to the
-- Entity's), {1,0} floating soul (pixel tesseract), {2,0} JOKER lettering
SMODS.Atlas {
    key = "creator_float",
    path = "j_cx_creator_float.png",
    px = 71,
    py = 95
}

-- wizard state: draft lives here, never in G.GAME, so a save mid-wizard
-- simply forgets the draft instead of writing UI state into the run
local CX_CREATOR = {}

-- cards in wizard screens render at this scale so the overlays fit the screen
local CX_CREATOR_UI_SCALE = 0.75

local function cx_creator_loc_misc(key, set)
    local ok, res = pcall(localize, key, set)
    if ok and type(res) == 'string' and res ~= 'ERROR LOC' then return res end
    return key
end

local function cx_creator_loc_name(set, key)
    local ok, res = pcall(function()
        return localize{type = 'name_text', set = set, key = key}
    end)
    if ok and type(res) == 'string' and res ~= 'ERROR LOC' then return res end
    return key
end

local function cx_creator_edition_keys()
    local keys = {'none'}
    for _, c in ipairs(G.P_CENTER_POOLS.Edition or {}) do
        if c.key ~= 'e_base' then keys[#keys + 1] = c.key end
    end
    return keys
end

-- resolves an index into the editions list to a set_edition-ready key ('e_...')
local function cx_creator_edition_for(idx)
    local key = CX_CREATOR.editions and CX_CREATOR.editions[idx or 1]
    if not key or key == 'none' then return nil end
    return key
end

local function cx_creator_build_pools()
    local d = CX_CREATOR
    d.suits, d.ranks, d.enhancements, d.seals = {}, {}, {'none'}, {'none'}
    for _, k in ipairs(SMODS.Suit.obj_buffer) do d.suits[#d.suits + 1] = k end
    for _, k in ipairs(SMODS.Rank.obj_buffer) do d.ranks[#d.ranks + 1] = k end
    for _, c in ipairs(G.P_CENTER_POOLS.Enhanced) do d.enhancements[#d.enhancements + 1] = c.key end
    for _, k in ipairs(SMODS.Seal.obj_buffer) do d.seals[#d.seals + 1] = k end
    d.editions = cx_creator_edition_keys()
end

local function cx_creator_front_key()
    local d = CX_CREATOR
    local suit = SMODS.Suits[d.suits[d.draft.suit]]
    local rank = SMODS.Ranks[d.ranks[d.draft.rank]]
    if not (suit and rank) then return nil end
    return suit.card_key .. '_' .. rank.card_key
end

local function cx_creator_enh_center()
    local key = CX_CREATOR.enhancements[CX_CREATOR.draft.enh]
    return (key ~= 'none' and G.P_CENTERS[key]) or G.P_CENTERS.c_base
end

local function cx_creator_seal_key()
    local key = CX_CREATOR.seals[CX_CREATOR.draft.seal]
    if key == 'none' then return nil end
    return key
end

local function cx_creator_refresh_preview()
    local d = CX_CREATOR
    local card = d.preview_card
    if not (card and d.draft) then return end
    local front = G.P_CARDS[cx_creator_front_key() or '']
    if front then card:set_base(front) end
    card:set_ability(cx_creator_enh_center())
    card:set_seal(cx_creator_seal_key(), true, true)
    -- silent=false skips the juice/sound block, so cycling stays quiet
    card:set_edition(cx_creator_edition_for(d.draft.edition), true)
end

local function cx_creator_release_preview()
    -- the Card/CardArea objects themselves are torn down with the overlay
    -- UIBox (collection-page pattern); just drop our handles
    CX_CREATOR.preview_card = nil
    CX_CREATOR.preview_area = nil
end

local function cx_creator_type_screen()
    return create_UIBox_generic_options({
        back_func = 'exit_overlay_menu',
        contents = {
            {n = G.UIT.R, config = {align = "cm", padding = 0.1}, nodes = {
                {n = G.UIT.T, config = {text = 'Speak, and it is so', scale = 0.6, colour = G.C.color_rgb or G.C.WHITE, shadow = true}}
            }},
            {n = G.UIT.R, config = {align = "cm", padding = 0.1}, nodes = {
                UIBox_button({label = {'Playing Card'}, button = 'cx_creator_open_playing_card', minw = 5, colour = G.C.BLUE})
            }},
            {n = G.UIT.R, config = {align = "cm", padding = 0.1}, nodes = {
                UIBox_button({label = {'Consumable'}, button = 'cx_creator_open_consumable', minw = 5, colour = G.C.SECONDARY_SET.Tarot or G.C.PURPLE})
            }},
            {n = G.UIT.R, config = {align = "cm", padding = 0.1}, nodes = {
                UIBox_button({label = {'Joker'}, button = 'cx_creator_open_joker', minw = 5, colour = G.C.RED})
            }}
        }
    })
end

local function cx_creator_playing_card_screen()
    local d = CX_CREATOR
    cx_creator_build_pools()
    d.draft = {suit = 1, rank = 1, enh = 1, seal = 1, edition = 1}
    for i, k in ipairs(d.suits) do if k == 'Spades' then d.draft.suit = i end end
    for i, k in ipairs(d.ranks) do if k == 'Ace' then d.draft.rank = i end end

    local cw, ch = CX_CREATOR_UI_SCALE * G.CARD_W, CX_CREATOR_UI_SCALE * G.CARD_H
    d.preview_area = CardArea(
        G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h,
        1.1 * cw, 1.1 * ch,
        {card_limit = 1, type = 'title', highlight_limit = 0, collection = true})
    local front = G.P_CARDS[cx_creator_front_key() or ''] or G.P_CARDS.S_A
    d.preview_card = Card(d.preview_area.T.x, d.preview_area.T.y, cw, ch, front, G.P_CENTERS.c_base)
    d.preview_card.bypass_discovery_center = true
    d.preview_card.bypass_discovery_ui = true
    d.preview_card.cx_creator_preview = true
    d.preview_area:emplace(d.preview_card)

    local suit_labels, rank_labels, enh_labels, seal_labels, edition_labels = {}, {}, {'None'}, {'None'}, {'None'}
    for _, k in ipairs(d.suits) do suit_labels[#suit_labels + 1] = cx_creator_loc_misc(k, 'suits_plural') end
    for _, k in ipairs(d.ranks) do rank_labels[#rank_labels + 1] = cx_creator_loc_misc(k, 'ranks') end
    for i = 2, #d.enhancements do enh_labels[#enh_labels + 1] = cx_creator_loc_name('Enhanced', d.enhancements[i]) end
    for i = 2, #d.seals do seal_labels[#seal_labels + 1] = cx_creator_loc_name('Other', d.seals[i]:lower() .. '_seal') end
    for i = 2, #d.editions do edition_labels[#edition_labels + 1] = cx_creator_loc_name('Edition', d.editions[i]) end

    local function cycle_row(label, field, labels)
        return {n = G.UIT.R, config = {align = "cm", padding = 0.03}, nodes = {
            {n = G.UIT.C, config = {align = "cm", minw = 1.8}, nodes = {
                {n = G.UIT.T, config = {text = label, scale = 0.38, colour = G.C.UI.TEXT_LIGHT, shadow = true}}
            }},
            {n = G.UIT.C, config = {align = "cm"}, nodes = {
                create_option_cycle({
                    options = labels,
                    current_option = d.draft[field],
                    opt_callback = 'cx_creator_cycle',
                    cx_field = field,
                    w = 4.5,
                    scale = 0.85,
                    colour = G.C.RED,
                    no_pips = true
                })
            }}
        }}
    end

    return create_UIBox_generic_options({
        back_func = 'cx_creator_back_to_type',
        contents = {
            {n = G.UIT.R, config = {align = "cm", padding = 0.05, no_fill = true}, nodes = {
                {n = G.UIT.O, config = {object = d.preview_area}}
            }},
            cycle_row('Suit', 'suit', suit_labels),
            cycle_row('Rank', 'rank', rank_labels),
            cycle_row('Enhancement', 'enh', enh_labels),
            cycle_row('Seal', 'seal', seal_labels),
            cycle_row('Edition', 'edition', edition_labels),
            {n = G.UIT.R, config = {align = "cm", padding = 0.08}, nodes = {
                UIBox_button({label = {'Create'}, button = 'cx_creator_confirm', minw = 3.5, minh = 0.7, scale = 0.45, colour = G.C.GREEN})
            }}
        }
    })
end

-- consumable picker: set select -> paged grid of real cards, click to create
local CX_CREATOR_GRID_ROWS, CX_CREATOR_GRID_COLS = 2, 5

local function cx_creator_fill_cons_grid()
    local d = CX_CREATOR
    if not (d.grid_areas and d.cons_set) then return end
    local pool = G.P_CENTER_POOLS[d.cons_set] or {}
    local per_page = CX_CREATOR_GRID_ROWS * CX_CREATOR_GRID_COLS
    local cw, ch = CX_CREATOR_UI_SCALE * G.CARD_W, CX_CREATOR_UI_SCALE * G.CARD_H
    local edition = cx_creator_edition_for(d.cons_edition)
    for j = 1, #d.grid_areas do
        local area = d.grid_areas[j]
        for i = #area.cards, 1, -1 do
            local c = area:remove_card(area.cards[i])
            if c then c:remove() end
        end
    end
    for i = 1, CX_CREATOR_GRID_COLS do
        for j = 1, #d.grid_areas do
            local center = pool[i + (j - 1) * CX_CREATOR_GRID_COLS + per_page * ((d.cons_page or 1) - 1)]
            if center then
                local area = d.grid_areas[j]
                local card = Card(area.T.x + area.T.w / 2, area.T.y, cw, ch, G.P_CARDS.empty, center)
                card.bypass_discovery_center = true
                card.bypass_discovery_ui = true
                card.cx_creator_preview = true
                card.cx_creator_pick = true
                if edition then card:set_edition(edition, true) end
                area:emplace(card)
            end
        end
    end
end

local function cx_creator_set_label(k)
    local name = cx_creator_loc_misc('k_' .. string.lower(k), 'dictionary')
    if name == 'k_' .. string.lower(k) then name = k end
    return name
end

local function cx_creator_consumable_sets_screen()
    local rows = {
        {n = G.UIT.R, config = {align = "cm", padding = 0.06}, nodes = {
            {n = G.UIT.T, config = {text = 'Choose a set', scale = 0.5, colour = G.C.color_rgb or G.C.WHITE, shadow = true}}
        }}
    }
    for _, k in ipairs(SMODS.ConsumableType.obj_buffer) do
        local pool = G.P_CENTER_POOLS[k]
        if pool and #pool > 0 then
            rows[#rows + 1] = {n = G.UIT.R, config = {align = "cm", padding = 0.05}, nodes = {
                UIBox_button({
                    label = {cx_creator_set_label(k) .. ' (' .. #pool .. ')'},
                    button = 'cx_creator_open_cons_grid',
                    ref_table = {cx_set = k},
                    minw = 4.5,
                    minh = 0.7,
                    scale = 0.4,
                    colour = G.C.SECONDARY_SET[k] or G.C.PURPLE
                })
            }}
        end
    end
    return create_UIBox_generic_options({back_func = 'cx_creator_back_to_type', contents = rows})
end

local function cx_creator_cons_grid_screen(set)
    local d = CX_CREATOR
    d.cons_set = set
    d.cons_page = 1
    d.cons_edition = 1
    d.editions = cx_creator_edition_keys()
    d.grid_areas = {}
    local pool = G.P_CENTER_POOLS[set] or {}
    local per_page = CX_CREATOR_GRID_ROWS * CX_CREATOR_GRID_COLS
    local pages = math.max(1, math.ceil(#pool / per_page))
    local cw, ch = CX_CREATOR_UI_SCALE * G.CARD_W, CX_CREATOR_UI_SCALE * G.CARD_H
    local area_rows = {}
    for j = 1, CX_CREATOR_GRID_ROWS do
        d.grid_areas[j] = CardArea(
            G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h,
            (CX_CREATOR_GRID_COLS + 0.25) * cw, 1.05 * ch,
            {card_limit = CX_CREATOR_GRID_COLS, type = 'title', highlight_limit = 0, collection = true})
        area_rows[#area_rows + 1] = {n = G.UIT.R, config = {align = "cm", padding = 0.05, no_fill = true}, nodes = {
            {n = G.UIT.O, config = {object = d.grid_areas[j]}}
        }}
    end
    cx_creator_fill_cons_grid()
    local page_options = {}
    for i = 1, pages do page_options[#page_options + 1] = localize('k_page') .. ' ' .. i .. '/' .. pages end
    local edition_labels = {'None'}
    for i = 2, #d.editions do edition_labels[#edition_labels + 1] = cx_creator_loc_name('Edition', d.editions[i]) end
    return create_UIBox_generic_options({
        back_func = 'cx_creator_back_to_cons_sets',
        contents = {
            {n = G.UIT.R, config = {align = "cm", padding = 0.03}, nodes = {
                {n = G.UIT.T, config = {text = 'Click a card to create it', scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true}}
            }},
            {n = G.UIT.R, config = {align = "cm", r = 0.1, colour = G.C.BLACK, emboss = 0.05}, nodes = area_rows},
            {n = G.UIT.R, config = {align = "cm", padding = 0.05}, nodes = {
                {n = G.UIT.C, config = {align = "cm"}, nodes = {
                    create_option_cycle({options = page_options, current_option = 1, opt_callback = 'cx_creator_cons_page', w = 3.5, colour = G.C.RED, no_pips = true, focus_args = {snap_to = true, nav = 'wide'}})
                }},
                {n = G.UIT.C, config = {align = "cm", padding = 0.05}, nodes = {
                    create_option_cycle({options = edition_labels, current_option = 1, opt_callback = 'cx_creator_cons_edition', w = 3.5, colour = G.C.DARK_EDITION or G.C.PURPLE, no_pips = true})
                }}
            }}
        }
    })
end

local function cx_creator_pick_consumable(grid_card)
    local center = cx_center(grid_card)
    if not (center and center.key and G.consumeables) then return end
    local edition = cx_creator_edition_for(CX_CREATOR.cons_edition)
    CX_CREATOR.grid_areas = nil
    G.FUNCS.exit_overlay_menu()
    discover_card(center)
    local card = create_card(center.set, G.consumeables, nil, nil, nil, nil, center.key)
    card:add_to_deck()
    G.consumeables:emplace(card)
    if edition then card:set_edition(edition, true, true) end
    card:start_materialize({G.C.SECONDARY_SET.Spectral})
    play_sound('card1', 0.8, 0.6)
    play_sound('generic1')
end

local function cx_creator_pick_joker(grid_card)
    local center = cx_center(grid_card)
    if not (center and center.key and G.jokers) then return end
    local jk = CX_CREATOR.jk or {}
    local edition = cx_creator_edition_for(jk.edition_i)
    local sticker = jk.stickers and jk.stickers[jk.sticker_i or 1]
    CX_CREATOR.grid_areas = nil
    G.FUNCS.exit_overlay_menu()
    discover_card(center)
    local card = create_card('Joker', G.jokers, nil, nil, nil, nil, center.key)
    card:add_to_deck()
    G.jokers:emplace(card)
    if edition then card:set_edition(edition, true, true) end
    if sticker and sticker ~= 'none' and SMODS.Stickers[sticker] then
        SMODS.Stickers[sticker]:apply(card, true)
    end
    card:start_materialize({G.C.SECONDARY_SET.Spectral})
    play_sound('card1', 0.8, 0.6)
    play_sound('generic1')
end

-- grid cards are chosen by clicking the card itself
local card_click_ref = Card.click
function Card:click()
    if self.cx_creator_pick == 'joker' then
        cx_creator_pick_joker(self)
        return
    elseif self.cx_creator_pick then
        cx_creator_pick_consumable(self)
        return
    end
    return card_click_ref(self)
end

G.FUNCS.cx_creator_open_consumable = function(e)
    G.FUNCS.overlay_menu{definition = cx_creator_consumable_sets_screen()}
end

G.FUNCS.cx_creator_open_cons_grid = function(e)
    local set = e.config.ref_table and e.config.ref_table.cx_set
    if set then
        G.FUNCS.overlay_menu{definition = cx_creator_cons_grid_screen(set)}
    end
end

G.FUNCS.cx_creator_back_to_cons_sets = function(e)
    CX_CREATOR.grid_areas = nil
    G.FUNCS.overlay_menu{definition = cx_creator_consumable_sets_screen()}
end

G.FUNCS.cx_creator_cons_page = function(args)
    if not (args and args.cycle_config) then return end
    CX_CREATOR.cons_page = args.cycle_config.current_option
    cx_creator_fill_cons_grid()
end

G.FUNCS.cx_creator_cons_edition = function(args)
    if not (args and args.cycle_config) then return end
    CX_CREATOR.cons_edition = args.cycle_config.current_option
    local edition = cx_creator_edition_for(CX_CREATOR.cons_edition)
    for _, area in ipairs(CX_CREATOR.grid_areas or {}) do
        for _, card in ipairs(area.cards) do
            card:set_edition(edition, true)
        end
    end
end

-- joker picker: the big pool (hundreds with Cryptid) gets rarity + source
-- filters on top of the paged grid, plus edition and sticker cycles
local function cx_creator_rarity_label(r)
    if r == 'any' then return 'Any Rarity' end
    local key
    if type(r) == 'number' then
        key = ({'k_common', 'k_uncommon', 'k_rare', 'k_legendary'})[r] or tostring(r)
    else
        key = 'k_' .. string.lower(tostring(r))
    end
    local name = cx_creator_loc_misc(key, 'dictionary')
    if name == key then name = tostring(r) end
    return name
end

local function cx_creator_jk_build()
    local jk = CX_CREATOR.jk
    jk.rarities, jk.sources = {'any'}, {'any'}
    local seen_r, seen_s = {}, {}
    for _, c in ipairs(G.P_CENTER_POOLS.Joker) do
        local r = c.rarity or 1
        if not seen_r[r] then seen_r[r] = true; jk.rarities[#jk.rarities + 1] = r end
        local s = (c.mod and c.mod.name) or 'Base Game'
        if not seen_s[s] then seen_s[s] = true; jk.sources[#jk.sources + 1] = s end
    end
    jk.pool = {}
    local want_r = jk.rarities[jk.rarity_i] or 'any'
    local want_s = jk.sources[jk.source_i] or 'any'
    for _, c in ipairs(G.P_CENTER_POOLS.Joker) do
        local r_ok = want_r == 'any' or (c.rarity or 1) == want_r
        local s_ok = want_s == 'any' or ((c.mod and c.mod.name) or 'Base Game') == want_s
        if r_ok and s_ok then jk.pool[#jk.pool + 1] = c end
    end
end

local function cx_creator_fill_joker_grid()
    local d = CX_CREATOR
    if not (d.grid_areas and d.jk and d.jk.pool) then return end
    local jk = d.jk
    local per_page = CX_CREATOR_GRID_ROWS * CX_CREATOR_GRID_COLS
    local cw, ch = CX_CREATOR_UI_SCALE * G.CARD_W, CX_CREATOR_UI_SCALE * G.CARD_H
    local edition = cx_creator_edition_for(jk.edition_i)
    local sticker = jk.stickers and jk.stickers[jk.sticker_i or 1]
    for j = 1, #d.grid_areas do
        local area = d.grid_areas[j]
        for i = #area.cards, 1, -1 do
            local c = area:remove_card(area.cards[i])
            if c then c:remove() end
        end
    end
    for i = 1, CX_CREATOR_GRID_COLS do
        for j = 1, #d.grid_areas do
            local center = jk.pool[i + (j - 1) * CX_CREATOR_GRID_COLS + per_page * ((jk.page or 1) - 1)]
            if center then
                local area = d.grid_areas[j]
                local card = Card(area.T.x + area.T.w / 2, area.T.y, cw, ch, G.P_CARDS.empty, center)
                card.bypass_discovery_center = true
                card.bypass_discovery_ui = true
                card.cx_creator_preview = true
                card.cx_creator_pick = 'joker'
                if edition then card:set_edition(edition, true) end
                if sticker and sticker ~= 'none' then card.ability[sticker] = true end
                area:emplace(card)
            end
        end
    end
end

local function cx_creator_joker_screen(reset)
    local d = CX_CREATOR
    if reset or not d.jk then
        d.jk = {rarity_i = 1, source_i = 1, edition_i = 1, sticker_i = 1}
    end
    local jk = d.jk
    jk.page = 1
    d.editions = cx_creator_edition_keys()
    jk.stickers = {'none'}
    for _, k in ipairs(SMODS.Sticker.obj_buffer) do jk.stickers[#jk.stickers + 1] = k end
    cx_creator_jk_build()

    d.grid_areas = {}
    local per_page = CX_CREATOR_GRID_ROWS * CX_CREATOR_GRID_COLS
    local pages = math.max(1, math.ceil(#jk.pool / per_page))
    local cw, ch = CX_CREATOR_UI_SCALE * G.CARD_W, CX_CREATOR_UI_SCALE * G.CARD_H
    local area_rows = {}
    for j = 1, CX_CREATOR_GRID_ROWS do
        d.grid_areas[j] = CardArea(
            G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h,
            (CX_CREATOR_GRID_COLS + 0.25) * cw, 1.05 * ch,
            {card_limit = CX_CREATOR_GRID_COLS, type = 'title', highlight_limit = 0, collection = true})
        area_rows[#area_rows + 1] = {n = G.UIT.R, config = {align = "cm", padding = 0.05, no_fill = true}, nodes = {
            {n = G.UIT.O, config = {object = d.grid_areas[j]}}
        }}
    end
    cx_creator_fill_joker_grid()

    local page_options = {}
    for i = 1, pages do page_options[#page_options + 1] = localize('k_page') .. ' ' .. i .. '/' .. pages end
    local rarity_labels = {}
    for _, r in ipairs(jk.rarities) do rarity_labels[#rarity_labels + 1] = cx_creator_rarity_label(r) end
    local source_labels = {}
    for _, s in ipairs(jk.sources) do source_labels[#source_labels + 1] = (s == 'any') and 'Any Source' or s end
    local edition_labels = {'None'}
    for i = 2, #d.editions do edition_labels[#edition_labels + 1] = cx_creator_loc_name('Edition', d.editions[i]) end
    local sticker_labels = {'None'}
    for i = 2, #jk.stickers do sticker_labels[#sticker_labels + 1] = cx_creator_loc_misc(jk.stickers[i], 'labels') end

    local function half_cycle(labels, cur, callback, colour)
        return {n = G.UIT.C, config = {align = "cm", padding = 0.04}, nodes = {
            create_option_cycle({options = labels, current_option = cur, opt_callback = callback, w = 3.4, scale = 0.85, colour = colour, no_pips = true})
        }}
    end

    return create_UIBox_generic_options({
        back_func = 'cx_creator_back_to_type',
        contents = {
            {n = G.UIT.R, config = {align = "cm", padding = 0.03}, nodes = {
                {n = G.UIT.T, config = {text = 'Click a Joker to create it', scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true}}
            }},
            {n = G.UIT.R, config = {align = "cm", r = 0.1, colour = G.C.BLACK, emboss = 0.05}, nodes = area_rows},
            {n = G.UIT.R, config = {align = "cm", padding = 0.03}, nodes = {
                half_cycle(page_options, jk.page, 'cx_creator_jk_page', G.C.RED),
                half_cycle(rarity_labels, jk.rarity_i, 'cx_creator_jk_rarity', G.C.ORANGE)
            }},
            {n = G.UIT.R, config = {align = "cm", padding = 0.03}, nodes = {
                half_cycle(source_labels, jk.source_i, 'cx_creator_jk_source', G.C.BLUE),
                half_cycle(edition_labels, jk.edition_i, 'cx_creator_jk_edition', G.C.DARK_EDITION or G.C.PURPLE)
            }},
            {n = G.UIT.R, config = {align = "cm", padding = 0.03}, nodes = {
                half_cycle(sticker_labels, jk.sticker_i, 'cx_creator_jk_sticker', G.C.GREEN)
            }}
        }
    })
end

G.FUNCS.cx_creator_open_joker = function(e)
    G.FUNCS.overlay_menu{definition = cx_creator_joker_screen(true)}
end

G.FUNCS.cx_creator_jk_page = function(args)
    if not (args and args.cycle_config and CX_CREATOR.jk) then return end
    CX_CREATOR.jk.page = args.cycle_config.current_option
    cx_creator_fill_joker_grid()
end

-- filter changes rebuild the screen: the page cycle's option list depends on
-- the filtered pool size (edition/sticker selections survive in CX_CREATOR.jk)
G.FUNCS.cx_creator_jk_rarity = function(args)
    if not (args and args.cycle_config and CX_CREATOR.jk) then return end
    CX_CREATOR.jk.rarity_i = args.cycle_config.current_option
    G.FUNCS.overlay_menu{definition = cx_creator_joker_screen()}
end

G.FUNCS.cx_creator_jk_source = function(args)
    if not (args and args.cycle_config and CX_CREATOR.jk) then return end
    CX_CREATOR.jk.source_i = args.cycle_config.current_option
    G.FUNCS.overlay_menu{definition = cx_creator_joker_screen()}
end

G.FUNCS.cx_creator_jk_edition = function(args)
    if not (args and args.cycle_config and CX_CREATOR.jk) then return end
    CX_CREATOR.jk.edition_i = args.cycle_config.current_option
    local edition = cx_creator_edition_for(CX_CREATOR.jk.edition_i)
    for _, area in ipairs(CX_CREATOR.grid_areas or {}) do
        for _, card in ipairs(area.cards) do
            card:set_edition(edition, true)
        end
    end
end

G.FUNCS.cx_creator_jk_sticker = function(args)
    if not (args and args.cycle_config and CX_CREATOR.jk) then return end
    local jk = CX_CREATOR.jk
    jk.sticker_i = args.cycle_config.current_option
    local sk = jk.stickers[jk.sticker_i]
    for _, area in ipairs(CX_CREATOR.grid_areas or {}) do
        for _, card in ipairs(area.cards) do
            for i = 2, #jk.stickers do card.ability[jk.stickers[i]] = nil end
            if sk ~= 'none' then card.ability[sk] = true end
        end
    end
end

G.FUNCS.can_cx_create = function(e)
    local card = e.config.ref_table
    if card and card.added_to_deck and (G.GAME.STOP_USE or 0) <= 0 then
        e.config.colour = G.C.PURPLE
        e.config.button = 'cx_creator_open'
    else
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    end
end

G.FUNCS.cx_creator_open = function(e)
    CX_CREATOR.draft = nil
    CX_CREATOR.grid_areas = nil
    cx_creator_release_preview()
    G.FUNCS.overlay_menu{definition = cx_creator_type_screen()}
end

G.FUNCS.cx_creator_back_to_type = function(e)
    cx_creator_release_preview()
    CX_CREATOR.grid_areas = nil
    G.FUNCS.overlay_menu{definition = cx_creator_type_screen()}
end

G.FUNCS.cx_creator_open_playing_card = function(e)
    G.FUNCS.overlay_menu{definition = cx_creator_playing_card_screen()}
end

G.FUNCS.cx_creator_cycle = function(args)
    local field = args and args.cycle_config and args.cycle_config.cx_field
    if field and CX_CREATOR.draft then
        CX_CREATOR.draft[field] = args.to_key
        cx_creator_refresh_preview()
    end
end

G.FUNCS.cx_creator_confirm = function(e)
    local d = CX_CREATOR
    if not d.draft then return end
    local front = G.P_CARDS[cx_creator_front_key() or '']
    if not front then return end
    local enh = cx_creator_enh_center()
    local seal = cx_creator_seal_key()
    local edition = cx_creator_edition_for(d.draft.edition)
    cx_creator_release_preview()
    G.FUNCS.exit_overlay_menu()

    -- mid-round the card lands in hand, otherwise it joins the deck;
    -- mirrors the standard-pack take-card flow (button_callbacks use_card)
    local area = (G.STATE == G.STATES.SELECTING_HAND and G.hand) or G.deck
    if not area then return end
    local card = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W, G.CARD_H, front, G.P_CENTERS.c_base)
    if enh ~= G.P_CENTERS.c_base then card:set_ability(enh) end
    if seal then card:set_seal(seal, true, true) end
    if edition then card:set_edition(edition, true, true) end
    G.playing_card = (G.playing_card and G.playing_card + 1) or 1
    card.playing_card = G.playing_card
    area:emplace(card)
    card:add_to_deck()
    table.insert(G.playing_cards, card)
    card:start_materialize({G.C.SECONDARY_SET.Spectral})
    playing_card_joker_effects({card})
    play_sound('card1', 0.8, 0.6)
    play_sound('generic1')
end

-- selling the Creator pays out (~1e100 via extra_value) but the Creator stays:
-- the flag makes the start_dissolve wrapper swallow only the sell flow's
-- dissolve, so the money lands and the card remains sellable again
local card_sell_card_ref = Card.sell_card
function Card:sell_card()
    local staying = cx_is_creator_card(self) or cx_is_entity_card(self)
    if cx_is_creator_card(self) then
        self.cx_sell_stay = true
    end
    local ret = card_sell_card_ref(self)
    if staying then
        -- sell_card strips the highlight buttons up front; this card survives
        -- the sale, so rebuild them once the sell events have settled
        G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.4, func = function()
            if not self.REMOVED and self.area == G.jokers and self.highlighted then
                self:highlight(true)
            end
            return true
        end}))
    end
    return ret
end

-- Create button on the Creator's highlight UI, above Sell (Buttercup pattern)
local cx_uasb_ref = G.UIDEF.use_and_sell_buttons
function G.UIDEF.use_and_sell_buttons(card)
    local retval = cx_uasb_ref(card)
    if cx_is_creator_card(card) and card.added_to_deck
        and retval and retval.nodes and retval.nodes[1] and retval.nodes[1].nodes then
        table.insert(retval.nodes[1].nodes, 1, {n = G.UIT.R, config = {align = "cl"}, nodes = {
            {n = G.UIT.C, config = {align = "cr"}, nodes = {
                {n = G.UIT.C, config = {ref_table = card, align = "cr", maxw = 1.25, padding = 0.1, r = 0.08, minw = 1.25, hover = true, shadow = true, colour = G.C.UI.BACKGROUND_INACTIVE, button = 'cx_creator_open', func = 'can_cx_create'}, nodes = {
                    {n = G.UIT.B, config = {w = 0.1, h = 0.6}},
                    {n = G.UIT.T, config = {text = 'Create', colour = G.C.UI.TEXT_LIGHT, scale = 0.4, shadow = true}}
                }}
            }}
        }})
    end
    return retval
end

-- split/swirl/reform shader for the tesseract soul: shard motion lives in the
-- shader (creator.fs) so the sprite stays a single frame; the colour treatment
-- is the Entity's glitch pipeline, sampled through the shard mapping
SMODS.Shader {
    key = 'creator',
    path = 'creator.fs',
    send_vars = function(sprite, card)
        return { cx_time = G.TIMERS.REAL }
    end
}

-- shimmering psychedelic treatment for the Creator's card base (counterpart
-- to the Entity's fractal shatter): hypno rings x spokes hue churn, glossy
-- sheens/glint, and a random whole-face negative flicker
SMODS.Shader {
    key = 'creator_base',
    path = 'creator_base.fs',
    send_vars = function(sprite, card)
        return { cx_time = G.TIMERS.REAL }
    end
}

local cx_creator_echo_colour = {1, 1, 1, 0.3}

-- deliberate contrast with the Entity's manic soul: slow weightless breathing,
-- no jitter — the drama is the shader's shard cycle, not the sprite's motion
local function cx_creator_soul_draw(card, scale_mod, rotate_mod)
    local fs = card.children.floating_sprite
    if not fs then return end
    local t = G.TIMERS.REAL
    local s = 0.08 + 0.03*math.sin(0.9*t)
    local r = 0.06*math.sin(0.55*t + 1.0)
    local send = card.ARGS and card.ARGS.send_to_shader

    -- no drop shadow on purpose: a static whole-cube shadow gives the shard
    -- cycle away (the shadow would sit intact while the pieces drift)

    -- two faint afterimages drifting on long, slow phases
    for i = 2, 1, -1 do
        local phase = 0.6*t + i*2.4
        cx_creator_echo_colour[4] = 0.30 - 0.10*i
        fs.drawing_colour = cx_creator_echo_colour
        fs:draw_shader('cx_creator', nil, send, nil, card.children.center,
            s + 0.02*i, r + 0.03*math.sin(0.5*phase),
            0.02*i*math.cos(phase), 0.015*i*math.sin(0.8*phase))
    end
    fs.drawing_colour = nil

    fs:draw_shader('cx_creator', nil, send, nil, card.children.center, s, r, 0, 0)
end

SMODS.Joker {
    key = 'creator',
    loc_txt = {
        name = 'The Creator',
        text = {
            '{C:color_rgb}Speak, and it is so{}',
            'Select this Joker and press {C:attention}Create{}',
            'to conjure {C:attention}any card{} into the run',
            '{C:inactive}Free of charge, forever{}'
        }
    },
    pos = {x = 0, y = 0},
    atlas = 'creator_float',
    soul_pos = {x = 1, y = 0, draw = cx_creator_soul_draw},
    set_card_type_badge = conceptual,
    no_doe = true,
    cost = 0,
    rarity = 1,
    unlocked = true,
    discovered = true,
    blueprint_compat = false,
    eternal_compat = false,
    cx_creator = true
}

----------------------------------------------
------------MOD CODE END----------------------
