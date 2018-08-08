server {
  listen 80 default_server;

  location /health {
    return 200 "Static health check";
  }
}

server {
  listen 80;

  server_name alerts-1.*;

  if ($http_x_forwarded_proto = 'http') {
    return 301 https://$host$request_uri;
  }

  set $alert "${alertmanager_1_dns_name}";

  location / {
    proxy_pass  http://$alert;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  resolver 10.0.0.2 valid=10s;
}

server {
  listen 80;


  server_name alerts-2.*;

  if ($http_x_forwarded_proto = 'http') {
    return 301 https://$host$request_uri;
  }

  set $alert "${alertmanager_2_dns_name}";

  location / {
    proxy_pass  http://$alert;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  resolver 10.0.0.2 valid=10s;
}

server {
  listen 80;


  server_name alerts-3.*;

  if ($http_x_forwarded_proto = 'http') {
    return 301 https://$host$request_uri;
  }

  set $alert "${alertmanager_3_dns_name}";

  location / {
    proxy_pass  http://$alert;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  resolver 10.0.0.2 valid=10s;
}

server {
  listen 80;


  server_name prom-1.*;

  if ($http_x_forwarded_proto = 'http') {
    return 301 https://$host$request_uri;
  }

  set $alert "${prometheus_1_dns_name}";

  location / {
    proxy_pass  http://$alert;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  resolver 10.0.0.2 valid=10s;
}

server {
  listen 80;


  server_name prom-2.*;

  if ($http_x_forwarded_proto = 'http') {
    return 301 https://$host$request_uri;
  }

  set $alert "${prometheus_2_dns_name}";

  location / {
    proxy_pass  http://$alert;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  resolver 10.0.0.2 valid=10s;
}

server {
  listen 80;


  server_name prom-3.*;

  if ($http_x_forwarded_proto = 'http') {
    return 301 https://$host$request_uri;
  }

  set $alert "${prometheus_3_dns_name}";

  location / {
    proxy_pass  http://$alert;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  resolver 10.0.0.2 valid=10s;
}
