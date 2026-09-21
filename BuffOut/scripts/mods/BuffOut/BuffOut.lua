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

mod.on_game_state_changed = function(status, state_name)
    _last_combat_time = 0
    mod._combat_alpha = 1.0
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
            mod._combat_alpha = target_alpha
        else
            mod._combat_alpha = math.min(target_alpha, current_alpha + dt / in_duration)
        end
    elseif current_alpha > target_alpha then
        local out_duration = mod:get("fade_out_duration") or 1.0
        if out_duration <= 0 then
            mod._combat_alpha = target_alpha
        else
            mod._combat_alpha = math.max(target_alpha, current_alpha - dt / out_duration)
        end
    end
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

mod:hook("HudElementPlayerBuffs", "draw", function(func, self, dt, t, ui_renderer, render_settings, input_service)
    if not mod:is_enabled() then
        return func(self, dt, t, ui_renderer, render_settings, input_service)
    end

    local alpha = mod._combat_alpha or 1.0

    if alpha <= 0.001 then
        return
    end

    if alpha < 0.999 then
        if self.set_dirty then
            self:set_dirty()
        end
        local prev_alpha = render_settings.alpha_multiplier or 1.0
        render_settings.alpha_multiplier = prev_alpha * alpha
        func(self, dt, t, ui_renderer, render_settings, input_service)
        render_settings.alpha_multiplier = prev_alpha
        return
    end

    return func(self, dt, t, ui_renderer, render_settings, input_service)
end)

