#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};
    use std::collections::HashMap;

    fn create_test_store() -> ResourceStore {
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
        
        data.insert(
            "profile".to_string(),
            json!({"id": 1, "name": "Test Profile", "bio": "Test Bio"})
        );
        
        ResourceStore::new(data)
    }

    #[test]
    fn test_get_resources() {
        let