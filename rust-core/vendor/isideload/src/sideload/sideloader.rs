use crate::{
    dev::{
        app_groups::AppGroupsApi,
        app_ids::AppIdsApi,
        developer_session::DeveloperSession,
        devices::DevicesApi,
        teams::{DeveloperTeam, TeamsApi},
    },
    sideload::{
        TeamSelection,
        application::{Application, SpecialApp},
        builder::MaxCertsBehavior,
        cert_identity::CertificateIdentity,
        sign,
    },
    util::{device::IdeviceInfo, storage::SideloadingStorage},
};

use std::path::PathBuf;

use futures_util::future::{try_join, try_join3, try_join_all};
use idevice::provider::IdeviceProvider;
use rootcause::{option_ext::OptionExt, prelude::*};
use tracing::info;

pub struct Sideloader {
    team_selection: TeamSelection,
    storage: Box<dyn SideloadingStorage>,
    dev_session: DeveloperSession,
    machine_name: String,
    apple_email: String,
    max_certs_behavior: MaxCertsBehavior,
    //extensions_behavior: ExtensionsBehavior,
    delete_app_after_install: bool,
    team: Option<DeveloperTeam>,
}

impl Sideloader {
    /// Construct a new `Sideloader` instance with the provided configuration
    ///
    /// See [`crate::sideload::SideloaderBuilder`] for more details and a more convenient way to construct a `Sideloader`.
    pub fn new(
        dev_session: DeveloperSession,
        apple_email: String,
        team_selection: TeamSelection,
        max_certs_behavior: MaxCertsBehavior,
        machine_name: String,
        storage: Box<dyn SideloadingStorage>,
        //extensions_behavior: ExtensionsBehavior,
        delete_app_after_install: bool,
    ) -> Self {
        Sideloader {
            team_selection,
            storage,
            dev_session,
            machine_name,
            apple_email,
            max_certs_behavior,
            //extensions_behavior,
            delete_app_after_install,
            team: None,
        }
    }

    /// Sign the app at the provided path and return the path to the signed app bundle (in a temp dir). To sign and install, see [`Self::install_app`].
    ///
    /// `register_device` is a device's (name, UDID) to register with the team
    /// first, since the provisioning profile only covers registered devices.
    pub async fn sign_app(
        &mut self,
        app_path: PathBuf,
        team: Option<DeveloperTeam>,
        // this will be replaced with proper entitlement handling later
        increased_memory_limit: bool,
        register_device: Option<(&str, &str)>,
    ) -> Result<(PathBuf, Option<SpecialApp>), Report> {
        let team = match team {
            Some(t) => t,
            None => self.get_team().await?,
        };

        // Requests that don't depend on each other go out together, each on its
        // own copy of the developer session. Anisette headers are fetched once
        // first, so every copy reuses them instead of asking the server again.
        self.dev_session
            .get_headers()
            .await
            .context("Failed to get anisette headers")?;
        let mut device_session = self.dev_session.clone();
        let mut cert_session = self.dev_session.clone();
        let mut app_id_session = self.dev_session.clone();
        let mut group_session = self.dev_session.clone();

        let registration = async {
            if let Some((name, udid)) = register_device
                && let Err(e) = device_session
                    .ensure_device_registered(&team, name, udid, None)
                    .await
            {
                bail!("device registration failed for UDID {udid}: {e}");
            }
            Ok::<(), Report>(())
        };

        let certificate = async {
            Ok::<_, Report>(
                CertificateIdentity::retrieve(
                    &self.machine_name,
                    &self.apple_email,
                    &mut cert_session,
                    &team,
                    self.storage.as_ref(),
                    &self.max_certs_behavior,
                )
                .await
                .context("Failed to retrieve certificate identity")?,
            )
        };

        // Extracting the archive is blocking work, so it runs off this task and
        // the requests above keep moving meanwhile.
        let bundle = async {
            let mut app = tokio::task::spawn_blocking(move || Application::new(app_path))
                .await
                .map_err(|e| report!("Failed to open application archive: {e}"))??;
            let special = app.get_special_app();

            let main_bundle_id = app.main_bundle_id()?;
            let main_app_name = app.main_app_name()?;
            let main_app_id_str = format!("{}.{}", main_bundle_id, team.team_id);
            app.update_bundle_id(&main_bundle_id, &main_app_id_str)?;

            let group_identifier = format!(
                "group.{}",
                if Some(SpecialApp::SideStoreLc) == special {
                    format!("com.SideStore.SideStore.{}", team.team_id)
                } else {
                    main_app_id_str.clone()
                }
            );

            let (mut app_ids, app_group) = try_join(
                app.register_app_ids(
                    /*&self.extensions_behavior, */ &mut app_id_session,
                    &team,
                ),
                group_session.ensure_app_group(&team, &main_app_name, &group_identifier, None),
            )
            .await?;

            let main_app_id = app_ids
                .iter()
                .find(|app_id| app_id.identifier == main_app_id_str)
                .cloned()
                .ok_or_else(|| {
                    report!(
                        "Main app ID {} not found in registered app IDs",
                        main_app_id_str
                    )
                })?;

            // Each App ID is configured on its own session, all at once.
            try_join_all(app_ids.iter_mut().map(|app_id| {
                let mut session = app_id_session.clone();
                let (team, app_group) = (&team, &app_group);
                async move {
                    app_id.ensure_group_feature(&mut session, team).await?;
                    session
                        .assign_app_group(team, app_group, app_id, None)
                        .await?;
                    if increased_memory_limit {
                        session.add_increased_memory_limit(team, app_id).await?;
                    }
                    Ok::<(), Report>(())
                }
            }))
            .await?;

            info!("App IDs configured");
            Ok::<_, Report>((app, special, group_identifier, main_app_id))
        };

        let ((), cert_identity, (mut app, special, group_identifier, main_app_id)) =
            try_join3(registration, certificate, bundle).await?;

        // The profile has to come after the device and App IDs are set up; the
        // certificate goes into the bundle meanwhile.
        let dev_session = &mut self.dev_session;
        let ((), provisioning_profile) = try_join(
            async {
                app.apply_special_app_behavior(&special, &group_identifier, &cert_identity)
                    .await
                    .context("Failed to modify app bundle")?;
                Ok::<(), Report>(())
            },
            async {
                let profile = dev_session
                    .download_team_provisioning_profile(&team, &main_app_id, None)
                    .await?;
                info!("Acquired provisioning profile");
                Ok::<_, Report>(profile)
            },
        )
        .await?;

        app.bundle.write_info()?;
        for ext in app.bundle.app_extensions_mut() {
            ext.write_info()?;
        }
        for ext in app.bundle.frameworks_mut() {
            ext.write_info()?;
        }

        tokio::fs::write(
            app.bundle.bundle_dir.join("embedded.mobileprovision"),
            provisioning_profile.encoded_profile.as_ref(),
        )
        .await?;

        // Every nested bundle is signed with the main app's entitlements below,
        // so the main profile is the one that authorizes an extension too — give
        // each .appex its own copy. Hosts read it back (AltStore-family apps
        // reject an extension without one), and it must land before signing
        // because embedded.mobileprovision is sealed into CodeResources.
        for ext in app.bundle.app_extensions() {
            tokio::fs::write(
                ext.bundle_dir.join("embedded.mobileprovision"),
                provisioning_profile.encoded_profile.as_ref(),
            )
            .await?;
        }

        sign::sign(
            &mut app,
            &cert_identity,
            &provisioning_profile,
            &special,
            &team,
        )
        .context("Failed to sign app")?;

        info!("App signed!");

        Ok((app.bundle.bundle_dir.clone(), special))
    }

    #[cfg(feature = "install")]
    /// Sign and install an app to a device.
    pub async fn install_app(
        &mut self,
        device_provider: &impl IdeviceProvider,
        app_path: PathBuf,
        // this is gross but will be replaced with proper entitlement handling later
        increased_memory_limit: bool,
    ) -> Result<Option<SpecialApp>, Report> {
        let device_info = IdeviceInfo::from_device(device_provider).await?;

        let team = self.get_team().await?;
        let (signed_app_path, special_app) = self
            .sign_app(
                app_path,
                Some(team),
                increased_memory_limit,
                Some((&device_info.name, &device_info.udid)),
            )
            .await?;

        info!("Transferring App...");

        crate::sideload::install::install_app(device_provider, &signed_app_path, |progress| {
            info!("Installing: {}%", progress);
        })
        .await
        .context("Failed to install app on device")?;

        if self.delete_app_after_install
            && let Err(e) = tokio::fs::remove_dir_all(signed_app_path).await
        {
            tracing::warn!("Failed to remove temporary signed app file: {}", e);
        }

        Ok(special_app)
    }

    /// Get the developer team according to the configured team selection behavior
    pub async fn get_team(&mut self) -> Result<DeveloperTeam, Report> {
        if let Some(team) = &self.team {
            return Ok(team.clone());
        }
        let teams = self.dev_session.list_teams().await?;
        let team = match teams.len() {
            0 => {
                bail!("No developer teams available")
            }
            1 => teams.into_iter().next().ok_or_report()?,
            _ => {
                info!(
                    "Multiple developer teams found, {} as per configuration",
                    self.team_selection
                );
                match &self.team_selection {
                    TeamSelection::First => teams.into_iter().next().ok_or_report()?,
                    TeamSelection::PromptOnce(prompt_fn)
                    | TeamSelection::PromptAlways(prompt_fn) => {
                        let selection =
                            prompt_fn(&teams).ok_or_else(|| report!("No team selected"))?;
                        teams
                            .into_iter()
                            .find(|t| t.team_id == selection)
                            .ok_or_else(|| report!("No team found with ID {}", selection))?
                    }
                }
            }
        };
        if !matches!(&self.team_selection, TeamSelection::PromptAlways(_)) {
            self.team = Some(team.clone());
        }
        Ok(team)
    }

    /// Use `team` without asking Apple, for a caller that has already listed the
    /// teams and picked one as the team selection would.
    pub fn set_team(&mut self, team: DeveloperTeam) {
        self.team = Some(team);
    }

    pub fn get_dev_session(&mut self) -> &mut DeveloperSession {
        &mut self.dev_session
    }

    pub fn get_email(&self) -> &str {
        &self.apple_email
    }
}
