## Note
Every "optimization" we do is simply fine tuning for specific resources we serve, we manage tradeoffs, there is not best performance nginx server configuration for all.

## [F] File server
### [F.1] config location
`templates/uncompressed_file.conf.j2`

### [F.2] spawn nginx processes dynamically
Use this inside the global configuration of nginx:
`worker_processes  auto;`

### [F.3] enable compress to decrease network load
Saves bandwidth and decreases traffic, add this inside http block:
`gzip on
gzip_comp_level 5;
gzip_min_length 256;
gzip_proxied any;
gzip_types application/json text/css application/javascript text/plain;`

### [F.4] optimize tcp connections
Under http block:
`tcp_nodelay on;`

### [F.5] Limit memory usage and lower buffer
Under http block:
`client_body_buffer_size 10K;
client_header_buffer_size 1k;
client_max_body_size 8m;
large_client_header_buffers 2 1k;`

### [F.6] Timeouts
Inside http block, change the keepalive value to something lower like this:
`keepalive_timeout 15;`

## [V] Video streaming server
For video server, we have to turn the compression off above all, as video files are already highly compressed and gzip would increase performance and waste cpu.

Revert the [F.3] entirely, or remove any such options.

### [V.1] config location
`templates/video.conf.j2`

### [V.2] Direct I/O instead of buffers
Buffering hurts the performance when serving media files, so instead directly serve the files, in http block:
`directio 4m;
aio threads;`

### [V.3] Enable caching to reduce disk usage
Disks can be slow especially when frequently accessed, we can cache file descriptors for video segments:
`open_file_cache max=1000 inactive=30s;
open_file_cache_valid 60s;
open_file_cache_min_uses 2;
open_file_cache_errors on;`

### [V.4] Bandwidth throttling
Prevent the download burst for few minutes, let files be served realtime, inside `location /` block:
`limit_rate_after 5m;
limit_rate 1m;`
