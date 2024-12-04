local ui = require("mod-gui")


local ID_BUTTON = "logistically-request-blueprint"
local JANITOR = "Janitor"
local TYPE_BLUEPRINT = "blueprint"
local TYPE_ITEM = "item"
local COMPARATOR = "="

local ERROR_CONFIG = {
	color = { 1, 0, 0, 1, },
	sound_path = "utility/cannot_build",
}
local ERROR_NO_BLUEPRINT = { "folk-janitor.no-blueprint", }
local ERROR_SECTION = { "folk-janitor.cant-add-section", }

---@param p LuaPlayer
local function clearSection(p)
	local log = p.character.get_logistic_sections()
	if not log or not log.valid then return end

	for i = log.sections_count, 1, -1 do
		if log.sections[i].valid and log.sections[i].group == JANITOR then
			-- We actually need to clear all the slots, believe it or not
			local s = log.sections[i]
			for j = s.filters_count, 1, -1 do
				s.clear_slot(j)
			end
			log.remove_section(i)
		end
	end
end

script.on_event(defines.events.on_gui_click, function(event)
	---@cast event OnGuiClick
	if not event or not event.element or event.element.name ~= ID_BUTTON then return end
	local p = game.players[event.player_index]
	if not p or not p.valid or not p.connected or p.spectator or not p.character then return end

	if event.button == defines.mouse_button_type.right then
		clearSection(p)
		return
	end

	if not p.is_cursor_blueprint() then
		p.print(ERROR_NO_BLUEPRINT, ERROR_CONFIG)
		return
	end

	---@type LuaItemStack|LuaRecord
	local cs = p.cursor_stack

	if not cs or not cs.valid then return end
	if not cs.is_blueprint and not cs.is_blueprint_book then
		cs = p.cursor_record
	end
	if not cs or not cs.valid or not cs.type then return end

	if cs.type ~= TYPE_BLUEPRINT then
		p.print(ERROR_NO_BLUEPRINT, ERROR_CONFIG)
		return
	end

	-- ZZZ this errors on blueprint books so check type first like above
	if not cs.is_blueprint_setup() then
		p.print(ERROR_NO_BLUEPRINT, ERROR_CONFIG)
		return
	end

	-- So here's the problem with books. There are two kinds: books from inventory and books from the library.
	-- p.cursor_stack.is_blueprint_book = true for inventory, false for library
	-- p.cursor_record is valid for library, invalid for inventory
	-- both _stack and _record .type == "blueprint-book"
	--
	-- _record has a field called https://lua-api.factorio.com/latest/classes/LuaRecord.html#contents
	--     from this field we can iterate all the blueprints in the book
	-- _stack has a field called https://lua-api.factorio.com/latest/classes/LuaItemCommon.html#active_index
	--     from this field we can determine which blueprint is the active one in a book
	--
	-- But that's the problem. _record doesn't have active_index, and _stack doesn't have .contents.
	-- So we can't really work with either of them.
	-- For _record (library books) we can't actually get the contents of any of the blueprints because
	-- we can't iterate them.
	-- And for _stack we can determine the active blueprint index, but not get the contents of that
	-- blueprint by index.

	local log = p.character.get_logistic_sections()
	if not log or not log.valid then return end

	local s = nil

	-- ZZZ we tried to just do |local s = log.add_section("Janitor")| but it creates a new section every time.
	for _, section in next, log.sections do
		if section.group == JANITOR then
			s = section
			break
		end
	end
	if not s then
		s = log.add_section(JANITOR)
	end
	if not s then
		p.print(ERROR_SECTION, ERROR_CONFIG)
		return
	end

	local multiplier = 1
	if event.shift then multiplier = 10 end

	local needs = {}
	-- First, build a hashmap of what we need. fekking quality shite
	for _, c in next, cs.cost_to_build do
		if not needs[c.name] then needs[c.name] = {} end
		if not needs[c.name][c.quality] then needs[c.name][c.quality] = 0 end
		needs[c.name][c.quality] = needs[c.name][c.quality] + (c.count * multiplier)
	end

	-- Look over the existing slots and see if we find one that matches
	for index, f in next, s.filters do
		if f and f.min and f.min > 0 and f.value and f.value.name then
			if needs[f.value.name] and needs[f.value.name][f.value.quality] then
				s.set_slot(index, {
					value = f.value,
					min = f.min + needs[f.value.name][f.value.quality],
				})
				needs[f.value.name][f.value.quality] = nil
				if table_size(needs[f.value.name]) == 0 then needs[f.value.name] = nil end
			end
		end
	end

	local slot = #s.filters + 1

	for need, qd in pairs(needs) do
		for q, count in pairs(qd) do
			s.set_slot(slot, {
				value = {
					type = TYPE_ITEM,
					name = need,
					comparator = COMPARATOR,
					quality = q,
				},
				min = count,
			})
			slot = slot + 1
		end
	end
end)

local function createButton()
	for _, p in pairs(game.players) do
		local flow = ui.get_button_flow(p)
		if not flow[ID_BUTTON] then
			flow.add {
				type = "sprite-button",
				name = ID_BUTTON,
				style = ui.button_style,
				sprite = "folk-janitor-thumbnail",
				tooltip = { "folk-janitor.button-tooltip", },
			}
		end
	end
end

script.on_configuration_changed(createButton)
script.on_event(defines.events.on_player_created, createButton)
script.on_event(defines.events.on_player_joined_game, createButton)
