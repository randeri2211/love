-- Every block is also an item with the same name, so anything mined can be carried(and placed later)
-- Runs after the blocks folder registers(see registerAll), blocks added by mods get their item the same way
for name, block in pairs(BLOCK_REGISTRY) do
    if ITEM_REGISTRY[name] == nil then
        registerItem(name, {block = name})
    end
end
