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
				string = {'Joker', 'Conceptual', 'Joker', '???'},
				colours = {G.C.color_rgb},
				float = true,
				rotate = true,
				bump = true,
				shadow = true,
				offset_y = -0.05,
				silent = true,
				spacing = 1,
				pop_in_rate = 9,
				pop_delay = 0.7,
				scale = 0.33*scaling
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
    if self.edition and self.edition.cx_conceptual and not cx_is_conceptual_edition(edition) then
        return
    end
    return card_set_edition_ref(self, edition, immediate, silent, delay)
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
    if ok and overkill then
        local overkill_ok, already_overkill = pcall(cx_big_gte, G.GAME.chips, overkill)
        if not overkill_ok or not already_overkill then
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
    cx_enforce_conceptual_editions()
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
            local ok, value = pcall(function()
                return cx_to_big(chips):arrow(ALEPH_OPERATOR, cx_to_big(mult))
            end)
            if ok and value then
                return value
            end
            local exp_ok, exp_value = pcall(function()
                return cx_to_big(chips) ^ cx_to_big(mult)
            end)
            if exp_ok and exp_value then
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

local card_destroy_ref = Card.destroy
function Card:destroy(dissolve_colours, silent, dissolve_time_fac, no_juice)
    if cx_is_entity_card(self) then
        self.true_dissolve = nil
        self.ability.eternal = true
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
        self:set_eternal(true)
        self:set_edition({cx_conceptual = true}, true)
        cx_set_aleph_scoring()
        CX_ALEPH_WATCHDOG('entity_added')
    end
    return ret
end

local game_updateref = Game.update
function Game:update(dt)
    game_updateref(self, dt)
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
    key = 'entity_base',
    path = 'entity_base.fs',
    send_vars = function(sprite, card)
        return { cx_time = G.TIMERS.REAL }
    end
}

-- glitch overlay on the Entity's card base, layered above the edition shader (order 20)
-- and below the floating sprite (order 60)
SMODS.DrawStep {
    key = 'cx_entity_base',
    order = 25,
    func = function(self)
        if self.config.center.cx_entity and (self.config.center.discovered or self.bypass_discovery_center) then
            self.children.center:draw_shader('cx_entity_base', nil, self.ARGS.send_to_shader)
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
            self.children.back:draw_shader('cx_conceptual', nil, self.ARGS.send_to_shader, true)
            self.children.back:draw_shader('cx_entity_base', nil, self.ARGS.send_to_shader, true)
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
    cost = 1,
    rarity = 1,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,
    perishable_compat = false,
    immutable = true,
    immune_to_vermillion = true,
    cx_entity = true,
    atlas = 'entity_float',
    soul_pos = { x = 1, y = 0, draw = cx_entity_soul_draw },
    calculate = function(self, card, context)
        cx_mark_aleph_active('entity_calculate')
        cx_set_aleph_scoring()
        if G.GAME.blind and G.GAME.blind.name ~= '' then
            G.GAME.blind.triggered = true
            G.GAME.blind.disabled = true
            card:set_eternal(true)
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
            '{C:color_rgb,E:1}Conceptual{} cards cannot be {C:attention}Debuffed{}, {C:attention}Flipped{} or {C:attention}Destroyed{}',
            '{C:color_rgb,E:1}Conceptual{} cannot be removed or replaced by other {C:attention}Editions{}',
            '{C:attention}Selection Status{} of {C:color_rgb,E:1}Conceptual{} cards can only be affected by the player'
        }
    },
    discovered = true,
    unlocked = true,
    disable_base_shader = true,
	no_shadow = true,
    shader = 'conceptual',
	sound = {
		sound = 'cx_e_conceptual',
		per = 1,
		vol = 0.5
	},
    in_shop = true,
    weight = 0.5,
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

----------------------------------------------
------------MOD CODE END----------------------
