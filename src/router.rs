use crate::handlers::*;
use crate::store::ResourceStore;
use actix_web::{web, App, HttpServer};
use std::sync::Arc;

pub fn create_app(store: Arc<ResourceStore>) -> App<
    impl actix_web::dev::ServiceFactory<
        actix_web::dev::ServiceRequest,
        Response = actix_web::dev::ServiceResponse,
        Error = actix_web::Error,
    >
> {
    App::new()
        .app_data(web::Data::new(store))
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
}