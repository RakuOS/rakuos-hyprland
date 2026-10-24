local animation = {
    name = "Default 2",
    icon = "󰇄",
    description = "Hyprland default animations with vertical workspace transitions."
}

if not hl then
    return animation
end

-- Keep Hyprland defaults for other animations and move workspace transitions vertically.
for _, leaf in ipairs({"workspaces", "workspacesIn", "workspacesOut", "specialWorkspace", "specialWorkspaceIn", "specialWorkspaceOut"}) do
    hl.animation({leaf = leaf, enabled = true, speed = 6, bezier = "default", style = "slidevert"})
end

return animation
