mod flatpak;
mod flathub;
mod pages;

use cosmic::app::{Core, Settings, Task};
use cosmic::iced::Length;
use cosmic::widget;
use cosmic::{Application, Element};

use flatpak::{InstalledApp, UpdateInfo};
use flathub::AppInfo;

fn main() -> cosmic::iced::Result {
    let settings = Settings::default()
        .size_limits(cosmic::iced::Limits::NONE.min_width(600.0).min_height(400.0));
    cosmic::app::run::<Forge>(settings, ())
}

#[derive(Debug, Clone)]
pub enum Page {
    Browse,
    Installed,
    Updates,
    AppDetail(String),
}

#[derive(Debug, Clone, PartialEq)]
pub enum SortOrder {
    Default,
    NameAsc,
    NameDesc,
}

#[derive(Debug, Clone)]
pub enum Message {
    NavigateTo(Page),
    SearchChanged(String),
    SearchSubmit,
    Install(String),
    Uninstall(String),
    Update(String),
    CatalogLoaded(Result<Vec<AppInfo>, String>),
    InstalledLoaded(Result<Vec<InstalledApp>, String>),
    InstallComplete(Result<String, String>),
    UninstallComplete(Result<String, String>),
    UpdateComplete(Result<String, String>),
    CheckUpdates,
    UpdatesChecked(Result<Vec<UpdateInfo>, String>),
    UpdateAll,
    UpdateAllComplete(Result<String, String>),
    CategorySelected(String),
    SortChanged(SortOrder),
    FilterInstalled(bool),
}

pub struct Forge {
    core: Core,
    page: Page,
    search_query: String,
    catalog: Vec<AppInfo>,
    installed: Vec<InstalledApp>,
    pub pending_updates: Vec<UpdateInfo>,
    loading: bool,
    status_message: Option<String>,
    selected_category: Option<String>,
    pub sort_order: SortOrder,
    pub hide_installed: bool,
}

impl Application for Forge {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;

    const APP_ID: &'static str = "com.stronk.forge";

    fn core(&self) -> &Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut Core {
        &mut self.core
    }

    fn init(core: Core, _flags: ()) -> (Self, Task<Message>) {
        let app = Forge {
            core,
            page: Page::Browse,
            search_query: String::new(),
            catalog: Vec::new(),
            installed: Vec::new(),
            pending_updates: Vec::new(),
            loading: true,
            status_message: None,
            selected_category: None,
            sort_order: SortOrder::Default,
            hide_installed: false,
        };

        let cmd = cosmic::task::batch::<Message, _>(vec![
            cosmic::task::future(async { Message::CatalogLoaded(flathub::fetch_popular().await) }),
            cosmic::task::future(async {
                Message::InstalledLoaded(flatpak::list_installed().await)
            }),
            cosmic::task::future(async {
                Message::UpdatesChecked(flatpak::check_updates().await)
            }),
        ]);

        (app, cmd)
    }

    fn header_start(&self) -> Vec<Element<'_, Message>> {
        vec![widget::nav_bar_toggle().into()]
    }

    fn nav_model(&self) -> Option<&widget::nav_bar::Model> {
        None
    }

    fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::NavigateTo(page) => {
                self.page = page;
                Task::none()
            }

            Message::SearchChanged(query) => {
                self.search_query = query;
                Task::none()
            }

            Message::SearchSubmit => {
                let query = self.search_query.clone();
                self.loading = true;
                cosmic::task::future(async move {
                    Message::CatalogLoaded(flathub::search(query).await)
                })
            }

            Message::Install(app_id) => {
                self.status_message = Some(format!("Installing {}...", app_id));
                cosmic::task::future(async move {
                    Message::InstallComplete(flatpak::install(app_id).await)
                })
            }

            Message::Uninstall(app_id) => {
                self.status_message = Some(format!("Removing {}...", app_id));
                cosmic::task::future(async move {
                    Message::UninstallComplete(flatpak::uninstall(app_id).await)
                })
            }

            Message::Update(app_id) => {
                self.status_message = Some(format!("Updating {}...", app_id));
                cosmic::task::future(async move {
                    Message::UpdateComplete(flatpak::update(app_id).await)
                })
            }

            Message::CatalogLoaded(result) => {
                self.loading = false;
                match result {
                    Ok(apps) => self.catalog = apps,
                    Err(e) => self.status_message = Some(format!("Failed to load catalog: {}", e)),
                }
                Task::none()
            }

            Message::InstalledLoaded(result) => {
                match result {
                    Ok(apps) => self.installed = apps,
                    Err(e) => {
                        self.status_message = Some(format!("Failed to list installed: {}", e))
                    }
                }
                Task::none()
            }

            Message::InstallComplete(result) | Message::UpdateComplete(result) => {
                match result {
                    Ok(name) => self.status_message = Some(format!("{} complete", name)),
                    Err(e) => self.status_message = Some(e),
                }
                cosmic::task::batch::<Message, _>(vec![
                    cosmic::task::future(async {
                        Message::InstalledLoaded(flatpak::list_installed().await)
                    }),
                    cosmic::task::future(async {
                        Message::UpdatesChecked(flatpak::check_updates().await)
                    }),
                ])
            }

            Message::UninstallComplete(result) => {
                match result {
                    Ok(name) => self.status_message = Some(format!("Removed {}", name)),
                    Err(e) => self.status_message = Some(e),
                }
                cosmic::task::batch::<Message, _>(vec![
                    cosmic::task::future(async {
                        Message::InstalledLoaded(flatpak::list_installed().await)
                    }),
                    cosmic::task::future(async {
                        Message::UpdatesChecked(flatpak::check_updates().await)
                    }),
                ])
            }

            Message::CheckUpdates => {
                self.status_message = Some("Checking for updates...".to_string());
                cosmic::task::future(async {
                    Message::UpdatesChecked(flatpak::check_updates().await)
                })
            }

            Message::UpdatesChecked(result) => {
                match result {
                    Ok(updates) => {
                        if !updates.is_empty() {
                            self.status_message = Some(format!(
                                "{} update{} available",
                                updates.len(),
                                if updates.len() == 1 { "" } else { "s" }
                            ));
                        }
                        self.pending_updates = updates;
                    }
                    Err(e) => {
                        self.status_message =
                            Some(format!("Failed to check updates: {}", e));
                    }
                }
                Task::none()
            }

            Message::UpdateAll => {
                self.status_message = Some("Updating all apps...".to_string());
                cosmic::task::future(async {
                    Message::UpdateAllComplete(flatpak::update_all().await)
                })
            }

            Message::UpdateAllComplete(result) => {
                match &result {
                    Ok(msg) => self.status_message = Some(msg.clone()),
                    Err(e) => self.status_message = Some(e.clone()),
                }
                self.pending_updates.clear();
                cosmic::task::batch::<Message, _>(vec![
                    cosmic::task::future(async {
                        Message::InstalledLoaded(flatpak::list_installed().await)
                    }),
                    cosmic::task::future(async {
                        Message::UpdatesChecked(flatpak::check_updates().await)
                    }),
                ])
            }

            Message::SortChanged(order) => {
                self.sort_order = order;
                Task::none()
            }

            Message::FilterInstalled(hide) => {
                self.hide_installed = hide;
                Task::none()
            }

            Message::CategorySelected(category) => {
                self.selected_category = Some(category.clone());
                self.loading = true;
                cosmic::task::future(async move {
                    Message::CatalogLoaded(flathub::fetch_category(category).await)
                })
            }
        }
    }

    fn view(&self) -> Element<'_, Message> {
        let content = match &self.page {
            Page::Browse => pages::browse::view(self),
            Page::Installed => pages::installed::view(self),
            Page::Updates => pages::updates::view(self),
            Page::AppDetail(app_id) => pages::detail::view(self, app_id),
        };

        let updates_label = if self.pending_updates.is_empty() {
            "Updates".to_string()
        } else {
            format!("Updates ({})", self.pending_updates.len())
        };

        let nav = widget::row::with_capacity(4)
            .push(
                widget::button::text("Browse").on_press(Message::NavigateTo(Page::Browse)),
            )
            .push(
                widget::button::text("Installed")
                    .on_press(Message::NavigateTo(Page::Installed)),
            )
            .push(
                widget::button::text(updates_label)
                    .on_press(Message::NavigateTo(Page::Updates)),
            )
            .spacing(8);

        let mut layout = widget::column::with_capacity(3)
            .push(nav)
            .push(content)
            .spacing(16)
            .padding(16)
            .width(Length::Fill);

        if let Some(msg) = &self.status_message {
            layout = layout.push(widget::text::body(msg));
        }

        layout.into()
    }
}
