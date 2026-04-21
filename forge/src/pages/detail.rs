use cosmic::iced::Length;
use cosmic::widget;
use cosmic::Element;

use crate::{Forge, Message, Page};

pub fn view<'a>(app: &'a Forge, app_id: &'a str) -> Element<'a, Message> {
    let mut col = widget::column::with_capacity(8).spacing(12).width(Length::Fill);

    col = col.push(
        widget::button::text("Back to Browse").on_press(Message::NavigateTo(Page::Browse)),
    );

    let catalog_entry = app.catalog.iter().find(|a| a.app_id == app_id);
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
    }

    if let Some(entry) = installed_entry {
        col = col.push(widget::text::body(format!("Version: {}", entry.version)));
        col = col.push(widget::text::body(format!("Source: {}", entry.origin)));
    }

    // Permissions — shown prominently BEFORE install action
    col = col.push(
        widget::container(
            widget::column::with_capacity(6)
                .push(widget::text::title4("Permissions"))
                .push(widget::text::body(
                    "Stronk enforces strict sandboxing. Review what this app can access:",
                ))
                .push(permission_row("Filesystem", "Sandboxed — no access to home or host. Files shared via portal only."))
                .push(permission_row("Network", if catalog_entry.map(|c| c.categories.as_ref().map(|cats| cats.iter().any(|c| c.name == "Network")).unwrap_or(false)).unwrap_or(false) { "Allowed — app may connect to the internet" } else { "Allowed — sandboxed apps may request network" }))
                .push(permission_row("Display", "Wayland only — no X11 screen capture"))
                .push(permission_row("Devices", "No direct device access. Portals mediate camera/microphone."))
                .spacing(6),
        )
        .padding(12)
        .class(cosmic::theme::Container::Card),
    );

    // Actions — placed after permissions so user reviews before installing
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
        .push(
            widget::text::body(label)
                .width(Length::Fixed(100.0)),
        )
        .push(widget::text::caption(detail))
        .spacing(8)
        .align_y(cosmic::iced::Alignment::Start)
        .into()
}
