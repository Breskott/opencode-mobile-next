//! Protocol-selecting phone driver. Selection is pinned for this client lifetime.
pub use crate::opencode1::{validate_model, GlobalStatusObservation, ProtocolError};
use crate::{opencode1, opencode2};
use reqwest::Method;
use serde_json::Value;
use tokio::sync::OnceCell;

pub struct OpenCodeClient {
    oc1: opencode1::OpenCodeClient,
    oc2: opencode2::OpenCode2Client,
    protocol: OnceCell<bool>,
}
impl OpenCodeClient {
    pub fn new(url: &str, username: &str, password: &str) -> Result<Self, ProtocolError> {
        Ok(Self {
            oc1: opencode1::OpenCodeClient::new(url, username, password)?,
            oc2: opencode2::OpenCode2Client::new(url, username, password)?,
            protocol: OnceCell::new(),
        })
    }
    /// Selected protocol identity survives verification or transport failure.
    pub fn is_oc2(&self) -> bool {
        self.protocol.get().copied().unwrap_or(false)
    }
    async fn oc2(&self) -> Result<bool, ProtocolError> {
        self.protocol
            .get_or_try_init(|| async {
                match self.oc1.request(Method::GET, "/api/info", None, None).await {
                    Ok(info) if info.get("version").is_some() => {
                        opencode2::validate_info(&info)?;
                        Ok(true)
                    }
                    Ok(_) => self.recognize_oc1().await,
                    Err(e) if matches!(e.code(), "protocol_unavailable" | "invalid_response") => {
                        self.recognize_oc1().await
                    }
                    Err(e) => Err(e),
                }
            })
            .await
            .copied()
    }
    async fn recognize_oc1(&self) -> Result<bool, ProtocolError> {
        let health = self
            .oc1
            .request(Method::GET, "/global/health", None, None)
            .await?;
        opencode1::validate_health(&health)?;
        Ok(false)
    }
    pub async fn verify(&self) -> Result<Value, ProtocolError> {
        if self.oc2().await? {
            self.oc2.verify().await
        } else {
            self.oc1.verify().await
        }
    }
    pub async fn resolve_model(
        &self,
        directory: &str,
        requested: &str,
    ) -> Result<String, ProtocolError> {
        if !requested.is_empty() {
            validate_model(requested)?;
            return Ok(requested.into());
        }
        if self.oc2().await? {
            self.oc2.resolve_model(directory, requested).await
        } else {
            self.oc1.resolve_model(directory, requested).await
        }
    }
    pub async fn chat_admission(&self, ids: &[String]) -> Result<bool, ProtocolError> {
        if self.oc2().await? {
            Err(ProtocolError("global_status_unavailable"))
        } else {
            self.oc1.chat_admission(ids).await
        }
    }
    pub async fn person_directory_status(
        &self,
        dirs: &[String],
        ids: &[String],
    ) -> Result<bool, ProtocolError> {
        opencode1::known_directories(dirs)?;
        opencode1::validate_team_ids(ids)?;
        if self.oc2().await? {
            self.oc2.person_directory_status(dirs, ids).await
        } else {
            self.oc1.person_directory_status(dirs, ids).await
        }
    }
    pub async fn global_status_observer(&self) -> Result<GlobalStatusObserver, ProtocolError> {
        if self.oc2().await? {
            self.oc2
                .global_status_observer()
                .await
                .map(GlobalStatusObserver::Oc2)
        } else {
            self.oc1
                .global_status_observer()
                .await
                .map(GlobalStatusObserver::Oc1)
        }
    }
    pub async fn create_session(
        &self,
        directory: &str,
        title: &str,
    ) -> Result<String, ProtocolError> {
        if self.oc2().await? {
            self.oc2.create_session(directory, title).await
        } else {
            self.oc1.create_session(directory, title).await
        }
    }
    pub async fn prompt(
        &self,
        directory: &str,
        id: &str,
        role: &str,
        model: &str,
        instructions: &str,
        text: &str,
        readonly: bool,
    ) -> Result<Value, ProtocolError> {
        opencode1::validate_session_id(id)?;
        opencode1::prompt_body(role, model, instructions, text, readonly)?;
        if self.oc2().await? {
            self.oc2
                .prompt(directory, id, role, model, instructions, text, readonly)
                .await
        } else {
            self.oc1
                .prompt(directory, id, role, model, instructions, text, readonly)
                .await
        }
    }
    pub async fn observe(&self, directory: &str, id: &str) -> Result<Value, ProtocolError> {
        opencode1::validate_session_id(id)?;
        if self.oc2().await? {
            self.oc2.observe(directory, id).await
        } else {
            self.oc1.observe(directory, id).await
        }
    }
    pub async fn abort(&self, directory: &str, id: &str) -> Result<(), ProtocolError> {
        opencode1::validate_session_id(id)?;
        if self.oc2().await? {
            self.oc2.abort(directory, id).await
        } else {
            self.oc1.abort(directory, id).await
        }
    }
}
pub enum GlobalStatusObserver {
    Oc1(opencode1::GlobalStatusObserver),
    Oc2(opencode2::GlobalStatusObserver),
}
impl GlobalStatusObserver {
    pub fn connected(&self) -> bool {
        match self {
            Self::Oc1(v) => v.connected(),
            Self::Oc2(v) => v.connected(),
        }
    }
    pub fn observed_non_team_busy(&self, ids: &[String]) -> Result<bool, ProtocolError> {
        match self {
            Self::Oc1(v) => v.observed_non_team_busy(ids),
            Self::Oc2(v) => v.observed_non_team_busy(ids),
        }
    }
    pub async fn next(&mut self) -> Result<GlobalStatusObservation, ProtocolError> {
        match self {
            Self::Oc1(v) => v.next().await,
            Self::Oc2(v) => v.next().await,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{extract::Request, response::IntoResponse, Router};
    #[tokio::test]
    async fn oc1_release_pins_verify_actual_identity_and_current_contract() {
        for (version, source) in [
            ("1.18.32", "545f51d26cc39a907d2867492d498d9607ea5fa4"),
            ("1.19.0", "733b2c627e5aec39cb33cc22373bdce33053ef2c"),
        ] {
            let doc: Value = serde_json::from_str(if version == "1.19.0" {
                include_str!("../tests/fixtures/oc1-1.19.0-driver-openapi.json")
            } else {
                include_str!("../../../contracts/opencode-openapi-f12e14cf.json")
            })
            .unwrap();
            let router = Router::new().fallback(move |request: Request| {
                let doc = doc.clone();
                async move {
                    match request.uri().path() {
                        "/global/health" => {
                            axum::Json(serde_json::json!({"healthy":true,"version":version}))
                                .into_response()
                        }
                        "/doc" => axum::Json(doc).into_response(),
                        _ => axum::response::Html("<!doctype html><html></html>").into_response(),
                    }
                }
            });
            let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
            let addr = listener.local_addr().unwrap();
            let task = tokio::spawn(async move { axum::serve(listener, router).await.unwrap() });
            let client =
                OpenCodeClient::new(&format!("http://{addr}"), "opencode", "fixture-only").unwrap();
            let result = client.verify().await;
            task.abort();
            let verified = result.unwrap_or_else(|error| panic!("{version}: {error}"));
            assert_eq!(verified["version"], version);
            assert_eq!(verified["sourceRevision"], source);
            assert_eq!(verified["openapiVerified"], true);
            assert!(!client.is_oc2());
        }
    }

    #[tokio::test]
    async fn oc1_release_pin_requires_healthy_supported_server_and_current_schema() {
        for (health, doc, expected) in [
            (
                serde_json::json!({"healthy":true,"version":"1.19.1"}),
                serde_json::json!({}),
                "unsupported_server_version",
            ),
            (
                serde_json::json!({"healthy":false,"version":"1.19.0"}),
                serde_json::json!({}),
                "unsupported_server_version",
            ),
            (
                serde_json::json!({"healthy":true,"version":"1.19.0"}),
                serde_json::json!({}),
                "openapi_unconfirmed",
            ),
        ] {
            let router = Router::new().fallback(move |request: Request| {
                let body = if request.uri().path() == "/global/health" {
                    health.clone()
                } else {
                    doc.clone()
                };
                async move { axum::Json(body) }
            });
            let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
            let addr = listener.local_addr().unwrap();
            let task = tokio::spawn(async move { axum::serve(listener, router).await.unwrap() });
            let client =
                OpenCodeClient::new(&format!("http://{addr}"), "opencode", "fixture-only").unwrap();
            let result = client.verify().await;
            task.abort();
            assert_eq!(result.unwrap_err().code(), expected);
        }
    }

    #[tokio::test]
    async fn selected_oc2_identity_survives_failed_schema_verification() {
        let router=Router::new().fallback(|request: Request| async move {
            if request.uri().path()=="/api/info" {axum::Json(serde_json::json!({"version":"2.0.29","pid":1,"urls":[],"paths":{"tmp":"/tmp"}})).into_response()}
            else {axum::Json(serde_json::json!({})).into_response()}
        });
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let task = tokio::spawn(async move { axum::serve(listener, router).await.unwrap() });
        let client =
            OpenCodeClient::new(&format!("http://{addr}"), "opencode", "fixture-only").unwrap();
        assert!(!client.is_oc2());
        assert_eq!(
            client.verify().await.unwrap_err().code(),
            "openapi_unconfirmed"
        );
        assert!(client.is_oc2());
        task.abort();
    }
    #[tokio::test]
    async fn oc1_spa_fallback_requires_recognized_pinned_health() {
        let router = Router::new().fallback(|request: Request| async move {
            if request.uri().path() == "/global/health" {
                axum::Json(serde_json::json!({"healthy":true,"version":"1.18.32"})).into_response()
            } else {
                axum::response::Html("<!doctype html><html></html>").into_response()
            }
        });
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let task = tokio::spawn(async move { axum::serve(listener, router).await.unwrap() });
        let client =
            OpenCodeClient::new(&format!("http://{addr}"), "opencode", "fixture-only").unwrap();
        assert!(!client.oc2().await.unwrap());
        assert!(!client.is_oc2());
        task.abort();
    }
    #[tokio::test]
    async fn detection_never_falls_back_on_auth_or_explicit_unsupported_version() {
        use std::sync::{Arc, Mutex};
        for (status, body, fallback) in [
            (
                reqwest::StatusCode::UNAUTHORIZED,
                serde_json::json!({}),
                false,
            ),
            (
                reqwest::StatusCode::OK,
                serde_json::json!({"version":"2.0.28","pid":1,"urls":[],"paths":{"tmp":"/tmp"}}),
                false,
            ),
            (reqwest::StatusCode::NOT_FOUND, serde_json::json!({}), true),
        ] {
            let calls = Arc::new(Mutex::new(Vec::<String>::new()));
            let seen = calls.clone();
            let router = Router::new().fallback(move |request: Request| {
                let seen = seen.clone();
                let body = body.clone();
                async move {
                    let path = request.uri().path().to_owned();
                    seen.lock().unwrap().push(path.clone());
                    if path == "/api/info" {
                        (status, axum::Json(body)).into_response()
                    } else {
                        axum::Json(serde_json::json!({"healthy":true,"version":"1.18.32"}))
                            .into_response()
                    }
                }
            });
            let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
            let addr = listener.local_addr().unwrap();
            let task = tokio::spawn(async move { axum::serve(listener, router).await.unwrap() });
            let client =
                OpenCodeClient::new(&format!("http://{addr}"), "opencode", "fixture-only").unwrap();
            let result = client.oc2().await;
            if fallback {
                assert_eq!(result.unwrap(), false);
                let before = calls.lock().unwrap().len();
                assert!(!client.oc2().await.unwrap());
                assert_eq!(
                    calls.lock().unwrap().len(),
                    before,
                    "pinned selection must not rediscover protocol"
                );
            } else {
                assert!(result.is_err());
            }
            assert_eq!(
                calls.lock().unwrap().iter().any(|p| p == "/global/health"),
                fallback
            );
            task.abort();
        }
        let closed = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = closed.local_addr().unwrap();
        drop(closed);
        let client =
            OpenCodeClient::new(&format!("http://{address}"), "opencode", "fixture-only").unwrap();
        assert_eq!(
            client.oc2().await.unwrap_err().code(),
            "transport_unavailable"
        );
        assert!(client.protocol.get().is_none());
    }
    #[tokio::test]
    async fn local_preflight_never_requires_network_or_protocol_detection() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        drop(listener);
        let client =
            OpenCodeClient::new(&format!("http://{addr}"), "opencode", "fixture-only").unwrap();
        assert_eq!(
            client
                .resolve_model("/repo", "provider/model")
                .await
                .unwrap(),
            "provider/model"
        );
        assert_eq!(
            client
                .resolve_model("/repo", "invalid")
                .await
                .unwrap_err()
                .code(),
            "invalid_model"
        );
        assert_eq!(
            client.observe("/repo", "invalid").await.unwrap_err().code(),
            "invalid_session"
        );
        assert_eq!(
            client.abort("/repo", "invalid").await.unwrap_err().code(),
            "invalid_session"
        );
        assert_eq!(
            client
                .prompt(
                    "/repo",
                    "invalid",
                    "planner",
                    "provider/model",
                    "instructions",
                    "text",
                    true
                )
                .await
                .unwrap_err()
                .code(),
            "invalid_session"
        );
        assert_eq!(
            client
                .prompt(
                    "/repo",
                    "ses_test",
                    "planner",
                    "provider/model",
                    "instructions",
                    "text",
                    false
                )
                .await
                .unwrap_err()
                .code(),
            "invalid_role"
        );
        assert_eq!(
            client
                .person_directory_status(&[], &[])
                .await
                .unwrap_err()
                .code(),
            "person_directory_unknown"
        );
        assert!(client.protocol.get().is_none());
    }
}
