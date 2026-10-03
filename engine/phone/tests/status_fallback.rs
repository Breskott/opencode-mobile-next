//! Local HTTP fixtures only; root runs these under the shared machine lock.
use axum::{
    extract::{Query, State},
    http::{header, StatusCode},
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use oc_phone_engine::opencode::{GlobalStatusObservation, OpenCodeClient};
use serde_json::{json, Value};
use std::collections::HashMap;

async fn status(
    State(fixtures): State<Value>,
    Query(query): Query<HashMap<String, String>>,
) -> Json<Value> {
    Json(
        query
            .get("directory")
            .and_then(|directory| fixtures.get(directory))
            .cloned()
            .unwrap_or(Value::Null),
    )
}

async fn server(
    fixtures: Value,
    events: &'static str,
) -> (OpenCodeClient, tokio::task::JoinHandle<()>) {
    let app = Router::new()
        .route(
            "/global/health",
            get(|| async { Json(json!({"healthy":true,"version":"1.18.32"})) }),
        )
        .route("/session/status", get(status))
        .route(
            "/global/event",
            get(move || async move {
                (
                    StatusCode::OK,
                    [(header::CONTENT_TYPE, "text/event-stream")],
                    events,
                )
                    .into_response()
            }),
        )
        .with_state(fixtures);
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let task = tokio::spawn(async move {
        axum::serve(listener, app).await.unwrap();
    });
    let client = OpenCodeClient::new(
        &format!("http://{address}"),
        "opencode",
        "fixture-only-password",
    )
    .unwrap();
    (client, task)
}

#[tokio::test]
async fn all_known_directories_are_checked_and_only_team_busy_is_excluded() {
    let (client, server) = server(json!({
        "/person/first":{}, "/person/second":{"ses_person":{"type":"busy"}},
        "/team":{"ses_team":{"type":"busy"}},
        "/retry":{"ses_person":{"type":"retry","attempt":1,"next":123,"message":"private provider retry"}}
    }), "").await;
    assert!(!client
        .person_directory_status(
            &["/person/first".into(), "/person/second".into()],
            &["ses_team".into()]
        )
        .await
        .unwrap());
    assert!(client
        .person_directory_status(
            &["/person/first".into(), "/team".into()],
            &["ses_team".into()]
        )
        .await
        .unwrap());
    assert!(!client
        .person_directory_status(&["/retry".into()], &[])
        .await
        .unwrap());
    assert!(client
        .person_directory_status(&["/missing".into()], &[])
        .await
        .is_err());
    assert!(client.person_directory_status(&[], &[]).await.is_err());
    assert!(client
        .person_directory_status(&["unknown".into()], &[])
        .await
        .is_err());
    server.abort();
}

#[tokio::test]
async fn malformed_later_directory_never_grants_idle_after_an_earlier_snapshot() {
    let (client, server) = server(
        json!({"/first":{},"/second":{"ses_person":{"type":"retry"}}}),
        "",
    )
    .await;
    assert_eq!(
        client
            .person_directory_status(&["/first".into(), "/second".into()], &[])
            .await
            .unwrap_err()
            .code(),
        "invalid_status"
    );
    server.abort();
}

#[tokio::test]
async fn unknown_directory_busy_blocks_until_exact_idle_and_eof_never_grants_idle() {
    const EVENTS: &str = concat!(
        "data: {\"payload\":{\"type\":\"server.connected\",\"properties\":{}}}\n\n",
        "data: {\"directory\":\"/unknown-client\",\"payload\":{\"type\":\"session.status\",\"properties\":{\"sessionID\":\"ses_person\",\"status\":{\"type\":\"busy\"}}}}\n\n",
        "data: {\"directory\":\"/known\",\"payload\":{\"type\":\"session.status\",\"properties\":{\"sessionID\":\"ses_person\",\"status\":{\"type\":\"idle\"}}}}\n\n",
        "data: {\"directory\":\"/unknown-client\",\"payload\":{\"type\":\"session.idle\",\"properties\":{\"sessionID\":\"ses_person\"}}}\n\n"
    );
    let (client, server) = server(json!({}), EVENTS).await;
    let mut observer = client.global_status_observer().await.unwrap();
    assert_eq!(
        observer.next().await.unwrap(),
        GlobalStatusObservation::Other
    );
    assert!(matches!(
        observer.next().await.unwrap(),
        GlobalStatusObservation::Status { busy: true, .. }
    ));
    assert!(observer.observed_non_team_busy(&[]).unwrap());
    assert!(!observer
        .observed_non_team_busy(&["ses_person".into()])
        .unwrap());
    assert!(matches!(
        observer.next().await.unwrap(),
        GlobalStatusObservation::Status { busy: false, .. }
    ));
    assert!(observer.observed_non_team_busy(&[]).unwrap());
    assert!(matches!(
        observer.next().await.unwrap(),
        GlobalStatusObservation::Status { busy: false, .. }
    ));
    assert!(!observer.observed_non_team_busy(&[]).unwrap()); // Evidence set only; never admission.
    assert_eq!(
        observer.next().await.unwrap_err().code(),
        "global_status_disconnected"
    );
    assert!(!observer.connected());
    assert!(observer.observed_non_team_busy(&[]).is_err());
    // A new connection is still incomplete history, with no global idle proof.
    let mut reconnected = client.global_status_observer().await.unwrap();
    assert_eq!(
        reconnected.next().await.unwrap(),
        GlobalStatusObservation::Other
    );
    assert!(matches!(
        reconnected.next().await.unwrap(),
        GlobalStatusObservation::Status { busy: true, .. }
    ));
    assert!(reconnected.observed_non_team_busy(&[]).unwrap());
    server.abort();
}
