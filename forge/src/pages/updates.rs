use cosmic::iced::Length;
use cosmic::widget;
use cosmic::Element;

use crate::{Forge, Message, Page};

pub fn view<'a>(app: &'a Forge) -> Element<'a, Message> {
    let mut col = widget::column::with_capacity(3 + app.pending_updates.len())
        .spacing(12)
        .width(Length::Fill);

    col = col.push(widget::text::title3("Available Updates"));

    if app.pending_updates.is_empty() {
        col = col.push(widget::text::body("All apps are up to date."));
        col = col.push(
            widget::button::text("Check for Updates").on_press(Message::CheckUpdates),
        );
        return col.into();
    }

    let header = widget::row::with_capacity(2)
        .push(widget::text::body(format!(
            "{} update{} available",
            app.pending_updates.len(),
            if app.pending_updates.len() == 1 { "" } else { "s" }
        )))
        .push(
            widget::button::suggested("Update All").on_press(Message::UpdateAll),
        )
        .spacing(12)
        .align_y(cosmic::iced::Alignment::Center);
    col = col.push(header);

    for update in &app.pending_updates {
        let current_version = app
            .installed
            .iter()
            .find(|a| a.app_id == update.app_id)
            .map(|a| a.version.as_str())
            .unwrap_or("?");

        let card = widget::container(
            widget::row::with_capacity(3)
                .push(
                    widget::column::with_capacity(2)
                        .push(widget::text::title4(&update.name))
                        .push(widget::text::caption(format!(
                            "{} → {}",
                            current_version, update.remote_version
                        )))
                        .spacing(4)
                        .width(Length::Fill),
                )
                .push(
                    widget::button::suggested("Update")
                        .on_press(Message::Update(update.app_id.clone())),
                )
                .push(
                    widget::button::text("Details").on_press(Message::NavigateTo(
                        Page::AppDetail(update.app_id.clone()),
                    )),
                )
                .spacing(8)
                .align_y(cosmic::iced::Alignment::Center),
        )
        .padding(12)
        .class(cosmic::theme::Container::Card);

        col = col.push(card);
    }

    col = col.push(
        widget::button::text("Check for Updates").on_press(Message::CheckUpdates),
    );

    widget::scrollable(col).into()
}
