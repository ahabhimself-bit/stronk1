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
        let card = widget::container(
            widget::row::with_capacity(4)
                .push(
                    widget::column::with_capacity(2)
                        .push(widget::text::title4(&installed.name))
                        .push(widget::text::caption(format!(
                            "{} v{}",
                            installed.app_id, installed.version
                        )))
                        .spacing(4)
                        .width(Length::Fill),
                )
                .push(
                    widget::button::text("Update")
                        .on_press(Message::Update(installed.app_id.clone())),
                )
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
