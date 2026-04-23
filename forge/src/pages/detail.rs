use cosmic::iced::Length;
use cosmic::widget;
use cosmic::Element;

use crate::{Forge, Message, Page};

pub fn view<'a>(app: &'a Forge, app_id: &'a str) -> Element<'a, Message> {
    let mut col = widget::column::with_capacity(10).spacing(12).width(Length::Fill);

    col = col.push(
        widget::button::text("Back to Browse").on_press(Message::NavigateTo(Page::Browse)),
    );

    let detail = app.detail_info.as_ref();
    let catalog_entry = detail.or_else(|| app.catalog.iter().find(|a| a.app_id == app_id));
    let installed_entry = app.installed.iter().find(|a| a.app_id == app_id);

    let name = catalog_entry
        .map(|a| a.name.as_str())
        .or(installed_entry.map(|a| a.name.as_str()))
        .unwrap_or(app_id);

    col = col.push(widget::text::title2(name));
    col = col.push(widget::text::caption(app_id));

    if let Some(entry) = catalog_entry {
        if let Some(dev) = &entry.developer {
            col = col.push(widget::text::body(format!("Developer: {}", dev)));
        }
        if let Some(summary) = &entry.summary {
            col = col.push(widget::text::body(summary));
        }
        if let Some(ver) = &entry.version {
            col = col.push(widget::text::body(format!("Latest version: {}", ver)));
        }
    }

    if let Some(entry) = installed_entry {
        col = col.push(widget::text::body(format!(
            "Installed version: {}",
            entry.version
        )));
        col = col.push(widget::text::body(format!("Source: {}", entry.origin)));
    }

    if let Some(entry) = catalog_entry {
        if let Some(desc) = &entry.description {
            let clean = strip_html_tags(desc);
            if !clean.is_empty() {
                col = col.push(
                    widget::container(
                        widget::column::with_capacity(2)
                            .push(widget::text::title4("About"))
                            .push(widget::text::body(clean))
                            .spacing(6),
                    )
                    .padding(12)
                    .class(cosmic::theme::Container::Card),
                );
            }
        }
    }

    let categorized = categorize_permissions(&app.detail_permissions);

    let mut perms_col = widget::column::with_capacity(8)
        .push(widget::text::title4("Permissions"))
        .push(widget::text::body(
            "Stronk enforces strict sandboxing. Review what this app can access:",
        ))
        .spacing(6);

    if app.detail_permissions.is_empty() {
        perms_col = perms_col
            .push(permission_row(
                "Filesystem",
                "Sandboxed — no access to home or host. Files shared via portal only.",
            ))
            .push(permission_row(
                "Network",
                if catalog_entry
                    .and_then(|c| c.categories.as_ref())
                    .map(|cats| cats.iter().any(|c| c.name == "Network"))
                    .unwrap_or(false)
                {
                    "Allowed — app may connect to the internet"
                } else {
                    "Allowed — sandboxed apps may request network"
                },
            ))
            .push(permission_row(
                "Display",
                "Wayland only — no X11 screen capture",
            ))
            .push(permission_row(
                "Devices",
                "No direct device access. Portals mediate camera/microphone.",
            ));
    } else {
        for (label, entries) in &categorized {
            let summary: String = entries.join(", ");
            perms_col = perms_col.push(
                widget::row::with_capacity(2)
                    .push(widget::text::body(*label).width(Length::Fixed(100.0)))
                    .push(widget::text::caption(summary))
                    .spacing(8)
                    .align_y(cosmic::iced::Alignment::Start),
            );
        }
    }

    col = col.push(
        widget::container(perms_col)
            .padding(12)
            .class(cosmic::theme::Container::Card),
    );

    let is_installed = installed_entry.is_some();
    let mut actions = widget::row::with_capacity(2).spacing(8);

    if is_installed {
        actions = actions
            .push(
                widget::button::text("Update").on_press(Message::Update(app_id.to_string())),
            )
            .push(
                widget::button::destructive("Remove")
                    .on_press(Message::Uninstall(app_id.to_string())),
            );
    } else {
        actions = actions.push(
            widget::button::suggested("Install").on_press(Message::Install(app_id.to_string())),
        );
    }

    col = col.push(actions);

    col.into()
}

fn permission_row<'a>(label: &'a str, detail: &'a str) -> Element<'a, Message> {
    widget::row::with_capacity(2)
        .push(widget::text::body(label).width(Length::Fixed(100.0)))
        .push(widget::text::caption(detail))
        .spacing(8)
        .align_y(cosmic::iced::Alignment::Start)
        .into()
}

fn categorize_permissions(raw: &[String]) -> Vec<(&'static str, Vec<String>)> {
    let mut filesystem = Vec::new();
    let mut network = Vec::new();
    let mut display = Vec::new();
    let mut devices = Vec::new();
    let mut other = Vec::new();

    let mut current_section = "";

    for line in raw {
        let trimmed = line.trim();
        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            current_section = match trimmed {
                "[Context]" => "context",
                "[Session Bus Policy]" => "dbus",
                "[System Bus Policy]" => "dbus",
                "[Environment]" => "env",
                _ => "",
            };
            continue;
        }

        if trimmed.is_empty() {
            continue;
        }

        if current_section == "dbus" || current_section == "env" {
            other.push(trimmed.to_string());
            continue;
        }

        if trimmed.starts_with("filesystems=") || trimmed.starts_with("filesystem=") {
            filesystem.push(trimmed.to_string());
        } else if trimmed.starts_with("shared=") || trimmed.contains("network") {
            network.push(trimmed.to_string());
        } else if trimmed.starts_with("sockets=") {
            let parts = trimmed.trim_start_matches("sockets=");
            for socket in parts.split(';').filter(|s| !s.is_empty()) {
                match socket {
                    "wayland" | "x11" | "fallback-x11" => display.push(socket.to_string()),
                    "pulseaudio" => network.push("audio (PulseAudio)".to_string()),
                    _ => other.push(format!("socket: {}", socket)),
                }
            }
        } else if trimmed.starts_with("devices=") || trimmed.starts_with("device=") {
            devices.push(trimmed.to_string());
        } else {
            other.push(trimmed.to_string());
        }
    }

    let mut result = Vec::new();
    if !filesystem.is_empty() {
        result.push(("Filesystem", filesystem));
    }
    if !network.is_empty() {
        result.push(("Network", network));
    }
    if !display.is_empty() {
        result.push(("Display", display));
    }
    if !devices.is_empty() {
        result.push(("Devices", devices));
    }
    if !other.is_empty() {
        result.push(("Other", other));
    }
    result
}

fn strip_html_tags(html: &str) -> String {
    let mut result = String::with_capacity(html.len());
    let mut in_tag = false;
    for ch in html.chars() {
        match ch {
            '<' => in_tag = true,
            '>' => in_tag = false,
            _ if !in_tag => result.push(ch),
            _ => {}
        }
    }
    let lines: Vec<&str> = result.lines().map(|l| l.trim()).filter(|l| !l.is_empty()).collect();
    lines.join("\n")
}
