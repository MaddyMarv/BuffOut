local mod = get_mod("BuffOut")

local _last_combat_time = 0
mod._combat_alpha = 1.0

local BUFF_UPDATE_INTERVAL = 1.0 / 30.0

local SETTINGS = {
    out_of_combat_timeout = 5.0,
    fade_in_duration = 0.25,
    fade_out_duration = 1.0,
    out_of_combat_alpha = 0.0,
}

local function _load_settings()
    for key, default in pairs(SETTINGS) do
        local val = mod:get(key)
        if val ~= nil then
            SETTINGS[key] = val
        else
            SETTINGS[key] = default
        end
    end
end

mod.on_setting_changed = function(setting_id)
    if SETTINGS[setting_id] ~= nil then
        local val = mod:get(setting_id)
        if val ~= nil then
            SETTINGS[setting_id] = val
        end
    end
end

local function _get_gameplay_time()
    local time_manager = Managers.time
    if time_manager and time_manager:has_timer("gameplay") then
        return time_manager:time("gameplay")
    end
    return nil
end

local function _is_local_player(unit)
    if not unit then
        return false
    end
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player(1)
    return player and player.player_unit == unit
end

local function _is_in_combat()
    local current_time = _get_gameplay_time()
    if not current_time or _last_combat_time == 0 then
        return false
    end
    return (current_time - _last_combat_time) <= SETTINGS.out_of_combat_timeout
end

local function is_buff_bar(class_name)
    if type(class_name) ~= "string" then
        return false
    end
    return class_name == "HudElementPlayerBuffs" or string.sub(class_name, 1, 17) == "HudElementBuffBar"
end

local function _restore_element(element)
    if not element then
        return
    end
    element._buffout_hidden = nil
    element._buffout_needs_full_sync = nil
    element._buffout_update_elapsed = nil
    element._buffout_idle_elapsed = nil
    if element.set_dirty then
        element:set_dirty()
    end
end

local function _restore_hud_elements()
    local ui_manager = rawget(_G, "Managers") and Managers.ui
    local hud = ui_manager and ui_manager:get_hud()
    if hud and hud._elements then
        for class_name, element in pairs(hud._elements) do
            if is_buff_bar(class_name) then
                _restore_element(element)
            end
        end
    end
end

mod.on_game_state_changed = function(status, state_name)
    _last_combat_time = 0
    mod._combat_alpha = 1.0
end

mod.on_disabled = function()
    mod._combat_alpha = 1.0
    _restore_hud_elements()
end

mod.on_enabled = function()
    _load_settings()
    mod._combat_alpha = 1.0
    _restore_hud_elements()
end

mod.update = function(dt)
    if not mod:is_enabled() then
        mod._combat_alpha = 1.0
        return
    end

    local min_alpha = SETTINGS.out_of_combat_alpha or 0.0
    local target_alpha = _is_in_combat() and 1.0 or min_alpha
    local current_alpha = mod._combat_alpha or 1.0

    if current_alpha < target_alpha then
        local in_duration = SETTINGS.fade_in_duration or 0.25
        if in_duration <= 0 then
            current_alpha = target_alpha
        else
            current_alpha = math.min(target_alpha, current_alpha + dt / in_duration)
        end
    elseif current_alpha > target_alpha then
        local out_duration = SETTINGS.fade_out_duration or 1.0
        if out_duration <= 0 then
            current_alpha = target_alpha
        else
            current_alpha = math.max(target_alpha, current_alpha - dt / out_duration)
        end
    end

    mod._combat_alpha = current_alpha
end

local _in_buffout_draw = false
local function _draw_hook(func, self, dt, t, ui_renderer, render_settings, input_service)
    if not mod:is_enabled() or _in_buffout_draw then
        return func(self, dt, t, ui_renderer, render_settings, input_service)
    end

    _in_buffout_draw = true

    local alpha = mod._combat_alpha or 1.0

    if alpha <= 0.001 then
        if not self._buffout_hidden then
            if self._destroy_widgets and ui_renderer then
                self:_destroy_widgets(ui_renderer)
            end
            self._buffout_hidden = true
        end
        _in_buffout_draw = false
        return
    end

    if self._buffout_hidden then
        _restore_element(self)
    end

    if alpha >= 0.999 then
        local ret = func(self, dt, t, ui_renderer, render_settings, input_service)
        _in_buffout_draw = false
        return ret
    end

    local prev_alpha = render_settings.alpha_multiplier
    render_settings.alpha_multiplier = (prev_alpha or 1) * alpha
    if self.set_dirty then
        self:set_dirty()
    end
    local ret = func(self, dt, t, ui_renderer, render_settings, input_service)
    render_settings.alpha_multiplier = prev_alpha
    _in_buffout_draw = false
    return ret
end

local _in_buffout_update = false
local function _update_hook(func, self, dt, t, ui_renderer, render_settings, input_service)
    if not mod:is_enabled() or _in_buffout_update or not self._syncronized then
        return func(self, dt, t, ui_renderer, render_settings, input_service)
    end

    _in_buffout_update = true

    local alpha = mod._combat_alpha or 1.0
    local in_combat = _is_in_combat()

    if alpha <= 0.001 and not in_combat then
        self._buffout_needs_full_sync = true
        self._buffout_idle_elapsed = (self._buffout_idle_elapsed or 0) + dt

        if self._buffout_idle_elapsed >= 2.0 then
            local elapsed = self._buffout_idle_elapsed
            self._buffout_idle_elapsed = 0
            local ret = func(self, elapsed, t, ui_renderer, render_settings, input_service)
            _in_buffout_update = false
            return ret
        end

        local base_class = rawget(_G, "CLASS") and CLASS.HudElementBase
        if base_class and base_class.update then
            base_class.update(self, dt, t, ui_renderer, render_settings, input_service)
        end
        _in_buffout_update = false
        return
    end

    self._buffout_idle_elapsed = 0

    if self._buffout_needs_full_sync then
        self._buffout_needs_full_sync = nil
        self._buffout_update_elapsed = 0
        local ret = func(self, dt, t, ui_renderer, render_settings, input_service)
        if self._update_buff_alignments then
            self:_update_buff_alignments(true, dt)
        end
        _in_buffout_update = false
        return ret
    end

    local elapsed = (self._buffout_update_elapsed or 0) + dt
    if elapsed >= BUFF_UPDATE_INTERVAL then
        self._buffout_update_elapsed = 0
        local ret = func(self, elapsed, t, ui_renderer, render_settings, input_service)
        _in_buffout_update = false
        return ret
    else
        self._buffout_update_elapsed = elapsed
        local base_class = rawget(_G, "CLASS") and CLASS.HudElementBase
        if base_class and base_class.update then
            base_class.update(self, dt, t, ui_renderer, render_settings, input_service)
        end
        _in_buffout_update = false
        return
    end
end

local _elements_hooked = {}

local function _hook_element_class(class_name)
    if _elements_hooked[class_name] then
        return
    end
    local target_class = rawget(_G, class_name) or (rawget(_G, "CLASS") and CLASS[class_name])
    if target_class then
        mod:hook(target_class, "draw", _draw_hook)
        mod:hook(target_class, "update", _update_hook)
        _elements_hooked[class_name] = true
    end
end

local function _hook_all_buff_classes()
    _hook_element_class("HudElementPlayerBuffs")
    _hook_element_class("HudElementBuffBar")
end

_hook_all_buff_classes()

mod.on_all_mods_loaded = function()
    _hook_all_buff_classes()
end

mod:hook_safe("AttackReportManager", "add_attack_result", function(self, damage_profile, attacked_unit, attacking_unit)
    if _is_local_player(attacking_unit) or _is_local_player(attacked_unit) then
        local t = _get_gameplay_time()
        if t then
            _last_combat_time = t
        end
    end
end)

local _IGNORED_ACTION_KEYWORDS = {
    "sprint",
    "wield",
    "inspect",
    "scan",
    "luggable",
}

mod:hook_safe("ActionHandler", "start_action", function(self, id, action_objects, action_name)
    if _is_local_player(self._unit) then
        if not action_name then
            return
        end
        for i = 1, #_IGNORED_ACTION_KEYWORDS do
            if string.find(action_name, _IGNORED_ACTION_KEYWORDS[i]) then
                return
            end
        end
        local t = _get_gameplay_time()
        if t then
            _last_combat_time = t
        end
    end
end)

_load_settings()
