-- Every block is also an item with the same name, so anything mined can be carried(and placed later)
-- Runs after the blocks folder registers(see registerAll), blocks added by mods get their item the same way
-- Blocks marked noItem(trees and plants) cant be placed, they drop materials instead
for name, block in pairs(BLOCK_REGISTRY) do
    if ITEM_REGISTRY[name] == nil and not block.noItem and not rawget(block, "abstract") then
        registerItem(name, {block = name})
    end
end
