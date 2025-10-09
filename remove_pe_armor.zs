// CraftTweaker 1.20.1 (v14.x) 
import crafttweaker.api.item.IItemStack;

val targets as IItemStack[] = [
    // Dark Matter
    <item:projecte:dm_helmet>,
    <item:projecte:dm_chestplate>,
    <item:projecte:dm_leggings>,
    <item:projecte:dm_boots>,
    // Red Matter
    <item:projecte:rm_helmet>,
    <item:projecte:rm_chestplate>,
    <item:projecte:rm_leggings>,
    <item:projecte:rm_boots>,
    // Gem
    <item:projecte:gem_helmet>,
    <item:projecte:gem_chestplate>,
    <item:projecte:gem_leggings>,
    <item:projecte:gem_boots>
];

for target in targets {
    craftingTable.removeRecipeByOutput(target);
    recipes.removeByOutput(target);
}
