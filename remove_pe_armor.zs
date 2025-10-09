// remove_pe_armor.zs
val ids = [
  // Dark Matter
  "projecte:dm_helmet",
  "projecte:dm_chestplate",
  "projecte:dm_leggings",
  "projecte:dm_boots",
  // Red Matter
  "projecte:rm_helmet",
  "projecte:rm_chestplate",
  "projecte:rm_leggings",
  "projecte:rm_boots",
  // Gem
  "projecte:gem_helmet",
  "projecte:gem_chestplate",
  "projecte:gem_leggings",
  "projecte:gem_boots"
];

for id in ids {
  try {
    recipes.remove(<${id}>);
  } catch (any) {}
}
