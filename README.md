# Bohongan

A zero-config JSON server built with Rust, inspired by the Node.js [json-server](https://github.com/typicode/json-server) package. It creates a full fake REST API with just a JSON file, perfect for prototyping and mocking.

## Features

- ✅ Zero configuration needed
- ✅ Full REST API based on your JSON structure
- ✅ Supports GET, POST, PUT, PATCH, DELETE verbs
- ✅ Automatic routes for all resources
- ✅ Command-line interface

## Installation

### Prerequisites

- Rust 1.65 or later

### Building from source

1. Clone this repository
2. Build the executable:

```bash
cargo build --release