# Bohongan

A zero-config JSON server built with Elixir, inspired by the Node.js [json-server](https://github.com/typicode/json-server) package. It creates a full fake REST API with just a JSON file, perfect for prototyping and mocking.

## Features

- ✅ Zero configuration needed
- ✅ Full REST API based on your JSON structure
- ✅ Supports GET, POST, PUT, PATCH, DELETE verbs
- ✅ Automatic routes for all resources
- ✅ Command-line interface

## Installation

### Prerequisites

- Elixir 1.14 or later
- Erlang 24 or later

### Building from source

1. Clone this repository
2. Build the executable:

```bash
mix deps.get
mix escript.build
```

3. Move the executable to your PATH (optional):

```bash
# On macOS/Linux
sudo cp bohongan /usr/local/bin/

# On Windows - move to a directory in your PATH
```

## Usage

Create a JSON file with your data structure (e.g., `db.json`):

```json
{
  "posts": [
    { "id": 1, "title": "First post", "author": "John" },
    { "id": 2, "title": "Second post", "author": "Jane" }
  ],
  "comments": [
    { "id": 1, "postId": 1, "body": "Great post!", "author": "Mike" },
    { "id": 2, "postId": 1, "body": "I agree", "author": "Sarah" }
  ]
}
```

Then run the server:

```bash
./bohongan --data=db.json
```

Or if you added it to your PATH:

```bash
bohongan --data=db.json
```

The server will start on port 3000 by default. You can specify a different port:

```bash
bohongan --data=db.json --port=4000
```

## API

Based on the example `db.json` above, the following routes will be automatically generated:

### Routes

```
GET    /posts
GET    /posts/:id
POST   /posts
PUT    /posts/:id
PATCH  /posts/:id
DELETE /posts/:id

GET    /comments
GET    /comments/:id
POST   /comments
PUT    /comments/:id
PATCH  /comments/:id
DELETE /comments/:id
```

### Examples

#### Get all posts
```
GET /posts
```

#### Get a single post
```
GET /posts/1
```

#### Create a new post
```
POST /posts
Content-Type: application/json

{
  "title": "New post",
  "author": "Robert"
}
```

#### Update a post
```
PUT /posts/1
Content-Type: application/json

{
  "title": "Updated post",
  "author": "Robert"
}
```

#### Delete a post
```
DELETE /posts/1
```

## Home Route

GET `/` returns metadata about available resources and routes:

```json
{
  "resources": ["posts", "comments"],
  "routes": [
    {
      "resource": "posts",
      "endpoints": [
        { "method": "GET", "url": "/posts" },
        { "method": "GET", "url": "/posts/:id" },
        { "method": "POST", "url": "/posts" },
        { "method": "PUT", "url": "/posts/:id" },
        { "method": "PATCH", "url": "/posts/:id" },
        { "method": "DELETE", "url": "/posts/:id" }
      ]
    },
    {
      "resource": "comments",
      "endpoints": [
        { "method": "GET", "url": "/comments" },
        { "method": "GET", "url": "/comments/:id" },
        { "method": "POST", "url": "/comments" },
        { "method": "PUT", "url": "/comments/:id" },
        { "method": "PATCH", "url": "/comments/:id" },
        { "method": "DELETE", "url": "/comments/:id" }
      ]
    }
  ]
}
```

## Why Elixir?

While the original json-server is built with Node.js, Elixir offers several advantages:

- Concurrency via the BEAM VM
- Fault tolerance through OTP supervision
- Low memory footprint
- Simple and elegant code

## License

MIT