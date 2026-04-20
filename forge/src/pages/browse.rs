use cosmic::iced::Length;
use cosmic::widget;
use cosmic::Element;

use crate::flathub::CATEGORIES;
use crate::{Forge, Message, Page, SortOrder};

pub fn view<'a>(app: &'a Forge) -> Element<'a, Message> {
    let mut col = widget::column::with_capacity(6).spacing(12).width(Length::Fill);

    // Search bar
    let search = widget::row::with_capacity(2)
        .push(
            widget::text_input::text_input("Search apps...", &app.search_query)
                .on_input(Message::SearchChanged)
                .on_submit(|_| Message::SearchSubmit)
                .width(Length::Fill),
        )
        .push(widget::button::text("Search").on_press(Message::SearchSubmit))
        .spacing(8);
    col = col.push(search);

    // Categories
    let mut cats = widget::row::with_capacity(CATEGORIES.len()).spacing(4);
    for cat in CATEGORIES {
        cats = cats.push(
            widget::button::text(*cat).on_press(Message::CategorySelected(cat.to_string())),
        );
    }
    col = col.push(widget::scrollable(cats));

    // Sort and filter controls
    let sort_filter = widget::row::with_capacity(4)
        .push(widget::text::body("Sort:"))
        .push(
            widget::button::text("Default")
                .on_press(Message::SortChanged(SortOrder::Default)),
        )
        .push(
            widget::button::text("Name A→Z")
                .on_press(Message::SortChanged(SortOrder::NameAsc)),
        )
        .push(
            widget::button::text("Name Z→A")
                .on_press(Message::SortChanged(SortOrder::NameDesc)),
        )
        .push(
            widget::button::text(if app.hide_installed {
                "Show All"
            } else {
                "Hide Installed"
            })
            .on_press(Message::FilterInstalled(!app.hide_installed)),
        )
        .spacing(6)
        .align_y(cosmic::iced::Alignment::Center);
    col = col.push(sort_filter);

    if app.loading {
        col = col.push(widget::text::body("Loading..."));
        return col.into();
    }

    let mut sorted_catalog: Vec<&crate::flathub::AppInfo> = app.catalog.iter().collect();

    match app.sort_order {
        SortOrder::Default => {}
        SortOrder::NameAsc => sorted_catalog.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
        SortOrder::NameDesc => sorted_catalog.sort_by(|a, b| b.name.to_lowercase().cmp(&a.name.to_lowercase())),
    }

    if app.hide_installed {
        sorted_catalog.retain(|info| !app.installed.iter().any(|i| i.app_id == info.app_id));
    }

    // App grid
    let mut grid = widget::column::with_capacity(sorted_catalog.len()).spacing(8);
    for app_info in &sorted_catalog {
        let name = &app_info.name;
        let summary = app_info.summary.as_deref().unwrap_or("");
        let developer = app_info.developer.as_deref().unwrap_or("Unknown");

        let is_installed = app.installed.iter().any(|i| i.app_id == app_info.app_id);

        let action_btn = if is_installed {
            widget::button::text("Installed")
        } else {
            widget::button::suggested("Install")
                .on_press(Message::Install(app_info.app_id.clone()))
        };

        let card = widget::container(
            widget::row::with_capacity(3)
                .push(
                    widget::column::with_capacity(3)
                        .push(widget::text::title4(name))
                        .push(widget::text::body(developer))
                        .push(widget::text::caption(summary))
                        .spacing(4)
                        .width(Length::Fill),
                )
                .push(action_btn)
                .push(
                    widget::button::text("Details")
                        .on_press(Message::NavigateTo(Page::AppDetail(app_info.app_id.clone()))),
                )
                .spacing(8)
                .align_y(cosmic::iced::Alignment::Center),
        )
        .padding(12)
        .class(cosmic::theme::Container::Card);

        grid = grid.push(card);
    }

    col = col.push(widget::scrollable(grid));

    col.into()
}
