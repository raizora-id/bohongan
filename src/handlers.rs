use crate::store::ResourceStore;
use actix_web::{web, HttpResponse, Responder};
use serde_json::{json, Value};
use std::sync::Arc;

pub async fn get_home(store: web::Data<Arc<ResourceStore>>) -> impl Responder {
    let resources = store.get_resources();
    
    // Generate routes for each resource
    let routes = resources.iter().map(|resource| {
        json!({
            "resource": resource,
            "endpoints": [
                {"method": "GET", "url": format!("/{}", resource)},
                {"method": "GET", "url": format!("/{}/:id", resource)},
                {"method": "POST", "url": format!("/{}", resource)},
                {"method": "PUT", "url": format!("/{}/:id", resource)},
                {"method": "PATCH", "url": format!("/{}/:id", resource)},
                {"method": "DELETE", "url": format!("/{}/:id", resource)}
            ]
        })
    }).collect::<Vec<_>>();
    
    HttpResponse::Ok().json(json!({
        "resources": resources,
        "routes": routes
    }))
}

pub async fn get_collection(
    path: web::Path<String>,
    store: web::Data<Arc<ResourceStore>>
) -> impl Responder {
    let resource = path.into_inner();
    
    match store.get_collection(&resource) {
        Some(collection) => HttpResponse::Ok().json(collection),
        None => HttpResponse::Ok().json(json!([])),
    }
}

pub async fn get_item(
    path: web::Path<(String, String)>,
    store: web::Data<Arc<ResourceStore>>
) -> impl Responder {
    let (resource, id) = path.into_inner();
    
    match store.get_item(&resource, &id) {
        Some(item) => HttpResponse::Ok().json(item),
        None => HttpResponse::NotFound().json(json!({"error": "Item not found"})),
    }
}

pub async fn create_item(
    path: web::Path<String>,
    body: web::Json<Value>,
    store: web::Data<Arc<ResourceStore>>
) -> impl Responder {
    let resource = path.into_inner();
    let item = body.into_inner();
    
    let created_item = store.create_item(&resource, item);
    HttpResponse::Created().json(created_item)
}

pub async fn update_item(
    path: web::Path<(String, String)>,
    body: web::Json<Value>,
    store: web::Data<Arc<ResourceStore>>
) -> impl Responder {
    let (resource, id) = path.into_inner();
    let updates = body.into_inner();
    
    match store.update_item(&resource, &id, updates) {
        Some(item) => HttpResponse::Ok().json(item),
        None => HttpResponse::NotFound().json(json!({"error": "Item not found"})),
    }
}

pub async fn delete_item(
    path: web::Path<(String, String)>,
    store: web::Data<Arc<ResourceStore>>
) -> impl Responder {
    let (resource, id) = path.into_inner();
    
    if store.delete_item(&resource, &id) {
        HttpResponse::NoContent().finish()
    } else {
        HttpResponse::NotFound().json(json!({"error": "Item not found"}))
    }
}