use bohongan::cli;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;
use tempfile::tempdir;

#[test]
fn test_merge_resource() {
    let mut existing = serde_json::json!([
        {"id": 1, "name": "Item 1"},
        {"id": 2, "name": "Item 2"},
        "non-map item"
    ]);
    
    let new = serde_json::json!([
        {"id": 2, "name": "Updated Item 2"},
        {"id": 3, "name": "Item 3"},
        {"no_id": true}
    ]);
    
    cli::merge_resource(&mut existing, new);
    
    // Verify the result
    let items = existing.as_array().unwrap();
    assert_eq!(items.len(), 5);
    
    // Check that item 2 was updated
    let item2 = items.iter().find(|item| {
        item.is_object() && 
        item.get("id").is_some() && 
        item["id"] == 2
    }).unwrap();
    assert_eq!(item2["name"], "Updated Item 2");
    
    // Check that other items are preserved
    assert!(items.iter().any(|item| {
        item.is_object() && 
        item.get("id").is_some() && 
        item["id"] == 1
    }));
    
    assert!(items.iter().any(|item| {
        item.is_object() && 
        item.get("id").is_some() && 
        item["id"] == 3
    }));
    
    // Check that non-map items are preserved
    assert!(items.iter().any(|item| {
        item.is_string() && 
        item == "non-map item"
    }));
    
    assert!(items.iter().any(|item| {
        item.is_object() && 
        item.get("no_id").is_some()
    }));
}

#[test]
fn test_process_json_files() {
    // Create temporary directory for test files
    let dir = tempdir().unwrap();
    
    // Create test JSON files
    let file1_path = dir.path().join("test1.json");
    let file2_path = dir.path().join("test2.json");
    
    let file1_content = r#"
    {
        "users": [
            {"id": 1, "name": "User 1"},
            {"id": 2, "name": "User 2"}
        ]
    }
    "#;
    
    let file2_content = r#"
    {
        "users": [
            {"id": 2, "name": "Updated User 2"},
            {"id": 3, "name": "User 3"}
        ],
        "posts": [
            {"id": 1, "title": "Post 1"}
        ]
    }
    "#;
    
    let mut file1 = File::create(&file1_path).unwrap();
    let mut file2 = File::create(&file2_path).unwrap();
    
    file1.write_all(file1_content.as_bytes()).unwrap();
    file2.write_all(file2_content.as_bytes()).unwrap();
    
    // Test processing files
    let result = cli::process_json_files(&[
        file1_path.to_str().unwrap().to_string(),
        file2_path.to_str().unwrap().to_string()
    ]).unwrap();
    
    // Verify the result
    assert!(result.contains_key("users"));
    assert!(result.contains_key("posts"));
    
    let users = result["users"].as_array().unwrap();
    assert_eq!(users.len(), 3);
    
    // Check that user 2 was updated
    let user2 = users.iter().find(|user| {
        user["id"] == 2
    }).unwrap();
    assert_eq!(user2["name"], "Updated User 2");
}