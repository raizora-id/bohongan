use crate::server::start_server;
use crate::store::ResourceStore;
use clap::{Arg, Command};
use log::{error, info};
use serde_json::Value;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

pub async fn run_cli() -> std::io::Result<()> {
    let matches = Command::new("Bohongan")
        .version("0.1.0")
        .author("Bohongan Team")
        .about("A zero-config JSON server for mocking REST APIs")
        .arg(
            Arg::new("data")
                .short('d')
                .long("data")
                .value_name("FILE")
                .help("JSON file to use as data source (can be specified multiple times)")
                .required_unless_present("proto")
                .action(clap::ArgAction::Append),
        )
        .arg(
            Arg::new("proto")
                .short('p')
                .long("proto")
                .value_name("FILE")
                .help("Protocol Buffer file to use for API generation (can be specified multiple times)")
                .required_unless_present("data")
                .action(clap::ArgAction::Append),
        )
        .arg(
            Arg::new("port")
                .short('P')
                .long("port")
                .value_name("PORT")
                .help("Port to use (default: 3000)")
                .value_parser(clap::value_parser!(u16))
                .default_value("3000"),
        )
        .get_matches();

    // Get the port
    let port = *matches.get_one::<u16>("port").unwrap_or(&3000);

    // Process the JSON files if provided
    if let Some(data_files) = matches.get_many::<String>("data") {
        let data_files: Vec<&String> = data_files.collect();
        
        // Check if all files exist
        let missing_files: Vec<&String> = data_files
            .iter()
            .filter(|file| !Path::new(file).exists())
            .cloned()
            .collect();
        
        if !missing_files.is_empty() {
            error!("Error: The following files were not found:");
            for file in missing_files {
                error!("  - {}", file);
            }
            std::process::exit(1);
        }
        
        // Load and merge all JSON files
        info!("Loading data from {} files:", data_files.len());
        let mut merged_data = HashMap::new();
        
        for file_path in data_files {
            info!("  - {}", file_path);
            let file_data = fs::read_to_string(file_path)?;
            let json_data: Value = serde_json::from_str(&file_data)?;
            
            if let Value::Object(map) = json_data {
                for (key, value) in map {
                    // Merge the resources
                    if let Some(existing) = merged_data.get_mut(&key) {
                        merge_resource(existing, value);
                    } else {
                        merged_data.insert(key, value);
                    }
                }
            } else {
                error!("Error: {} is not a valid JSON object", file_path);
                std::process::exit(1);
            }
        }
        
        // Create and initialize the resource store
        let store = ResourceStore::new(merged_data);
        
        // Start the server
        info!("Bohongan JSON Server is running at http://localhost:{}", port);
        info!("Press Ctrl+C to stop");
        
        return start_server(store, port).await;
    }
    // Process the Proto files if provided
    else if let Some(proto_files) = matches.get_many::<String>("proto") {
        let proto_files: Vec<&String> = proto_files.collect();
        
        // Check if all files exist
        let missing_files: Vec<&String> = proto_files
            .iter()
            .filter(|file| !Path::new(file).exists())
            .cloned()
            .collect();
        
        if !missing_files.is_empty() {
            error!("Error: The following files were not found:");
            for file in missing_files {
                error!("  - {}", file);
            }
            std::process::exit(1);
        }
        
        // Load and process all Proto files
        info!("Loading API schema from {} proto files:", proto_files.len());
        
        // TODO: Implement proto file processing
        // Currently this is just a placeholder to match the structure
        let merged_data = process_proto_files(proto_files)?;
        
        // Create and initialize the resource store
        let store = ResourceStore::new(merged_data);
        
        // Start the server
        info!("Bohongan JSON Server is running at http://localhost:{}", port);
        info!("Press Ctrl+C to stop");
        
        return start_server(store, port).await;
    }
    
    // Should never reach here due to clap's requirement settings
    Ok(())
}

fn merge_resource(existing: &mut Value, new_value: Value) {
    match (existing, new_value) {
        (Value::Array(existing_array), Value::Array(new_array)) => {
            // When both are arrays, merge items by ID
            let mut id_map: HashMap<String, usize> = HashMap::new();
            
            // First, index existing items by ID
            for (i, item) in existing_array.iter().enumerate() {
                if let Value::Object(obj) = item {
                    if let Some(Value::Number(id)) = obj.get("id") {
                        id_map.insert(id.to_string(), i);
                    }
                }
            }
            
            // Then process new items
            for item in new_array {
                if let Value::Object(obj) = &item {
                    if let Some(Value::Number(id)) = obj.get("id") {
                        let id_str = id.to_string();
                        if let Some(index) = id_map.get(&id_str) {
                            // Update existing item
                            existing_array[*index] = item;
                        } else {
                            // Add new item
                            existing_array.push(item);
                        }
                    } else {
                        // No ID, just add
                        existing_array.push(item);
                    }
                } else {
                    // Not an object, just add
                    existing_array.push(item);
                }
            }
        }
        (existing, new_value) => {
            // For non-arrays or when types don't match, prefer the newer value
            *existing = new_value;
        }
    }
}

fn process_proto_files(proto_files: Vec<&String>) -> std::io::Result<HashMap<String, Value>> {
    use crate::proto::ProtoLoader;
    
    let mut merged_data = HashMap::new();
    
    for file_path in proto_files {
        info!("  - {}", file_path);
        match ProtoLoader::load_proto_file(file_path) {
            Ok(schema) => {
                // Merge the schema into our data
                for (key, value) in schema {
                    if let Some(existing) = merged_data.get_mut(&key) {
                        merge_resource(existing, value);
                    } else {
                        merged_data.insert(key, value);
                    }
                }
            }
            Err(e) => {
                error!("Error processing proto file {}: {}", file_path, e);
                std::process::exit(1);
            }
        }
    }
    
    Ok(merged_data)
}