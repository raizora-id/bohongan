use crate::handlers::*;
use crate::store::ResourceStore;
use actix_web::{web, App, HttpServer};
use log::info;
use std::sync::Arc;

pub async fn start_server(store: ResourceStore, port: u16) -> std::io::Result<()> {
    // Wrap the store in an Arc for thread-safe sharing
    let store = Arc::new(store);
    
    // Start the HTTP server
    info!("Starting server on port {}", port);
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(Arc::clone(&store)))
            // Add CORS middleware
            .wrap(
                actix_web::middleware::DefaultHeaders::new()
                    .add(("Access-Control-Allow-Origin", "*"))
                    .add(("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE"))
                    .add(("Access-Control-Allow-Headers", "Content-Type"))
            )
            // Define routes
            .route("/", web::get().to(get_home))
            .route("/{resource}", web::get().to(get_collection))
            .route("/{resource}/{id}", web::get().to(get_item))
            .route("/{resource}", web::post().to(create_item))
            .route("/{resource}/{id}", web::put().to(update_item))
            .route("/{resource}/{id}", web::patch().to(update_item))
            .route("/{resource}/{id}", web::delete().to(delete_item))
            // Add logging middleware
            .wrap(actix_web::middleware::Logger::default())
    })
    .bind(format!("127.0.0.1:{}", port))?
    .run()
    .await
}