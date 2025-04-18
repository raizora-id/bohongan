use bohongan::cli::run_cli;
use log::info;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize the logger
    env_logger::init_from_env(env_logger::Env::default().default_filter_or("info"));
    
    // Run the CLI
    info!("Starting Bohongan JSON Server");
    run_cli().await
}