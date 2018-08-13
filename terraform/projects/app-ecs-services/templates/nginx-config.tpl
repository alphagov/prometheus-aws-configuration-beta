
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}

stream {
    server {
      listen 9094;

      proxy_pass  ${mesh_1_dns_name}:9094;

      resolver 10.0.0.2 valid=10s;
    }

    server {
      listen 9095;

      proxy_pass  ${mesh_2_dns_name}:9094;

      resolver 10.0.0.2 valid=10s;
    }

    server {
      listen 9096;

      proxy_pass  ${mesh_3_dns_name}:9094;

      resolver 10.0.0.2 valid=10s;
    }

}