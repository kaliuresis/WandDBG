dofile_once(base_dir .. "files/utils.lua");

cast_state_properties = {
    -- {name = "action_id", get = function(c) return c.action_id end, default = ""},
    -- {name = "action_name", get = function(c) return c.action_name end, default = ""},
    -- {name = "action_description", get = function(c) return c.action_description end, default = ""},
    -- {name = "action_sprite_filename", get = function(c) return c.action_sprite_filename end, default = ""},
    -- {name = "action_unidentified_sprite_filename", get = function(c) return c.action_unidentified_sprite_filename end, default = "data/ui_gfx/gun_actions/unidentified.png"},
    -- {name = "action_type", get = function(c) return c.action_type end, DEFAULT = ACTION_TYPE_PROJECTILE},
    -- {name = "action_spawn_level", get = function(c) return c.action_spawn_level end, default = ""},
    -- {name = "action_spawn_probability", get = function(c) return c.action_spawn_probability end, default = ""},
    -- {name = "action_spawn_requires_flag", get = function(c) return c.action_spawn_requires_flag end, default = ""},
    -- {name = "action_spawn_manual_unlock", get = function(c) return c.action_spawn_manual_unlock end, default = false},
    -- {name = "action_max_uses", get = function(c) return c.action_max_uses end, default = -1},
    {name = "custom_xml_file", get = function(c) return c.custom_xml_file end, default = ""},
    -- {name = "action_mana_drain", get = function(c) return c.action_mana_drain end, default = 10},
    -- {name = "action_is_dangerous_blast", get = function(c) return c.action_is_dangerous_blast end, default = false},
    -- {name = "action_draw_many_count", get = function(c) return c.action_draw_many_count end, default = 0},
    -- {name = "action_ai_never_uses", get = function(c) return c.action_ai_never_uses end, default = false},
    -- {name = "action_never_unlimited", get = function(c) return c.action_never_unlimited end, default = false},
    {name = "state_shuffled", get = function(c) return c.state_shuffled end, default = false},
    {name = "state_cards_drawn", get = function(c) return c.state_cards_drawn end, default = 0},
    {name = "state_discarded_action", get = function(c) return c.state_discarded_action end, default = false},
    {name = "state_destroyed_action", get = function(c) return c.state_destroyed_action end, default = false},
    {name = "fire_rate_wait", get = function(c) return c.fire_rate_wait end, default = 0},
    {name = "speed_multiplier", get = function(c) return c.speed_multiplier end, default = 1.0},
    {name = "child_speed_multiplier", get = function(c) return c.child_speed_multiplier end, default = 1.0},
    {name = "dampening", get = function(c) return c.dampening end, default = 1},
    {name = "explosion_radius", get = function(c) return c.explosion_radius end, default = 0},
    {name = "spread_degrees", get = function(c) return c.spread_degrees end, default = 0},
    {name = "pattern_degrees", get = function(c) return c.pattern_degrees end, default = 0},
    {name = "screenshake", get = function(c) return c.screenshake end, default = 0},
    {name = "recoil", get = function(c) return c.recoil end, default = 0},
    {name = "damage_melee_add", get = function(c) return c.damage_melee_add end, default = 0.0},
    {name = "damage_projectile_add", get = function(c) return c.damage_projectile_add end, default = 0.0},
    {name = "damage_electricity_add", get = function(c) return c.damage_electricity_add end, default = 0.0},
    {name = "damage_fire_add", get = function(c) return c.damage_fire_add end, default = 0.0},
    {name = "damage_explosion_add", get = function(c) return c.damage_explosion_add end, default = 0.0},
    {name = "damage_ice_add", get = function(c) return c.damage_ice_add end, default = 0.0},
    {name = "damage_slice_add", get = function(c) return c.damage_slice_add end, default = 0.0},
    {name = "damage_healing_add", get = function(c) return c.damage_healing_add end, default = 0.0},
    {name = "damage_curse_add", get = function(c) return c.damage_curse_add end, default = 0.0},
    {name = "damage_drill_add", get = function(c) return c.damage_drill_add end, default = 0.0},
    {name = "damage_critical_chance", get = function(c) return c.damage_critical_chance end, default = 0},
    {name = "damage_critical_multiplier", get = function(c) return c.damage_critical_multiplier end, default = 0.0},
    {name = "explosion_damage_to_materials", get = function(c) return c.explosion_damage_to_materials end, default = 0},
    {name = "knockback_force", get = function(c) return c.knockback_force end, default = 0},
    {name = "reload_time", get = function(c) return c.reload_time end, default = 0},
    {name = "lightning_count", get = function(c) return c.lightning_count end, default = 0},
    {name = "material", get = function(c) return c.material end, default = ""},
    {name = "material_amount", get = function(c) return c.material_amount end, default = 0},
    {name = "trail_material", get = function(c) return c.trail_material end, default = "", format=format_comma_list},
    {name = "trail_material_amount", get = function(c) return c.trail_material_amount end, default = 0},
    {name = "bounces", get = function(c) return c.bounces end, default = 0},
    {name = "gravity", get = function(c) return c.gravity end, default = 0},
    {name = "light", get = function(c) return c.light end, default = 0},
    {name = "blood_count_multiplier", get = function(c) return c.blood_count_multiplier end, default = 1.0},
    {name = "gore_particles", get = function(c) return c.gore_particles end, default = 0},
    {name = "ragdoll_fx", get = function(c) return c.ragdoll_fx end, default = 0},
    {name = "friendly_fire", get = function(c) return c.friendly_fire end, default = false},
    {name = "physics_impulse_coeff", get = function(c) return c.physics_impulse_coeff end, default = 0},
    {name = "lifetime_add", get = function(c) return c.lifetime_add end, default = 0},
    {name = "sprite", get = function(c) return c.sprite end, default = ""},
    {name = "extra_entities", get = function(c) return c.extra_entities end, default = "", format=format_cast_state_list},
    {name = "game_effect_entities", get = function(c) return c.game_effect_entities end, default = "", format=format_comma_list},
    {name = "sound_loop_tag", get = function(c) return c.sound_loop_tag end, default = ""},
    {name = "projectile_file", get = function(c) return c.projectile_file end, default = ""},
    -- {name = "projectiles", get = function(c) return c.projectiles end, default = "",
    --  format=make_format_comma_list_with_images(
    --      function(entity_filename)
    --          local action = projectile_table[entity_filename]
    --          if(action == nil) then
    --              return "data/ui_gfx/gun_actions/unidentified.png"
    --          end
    --          if(action.normal ~= nil) then
    --              return action.normal.sprite
    --          elseif(action.timer ~= nil) then
    --              return action.timer.sprite
    --          elseif(action.trigger ~= nil) then
    --              return action.trigger.sprite
    --          elseif(action.death_trigger ~= nil) then
    --              return action.death_trigger.sprite
    --          end
    --          return "data/ui_gfx/gun_actions/unidentified.png"
    --      end
    -- )},
}
