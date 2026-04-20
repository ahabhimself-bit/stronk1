use cosmic::iced::Length;
use cosmic::widget;
use cosmic::Element;

use crate::{Forge, Message, Page};

pub fn view<'a>(app: &'a Forge) -> Element<'a, Message> {
    let mut col = widget::column::with_capacity(2 + app.installed.len())
        .spacing(12)
        .width(Length::Fill);

    col = col.push(widget::text::title3("Installed Apps"));

    if app.installed.is_empty() {
        col = col.push(widget::text::body(
            "No Flatpak apps installed yet. Browse The Forge to find apps.",
        ));
        return col.into();
    }

    for installed in &app.installed {
        let has_update = app
            .pending_updates
            .iter()
            .any(|u| u.app_id == installed.app_id);

        let version_text = if has_update {
            let new_ver = app
                .pending_updates
                .iter()
                .find(|u| u.app_id == installed.app_id)
                .map(|u| u.remote_version.as_str())
                .unwrap_or("?");
            format!("{} v{} → {}", installed.app_id, installed.version, new_ver)
        } else {
            format!("{} v{}", installed.app_id, installed.version)
        };

        let mut info_col = widget::column::with_capacity(3)
            .push(widget::text::title4(&installed.name))
            .push(widget::text::caption(version_text))
            .spacing(4)
            .width(Length::Fill);

        if has_update {
            info_col = info_col.push(widget::text::caption("Update available"));
        }

        let update_btn = if has_update {
            widget::button::suggested("Update")
                .on_press(Message::Update(installed.app_id.clone()))
        } else {
            widget::button::text("Update")
                .on_press(Message::Update(installed.app_id.clone()))
        };

        let card = widget::container(
            widget::row::with_capacity(4)
                .push(info_col)
                .push(update_btn)
                .push(
                    widget::button::destructive("Remove")
                        .on_press(Message::Uninstall(installed.app_id.clone())),
                )
                .push(
                    widget::button::text("Details").on_press(Message::NavigateTo(
                        Page::AppDetail(installed.app_id.clone()),
                    )),
                )
                .spacing(8)
                .align_y(cosmic::iced::Alignment::Center),
        )
        .padding(12)
        .class(cosmic::theme::Container::Card);

        col = col.push(card);
    }

    widget::scrollable(col).into()
}
