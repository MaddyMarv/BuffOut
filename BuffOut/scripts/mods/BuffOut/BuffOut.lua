local mod = get_mod("BuffOut")

local _last_combat_time = 0
mod._combat_alpha = 1.0

local function _get_gameplay_time()
    if Managers.time and Managers.time:has_timer("gameplay") then
        return Managers.time:time("gameplay")
    end
    return nil
end

local function _is_local_player(unit)
    if not unit then
        return false
    end
    local player = Managers.player and Managers.player:local_player(1)
    return player and player.player_unit == unit
end

local function _is_in_combat()
    local current_time = _get_gameplay_time()
    if not current_time or _last_combat_time == 0 then
        return false
    end

    local timeout = mod:get("out_of_combat_timeout") or 5.0
    return (current_time - _last_combat_time) <= timeout
end

local function is_buff_bar(class_name)
    if type(class_name) ~= "string" then
        return false
    end
    return string.find(class_name, "^HudElementBuffBar") ~= nil or class_name == "HudElementPlayerBuffs"
end

local function _restore_element(element)
    if not element then
        return
    end
    element._buffout_hidden = nil
    if element._widgets then
        for _, w in pairs(element._widgets) do
            w.alpha_multiplier = 1.0
            if w.content then
                w.content.visible = true
            end
            if w.style then
                for _, s in pairs(w.style) do
                    if type(s) == "table" and s.color then
                        s.color[1] = 255
                    end
                end
            end
        end
    end
    if element._widgets_by_name then
        for _, w in pairs(element._widgets_by_name) do
            w.alpha_multiplier = 1.0
            if w.content then
                w.content.visible = true
            end
            if w.style then
                for _, s in pairs(w.style) do
                    if type(s) == "table" and s.color then
                        s.color[1] = 255
                    end
                end
            end
        end
    end
    if element.set_dirty then
        element:set_dirty()
    end
end

mod.on_game_state_changed = function(status, state_name)
    _last_combat_time = 0
    mod._combat_alpha = 1.0
end

mod.on_disabled = function()
    mod._combat_alpha = 1.0
    local ui_manager = rawget(_G, "Managers") and Managers.ui
    local hud = ui_manager and ui_manager:get_hud()
    if hud and hud._elements then
        for class_name, _ in pairs(hud._elements) do
            if is_buff_bar(class_name) then
                _restore_element(hud:element(class_name))
            end
        end
    end
end

mod.on_enabled = function()
    mod._combat_alpha = 1.0
    local ui_manager = rawget(_G, "Managers") and Managers.ui
    local hud = ui_manager and ui_manager:get_hud()
    if hud and hud._elements then
        for class_name, _ in pairs(hud._elements) do
            if is_buff_bar(class_name) then
                _restore_element(hud:element(class_name))
            end
        end
    end
end

mod.update = function(dt)
    if not mod:is_enabled() then
        mod._combat_alpha = 1.0
        return
    end

    local min_alpha = mod:get("out_of_combat_alpha") or 0.0
    local target_alpha = _is_in_combat() and 1.0 or min_alpha
    local current_alpha = mod._combat_alpha or 1.0

    if current_alpha < target_alpha then
        local in_duration = mod:get("fade_in_duration") or 0.25
        if in_duration <= 0 then
            current_alpha = target_alpha
        else
            current_alpha = math.min(target_alpha, current_alpha + dt / in_duration)
        end
    elseif current_alpha > target_alpha then
        local out_duration = mod:get("fade_out_duration") or 1.0
        if out_duration <= 0 then
            current_alpha = target_alpha
        else
            current_alpha = math.max(target_alpha, current_alpha - dt / out_duration)
        end
    end

    mod._combat_alpha = current_alpha
end

local function _draw_hook(func, self, dt, t, ui_renderer, render_settings, input_service)
    if not mod:is_enabled() then
        return func(self, dt, t, ui_renderer, render_settings, input_service)
    end

    local alpha = mod._combat_alpha or 1.0
    if alpha <= 0.001 then
        if not self._buffout_hidden then
            if self._destroy_widgets and ui_renderer then
                self:_destroy_widgets(ui_renderer)
            end
            self._buffout_hidden = true
        end
        return
    end

    if self._buffout_hidden then
        _restore_element(self)
    end

    if alpha >= 0.999 then
        return func(self, dt, t, ui_renderer, render_settings, input_service)
    end

    local prev_alpha = render_settings.alpha_multiplier
    render_settings.alpha_multiplier = (prev_alpha or 1) * alpha
    if self.set_dirty then
        self:set_dirty()
    end
    func(self, dt, t, ui_renderer, render_settings, input_service)
    render_settings.alpha_multiplier = prev_alpha
end

mod:hook("HudElementPlayerBuffs", "draw", _draw_hook)

local _bbm_hooked = false
local function _hook_bbm()
    if _bbm_hooked then
        return
    end
    local HudElementBuffBar = rawget(_G, "HudElementBuffBar")
    if HudElementBuffBar then
        mod:hook(HudElementBuffBar, "draw", _draw_hook)
        _bbm_hooked = true
    end
end

_hook_bbm()

mod:hook("HudElementBase", "draw", function(func, self, dt, t, ui_renderer, render_settings, input_service)
    if is_buff_bar(self.__class_name) then
        return _draw_hook(func, self, dt, t, ui_renderer, render_settings, input_service)
    end
    return func(self, dt, t, ui_renderer, render_settings, input_service)
end)

mod.on_all_mods_loaded = function()
    _hook_bbm()
end

mod:hook_safe("AttackReportManager", "add_attack_result", function(self, damage_profile, attacked_unit, attacking_unit)
    if _is_local_player(attacking_unit) or _is_local_player(attacked_unit) then
        local t = _get_gameplay_time()
        if t then
            _last_combat_time = t
        end
    end
end)

mod:hook_safe("ActionHandler", "start_action", function(self, id, action_objects, action_name)
    if _is_local_player(self._unit) then
        if not action_name
            or string.find(action_name, "sprint")
            or string.find(action_name, "wield")
            or string.find(action_name, "inspect")
            or string.find(action_name, "scan")
            or string.find(action_name, "luggable")
        then
            return
        end
        local t = _get_gameplay_time()
        if t then
            _last_combat_time = t
        end
    end
end)
