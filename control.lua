-- So, as of 0.15.3, events are triggered in this order:
-- tick 0: on_player_cursor_stack_changed
-- tick 1: on_player_main_inventory_changed/on_player_quickbar_inventory_changed
--
-- This is the case both if the player picks up a blueprint(-book) from the
-- library, or inventory. Regardless, they fire in this sequence.
--
-- Events trigger instantly after you close the library GUI, if open.
--
-- I was investigating this because I was hoping that when you picked
-- up a blueprint(book) from the library, the sequence would be different, in
-- that inventory_changed would NOT fire. After all, the item is still in your
-- hand, not the inventory.
--
--
-- And the reason I was checking this out at all was that I wanted to find a way to
-- detect when a player picked up an item from the library.
--
-- And I wanted to do that, because I would then do a few things:
-- 1. Instantly remove all copies of that blueprint(book) from the players inventory
-- 2. When the blueprint(book) was used and entered the players inventory, remove that, too.
--
-- This way, your inventory would be clean 24/7, and you could simply use the BP library.
-- Which, frankly, is much easier than ravaging through the inventory. At least for me.
--
-- But, I can't. Because of the above.
-- So instead, whenever you pick up a blueprint(book) from anywhere, any of the same type
-- with the same label in your main inventory are instantly destroyed.
--

local function wipe(inv, locate)
	-- we could check inventory.is_empty, but srsly how often is that going to be the case
	local count = inv.get_item_count(locate.name)
	if not count or count == 0 then return end
	-- count is the number of items in the inventory, so not including the one held in the cursor
	for i = 1, #inv do
		local it = inv[i]
		if it and it.valid_for_read and it.name == locate.name and type(it.label) == "string" and it.label == locate.label then
			it.clear()
		end
	end
end
local function cursor(event)
	if not event or not event.player_index then return end
	local locate = game.players[event.player_index].cursor_stack
	if not locate or not locate.valid_for_read then return end
	if type(locate.label) == "string" and (locate.type == "blueprint" or locate.type == "blueprint-book") then
		local inv = game.players[event.player_index].get_inventory(defines.inventory.player_main)
		if inv and inv.valid then wipe(inv, locate) end
		--inv = game.players[event.player_index].get_inventory(defines.inventory.player_quickbar)
		--if inv and inv.valid then wipe(inv, locate) end
	end
end
script.on_event(defines.events.on_player_cursor_stack_changed, cursor)


-- player.opened_gui_type == defines.gui_type.blueprint_library or nil
-- player.opened = defines.gui_type.blueprint_library opens the library
