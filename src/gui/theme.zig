const std = @import("std");
const c = @import("../c.zig").c;

pub fn applyModernDarkTheme() void {
    const style = c.igGetStyle();
    if (style == null) return;

    // Window & frame geometry
    style.*.WindowRounding = 8.0;
    style.*.ChildRounding = 6.0;
    style.*.FrameRounding = 5.0;
    style.*.PopupRounding = 6.0;
    style.*.ScrollbarRounding = 8.0;
    style.*.GrabRounding = 5.0;
    style.*.TabRounding = 5.0;

    style.*.WindowBorderSize = 1.0;
    style.*.ChildBorderSize = 1.0;
    style.*.FrameBorderSize = 0.0;
    style.*.PopupBorderSize = 1.0;
    style.*.TabBorderSize = 0.0;

    // Spacing
    style.*.WindowPadding = c.ImVec2{ .x = 12.0, .y = 12.0 };
    style.*.FramePadding = c.ImVec2{ .x = 10.0, .y = 6.0 };
    style.*.ItemSpacing = c.ImVec2{ .x = 8.0, .y = 8.0 };
    style.*.ItemInnerSpacing = c.ImVec2{ .x = 6.0, .y = 4.0 };
    style.*.ScrollbarSize = 13.0;
    style.*.GrabMinSize = 12.0;

    const colors = &style.*.Colors;

    // High quality modern dark slate palette
    colors[c.ImGuiCol_Text] = c.ImVec4{ .x = 0.94, .y = 0.95, .z = 0.97, .w = 1.00 };
    colors[c.ImGuiCol_TextDisabled] = c.ImVec4{ .x = 0.50, .y = 0.54, .z = 0.60, .w = 1.00 };
    colors[c.ImGuiCol_WindowBg] = c.ImVec4{ .x = 0.08, .y = 0.09, .z = 0.11, .w = 1.00 };
    colors[c.ImGuiCol_ChildBg] = c.ImVec4{ .x = 0.11, .y = 0.12, .z = 0.15, .w = 1.00 };
    colors[c.ImGuiCol_PopupBg] = c.ImVec4{ .x = 0.12, .y = 0.13, .z = 0.17, .w = 0.98 };
    colors[c.ImGuiCol_Border] = c.ImVec4{ .x = 0.20, .y = 0.22, .z = 0.27, .w = 0.75 };
    colors[c.ImGuiCol_BorderShadow] = c.ImVec4{ .x = 0.00, .y = 0.00, .z = 0.00, .w = 0.00 };

    // Frames & inputs
    colors[c.ImGuiCol_FrameBg] = c.ImVec4{ .x = 0.15, .y = 0.17, .z = 0.21, .w = 1.00 };
    colors[c.ImGuiCol_FrameBgHovered] = c.ImVec4{ .x = 0.20, .y = 0.23, .z = 0.29, .w = 1.00 };
    colors[c.ImGuiCol_FrameBgActive] = c.ImVec4{ .x = 0.24, .y = 0.28, .z = 0.35, .w = 1.00 };

    // Title & Menus
    colors[c.ImGuiCol_TitleBg] = c.ImVec4{ .x = 0.07, .y = 0.08, .z = 0.10, .w = 1.00 };
    colors[c.ImGuiCol_TitleBgActive] = c.ImVec4{ .x = 0.09, .y = 0.11, .z = 0.14, .w = 1.00 };
    colors[c.ImGuiCol_TitleBgCollapsed] = c.ImVec4{ .x = 0.07, .y = 0.08, .z = 0.10, .w = 0.75 };
    colors[c.ImGuiCol_MenuBarBg] = c.ImVec4{ .x = 0.10, .y = 0.11, .z = 0.14, .w = 1.00 };

    // Buttons
    colors[c.ImGuiCol_Button] = c.ImVec4{ .x = 0.16, .y = 0.36, .z = 0.75, .w = 0.90 };
    colors[c.ImGuiCol_ButtonHovered] = c.ImVec4{ .x = 0.22, .y = 0.46, .z = 0.90, .w = 1.00 };
    colors[c.ImGuiCol_ButtonActive] = c.ImVec4{ .x = 0.13, .y = 0.30, .z = 0.65, .w = 1.00 };

    // Headers & Selectable
    colors[c.ImGuiCol_Header] = c.ImVec4{ .x = 0.18, .y = 0.22, .z = 0.29, .w = 0.85 };
    colors[c.ImGuiCol_HeaderHovered] = c.ImVec4{ .x = 0.24, .y = 0.30, .z = 0.40, .w = 1.00 };
    colors[c.ImGuiCol_HeaderActive] = c.ImVec4{ .x = 0.28, .y = 0.36, .z = 0.48, .w = 1.00 };

    // Tabs
    colors[c.ImGuiCol_Tab] = c.ImVec4{ .x = 0.12, .y = 0.14, .z = 0.18, .w = 1.00 };
    colors[c.ImGuiCol_TabHovered] = c.ImVec4{ .x = 0.22, .y = 0.32, .z = 0.52, .w = 0.90 };
    colors[c.ImGuiCol_TabSelected] = c.ImVec4{ .x = 0.16, .y = 0.34, .z = 0.68, .w = 1.00 };

    // Sliders & Grabs
    colors[c.ImGuiCol_SliderGrab] = c.ImVec4{ .x = 0.32, .y = 0.58, .z = 0.98, .w = 1.00 };
    colors[c.ImGuiCol_SliderGrabActive] = c.ImVec4{ .x = 0.45, .y = 0.70, .z = 1.00, .w = 1.00 };
    colors[c.ImGuiCol_CheckMark] = c.ImVec4{ .x = 0.35, .y = 0.75, .z = 1.00, .w = 1.00 };

    // Tables & Separators
    colors[c.ImGuiCol_Separator] = c.ImVec4{ .x = 0.20, .y = 0.22, .z = 0.27, .w = 0.75 };
    colors[c.ImGuiCol_TableHeaderBg] = c.ImVec4{ .x = 0.13, .y = 0.15, .z = 0.19, .w = 1.00 };
    colors[c.ImGuiCol_TableBorderStrong] = c.ImVec4{ .x = 0.22, .y = 0.25, .z = 0.31, .w = 1.00 };
    colors[c.ImGuiCol_TableBorderLight] = c.ImVec4{ .x = 0.16, .y = 0.18, .z = 0.23, .w = 0.60 };
}
