# Nginx Configuration & Optimization Guide

> **Core Principle:** Every optimization is a deliberate trade-off tailored to a specific workload. There is no universal "best" Nginx configuration—tuning depends entirely on whether the server delivers lightweight static assets or high-throughput media streams.

---

## 1. Static Asset & File Server

* **Target Template:** `templates/uncompressed_file.conf.j2`
* **Use Case:** Low latency, maximum compression ratio, and high concurrency for web assets (HTML, CSS, JS, fonts, JSON).

### 1.1 Process Management
Spawn worker processes matching the host's available CPU cores.

```nginx
# Global context
worker_processes auto;
```

### 1.2 Compression & Bandwidth Reduction
Compress text-based payloads over the wire to reduce transfer sizes and page-load times.

```nginx
# http context
gzip on;
gzip_comp_level 5;
gzip_min_length 256;
gzip_proxied any;
gzip_vary on;
gzip_types
    application/javascript
    application/json
    application/xml
    image/svg+xml
    text/css
    text/plain;
```

### 1.3 TCP Socket Optimization
Disable Nagle's algorithm and optimize kernel packet sending to deliver buffers immediately.

```nginx
# http context
sendfile on;
tcp_nopush on;
tcp_nodelay on;
```

### 1.4 Request Buffering & Memory Protection
Prevent memory bloat and resource exhaustion by constraining client header and body buffer allocations.

```nginx
# http context
client_body_buffer_size 128k;
client_header_buffer_size 1k;
client_max_body_size 8m;
large_client_header_buffers 4 8k;
```

### 1.5 Connection Lifecycles & Timeouts
Keep connections open long enough to pipeline assets without leaving idle sockets open indefinitely.

```nginx
# http context
keepalive_timeout 30;
keepalive_requests 1000;
reset_timedout_connection on;
```

---

## 2. Video Streaming Server

* **Target Template:** `templates/video.conf.j2`
* **Use Case:** Sequential reads, large payload transfers, and smooth byte-range seeking.

> **Crucial:** Disable all `gzip` compression directives. Video containers (`.mp4`, `.webm`, `.ts`, `.mkv`) are already heavily compressed. Running gzip on media assets wastes CPU cycles and adds delivery latency without reducing payload size.

### 2.1 Direct I/O & Asynchronous Offloading
Bypass the OS page cache for large media files to prevent RAM thrashing, offloading disk reads to dedicated background thread pools.

```nginx
# http context
sendfile on;
directio 4m;
directio_alignment 512;
aio threads;
```

### 2.2 File Descriptor Caching
Cache open file descriptors, directory structures, and file size metadata in memory to eliminate repeated disk lookups for media segments.

```nginx
# http context
open_file_cache max=10000 inactive=60s;
open_file_cache_valid 30s;
open_file_cache_min_uses 2;
open_file_cache_errors off;
```

### 2.3 Bandwidth Throttling & Playback Pacing
Provide an initial burst buffer for fast playback start, then throttle transfer speeds to match real-time consumption rates.

```nginx
# server or location context
limit_rate_after 5m;
limit_rate 1m;
```

### 2.4 Byte-Range & MP4 Streaming Directives
Ensure video players can scrub and seek reliably without downloading entire files.

```nginx
# location context
location ~* \.(mp4|m4v|mkv|webm|ts|m3u8)$ {
    mp4;
    mp4_buffer_size 1m;
    mp4_max_buffer_size 5m;

    add_header Accept-Ranges bytes;
    add_header Cache-Control "public, max-age=31536000, immutable";
}
```
