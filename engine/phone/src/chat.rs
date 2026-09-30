//! App-authoritative admission lease. Expiry is unknown, never idle.
use serde::Deserialize;
use std::collections::{BTreeSet, HashSet};

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ChatHeartbeat {
    pub until: u64,
    pub session_ids: Vec<String>,
    pub directories: Vec<String>,
    pub known: bool,
    pub app_instance: String,
    pub sequence: u64,
}

#[derive(Debug, PartialEq, Eq)]
pub enum ChatAdmission {
    Idle,
    Busy,
    Unknown,
    PollKnownDirectories,
}

#[derive(Clone, Default)]
pub struct ChatLedger {
    current: Option<ChatHeartbeat>,
    received_at: u64,
    retired: HashSet<String>,
    directories: BTreeSet<String>,
    observed_busy: BTreeSet<(String, String)>,
    observation_revision: u64,
    observation_unknown: bool,
}

impl ChatLedger {
    pub fn accept(&mut self, heartbeat: ChatHeartbeat, now: u64) -> Result<(), &'static str> {
        if heartbeat.until <= now
            || heartbeat.until > now.saturating_add(30_000)
            || heartbeat.session_ids.len() > 1000
            || heartbeat.directories.len() > 256
            || !crate::config::valid_id(&heartbeat.app_instance)
            || heartbeat
                .session_ids
                .iter()
                .any(|id| id.is_empty() || id.len() > 256 || id.chars().any(char::is_whitespace))
            || heartbeat
                .directories
                .iter()
                .any(|path| !valid_directory(path))
        {
            return Err("heartbeatInvalid");
        }
        let mut proposed = self.directories.clone();
        proposed.extend(heartbeat.directories.iter().cloned());
        if proposed.len() > 256 {
            return Err("directoryLimit");
        }
        if self.retired.contains(&heartbeat.app_instance) {
            return Err("heartbeatStale");
        }
        if let Some(previous) = &self.current {
            if previous.app_instance == heartbeat.app_instance {
                if heartbeat.sequence <= previous.sequence {
                    return Err("heartbeatStale");
                }
            } else {
                if self.retired.len() >= 128 {
                    return Err("heartbeatGenerationLimit");
                }
                self.retired.insert(previous.app_instance.clone());
            }
        }
        for directory in &heartbeat.directories {
            self.learn_directory(directory)?;
        }
        self.received_at = now;
        self.current = Some(heartbeat);
        Ok(())
    }

    pub fn admission(&self, now: u64, app_alive: Option<bool>, team: &[String]) -> ChatAdmission {
        // Any observed busy non-team session blocks, including another device.
        // SSE silence/reconnect is not an authoritative idle checkpoint.
        if self.observation_unknown {
            return ChatAdmission::Unknown;
        }
        if self.observed_busy.iter().any(|(_, id)| !team.contains(id)) {
            return ChatAdmission::Busy;
        }
        match app_alive {
            Some(true) => match &self.current {
                Some(value) if now >= self.received_at && now < value.until && value.known => {
                    if value.session_ids.iter().any(|id| !team.contains(id)) {
                        ChatAdmission::Busy
                    } else {
                        ChatAdmission::Idle
                    }
                }
                _ => ChatAdmission::Unknown,
            },
            Some(false) if !self.directories.is_empty() => ChatAdmission::PollKnownDirectories,
            _ => ChatAdmission::Unknown,
        }
    }

    pub fn learn_directory(&mut self, directory: &str) -> Result<(), &'static str> {
        if !valid_directory(directory) {
            return Err("directoryUnknown");
        }
        if !self.directories.contains(directory) && self.directories.len() >= 256 {
            return Err("directoryLimit");
        }
        self.directories.insert(directory.to_owned());
        Ok(())
    }

    pub fn observe(
        &mut self,
        directory: &str,
        session: &str,
        busy: bool,
    ) -> Result<(), &'static str> {
        self.observation_revision = self.observation_revision.saturating_add(1);
        self.learn_directory(directory)?;
        if session.is_empty() || session.len() > 256 {
            return Err("sessionUnknown");
        }
        if busy {
            if self.observed_busy.len() >= 1000 {
                return Err("sessionLimit");
            }
            self.observed_busy
                .insert((directory.to_owned(), session.to_owned()));
        } else {
            self.observed_busy
                .remove(&(directory.to_owned(), session.to_owned()));
        }
        Ok(())
    }

    pub fn observation_revision(&self) -> u64 {
        self.observation_revision
    }
    pub fn reconcile_observed_idle(&mut self, revision: u64) {
        if self.observation_revision == revision {
            self.observed_busy.clear();
        }
    }
    pub fn observation_unknown(&mut self) {
        self.observation_unknown = true;
    }
    pub fn has_observed_busy(&self) -> bool {
        !self.observed_busy.is_empty()
    }

    pub fn directories(&self) -> Vec<String> {
        self.directories.iter().cloned().collect()
    }
}

fn valid_directory(path: &str) -> bool {
    path.starts_with('/')
        && path.len() <= 4096
        && !path.contains('\0')
        && !path.split('/').any(|part| part == "." || part == "..")
}

#[cfg(test)]
mod tests {
    use super::*;
    fn heartbeat(seq: u64, ids: &[&str]) -> ChatHeartbeat {
        ChatHeartbeat {
            until: 31_000,
            session_ids: ids.iter().map(|s| s.to_string()).collect(),
            directories: vec!["/root/projects/person".into()],
            known: true,
            app_instance: "instance".into(),
            sequence: seq,
        }
    }
    #[test]
    fn strict_idle_poll_does_not_erase_a_newer_busy_observation() {
        let mut ledger = ChatLedger::default();
        ledger.accept(heartbeat(1, &[]), 1000).unwrap();
        ledger.observe("/root/other", "one", true).unwrap();
        let polling_revision = ledger.observation_revision();
        ledger.observe("/root/other", "two", true).unwrap();
        ledger.reconcile_observed_idle(polling_revision);
        assert_eq!(ledger.admission(2000, Some(true), &[]), ChatAdmission::Busy);
        ledger.reconcile_observed_idle(ledger.observation_revision());
        assert_eq!(ledger.admission(2000, Some(true), &[]), ChatAdmission::Idle);
        ledger.observation_unknown();
        assert_eq!(
            ledger.admission(2000, Some(true), &[]),
            ChatAdmission::Unknown
        );
    }
    #[test]
    fn missing_expired_unknown_and_reversed_clock_never_mean_idle() {
        let mut ledger = ChatLedger::default();
        assert_eq!(
            ledger.admission(1000, Some(true), &[]),
            ChatAdmission::Unknown
        );
        ledger.accept(heartbeat(1, &[]), 1000).unwrap();
        assert_eq!(ledger.admission(2000, Some(true), &[]), ChatAdmission::Idle);
        assert_eq!(
            ledger.admission(31_000, Some(true), &[]),
            ChatAdmission::Unknown
        );
        assert_eq!(
            ledger.admission(999, Some(true), &[]),
            ChatAdmission::Unknown
        );
        assert_eq!(ledger.admission(2000, None, &[]), ChatAdmission::Unknown);
        let mut unknown = heartbeat(2, &[]);
        unknown.known = false;
        ledger.accept(unknown, 2000).unwrap();
        assert_eq!(
            ledger.admission(3000, Some(true), &[]),
            ChatAdmission::Unknown
        );
    }
    #[test]
    fn person_busy_blocks_and_team_ids_do_not_impersonate_a_person() {
        let mut ledger = ChatLedger::default();
        ledger
            .accept(heartbeat(1, &["person", "team"]), 1000)
            .unwrap();
        assert_eq!(
            ledger.admission(2000, Some(true), &["team".into()]),
            ChatAdmission::Busy
        );
        ledger.accept(heartbeat(2, &["team"]), 2000).unwrap();
        assert_eq!(
            ledger.admission(3000, Some(true), &["team".into()]),
            ChatAdmission::Idle
        );
        ledger.observe("/root/other-device", "other", true).unwrap();
        assert_eq!(ledger.admission(3000, Some(true), &[]), ChatAdmission::Busy);
        ledger
            .observe("/root/other-device", "other", false)
            .unwrap();
        assert_eq!(
            ledger.admission(40_000, Some(true), &[]),
            ChatAdmission::Unknown
        );
    }
    #[test]
    fn alive_process_cannot_fall_back_and_old_inflight_heartbeats_cannot_replace_busy() {
        let mut ledger = ChatLedger::default();
        ledger.accept(heartbeat(2, &["person"]), 1000).unwrap();
        assert_eq!(
            ledger.accept(heartbeat(1, &[]), 1000),
            Err("heartbeatStale")
        );
        assert_eq!(
            ledger.admission(32_000, Some(true), &[]),
            ChatAdmission::Unknown
        );
        assert_eq!(
            ledger.admission(32_000, Some(false), &[]),
            ChatAdmission::PollKnownDirectories
        );
        let mut new = heartbeat(1, &[]);
        new.app_instance = "new-instance".into();
        ledger.accept(new, 2000).unwrap();
        assert_eq!(
            ledger.accept(heartbeat(3, &[]), 2000),
            Err("heartbeatStale")
        );
    }
}
