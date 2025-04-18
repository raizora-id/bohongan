#[cfg(test)]
mod tests;

use serde_json::Value;
use std::collections::HashMap;
use std::sync::RwLock;

pub struct ResourceStore {
    data: RwLock<HashMap<String, Value>>,
    id_counters: RwLock<HashMap<String, i64>>,
}

impl ResourceStore {
    pub fn new(initial_data: HashMap<String, Value>) -> Self {
        // Initialize id counters for each resource
        let mut id_counters = HashMap::new();
        
        for (resource, value) in &initial_data {
            if let Value::Array(items) = value {
                // Find the maximum ID in the array
                let max_id = items
                    .iter()
                    .filter_map(|item| {
                        if let Value::Object(obj) = item {
                            if let Some(Value::Number(id)) = obj.get("id") {
                                id.as_i64()
                            } else {
                                None
                            }
                        } else {
                            None
                        }
                    })
                    .max()
                    .unwrap_or(0);
                
                id_counters.insert(resource.clone(), max_id + 1);
            } else if let Value::Object(obj) = value {
                if let Some(Value::Number(id)) = obj.get("id") {
                    if let Some(id) = id.as_i64() {
                        id_counters.insert(resource.clone(), id + 1);
                    }
                }
            }
        }
        
        Self {
            data: RwLock::new(initial_data),
            id_counters: RwLock::new(id_counters),
        }
    }
    
    pub fn get_resources(&self) -> Vec<String> {
        self.data.read().unwrap().keys().cloned().collect()
    }
    
    pub fn get_collection(&self, resource: &str) -> Option<Value> {
        self.data.read().unwrap().get(resource).cloned()
    }
    
    pub fn get_item(&self, resource: &str, id: &str) -> Option<Value> {
        let data = self.data.read().unwrap();
        
        if let Some(collection) = data.get(resource) {
            if let Value::Array(items) = collection {
                // Look for an item with matching ID
                for item in items {
                    if let Value::Object(obj) = item {
                        if let Some(item_id) = obj.get("id") {
                            if item_id.to_string() == id {
                                return Some(item.clone());
                            }
                        }
                    }
                }
            } else if let Value::Object(obj) = collection {
                // Handle single object resources
                if let Some(obj_id) = obj.get("id") {
                    if obj_id.to_string() == id {
                        return Some(collection.clone());
                    }
                }
            }
        }
        
        None
    }
    
    pub fn create_item(&self, resource: &str, mut item: Value) -> Value {
        let mut id_counters = self.id_counters.write().unwrap();
        let mut data = self.data.write().unwrap();
        
        // Get the next ID
        let next_id = id_counters
            .entry(resource.to_string())
            .or_insert(1);
        
        // Add ID to the item
        if let Value::Object(obj) = &mut item {
            obj.insert("id".to_string(), Value::Number((*next_id).into()));
            *next_id += 1;
        }
        
        // Add or update the item in the collection
        if let Some(collection) = data.get_mut(resource) {
            if let Value::Array(items) = collection {
                items.push(item.clone());
            } else {
                // Convert single object to array
                let array = vec![collection.clone(), item.clone()];
                *collection = Value::Array(array);
            }
        } else {
            // Create a new collection
            data.insert(resource.to_string(), Value::Array(vec![item.clone()]));
        }
        
        item
    }
    
    pub fn update_item(&self, resource: &str, id: &str, updates: Value) -> Option<Value> {
        let mut data = self.data.write().unwrap();
        
        if let Some(collection) = data.get_mut(resource) {
            if let Value::Array(items) = collection {
                // Find the item with matching ID
                for item in items.iter_mut() {
                    if let Value::Object(obj) = item {
                        if let Some(item_id) = obj.get("id") {
                            if item_id.to_string() == id {
                                // Apply updates
                                if let Value::Object(updates_obj) = &updates {
                                    for (key, value) in updates_obj {
                                        if key != "id" {  // Don't update ID
                                            obj.insert(key.clone(), value.clone());
                                        }
                                    }
                                }
                                return Some(item.clone());
                            }
                        }
                    }
                }
            } else if let Value::Object(obj) = collection {
                // Handle single object resources
                if let Some(obj_id) = obj.get("id") {
                    if obj_id.to_string() == id {
                        // Apply updates
                        if let Value::Object(updates_obj) = &updates {
                            for (key, value) in updates_obj {
                                if key != "id" {  // Don't update ID
                                    obj.insert(key.clone(), value.clone());
                                }
                            }
                        }
                        return Some(collection.clone());
                    }
                }
            }
        }
        
        None
    }
    
    pub fn delete_item(&self, resource: &str, id: &str) -> bool {
        let mut data = self.data.write().unwrap();
        
        if let Some(collection) = data.get_mut(resource) {
            if let Value::Array(items) = collection {
                // Find the index of the item with matching ID
                let index = items.iter().position(|item| {
                    if let Value::Object(obj) = item {
                        if let Some(item_id) = obj.get("id") {
                            return item_id.to_string() == id;
                        }
                    }
                    false
                });
                
                // Remove the item if found
                if let Some(index) = index {
                    items.remove(index);
                    return true;
                }
            } else if let Value::Object(obj) = collection {
                // Handle single object resources
                if let Some(obj_id) = obj.get("id") {
                    if obj_id.to_string() == id {
                        // Replace with empty object
                        *collection = Value::Object(serde_json::Map::new());
                        return true;
                    }
                }
            }
        }
        
        false
    }
}