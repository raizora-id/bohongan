use actix_web::{test, App, web};
use bohongan::router::create_app;
use bohongan::store::ResourceStore;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Arc;

fn create_test_app() -> test::TestApp {
    // Create test data
    let mut data = HashMap::new();
    
    data.insert(
        "posts".to_string(),
        json!([
            {"id": 1, "title": "Test Post 1", "author": "Test Author 1"},
            {"id": 2, "title": "Test Post 2", "author": "Test Author 2"}
        ])
    );
    
    data.insert(
        "comments".to_string(),
        json!([
            {"id": 1, "postId": 1, "body": "Test Comment 1", "author": "Test Commenter 1"},
            {"id": 2, "postId": 1, "body": "Test Comment 2", "author": "Test Commenter 2"}
        ])
    );
    
    // Create store
    let store = Arc::new(ResourceStore::new(data));
    
    // Create test app
    test::init_service(create_app(store))
}

#[actix_web::test]
async fn test_get_home() {
    let app = create_test_app().await;
    
    // Test the home endpoint
    let req = test::TestRequest::get().uri("/").to_request();
    let resp = test::call_service(&app, req).await;
    
    assert!(resp.status().is_success());
    
    let body: Value = test::read_body_json(resp).await;
    
    // Check response structure
    assert!(body.get("resources").is_some());
    assert!(body.get("routes").is_some());
    
    // Check resources
    let resources = body["resources"].as_array().unwrap();
    assert_eq!(resources.len(), 2);
    assert!(resources.contains(&json!("posts")));
    assert!(resources.contains(&json!("comments")));
}

#[actix_web::test]
async fn test_get_collection() {
    let app = create_test_app().await;
    
    // Test getting a collection
    let req = test::TestRequest::get().uri("/posts").to_request();
    let resp = test::call_service(&app, req).await;
    
    assert!(resp.status().is_success());
    
    let body: Value = test::read_body_json(resp).await;
    
    // Check it's an array with the expected items
    assert!(body.is_array());
    let posts = body.as_array().unwrap();
    assert_eq!(posts.len(), 2);
}

#[actix_web::test]
async fn test_get_item() {
    let app = create_test_app().await;
    
    // Test getting an existing item
    let req = test::TestRequest::get().uri("/posts/1").to_request();
    let resp = test::call_service(&app, req).await;
    
    assert!(resp.status().is_success());
    
    let body: Value = test::read_body_json(resp).await;
    
    // Check it's the expected item
    assert_eq!(body["id"], 1);
    assert_eq!(body["title"], "Test Post 1");
    
    // Test getting a non-existent item
    let req = test::TestRequest::get().uri("/posts/999").to_request();
    let resp = test::call_service(&app, req).await;
    
    assert_eq!(resp.status().as_u16(), 404);
}

#[actix_web::test]
async fn test_create_item() {
    let app = create_test_app().await;
    
    // Test creating a new item
    let new_post = json!({"title": "New Post", "author": "New Author"});
    let req = test::TestRequest::post()
        .uri("/posts")
        .set_json(&new_post)
        .to_request();
    let resp = test::call_service(&app, req).await;
    
    assert_eq!(resp.status().as_u16(), 201);
    
    let body: Value = test::read_body_json(resp).await;
    
    // Check the created item has an ID and expected values
    assert!(body["id"].is_number());
    assert_eq!(body["title"], "New Post");
    assert_eq!(body["author"], "New Author");
    
    // Verify the item was added by getting the collection
    let req = test::TestRequest::get().uri("/posts").to_request();
    let resp = test::call_service(&app, req).await;
    
    let body: Value = test::read_body_json(resp).await;
    let posts = body.as_array().unwrap();
    
    // Should now have 3 items
    assert_eq!(posts.len(), 3);
}

#[actix_web::test]
async fn test_update_item() {
    let app = create_test_app().await;
    
    // Test updating an existing item
    let update = json!({"title": "Updated Title"});
    let req = test::TestRequest::put()
        .uri("/posts/1")
        .set_json(&update)
        .to_request();
    let resp = test::call_service(&app, req).await;
    
    assert!(resp.status().is_success());
    
    let body: Value = test::read_body_json(resp).await;
    
    // Check the update was applied
    assert_eq!(body["id"], 1);
    assert_eq!(body["title"], "Updated Title");
    assert_eq!(body["author"], "Test Author 1"); // Original field retained
    
    // Test updating a non-existent item
    let req = test::TestRequest::put()
        .uri("/posts/999")
        .set_json(&update)
        .to_request();
    let resp = test::call_service(&app, req).await;
    
    assert_eq!(resp.status().as_u16(), 404);
}

#[actix_web::test]
async fn test_delete_item() {
    let app = create_test_app().await;
    
    // Test deleting an existing item
    let req = test::TestRequest::delete().uri("/posts/1").to_request();
    let resp = test::call_service(&app, req).await;
    
    assert_eq!(resp.status().as_u16(), 204);
    assert!(resp.status().is_success());
    
    // Verify the item was deleted by trying to get it
    let req = test::TestRequest::get().uri("/posts/1").to_request();
    let resp = test::call_service(&app, req).await;
    
    assert_eq!(resp.status().as_u16(), 404);
    
    // Test deleting a non-existent item
    let req = test::TestRequest::delete().uri("/posts/999").to_request();
    let resp = test::call_service(&app, req).await;
    
    assert_eq!(resp.status().as_u16(), 404);
}