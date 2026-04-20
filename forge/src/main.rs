mod flatpak;
mod flathub;
mod pages;

use cosmic::app::{Core, Settings, Task};
use cosmic::iced::Length;
use cosmic::widget;
use cosmic::{Application, Element};

use flatpak::InstalledApp;
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
    AppDetail(String),
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
    CategorySelected(String),
}

pub struct Forge {
    core: Core,
    page: Page,
    search_query: String,
    catalog: Vec<AppInfo>,
    installed: Vec<InstalledApp>,
    loading: bool,
    status_message: Option<String>,
    selected_category: Option<String>,
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
            loading: true,
            status_message: None,
            selected_category: None,
        };

        let cmd = cosmic::task::batch::<Message, _>(vec![
            cosmic::task::future(async { Message::CatalogLoaded(flathub::fetch_popular().await) }),
            cosmic::task::future(async {
                Message::InstalledLoaded(flatpak::list_installed().await)
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
                cosmic::task::future(async {
                    Message::InstalledLoaded(flatpak::list_installed().await)
                })
            }

            Message::UninstallComplete(result) => {
                match result {
                    Ok(name) => self.status_message = Some(format!("Removed {}", name)),
                    Err(e) => self.status_message = Some(e),
                }
                cosmic::task::future(async {
                    Message::InstalledLoaded(flatpak::list_installed().await)
                })
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
            Page::AppDetail(app_id) => pages::detail::view(self, app_id),
        };

        let nav = widget::row::with_capacity(3)
            .push(
                widget::button::text("Browse").on_press(Message::NavigateTo(Page::Browse)),
            )
            .push(
                widget::button::text("Installed")
                    .on_press(Message::NavigateTo(Page::Installed)),
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
